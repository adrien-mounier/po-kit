# Installs the PO Kit on this machine, or updates it. One command, run from a clone of the kit:
#
#   powershell -NoProfile -File install.ps1 -Workspace <folder> -SkillsFolder <folder>
#
#   -Workspace     where the PO's workspace lives. A new or empty folder becomes a workspace: the
#                  kit's template, under version control, with a first commit.
#   -SkillsFolder  the folder where the agent of this machine looks for its skills.
#
# Run again, it replaces what the kit owns with the kit's current version, and nothing else:
#   in the workspace       tools\, AGENTS.md and CLAUDE.md, committed together
#   in the skills folder   one folder per routine of the kit, named after it
# The register, the inbox, the views, the state, the settings and the connections are the PO's:
# an update never touches them. The workspace records the kit version in tools\kit-version.txt.
#
# The last step runs the installed register tool once, harmlessly. When the machine's execution
# policy refuses, the installation stops and the PO asks their IT team: the installer never
# changes or bypasses the policy.
#
# Keep this file in plain ASCII: Windows PowerShell 5.1 misreads other characters in a script
# saved without a byte order mark.
param([string]$Workspace, [string]$SkillsFolder)

$ErrorActionPreference = 'Stop'
$Kit = $PSScriptRoot
$Template = Join-Path $Kit 'workspace-template'
$KitOwned = 'tools', 'AGENTS.md', 'CLAUDE.md'

function Stop-Install([string[]]$Lines) {
    # Says why the installation cannot go on, and ends it with a failure code.
    $Lines | ForEach-Object { Write-Host $_ }
    exit 1
}

function Invoke-Git {
    # Runs git in the workspace, and stops the installation when git fails.
    & git -C $Workspace @args
    if ($LASTEXITCODE -ne 0) { Stop-Install "git $($args[0]) failed. Run this installer again once the cause above is fixed." }
}

function Copy-Replacing([string]$From, [string]$To) {
    # Puts a file or a folder of the kit in place of the one installed before. The old one goes
    # whole, so that a file the kit no longer ships does not linger.
    if (Test-Path -LiteralPath $To) { Remove-Item -LiteralPath $To -Recurse -Force }
    Copy-Item -LiteralPath $From -Destination $To -Recurse
}

if (-not $Workspace -or -not $SkillsFolder) {
    Stop-Install 'Give both locations:', '  powershell -NoProfile -File install.ps1 -Workspace <folder> -SkillsFolder <folder>'
}
# A location may be given relative to the current folder.
$Workspace = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Workspace)
$SkillsFolder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SkillsFolder)

# The kit version is the commit of this clone, or its tag when it has one.
$version = "$(& git -C $Kit describe --tags --always --dirty)"
if (-not $version) { Stop-Install 'Install from a clone of the kit made with git: its commit is the version the workspace records.' }

# --- The workspace ------------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Workspace) -or -not (Get-ChildItem -LiteralPath $Workspace -Force)) {
    New-Item -ItemType Directory -Path $Workspace -Force | Out-Null
    Get-ChildItem -LiteralPath $Template -Force | Copy-Item -Destination $Workspace -Recurse
    Invoke-Git init -q
    # The history keeps every file exactly as it was written.
    Invoke-Git config core.autocrlf false
}
elseif (-not (Test-Path -LiteralPath (Join-Path $Workspace '.git')) -or -not (Test-Path -LiteralPath (Join-Path $Workspace 'tools\register.ps1'))) {
    Stop-Install "$Workspace holds files and is not a workspace.", 'Give the location of a workspace to update it, or a new or empty folder to create one.'
}

foreach ($name in $KitOwned) { Copy-Replacing (Join-Path $Template $name) (Join-Path $Workspace $name) }
[IO.File]::WriteAllText((Join-Path $Workspace 'tools\kit-version.txt'), $version + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding $false))

# The first commit holds the whole new workspace. An update commits what the kit owns and only
# that, so the history shows which version of the register tool wrote which records.
$first = -not (& git -C $Workspace rev-parse -q --verify HEAD)
$paths = if ($first) { , '.' } else { $KitOwned }
Invoke-Git add -A -- $paths
& git -C $Workspace diff --cached --quiet -- $paths
if ($LASTEXITCODE -ne 0) {
    Invoke-Git commit -q -m $(if ($first) { "Install PO Kit $version" } else { "Update PO Kit to $version" }) -- $paths
}

# --- The routines -------------------------------------------------------------------------------
# A routine is a folder under routines; it becomes the skill of the same name.
# ponytail: a routine the kit no longer ships stays in the skills folder. Keep a list of what was
# installed if the kit ever retires a routine.

New-Item -ItemType Directory -Path $SkillsFolder -Force | Out-Null
$routines = @(Get-ChildItem -LiteralPath (Join-Path $Kit 'routines') -Directory)
foreach ($routine in $routines) { Copy-Replacing $routine.FullName (Join-Path $SkillsFolder $routine.Name) }

# --- The register tool must run here ------------------------------------------------------------

function Get-RegisterToolAnswer {
    # What the installed register tool answers to one harmless run: preview writes nothing.
    # The run meets the machine's own execution policy. An override handed to this installer is
    # set aside for it and put back after: the agent will not have that override, and the
    # installer neither changes nor bypasses the policy.
    $ErrorActionPreference = 'Continue'
    $override = $env:PSExecutionPolicyPreference
    $env:PSExecutionPolicyPreference = $null
    try { & powershell.exe -NoProfile -NonInteractive -File (Join-Path $Workspace 'tools\register.ps1') preview 2>&1 | Out-String }
    finally { $env:PSExecutionPolicyPreference = $override }
}

# Windows PowerShell points to this help topic when a policy keeps it from running a script. The
# name of the topic is not translated, and line wrapping may cut it.
if (((Get-RegisterToolAnswer) -replace '\s') -match 'about_Execution_Policies') {
    Stop-Install "The execution policy of this machine refuses to run the register tool:",
        "  $(Join-Path $Workspace 'tools\register.ps1')",
        'The kit cannot work here until that script is allowed to run. Ask your IT team to allow it,',
        'then run this installer again. The kit never changes or works around the policy.'
}

"PO Kit $version is installed."
"  Workspace: $Workspace"
"  Routines:  $($routines.Count), in $SkillsFolder"
'The register tool runs on this machine.'
