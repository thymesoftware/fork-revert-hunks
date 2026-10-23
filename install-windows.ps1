# Installs the "Revert File Changes" and "Revert Hunks..." custom commands into Fork (Windows)
# Usage:
#   install-windows.bat              Install / update
#   install-windows.bat -Uninstall   Uninstall
param(
    [switch]$Uninstall,
    [string]$ForkDir = (Join-Path $env:LOCALAPPDATA 'Fork'),
    [string]$InstallDir = (Join-Path $HOME 'fork-scripts')
)

$ErrorActionPreference = 'Stop'

# Keep this file ASCII only: Windows PowerShell 5.1 reads BOM-less scripts as the ANSI code page
$CommandNames = @('Revert File Changes', ('Revert Hunks' + [char]0x2026))
$ScriptName = 'revert-hunks.sh'
$ConfigPath = Join-Path $ForkDir 'custom-commands.json'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Convert-ToPosixPath([string]$Path) {
    if ($Path -match '^([A-Za-z]):\\(.*)$') {
        return '/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/')
    }
    return ($Path -replace '\\', '/')
}

if (-not (Test-Path $ForkDir)) {
    Write-Host "Fork settings folder not found: $ForkDir"
    Write-Host 'Install Fork and launch it once, then run this installer again.'
    exit 1
}

# Load existing commands (keep every entry that is not ours)
$entries = New-Object System.Collections.ArrayList
if (Test-Path $ConfigPath) {
    $raw = [System.IO.File]::ReadAllText($ConfigPath, $Utf8NoBom)
    if ($raw.Trim().Length -gt 0) {
        $parsed = ConvertFrom-Json $raw
        foreach ($entry in $parsed) {
            if ($CommandNames -notcontains $entry.name) { [void]$entries.Add($entry) }
        }
    }
    $backup = "$ConfigPath.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item $ConfigPath $backup
    Write-Host "Backup: $backup"
}

$hasVersion = $false
foreach ($entry in $entries) { if ($null -ne $entry.version) { $hasVersion = $true } }
if (-not $hasVersion) { $entries.Insert(0, [pscustomobject]@{ version = 2 }) }

$scriptPath = Join-Path $InstallDir $ScriptName

if ($Uninstall) {
    if (Test-Path $scriptPath) { Remove-Item $scriptPath }
    Write-Host "Removed: $scriptPath"
}
else {
    $source = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path $source)) {
        Write-Host "$ScriptName not found next to this installer: $source"
        exit 1
    }
    New-Item -ItemType Directory -Force $InstallDir | Out-Null
    Copy-Item $source $scriptPath -Force
    Write-Host "Installed: $scriptPath"

    $fileScript = @'
cd "${repo:path}" || exit 1
SHA="${sha}"
FILE="${file}"
if [ -z "$SHA" ] || [ -z "$FILE" ]; then echo "Could not get commit or file (sha=[$SHA] file=[$FILE])"; exit 1; fi
if git diff "$SHA^" "$SHA" -- "$FILE" | git apply -R; then
  echo "Reverted: $FILE"
elif git diff "$SHA^" "$SHA" -- "$FILE" | git apply -R --3way; then
  echo "Reverted with 3-way merge (result is staged): $FILE"
else
  echo "Failed to revert: $FILE"; exit 1
fi
'@

    $hunkScript = @'
cd "${repo:path}" || exit 1
SCRIPT='__SCRIPT__'
if command -v mintty > /dev/null; then
  mintty -t "Revert Hunks" -e /usr/bin/bash "$SCRIPT" "$PWD" "${sha}" "${file}"
else
  cmd.exe //c start "" bash "$SCRIPT" "$PWD" "${sha}" "${file}"
fi
'@
    $hunkScript = $hunkScript.Replace('__SCRIPT__', (Convert-ToPosixPath $scriptPath))

    [void]$entries.Add([pscustomobject][ordered]@{
        action = [pscustomobject][ordered]@{
            script      = ($fileScript.Trim() -replace "`r`n", "`n")
            showOutput  = $true
            type        = 'sh'
            waitForExit = $true
        }
        name   = $CommandNames[0]
        target = 'file'
    })
    [void]$entries.Add([pscustomobject][ordered]@{
        action = [pscustomobject][ordered]@{
            script      = ($hunkScript.Trim() -replace "`r`n", "`n")
            showOutput  = $false
            type        = 'sh'
            waitForExit = $true
        }
        name   = $CommandNames[1]
        target = 'file'
    })
}

$json = ConvertTo-Json -InputObject $entries.ToArray() -Depth 10
[System.IO.File]::WriteAllText($ConfigPath, $json, $Utf8NoBom)

if ($Uninstall) {
    Write-Host 'Uninstalled. Restart Fork to apply.'
}
else {
    Write-Host "Updated: $ConfigPath"
    Write-Host 'Done. Restart Fork, then right-click a file in a commit to use the commands.'
}
