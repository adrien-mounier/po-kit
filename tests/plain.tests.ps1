# The lighter validation mode: the plain facts of a proposal are applied at once, and the lines
# that wait for the PO stay pending until the PO applies or drops them.

function New-InterpretedOperation([string]$Type, [hashtable]$Fields = @{}) {
    # One valid operation creating a record that holds a reading of its source.
    $operation = if ($Type -eq 'subject') { New-SubjectOperation $Fields } else { New-RecordOperation $Type $Fields }
    $operation.interpreted = $true
    $operation
}

function Get-RecordsWritten([string]$Workspace) {
    # The identifiers of the records of the register, in order, on one line.
    @(Get-ChildItem (Join-Path $Workspace 'register') -Recurse -File -Filter *.json | ForEach-Object { $_.BaseName } | Sort-Object) -join ' '
}

Test 'apply plain records the plain facts and keeps the interpreted lines pending, where preview shows them numbered from 1' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-InterpretedOperation decision @{ title = 'Choose the branches of the pilot'; needed_from = 'the sponsor' }),
            (New-RecordOperation commitment @{ title = 'Send the security file of the pilot'; owner = 'the architect' }),
            (New-InterpretedOperation risk @{ title = 'The pilot branches may not be staffed'; evidence_level = 'hypothesis' })
        )
    }

    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'C-2026-001 mobile-onboarding' (Get-RecordsWritten $ws) 'records of the register'
    Assert-Equal 'the architect' (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')).owner 'owner of the commitment recorded'
    Assert-Match $run.Output '(?m)^- create commitment C-2026-001$' 'what was recorded'
    Assert-Match $run.Output '(?m)^Waiting for the PO: 2 line\(s\), still pending\.' 'what waits'
    $pending = @((Read-Json (Join-Path $ws 'state\proposal.json')).operations)
    Assert-Equal 'Choose the branches of the pilot | The pilot branches may not be staffed' (@($pending | ForEach-Object { $_.fields.title }) -join ' | ') 'lines still pending'
    Assert-Equal '?? state/proposal.json' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'

    $preview = Invoke-Register $ws preview

    Assert-Equal 0 $preview.ExitCode "exit code of preview, with output: $($preview.Output)"
    Assert-Match $preview.Output 'Pending proposal: 2 operation\(s\)' 'output of preview'
    Assert-Match $preview.Output '(?m)^\| 1 +\| create +\| decision +\| Choose the branches of the pilot ' 'first line that waits'
    Assert-Match $preview.Output '(?m)^\| 2 +\| create +\| risk +\| The pilot branches may not be staffed ' 'second line that waits'
}

Test 'a plain fact attached to the subject that an interpreted line creates waits with it, and is recorded under that subject once the PO accepts' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation),
            (New-InterpretedOperation subject @{ title = 'Branch appointment booking' }),
            (New-RecordOperation commitment @{ title = 'Send the onboarding figures'; subject = 'line 1' }),
            (New-RecordOperation commitment @{ title = 'List the branches that take appointments'; subject = 'line 2' }),
            (New-InterpretedOperation risk @{ title = 'The onboarding pilot may slip'; subject = 'line 1' })
        )
    }

    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'C-2026-001 mobile-onboarding' (Get-RecordsWritten $ws) 'records of the register'
    Assert-Equal 'Send the onboarding figures' (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')).title 'commitment recorded'
    Assert-Match $run.Output '(?m)^Waiting for the PO: 3 line\(s\), still pending\.' 'what waits'
    # A line that waits names its subject as the proposal left pending can find it: by the new number
    # of the line that creates it, or by the identifier it received when its line was applied.
    $pending = @((Read-Json (Join-Path $ws 'state\proposal.json')).operations)
    Assert-Equal 'Branch appointment booking | List the branches that take appointments | The onboarding pilot may slip' (@($pending | ForEach-Object { $_.fields.title }) -join ' | ') 'lines still pending'
    Assert-Equal 'line 1' $pending[1].fields.subject 'subject of the commitment that waits'
    Assert-Equal 'mobile-onboarding' $pending[2].fields.subject 'subject of the risk that waits'

    $run = Invoke-Register $ws apply -Today 2026-03-04

    Assert-Equal 0 $run.ExitCode "exit code of the later apply, with output: $($run.Output)"
    Assert-Equal 'branch-appointment-booking' (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-002.json')).subject 'subject of the commitment recorded later'
    Assert-Equal 'mobile-onboarding' (Read-Json (Join-Path $ws 'register\risks\R-2026-001.json')).subject 'subject of the risk recorded later'
}

Test 'a line that waits is recorded later with every value it held: a list of one item, a group of fields, an apostrophe' {
    $ws = New-TestWorkspaceWithSubject
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.gates = @('architecture review')
    $settings.objectives = @(@{ number = 1; title = 'Halve the time to open an account' })
    Write-Json (Join-Path $ws 'settings.json') $settings
    $gates = New-UpdateOperation 'mobile-onboarding' @{ gates = @(@{ name = 'architecture review'; state = 'planned' }); next_step = "Await the sponsor's answer" }
    $gates.interpreted = $true
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment),
            $gates,
            (New-InterpretedOperation commitment @{ title = 'Book the committee room'; objectives = @(1) })
        )
    }

    $plain = Invoke-Register $ws apply plain -Today 2026-03-03
    $run = Invoke-Register $ws apply -Today 2026-03-04

    Assert-Equal 0 $plain.ExitCode "exit code of apply plain, with output: $($plain.Output)"
    Assert-Equal 0 $run.ExitCode "exit code of the later apply, with output: $($run.Output)"
    $subject = Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')
    Assert-Equal 'architecture review: planned' (@($subject.gates | ForEach-Object { "$($_.name): $($_.state)" }) -join ', ') 'gates of the subject'
    Assert-Equal "Await the sponsor's answer" $subject.next_step 'next step of the subject'
    Assert-Equal 'inbox/call-with-the-tech-lead.md' $subject.history[-1].source.where 'source of the change'
    $commitment = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-002.json')
    Assert-True ($commitment.objectives -is [array]) 'the objectives of the commitment are not a list'
    Assert-Equal '1' ($commitment.objectives -join ', ') 'objectives of the commitment'
}

function New-WorkspaceWithRecords {
    # A workspace whose register holds the subject mobile-onboarding, the open commitment
    # C-2026-001 and the pending decision D-2026-001.
    $workspace = New-TestWorkspaceWithSubject
    Set-Proposal $workspace @{ operations = @((New-RecordOperation commitment @{ due_date = '2026-03-20' }), (New-RecordOperation decision)) }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the commitment and the decision, with output: $($run.Output)"
    $workspace
}

Test 'a plain update waits with the interpreted update of the same record, so that what is recorded without asking never breaks a rule of the check' {
    $ws = New-WorkspaceWithRecords
    $author = New-UpdateOperation 'D-2026-001' @{ decided_by = 'the sponsor' }
    $author.interpreted = $true
    Set-Proposal $ws @{ operations = @(
            (New-UpdateOperation 'D-2026-001' @{ status = 'taken' }),
            $author,
            (New-UpdateOperation 'C-2026-001' @{ due_date = '2026-04-10' })
        )
    }

    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'pending' (Read-Json (Join-Path $ws 'register\decisions\2026\D-2026-001.json')).status 'status of the decision'
    Assert-Equal '2026-04-10' (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')).due_date 'due date of the commitment'
    Assert-Match $run.Output '(?m)^Waiting for the PO: 2 line\(s\), still pending\.' 'what waits'
    Assert-Match $run.Output 'Check: 0 error\(s\)' 'check'

    $run = Invoke-Register $ws apply -Today 2026-03-04

    Assert-Equal 0 $run.ExitCode "exit code of the later apply, with output: $($run.Output)"
    Assert-Equal 'taken' (Read-Json (Join-Path $ws 'register\decisions\2026\D-2026-001.json')).status 'status of the decision once the PO accepts'
}

Test 'a plain fact that updates or supersedes a record waits when a line that waits does so too, whatever their order' {
    $ws = New-WorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(
            (New-UpdateOperation 'C-2026-001' @{ due_date = '2026-04-10' }),
            (New-InterpretedOperation subject @{ title = 'Branch appointment booking' }),
            (New-RecordOperation decision @{ title = 'Hand the figures over to the branch network'; subject = 'line 2'; supersedes = 'C-2026-001' }),
            (New-RecordOperation risk @{ title = 'The figures may come late' })
        )
    }

    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'C-2026-001 D-2026-001 mobile-onboarding R-2026-001' (Get-RecordsWritten $ws) 'records of the register'
    $commitment = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    Assert-Equal '2026-03-20 open' "$($commitment.due_date) $($commitment.status)" 'due date and status of the commitment'
    Assert-Match $run.Output '(?m)^Waiting for the PO: 3 line\(s\), still pending\.' 'what waits'

    $run = Invoke-Register $ws apply -Today 2026-03-04

    Assert-Equal 0 $run.ExitCode "exit code of the later apply, with output: $($run.Output)"
    $commitment = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    Assert-Equal '2026-04-10 superseded D-2026-002' "$($commitment.due_date) $($commitment.status) $($commitment.superseded_by)" 'the commitment once the PO accepts'
    Assert-Equal 'branch-appointment-booking' (Read-Json (Join-Path $ws 'register\decisions\2026\D-2026-002.json')).subject 'subject of the decision recorded later'
}

function Set-CollectedProposal([string]$Workspace, [object[]]$Operations) {
    # Leaves the proposal of a collect at Example Bank on the morning of 3 March 2026, which read one
    # note of the inbox and holds one unclassified item, with these operations.
    Add-InboxNote $Workspace 'pilot preparation.md'
    Set-Proposal $Workspace @{
        collected_at        = '2026-03-03T08:30:00+01:00'
        sources_read        = @(@{ source = 'notes'; cutoff = '2026-03-03T08:30:00+01:00'; items = 1 })
        sources_not_covered = @('mail', 'tracker')
        notes_processed     = @('pilot preparation.md')
        unclassified        = @(@{ source = 'inbox/pilot preparation.md'; text = 'The branch network asks who owns the queue screens.' })
        operations          = $Operations
    }
}

Test 'the collect is settled once, when the plain facts are applied: applying the lines that wait later files no note and moves no cutoff' {
    $ws = New-TestWorkspaceWithSubject
    Set-CollectedProposal $ws @(
        (New-RecordOperation commitment @{ title = 'Send the security file of the pilot' }),
        (New-InterpretedOperation decision @{ title = 'Choose the branches of the pilot' })
    )

    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-True (Test-Path -LiteralPath (Join-Path $ws 'inbox\done\2026-03\pilot preparation.md')) 'the note is not filed'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $ws 'inbox\pilot preparation.md'))) 'the note is still in the inbox'
    Assert-Equal '2026-03-03T08:30:00+01:00' (Read-Json (Join-Path $ws 'state\last-collect.json')).sources.notes.cutoff 'cutoff of the notes'
    $pending = Read-Json (Join-Path $ws 'state\proposal.json')
    Assert-Equal 'operations' (@($pending.PSObject.Properties | ForEach-Object { $_.Name }) -join ' ') 'what the proposal left pending holds'
    $committed = @(git -C $ws show --name-only --format= HEAD)
    foreach ($path in 'register/commitments/2026/C-2026-001.json', 'inbox/done/2026-03/pilot preparation.md', 'state/last-collect.json', 'state/unclassified.md') {
        Assert-True ($committed -contains $path) "the last commit lacks $path; it holds: $($committed -join ', ')"
    }
    $settled = Get-WorkspaceSnapshot (Join-Path $ws 'inbox')
    $state = 'last-collect.json', 'unclassified.md' | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $ws "state\$_")).Hash }

    $run = Invoke-Register $ws apply -Today 2026-04-02

    Assert-Equal 0 $run.ExitCode "exit code of the later apply, with output: $($run.Output)"
    Assert-Equal 'C-2026-001 D-2026-001 mobile-onboarding' (Get-RecordsWritten $ws) 'records of the register'
    Assert-True ($run.Output -notmatch 'settle the collect|file note') "the later apply settled a collect again: $($run.Output)"
    Assert-Equal $settled (Get-WorkspaceSnapshot (Join-Path $ws 'inbox')) 'files of the inbox after the later apply'
    Assert-Equal ($state -join ' ') (('last-collect.json', 'unclassified.md' | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $ws "state\$_")).Hash }) -join ' ') 'collect state and unclassified list after the later apply'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
}

Test 'a morning collect over lines that still wait carries them first, unchanged: apply plain records its plain facts and leaves the old and the new waiting lines pending' {
    # Monday: the PO's commitment is recorded, and its estimate waits for the PO.
    $ws = New-TestWorkspaceWithSubject
    $estimate = { param($Id, $Days) @{ op = 'update'; id = $Id; interpreted = $true; source = @{ where = 'inbox/steering-notes.md'; read_on = '2026-03-02' }; fields = @{ estimated_effort = $Days } } }
    Set-Proposal $ws @{ operations = @((New-RecordOperation commitment @{ title = 'Draft the pilot timeline'; owner = 'the PO'; due_date = '2026-03-20' }), (& $estimate 'line 1' 2)) }
    $run = Invoke-Register $ws apply plain -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code of Monday's apply plain, with output: $($run.Output)"
    $waiting = @((Read-Json (Join-Path $ws 'state\proposal.json')).operations)

    # Tuesday's morning collect writes the line that waits first, as it was, then its own lines.
    Set-CollectedProposal $ws (@($waiting) + @((New-RecordOperation commitment @{ title = 'Book the committee room'; owner = 'the PO'; due_date = '2026-03-13' }), (& $estimate 'line 2' 0.5)))
    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code of Tuesday's apply plain, with output: $($run.Output)"
    Assert-Equal 'C-2026-001 C-2026-002 mobile-onboarding' (Get-RecordsWritten $ws) 'records of the register'
    Assert-True (Test-Path -LiteralPath (Join-Path $ws 'inbox\done\2026-03\pilot preparation.md')) 'the note of the morning collect is not filed'
    $pending = @((Read-Json (Join-Path $ws 'state\proposal.json')).operations)
    Assert-Equal 'C-2026-001: 2 | C-2026-002: 0.5' (@($pending | ForEach-Object { "$($_.id): $($_.fields.estimated_effort)" }) -join ' | ') 'lines still pending: the one carried over, then the new one'
}

Test 'when no line is a plain fact, apply plain settles the collect, records nothing and leaves every line pending; asked again, it writes nothing' {
    $ws = New-TestWorkspaceWithSubject
    Set-CollectedProposal $ws @(
        (New-InterpretedOperation decision @{ title = 'Choose the branches of the pilot' }),
        (New-InterpretedOperation risk @{ title = 'The pilot branches may not be staffed' })
    )

    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'mobile-onboarding' (Get-RecordsWritten $ws) 'records of the register'
    Assert-True (Test-Path -LiteralPath (Join-Path $ws 'inbox\done\2026-03\pilot preparation.md')) 'the note is not filed'
    Assert-Match $run.Output '(?m)^Waiting for the PO: 2 line\(s\), still pending\.' 'what waits'
    $before = Get-WorkspaceSnapshot $ws
    $head = git -C $ws rev-parse HEAD

    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code when asked again, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^No plain fact to record: the 2 line\(s\) of the proposal wait for the PO\.' 'output when asked again'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace when asked again'
    Assert-Equal $head (git -C $ws rev-parse HEAD) 'last commit when asked again'
}

Test 'when every line is a plain fact, apply plain applies the proposal whole and no proposal stays pending' {
    $ws = New-TestWorkspaceWithSubject
    Set-CollectedProposal $ws @(New-RecordOperation commitment @{ title = 'Send the security file of the pilot' })

    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'C-2026-001 mobile-onboarding' (Get-RecordsWritten $ws) 'records of the register'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending'
    Assert-True ($run.Output -notmatch 'Waiting for the PO') "a line is said to wait: $($run.Output)"
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
}

function New-WorkspaceWithWaitingLines {
    # A workspace where the plain fact of a proposal was recorded on 3 March 2026, and where its two
    # interpreted lines wait for the PO: a decision and a risk.
    $workspace = New-TestWorkspaceWithSubject
    Set-Proposal $workspace @{ operations = @(
            (New-InterpretedOperation decision @{ title = 'Choose the branches of the pilot'; needed_from = 'the sponsor' }),
            (New-RecordOperation commitment @{ title = 'Send the security file of the pilot'; owner = 'the architect' }),
            (New-InterpretedOperation risk @{ title = 'The pilot branches may not be staffed'; evidence_level = 'hypothesis' })
        )
    }
    $run = Invoke-Register $workspace apply plain -Today 2026-03-03
    Assert-Equal 0 $run.ExitCode "exit code when recording the plain fact, with output: $($run.Output)"
    $workspace
}

Test 'the lines that wait are applied later as any proposal is: whole, or the lines the PO keeps' {
    $ws = New-WorkspaceWithWaitingLines

    $run = Invoke-Register $ws apply -Today 2026-03-04

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'C-2026-001 D-2026-001 mobile-onboarding R-2026-001' (Get-RecordsWritten $ws) 'records of the register'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'

    $ws = New-WorkspaceWithWaitingLines

    $run = Invoke-Register $ws apply 2 -Today 2026-03-04

    Assert-Equal 0 $run.ExitCode "exit code of the selection, with output: $($run.Output)"
    Assert-Equal 'C-2026-001 mobile-onboarding R-2026-001' (Get-RecordsWritten $ws) 'records of the register after the selection'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending after the selection'
}

Test 'apply none drops every line that waits: nothing more is recorded or committed, and no proposal stays pending' {
    $ws = New-WorkspaceWithWaitingLines
    $head = git -C $ws rev-parse HEAD

    $run = Invoke-Register $ws apply none -Today 2026-03-04

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Dropped: line 1, 2\.' 'output'
    Assert-Equal 'C-2026-001 mobile-onboarding' (Get-RecordsWritten $ws) 'records of the register'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending'
    Assert-Equal $head (git -C $ws rev-parse HEAD) 'last commit'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'

    $preview = Invoke-Register $ws preview

    Assert-Equal 1 $preview.ExitCode "exit code of preview, with output: $($preview.Output)"
    Assert-Match $preview.Output 'No proposal is pending\.' 'output of preview'
}

Test 'apply none on the proposal of a collect drops every line and settles the collect: the notes are filed and nothing is recorded' {
    $ws = New-TestWorkspaceWithSubject
    Set-CollectedProposal $ws @(
        (New-RecordOperation commitment @{ title = 'Send the security file of the pilot' }),
        (New-InterpretedOperation decision @{ title = 'Choose the branches of the pilot' })
    )

    $run = Invoke-Register $ws apply none -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Dropped: line 1, 2\.' 'output'
    Assert-Equal 'mobile-onboarding' (Get-RecordsWritten $ws) 'records of the register'
    Assert-True (Test-Path -LiteralPath (Join-Path $ws 'inbox\done\2026-03\pilot preparation.md')) 'the note is not filed'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
}

Test 'none and plain stand alone: with the number of a line, the selection is refused whole' {
    $ws = New-WorkspaceWithWaitingLines
    $before = Get-WorkspaceSnapshot $ws

    foreach ($word in 'none', 'plain') {
        $run = Invoke-Register $ws apply $word 2

        Assert-Equal 1 $run.ExitCode "exit code for $word, with output: $($run.Output)"
        Assert-Match $run.Output 'Selection refused\. Nothing was written\.' "output for $word"
        Assert-Match $run.Output "- '$word' is not a line of the proposal, which has lines 1 to 2\." "reason for $word"
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for $word"
    }
}

Test 'after the plain facts, apply plain shows the lines that wait as preview does, numbered from 1' {
    $ws = New-TestWorkspaceWithSubject
    Set-CollectedProposal $ws @(
        (New-RecordOperation commitment @{ title = 'Send the security file of the pilot' }),
        (New-InterpretedOperation decision @{ title = 'Choose the branches of the pilot' })
    )

    $run = Invoke-Register $ws apply plain -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $after = ($run.Output -split '(?m)^Waiting for the PO: 1 line\(s\), still pending\..*$', 2)[1]
    Assert-Match $after 'Pending proposal: 1 operation\(s\)' 'under what waits'
    Assert-Match $after '(?m)^\| 1 +\| create +\| decision +\| Choose the branches of the pilot +\| mobile-onboarding +\| fact +\| yes ' 'the line that waits'
    Assert-True ($after -notmatch 'Send the security file of the pilot') "the line recorded is shown as waiting: $after"
    Assert-True ($after -notmatch 'Collect of') "the collect is shown as still to settle: $after"
}

Test 'preview states the validation mode of the settings, and a mode other than all or interpreted is refused by every command' {
    $ws = New-WorkspaceWithWaitingLines
    $settings = Read-Json (Join-Path $ws 'settings.json')

    $run = Invoke-Register $ws preview

    Assert-Match $run.Output '(?m)^Validation mode: interpreted\.' 'output of preview in the default mode'

    $settings.validation_mode = 'all'
    Write-Json (Join-Path $ws 'settings.json') $settings
    $run = Invoke-Register $ws preview

    Assert-Equal 0 $run.ExitCode "exit code of preview, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Validation mode: all\.' 'output of preview in the stricter mode'

    foreach ($mode in 'none', 'Interpreted', '', $null) {
        $settings.validation_mode = $mode
        Write-Json (Join-Path $ws 'settings.json') $settings
        $before = Get-WorkspaceSnapshot $ws
        foreach ($command in 'preview', 'apply', 'check', 'view', 'export', 'verify') {
            $run = Invoke-Register $ws $command

            Assert-Equal 1 $run.ExitCode "exit code of $command in mode '$mode', with output: $($run.Output)"
            Assert-Match $run.Output "The validation mode must be 'all' or 'interpreted', not '$mode'\. Nothing was done\." "output of $command in mode '$mode'"
            Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace after $command in mode '$mode'"
        }
    }
}
