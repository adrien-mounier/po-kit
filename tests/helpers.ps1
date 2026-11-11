# Shared by every test file. A test builds a temporary workspace under version control, runs the
# register tool once as the agent would, and asserts on the resulting files, output and exit code.
#
# Keep every .ps1 of the kit in plain ASCII: Windows PowerShell 5.1 misreads other characters in a
# script saved without a byte order mark. Text with accents goes in a fixture file.

$KitRoot = Split-Path -Parent $PSScriptRoot
$Fixtures = Join-Path $PSScriptRoot 'fixtures'
$TestRoot = Join-Path ([IO.Path]::GetTempPath()) ('po-kit-tests-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$Utf8 = New-Object System.Text.UTF8Encoding $false

# The register tool prints UTF-8; read it as such.
try { [Console]::OutputEncoding = $Utf8 } catch { }

function Test([string]$Name, [scriptblock]$Body) {
    try {
        & $Body
        $Results.Passed++
        Write-Host "  ok    $Name"
    }
    catch {
        $Results.Failed++
        Write-Host "  FAIL  $Name"
        Write-Host "        $($_.Exception.Message)"
    }
}

function Assert-True($Condition, [string]$What) {
    if (-not $Condition) { throw $What }
}

function Assert-Equal($Expected, $Actual, [string]$What) {
    if ($Expected -cne $Actual) { throw "${What}: expected '$Expected', got '$Actual'" }
}

function Assert-Match([string]$Text, [string]$Pattern, [string]$What) {
    if ($Text -notmatch $Pattern) { throw "${What}: nothing matches '$Pattern' in:`n$Text" }
}

function New-TestWorkspace {
    # A fresh workspace: the kit's template, under version control, with one first commit.
    # It is built once per run, then copied for each test.
    $pristine = Join-Path $TestRoot 'pristine'
    if (-not (Test-Path $pristine)) {
        New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
        Copy-Item (Join-Path $KitRoot 'workspace-template') $pristine -Recurse
        git -C $pristine init -q -b main
        git -C $pristine config user.name 'PO Kit tests'
        git -C $pristine config user.email 'tests@example.com'
        git -C $pristine config core.autocrlf false
        git -C $pristine add -A
        git -C $pristine commit -q -m 'Empty workspace'
    }
    $workspace = Join-Path $TestRoot ([Guid]::NewGuid().ToString('N').Substring(0, 8))
    Copy-Item $pristine $workspace -Recurse -Force
    $workspace
}

function Remove-TestWorkspaces {
    if (Test-Path $TestRoot) { Remove-Item $TestRoot -Recurse -Force }
}

function Invoke-Register([string]$Workspace) {
    # Runs the workspace's register tool once: Invoke-Register $ws apply -Today 2026-03-02
    # Returns its output (standard output and errors together) and its exit code.
    $ErrorActionPreference = 'Continue'
    $lines = & powershell.exe -NoProfile -File (Join-Path $Workspace 'tools\register.ps1') @args 2>&1 | ForEach-Object { "$_" }
    @{ Output = ($lines -join "`n"); ExitCode = $LASTEXITCODE }
}

function Read-Json([string]$Path) {
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $Value -Depth 20), $Utf8)
}

function Set-Proposal([string]$Workspace, $Proposal) {
    # Leaves a pending proposal in the workspace, as a routine would.
    # $Proposal is the name of a file under tests\fixtures, or a hashtable.
    $path = Join-Path $Workspace 'state\proposal.json'
    if ($Proposal -is [string]) { Copy-Item (Join-Path $Fixtures $Proposal) $path }
    else { Write-Json $path $Proposal }
}

function New-SubjectOperation([hashtable]$Fields = @{}) {
    # One valid operation creating a subject of Example Bank.
    # $Fields replaces or adds fields; a $null value removes the field.
    $subject = @{
        title          = 'Mobile onboarding'
        kind           = 'product'
        horizon        = 'now'
        evidence_level = 'fact'
        source         = @{ where = 'conversation with the PO'; read_on = '2026-03-02' }
    }
    foreach ($name in $Fields.Keys) {
        if ($null -eq $Fields[$name]) { $subject.Remove($name) } else { $subject[$name] = $Fields[$name] }
    }
    @{ op = 'create'; type = 'subject'; fields = $subject }
}

function Get-WorkspaceSnapshot([string]$Workspace) {
    # Every file of the workspace with its content hash, to assert that a command wrote nothing.
    $files = Get-ChildItem -LiteralPath $Workspace -Recurse -File -Force |
        Where-Object { $_.FullName -notlike '*\.git\*' } | Sort-Object FullName
    ($files | ForEach-Object { $_.FullName.Substring($Workspace.Length) + ' ' + (Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
}
