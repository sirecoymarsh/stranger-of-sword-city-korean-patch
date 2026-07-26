[CmdletBinding()]
param(
    [string]$GameRoot = 'Y:\SteamLibrary\steamapps\common\Stranger of Sword City'
)
$ErrorActionPreference = 'Stop'
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
