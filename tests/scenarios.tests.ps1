# The scenario runner: what it builds, what it checks and what it reports, proven without any
# agent. A script stands in for the agent: it starts no model, costs nothing and does as told.
# The scenarios themselves, which do start an agent, are run by scenarios\run.ps1.

$FakeAgent = "powershell -NoProfile -File `"$(Join-Path $Fixtures 'fake-agent.ps1')`""

function Invoke-Scenarios {
    # Runs the scenario runner once: Invoke-Scenarios -Agent $FakeAgent subject-create
    # Returns its output (standard output and errors together) and its exit code.
    $ErrorActionPreference = 'Continue'
    # Windows PowerShell 5.1 hands a quote inside an argument to a program only when it is escaped.
    $arguments = @($args | ForEach-Object { "$_".Replace('"', '\"') })
    # The runner works in the temporary folder of the machine: under the test root, for these tests.
    $temp = $env:TMP
    $env:TMP = $TestRoot
    try { $lines = & powershell.exe -NoProfile -File (Join-Path $KitRoot 'scenarios\run.ps1') @arguments 2>&1 | ForEach-Object { "$_" } }
    finally { $env:TMP = $temp }
    @{ Output = ($lines -join "`n"); ExitCode = $LASTEXITCODE }
}

Test 'the scenario "create" passes when the agent records the subject the PO describes, through the register tool' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenario-create.proposal.json`"" subject-create

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'kind is "product"', 'horizon is "next"', 'banks is \["Harbour Bank","Alpine Bank"\]', 'clearance is "cleared"', 'cleared_by is "the sponsor"',
        'watch_list.people is \["the tech lead","the head of savings"\]') {
        Assert-Match $run.Output "  ok    record savings-simulator: $fact" 'expected fact reported as passed'
    }
    Assert-Match $run.Output '  ok    register/subjects holds 4 record\(s\)' 'the register gains one subject'
    Assert-Match $run.Output '  ok    file views/portfolio\.md has a line containing "Savings simulator \[savings-simulator\] \(Harbour Bank, Alpine Bank\)"' 'the portfolio view shows the new subject with its banks'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
    Assert-Match $run.Output '1 scenario\(s\): 1 passed, 0 failed' 'verdict'
}

Test 'the scenario "create for every bank" passes when the subject the PO says concerns all the client banks names none, and fails when it names one' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenario-create-every-bank.proposal.json`"" subject-create-every-bank

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    record group-data-platform: banks is \[\]' 'the subject names no bank'

    $proposal = Join-Path $TestRoot 'one-bank.proposal.json'
    [IO.File]::WriteAllText($proposal, [IO.File]::ReadAllText("$Fixtures\scenario-create-every-bank.proposal.json").Replace('"banks": []', '"banks": ["Harbour Bank"]'), $Utf8)
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$proposal`"" subject-create-every-bank

    Assert-Match $run.Output '  FAIL  record group-data-platform: banks is \[\]' 'the subject that names a bank'
    Assert-Equal 1 $run.ExitCode 'exit code when the subject names a bank'
}

Test 'the scenario "modify" passes when one subject moves to Now with a history entry and the other is closed and kept' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenario-modify.proposal.json`"" subject-modify

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'horizon is "now"', 'history\[0\]\.field is "horizon"', 'history\[0\]\.previous is "next"', 'history\[0\]\.new is "now"') {
        Assert-Match $run.Output "  ok    record payments-api-contribution: $fact" 'expected fact reported as passed'
    }
    Assert-Match $run.Output '  ok    record branch-opening-hours-page: status is "closed"' 'the closed subject is still a record'
    Assert-Match $run.Output '  ok    register/subjects holds 3 record\(s\)' 'no subject is added or lost'
    Assert-Match $run.Output '  ok    file views/portfolio\.md has no line containing "Branch opening hours page"' 'the closed subject leaves the portfolio view'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "missing answer" passes when the agent records nothing, and fails when it records a subject the PO did not describe' {
    $run = Invoke-Scenarios -Agent $FakeAgent subject-missing-answer

    Assert-Equal 0 $run.ExitCode "exit code when nothing is recorded, with output: $($run.Output)"

    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenarios\every-kind-of-fact\workspace\state\proposal.json`"" subject-missing-answer

    Assert-Match $run.Output '  FAIL  record card-dispute-portal is absent' 'the subject recorded on a guess'
    Assert-Equal 1 $run.ExitCode 'exit code when the subject is recorded on a guess'
}

# --- The collect scenarios ----------------------------------------------------------------------
# The register tool numbers a record in the year it is recorded and files a note under the month it
# is processed: a scenario names them {year} and {month}, and {today} the day of the run.
$Year, $Month, $Day = 'yyyy', 'yyyy-MM', 'yyyy-MM-dd' | ForEach-Object { (Get-Date).ToString($_, [Globalization.CultureInfo]::InvariantCulture) }

function New-CollectAgent([string[]]$Notes, [object[]]$Operations, [string]$Do = '', [hashtable]$Collect = @{}) {
    # The command of a fake agent that collects: it leaves the proposal of a collect that read these
    # notes of the inbox, with these operations, and has the register tool apply it. $Do adds
    # options of the fake agent. $Collect replaces parts of the proposal: the sources read, the
    # sources not covered, the unclassified items.
    New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
    $path = Join-Path $TestRoot ([Guid]::NewGuid().ToString('N').Substring(0, 8) + '.proposal.json')
    $proposal = @{
        collected_at        = '2026-03-12T08:30:00+01:00'
        sources_read        = @(@{ source = 'notes'; cutoff = '2026-03-12T08:30:00+01:00'; items = @($Notes).Count })
        sources_not_covered = @('mail', 'tracker')
        notes_processed     = @($Notes)
        operations          = @($Operations)
    }
    foreach ($part in $Collect.Keys) { $proposal[$part] = $Collect[$part] }
    Write-Json $path $proposal
    "$FakeAgent -Proposal `"$path`" $Do"
}

function New-NoteOperation([string]$Type, [string]$Note, [hashtable]$Fields) {
    # One operation creating a record from a note of the inbox, which its source names.
    New-RecordOperation $Type (@{ source = @{ where = "inbox/$Note"; read_on = '2026-03-12' } } + $Fields)
}

Test 'the scenario "collect an action" passes when the note becomes a commitment with its owner, its due date and the objective the note names, attached to its subject, and is filed' {
    $note = 'onboarding workshop.md'
    $agent = New-CollectAgent $note @(
        New-NoteOperation commitment $note @{ title = 'Send the list of the onboarding screens'; owner = 'the tech lead'; owed_to = 'the PO'; due_date = '2026-03-20'; date_of_fact = '2026-03-10'; objectives = @(1) }
    )

    $run = Invoke-Scenarios -Agent $agent collect-action

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'owner is "the tech lead"', 'due_date is "2026-03-20"', 'subject is "mobile-onboarding"', 'objectives is \[1\]', 'source\.where is "inbox/onboarding workshop\.md"') {
        Assert-Match $run.Output "  ok    record C-$Year-002: $fact" 'expected fact reported as passed'
    }
    Assert-Match $run.Output "  ok    file inbox/done/$Month/onboarding workshop\.md is there" 'the note is filed as processed'
    Assert-Match $run.Output '  ok    file inbox/onboarding workshop\.md is absent' 'the note leaves the inbox'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "collect a decision" passes when the decision supersedes the commitment to present, and the portfolio view stops announcing the presentation' {
    $note = 'call-with-the-sponsor.md'
    $agent = New-CollectAgent $note @(
        (New-NoteOperation decision $note @{ title = 'Suspend the presentation of the target journey'; status = 'taken'; decided_by = 'the sponsor'; date_of_fact = '2026-03-09'; supersedes = "C-$Year-001" }),
        (New-UpdateOperation 'mobile-onboarding' @{ next_step = '' })
    )

    $run = Invoke-Scenarios -Agent $agent collect-decision

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'status is "taken"', 'decided_by is "the sponsor"', "supersedes is `"C-$Year-001`"", 'subject is "mobile-onboarding"') {
        Assert-Match $run.Output "  ok    record D-$Year-001: $fact" 'expected fact reported as passed'
    }
    Assert-Match $run.Output "  ok    record C-$Year-001: status is `"superseded`"" 'the commitment to present is superseded'
    Assert-Match $run.Output "  ok    record C-$Year-001: superseded_by is `"D-$Year-001`"" 'the commitment is linked to the decision'
    Assert-Match $run.Output '  ok    file views/portfolio\.md has no line containing "Present the target journey"' 'the portfolio view no longer announces the presentation'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "collect a missing gate" passes when the subject gets its gate missing and goes out of frame, as the portfolio view shows' {
    $note = 'security-review.md'
    $gates = @{ name = 'architecture review'; state = 'done' }, @{ name = 'security review'; state = 'missing' }
    $agent = New-CollectAgent $note @(New-UpdateOperation 'mobile-onboarding' @{ clearance = 'out of frame'; gates = $gates })

    $run = Invoke-Scenarios -Agent $agent collect-missing-gate

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'gates\[0\]\.state is "done"', 'gates\[1\]\.state is "missing"', 'clearance is "out of frame"') {
        Assert-Match $run.Output "  ok    record mobile-onboarding: $fact" 'expected fact reported as passed'
    }
    Assert-Match $run.Output '  ok    file views/portfolio\.md has a line containing "\*\*Out of frame\*\*"' 'the portfolio view shows the subject out of frame'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "collect a position" passes when the position is recorded as reported and the guess at its motives as hypothesis' {
    $note = 'call-with-the-head-of-payments.md'
    $said = @{ subject = 'payments-api-contribution'; date_of_fact = '2026-03-12' }
    $agent = New-CollectAgent $note @(
        (New-NoteOperation risk $note ($said + @{ title = 'The head of payments is against the contribution'; evidence_level = 'reported' })),
        (New-NoteOperation risk $note ($said + @{ title = 'The head of payments may fear the blame for an incident'; evidence_level = 'hypothesis' }))
    )

    $run = Invoke-Scenarios -Agent $agent collect-position

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    record R-$Year-001: evidence_level is `"reported`"" 'the position'
    Assert-Match $run.Output "  ok    record R-$Year-002: evidence_level is `"hypothesis`"" 'the guess'
    Assert-Match $run.Output '  ok    register/risks holds 2 record\(s\)' 'nothing else is recorded, as a fact or otherwise'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "collect an action without a due date" passes when the commitment is recorded all the same, and the check report lists it' {
    $note = 'call-with-the-architect.md'
    $agent = New-CollectAgent $note @(
        New-NoteOperation commitment $note @{ title = 'Share the sequence diagrams of the onboarding journey'; owner = 'the architect'; owed_to = 'the PO'; date_of_fact = '2026-03-11' }
    )

    $run = Invoke-Scenarios -Agent $agent collect-no-due-date

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    record C-$Year-002: owner is `"the architect`"" 'the owner'
    Assert-Match $run.Output "  ok    record C-$Year-002: due_date is null" 'no due date'
    Assert-Match $run.Output '  ok    file views/check-report\.md has a line containing "### Open commitment without due date"' 'the rule in the check report'
    Assert-Match $run.Output "  ok    file views/check-report\.md has a line containing `"\[C-$Year-002\] \(owner: the architect\)`"" 'the commitment under that rule'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "collect waits for the PO" passes when the proposal stays pending, each line marked interpreted or plain fact, and fails when it is applied unasked' {
    $note = 'pilot-preparation.md'
    $awaited = New-NoteOperation decision $note @{ title = 'Choose the branches of the pilot'; needed_from = 'the sponsor'; needed_by = '2026-03-27'; date_of_fact = '2026-03-12' }
    $awaited.interpreted = $true
    $operations = (New-NoteOperation commitment $note @{ title = 'Send the security file of the pilot'; owner = 'the architect'; owed_to = 'the tech lead'; due_date = '2026-03-26'; date_of_fact = '2026-03-12' }), $awaited

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $operations -Do '-Pending') collect-waits-for-the-po

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'operations\[0\]\.interpreted is false', 'operations\[1\]\.interpreted is true', 'operations\[1\]\.fields\.status is "pending"',
        'operations\[1\]\.fields\.needed_from is "the sponsor"', 'operations\[1\]\.fields\.needed_by is "2026-03-27"') {
        Assert-Match $run.Output "  ok    file state/proposal\.json: $fact" 'expected fact reported as passed'
    }
    Assert-Match $run.Output '  ok    file inbox/pilot-preparation\.md is there' 'the note waits in the inbox'

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $operations) collect-waits-for-the-po

    Assert-Match $run.Output '  FAIL  register/commitments holds 1 record\(s\)\n        found: 2 record\(s\)' 'the commitment recorded before the PO accepted'
    Assert-Equal 1 $run.ExitCode 'exit code when the proposal is applied unasked'
}

Test 'the scenario "collect records the plain facts" passes when the quoted fact is recorded without asking and the commitment whose deadline is inferred still waits, and fails when that one is recorded too' {
    $note = 'pilot-preparation.md'
    $inferred = New-NoteOperation commitment $note @{ title = 'Send the list of the branches of the pilot'; owner = 'the tech lead'; owed_to = 'the PO'; due_date = '2026-03-31'; date_of_fact = '2026-03-12' }
    $inferred.interpreted = $true
    $operations = (New-NoteOperation commitment $note @{ title = 'Send the security file of the pilot'; owner = 'the architect'; owed_to = 'the tech lead'; due_date = '2026-03-26'; date_of_fact = '2026-03-12' }), $inferred

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $operations -Do '-Plain') collect-records-plain-facts

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    record C-$Year-002: owner is `"the architect`"" 'the quoted fact is in the register'
    foreach ($fact in 'operations\[0\]\.interpreted is true', 'operations\[0\]\.fields\.owner is "the tech lead"', 'operations\[0\]\.fields\.due_date is "2026-03-31"', 'operations\[1\] is null', 'notes_processed is null') {
        Assert-Match $run.Output "  ok    file state/proposal\.json: $fact" 'expected fact reported as passed'
    }
    Assert-Match $run.Output "  ok    file inbox/done/$Month/pilot-preparation\.md is there" 'the note is filed'

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $operations) collect-records-plain-facts

    Assert-Match $run.Output '  FAIL  register/commitments holds 2 record\(s\)\n        found: 3 record\(s\)' 'the inferred deadline recorded before the PO accepted'
    Assert-Equal 1 $run.ExitCode 'exit code when the whole proposal is applied'
}

Test 'the scenario "morning" passes when the note is collected over the line still waiting, which stays pending, and the page written with its late commitment under What you owe, and fails when no page is written or the waiting line is lost' {
    $note = 'pilot-follow-up.md'
    # The line the workspace of the scenario leaves waiting, which the morning collect carries first.
    $waiting = @{ op = 'update'; id = 'mobile-onboarding'; interpreted = $true; source = @{ where = 'inbox/pilot review.md'; read_on = '2026-03-11' }
        fields = @{ next_step = 'Agree the pilot branches with the sponsor' } }
    $operations = @(New-NoteOperation commitment $note @{ title = 'Send the list of onboarding screens to the tech lead'; owner = 'the PO'; owed_to = 'the tech lead'; due_date = '2026-03-06'; date_of_fact = '2026-03-02' })

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note (@($waiting) + $operations) -Do '-Plain -Morning') morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    file views/morning\.html has lines containing, in this order: .*C-$Year-002" 'the late commitment under What you owe'
    Assert-Match $run.Output "  ok    file inbox/done/$Month/pilot-follow-up\.md is there" 'the note is filed'
    Assert-Match $run.Output '  ok    file state/proposal\.json: operations\[0\]\.fields\.next_step is "Agree the pilot branches with the sponsor"' 'the line that waited still waits'

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note (@($waiting) + $operations) -Do '-Plain') morning

    Assert-Match $run.Output '  FAIL  file views/morning\.html is there' 'the page not written'
    Assert-Equal 1 $run.ExitCode 'exit code when no page is written'

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $operations -Do '-Plain -Morning') morning

    Assert-Match $run.Output '  FAIL  file state/proposal\.json: operations\[0\]\.fields\.next_step is "Agree the pilot branches with the sponsor"' 'the line that waited, lost'
    Assert-Equal 1 $run.ExitCode 'exit code when the line that waited is lost'
}

function New-EstimateUpdate([string]$Id, [string]$Note) {
    # The estimate an agent proposes for a commitment of the PO: an interpreted update.
    @{ op = 'update'; id = $Id; interpreted = $true; source = @{ where = "inbox/$Note"; read_on = '2026-03-12' }
        fields = @{ estimated_effort = 2; task_kind = 'steering pack'; estimate_reason = 'A steering pack takes about two days.' } }
}

Test 'the scenario "an estimate adjusted by past efforts" passes when the commitment of the PO gets its kind and estimate, which export shows with the ratio of past steering packs, and fails without an estimate' {
    $note = 'april steering committee.md'
    $commitment = New-NoteOperation commitment $note @{ title = 'Prepare the April steering pack'; owner = 'the PO'; owed_to = 'the retail steering committee'; due_date = '2026-04-10'; date_of_fact = '2026-03-02' }

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $commitment, (New-EstimateUpdate 'line 1' $note)) effort-estimate-adjusted

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    record C-$Year-005: task_kind is `"steering pack`"" 'the kind of task'
    Assert-Match $run.Output "  ok    what the register tool prints for export $Day has a line containing `"adjusted x1\.4 from past steering pack`"" 'the adjusted estimate'

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note @($commitment)) effort-estimate-adjusted

    Assert-Match $run.Output "  FAIL  what the register tool prints for export $Day has a line containing `"adjusted x1\.4 from past steering pack`"\n        found: no such line" 'no estimate'
    Assert-Equal 1 $run.ExitCode 'exit code without an estimate'
}

function New-DoneUpdate([string]$Note, [hashtable]$Fields) {
    # The update an agent proposes when the PO says the March steering pack is done.
    @{ op = 'update'; id = "C-$Year-002"; interpreted = $true; source = @{ where = "inbox/$Note"; read_on = '2026-03-12' }; fields = $Fields }
}

Test 'the scenario "a clear real effort" passes when the done update carries the real effort the note gives and nothing is asked, and fails when the agent asks' {
    $note = 'march steering pack.md'
    $done = New-DoneUpdate $note @{ status = 'done'; real_effort = 3 }

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note @($done) -Do '-Plain -Morning') effort-real-clear

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file state/proposal\.json: operations\[0\]\.fields\.real_effort is 3' 'the real effort waits for the PO'

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note @($done) -Do '-Plain -Morning -Say "Real effort of C-2026-002: how many days did it take you? My guess: 2 d."') effort-real-clear

    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has no line containing "My guess"' 'the question asked all the same'
    Assert-Equal 1 $run.ExitCode 'exit code when the agent asks'
}

Test 'the scenario "an unclear real effort" passes when the done update leaves the real effort out and the question goes to the open questions, and fails when the agent asks it in the chat instead' {
    $note = 'march steering pack.md'
    $done = New-DoneUpdate $note @{ status = 'done' }

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note @($done) -Do "-Plain -Questions `"$Fixtures\real-effort-questions.json`" -Morning") effort-real-unclear

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    file state/questions\.json has a line containing `"C-$Year-002`"" 'the question kept in the open questions'

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note @($done) -Do "-Plain -Morning -Say `"Real effort of C-$Year-002, Prepare the March steering pack: how many days did it take you? My guess: 2 d.`"") effort-real-unclear

    Assert-Match $run.Output "  FAIL  file state/questions\.json has a line containing `"C-$Year-002`"" 'no open question'
    Assert-Match $run.Output "  FAIL  file \.\./agent-output\.txt has no line containing `"My guess`"" 'the question asked in the chat'
    Assert-Equal 1 $run.ExitCode 'exit code when the agent asks in the chat'
}

Test 'the scenario "morning meeting brief" passes when the meeting with Harbour Bank gets a brief from Harbour Bank''s subjects only, and fails when the calendar is not read' {
    $agent = "$FakeAgent -Snapshot `"$Fixtures\calendar.json`" -MeetingNotes `"$Fixtures\morning-notes.json`" -Morning -Say `"Brief: Send the pilot timeline to Harbour Bank [C-$Year-002]`""

    $run = Invoke-Scenarios -Agent $agent morning-meeting-brief

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    file views/morning\.html has no line containing `"<span class=`"id`">C-$Year-003</span>`"" 'the commitment of North Bank stays out of the brief'

    $run = Invoke-Scenarios -Agent "$FakeAgent -Morning" morning-meeting-brief

    Assert-Match $run.Output '  FAIL  file state/calendar\.json: meetings\[0\]\.status is "accepted"' 'no calendar snapshot'
    Assert-Match $run.Output '  FAIL  file views/morning\.html has lines containing' 'no meeting on the page'
    Assert-Equal 1 $run.ExitCode 'exit code when the calendar is not read'
}

Test 'the scenario "morning with the calendar off" passes when the meetings block says the calendar was not read, and fails when the agent reads it all the same' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Morning" morning-calendar-off

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file views/morning\.html has a line containing "not read: calendar</span></span></h2>"' 'the meetings block'

    $run = Invoke-Scenarios -Agent "$FakeAgent -Snapshot `"$Fixtures\calendar.json`" -Morning" morning-calendar-off

    Assert-Match $run.Output '  FAIL  file state/calendar\.json is absent' 'the calendar read although it is off'
    Assert-Equal 1 $run.ExitCode 'exit code when the calendar is read'
}

Test 'the scenario "morning start today" passes when the commitment due in three working days with two days of effort is under Start soon, to start today, and among the actions to do first, and fails when no page is written' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Morning" morning-start-today

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file views/morning\.html has lines containing, in this order: .*1 to start today' 'the line to start today'
    Assert-Match $run.Output '  ok    file views/morning\.html has lines containing, in this order: "id="h-first""' 'the line to start today among the actions to do first'

    $run = Invoke-Scenarios -Agent $FakeAgent morning-start-today

    Assert-Match $run.Output '  FAIL  file views/morning\.html has lines containing' 'no page'
    Assert-Equal 1 $run.ExitCode 'exit code when no page is written'
}

Test 'the scenario "morning steering week" passes when the day before the steering committee does not fit and the page proposes a way out, and fails when the calendar is not read' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Snapshot `"$Fixtures\steering-week-calendar.json`" -Morning" morning-steering-week

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file views/morning\.html has lines containing, in this order: .*<div class="suggest">' 'the way out'

    $run = Invoke-Scenarios -Agent "$FakeAgent -Morning" morning-steering-week

    Assert-Match $run.Output '  FAIL  file views/morning\.html has a line containing "<use href="#i-alert"/></svg> Does not fit</span>"' 'no day that does not fit'
    Assert-Equal 1 $run.ExitCode 'exit code when the calendar is not read'
}

Test 'the scenario "morning messages" passes when the chat message that asks the PO something is under the messages awaiting a reply and the one-to-one chat stays unread, and fails when the agent lists no message' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -MeetingNotes `"$Fixtures\messages-notes.json`" -Morning" morning-messages

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file views/morning\.html has lines containing, in this order: .*pilot branches' 'the message'

    $run = Invoke-Scenarios -Agent "$FakeAgent -Morning" morning-messages

    Assert-Match $run.Output '  FAIL  file views/morning\.html has lines containing' 'no message'
    Assert-Equal 1 $run.ExitCode 'exit code when no message is listed'
}

Test 'the scenario "morning reminders" passes when the late commitment owed to the PO is offered a reminder and the one due in three working days a nudge, both named to the PO and left open, and fails when the agent writes no page and names neither' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Morning -Say `"Shall I draft the reminder for C-$Year-002, and a nudge for C-$Year-003?`"" morning-reminders

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    file views/morning\.html has a line containing `"data-ask=`"Draft a nudge for C-$Year-003`"`"" 'the nudge'

    $run = Invoke-Scenarios -Agent $FakeAgent morning-reminders

    Assert-Match $run.Output "  FAIL  file views/morning\.html has a line containing `"data-ask=`"Draft the reminder for C-$Year-002`"`"" 'no reminder on the page'
    Assert-Match $run.Output "  FAIL  file \.\./agent-output\.txt has a line containing `"C-$Year-002`"" 'no reminder offered'
    Assert-Equal 1 $run.ExitCode 'exit code when nothing is offered'
}

Test 'the scenario "morning backlog" passes when the ticket still open for the plan a decision dropped is a contradiction, and fails when the agent finds none' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -MeetingNotes `"$Fixtures\backlog-notes.json`" -Morning" morning-backlog

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    file views/morning\.html has lines containing, in this order: .*against D-$Year-001" 'the contradiction'

    $run = Invoke-Scenarios -Agent "$FakeAgent -Morning" morning-backlog

    Assert-Match $run.Output '  FAIL  file views/morning\.html has lines containing' 'no contradiction'
    Assert-Equal 1 $run.ExitCode 'exit code when no contradiction is found'
}

Test 'the scenario "morning briefing" passes when the outcome of yesterday''s meeting is asked, its recommended answer and the PO''s corrected one are both applied and the page is written again, and fails when the briefing records nothing' {
    $due = @(1..9 | ForEach-Object { (Get-Date).Date.AddDays($_) } | Where-Object { 'Saturday', 'Sunday' -notcontains $_.DayOfWeek })[2].ToString('yyyy-MM-dd')
    New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
    $answers = Join-Path $TestRoot 'briefing.proposal.json'
    $source = @{ where = 'the PO, at the morning briefing'; read_on = $Day }
    Write-Json $answers @{ operations = @(
            @{ op = 'update'; id = "D-$Year-001"; interpreted = $false; source = $source; fields = @{ status = 'taken'; decided_by = 'the sponsor' } },
            @{ op = 'update'; id = "C-$Year-002"; interpreted = $false; source = $source; fields = @{ due_date = $due } }
        )
    }
    $run = Invoke-Scenarios -Agent "$FakeAgent -Questions `"$Fixtures\briefing-questions.json`" -Proposal `"$answers`" -Morning" morning-briefing

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    record D-$Year-001: status is `"taken`"" 'the recommended answer'
    Assert-Match $run.Output "  ok    record C-$Year-002: due_date is `"$due`"" 'the corrected answer'

    $run = Invoke-Scenarios -Agent "$FakeAgent -Morning" morning-briefing

    Assert-Match $run.Output "  FAIL  record D-$Year-001: status is `"taken`"" 'nothing recorded'
    Assert-Match $run.Output "  FAIL  file views/morning\.html has no line containing `"D-$Year-001`"" 'the page still awaits the decision'
    Assert-Equal 1 $run.ExitCode 'exit code when the briefing records nothing'
}

Test 'the scenario "morning briefing later" passes when the question of the collect is asked and, put off, is still listed the next day with its age, and fails when it leaves the list' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Questions `"$Fixtures\later-questions.json`" -Morning -Say `"Who writes the security file?`"" morning-briefing-later

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    what the register tool prints for morning -Today \S+ has a line containing ", open 1 working day\(s\): "' 'the age the next day'

    $run = Invoke-Scenarios -Agent "$FakeAgent -Morning -Say `"Who writes the security file?`"" morning-briefing-later

    Assert-Match $run.Output '  FAIL  file state/questions\.json has a line containing "security file"' 'the question left the list'
    Assert-Equal 1 $run.ExitCode 'exit code when the question left the list'
}

Test 'the scenario "subject open question" passes when the agent asks the open question of the subject the PO talks about, and fails when it asks that of another subject' {
    New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
    $change = Join-Path $TestRoot 'next-step.proposal.json'
    Write-Json $change @{ operations = @(@{ op = 'update'; id = 'mobile-onboarding'; interpreted = $false; source = @{ where = 'conversation with the PO'; read_on = $Day }; fields = @{ next_step = 'Run the pilot in two branches' } }) }

    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$change`" -Say `"Is the selfie check still in the scope of the onboarding pilot? Recommended: yes.`"" subject-open-question

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"

    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$change`" -Say `"Is the selfie check in scope? And does the payments API need card tokens?`"" subject-open-question

    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has no line containing "card tokens"' 'the question of another subject'
    Assert-Equal 1 $run.ExitCode 'exit code when the agent asks the question of another subject'
}
Test 'the scenario "collect and drop a line" passes when the line kept is recorded alone and the note is filed, and fails when the line dropped is recorded too' {
    $note = 'pilot-preparation.md'
    $kept = New-NoteOperation commitment $note @{ title = 'Send the security file of the pilot'; owner = 'the architect'; owed_to = 'the tech lead'; due_date = '2026-03-26'; date_of_fact = '2026-03-12' }
    $dropped = New-NoteOperation decision $note @{ title = 'Choose the branches of the pilot'; needed_from = 'the sponsor'; needed_by = '2026-03-27'; date_of_fact = '2026-03-12' }

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note @($kept)) collect-drop-a-line

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    record C-$Year-002: owner is `"the architect`"" 'the line kept'
    Assert-Match $run.Output "  ok    file inbox/done/$Month/pilot-preparation\.md is there" 'the note is filed all the same'

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $kept, $dropped) collect-drop-a-line

    Assert-Match $run.Output '  FAIL  register/decisions holds 0 record\(s\)\n        found: 1 record\(s\)' 'the line the PO dropped'
    Assert-Equal 1 $run.ExitCode 'exit code when the line dropped is recorded'
}

Test 'the scenario "collect with a pending proposal" passes when the pending proposal is left as it is, and fails when the collect replaces it' {
    $run = Invoke-Scenarios -Agent $FakeAgent collect-pending-proposal

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file state/proposal\.json: operations\[0\]\.fields\.title is "Book the committee room"' 'the pending proposal'

    $note = 'corridor-chat.md'
    $agent = New-CollectAgent $note @(New-NoteOperation commitment $note @{ title = 'Send the test plan of the pilot'; owner = 'the tech lead' }) -Do '-Pending'
    $run = Invoke-Scenarios -Agent $agent collect-pending-proposal

    Assert-Match $run.Output '  FAIL  file state/proposal\.json: operations\[0\]\.fields\.title is "Book the committee room"\n        found: "Send the test plan of the pilot"' 'the pending proposal overwritten'
    Assert-Equal 1 $run.ExitCode 'exit code when the pending proposal is overwritten'
}

Test 'the scenario "collect a pasted text" passes when the text is saved as an inbox note, which the record names as its source and which is then filed' {
    $note = "pasted-$Day.md"
    $agent = New-CollectAgent $note @(
        New-NoteOperation commitment $note @{ title = 'Send the corrected opening hours of the pilot branches'; subject = 'branch-opening-hours-page'; owner = 'the branch network manager'; owed_to = 'the PO'; due_date = '2026-03-31'; date_of_fact = '2026-03-13' }
    ) -Do "-Note $note"

    $run = Invoke-Scenarios -Agent $agent collect-pasted-text

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    record C-$Year-002: source\.where is `"inbox/pasted-$Day\.md`"" 'the record names the note'
    Assert-Match $run.Output "  ok    file inbox/done/$Month/pasted-$Day\.md has a line containing `"corrected opening hours`"" 'the note holds the pasted text, and is filed'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

# --- The collect scenarios of mail and tracker ---------------------------------------------------
# Mail and tickets are supplied as folders of exported files, exports/mail and exports/tracker, and
# the collect state of the scenario says how far an earlier collect read these sources.

function New-SourceRead([string]$Source, [int]$Items, [string]$Cutoff = '2026-03-12T08:30:00+01:00') {
    @{ source = $Source; cutoff = $Cutoff; items = $Items }
}

function New-ItemOperation([string]$Where, [hashtable]$Fields) {
    # One operation creating a commitment from a mail or a ticket, which its source names.
    New-RecordOperation commitment (@{ source = @{ where = $Where; read_on = '2026-03-12' } } + $Fields)
}

$MailRead = @{ sources_read = (New-SourceRead notes 0), (New-SourceRead mail 1); sources_not_covered = @('tracker') }

Test 'the scenario "collect mail outside every watch list" passes when the proposal holds the mail a watch list matched and nothing of the other, and fails when it quotes the other' {
    $matched = New-ItemOperation 'exports/mail/received/list of the onboarding screens.txt' @{ title = 'Send the list of the onboarding screens'; owner = 'the tech lead'; due_date = '2026-03-20'; date_of_fact = '2026-03-10' }

    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $matched -Do '-Pending' -Collect $MailRead) collect-mail-outside-watch-lists

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file state/proposal\.json: sources_read\[1\]\.items is 1' 'one mail is read'
    Assert-Match $run.Output '  ok    file state/proposal\.json has no line containing "permit"' 'the mail outside the watch lists is not quoted'
    Assert-Match $run.Output '  ok    file \.\./agent-output\.txt has no line containing "car park"' 'nor in what the agent printed'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"

    $quoted = $MailRead + @{ unclassified = @(@{ source = 'exports/mail/received/parking permits.txt'; text = 'Renew your parking permit before 20 March 2026.' }) }
    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $matched -Do '-Pending' -Collect $quoted) collect-mail-outside-watch-lists

    Assert-Match $run.Output '  FAIL  file state/proposal\.json has no line containing "permit"' 'the mail outside the watch lists quoted as unclassified'
    Assert-Match $run.Output '  FAIL  file state/proposal\.json: unclassified\[0\] is null' 'the unclassified item'
    Assert-Equal 1 $run.ExitCode 'exit code when the mail is quoted'

    # What the agent printed is checked too: its answer and, when its command prints them, the
    # files it opened.
    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $matched -Do '-Pending -Say "I left aside a notice: the car park closes for resurfacing."' -Collect $MailRead) collect-mail-outside-watch-lists

    Assert-Match $run.Output '  ok    file state/proposal\.json has no line containing "car park"' 'the proposal quotes nothing of the mail'
    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has no line containing "car park"' 'the mail outside the watch lists quoted in what the agent printed'
    Assert-Equal 1 $run.ExitCode 'exit code when the agent prints something of the mail'
}

Test 'the scenario "collect unclassified mail" passes when the mail a watch list matched, which fits no subject, lands in the unclassified list and yields no record' {
    $where = 'exports/mail/received/card dispute form.txt'
    $collect = $MailRead + @{ unclassified = @(@{ source = $where; text = 'The cards team looks for a product owner to review the wording of its card dispute form in April.' }) }

    $run = Invoke-Scenarios -Agent (New-CollectAgent @() @() -Collect $collect) collect-mail-unclassified

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    file state/unclassified\.md has a line containing `" \| $([regex]::Escape($where)) \| `"" 'the unclassified item names the mail'
    Assert-Match $run.Output '  ok    register/commitments holds 1 record\(s\)' 'no record'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "collect a sent mail" passes when the promise of the PO becomes a commitment owned by the PO, with the mail as its source' {
    $where = 'exports/mail/sent/scope of our contribution.txt'
    $promise = New-ItemOperation $where @{ title = 'Send the list of the API calls needed'; subject = 'payments-api-contribution'; owner = 'the PO'; owed_to = 'the head of payments'; due_date = '2026-03-20'; date_of_fact = '2026-03-11' }

    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $promise -Collect $MailRead) collect-sent-mail

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'owner is "the PO"', 'owed_to is "the head of payments"', 'due_date is "2026-03-20"', 'subject is "payments-api-contribution"', "source\.where is `"$([regex]::Escape($where))`"") {
        Assert-Match $run.Output "  ok    record C-$Year-002: $fact" 'expected fact reported as passed'
    }
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "collect a ticket" passes when the ticket of a watched project yields a record with the ticket as its source, and fails when the ticket of another project is recorded too, or shows in what the agent printed' {
    $watched = New-ItemOperation 'exports/tracker/ONB-142.txt' @{ title = 'Deliver the identity document scan screen'; owner = 'the tech lead'; due_date = '2026-03-27'; date_of_fact = '2026-03-11' }
    $other = New-ItemOperation 'exports/tracker/CRD-7.txt' @{ title = 'Rewrite the wording of the card dispute form'; owner = 'the cards analyst'; due_date = '2026-04-10' }
    $collect = @{ sources_read = (New-SourceRead notes 0), (New-SourceRead tracker 1); sources_not_covered = @('mail') }

    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $watched -Collect $collect) collect-ticket

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    record C-$Year-002: source\.where is `"exports/tracker/ONB-142\.txt`"" 'the ticket is the source of the record'
    Assert-Match $run.Output '  ok    file state/last-collect\.json: sources\.tracker\.items is 1' 'one ticket is read'
    Assert-Match $run.Output '  ok    file \.\./agent-output\.txt has no line containing "card dispute"' 'nothing of the ticket of another project in what the agent printed'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"

    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $watched, $other -Collect $collect) collect-ticket

    Assert-Match $run.Output '  FAIL  register/commitments holds 2 record\(s\)\n        found: 3 record\(s\)' 'the ticket of a project that no watch list names'
    Assert-Equal 1 $run.ExitCode 'exit code when the other ticket is recorded'

    # What the agent printed is checked too: its answer and, when its command prints them, the
    # files it opened.
    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $watched -Do '-Say "I left aside a ticket of the cards analyst, about the card dispute form."' -Collect $collect) collect-ticket

    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has no line containing "card dispute"' 'the ticket of another project in what the agent printed'
    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has no line containing "cards analyst"' 'the person the ticket names in what the agent printed'
    Assert-Equal 1 $run.ExitCode 'exit code when the agent prints something of the other ticket'
}

Test 'the scenario "collect with the tracker off" passes when the collect completes, the collect state lists the tracker as not covered and the stamp of the portfolio view says so' {
    $read = New-ItemOperation 'exports/mail/received/sequence diagrams.txt' @{ title = 'Send the sequence diagrams of the onboarding journey'; owner = 'the architect'; due_date = '2026-03-24'; date_of_fact = '2026-03-10' }

    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $read -Collect $MailRead) collect-tracker-off

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file state/last-collect\.json: not_covered is \["tracker"\]' 'the proposal listed the tracker as not covered'
    Assert-Match $run.Output '  ok    file views/portfolio\.md has a line containing "> Sources not covered by the last collect: tracker\."' 'the stamp of the portfolio view'
    Assert-Match $run.Output "  ok    record C-$Year-002: owner is `"the architect`"" 'the collect completed'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "collect up to the cap" passes when the two oldest mails are read, the cap is said reached and the cutoff is the date of the second, and fails when the third is read too' {
    $mails = @(
        (New-ItemOperation 'exports/mail/received/screens list.txt' @{ title = 'Send the list of the onboarding screens'; owner = 'the tech lead'; due_date = '2026-03-20'; date_of_fact = '2026-03-10' }),
        (New-ItemOperation 'exports/mail/received/sequence diagrams.txt' @{ title = 'Send the sequence diagrams of the onboarding journey'; owner = 'the architect'; due_date = '2026-03-25'; date_of_fact = '2026-03-11' }),
        (New-ItemOperation 'exports/mail/received/a reminder about the test accounts.txt' @{ title = 'Create the test accounts of the onboarding pilot'; owner = 'the tech lead'; due_date = '2026-03-27'; date_of_fact = '2026-03-12' })
    )
    $capped = @{ sources_read = (New-SourceRead notes 0), ((New-SourceRead mail 2 '2026-03-11T14:05:00+01:00') + @{ cap_reached = $true }); sources_not_covered = @('tracker') }

    $run = Invoke-Scenarios -Agent (New-CollectAgent @() ($mails[0, 1]) -Collect $capped) collect-cap

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'items is 2', 'cutoff is "2026-03-11T14:05:00\+01:00"', 'cap_reached is true') {
        Assert-Match $run.Output "  ok    file state/last-collect\.json: sources\.mail\.$fact" 'expected fact reported as passed'
    }
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"

    $whole = @{ sources_read = (New-SourceRead notes 0), (New-SourceRead mail 3); sources_not_covered = @('tracker') }
    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $mails -Collect $whole) collect-cap

    Assert-Match $run.Output '  FAIL  register/commitments holds 3 record\(s\)\n        found: 4 record\(s\)' 'the mail beyond the cap'
    Assert-Match $run.Output '  FAIL  file state/last-collect\.json: sources\.mail\.cap_reached is true\n        found: false' 'the cap not said reached'
    Assert-Equal 1 $run.ExitCode 'exit code when the collect reads beyond the cap'
}

Test 'the scenario "collect with nothing new" passes when the collect records nothing and still says that the sources were read, and fails when it leaves the collect state as it was or proposes again what an earlier collect read' {
    # A proposal with no operation, applied at once: the collect state moves to the time of this collect.
    $now = "${Day}T08:30:00+01:00"
    $quiet = @{ collected_at = $now; sources_read = (New-SourceRead notes 0 $now), (New-SourceRead mail 0 $now), (New-SourceRead tracker 0 $now); sources_not_covered = @() }

    $run = Invoke-Scenarios -Agent (New-CollectAgent @() @() -Collect $quiet) collect-nothing-new

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file state/proposal\.json is absent' 'no proposal waits'
    Assert-Match $run.Output '  ok    register/commitments holds 1 record\(s\)' 'no record'
    Assert-Match $run.Output '  ok    file state/last-collect\.json has no line containing "2026-03-12T08:30:00\+01:00"' 'the collect state moved'
    Assert-Match $run.Output "  ok    file state/last-collect\.json has a line containing `"${Day}T`"" 'to the day of the run'

    $run = Invoke-Scenarios -Agent $FakeAgent collect-nothing-new

    Assert-Match $run.Output '  FAIL  file state/last-collect\.json has no line containing "2026-03-12T08:30:00\+01:00"' 'the collect state left as it was'
    Assert-Equal 1 $run.ExitCode 'exit code when the collect state does not move'

    $again = New-ItemOperation 'exports/mail/received/list of the onboarding screens.txt' @{ title = 'Send the list of the onboarding screens'; owner = 'the tech lead'; due_date = '2026-03-20' }
    $collect = @{ sources_read = (New-SourceRead notes 0), (New-SourceRead mail 1), (New-SourceRead tracker 0); sources_not_covered = @() }
    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $again -Do '-Pending' -Collect $collect) collect-nothing-new

    Assert-Match $run.Output '  FAIL  file state/proposal\.json is absent' 'the mail read before its cutoff is proposed again'
    Assert-Equal 1 $run.ExitCode 'exit code when something is proposed'
}

Test 'the scenario "collect with a connector that fails" passes when the connections record the failed verification, the tracker is not covered and the collect goes on' {
    $note = 'call with the tech lead.md'
    $connections = Join-Path $TestRoot 'failed.connections.json'
    Write-Json $connections ([ordered]@{
            notes   = @{ mode = 'folder' }
            mail    = @{ mode = 'off' }
            tracker = [ordered]@{ mode = 'connector'; connector = 'Example Bank tracker'; verified = [ordered]@{ result = 'failed'; on = $Day; detail = 'no connector of that name on this machine' } }
        })
    $action = New-NoteOperation commitment $note @{ title = 'Send the test plan of the onboarding pilot'; owner = 'the tech lead'; owed_to = 'the PO'; due_date = '2026-03-26'; date_of_fact = '2026-03-12' }

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $action -Do "-Connections `"$connections`"") collect-connector-fails

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file connections\.json: tracker\.verified\.result is "failed"' 'the result of the verification'
    Assert-Match $run.Output "  ok    file connections\.json: tracker\.verified\.on is `"$Day`"" 'the date of the verification'
    Assert-Match $run.Output '  ok    file state/last-collect\.json: not_covered is \["mail","tracker"\]' 'the tracker is not covered'
    Assert-Match $run.Output "  ok    record C-$Year-002: owner is `"the tech lead`"" 'the collect went on'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $action) collect-connector-fails

    Assert-Match $run.Output '  FAIL  file connections\.json: tracker\.verified\.result is "failed"\n        found: null' 'the verification left unrecorded'
    Assert-Equal 1 $run.ExitCode 'exit code when the verification is not recorded'
}

# --- The collect scenarios of chat ---------------------------------------------------------------
# Chat is supplied as a folder of exported files, exports/chat, one file per message under the
# folder of its channel, its group chat or its one-to-one chat.

$ChatRead = @{ sources_read = (New-SourceRead notes 0), (New-SourceRead chat 1); sources_not_covered = @('mail', 'tracker') }

Test 'the scenario "collect chat" passes when the message of a channel a watch list names yields a record with the message as its source, and fails when a message of another channel or of a one-to-one chat is quoted, or shows in what the agent printed' {
    $named = New-ItemOperation 'exports/chat/channels/onboarding squad/2026-03-10 0915 the tech lead.txt' @{ title = 'Create the test accounts of the onboarding pilot'; owner = 'the tech lead'; due_date = '2026-03-25'; date_of_fact = '2026-03-10' }

    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $named -Do '-Pending' -Collect $ChatRead) collect-chat

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file state/proposal\.json: operations\[0\]\.fields\.source\.where is "exports/chat/channels/onboarding squad/2026-03-10 0915 the tech lead\.txt"' 'the message is the source of the record'
    Assert-Match $run.Output '  ok    file state/proposal\.json: sources_read\[1\]\.items is 1' 'one message is read'
    Assert-Match $run.Output '  ok    file \.\./agent-output\.txt has no line containing "vendor"' 'nothing of the one-to-one chat in what the agent printed'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"

    $private = New-ItemOperation 'exports/chat/one-to-one/the tech lead/2026-03-10 1130 the tech lead.txt' @{ title = 'The onboarding vendor is late again'; owner = 'the tech lead' }
    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $named, $private -Do '-Pending' -Collect $ChatRead) collect-chat

    Assert-Match $run.Output '  FAIL  file state/proposal\.json has no line containing "vendor"' 'the one-to-one chat quoted in the proposal'
    Assert-Equal 1 $run.ExitCode 'exit code when the one-to-one chat is read'

    $other = $ChatRead + @{ unclassified = @(@{ source = 'exports/chat/channels/branch staff/2026-03-10 1000 the head of cards.txt'; text = 'The staff canteen moves to the second floor.' }) }
    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $named -Do '-Pending' -Collect $other) collect-chat

    Assert-Match $run.Output '  FAIL  file state/proposal\.json has no line containing "canteen"' 'the message of a channel no watch list names, quoted as unclassified'
    Assert-Equal 1 $run.ExitCode 'exit code when the message of another channel is read'

    # What the agent printed is checked too: its answer and, when its command prints them, the
    # files it listed and opened. Even the name of a one-to-one chat is private.
    $run = Invoke-Scenarios -Agent (New-CollectAgent @() $named -Do '-Pending -Say "I left aside a private message, 2026-03-10 1130 the tech lead.txt: the onboarding vendor is late again."' -Collect $ChatRead) collect-chat

    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has no line containing "vendor"' 'the one-to-one chat in what the agent printed'
    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has no line containing "1130 the tech lead"' 'the name of the one-to-one chat in what the agent printed'
    Assert-Equal 1 $run.ExitCode 'exit code when the agent prints something of the one-to-one chat'
}

Test 'the scenario "collect with chat off" passes when the collect completes, the collect state lists chat as not covered and the stamp of the portfolio view says so' {
    $note = 'call with the architect.md'
    $action = New-NoteOperation commitment $note @{ title = 'Send the sequence diagrams of the onboarding journey'; owner = 'the architect'; owed_to = 'the PO'; due_date = '2026-03-24'; date_of_fact = '2026-03-11' }

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $action -Collect @{ sources_not_covered = @('mail', 'tracker', 'chat') }) collect-chat-off

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file state/last-collect\.json: not_covered is \["mail","tracker","chat"\]' 'chat is not covered'
    Assert-Match $run.Output '  ok    file views/portfolio\.md has a line containing "> Sources not covered by the last collect: mail, tracker, chat\."' 'the stamp of the portfolio view'
    Assert-Match $run.Output "  ok    record C-$Year-002: owner is `"the architect`"" 'the collect completed'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"

    $run = Invoke-Scenarios -Agent (New-CollectAgent $note $action) collect-chat-off

    Assert-Match $run.Output '  FAIL  file state/last-collect\.json: not_covered is \["mail","tracker","chat"\]' 'chat left out of what was not covered'
    Assert-Equal 1 $run.ExitCode 'exit code when chat is not listed as not covered'
}

# --- The weekly synthesis scenarios --------------------------------------------------------------
# A scenario that starts after a collect gives the proposal of that collect, which the runner has
# the register tool apply before the agent starts. The fake agent stores a synthesis written ahead,
# under tests\fixtures\weekly, with the stamp and the portfolio view that export prints.

function New-WeeklyAgent([string]$Synthesis, [scriptblock]$Change = { $args[0] }) {
    # The command of a fake agent that stores this synthesis of tests\fixtures\weekly, where {year}
    # is the year of the run. $Change rewrites its text first.
    New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
    $path = Join-Path $TestRoot ([Guid]::NewGuid().ToString('N').Substring(0, 8) + '.weekly.md')
    $text = [IO.File]::ReadAllText((Join-Path $Fixtures "weekly\$Synthesis.md"), $Utf8).Replace('{year}', $Year)
    [IO.File]::WriteAllText($path, (& $Change $text), $Utf8)
    "$FakeAgent -Weekly `"$path`""
}

Test 'the scenario "weekly after a decision" passes when the synthesis cites the decision and announces no presentation, and fails when it still cites the superseded commitment' {
    $run = Invoke-Scenarios -Agent (New-WeeklyAgent after-decision) weekly-after-decision

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    record C-$Year-001: superseded_by is `"D-$Year-001`"" 'the collect the scenario gives was applied before the agent started'
    Assert-Match $run.Output "  ok    the register tool verifies views/weekly/$Day\.md" 'the verdict of verify'
    Assert-Match $run.Output "  ok    every record that views/weekly/$Day\.md cites is in the export since 2026-03-03" 'the records cited are those of the export of the period'
    Assert-Match $run.Output "  ok    file views/weekly/$Day\.md has lines containing, in this order: `"# Portfolio view`", .*`"## Now`", .*`"# Not covered this week`"" 'the portfolio view, then the blocks in order'
    Assert-Match $run.Output "  ok    file views/weekly/$Day\.md has no line containing `"2026-03-16`"" 'the date of the presentation'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"

    $announced = { $args[0].Replace('No commitment is open.', "- Present the target journey to the retail steering committee: the PO, due 2026-03-16 [C-$Year-001]") }
    $run = Invoke-Scenarios -Agent (New-WeeklyAgent after-decision $announced) weekly-after-decision

    Assert-Match $run.Output "  FAIL  the register tool verifies views/weekly/$Day\.md\n        found: Not verified: views/weekly/$Day\.md\n- C-$Year-001 is superseded by D-$Year-001\." 'the superseded commitment, named by verify'
    Assert-Match $run.Output "  FAIL  every record that views/weekly/$Day\.md cites is in the export since 2026-03-03\n        found: not in the export: C-$Year-001" 'the superseded commitment, which the export leaves out'
    Assert-Match $run.Output "  FAIL  file views/weekly/$Day\.md has no line containing `"2026-03-16`"" 'the presentation still announced'
    Assert-Match $run.Output '  FAIL  file views/weekly/\S+ has lines containing, in this order: "# Progress and commitments", .*\n        found: no line containing "No commitment is open\." further down' 'the commitment still listed as open'
    Assert-Equal 1 $run.ExitCode 'exit code when the presentation is still announced'
}

Test 'the scenario "weekly with a commitment without a due date" passes when the synthesis lists it as having no due date and the decision expected from the sponsor with its date, and fails when the blocks are not in order' {
    $run = Invoke-Scenarios -Agent (New-WeeklyAgent no-due-date) weekly-no-due-date

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    file views/weekly/$Day\.md has lines containing, in this order: `"Open commitments:`", `"no due date`", `"# Proposed priorities`"" 'the commitment without a due date'
    Assert-Match $run.Output "  ok    file views/weekly/$Day\.md has lines containing, in this order: `"Decisions expected from the sponsor:`", `"2026-03-27`", `"# Team capacity`"" 'the date the decision is needed by'
    Assert-Match $run.Output "  ok    file views/weekly/$Day\.md has lines containing, in this order: `"# Team capacity`", `"The PO provided no statement on team capacity\.`"" 'no sentence on team capacity'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"

    # The block of team capacity moved above the proposed priorities.
    $moved = {
        $capacity = "# Team capacity`n`nThe PO provided no statement on team capacity.`n`n"
        ($args[0] -replace '\r\n', "`n").Replace($capacity, '').Replace('# Proposed priorities', "$capacity# Proposed priorities")
    }
    $run = Invoke-Scenarios -Agent (New-WeeklyAgent no-due-date $moved) weekly-no-due-date

    Assert-Match $run.Output '  FAIL  file views/weekly/\S+ has lines containing, in this order: "# Portfolio view", .*\n        found: no line containing "# Team capacity" further down' 'the blocks out of order'
    Assert-Equal 1 $run.ExitCode 'exit code when the blocks are not in order'
}

Test 'the scenario "weekly with a source off" passes when the stamp and the block of what is not covered both name the tracker, and the block names the mail read in part, and fails when the block names neither' {
    $run = Invoke-Scenarios -Agent (New-WeeklyAgent source-off) weekly-source-off

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '"> Sources not covered by the last collect: tracker\.", .*"# Not covered this week", "tracker"' 'the stamp and the block name the tracker'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"

    $covered = { ($args[0] -replace '(?s)(# Not covered this week\r?\n\r?\n).*$', '$1Every source was covered by the last collect.') + "`n" }
    $run = Invoke-Scenarios -Agent (New-WeeklyAgent source-off $covered) weekly-source-off

    Assert-Match $run.Output '  FAIL  file views/weekly/\S+ has lines containing, in this order: .*\n        found: no line containing "tracker" further down' 'the source off left out of the block'
    Assert-Match $run.Output '  FAIL  file views/weekly/\S+ has lines containing, in this order: "# Not covered this week", "mail"' 'the source read in part left out of the block'
    Assert-Equal 1 $run.ExitCode 'exit code when the block names no source'
}

Test 'the scenario "weekly in the language of the sponsor" passes when the six blocks and the labels of the portfolio view are in French, and the portfolio view of the workspace stays in the default language' {
    $run = Invoke-Scenarios -Agent (New-WeeklyAgent sponsor-language) weekly-sponsor-language

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "  ok    file views/weekly/$Day\.md has lines containing, in this order: `"# Vue portefeuille`", .*`"## Maintenant`", .*`"# Non couvert cette semaine`"" 'the portfolio view and the blocks in French'
    Assert-Match $run.Output "  ok    the register tool verifies views/weekly/$Day\.md" 'the verdict of verify'
    Assert-Match $run.Output '  ok    file views/portfolio\.md has lines containing, in this order: "# Portfolio view", "## Now"' 'the portfolio view of the workspace'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}

Test 'the scenario "weekly with errors in the check" passes when the agent shows the errors and stores no synthesis, and fails when it stores one' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Check -Say `"The check found errors: the gate security review is not listed in the settings.`"" weekly-check-errors

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file views/check-report\.md has a line containing "### Unknown field or value"' 'the error the scenario plants'
    Assert-Match $run.Output "  ok    file views/weekly/$Day\.md is absent" 'no synthesis is stored'

    $run = Invoke-Scenarios -Agent "$(New-WeeklyAgent source-off) -Check" weekly-check-errors

    Assert-Match $run.Output "  FAIL  file views/weekly/$Day\.md is absent" 'the synthesis stored in spite of the errors'
    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has a line containing "security review"' 'the errors not shown'
    Assert-Equal 1 $run.ExitCode 'exit code when a synthesis is stored'
}

Test 'the scenario "weekly that verify refuses" passes when the agent names what failed and leaves no synthesis stored, and fails when it leaves one' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Say `"Not verified: D-2025-031 is not in the register. No synthesis is stored and no mail draft was created.`"" weekly-verify-fails

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file \.\./agent-output\.txt has a line containing "D-2025-031"' 'what failed is named'

    # A synthesis that leaves out the record the PO cites, which the register does not hold.
    $run = Invoke-Scenarios -Agent (New-WeeklyAgent source-off) weekly-verify-fails

    Assert-Match $run.Output "  FAIL  file views/weekly/$Day\.md is absent" 'the synthesis left stored without what the PO said'
    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has a line containing "D-2025-031"' 'what failed is not named'
    Assert-Equal 1 $run.ExitCode 'exit code when a synthesis is left stored'
}

Test 'the scenario "weekly without a start date" passes when the agent asks for the date and stores no synthesis, and fails when it stores one' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Say `"No synthesis is stored yet: on which date does the period start?`"" weekly-no-start-date

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  ok    file \.\./agent-output\.txt has a line containing "period"' 'the agent speaks of the period'
    Assert-Match $run.Output "  ok    file views/weekly/$Day\.md is absent" 'no synthesis is stored'

    $run = Invoke-Scenarios -Agent (New-WeeklyAgent source-off) weekly-no-start-date

    Assert-Match $run.Output '  FAIL  file \.\./agent-output\.txt has a line containing "period"' 'nothing asked about the period'
    Assert-Match $run.Output "  FAIL  file views/weekly/$Day\.md is absent" 'the synthesis stored on a date of its own'
    Assert-Equal 1 $run.ExitCode 'exit code when a synthesis is stored'
}

Test 'when the agent does nothing, each fact is reported as passed or failed with what was found, the folder is kept and the run fails' {
    $run = Invoke-Scenarios -Agent $FakeAgent subject-modify

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  FAIL  record payments-api-contribution: horizon is "now"\n        found: "next"' 'a field that holds another value'
    Assert-Match $run.Output '  FAIL  record payments-api-contribution: history\[0\]\.field is "horizon"\n        found: null' 'a field that holds nothing'
    Assert-Match $run.Output '  FAIL  record branch-opening-hours-page: status is "closed"\n        found: "active"' 'the subject that was to be closed'
    Assert-Match $run.Output '  ok    record payments-api-contribution: status is "active"' 'a fact that holds all the same'
    Assert-Match $run.Output '  ok    register/subjects holds 3 record\(s\)' 'a fact that holds all the same'
    Assert-Match $run.Output '1 scenario\(s\): 0 passed, 1 failed' 'verdict'
    Assert-True ($run.Output -match '(?m)^Kept: (.+)$') "the run does not say where its folder is kept: $($run.Output)"
    $kept = $Matches[1].Trim()
    Assert-True (Test-Path (Join-Path $kept 'subject-modify\workspace\register\subjects\payments-api-contribution.json')) 'the workspace of the failed scenario was not kept'
}

Test 'the agent is started in a temporary Example Bank workspace, and its prompt names the routine installed for the scenario and gives what the PO says' {
    $report = Join-Path $TestRoot 'agent-report.txt'

    $run = Invoke-Scenarios -Agent "$FakeAgent -Report `"$report`"" subject-modify

    $startedIn, $prompt = (Get-Content -LiteralPath $report -Raw -Encoding UTF8) -split "`n", 2
    Assert-Match $startedIn ('^' + [regex]::Escape($TestRoot) + '\\po-kit-scenarios-\w+\\subject-modify\\workspace$') 'folder the agent is started in'
    Assert-True ($prompt -match '(?m)^Follow the routine written in this file: (.+)$') "the prompt names no routine: $prompt"
    $routine = $Matches[1].Trim()
    Assert-Match $routine ('^' + [regex]::Escape($TestRoot) + '\\po-kit-scenarios-\w+\\subject-modify\\skills\\subject\\SKILL\.md$') 'routine named in the prompt'
    Assert-Equal (Get-FileHash (Join-Path $KitRoot 'routines\subject\SKILL.md')).Hash (Get-FileHash $routine).Hash "the routine installed against the kit's"
    Assert-Match $prompt 'The PO says:\nTwo changes to my subjects\. Move the Payments API contribution from Next to Now\.' 'what the PO says'

    $workspace = $startedIn.Trim()
    $settings = Read-Json (Join-Path $workspace 'settings.json')
    Assert-Equal 'architecture review, security review' ($settings.gates -join ', ') 'gates of Example Bank'
    Assert-Equal 2 @($settings.objectives).Count 'objectives of Example Bank'
    Assert-Equal 'The sponsor' $settings.sponsor.name 'sponsor of Example Bank'
    Assert-Equal 'mobile-onboarding' (Read-Json (Join-Path $workspace 'register\subjects\mobile-onboarding.json')).id 'a subject of Example Bank, recorded by the register tool'
    Assert-Equal '' "$(git -C $workspace status --porcelain register)" 'changes to the register left out of its history'
}

Test 'a scenario given as a folder lays its own files over the workspace, and every kind of fact is checked exactly: records, fields, files, lines, their order and the verdict of verify' {
    $run = Invoke-Scenarios -Agent $FakeAgent (Join-Path $Fixtures 'scenarios\every-kind-of-fact')

    $expected = @(
        'every-kind-of-fact'
        '  ok    the agent ran to its end'
        '  ok    record mobile-onboarding is there'
        '  FAIL  record card-dispute-portal is there'
        '        found: it is absent'
        '  ok    record card-dispute-portal is absent'
        '  FAIL  record mobile-onboarding is absent'
        '        found: it is there'
        '  ok    record mobile-onboarding: gates[-1].state is "planned"'
        '  ok    record mobile-onboarding: next_date is null'
        '  FAIL  record mobile-onboarding: watch_list.people is ["the architect","the tech lead"]'
        '        found: ["the tech lead","the architect"]'
        '  FAIL  record mobile-onboarding: kind is "Product"'
        '        found: "product"'
        '  FAIL  record card-dispute-portal: kind is "product"'
        '        found: nothing: it is absent'
        '  FAIL  register/subjects holds 2 record(s)'
        '        found: 3 record(s)'
        '  ok    file inbox/steering committee.md is there'
        '  FAIL  file inbox/done/steering committee.md is there'
        '        found: it is absent'
        '  ok    file state/proposal.json: operations[0].fields.title is "Card dispute portal"'
        '  ok    file views/weekly/2026-03-02.md has a line containing "Mobile onboarding"'
        '  FAIL  file views/weekly/2026-03-02.md has a line containing "mobile onboarding"'
        '        found: no such line'
        '  ok    file views/weekly/2026-03-02.md has no line containing "Savings simulator"'
        '  FAIL  file views/weekly/2026-03-02.md has no line containing "Mobile onboarding"'
        '        found: - Mobile onboarding: cleared by the sponsor.'
        '  FAIL  file views/weekly/2026-03-09.md has a line containing "Mobile onboarding"'
        '        found: nothing: it is absent'
        '  ok    file views/weekly/2026-03-02.md has lines containing, in this order: "# Weekly synthesis", "## Now", "Mobile onboarding"'
        '  FAIL  file views/weekly/2026-03-02.md has lines containing, in this order: "# Weekly synthesis", "Mobile onboarding", "## Now"'
        '        found: no line containing "## Now" further down'
        '  FAIL  file views/weekly/2026-03-09.md has lines containing, in this order: "# Weekly synthesis", "## Now"'
        '        found: nothing: it is absent'
        '  FAIL  the register tool verifies views/weekly/2026-03-02.md'
        '        found: Not verified: views/weekly/2026-03-02.md'
        '- The stamp is absent, or not whole as the register tool gives it. export prints the stamp of the view to write from it.'
        '  ok    the register holds only what the register tool committed'
    ) -join "`n"
    Assert-True $run.Output.Contains($expected) "the report differs from:`n$expected`ngot:`n$($run.Output)"
    Assert-Equal 1 $run.ExitCode 'exit code'
}

Test 'a stored synthesis passes the fact on the export when every record it cites is in the export of its period, and fails it for a record that verify accepts and the export leaves out' {
    $scenario = Join-Path $Fixtures 'scenarios\cites-a-closed-subject'

    $run = Invoke-Scenarios -Agent (New-WeeklyAgent source-off) $scenario

    Assert-Match $run.Output "  ok    the register tool verifies views/weekly/$Day\.md" 'the verdict of verify'
    Assert-Match $run.Output "  ok    every record that views/weekly/$Day\.md cites is in the export since 2026-03-09" 'the records cited are in the export'
    Assert-Match $run.Output '  FAIL  every record that views/weekly/2026-03-09\.md cites is in the export since 2026-03-09\n        found: nothing: it is absent' 'a view that is not stored'

    # A closed subject is still a record to cite for verify, and the export of the period leaves it out.
    $closed = { $args[0].Replace('No blocker is recorded.', '- The opening hours page was handed over [branch-opening-hours-page, mobile-onboarding]') }
    $run = Invoke-Scenarios -Agent (New-WeeklyAgent source-off $closed) $scenario

    Assert-Match $run.Output "  ok    the register tool verifies views/weekly/$Day\.md" 'the verdict of verify on the closed subject'
    Assert-Match $run.Output "  FAIL  every record that views/weekly/$Day\.md cites is in the export since 2026-03-09\n        found: not in the export: branch-opening-hours-page" 'the closed subject, named'
    Assert-Equal 1 $run.ExitCode 'exit code'
}

Test 'a record that the agent writes itself, without the register tool, fails the scenario' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -ByHand" (Join-Path $Fixtures 'scenarios\every-kind-of-fact')

    Assert-Match $run.Output '  FAIL  the register holds only what the register tool committed\n        found: \?\? register/subjects/written-by-hand\.json' 'the record written by hand'
    Assert-Equal 1 $run.ExitCode 'exit code'
}

Test 'an agent that ends on a failure code fails the scenario, whatever the register holds' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenario-create.proposal.json`" -ExitCode 3" subject-create

    Assert-Match $run.Output '  FAIL  the agent ran to its end\n        found: exit code 3' 'the failure of the agent'
    Assert-Match $run.Output '  ok    record savings-simulator: kind is "product"' 'the facts are checked all the same'
    Assert-Match $run.Output '1 scenario\(s\): 0 passed, 1 failed' 'verdict'
    Assert-Equal 1 $run.ExitCode 'exit code'
}

Test 'several scenarios run in one go, each with its own verdict; a name that is no scenario is a failure' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenario-create.proposal.json`"" subject-create no-such-scenario

    Assert-Match $run.Output 'subject-create\n  ok    the agent ran to its end' 'the scenario that exists'
    Assert-Match $run.Output "no-such-scenario\n  FAIL  no scenario 'no-such-scenario'" 'the name that is no scenario'
    Assert-Match $run.Output '2 scenario\(s\): 1 passed, 1 failed' 'verdict'
    Assert-Equal 1 $run.ExitCode 'exit code'
}

Test 'without the command that starts the agent, the runner explains itself and runs nothing' {
    $run = Invoke-Scenarios subject-create

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'scenarios\\run\.ps1 -Agent "<command>"' 'how to call the runner'
    Assert-True ($run.Output -notmatch 'subject-create') "a scenario was run: $($run.Output)"
}

Test 'in the files a scenario lays over the workspace, {today}, {month} and {year} stand for those of the day of the run, {workday+N} for the Nth working day after it and {workday-N} before it, as in scenario.json' {
    $run = Invoke-Scenarios -Agent $FakeAgent (Join-Path $Fixtures 'scenarios\dated-workspace')

    Assert-Match $run.Output "  ok    file exports/calendar/stand-up\.txt has a line containing `"Start: ${Day}T09:30:00\+01:00`"" 'the date of the run in a file of the scenario'
    $weekdays = @(1..7 | ForEach-Object { (Get-Date).Date.AddDays($_) } | Where-Object { 'Saturday', 'Sunday' -notcontains $_.DayOfWeek })
    Assert-Match $run.Output "  ok    file exports/calendar/stand-up\.txt has a line containing `"Due: $($weekdays[2].ToString('yyyy-MM-dd'))`"" 'the third working day after the run in a file of the scenario'
    $before = @(1..7 | ForEach-Object { (Get-Date).Date.AddDays(-$_) } | Where-Object { 'Saturday', 'Sunday' -notcontains $_.DayOfWeek })[0]
    Assert-Match $run.Output "  ok    file exports/calendar/stand-up\.txt has a line containing `"Before: $($before.ToString('yyyy-MM-dd'))`"" 'the working day before the run in a file of the scenario'
}

Test 'the Example Bank settings carry every setting of the template, so the register tool reads them as it reads any workspace; so do the settings a scenario lays over them' {
    $names = { param($Path) ((Read-Json $Path).PSObject.Properties | ForEach-Object { $_.Name }) -join ', ' }

    foreach ($settings in Get-ChildItem (Join-Path $KitRoot 'scenarios\*\workspace\settings.json')) {
        Assert-Equal (& $names (Join-Path $KitRoot 'workspace-template\settings.json')) (& $names $settings.FullName) "settings of $($settings.Directory.Parent.Name)"
    }
}
