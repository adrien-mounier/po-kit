# The register tool: the only program allowed to write the register. It runs without any model.
#
#   powershell -NoProfile -File tools\register.ps1 <command> [arguments] [-Today yyyy-mm-dd]
#
# It works on the workspace it sits in. Each command is one file under tools\commands, run with
# everything defined here in scope and its own arguments in $Arguments: adding a command means
# adding a file. -Today sets the date this run treats as today.
#
# Keep this file and the commands in plain ASCII: Windows PowerShell 5.1 misreads other
# characters in a script saved without a byte order mark.
param(
    [Parameter(Position = 0)][string]$Command,
    [string]$Today,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
)

$ErrorActionPreference = 'Stop'
$Utf8 = New-Object System.Text.UTF8Encoding $false
# Agents read the output as UTF-8. A run without a console cannot set this, and does not need to.
try { [Console]::OutputEncoding = $Utf8 } catch { }

$Workspace = Split-Path -Parent $PSScriptRoot
$ProposalPath = Join-Path $Workspace 'state\proposal.json'

function Read-JsonFile([string]$Path) {
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-PendingProposal {
    # The operations of the pending proposal.
    (Read-JsonFile $ProposalPath).operations
}

$commandFile = Join-Path $PSScriptRoot "commands\$Command.ps1"
if ($Command -notmatch '^[a-z]+$' -or -not (Test-Path -LiteralPath $commandFile)) {
    $known = (Get-ChildItem (Join-Path $PSScriptRoot 'commands\*.ps1') | ForEach-Object { $_.BaseName }) -join ', '
    "Unknown command '$Command'. Commands: $known."
    exit 1
}
. $commandFile
