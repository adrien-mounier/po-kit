# The check: what is broken in the register and what has gone stale, in the check report.

function New-CheckedWorkspace([hashtable[]]$More = @()) {
    # A workspace of Example Bank in order, recorded on 2 March 2026 by a collect that read the
    # notes, the only source that is not off: the subject mobile-onboarding under Now and, attached
    # to it, the commitment C-2026-001, the decision D-2026-001 and the risk R-2026-001.
    # $More adds operations to that first proposal: a record attached to mobile-onboarding is
    # attached to the line that creates it.
    $workspace = New-TestWorkspace
    foreach ($operation in $More) { if ($operation.fields.subject -eq 'mobile-onboarding') { $operation.fields.subject = 'line 1' } }
    Set-Proposal $workspace @{
        collected_at = '2026-03-02T08:30:00+01:00'
        sources_read = @(@{ source = 'notes'; cutoff = '2026-03-02T08:30:00+01:00'; items = 1 })
        operations   = @(
            (New-SubjectOperation),
            (New-RecordOperation commitment @{ title = 'Present the onboarding pilot to the retail steering committee'; subject = 'line 1'; owner = 'the tech lead'; due_date = '2026-03-20' }),
            (New-RecordOperation decision @{ title = 'Open the pilot to ten branches'; subject = 'line 1'; status = 'taken'; decided_by = 'the sponsor' }),
            (New-RecordOperation risk @{ title = 'The pilot branches are not staffed'; subject = 'line 1' })
        ) + $More
    }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the records, with output: $($run.Output)"
    $workspace
}

function Read-CheckReport([string]$Workspace) {
    [IO.File]::ReadAllText((Join-Path $Workspace 'views\check-report.md'), $Utf8)
}

function Get-Listed([string]$Report, [string]$Heading) {
    # What a check report lists under a heading, given with its hashes: one line per item, without
    # its dash. Nothing when the heading is absent or lists nothing.
    $under = $false
    @(foreach ($line in $Report -split '\r?\n') {
            if ($line -like '#*') { $under = $line -ceq $Heading }
            elseif ($under -and $line -like '- *') { $line.Substring(2) }
        }) -join "`n"
}

Test 'check on a register in order writes the check report under its stamp, with no error and no warning, and succeeds' {
    $ws = New-CheckedWorkspace

    $run = Invoke-Register $ws check -Now 2026-03-03T09:15:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $state = "$(git -C $ws rev-parse HEAD:register)".Substring(0, 12)
    $expected = '# Check report', '', '> Generated: 2026-03-03T09:15:00+01:00.', "> Register state: $state.",
        '> Last collect: 2026-03-02T08:30:00+01:00.', '> Sources not covered by the last collect: mail, tracker.', '',
        '## Errors', '', 'No error.', '', '## Warnings', '', 'No warning.', ''
    Assert-Equal ($expected -join "`n") ((Read-CheckReport $ws) -replace '\r\n', "`n") 'check report'
    Assert-Match $run.Output '(?m)^Check: 0 error\(s\), 0 warning\(s\)\. Check report: views\\check-report\.md$' 'output'
    Assert-True ([IO.File]::ReadAllBytes((Join-Path $ws 'views\check-report.md'))[0] -ne 0xEF) 'the check report opens with a byte order mark'
}

function Save-OutsideEdit([string]$Workspace) {
    # Commits what a test changed in the register by hand. It is the only way to a broken register:
    # the register tool refuses to write one, and refuses to run on changes left uncommitted.
    git -C $Workspace add -A register
    git -C $Workspace commit -q -m 'Change the register outside the register tool'
}

function Edit-JsonFile([string]$Path, [scriptblock]$Change) {
    # Changes a JSON file by hand: $Change receives its content as $args[0].
    $content = Read-Json $Path
    & $Change $content
    Write-Json $Path $content
}

function Edit-Record([string]$Workspace, [string]$File, [scriptblock]$Change) {
    # Changes a record by hand, as Edit-JsonFile does, and commits it.
    Edit-JsonFile (Join-Path $Workspace "register\$File") $Change
    Save-OutsideEdit $Workspace
}

function Invoke-Check([string]$Workspace, [string]$Today = '2026-03-03') {
    # Runs the check on a day, and gives its exit code, its output and the check report it wrote.
    $run = Invoke-Register $Workspace check -Today $Today
    $run.Report = Read-CheckReport $Workspace
    $run
}

Test 'a record that cannot be read is an error naming its file, and the check ends with a failure code' {
    $ws = New-CheckedWorkspace
    [IO.File]::WriteAllText((Join-Path $ws 'register\risks\R-2026-001.json'), '{ "id": "R-2026-001", "title": ')
    [IO.File]::WriteAllText((Join-Path $ws 'register\decisions\2026\D-2026-001.json'), '"a text, not a record"')
    Save-OutsideEdit $ws

    $check = Invoke-Check $ws

    Assert-Equal 1 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal "Unreadable record: ``register/decisions/2026/D-2026-001.json```nUnreadable record: ``register/risks/R-2026-001.json``" (Get-Listed $check.Report '## Errors') 'errors'
    Assert-True ($check.Report -notmatch 'No error') 'the check report says there is no error'
    Assert-Match $check.Output '(?m)^Check: 2 error\(s\), 0 warning\(s\)\.' 'output'
}

Test 'an unknown field, a value outside the allowed ones and a missing required field are errors naming the record' {
    $ws = New-CheckedWorkspace
    Edit-Record $ws 'subjects\mobile-onboarding.json' { $args[0] | Add-Member colour 'blue' }
    Edit-Record $ws 'commitments\2026\C-2026-001.json' { $args[0].status = 'late'; $args[0].due_date = 'end of March' }
    Edit-Record $ws 'decisions\2026\D-2026-001.json' { $args[0].type = 'commitment'; $args[0].PSObject.Properties.Remove('date_updated') }
    Edit-Record $ws 'risks\R-2026-001.json' { $args[0].title = ''; $args[0].source.PSObject.Properties.Remove('read_on') }

    $check = Invoke-Check $ws

    Assert-Equal 1 $check.ExitCode "exit code, with output: $($check.Output)"
    $commitment = 'Present the onboarding pilot to the retail steering committee [C-2026-001]'
    $expected = "Unknown field or value: ${commitment}: field 'status' is 'late'; allowed: open, done, dropped, superseded",
        "Unknown field or value: ${commitment}: field 'due_date' must be an ISO date (yyyy-mm-dd), not 'end of March'",
        "Missing required field: Open the pilot to ten branches [D-2026-001]: missing required field 'date_updated'",
        "Unknown field or value: Open the pilot to ten branches [D-2026-001]: field 'type' is 'commitment'; allowed: decision",
        "Missing required field: [R-2026-001]: missing required field 'title'",
        "Missing required field: [R-2026-001]: missing required field 'source.read_on'",
        "Unknown field or value: Mobile onboarding [mobile-onboarding]: unknown field 'colour'"
    Assert-Equal ($expected -join "`n") (Get-Listed $check.Report '## Errors') 'errors'
}

Test 'an identifier that differs from the file name, and a reference to a record the register does not hold, are errors' {
    $ws = New-CheckedWorkspace
    Edit-Record $ws 'commitments\2026\C-2026-001.json' { $args[0].id = 'C-2026-007'; $args[0].subject = 'branch-kiosks-pilot' }
    Edit-Record $ws 'decisions\2026\D-2026-001.json' { $args[0].supersedes = 'D-2025-004'; $args[0].superseded_by = 'D-2026-009' }
    # A subject is the only record another one is attached to.
    Edit-Record $ws 'risks\R-2026-001.json' { $args[0].subject = 'D-2026-001' }

    $check = Invoke-Check $ws

    Assert-Equal 1 $check.ExitCode "exit code, with output: $($check.Output)"
    $commitment = 'Present the onboarding pilot to the retail steering committee [C-2026-001]'
    $expected = "Identifier differing from the file name: ``register/commitments/2026/C-2026-001.json``: 'C-2026-007'",
        "Reference to a missing record: ${commitment}: subject 'branch-kiosks-pilot'",
        "Reference to a missing record: Open the pilot to ten branches [D-2026-001]: supersedes 'D-2025-004'",
        "Reference to a missing record: Open the pilot to ten branches [D-2026-001]: superseded_by 'D-2026-009'",
        "Reference to a missing record: The pilot branches are not staffed [R-2026-001]: subject 'D-2026-001'"
    Assert-Equal ($expected -join "`n") (Get-Listed $check.Report '## Errors') 'errors'
}

Test 'a cleared subject without a name and a date, a subject under Now with a missing gate that is not out of frame, and a taken decision without its author are errors' {
    $ws = New-CheckedWorkspace @(
        (New-SubjectOperation @{ title = 'Card dispute handling' }),
        (New-SubjectOperation @{ title = 'Branch kiosks pilot' }),
        (New-SubjectOperation @{ title = 'Paper statements'; horizon = 'next' })
    )
    Edit-JsonFile (Join-Path $ws 'settings.json') { $args[0].gates = @('architecture review', 'security review') }
    $missing = @(@{ name = 'security review'; state = 'done' }, @{ name = 'architecture review'; state = 'missing' })
    Edit-Record $ws 'subjects\card-dispute-handling.json' { $args[0].clearance = 'cleared'; $args[0].cleared_by = 'the sponsor' }
    Edit-Record $ws 'subjects\mobile-onboarding.json' { $args[0].clearance = 'pending'; $args[0].gates = $missing }
    # Out of frame is what a subject with a missing gate must say, and the rule is about Now only.
    Edit-Record $ws 'subjects\branch-kiosks-pilot.json' { $args[0].clearance = 'out of frame'; $args[0].gates = $missing }
    Edit-Record $ws 'subjects\paper-statements.json' { $args[0].clearance = 'pending'; $args[0].gates = $missing }
    Edit-Record $ws 'decisions\2026\D-2026-001.json' { $args[0].decided_by = $null }

    $check = Invoke-Check $ws

    Assert-Equal 1 $check.ExitCode "exit code, with output: $($check.Output)"
    $expected = 'Taken decision without its author: Open the pilot to ten branches [D-2026-001]',
        'Cleared subject without a name and a date: Card dispute handling [card-dispute-handling]',
        'Subject under Now with a missing gate and a clearance other than out of frame: Mobile onboarding [mobile-onboarding]: architecture review'
    Assert-Equal ($expected -join "`n") (Get-Listed $check.Report '## Errors') 'errors'
}

function Get-Headings([string]$Report) {
    # The headings of a check report, in their order.
    @($Report -split '\r?\n' | Where-Object { $_ -like '#*' }) -join "`n"
}

Test 'an open commitment without owner or without due date is a warning under its rule, and the check succeeds with warnings only' {
    $ws = New-CheckedWorkspace @(
        (New-RecordOperation commitment @{ title = 'Send the pilot figures to the sponsor'; due_date = '2026-03-10' }),
        (New-RecordOperation commitment @{ title = 'Book the committee room'; owner = 'the PO' }),
        (New-RecordOperation commitment @{ title = 'Draft the target journey' })
    )

    $check = Invoke-Check $ws

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal "# Check report`n## Errors`n## Warnings`n### Open commitment without owner`n### Open commitment without due date" (Get-Headings $check.Report) 'headings of the check report'
    Assert-Equal "Send the pilot figures to the sponsor [C-2026-002] (due: 2026-03-10)`nDraft the target journey [C-2026-004]" (Get-Listed $check.Report '### Open commitment without owner') 'commitments without owner'
    Assert-Equal "Book the committee room [C-2026-003] (owner: the PO)`nDraft the target journey [C-2026-004]" (Get-Listed $check.Report '### Open commitment without due date') 'commitments without due date'
    Assert-True ($check.Report -match 'No error\.' -and $check.Report -notmatch 'No warning') 'the check report says there is an error, or no warning'
    Assert-Match $check.Output '(?m)^Check: 0 error\(s\), 4 warning\(s\)\.' 'output'
}

Test 'a commitment past its due date is listed as overdue with its owner and its due date, from the day after' {
    $ws = New-CheckedWorkspace @((New-RecordOperation commitment @{ title = 'Send the pilot figures to the sponsor'; due_date = '2026-03-10' }))

    $check = Invoke-Check $ws 2026-03-20

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal 'Send the pilot figures to the sponsor [C-2026-002] (due: 2026-03-10)' (Get-Listed $check.Report '### Overdue commitment') 'overdue commitments on the day the first one is due'

    $check = Invoke-Check $ws 2026-03-21

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal "Present the onboarding pilot to the retail steering committee [C-2026-001] (owner: the tech lead, due: 2026-03-20)`nSend the pilot figures to the sponsor [C-2026-002] (due: 2026-03-10)" (Get-Listed $check.Report '### Overdue commitment') 'overdue commitments the day after'
}

Test 'a pending decision is a warning once the date it is needed by has passed, with the person it is awaited from' {
    $ws = New-CheckedWorkspace @(
        (New-RecordOperation decision @{ title = 'Choose the pilot branches'; needed_from = 'the sponsor'; needed_by = '2026-03-10' }),
        (New-RecordOperation decision @{ title = 'Choose the pilot dates'; needed_from = 'the sponsor' })
    )
    $rule = '### Pending decision past its date'

    $check = Invoke-Check $ws 2026-03-10

    Assert-Equal '' (Get-Listed $check.Report $rule) 'decisions past their date on the day the decision is needed by'

    $check = Invoke-Check $ws 2026-03-11

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal 'Choose the pilot branches [D-2026-002] (needed from: the sponsor, needed by: 2026-03-10)' (Get-Listed $check.Report $rule) 'decisions past their date the day after'
}

Test 'a subject under Now that was not updated within the stale delay is a warning, until it is updated' {
    $ws = New-CheckedWorkspace @((New-SubjectOperation @{ title = 'Paper statements'; horizon = 'next' }))
    $rule = '### Subject under Now not updated for more than 7 day(s)'

    $check = Invoke-Check $ws 2026-03-09

    Assert-Equal '' (Get-Listed $check.Report $rule) 'stale subjects seven days after the last update'

    $check = Invoke-Check $ws 2026-03-10

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal 'Mobile onboarding [mobile-onboarding] (last updated: 2026-03-02)' (Get-Listed $check.Report $rule) 'stale subjects eight days after the last update'

    Set-Proposal $ws @{ operations = @(New-UpdateOperation 'mobile-onboarding' @{ next_step = 'Present the target journey to the committee' }) }
    $applied = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $applied.ExitCode "exit code of apply, with output: $($applied.Output)"

    $check = Invoke-Check $ws 2026-03-10

    Assert-Equal '' (Get-Listed $check.Report $rule) 'stale subjects once the subject is updated'
}

Test 'records that are done, dropped, closed or superseded raise no staleness warning' {
    $ws = New-CheckedWorkspace @(
        (New-RecordOperation commitment @{ title = 'Send the pilot figures to the sponsor'; due_date = '2026-03-10' }),
        (New-RecordOperation commitment @{ title = 'Book the committee room' }),
        (New-RecordOperation commitment @{ title = 'Draft the target journey'; due_date = '2026-03-10' }),
        (New-RecordOperation decision @{ title = 'Choose the pilot branches'; needed_from = 'the sponsor'; needed_by = '2026-03-10' })
    )
    $source = '### Source not read for more than 3 day(s)'
    $check = Invoke-Check $ws 2026-04-30
    Assert-Equal ("# Check report`n## Errors`n## Warnings`n### Open commitment without owner`n### Open commitment without due date`n### Overdue commitment`n" +
        "### Pending decision past its date`n### Subject under Now not updated for more than 7 day(s)`n$source") (Get-Headings $check.Report) 'headings while the records are in play'

    Set-Proposal $ws @{ operations = @(
            (New-UpdateOperation 'C-2026-001' @{ status = 'done' }),
            (New-UpdateOperation 'C-2026-002' @{ status = 'done' }),
            (New-UpdateOperation 'C-2026-003' @{ status = 'dropped' }),
            (New-RecordOperation commitment @{ title = 'Draft the target journey with the tech lead'; owner = 'the tech lead'; due_date = '2026-12-31'; supersedes = 'C-2026-004' }),
            (New-RecordOperation decision @{ title = 'The pilot runs in ten branches'; status = 'taken'; decided_by = 'the sponsor'; supersedes = 'D-2026-002' }),
            (New-UpdateOperation 'mobile-onboarding' @{ status = 'closed' })
        )
    }
    $applied = Invoke-Register $ws apply -Today 2026-04-30
    Assert-Equal 0 $applied.ExitCode "exit code of apply, with output: $($applied.Output)"

    $check = Invoke-Check $ws 2026-05-30

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal "# Check report`n## Errors`n## Warnings`n$source" (Get-Headings $check.Report) 'headings once the records are done, dropped, closed or superseded'
}

Test 'a source that is not off and was never read is a warning, and a source set to off raises none' {
    # The connections of a new workspace read the notes from the inbox and set mail and tracker to off.
    $ws = New-TestWorkspaceWithSubject

    $check = Invoke-Check $ws

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal 'notes (never read)' (Get-Listed $check.Report '### Source not read for more than 3 day(s)') 'sources not read'
}

Test 'a source is a warning when the last collect that read it is older than the source delay, unless the source is set to off' {
    $ws = New-TestWorkspaceWithSubject
    $connections = Join-Path $ws 'connections.json'
    Edit-JsonFile $connections { $args[0].mail = @{ mode = 'folder'; folder = 'mail-export' } }
    Set-CollectProposal $ws '2026-03-02T08:30:00+01:00' 'notes', 'mail'
    $first = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $first.ExitCode "exit code of the first collect, with output: $($first.Output)"
    Set-CollectProposal $ws '2026-03-04T08:30:00+01:00' 'mail' 'notes'
    $second = Invoke-Register $ws apply -Today 2026-03-04
    Assert-Equal 0 $second.ExitCode "exit code of the second collect, with output: $($second.Output)"
    $rule = '### Source not read for more than 3 day(s)'

    $check = Invoke-Check $ws 2026-03-05

    Assert-Equal '' (Get-Listed $check.Report $rule) 'sources not read three days after the notes were read'

    $check = Invoke-Check $ws 2026-03-06

    Assert-Equal 'notes (last read: 2026-03-02T08:30:00+01:00)' (Get-Listed $check.Report $rule) 'sources not read four days after the notes were read'

    $check = Invoke-Check $ws 2026-03-08

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal "notes (last read: 2026-03-02T08:30:00+01:00)`nmail (last read: 2026-03-04T08:30:00+01:00)" (Get-Listed $check.Report $rule) 'sources not read four days after the mail was read'

    Edit-JsonFile $connections { $args[0].mail = @{ mode = 'off' } }

    $check = Invoke-Check $ws 2026-03-08

    Assert-Equal 'notes (last read: 2026-03-02T08:30:00+01:00)' (Get-Listed $check.Report $rule) 'sources not read once the mail is set to off'
}

function Add-DatedNote([string]$Workspace, [string]$Name, [string]$Date) {
    # Drops a note in the inbox, as the PO did on that day.
    Add-InboxNote $Workspace $Name
    (Get-Item -LiteralPath (Join-Path $Workspace "inbox\$Name")).LastWriteTime = [DateTime]"${Date}T18:00:00"
}

Test 'a note left in the inbox for longer than the inbox delay is a warning, and a note already filed is not' {
    $ws = New-CheckedWorkspace
    Add-DatedNote $ws 'steering committee.md' 2026-03-01
    Add-DatedNote $ws 'call with the tech lead.md' 2026-03-02
    New-Item -ItemType Directory -Path (Join-Path $ws 'inbox\done\2026-02') | Out-Null
    Add-DatedNote $ws 'done\2026-02\kick-off.md' 2026-02-10
    $rule = '### Inbox note older than 2 day(s)'

    $check = Invoke-Check $ws 2026-03-03

    Assert-Equal '' (Get-Listed $check.Report $rule) 'old notes two days after the first note'

    $check = Invoke-Check $ws 2026-03-04

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal 'steering committee.md (dated 2026-03-01)' (Get-Listed $check.Report $rule) 'old notes three days after the first note'

    $check = Invoke-Check $ws 2026-03-05

    Assert-Equal "call with the tech lead.md (dated 2026-03-02)`nsteering committee.md (dated 2026-03-01)" (Get-Listed $check.Report $rule) 'old notes three days after the second note'
}

Test 'an unclassified item collected more than a week ago is a warning, until the PO takes it off the list' {
    $ws = New-CheckedWorkspace
    foreach ($day in '03', '05') {
        Set-Proposal $ws @{ collected_at = "2026-03-${day}T08:30:00+01:00"
            unclassified = @(@{ source = "mail from the tech lead, 2026-03-$day"; text = "Who owns the branch kiosks pilot? (asked on the $day)" })
        }
        $collect = Invoke-Register $ws apply -Today "2026-03-$day"
        Assert-Equal 0 $collect.ExitCode "exit code of the collect of the $day, with output: $($collect.Output)"
    }
    $list = Join-Path $ws 'state\unclassified.md'
    [IO.File]::AppendAllText($list, "- to sort with the sponsor, no date`n", $Utf8)
    $rule = '### Unclassified items older than 7 day(s)'
    $first, $second = '03', '05' | ForEach-Object { "2026-03-$_ | mail from the tech lead, 2026-03-$_ | Who owns the branch kiosks pilot? (asked on the $_)" }

    $check = Invoke-Check $ws 2026-03-10

    Assert-Equal '' (Get-Listed $check.Report $rule) 'old unclassified items seven days after the first one'

    $check = Invoke-Check $ws 2026-03-11

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Equal $first (Get-Listed $check.Report $rule) 'old unclassified items eight days after the first one'

    $check = Invoke-Check $ws 2026-03-13

    Assert-Equal "$first`n$second" (Get-Listed $check.Report $rule) 'old unclassified items eight days after the second one'

    [IO.File]::WriteAllLines($list, @([IO.File]::ReadAllLines($list, $Utf8) | Where-Object { $_ -notlike '*asked on the 03*' }), $Utf8)

    $check = Invoke-Check $ws 2026-03-13

    Assert-Equal $second (Get-Listed $check.Report $rule) 'old unclassified items once the PO sorted the first one'
}

Test 'the three delays are read from the settings: changing one changes the verdict' {
    $ws = New-CheckedWorkspace
    Add-DatedNote $ws 'steering committee.md' 2026-03-03
    $settings = Join-Path $ws 'settings.json'

    # On 5 March the subject was updated and the notes were read three days ago, and the note is two days old.
    $check = Invoke-Check $ws 2026-03-05

    Assert-Equal "# Check report`n## Errors`n## Warnings" (Get-Headings $check.Report) 'headings with the default delays'

    Edit-JsonFile $settings { $args[0].delays_in_days.subject = 2 }
    $check = Invoke-Check $ws 2026-03-05

    Assert-Equal "# Check report`n## Errors`n## Warnings`n### Subject under Now not updated for more than 2 day(s)" (Get-Headings $check.Report) 'headings with a shorter delay for subjects'

    Edit-JsonFile $settings { $args[0].delays_in_days.inbox_note = 1 }
    $check = Invoke-Check $ws 2026-03-05

    Assert-Equal 'steering committee.md (dated 2026-03-03)' (Get-Listed $check.Report '### Inbox note older than 1 day(s)') 'old notes with a shorter delay for inbox notes'

    Edit-JsonFile $settings { $args[0].delays_in_days.source = 2 }
    $check = Invoke-Check $ws 2026-03-05

    Assert-Equal 'notes (last read: 2026-03-02T08:30:00+01:00)' (Get-Listed $check.Report '### Source not read for more than 2 day(s)') 'sources not read with a shorter delay for sources'

    Edit-JsonFile $settings { $args[0].delays_in_days.subject = 30 }
    $check = Invoke-Check $ws 2026-03-05

    Assert-Equal "# Check report`n## Errors`n## Warnings`n### Inbox note older than 1 day(s)`n### Source not read for more than 2 day(s)" (Get-Headings $check.Report) 'headings with a longer delay for subjects'
}

Test 'a register whose records were corrected, superseded and closed by the register tool is in order' {
    $ws = New-CheckedWorkspace
    Set-Proposal $ws @{ operations = @(
            (New-UpdateOperation 'C-2026-001' @{ owner = 'the PO' }),
            (New-UpdateOperation 'mobile-onboarding' @{ links = @('https://example.com/pilot'); next_date_confirmed = $true }),
            (New-RecordOperation decision @{ title = 'Open the pilot to twenty branches'; status = 'taken'; decided_by = 'the sponsor'; supersedes = 'D-2026-001' }),
            (New-UpdateOperation 'R-2026-001' @{ status = 'closed' })
        )
    }
    $applied = Invoke-Register $ws apply -Today 2026-03-03
    Assert-Equal 0 $applied.ExitCode "exit code of apply, with output: $($applied.Output)"

    $check = Invoke-Check $ws

    Assert-Equal 0 $check.ExitCode "exit code, with output: $($check.Output)"
    Assert-Match $check.Report '## Errors\r?\n\r?\nNo error\.' 'errors'
}
