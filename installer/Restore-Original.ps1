[CmdletBinding()]
param(
    [string]$GameRoot = 'Y:\SteamLibrary\steamapps\common\Stranger of Sword City',
    [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Stranger of Sword City Korean Patch Backups'),
    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'

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
function Assert-ProcessesStopped {
    foreach ($processName in @('StrangerOfSwordCity')) {
        if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
            throw "게임 프로세스를 먼저 종료하십시오: $processName"
        }
    }
}
function Replace-Atomic([string]$Source, [string]$Destination, [string]$ExpectedHash) {
    $directory = Split-Path -Parent $Destination
    $temp = Join-Path $directory ('.korean-restore-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $swap = Join-Path $directory ('.korean-restore-' + [Guid]::NewGuid().ToString('N') + '.swap')
    try {
        [IO.File]::Copy($Source, $temp, $true)
        if ((Get-Sha256 $temp) -ne $ExpectedHash) { throw "백업 해시 검증 실패: $Source" }
        [IO.File]::Replace($temp, $Destination, $swap, $true)
        [IO.File]::Delete($swap)
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
        if ([IO.File]::Exists($swap)) { [IO.File]::Delete($swap) }
    }
    if ((Get-Sha256 $Destination) -ne $ExpectedHash) { throw "복구 후 해시 검증 실패: $Destination" }
}

$recoverableStatuses = @('installed','installing','rolling_back','rollback_incomplete','rolled_back','restored')
if (-not $BackupPath) {
    $candidate = Get-ChildItem -LiteralPath $BackupRoot -Directory -ErrorAction Stop |
        Where-Object {
            $candidateManifest = Join-Path $_.FullName 'backup_manifest.json'
            if (-not (Test-Path -LiteralPath $candidateManifest -PathType Leaf)) { return $false }
            try {
                $candidateJournal = Get-Content -LiteralPath $candidateManifest -Raw -Encoding UTF8 | ConvertFrom-Json
                return $candidateJournal.status -in $recoverableStatuses
            } catch {
                return $false
            }
        } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if (-not $candidate) { throw "사용 가능한 백업이 없습니다: $BackupRoot" }
    $BackupPath = $candidate.FullName
}
$backup = [IO.Path]::GetFullPath($BackupPath)
$journalPath = Join-Path $backup 'backup_manifest.json'
if (-not (Test-Path -LiteralPath $journalPath -PathType Leaf)) { throw "백업 매니페스트 누락: $journalPath" }
$journal = Get-Content -LiteralPath $journalPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($journal.status -notin $recoverableStatuses) {
    throw "복구할 수 없는 백업 상태: $($journal.status)"
}
Assert-ProcessesStopped

$game = [IO.Path]::GetFullPath($GameRoot)
$states = @()
foreach ($file in $journal.files) {
    $live = Resolve-SafeChild $game $file.path
    $copy = Resolve-SafeChild (Join-Path $backup 'original') $file.path
    if (-not (Test-Path -LiteralPath $live -PathType Leaf)) { throw "게임 파일 누락: $live" }
    if (-not (Test-Path -LiteralPath $copy -PathType Leaf)) { throw "원본 백업 누락: $copy" }
    if ((Get-Sha256 $copy) -ne $file.original_sha256) { throw "원본 백업 변조: $($file.path)" }
    $hash = Get-Sha256 $live
    if ($hash -eq $file.original_sha256) { $state = 'original' }
    elseif ($hash -eq $file.patched_sha256) { $state = 'patched' }
    else { throw "알 수 없는/변조된 게임 파일: $($file.path)" }
    $states += [pscustomobject]@{ File=$file; Live=$live; Copy=$copy; State=$state }
}
# 대용량 백업 검증 중 게임이 다시 실행되었을 수 있으므로 쓰기 직전에 재확인합니다.
Assert-ProcessesStopped
foreach ($item in $states | Where-Object State -eq 'patched') {
    Replace-Atomic $item.Copy $item.Live $item.File.original_sha256
}
foreach ($item in $states) {
    if ((Get-Sha256 $item.Live) -ne $item.File.original_sha256) {
        throw "최종 원본 검증 실패: $($item.File.path)"
    }
}
$journal.status = 'restored'
$journal | Add-Member -NotePropertyName restored_utc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
$journal | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $journalPath -Encoding UTF8
Write-Host "원본 복구 및 해시 검증 완료"
Write-Host "사용한 백업: $backup"
