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

function Invoke-WithoutIdentity([scriptblock]$Run) {
    # Runs a script block as on a machine where git does not know who commits: no name and no
    # address in its settings or in the environment, and no guess from the name of the machine.
    $names = 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL', 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM'
    $saved = @{}
    foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
    $settings = Join-Path $TestRoot 'git-knows-nobody.gitconfig'
    [IO.File]::WriteAllText($settings, "[user]`n`tuseConfigOnly = true`n")
    try {
        foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $null) }
        $env:GIT_CONFIG_GLOBAL = $settings
        $env:GIT_CONFIG_NOSYSTEM = '1'
        & $Run
    }
    finally { foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) } }
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
    @{ op = 'create'; type = 'subject'; interpreted = $false; fields = $subject }
}

function New-RecordOperation([string]$Type, [hashtable]$Fields = @{}) {
    # One valid operation creating a commitment, a decision or a risk of Example Bank, attached to
    # the subject New-SubjectOperation creates. $Fields works as in New-SubjectOperation.
    $record = @{
        title          = "Send the onboarding figures to the sponsor ($Type)"
        subject        = 'mobile-onboarding'
        date_of_fact   = '2026-03-02'
        evidence_level = 'fact'
        source         = @{ where = 'inbox/steering-notes.md'; read_on = '2026-03-03' }
    }
    if ($Type -eq 'decision') { $record.status = 'pending' }
    if ($Type -eq 'risk') { $record.severity = 'watch' }
    foreach ($name in $Fields.Keys) {
        if ($null -eq $Fields[$name]) { $record.Remove($name) } else { $record[$name] = $Fields[$name] }
    }
    @{ op = 'create'; type = $Type; interpreted = $false; fields = $record }
}

function New-UpdateOperation([string]$Id, [hashtable]$Fields) {
    # One valid operation updating a record of Example Bank: the fields to change, and the source
    # of the change.
    @{
        op = 'update'; id = $Id; interpreted = $false; fields = $Fields
        source = @{ where = 'inbox/call-with-the-tech-lead.md'; read_on = '2026-03-10' }
    }
}

function Set-CollectProposal([string]$Workspace, [string]$CollectedAt, [string[]]$Read, [string[]]$NotCovered = @()) {
    # Leaves the proposal of a collect that read these sources, and says it did not cover those.
    Set-Proposal $Workspace @{
        collected_at        = $CollectedAt
        sources_read        = @($Read | ForEach-Object { @{ source = $_; cutoff = $CollectedAt; items = 3 } })
        sources_not_covered = $NotCovered
    }
}

function Add-InboxNote([string]$Workspace, [string]$Name, [string]$Text = 'Steering committee of Example Bank: the tech lead presents the target journey on 16 March.') {
    # Drops a raw note in the inbox, as the PO would.
    [IO.File]::WriteAllText((Join-Path $Workspace "inbox\$Name"), $Text, $Utf8)
}

function New-TestWorkspaceWithWeek {
    # A workspace of Example Bank after two collects a week apart, as the weekly synthesis finds it.
    # It is built once per run, then copied for each test.
    #
    # Applied on 2026-03-03, with the notes and the mail read: three subjects, and the records
    # attached to them. Applied on 2026-03-10, with the notes read and the tracker not covered:
    # - C-2026-003 has its due date moved, and C-2026-005 is done;
    # - the decision D-2026-005 supersedes the commitment C-2026-001;
    # - the commitment C-2026-006 is recorded;
    # - the risk R-2026-003 is closed;
    # - the risk R-2026-004 moves from the subject paper-statements to mobile-onboarding;
    # - the subject paper-statements is closed, with the commitment C-2026-004 still attached to it.
    # The settings list the objectives 1, 3 and 5. The mail is read from a folder, and the tracker
    # is off.
    $week = Join-Path $TestRoot 'week'
    if (-not (Test-Path $week)) {
        $built = New-TestWorkspace
        $connections = Read-Json (Join-Path $built 'connections.json')
        $connections.mail = @{ mode = 'folder'; folder = 'exports\mail' }
        Write-Json (Join-Path $built 'connections.json') $connections
        $settings = Read-Json (Join-Path $built 'settings.json')
        $settings.objectives = @(
            @{ number = 1; title = 'Halve the time to open an account' },
            @{ number = 3; title = 'Bring the branch network on board' },
            @{ number = 5; title = 'Retire the paper statements' }
        )
        Write-Json (Join-Path $built 'settings.json') $settings

        Set-Proposal $built @{
            collected_at = '2026-03-03T08:30:00+01:00'
            sources_read = @(
                @{ source = 'notes'; cutoff = '2026-03-03T08:12:00+01:00'; items = 4 },
                @{ source = 'mail'; cutoff = '2026-03-03T08:20:00+01:00'; items = 14 }
            )
            operations   = @(
                (New-SubjectOperation @{ clearance = 'cleared'; cleared_by = 'the sponsor'; cleared_on = '2026-02-20'; objectives = @(1) }),
                (New-SubjectOperation @{ title = 'Branch kiosks pilot'; horizon = 'next'; clearance = 'out of frame'; evidence_level = 'reported' }),
                (New-SubjectOperation @{ title = 'Paper statements'; horizon = 'later' }),
                (New-RecordOperation commitment @{ title = 'Present the onboarding pilot to the retail steering committee'; subject = 'line 1'; owner = 'the PO'; due_date = '2026-03-20'; objectives = @(1) }),
                (New-RecordOperation commitment @{ title = 'Send the onboarding figures to the sponsor'; subject = 'line 1'; evidence_level = 'reported' }),
                (New-RecordOperation commitment @{ title = 'Order the kiosks'; subject = 'line 2'; owner = 'the tech lead'; due_date = '2026-04-02'; objectives = @(1, 3) }),
                (New-RecordOperation commitment @{ title = 'Archive the paper statement templates'; subject = 'line 3'; owner = 'the PO'; objectives = @(5) }),
                (New-RecordOperation commitment @{ title = 'Book the committee room'; subject = 'line 1'; owner = 'the PO'; due_date = '2026-03-06' }),
                (New-RecordOperation decision @{ title = 'Choose the pilot branches'; subject = 'line 1'; needed_from = 'the sponsor'; needed_by = '2026-03-27' }),
                (New-RecordOperation decision @{ title = 'Fund the kiosk maintenance'; subject = 'line 2'; needed_from = 'the tech lead' }),
                (New-RecordOperation decision @{ title = 'Name the kiosk supplier'; subject = 'line 2'; needed_from = 'The sponsor' }),
                (New-RecordOperation decision @{ title = 'Keep or drop the paper option at onboarding'; subject = 'line 1'; needed_by = '2026-04-30' }),
                (New-RecordOperation risk @{ title = 'The pilot branches are not staffed'; subject = 'line 1'; evidence_level = 'hypothesis' }),
                (New-RecordOperation risk @{ title = 'The kiosk supplier may withdraw'; subject = 'line 2'; severity = 'urgent'; owner = 'the tech lead' }),
                (New-RecordOperation risk @{ title = 'The print contract renews in June'; subject = 'line 2'; objectives = @(3) }),
                (New-RecordOperation risk @{ title = 'Customers keep asking for paper'; subject = 'line 3' })
            )
        }
        $run = Invoke-Register $built apply -Today 2026-03-03
        Assert-Equal 0 $run.ExitCode "exit code of the first apply of the week, with output: $($run.Output)"

        Set-Proposal $built @{
            collected_at        = '2026-03-10T08:30:00+01:00'
            sources_read        = @(@{ source = 'notes'; cutoff = '2026-03-10T08:12:00+01:00'; items = 2 })
            sources_not_covered = @('tracker')
            operations          = @(
                (New-UpdateOperation 'C-2026-003' @{ due_date = '2026-04-16' }),
                (New-UpdateOperation 'C-2026-005' @{ status = 'done' }),
                (New-RecordOperation decision @{ title = 'Suspend the presentation of the pilot'; status = 'taken'; decided_by = 'the sponsor'; date_of_fact = '2026-03-09'; supersedes = 'C-2026-001'; objectives = @(1) }),
                (New-RecordOperation commitment @{ title = 'Brief the branch managers'; subject = 'branch-kiosks-pilot'; owner = 'the PO'; due_date = '2026-03-24'; date_of_fact = '2026-03-09' }),
                (New-UpdateOperation 'R-2026-003' @{ status = 'closed' }),
                (New-UpdateOperation 'R-2026-004' @{ subject = 'mobile-onboarding' }),
                (New-UpdateOperation 'paper-statements' @{ status = 'closed' })
            )
        }
        $run = Invoke-Register $built apply -Today 2026-03-10
        Assert-Equal 0 $run.ExitCode "exit code of the second apply of the week, with output: $($run.Output)"
        Move-Item $built $week
    }
    $workspace = Join-Path $TestRoot ([Guid]::NewGuid().ToString('N').Substring(0, 8))
    Copy-Item $week $workspace -Recurse -Force
    $workspace
}

function New-TestWorkspaceWithSubject {
    # A workspace whose register holds one subject: mobile-onboarding.
    $workspace = New-TestWorkspace
    Set-Proposal $workspace @{ operations = @(New-SubjectOperation) }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the subject, with output: $($run.Output)"
    $workspace
}

function Assert-Refused([string]$Workspace, [string[]]$Reasons) {
    # The pending proposal must be refused by preview and by apply: every reason given (as a
    # pattern), one reason per problem, a failure exit code and no file written.
    $before = Get-WorkspaceSnapshot $Workspace
    foreach ($command in 'preview', 'apply') {
        $run = Invoke-Register $Workspace $command
        Assert-Equal 1 $run.ExitCode "exit code of $command, with output: $($run.Output)"
        foreach ($reason in $Reasons) { Assert-Match $run.Output $reason "reason given by $command" }
        Assert-Equal $Reasons.Count @($run.Output -split "`n" | Where-Object { $_ -like '- *' }).Count "number of reasons given by $command, with output: $($run.Output)"
        Assert-Equal $before (Get-WorkspaceSnapshot $Workspace) "files of the workspace after $command"
    }
}

function Get-WorkspaceSnapshot([string]$Workspace) {
    # Every file of the workspace with its content hash, to assert that a command wrote nothing.
    $files = Get-ChildItem -LiteralPath $Workspace -Recurse -File -Force |
        Where-Object { $_.FullName -notlike '*\.git\*' } | Sort-Object FullName
    ($files | ForEach-Object { $_.FullName.Substring($Workspace.Length) + ' ' + (Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
}
