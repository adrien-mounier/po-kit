# One command installs or updates the kit without touching data.
#
# Every test installs into temporary folders, given explicitly: the installer has no default
# location, so a test cannot reach the machine's real skills folder or a real workspace.

# The installer commits as whoever git knows on the machine. A test machine may know nobody.
$env:GIT_AUTHOR_NAME = $env:GIT_COMMITTER_NAME = 'PO Kit tests'
$env:GIT_AUTHOR_EMAIL = $env:GIT_COMMITTER_EMAIL = 'tests@example.com'

function New-InstallTarget {
    # Where a test installs: a workspace location and a skills folder, neither created yet.
    # The spaces are deliberate: the PO's own folders often hold one.
    $root = Join-Path $TestRoot ('install ' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    @{ Workspace = Join-Path $root 'Example Bank workspace'; Skills = Join-Path $root 'agent skills' }
}

function New-TestKit {
    # A clone of the kit as a machine holds it: what the installer needs, under version control.
    # A test changes it at will, and saves it as a version before installing from it.
    $kit = Join-Path $TestRoot ('kit-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $kit -Force | Out-Null
    foreach ($part in 'install.ps1', 'workspace-template', 'routines') { Copy-Item (Join-Path $KitRoot $part) $kit -Recurse }
    git -C $kit init -q
    git -C $kit config core.autocrlf false
    $kit
}

function Save-TestKit([string]$Kit, [string]$Version) {
    # Commits the kit as it stands and tags it with its version.
    git -C $Kit add -A
    git -C $Kit commit -q --allow-empty -m "Version $Version"
    git -C $Kit tag $Version
}

function Set-TestFile([string]$Path, [string]$Text) {
    # Writes a file as UTF-8 without a byte order mark, creating its folder.
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Text, $Utf8)
}

function Invoke-Install([string]$Kit) {
    # Runs the installer of a kit once: Invoke-Install $kit -Workspace $folder -SkillsFolder $folder
    # Returns its output (standard output and errors together) and its exit code.
    $ErrorActionPreference = 'Continue'
    $lines = & powershell.exe -NoProfile -File (Join-Path $Kit 'install.ps1') @args 2>&1 | ForEach-Object { "$_" }
    @{ Output = ($lines -join "`n"); ExitCode = $LASTEXITCODE }
}

function Get-ToolsSnapshot([string]$Folder) {
    # The register tool and the record definitions under a folder, without the recorded kit version.
    (@((Get-WorkspaceSnapshot $Folder) -split "`n") -notlike '\kit-version.txt *') -join "`n"
}

function Get-DataSnapshot([string]$Workspace) {
    # Every file of the workspace that the kit does not own, with its content hash.
    (@((Get-WorkspaceSnapshot $Workspace) -split "`n") -notmatch '^\\(tools\\|AGENTS\.md |CLAUDE\.md )') -join "`n"
}

function New-UpdatedWorkspace {
    # The story of an update: version 1 of the kit is installed, the workspace fills up over weeks
    # of use, the kit moves to version 2, and the installer is run again.
    $kit = New-TestKit
    Set-TestFile (Join-Path $kit 'workspace-template\tools\commands\retired.ps1') "# retired: a command that version 2 drops.`n"
    Set-TestFile (Join-Path $kit 'routines\collect\SKILL.md') "# Collect, version 1`n"
    Set-TestFile (Join-Path $kit 'routines\collect\reference\retired.md') "A reference that version 2 drops.`n"
    Save-TestKit $kit 'v1'
    $to = New-InstallTarget
    $ws = $to.Workspace
    $first = Invoke-Install $kit -Workspace $ws -SkillsFolder $to.Skills
    if ($first.ExitCode -ne 0) { throw "version 1 did not install: $($first.Output)" }

    # Saved in the history of the workspace, as the register tool saves what it writes.
    $steering = "Comit$([char]0xE9) de pilotage"
    Set-TestFile (Join-Path $ws 'register\subjects\mobile-onboarding.json') "{`r`n  `"id`": `"mobile-onboarding`",`r`n  `"title`": `"Mobile onboarding`"`r`n}`r`n"
    Set-TestFile (Join-Path $ws 'register\commitments\2026\2026-001.json') "{ `"id`": `"2026-001`", `"title`": `"Present the demo to the $steering`" }`n"
    Set-TestFile (Join-Path $ws 'inbox\done\2026-02\2026-02-27 tech lead.md') "The tech lead will present the demo.`n"
    Set-TestFile (Join-Path $ws 'views\portfolio.md') "# Portfolio view`r`n"
    Set-TestFile (Join-Path $ws 'views\check-report.md') "# Check report`n"
    Set-TestFile (Join-Path $ws 'views\weekly\2026-03-02.md') "# Weekly synthesis`n"
    Set-TestFile (Join-Path $ws 'state\last-collect.json') "{ `"notes`": `"2026-03-02T08:00:00+01:00`" }`n"
    Set-TestFile (Join-Path $ws 'state\unclassified.md') "- A mail about the opening hours of a branch.`n"
    git -C $ws add -A
    git -C $ws commit -q -m 'Apply proposal: 2 operation(s)'

    # Not saved yet: a note to collect, a pending proposal, and what the PO edited by hand.
    Set-TestFile (Join-Path $ws "inbox\2026-03-03 $steering.md") "The sponsor wants the demo moved to April.`r`n"
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.gates = @('architecture review')
    $settings.sponsor.name = 'The sponsor'
    Write-Json (Join-Path $ws 'settings.json') $settings
    $connections = Read-Json (Join-Path $ws 'connections.json')
    $connections.mail = @{ mode = 'folder'; folder = 'mail-export' }
    Write-Json (Join-Path $ws 'connections.json') $connections

    # Version 2 of the kit changes the register tool, the rules, the routines and a default setting.
    $template = Join-Path $kit 'workspace-template'
    [IO.File]::AppendAllText((Join-Path $template 'tools\register.ps1'), "# Changed by version 2.`r`n")
    Set-TestFile (Join-Path $template 'tools\commands\added.ps1') "# added: a command that version 2 brings.`n"
    Remove-Item (Join-Path $template 'tools\commands\retired.ps1')
    [IO.File]::AppendAllText((Join-Path $template 'AGENTS.md'), "`nA rule added by version 2.`n")
    $defaults = Read-Json (Join-Path $template 'settings.json')
    $defaults.per_source_cap = 80
    Write-Json (Join-Path $template 'settings.json') $defaults
    Set-TestFile (Join-Path $kit 'routines\collect\SKILL.md') "# Collect, version 2`n"
    Remove-Item (Join-Path $kit 'routines\collect\reference') -Recurse
    Set-TestFile (Join-Path $kit 'routines\weekly-synthesis\SKILL.md') "# Weekly synthesis`n"
    Save-TestKit $kit 'v2'

    $story = @{
        Kit = $kit; Workspace = $ws; Skills = $to.Skills
        DataBefore = Get-DataSnapshot $ws; StatusBefore = "$(git -C $ws status --porcelain)"
    }
    $story.Run = Invoke-Install $kit -Workspace $ws -SkillsFolder $to.Skills
    $story
}

Test 'one command creates a workspace with the full layout, under version control, with a first commit' {
    $to = New-InstallTarget

    $run = Invoke-Install $KitRoot -Workspace $to.Workspace -SkillsFolder $to.Skills

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($folder in 'inbox\done', 'register\subjects', 'register\commitments', 'register\decisions', 'register\risks',
        'views\weekly', 'state', 'tools') {
        Assert-True (Test-Path (Join-Path $to.Workspace $folder) -PathType Container) "the workspace lacks the folder $folder"
    }
    foreach ($file in 'AGENTS.md', 'settings.json', 'connections.json', 'tools\register.ps1') {
        Assert-True (Test-Path (Join-Path $to.Workspace $file) -PathType Leaf) "the workspace lacks the file $file"
    }
    Assert-True (Test-Path (Join-Path $to.Workspace '.git')) 'the workspace is not under version control'
    Assert-Equal 1 @(git -C $to.Workspace log --format=%H).Count 'commits of a new workspace'
    Assert-Equal '' "$(git -C $to.Workspace status --porcelain)" 'files left out of the first commit'
    Assert-Match $run.Output 'The register tool runs on this machine' 'what the installer says of its last step'
}

Test 'the workspace rules come from the kit and state the five rules and how to call the register tool; the companion file imports them' {
    $to = New-InstallTarget

    $run = Invoke-Install $KitRoot -Workspace $to.Workspace -SkillsFolder $to.Skills

    $installed = Join-Path $to.Workspace 'AGENTS.md'
    Assert-Equal (Get-FileHash (Join-Path $KitRoot 'workspace-template\AGENTS.md')).Hash (Get-FileHash $installed).Hash "the rules file against the kit's"
    $rules = Get-Content -LiteralPath $installed -Raw -Encoding UTF8
    Assert-Match $rules 'only writer of `register/` and `views/`' 'rule: the register tool alone writes the register and the views'
    Assert-Match $rules 'updated, superseded or closed, never deleted' 'rule: records are never deleted'
    Assert-Match $rules 'send nothing and modify nothing' 'rule: nothing is sent, no source is modified'
    Assert-Match $rules 'mail draft is the only' 'rule: mail drafts are the only write outside the workspace'
    Assert-Match $rules 'performance or career' "rule: no notes about people's performance or career"
    Assert-Match $rules '`reported`' 'rule: a stated position is reported'
    Assert-Match $rules '`hypothesis`' 'rule: a reading of motives is a hypothesis'
    Assert-Match $rules 'powershell -NoProfile -File tools\\register\.ps1 <command>' 'how to call the register tool'

    $companion = Get-Content -LiteralPath (Join-Path $to.Workspace 'CLAUDE.md') -Raw -Encoding UTF8
    Assert-Equal '@AGENTS.md' $companion.Trim() 'companion file'
}

Test 'the register tool and the record definitions are copied into the workspace, which records the kit version' {
    $kit = New-TestKit
    Save-TestKit $kit 'v1'
    $to = New-InstallTarget

    $run = Invoke-Install $kit -Workspace $to.Workspace -SkillsFolder $to.Skills

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $tools = Join-Path $to.Workspace 'tools'
    Assert-Equal (Get-ToolsSnapshot (Join-Path $kit 'workspace-template\tools')) (Get-ToolsSnapshot $tools) 'files under tools'
    Assert-True (Test-Path (Join-Path $tools 'definitions\subject.json')) 'the record definition of a subject is missing'
    $version = [IO.File]::ReadAllBytes((Join-Path $tools 'kit-version.txt'))
    Assert-Equal 'v1' $Utf8.GetString($version).Trim() 'kit version recorded'
    Assert-True ($version[0] -ne 0xEF) 'the recorded version starts with a byte order mark'
    Assert-Match "$(git -C $to.Workspace log -1 --format=%s)" 'v1' 'first commit'

    Set-Proposal $to.Workspace @{ operations = @(New-SubjectOperation) }
    $preview = Invoke-Register $to.Workspace preview
    Assert-Equal 0 $preview.ExitCode "exit code of the installed register tool, with output: $($preview.Output)"
    Assert-Match $preview.Output 'Mobile onboarding' 'preview by the installed register tool'
}

Test 'every routine of the kit is copied into the skills folder given, beside the skills already there' {
    $kit = New-TestKit
    foreach ($routine in 'collect', 'weekly-synthesis') {
        Set-TestFile (Join-Path $kit "routines\$routine\SKILL.md") "# $routine`n"
        Set-TestFile (Join-Path $kit "routines\$routine\reference\blocks.md") "Reference of $routine.`n"
    }
    Save-TestKit $kit 'v1'
    $to = New-InstallTarget
    $own = Join-Path $to.Skills 'a-skill-of-the-po'
    Set-TestFile (Join-Path $own 'SKILL.md') "# Mine`n"
    $before = Get-WorkspaceSnapshot $own

    $run = Invoke-Install $kit -Workspace $to.Workspace -SkillsFolder $to.Skills

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    # The two routines of this test, and those the kit already ships.
    $routines = @(Get-ChildItem (Join-Path $kit 'routines') -Directory | ForEach-Object { $_.Name })
    Assert-True ($routines -contains 'collect' -and $routines -contains 'weekly-synthesis') "the kit of this test lacks its routines: $routines"
    foreach ($routine in $routines) {
        Assert-True (Test-Path (Join-Path $to.Skills $routine)) "the routine $routine was not copied"
        Assert-Equal (Get-WorkspaceSnapshot (Join-Path $kit "routines\$routine")) (Get-WorkspaceSnapshot (Join-Path $to.Skills $routine)) "files of the routine $routine"
    }
    Assert-Equal $before (Get-WorkspaceSnapshot $own) "the PO's own skill"
    Assert-Equal ((@('a-skill-of-the-po') + $routines | Sort-Object) -join ' ') ((Get-ChildItem $to.Skills -Force | Sort-Object Name | ForEach-Object { $_.Name }) -join ' ') 'content of the skills folder'
}

Test 'an update leaves records, inbox notes, views, state, settings and connections byte-identical, and replaces the kit-owned files' {
    $story = New-UpdatedWorkspace

    Assert-Equal 0 $story.Run.ExitCode "exit code, with output: $($story.Run.Output)"
    foreach ($file in 'register\subjects\mobile-onboarding.json', 'register\commitments\2026\2026-001.json', 'inbox\2026-03-03',
        'inbox\done\2026-02\2026-02-27', 'views\portfolio.md', 'views\weekly\2026-03-02.md', 'state\proposal.json',
        'state\last-collect.json', 'settings.json', 'connections.json') {
        Assert-Match $story.DataBefore ([regex]::Escape("\$file")) 'files compared before and after the update'
    }
    Assert-Equal $story.DataBefore (Get-DataSnapshot $story.Workspace) 'files the kit does not own'

    $template = Join-Path $story.Kit 'workspace-template'
    Assert-Equal (Get-ToolsSnapshot (Join-Path $template 'tools')) (Get-ToolsSnapshot (Join-Path $story.Workspace 'tools')) 'files under tools'
    foreach ($file in 'AGENTS.md', 'CLAUDE.md') {
        Assert-Equal (Get-FileHash (Join-Path $template $file)).Hash (Get-FileHash (Join-Path $story.Workspace $file)).Hash "$file against the kit's"
    }
    Assert-Equal 'v2' (Get-Content -LiteralPath (Join-Path $story.Workspace 'tools\kit-version.txt') -Raw).Trim() 'kit version recorded'
    Assert-Equal (Get-WorkspaceSnapshot (Join-Path $story.Kit 'routines\collect')) (Get-WorkspaceSnapshot (Join-Path $story.Skills 'collect')) 'files of the routine collect'
    Assert-True (Test-Path (Join-Path $story.Skills 'weekly-synthesis\SKILL.md')) 'the routine that version 2 brings was not copied'
}

Test 'an update commits the kit-owned files it replaced, and nothing else' {
    $story = New-UpdatedWorkspace
    $ws = $story.Workspace

    Assert-Equal 'Install PO Kit v1 | Apply proposal: 2 operation(s) | Update PO Kit to v2' ((git -C $ws log --reverse --format=%s) -join ' | ') 'history of the workspace'
    $committed = @(git -C $ws show --name-only --format= HEAD | Where-Object { $_ })
    foreach ($file in 'AGENTS.md', 'tools/register.ps1', 'tools/commands/added.ps1', 'tools/commands/retired.ps1', 'tools/kit-version.txt') {
        Assert-True ($committed -contains $file) "the commit of the update lacks $file; it holds: $($committed -join ', ')"
    }
    Assert-Equal '' "$($committed -notmatch '^(tools/|AGENTS\.md$|CLAUDE\.md$)')" 'files the kit does not own in the commit of the update'
    Assert-Equal $story.StatusBefore "$(git -C $ws status --porcelain)" 'changes the PO has not saved yet'
}

Test 'run twice in a row, the second run changes nothing' {
    $kit = New-TestKit
    Set-TestFile (Join-Path $kit 'routines\collect\SKILL.md') "# Collect`n"
    Save-TestKit $kit 'v1'
    $to = New-InstallTarget
    $first = Invoke-Install $kit -Workspace $to.Workspace -SkillsFolder $to.Skills
    $workspace = Get-WorkspaceSnapshot $to.Workspace
    $skills = Get-WorkspaceSnapshot $to.Skills
    $commit = "$(git -C $to.Workspace rev-parse HEAD)"

    $second = Invoke-Install $kit -Workspace $to.Workspace -SkillsFolder $to.Skills

    Assert-Equal 0 $second.ExitCode "exit code, with output: $($second.Output)"
    Assert-Equal $workspace (Get-WorkspaceSnapshot $to.Workspace) 'files of the workspace'
    Assert-Equal $skills (Get-WorkspaceSnapshot $to.Skills) 'files of the skills folder'
    Assert-Equal $commit "$(git -C $to.Workspace rev-parse HEAD)" 'last commit of the workspace'
    Assert-Equal '' "$(git -C $to.Workspace status --porcelain)" 'changes left unsaved in the workspace'
}

Test 'a folder that holds files and is not a workspace is refused and left as it was; an empty folder becomes a workspace' {
    $to = New-InstallTarget
    Set-TestFile (Join-Path $to.Workspace 'holiday plans.txt') "Not a workspace.`n"
    $before = Get-WorkspaceSnapshot $to.Workspace

    $run = Invoke-Install $KitRoot -Workspace $to.Workspace -SkillsFolder $to.Skills

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'is not a workspace' 'reason given'
    Assert-Equal $before (Get-WorkspaceSnapshot $to.Workspace) 'files of the folder'
    Assert-True (-not (Test-Path (Join-Path $to.Workspace '.git'))) 'the folder was put under version control'
    Assert-True (-not (Test-Path $to.Skills)) 'a skills folder was created'

    Remove-Item (Join-Path $to.Workspace 'holiday plans.txt')

    $run = Invoke-Install $KitRoot -Workspace $to.Workspace -SkillsFolder $to.Skills

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 1 @(git -C $to.Workspace log --format=%H).Count 'commits of the new workspace'
}

Test 'a first installation that could not commit is completed by running the installer again' {
    $to = New-InstallTarget
    # git refuses to commit with a date it cannot read, as it does on a machine where it does not
    # know who is committing.
    $env:GIT_AUTHOR_DATE = 'not a date'
    try { $failed = Invoke-Install $KitRoot -Workspace $to.Workspace -SkillsFolder $to.Skills }
    finally { $env:GIT_AUTHOR_DATE = $null }
    Assert-Equal 1 $failed.ExitCode "exit code of the run that cannot commit, with output: $($failed.Output)"
    Assert-Match $failed.Output 'Run this installer again' 'what the PO is told'

    $run = Invoke-Install $KitRoot -Workspace $to.Workspace -SkillsFolder $to.Skills

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 1 @(git -C $to.Workspace log --format=%H).Count 'commits of the workspace'
    Assert-Equal '' "$(git -C $to.Workspace status --porcelain)" 'files left out of the first commit'
}

Test 'when the execution policy refuses the register tool, the installation stops and tells the PO to ask their IT team' {
    # A machine that runs its own scripts and refuses downloaded ones refuses a register tool
    # marked as downloaded: the one refusal a test can stage without touching the policy.
    $policies = Get-ExecutionPolicy -List
    $own = "$(($policies | Where-Object { $_.Scope -ne 'Process' -and $_.ExecutionPolicy -ne 'Undefined' } | Select-Object -First 1).ExecutionPolicy)"
    if ($own -ne 'RemoteSigned') {
        Write-Host "        not checked: the policy of this machine is '$own', which does not single out downloaded scripts"
        return
    }
    $kit = New-TestKit
    Set-Content -LiteralPath (Join-Path $kit 'workspace-template\tools\register.ps1') -Stream Zone.Identifier -Value '[ZoneTransfer]', 'ZoneId=3'
    Save-TestKit $kit 'v1'
    $to = New-InstallTarget

    # Started under a bypass, the installer still answers for the policy of the machine.
    $override = $env:PSExecutionPolicyPreference
    $env:PSExecutionPolicyPreference = 'Bypass'
    try { $run = Invoke-Install $kit -Workspace $to.Workspace -SkillsFolder $to.Skills }
    finally { $env:PSExecutionPolicyPreference = $override }

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'execution policy' 'reason given'
    Assert-Match $run.Output 'IT team' 'whom the PO is told to ask'
    Assert-Equal ($policies | Out-String) (Get-ExecutionPolicy -List | Out-String) 'execution policy of the machine'
}

Test 'a kit that is not a clone has no version to record: the installer says so and installs nothing' {
    $kit = New-TestKit
    Remove-Item (Join-Path $kit '.git') -Recurse -Force
    $to = New-InstallTarget

    $run = Invoke-Install $kit -Workspace $to.Workspace -SkillsFolder $to.Skills

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Install from a clone of the kit' 'reason given'
    Assert-True (-not (Test-Path $to.Workspace)) 'a workspace was created'
    Assert-True (-not (Test-Path $to.Skills)) 'a skills folder was created'
}

Test 'without both locations the installer explains itself and installs nothing' {
    $to = New-InstallTarget

    $run = Invoke-Install $KitRoot -Workspace $to.Workspace

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'install\.ps1 -Workspace <folder> -SkillsFolder <folder>' 'how to call the installer'
    Assert-True (-not (Test-Path $to.Workspace)) 'a workspace was created'

    $run = Invoke-Install $KitRoot -SkillsFolder $to.Skills

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-True (-not (Test-Path $to.Skills)) 'a skills folder was created'
}
