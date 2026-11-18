# Source readiness: what a subject has to follow in each source, what each connection can search,
# a watch-list entry that waits for the PO and is read back seven days, a question that waits for
# its day, and a watch list that follows single tickets.

function Set-Connections([string]$Workspace, [hashtable]$Entries) {
    $connections = Read-Json (Join-Path $Workspace 'connections.json')
    foreach ($name in $Entries.Keys) { $connections.$name = $Entries[$name] }
    Write-Json (Join-Path $Workspace 'connections.json') $connections
}

function New-ReadinessWorkspace([hashtable]$Watch = @{ people = @('the tech lead') }, [string]$Horizon = 'now') {
    # A workspace of Example Bank with mail and the tracker read from folders, chat off, and one
    # subject whose watch list is $Watch.
    $ws = New-TestWorkspace
    Set-Connections $ws @{ mail = @{ mode = 'folder'; folder = 'exports/mail' }; tracker = @{ mode = 'folder'; folder = 'exports/tracker' } }
    Set-Proposal $ws @{ operations = @((New-SubjectOperation @{ horizon = $Horizon; watch_list = $Watch })) }
    $run = Invoke-Register $ws apply -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "seed, with output: $($run.Output)"
    $ws
}

function Set-MailRead([string]$Workspace, [string]$Cutoff = '2026-03-09T18:00:00+01:00') {
    # The collect state of a workspace whose mail was read up to $Cutoff.
    Write-Json (Join-Path $Workspace 'state\last-collect.json') @{
        collected_at = $Cutoff; not_covered = @()
        sources = @{ mail = @{ cutoff = $Cutoff; items = 0; collected_at = $Cutoff; cap_reached = $false } }
    }
    & git -C $Workspace add -A state
    & git -C $Workspace commit -q -m 'Mail read'
}

function Read-CheckReport([string]$Workspace) {
    $run = Invoke-Register $Workspace check -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "check, with output: $($run.Output)"
    [IO.File]::ReadAllText((Join-Path $Workspace 'views\check-report.md'))
}

Test 'a subject under Now with nothing to follow in a source that is on is warned of, and morning names it; not under Later, not in a source that is off' {
    $ws = New-ReadinessWorkspace
    $report = Read-CheckReport $ws
    Assert-Match $report 'Subject under Now or Next with nothing to follow in a source that is on' 'rule of the gap'
    Assert-Match $report 'nothing to follow in: tracker' 'the tracker, which the watch list gives nothing for'
    Assert-True ($report -notmatch 'nothing to follow in: [^\n]*mail') 'mail has a person to follow'
    Assert-True ($report -notmatch 'nothing to follow in: [^\n]*chat') 'chat is off'
    $run = Invoke-Register $ws morning -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "morning, with output: $($run.Output)"
    Assert-Match $run.Output 'Nothing to follow: Mobile onboarding \[mobile-onboarding\] in tracker\.' 'what morning prints for the routine'

    $later = New-ReadinessWorkspace @{} 'later'
    Assert-True ((Read-CheckReport $later) -notmatch 'nothing to follow') 'a subject under Later is not chased'
}

Test 'a watch list that follows a single ticket fills the gap of the tracker' {
    $ws = New-ReadinessWorkspace @{ people = @('the tech lead'); tracker_tickets = @('ONB-177') }
    $subject = Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')
    Assert-Equal 'ONB-177' "$($subject.watch_list.tracker_tickets)" 'the ticket followed'
    Assert-True ((Read-CheckReport $ws) -notmatch 'nothing to follow') 'no gap'
}

Test 'a connector verified names the searches it cannot make and those never tested; one not verified is not judged' {
    $ws = New-ReadinessWorkspace @{ people = @('the tech lead'); tracker_projects = @('ONB') }
    Set-Connections $ws @{
        mail    = @{ mode = 'connector'; connector = 'mailbox'; verified = @{ result = 'ok'; on = '2026-03-09' } }
        chat    = @{ mode = 'connector'; connector = 'messages'; verified = @{ result = 'ok'; on = '2026-03-09'; searches = @{ channel = $true; person = $true; keyword = $false } } }
        tracker = @{ mode = 'connector'; connector = 'tickets' }
    }
    $report = Read-CheckReport $ws
    Assert-Match $report 'Search a connection cannot make, or never tested' 'rule of the searches'
    Assert-Match $report 'chat[^\n]*cannot search the other one-to-one messages that hold a keyword' 'what chat cannot search'
    Assert-Match $report 'mail[^\n]*never tested: the mail of a person, the mail that holds a keyword' 'what mail never tested'
    Assert-True ($report -notmatch 'tracker[^\n]*(cannot search|never tested)') 'the tracker, not verified, is not judged'
    $run = Invoke-Register $ws morning -Now '2026-03-10T09:00:00+01:00'
    Assert-Match $run.Output 'Search limit of chat: cannot search the other one-to-one messages that hold a keyword\.' 'what morning prints for the routine'
}

Test 'a line that adds to a watch list waits for the PO in apply plain, and preview says what following a person opens in chat' {
    $ws = New-ReadinessWorkspace
    Set-Connections $ws @{ chat = @{ mode = 'folder'; folder = 'exports/chat' } }
    & git -C $ws add -A connections.json
    & git -C $ws commit -q -m 'Chat on'
    $widen = New-UpdateOperation 'mobile-onboarding' @{ watch_list = @{ people = @('the tech lead', 'the architect'); tracker_projects = @('ONB') } }
    $narrow = New-UpdateOperation 'mobile-onboarding' @{ next_step = 'Agree the pilot branches' }
    Set-Proposal $ws @{ operations = @((New-RecordOperation commitment), $widen) }
    $preview = Invoke-Register $ws preview
    Assert-Match $preview.Output 'adds to the watch list, which waits for the PO even in apply plain: people: the architect, tracker_projects: ONB' 'what the line adds'
    Assert-Match $preview.Output 'reads in full the one-to-one chat of the PO with: the architect' 'what following the person opens'

    $run = Invoke-Register $ws apply plain -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "apply plain, with output: $($run.Output)"
    Assert-Equal 'the tech lead' "$((Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')).watch_list.people)" 'the watch list, not widened'
    $pending = Read-Json (Join-Path $ws 'state\proposal.json')
    Assert-Equal 1 @($pending.operations).Count 'the line left pending'
    Assert-Equal 'mobile-onboarding' $pending.operations[0].id 'the update that waits'

    Set-Proposal $ws @{ operations = @($narrow) }
    $run = Invoke-Register $ws apply plain -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "apply plain of a line that adds nothing, with output: $($run.Output)"
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'nothing waits'
}

Test 'an entry added to a watch list is read back seven days in each source it concerns, and the collect that read it clears it' {
    $ws = New-ReadinessWorkspace
    Set-MailRead $ws
    Set-Proposal $ws @{ operations = @((New-UpdateOperation 'mobile-onboarding' @{ watch_list = @{ people = @('the tech lead', 'the architect'); tracker_tickets = @('ONB-142') } })) }
    $run = Invoke-Register $ws apply -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "apply, with output: $($run.Output)"
    Assert-Match $run.Output 'read mail back to 2026-03-03 at the next collect for people: the architect' 'what apply says'
    $state = Read-Json (Join-Path $ws 'state\last-collect.json')
    Assert-Equal 'people: the architect' "$($state.sources.mail.catch_up.entry)" 'the catch-up of mail'
    Assert-Equal '2026-03-03T09:00:00+01:00' "$($state.sources.mail.catch_up.from)" 'from seven days back'
    Assert-True ($null -eq $state.sources.tracker) 'the tracker, never read, is read seven days back at its first collect anyway'

    $window = (Invoke-Register $ws select mail -Now '2026-03-10T10:00:00+01:00').Output | ConvertFrom-Json
    Assert-Equal '2026-03-09T18:00:00+01:00' $window.search_from 'where the searches of mail start'
    Assert-Equal 'people: the architect' "$($window.catch_up.entry)" 'the catch-up to search'

    Write-Json (Join-Path $ws 'state\mail-matches.json') @(
        @{ id = 'm-new'; when = '2026-03-10T08:00:00+01:00'; where = 'exports/mail/received/new.txt'; matched_by = @('people: the tech lead') },
        @{ id = 'm-back'; when = '2026-03-05T11:00:00+01:00'; where = 'exports/mail/received/back.txt'; matched_by = @('people: the architect') },
        @{ id = 'm-old'; when = '2026-03-05T12:00:00+01:00'; where = 'exports/mail/received/old.txt'; matched_by = @('people: the tech lead') },
        @{ id = 'm-too-old'; when = '2026-03-01T12:00:00+01:00'; where = 'exports/mail/received/too old.txt'; matched_by = @('people: the architect') }
    )
    $batch = (Invoke-Register $ws select mail state\mail-matches.json -Now '2026-03-10T10:00:00+01:00').Output | ConvertFrom-Json
    Assert-Equal 'm-back m-new' (@($batch.selected | ForEach-Object { $_.id }) -join ' ') 'the catch-up first, then the new mail; nothing before the cutoff a catch-up did not match, nothing before its day'
    Assert-Equal $true $batch.selected[0].catch_up 'the match read back is marked'
    Assert-Equal 'people: the architect' "$($batch.sources_read.caught_up)" 'the catch-up read whole'
    Write-Json (Join-Path $ws 'state\bare-matches.json') @(@{ id = 'm-bare'; when = '2026-03-05T11:00:00+01:00'; where = 'exports/mail/received/back.txt' })
    $refused = Invoke-Register $ws select mail state\bare-matches.json -Now '2026-03-10T10:00:00+01:00'
    Assert-Equal 1 $refused.ExitCode 'select of a match before the cutoff that names no entry, while a catch-up is pending'
    Assert-Match $refused.Output 'Match m-bare is dated before the cutoff, 2026-03-09T18:00:00\+01:00, and names no watch-list entry in matched_by' 'the reason'

    Set-Proposal $ws @{ operations = @(); collected_at = '2026-03-10T10:00:00+01:00'; sources_read = @($batch.sources_read) }
    $run = Invoke-Register $ws apply -Now '2026-03-10T10:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "collect, with output: $($run.Output)"
    $state = Read-Json (Join-Path $ws 'state\last-collect.json')
    Assert-True ($null -eq $state.sources.mail.catch_up) 'the catch-up is cleared'
    Assert-Equal '2026-03-10T10:00:00+01:00' $state.sources.mail.cutoff 'the cutoff of mail'
}

Test 'a catch-up stopped at the cap never moves the cutoff back, and goes on from where it stopped' {
    $ws = New-ReadinessWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.per_source_cap = 1
    Write-Json (Join-Path $ws 'settings.json') $settings
    Set-MailRead $ws
    Set-Proposal $ws @{ operations = @((New-UpdateOperation 'mobile-onboarding' @{ watch_list = @{ people = @('the tech lead', 'the architect') } })) }
    $run = Invoke-Register $ws apply -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "apply, with output: $($run.Output)"
    Write-Json (Join-Path $ws 'state\mail-matches.json') @(
        @{ id = 'back-1'; when = '2026-03-04T10:00:00+01:00'; matched_by = @('people: the architect') },
        @{ id = 'back-2'; when = '2026-03-06T10:00:00+01:00'; matched_by = @('people: the architect') },
        @{ id = 'new-1'; when = '2026-03-10T08:00:00+01:00'; matched_by = @('people: the tech lead') }
    )
    $batch = (Invoke-Register $ws select mail state\mail-matches.json -Now '2026-03-10T10:00:00+01:00').Output | ConvertFrom-Json
    Assert-Equal 'back-1' "$($batch.selected.id)" 'the oldest catch-up match, alone under the cap'
    Assert-Equal $true $batch.sources_read.cap_reached 'the cap'
    Assert-Equal '2026-03-09T18:00:00+01:00' $batch.sources_read.cutoff 'the cutoff stays'
    Assert-Equal '2026-03-06T10:00:00+01:00' "$($batch.sources_read.catch_up.from)" 'the catch-up goes on from the match left'
    Set-Proposal $ws @{ operations = @(); collected_at = '2026-03-10T10:00:00+01:00'; sources_read = @($batch.sources_read) }
    $run = Invoke-Register $ws apply -Now '2026-03-10T10:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "collect, with output: $($run.Output)"

    $batch = (Invoke-Register $ws select mail state\mail-matches.json -Now '2026-03-10T11:00:00+01:00').Output | ConvertFrom-Json
    Assert-Equal 'back-2' "$($batch.selected.id)" 'the next catch-up match'
    Assert-Equal 'people: the architect' "$($batch.sources_read.caught_up)" 'read whole now'
    Set-Proposal $ws @{ operations = @(); collected_at = '2026-03-10T11:00:00+01:00'; sources_read = @($batch.sources_read) }
    $run = Invoke-Register $ws apply -Now '2026-03-10T11:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "second collect, with output: $($run.Output)"
    $batch = (Invoke-Register $ws select mail state\mail-matches.json -Now '2026-03-10T12:00:00+01:00').Output | ConvertFrom-Json
    Assert-Equal 'new-1' "$($batch.selected.id)" 'then the new mail, which waited'
}

Test 'a question that waits for its day is not shown before it, nor is the watch gap of its subject, and one whose day is not a date refuses the list' {
    $ws = New-ReadinessWorkspace
    Write-Json (Join-Path $ws 'state\questions.json') @{ questions = @(
            @{ about = 'mobile-onboarding'; question = 'Which ticket should I follow?'; recommended = 'Not known yet: I ask again next week.'; added = '2026-03-02'; ask_on = '2026-03-16' },
            @{ about = 'mobile-onboarding'; question = 'Who leads the pilot?'; recommended = 'The tech lead.'; added = '2026-03-09' }
        ) }
    $run = Invoke-Register $ws morning -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $run.ExitCode "morning, with output: $($run.Output)"
    Assert-Match $run.Output 'Who leads the pilot\?' 'the question of today'
    Assert-True ($run.Output -notmatch 'Which ticket should I follow') 'the question that waits'
    Assert-True ([IO.File]::ReadAllText((Join-Path $ws 'views\morning.html')) -notmatch 'Which ticket should I follow') 'nor on the page'
    Assert-True ($run.Output -notmatch 'Nothing to follow') 'the watch gap of the subject, which its question asks again on its day'
    $run = Invoke-Register $ws morning -Now '2026-03-16T09:00:00+01:00'
    Assert-Match $run.Output 'Which ticket should I follow\?' 'asked on its day'
    Assert-Match $run.Output 'Nothing to follow: Mobile onboarding \[mobile-onboarding\] in tracker\.' 'the watch gap, on that day'

    $questions = Read-Json (Join-Path $ws 'state\questions.json')
    $questions.questions[0].ask_on = 'next week'
    Write-Json (Join-Path $ws 'state\questions.json') $questions
    $run = Invoke-Register $ws morning -Now '2026-03-10T09:00:00+01:00'
    Assert-Match $run.Output "Question 1 gives ask_on 'next week', which is not a date" 'the reason'
}
