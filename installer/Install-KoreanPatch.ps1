[CmdletBinding()]
param(
    [string]$GameRoot = 'Y:\SteamLibrary\steamapps\common\Stranger of Sword City',
    [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Stranger of Sword City Korean Patch Backups')
)

$ErrorActionPreference = 'Stop'
$PackageRoot = $PSScriptRoot
$ManifestPath = Join-Path $PackageRoot 'manifests\install_manifest.json'
$PackageManifestPath = Join-Path $PackageRoot 'manifests\package_manifest.json'
$PayloadRoot = Join-Path $PackageRoot 'payload'

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Resolve-SafeChild([string]$Root, [string]$Relative) {
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $candidate = [IO.Path]::GetFullPath((Join-Path $base ($Relative -replace '/', '\')))
    if (-not $candidate.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        throw "허용되지 않은 상대 경로: $Relative"
    }
    return $candidate
}

function Test-SameOrChild([string]$Candidate, [string]$Parent) {
    $candidateFull = [IO.Path]::GetFullPath($Candidate).TrimEnd('\')
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\')
    return $candidateFull.Equals($parentFull, [StringComparison]::OrdinalIgnoreCase) -or
        $candidateFull.StartsWith($parentFull + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-ProcessesStopped($ProcessNames) {
    foreach ($processName in $ProcessNames) {
        if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
            throw "게임 프로세스를 먼저 종료하십시오: $processName"
        }
    }
}

function Assert-PackageInventory([string]$Root, [string]$InventoryPath) {
    if (-not (Test-Path -LiteralPath $InventoryPath -PathType Leaf)) {
        throw "패키지 인벤토리를 찾을 수 없습니다: $InventoryPath"
    }
    $inventory = Get-Content -LiteralPath $InventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($inventory.schema_version -ne 1 -or $inventory.algorithm -ne 'SHA-256') {
        throw '지원하지 않는 패키지 인벤토리 형식입니다.'
    }
    $entries = @($inventory.files)
    if ([int]$inventory.file_count_excluding_this_manifest -ne $entries.Count) {
        throw '패키지 인벤토리 파일 수가 일치하지 않습니다.'
    }
    $seen = @{}
    foreach ($entry in $entries) {
        $relative = [string]$entry.path
        if ([string]::IsNullOrWhiteSpace($relative)) {
            throw '패키지 인벤토리에 빈 경로가 있습니다.'
        }
        $key = ($relative -replace '\\', '/').ToLowerInvariant()
        if ($key -eq 'manifests/package_manifest.json') {
            throw '패키지 인벤토리는 자기 자신을 포함할 수 없습니다.'
        }
        if ($seen.ContainsKey($key)) {
            throw "패키지 인벤토리에 중복 경로가 있습니다: $relative"
        }
        $seen[$key] = $true
        $path = Resolve-SafeChild $Root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "패키지 파일 누락: $relative"
        }
        if ((Get-Item -LiteralPath $path).Length -ne [long]$entry.size) {
            throw "패키지 파일 크기 불일치: $relative"
        }
        if ((Get-Sha256 $path) -ne ([string]$entry.sha256).ToLowerInvariant()) {
            throw "패키지 파일 해시 불일치: $relative"
        }
    }
    if (-not $seen.ContainsKey('manifests/install_manifest.json')) {
        throw '패키지 인벤토리에 설치 매니페스트가 없습니다.'
    }
}

function Replace-Atomic([string]$Source, [string]$Destination, [string]$ExpectedHash) {
    $directory = Split-Path -Parent $Destination
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $temp = Join-Path $directory ('.korean-patch-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $swap = Join-Path $directory ('.korean-patch-' + [Guid]::NewGuid().ToString('N') + '.swap')
    try {
        [IO.File]::Copy($Source, $temp, $true)
        if ((Get-Sha256 $temp) -ne $ExpectedHash) {
            throw "임시 파일 해시 검증 실패: $Destination"
        }
        if ([IO.File]::Exists($Destination)) {
            [IO.File]::Replace($temp, $Destination, $swap, $true)
            [IO.File]::Delete($swap)
        } else {
            [IO.File]::Move($temp, $Destination)
        }
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
        if ([IO.File]::Exists($swap)) { [IO.File]::Delete($swap) }
    }
    if ((Get-Sha256 $Destination) -ne $ExpectedHash) {
        throw "교체 후 해시 검증 실패: $Destination"
    }
}

Assert-PackageInventory $PackageRoot $PackageManifestPath
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$game = [IO.Path]::GetFullPath($GameRoot)
$package = [IO.Path]::GetFullPath($PackageRoot)
$backupBase = [IO.Path]::GetFullPath($BackupRoot)
if ((Test-SameOrChild $backupBase $game) -or (Test-SameOrChild $backupBase $package)) {
    throw '백업 폴더는 게임 및 패치 패키지 바깥이어야 합니다.'
}
Assert-ProcessesStopped $manifest.process_names

$states = @()
foreach ($file in $manifest.files) {
    $live = Resolve-SafeChild $game $file.path
    $payload = Resolve-SafeChild $PayloadRoot $file.path
    if (-not (Test-Path -LiteralPath $live -PathType Leaf)) { throw "게임 파일 누락: $live" }
    if (-not (Test-Path -LiteralPath $payload -PathType Leaf)) { throw "패치 파일 누락: $payload" }
    $payloadHash = Get-Sha256 $payload
    if ($payloadHash -ne $file.patched_sha256) { throw "패키지 변조 감지: $($file.path)" }
    $liveHash = Get-Sha256 $live
    $state = if ($liveHash -eq $file.original_sha256) { 'original' }
             elseif ($liveHash -eq $file.patched_sha256) { 'patched' }
             else { 'unknown' }
    $states += [pscustomobject]@{ File=$file; Live=$live; Payload=$payload; State=$state; Hash=$liveHash }
}
$unknown = @($states | Where-Object State -eq 'unknown')
if ($unknown.Count) {
    throw ('알 수 없는/변조된 게임 파일: ' + (($unknown | ForEach-Object { $_.File.path }) -join ', '))
}
$originalCount = @($states | Where-Object State -eq 'original').Count
$patchedCount = @($states | Where-Object State -eq 'patched').Count
if ($patchedCount -eq $states.Count) {
    Write-Host "이미 설치되어 있으며 모든 파일 해시가 일치합니다."
    exit 0
}
if ($originalCount -ne $states.Count) {
    throw '원본/패치 파일이 섞인 상태입니다. Restore-Original.ps1로 먼저 복구하십시오.'
}

[IO.Directory]::CreateDirectory($backupBase) | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmssZ')
$backup = Join-Path $backupBase ($stamp + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
$originalRoot = Join-Path $backup 'original'
$patchedRoot = Join-Path $backup 'patched'
[IO.Directory]::CreateDirectory($originalRoot) | Out-Null
[IO.Directory]::CreateDirectory($patchedRoot) | Out-Null

$journal = [ordered]@{
    schema_version = 1
    package_id = $manifest.package_id
    game_root = $game
    created_utc = [DateTime]::UtcNow.ToString('o')
    status = 'backing_up'
    files = @()
}
$journalPath = Join-Path $backup 'backup_manifest.json'
try {
    foreach ($item in $states) {
        $rel = $item.File.path
        $originalCopy = Resolve-SafeChild $originalRoot $rel
        $patchedCopy = Resolve-SafeChild $patchedRoot $rel
        [IO.Directory]::CreateDirectory((Split-Path -Parent $originalCopy)) | Out-Null
        [IO.Directory]::CreateDirectory((Split-Path -Parent $patchedCopy)) | Out-Null
        [IO.File]::Copy($item.Live, $originalCopy, $true)
        [IO.File]::Copy($item.Payload, $patchedCopy, $true)
        if ((Get-Sha256 $originalCopy) -ne $item.File.original_sha256) { throw "원본 백업 실패: $rel" }
        if ((Get-Sha256 $patchedCopy) -ne $item.File.patched_sha256) { throw "패치 복구본 백업 실패: $rel" }
        $journal.files += [ordered]@{
            path = $rel
            original_sha256 = $item.File.original_sha256
            patched_sha256 = $item.File.patched_sha256
            installed = $false
        }
    }
    $journal.status = 'installing'
    $journal | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $journalPath -Encoding UTF8
    # 대용량 동영상 백업 중 게임이 다시 실행되었을 수 있으므로 쓰기 직전에 재확인합니다.
    Assert-ProcessesStopped $manifest.process_names
    for ($index = 0; $index -lt $states.Count; $index++) {
        $item = $states[$index]
        Replace-Atomic $item.Payload $item.Live $item.File.patched_sha256
        $journal.files[$index].installed = $true
        $journal | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $journalPath -Encoding UTF8
    }
    $journal.status = 'installed'
    $journal.completed_utc = [DateTime]::UtcNow.ToString('o')
    $journal | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $journalPath -Encoding UTF8
} catch {
    $failure = $_
    $journal.status = 'rolling_back'
    $journal.failure = $failure.Exception.Message
    $journal | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $journalPath -Encoding UTF8
    $rollbackErrors = @()
    foreach ($item in $states) {
        try {
            $copy = Resolve-SafeChild $originalRoot $item.File.path
            if (Test-Path -LiteralPath $copy -PathType Leaf) {
                if (-not (Test-Path -LiteralPath $item.Live -PathType Leaf)) {
                    Replace-Atomic $copy $item.Live $item.File.original_sha256
                } else {
                    $rollbackHash = Get-Sha256 $item.Live
                    if ($rollbackHash -eq $item.File.patched_sha256) {
                        Replace-Atomic $copy $item.Live $item.File.original_sha256
                    } elseif ($rollbackHash -ne $item.File.original_sha256) {
                        throw "롤백을 거부한 알 수 없는 게임 파일: $($item.File.path)"
                    }
                }
            }
        } catch {
            $rollbackErrors += $_.Exception.Message
        }
    }
    $journal.status = if ($rollbackErrors.Count) { 'rollback_incomplete' } else { 'rolled_back' }
    $journal.rollback_errors = $rollbackErrors
    $journal | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $journalPath -Encoding UTF8
    throw $failure
}

Write-Host "한국어 패치 설치 및 해시 검증 완료"
Write-Host "백업: $backup"
