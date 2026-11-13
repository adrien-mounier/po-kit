# Effort and learning: a commitment of the PO carries its estimated effort, its kind of task, when
# it was started and its real effort, and the register tool learns, per kind of task, how far the
# real effort strays from the estimate. The learning concerns the PO's own tasks only.

function New-TestWorkspaceWithKinds {
    # A workspace whose settings list the kinds of task steering pack and intake review, and whose
    # register holds the subject mobile-onboarding.
    $workspace = New-TestWorkspace
    $settings = Read-Json (Join-Path $workspace 'settings.json')
    $settings.task_kinds = @('steering pack', 'intake review')
    Write-Json (Join-Path $workspace 'settings.json') $settings
    Set-Proposal $workspace @{ operations = @(New-SubjectOperation) }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the subject, with output: $($run.Output)"
    $workspace
}

Test 'a commitment of the PO records an estimated effort in days, a kind of task listed in the settings, the reason of the estimate, when it was started with the sign seen, and its real effort, all optional' {
    $ws = New-TestWorkspaceWithKinds
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ title = 'Build the steering pack'; owner = 'the PO'; estimated_effort = 1.5; task_kind = 'steering pack'
                estimate_reason = 'a steering pack takes a day and a half'; started_on = '2026-03-01'; started_sign = 'ticket ONB-12 moved to in progress'; real_effort = 2
            }),
            (New-RecordOperation commitment @{ title = 'Review the intake'; owner = 'the PO' })
        ) }

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $record = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    Assert-Equal 1.5 $record.estimated_effort 'estimated effort'
    Assert-Equal 'steering pack' $record.task_kind 'kind of task'
    Assert-Equal 'a steering pack takes a day and a half' $record.estimate_reason 'reason of the estimate'
    Assert-Equal '2026-03-01' $record.started_on 'started on'
    Assert-Equal 'ticket ONB-12 moved to in progress' $record.started_sign 'sign of the start'
    Assert-Equal 2 $record.real_effort 'real effort'
}

function New-EstimateOperation([string]$Id, [hashtable]$Fields = @{ estimated_effort = 2; task_kind = 'steering pack'; estimate_reason = 'a steering pack takes two days' }) {
    # The estimate the agent proposes for a commitment of the PO: an interpreted update.
    $update = New-UpdateOperation $Id $Fields
    $update.interpreted = $true
    $update
}

Test 'the estimate of a commitment that the same proposal creates is an interpreted update naming its line: apply plain records the commitment, and the estimate waits under its identifier' {
    $ws = New-TestWorkspaceWithKinds
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ title = 'Build the steering pack'; owner = 'the PO'; due_date = '2026-03-20' }),
            (New-EstimateOperation 'line 1')
        ) }

    $preview = Invoke-Register $ws preview
    Assert-Equal 0 $preview.ExitCode "exit code of preview, with output: $($preview.Output)"
    Assert-Match $preview.Output '\| 2 \| update +\| commitment \| Build the steering pack .*\| yes +\| record: line 1; .*estimated_effort: \(none\) -> 2' 'the estimate in the preview'

    $run = Invoke-Register $ws apply plain -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code of apply plain, with output: $($run.Output)"
    Assert-Equal $null (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')).estimated_effort 'estimate recorded without the PO'
    $pending = @((Read-Json (Join-Path $ws 'state\proposal.json')).operations)
    Assert-Equal 1 $pending.Count 'lines still pending'
    Assert-Equal 'C-2026-001' $pending[0].id 'record the pending estimate names'

    $run = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code of apply, with output: $($run.Output)"
    $record = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    Assert-Equal 2 $record.estimated_effort 'estimate recorded once the PO said yes'
    Assert-True (@($record.history | Where-Object { $_.field -eq 'estimated_effort' -and $_.new -eq 2 }).Count -eq 1) 'the history does not hold the estimate'
}

Test 'a commitment and its estimate applied together are one record; an update cannot name a later line, a line that creates nothing, or a line the selection drops' {
    $ws = New-TestWorkspaceWithKinds
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ title = 'Build the steering pack'; owner = 'the PO' }),
            (New-EstimateOperation 'line 1')
        ) }
    $run = Invoke-Register $ws apply 2 -Today 2026-03-02
    Assert-Equal 1 $run.ExitCode "exit code of apply 2, with output: $($run.Output)"
    Assert-Match $run.Output 'Line 2 updates the record that line 1 creates, and the selection drops line 1' 'reason of the refused selection'

    $run = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code of apply, with output: $($run.Output)"
    Assert-Equal 2 (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')).estimated_effort 'estimate'
    Assert-Equal 1 @(Get-ChildItem (Join-Path $ws 'register\commitments') -Recurse -File -Filter *.json).Count 'commitments recorded'

    Set-Proposal $ws @{ operations = @(
            (New-EstimateOperation 'line 2'),
            (New-RecordOperation commitment @{ owner = 'the PO' }),
            (New-UpdateOperation 'C-2026-001' @{ due_date = '2026-03-27' }),
            (New-EstimateOperation 'line 3')
        ) }
    Assert-Refused $ws @(
        "Line 1: record 'line 2' does not exist in the register nor earlier in this proposal",
        "Line 4: record 'line 3' does not exist in the register nor earlier in this proposal"
    )
}

function New-TestWorkspaceWithPastEfforts {
    # A workspace with the kinds steering pack and intake review, seen on Monday 2 March 2026:
    #   C-2026-001..003  steering packs the PO did: estimated 2, 1 and 2 days, really 3, 1.5 and
    #                    2.5: 7 days for 5 estimated, a ratio of 1.4
    #   C-2026-004       a steering pack done, its real effort unknown: not learned from
    #   C-2026-005       a steering pack dropped, estimated 1, really 10: not learned from
    #   C-2026-006       open, a steering pack estimated 2 days, started on 27 Feb on a sign
    #   C-2026-007       open, an intake review estimated 1 day: no past intake review
    #   C-2026-008       open, estimated half a day, no kind of task
    #   C-2026-009       open, no estimate
    $workspace = New-TestWorkspaceWithKinds
    $c = { param($Fields) $all = @{ owner = 'the PO'; task_kind = 'steering pack' }; foreach ($name in $Fields.Keys) { $all[$name] = $Fields[$name] }; New-RecordOperation commitment $all }
    Set-Proposal $workspace @{ operations = @(
            (& $c @{ title = 'January steering pack'; status = 'done'; estimated_effort = 2; real_effort = 3 }),
            (& $c @{ title = 'February steering pack'; status = 'done'; estimated_effort = 1; real_effort = 1.5 }),
            (& $c @{ title = 'Pilot steering pack'; status = 'done'; estimated_effort = 2; real_effort = 2.5 }),
            (& $c @{ title = 'Budget steering pack'; status = 'done'; estimated_effort = 3 }),
            (& $c @{ title = 'Dropped steering pack'; status = 'dropped'; estimated_effort = 1; real_effort = 10 }),
            (& $c @{ title = 'March steering pack'; estimated_effort = 2; due_date = '2026-03-13'; started_on = '2026-02-27'; started_sign = 'ticket ONB-12 moved to in progress' }),
            (& $c @{ title = 'Review the kiosk intake'; estimated_effort = 1; task_kind = 'intake review'; due_date = '2026-03-04' }),
            (& $c @{ title = 'Answer the branch network'; estimated_effort = 0.5; task_kind = $null; due_date = '2026-03-05' }),
            (& $c @{ title = 'Book the committee room'; task_kind = $null; due_date = '2026-03-06' })
        ) }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the past efforts, with output: $($run.Output)"
    $workspace
}

Test 'export states the effort of each open commitment of the PO: the estimate adjusted by the ratio of real to estimated effort over the done commitments of its kind, or unadjusted and saying why' {
    $ws = New-TestWorkspaceWithPastEfforts

    $run = Invoke-Register $ws export 2026-03-02 -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $line = { param($Id) ($run.Output -split "`n" | Where-Object { $_.Contains("[$Id]") -and -not $_.Contains('recorded 2026') }) -join "`n" }
    Assert-Match (& $line 'C-2026-006') '\| effort: est\. 2 d, adjusted x1\.4 from past steering pack: 2\.8 d \| started: 2026-02-27, ticket ONB-12 moved to in progress$' 'a steering pack'
    Assert-Match (& $line 'C-2026-007') '\| effort: est\. 1 d, not adjusted: no past intake review$' 'an intake review'
    Assert-Match (& $line 'C-2026-008') '\| effort: est\. 0\.5 d, not adjusted: no kind of task$' 'a task without a kind'
    Assert-True ((& $line 'C-2026-009') -notmatch 'effort') 'a commitment without an estimate states an effort'
    # Only an open commitment has an estimate to adjust.
    Assert-Match $run.Output '\[C-2026-001\] .*\| estimated effort: 2 d \| real effort: 3 d \| recorded 2026-03-02' 'a done commitment, among the changes'
}

Test 'the morning page states under What you owe the effort of each line, with the ratio it was adjusted by, in the language of the page' {
    $ws = New-TestWorkspaceWithPastEfforts

    $run = Invoke-Register $ws morning -Now 2026-03-02T07:12:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $page = [IO.File]::ReadAllText((Join-Path $ws 'views\morning.html'), $Utf8)
    $row = { param($Id) if ($page -match "(?s)<li class=`"row[^`"]*`">(?:(?!</li>).)*&middot; <span class=`"id`">$Id</span>.*?</li>") { $Matches[0] } }
    Assert-Match (& $row 'C-2026-006') '<span class="t">March steering pack</span> <span class="who">est\. 2 d, adjusted x1\.4 from past steering pack: 2\.8 d</span></span>' 'a steering pack'
    Assert-Match (& $row 'C-2026-007') '<span class="who">est\. 1 d, not adjusted: no past intake review</span>' 'an intake review'
    Assert-True ((& $row 'C-2026-009') -notmatch 'class="who"') 'a line without an estimate states an effort'

    $run = Invoke-Register $ws morning fr -Now 2026-03-02T07:12:00+01:00
    $page = [IO.File]::ReadAllText((Join-Path $ws 'views\morning.html'), $Utf8)
    # Each accented letter of the French label is a dot of the pattern: a test file is plain ASCII.
    Assert-Match ([Net.WebUtility]::HtmlDecode((& $row 'C-2026-006'))) '<span class="who">estim\. 2 j, ajust.e x1,4 d''apr.s les t.ches pass.es . steering pack . : 2,8 j</span>' 'a steering pack, in French'
}

Test 'an effort or a start is recorded on the commitments the PO owns only: never on what another person owes' {
    $ws = New-TestWorkspaceWithKinds
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ owner = 'the PO'; due_date = '2026-03-20' }),
            (New-RecordOperation commitment @{ owner = 'the tech lead'; estimated_effort = 2 }),
            (New-RecordOperation commitment @{ real_effort = 1 }),
            (New-RecordOperation commitment @{ owner = 'the architect'; started_on = '2026-03-01' })
        ) }

    Assert-Refused $ws @(
        "Line 2: effort or start recorded on a commitment the PO does not own \(owner: the tech lead\): the register holds the PO's own effort only",
        "Line 3: effort or start recorded on a commitment the PO does not own \(owner: none\)",
        "Line 4: effort or start recorded on a commitment the PO does not own \(owner: the architect\)"
    )
}

Test 'a kind of task not listed in the settings, or an effort that is not a number of days above zero, is refused' {
    $ws = New-TestWorkspaceWithKinds
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ owner = 'the PO'; task_kind = 'ticket refinement' }),
            (New-RecordOperation commitment @{ owner = 'the PO'; estimated_effort = 0 }),
            (New-RecordOperation commitment @{ owner = 'the PO'; real_effort = 'two days' })
        ) }

    Assert-Refused $ws @(
        "Line 1: field 'task_kind' is 'ticket refinement'; settings.json lists under 'task_kinds': steering pack, intake review",
        "Line 2: field 'estimated_effort' must be a number of days above zero",
        "Line 3: field 'real_effort' must be a number of days above zero"
    )
}
