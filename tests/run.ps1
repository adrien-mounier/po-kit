# Runs the kit's tests under Windows PowerShell 5.1, with no dependency beyond git:
#
#   powershell -NoProfile -File tests\run.ps1            every test file
#   powershell -NoProfile -File tests\run.ps1 subject    only tests\subject.tests.ps1
#
# A test file is any tests\<name>.tests.ps1. Adding one needs no change here.
param([string]$Only = '*')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$Results = @{ Passed = 0; Failed = 0 }
try {
    foreach ($file in Get-ChildItem (Join-Path $PSScriptRoot "$Only.tests.ps1") | Sort-Object Name) {
        Write-Host ''
        Write-Host $file.Name
        . $file.FullName
    }
}
finally {
    Remove-TestWorkspaces
}

Write-Host ''
Write-Host "$($Results.Passed) passed, $($Results.Failed) failed"
if ($Results.Failed -gt 0 -or $Results.Passed -eq 0) { exit 1 }
