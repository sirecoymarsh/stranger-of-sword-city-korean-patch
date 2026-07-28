[CmdletBinding()]
param(
    [string]$GameRoot
)
$ErrorActionPreference = 'Stop'

function Resolve-SteamGameRoot([string]$RequestedRoot) {
    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        return [IO.Path]::GetFullPath($RequestedRoot)
    }
    $steamRoots = @()
    try {
        $steamPath = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath
        if ($steamPath) { $steamRoots += [IO.Path]::GetFullPath($steamPath) }
    } catch {}
    $defaultSteam = Join-Path ${env:ProgramFiles(x86)} 'Steam'
    if (Test-Path -LiteralPath $defaultSteam -PathType Container) {
        $steamRoots += [IO.Path]::GetFullPath($defaultSteam)
    }
    foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        foreach ($folder in @('SteamLibrary', 'Steam')) {
            $candidateRoot = Join-Path $drive.Root $folder
            if (Test-Path -LiteralPath (Join-Path $candidateRoot 'steamapps') -PathType Container) {
                $steamRoots += [IO.Path]::GetFullPath($candidateRoot)
            }
        }
    }
    foreach ($root in @($steamRoots | Select-Object -Unique)) {
        $libraries = @($root)
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf -PathType Leaf) {
            $raw = Get-Content -LiteralPath $vdf -Raw -Encoding UTF8
            foreach ($match in [regex]::Matches($raw, '"path"\s+"([^"]+)"')) {
                $libraries += ($match.Groups[1].Value -replace '\\\\', '\')
            }
        }
        foreach ($library in @($libraries | Select-Object -Unique)) {
            $candidate = Join-Path $library 'steamapps\common\Stranger of Sword City'
            if (Test-Path -LiteralPath (Join-Path $candidate 'StrangerOfSwordCity.exe') -PathType Leaf) {
                return [IO.Path]::GetFullPath($candidate)
            }
        }
    }
    throw 'Steam 라이브러리에서 게임을 찾지 못했습니다. -GameRoot로 설치 폴더를 지정하십시오.'
}

$GameRoot = Resolve-SteamGameRoot $GameRoot
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifests\install_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$game = [IO.Path]::GetFullPath($GameRoot).TrimEnd('\') + '\'
$result = @()
foreach ($file in $manifest.files) {
    $path = [IO.Path]::GetFullPath((Join-Path $game ($file.path -replace '/', '\')))
    if (-not $path.StartsWith($game, [StringComparison]::OrdinalIgnoreCase)) { throw "허용되지 않은 경로: $($file.path)" }
    $hash = if (Test-Path -LiteralPath $path -PathType Leaf) {
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    } else { '' }
    $state = if ($hash -eq $file.patched_sha256) { 'patched' }
             elseif ($hash -eq $file.original_sha256) { 'original' }
             elseif (-not $hash) { 'missing' }
             else { 'unknown' }
    $result += [pscustomobject]@{ Path=$file.path; State=$state; SHA256=$hash }
}
$result | Format-Table -AutoSize
if (@($result | Where-Object State -ne 'patched').Count) { exit 1 }
Write-Host "모든 패치 파일이 일치합니다."
