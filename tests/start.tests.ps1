# Start soon and the workload on the morning page: the commitments of the PO that must be started
# now to be done in time, and the work of the next ten working days set against the free time the
# calendar leaves.

# Monday 2 March 2026: its week runs Mon 2 to Fri 6, the next one Mon 9 to Fri 13.
$StartMorning = '2026-03-02T07:12:00+01:00'

function Read-StartBlock([string]$Workspace) {
    $page = [IO.File]::ReadAllText((Join-Path $Workspace 'views\morning.html'), $Utf8)
    if ($page -match '(?s)<section class="block" id="start".*?</section>') { $Matches[0] }
}

function Get-StartRow([string]$Block, [string]$Id) {
    # The HTML of the line of Start soon that names a record.
    if ($Block -match "(?s)<li class=`"row start[^`"]*`"[^>]*>(?:(?!</li>).)*<span class=`"ref`">$Id</span>.*?</li>") { $Matches[0] }
}

function Get-StartText([string]$Html) {
    [Net.WebUtility]::HtmlDecode(($Html -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim())
}

function New-StartWorkspace([object[]]$Commitments, [hashtable]$Settings = @{}) {
    # A workspace of Example Bank seen on Monday 2 March 2026, with the working hours 10:00 to 12:00
    # and 14:00 to 18:00, the kind of task steering pack, the subject mobile-onboarding and these
    # commitments, given as their fields, attached to it.
    $workspace = New-TestWorkspace
    $saved = Read-Json (Join-Path $workspace 'settings.json')
    $saved.working_hours = @(@{ from = '10:00'; to = '12:00' }, @{ from = '14:00'; to = '18:00' })
    $saved.task_kinds = @('steering pack')
    foreach ($name in $Settings.Keys) { $saved | Add-Member -NotePropertyName $name -NotePropertyValue $Settings[$name] -Force }
    Write-Json (Join-Path $workspace 'settings.json') $saved
    Set-Proposal $workspace @{ operations = @(New-SubjectOperation) + @($Commitments | ForEach-Object { New-RecordOperation commitment (@{ subject = 'line 1' } + $_) }) }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the commitments, with output: $($run.Output)"
    $workspace
}

# C-2026-001..003 are three steering packs done, which teach a ratio of 1.5.
$PastPacks = @(
    @{ title = 'January steering pack'; owner = 'the PO'; status = 'done'; task_kind = 'steering pack'; estimated_effort = 1; real_effort = 1.5 },
    @{ title = 'February steering pack'; owner = 'the PO'; status = 'done'; task_kind = 'steering pack'; estimated_effort = 1; real_effort = 1.5 },
    @{ title = 'Pilot steering pack'; owner = 'the PO'; status = 'done'; task_kind = 'steering pack'; estimated_effort = 2; real_effort = 3 }
)

Test 'a commitment of the PO enters Start soon when its latest start, its due date minus its adjusted effort in working days minus a margin of one day, falls within a lead of two working days' {
    # Latest starts, the lead running to Wed 4:
    #   C-2026-004  due Thu 5, 2 d:                       Thu 5 - 3 = Mon 2, today
    #   C-2026-005  due Fri 6, 2 d adjusted x1.5 to 3 d:  Fri 6 - 4 = Mon 2, today
    #   C-2026-006  due Fri 6, 1 d, started:              Fri 6 - 2 = Wed 4
    #   C-2026-007  due Wed 4, 2 d:                       Wed 4 - 3 = Fri 27 Feb, late
    #   C-2026-008  due Mon 9, 1 d:                       Mon 9 - 2 = Thu 5, beyond the lead
    #   C-2026-009  due Tue 3, no estimate
    #   C-2026-010  the tech lead owes it, due Tue 3
    $ws = New-StartWorkspace ($PastPacks + @(
            @{ title = 'Review the target journey'; owner = 'the PO'; due_date = '2026-03-05'; estimated_effort = 2 },
            @{ title = 'March steering pack'; owner = 'the PO'; owed_to = 'the sponsor'; due_date = '2026-03-06'; estimated_effort = 2; task_kind = 'steering pack' },
            @{ title = 'Draft the pilot timeline'; owner = 'the PO'; due_date = '2026-03-06'; estimated_effort = 1; started_on = '2026-02-27'; started_sign = 'a draft in the shared folder' },
            @{ title = 'Score the intake'; owner = 'the PO'; due_date = '2026-03-04'; estimated_effort = 2 },
            @{ title = 'Brief the branch managers'; owner = 'the PO'; due_date = '2026-03-09'; estimated_effort = 1 },
            @{ title = 'Book the committee room'; owner = 'the PO'; due_date = '2026-03-03' },
            @{ title = 'Deliver the test accounts'; owner = 'the tech lead'; owed_to = 'the PO'; due_date = '2026-03-03' }
        ))

    $run = Invoke-Register $ws morning -Now $StartMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Read-StartBlock $ws
    Assert-True $block 'the page holds no Start soon block'
    Assert-Equal 'C-2026-007 C-2026-004 C-2026-005 C-2026-006' (@([regex]::Matches($block, '<span class="ref">([^<]+)</span>') | ForEach-Object { $_.Groups[1].Value }) -join ' ') 'lines of Start soon, the earliest start first'
    Assert-Match $block '<div class="cols start" aria-hidden="true"><span>Start by</span><span>Task</span><span>Effort<span class="adj-h">, adjusted from your past tasks</span></span><span>Due</span><span>Status</span><span></span></div>' 'the named columns'
    Assert-Match (Get-StartRow $block 'C-2026-007') '<li class="row start is-late" id="start-C-2026-007">\s*<span class="when"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg><span class="sr k">Start by </span><b>Fri 27</b> <span class="lag">3 days late</span></span>' 'a latest start past'
    Assert-Match (Get-StartRow $block 'C-2026-004') '<li class="row start is-soon" id="start-C-2026-004">\s*<span class="when"><svg class="i" aria-hidden="true"><use href="#i-clock"/></svg><span class="sr k">Start by </span><b>Today</b></span>' 'a latest start today'
    Assert-Equal 'Start by Today March steering pack C-2026-005 Effort 3 d est. 2 d, adjusted x1.5 from past steering pack: 3 d Due Fri 6 Not started 3 In Do first , number 3' (Get-StartText (Get-StartRow $block 'C-2026-005')) 'a line: start by, task, effort with how it was adjusted, due, status, and its pointer to Do first, where its button is'
    Assert-Match (Get-StartRow $block 'C-2026-006') '<li class="row start is-soon" id="start-C-2026-006">\s*<span class="when"><svg class="i" aria-hidden="true"><use href="#i-clock"/></svg><span class="sr k">Start by </span><b>Wed 4</b></span>' 'a latest start within the lead, this week: amber'
    Assert-Match (Get-StartRow $block 'C-2026-006') '<span class="status"><span class="dot on" aria-hidden="true"></span>Started: a draft in the shared folder</span>' 'a commitment started, with the sign used'
    Assert-Match ([IO.File]::ReadAllText((Join-Path $ws 'views\morning.html'), $Utf8)) '(?s)<li id="first-3">(?:(?!</li>).)*data-ask="Tell me what C-2026-005 needs: March steering pack"' 'the request of a line to start today, in Do first'
    Assert-Match (Get-StartRow $block 'C-2026-006') 'data-ask="Show me where I am on C-2026-006: Draft the pilot timeline"' 'the request a line copies'
    Assert-Match $run.Output '(?m)^Start soon 1 late to start, 2 to start today, 1 more, not read: notes$' 'what morning prints'
}

function Set-StartCalendar([string]$Workspace, [object[]]$Meetings, [object[]]$Absences = @()) {
    # Declares the calendar as read from a folder, and leaves the snapshot of the ten working days
    # from Mon 2 March that the morning routine writes. A meeting is given as its day, its start, its
    # end and, when not accepted, its status: '2026-03-02 10:00 11:00 tentative'.
    $connections = Read-Json (Join-Path $Workspace 'connections.json')
    $connections | Add-Member -NotePropertyName calendar -NotePropertyValue @{ mode = 'folder'; folder = 'exports\calendar' } -Force
    Write-Json (Join-Path $Workspace 'connections.json') $connections
    $events = @($Meetings | ForEach-Object {
            $day, $from, $to, $status = $_ -split ' '
            @{ start = "${day}T${from}:00+01:00"; end = "${day}T${to}:00+01:00"; title = 'Steering committee'; attendees = @('the sponsor'); status = $(if ($status) { $status } else { 'accepted' }) }
        })
    Write-Json (Join-Path $Workspace 'state\calendar.json') @{ read_at = '2026-03-02T07:05:00+01:00'; from = '2026-03-02'; to = '2026-03-13'; meetings = $events; absences = @($Absences | ForEach-Object { @{ date = $_; title = 'Leave' } }) }
}

function Get-Day([string]$Block, [string]$Date) {
    # The HTML of a day of the workload view.
    if ($Block -match "(?s)<li[^>]* data-day=`"$Date`"[^>]*>.*?</li>") { $Matches[0] }
}

function Get-DayValue([string]$Block, [string]$Date, [string]$Name) {
    # What the workload view counts for a day, in days: free, work or over.
    if ((Get-Day $Block $Date) -match "data-$Name=`"([0-9.]+)`"") { $Matches[1] }
}

Test 'every task of Start soon is shown, none folded, whatever the meetings of the day; one whose latest start is next week is not amber' {
    # With a lead of six working days, running to Tue 10: six tasks to start, the last on Tue 10.
    $ws = New-StartWorkspace @(foreach ($due in '05', '06', '09', '10', '11', '12') {
            @{ title = "Steering pack due on the $due"; owner = 'the PO'; due_date = "2026-03-$due"; estimated_effort = 1 }
        }) @{ start_soon = @{ margin = 1; lead = 6 } }
    Set-StartCalendar $ws @('2026-03-02 09:00 09:30', '2026-03-02 09:30 10:00', '2026-03-02 12:00 12:30', '2026-03-02 12:30 13:00', '2026-03-02 13:00 13:30', '2026-03-02 13:30 14:00')

    $run = Invoke-Register $ws morning -Now $StartMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Read-StartBlock $ws
    Assert-Equal 6 @([regex]::Matches($block, '<li class="row start')).Count 'lines of Start soon'
    Assert-True ($block -notmatch '<details') "a line of Start soon is folded: $block"
    Assert-Match (Get-StartRow $block 'C-2026-006') '<li class="row start" id="start-C-2026-006">\s*<span class="when"><span class="sr k">Start by </span><b>Tue 10</b></span>' 'a latest start next week'
}

# Mon 2: an hour accepted, two tentative hours and a tentative hour half under the accepted one.
# Tue 3: four hours accepted. Wed 4: the steering committee all day. Thu 5: on leave.
$SteeringWeek = @('2026-03-02 10:00 11:00', '2026-03-02 14:00 16:00 tentative', '2026-03-02 10:30 11:30 tentative',
    '2026-03-03 10:00 12:00', '2026-03-03 14:00 16:00', '2026-03-04 10:00 12:00', '2026-03-04 14:00 18:00')

Test 'the free time of a day is its working hours minus its meetings, a tentative one counting half, a day of absence none, times a usable share of 70%' {
    # C-2026-001, due Fri 13 with 1 d, starts on Wed 11 and is planned on Wed 11 and Thu 12.
    $ws = New-StartWorkspace @(@{ title = 'Brief the branch managers'; owner = 'the PO'; due_date = '2026-03-13'; estimated_effort = 1 })
    Set-StartCalendar $ws $SteeringWeek '2026-03-05'

    $run = Invoke-Register $ws morning -Now $StartMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Read-StartBlock $ws
    # Mon 2: 360 minutes, less 60 accepted, 60 for two tentative hours, 15 for the half hour of the
    # third that the accepted one leaves: 225 minutes, 0.625 d, of which 70% usable.
    Assert-Equal '0.44 0.23 0.00 0.00 0.70 0.70' (@('02', '03', '04', '05', '06', '09') | ForEach-Object { Get-DayValue $block "2026-03-$_" 'free' }) 'usable free time per day'
    Assert-Equal 10 @([regex]::Matches($block, 'data-day="')).Count 'days of the workload'
    Assert-Equal '0.00 0.70 0.30 0.00' (@('10', '11', '12', '13') | ForEach-Object { Get-DayValue $block "2026-03-$_" 'work' }) 'work planned per day, from the latest start to the day before the due date'
    Assert-Match (Get-Day $block '2026-03-02') '<span class="d">Today</span><span class="sq" aria-hidden="true"><i class="o"></i></span><span class="sr">: 1 half-day\(s\) free, 0 planned</span>' 'a day: one square per half-day of usable free time'
    Assert-Match (Get-Day $block '2026-03-03') '<span class="sq" aria-hidden="true"><i class="o"></i></span>' 'a day with less than a quarter of a day free shows one square all the same'
    Assert-Match (Get-Day $block '2026-03-05') '<span class="d">Thu 5</span><span class="sq"><span class="none">day off</span></span>' 'a day of absence'
    Assert-Match (Get-Day $block '2026-03-04') '<span class="d">Wed 4</span><span class="sq"><span class="none">none</span></span>' 'a day without free time'
    Assert-Match (Get-Day $block '2026-03-11') '<i class="p"></i></span>' 'a day with work planned'
    Assert-Match $block '<h3 id="h-load">Workload, next 10 working days <span class="note">One square is half a day you can use for tasks: 70% of the time meetings leave, the share to start with\.</span></h3>' 'the heading of the workload'
    Assert-Match $block '<p class="week-cap"><b>This week</b>: no work planned, 1\.5 days free\. 1\.5 days still open\.</p>' 'the sentence of this week'
    Assert-Match $block '<p class="week-cap"><b>Next week</b>: 1 day of work, 3\.5 days free\. 2\.5 days still open\.</p>' 'the sentence of next week'
}

$SteeringDeck = @{ title = 'Steering committee deck'; owner = 'the PO'; owed_to = 'the sponsor'; due_date = '2026-03-05'; estimated_effort = 2 }

Test 'a day that does not fit is marked in words, an icon and red, and so are its week and the block' {
    # C-2026-001, due Thu 5 with 2 d, starts today: 0.44 d on Mon 2, 0.23 d on Tue 3, and its
    # 1.33 d left do not fit on Wed 4, the day before it is due, which the steering committee fills.
    $ws = New-StartWorkspace @($SteeringDeck)
    Set-StartCalendar $ws $SteeringWeek '2026-03-05'

    $run = Invoke-Register $ws morning -Now $StartMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Read-StartBlock $ws
    Assert-Equal '0.44 0.23 0.00' (@('02', '03', '04') | ForEach-Object { Get-DayValue $block "2026-03-$_" 'work' }) 'work planned'
    Assert-Equal '1.33' (Get-DayValue $block '2026-03-04' 'over') 'work that does not fit on Wed 4'
    Assert-Match (Get-Day $block '2026-03-04') '^<li class="over" [^>]*><span class="d">Wed 4</span><span class="late"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg> Does not fit</span><span class="sq" aria-hidden="true"><i class="x"></i><i class="x"></i><i class="x"></i></span><span class="sr">: 0 half-day\(s\) free, 0 planned, 3 half-day\(s\) of work that do not fit</span></li>$' 'the day that does not fit'
    Assert-Match $block '<p class="week-cap"><b>This week</b>: 2 days of work, 1\.5 days free\. <span class="late"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg> 1 day does not fit: Wed 4\.</span></p>' 'the sentence of the week'
    Assert-Match $run.Output '(?m)^Start soon 1 to start today, Does not fit: Wed 4, not read: notes$' 'the counts of the block'
}

Test 'a week with a day that does not fit by less than a quarter of a day says so in red, and never that nothing does not fit' {
    # C-2026-001, due Wed 4 with 0.7 d, starts today: 0.44 d on Mon 2 and 0.23 d on Tue 3, its last
    # day, leave 0.03 d that do not fit on Tue 3.
    $ws = New-StartWorkspace @(@{ title = 'Steering committee deck'; owner = 'the PO'; owed_to = 'the sponsor'; due_date = '2026-03-04'; estimated_effort = 0.7 })
    Set-StartCalendar $ws $SteeringWeek '2026-03-05'

    $run = Invoke-Register $ws morning -Now $StartMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Read-StartBlock $ws
    Assert-Equal '0.03' (Get-DayValue $block '2026-03-03' 'over') 'work that does not fit on Tue 3'
    Assert-Match $block '<p class="week-cap"><b>This week</b>: half a day of work, 1\.5 days free\. <span class="late"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg> 1 day does not fit: Tue 3\.</span></p>' 'the sentence of the week'
    Assert-True ($block -notmatch 'nothing') "the workload says nothing: $block"
}

Test 'the workload says how many open commitments of the PO it leaves out, and why: no estimate or no due date' {
    $ws = New-StartWorkspace @(
        @{ title = 'Brief the branch managers'; owner = 'the PO'; due_date = '2026-03-13'; estimated_effort = 1 },
        @{ title = 'Book the committee room'; owner = 'the PO'; due_date = '2026-03-06' },
        @{ title = 'Archive the paper statement templates'; owner = 'the PO' },
        @{ title = 'Score the intake'; owner = 'the PO'; estimated_effort = 2 },
        @{ title = 'Deliver the test accounts'; owner = 'the tech lead'; owed_to = 'the PO' },
        @{ title = 'January steering pack'; owner = 'the PO'; status = 'done' }
    )
    Set-StartCalendar $ws @()

    $run = Invoke-Register $ws morning -Now $StartMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match (Read-StartBlock $ws) '<p class="free"><b>Left out of the workload:</b> 2 commitment\(s\) without an estimate, 1 commitment\(s\) without a due date\.</p>' 'the commitments left out'

    $run = Invoke-Register $ws morning fr -Now $StartMorning

    Assert-Match ([IO.File]::ReadAllText((Join-Path $ws 'views\morning.html'), $Utf8)) '<p class="free"><b>Hors de la charge :</b> 2 engagement\(s\) sans estimation, 1 engagement\(s\) sans &#233;ch&#233;ance\.</p>' 'the commitments left out, in French'
}

Test 'the free time of a day goes first to the task due first' {
    # C-2026-002, due Wed 4 with 0.5 d, gets 0.5 d of Mon 2; C-2026-001, due Fri 13 with 1 d, the
    # rest of Mon 2 and its 0.8 d left after. Both started: everything fits.
    $ws = New-StartWorkspace @(
        @{ title = 'Brief the branch managers'; owner = 'the PO'; due_date = '2026-03-13'; estimated_effort = 1; started_on = '2026-02-27'; started_sign = 'the PO said so' },
        @{ title = 'Book the committee room'; owner = 'the PO'; due_date = '2026-03-04'; estimated_effort = 0.5; started_on = '2026-02-27'; started_sign = 'the PO said so' }
    )
    Set-StartCalendar $ws @()

    Invoke-Register $ws morning -Now $StartMorning | Out-Null

    $block = Read-StartBlock $ws
    Assert-Equal '0.70 0.70 0.10' (@('02', '03', '04') | ForEach-Object { Get-DayValue $block "2026-03-$_" 'work' }) 'work planned'
    Assert-True ($block -notmatch 'class="over"') 'a day does not fit'
}

Test 'when a day does not fit, the page proposes one way out: start a task earlier, then drop or hand over a task marked optional, then ask to move a due date' {
    # Asked to move: the deck fits when it is due Tue 10, with Fri 6 and Mon 9 free.
    $ws = New-StartWorkspace @($SteeringDeck)
    Set-StartCalendar $ws $SteeringWeek '2026-03-05'
    Invoke-Register $ws morning -Now $StartMorning | Out-Null

    $block = Read-StartBlock $ws
    Assert-Match $block '<div class="suggest">\s*<p><b>Suggestion:</b> ask the sponsor to move Steering committee deck <span class="id">C-2026-001</span> to Tue 10: then Wed 4 fits\.</p>\s*<span class="btns"><button class="ask" type="button" data-ask="Draft a request to the sponsor to move C-2026-001 to Tue 10">(?:(?!</button>).)*<span class="lbl">Ask to move</span></button></span>\s*</div>' 'asked to move a due date'

    # Started early enough: the scoring grid, due Wed 11 with 2 d, starts on Fri 6, its latest
    # start, and does not fit on Tue 10 with Mon 9 taken all day; begun today, it fits.
    $ws = New-StartWorkspace @(@{ title = 'Scoring grid'; owner = 'the PO'; due_date = '2026-03-11'; estimated_effort = 2 })
    Set-StartCalendar $ws @('2026-03-09 10:00 12:00', '2026-03-09 14:00 18:00')
    $run = Invoke-Register $ws morning -Now $StartMorning

    $block = Read-StartBlock $ws
    Assert-True ((Get-DayValue $block '2026-03-10' 'over') -gt 0) 'the scoring grid fits'
    Assert-Match $block '<p><b>Suggestion:</b> start Scoring grid <span class="id">C-2026-001</span> today rather than Fri 6: then Tue 10 fits\.</p>\s*<span class="btns"><button class="ask" type="button" data-ask="Help me start C-2026-001 today: Scoring grid">' 'started earlier'
    Assert-Match $run.Output '(?m)^Suggestion: start Scoring grid \[C-2026-001\] today rather than Fri 6: then Tue 10 fits\.$' 'what morning prints'

    # Dropped: a deck of 0.6 d, started, gets 0.17 d before Wed 4 after the optional survey, due
    # earlier, and 0.67 d without it.
    $ws = New-StartWorkspace @(
        @{ title = 'Steering committee deck'; owner = 'the PO'; owed_to = 'the sponsor'; due_date = '2026-03-05'; estimated_effort = 0.6; started_on = '2026-02-27'; started_sign = 'a draft in the shared folder' },
        @{ title = 'Branch survey'; owner = 'the PO'; owed_to = 'the branch network'; due_date = '2026-03-04'; estimated_effort = 0.5; optional = $true }
    )
    Set-StartCalendar $ws $SteeringWeek '2026-03-05'
    Invoke-Register $ws morning -Now $StartMorning | Out-Null

    Assert-True (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-002.json')).optional 'the commitment marked optional'
    Assert-Match (Read-StartBlock $ws) '<p><b>Suggestion:</b> drop or hand over Branch survey <span class="id">C-2026-002</span>, which is optional: then Wed 4 fits\.</p>\s*<span class="btns"><button class="ask" type="button" data-ask="Draft the hand-over of C-2026-002: Branch survey">' 'an optional task dropped'
}

Test 'morning keeps the free time of each day it is run, and the usable share is learned from the real efforts of the PO''s done tasks once they span ten working days of it' {
    # C-2026-001, started Mon 16 Feb and done Fri 20 Feb in 2 d; C-2026-002, started Mon 23 Feb and
    # done Fri 27 Feb in 3 d: 5 d of work over the 10 d free of those two weeks, a share of 50%.
    # C-2026-003, open, due Fri 13 with 1 d, gives the view something to plan.
    $ws = New-StartWorkspace @(
        @{ title = 'February steering pack'; owner = 'the PO'; estimated_effort = 2; started_on = '2026-02-16'; started_sign = 'a draft in the shared folder' },
        @{ title = 'Intake review'; owner = 'the PO'; estimated_effort = 3; started_on = '2026-02-23'; started_sign = 'a mail of the PO about it' },
        @{ title = 'Brief the branch managers'; owner = 'the PO'; due_date = '2026-03-13'; estimated_effort = 1 }
    )
    foreach ($done in @(@('C-2026-001', 2, '2026-02-20'), @('C-2026-002', 3, '2026-02-27'))) {
        Set-Proposal $ws @{ operations = @(New-UpdateOperation $done[0] @{ status = 'done'; real_effort = $done[1] }) }
        $run = Invoke-Register $ws apply -Today $done[2]
        Assert-Equal 0 $run.ExitCode "exit code when $($done[0]) is done, with output: $($run.Output)"
    }
    $kept = [ordered]@{}
    foreach ($date in '16', '17', '18', '19', '20', '23', '24', '25', '26') { $kept["2026-02-$date"] = 1 }
    Write-Json (Join-Path $ws 'state\free-time.json') $kept
    Set-StartCalendar $ws $SteeringWeek '2026-03-05'

    Invoke-Register $ws morning -Now $StartMorning | Out-Null

    # Fri 27 Feb is not kept: C-2026-002 spans a day of unknown free time, and the share stays.
    Assert-Match (Read-StartBlock $ws) '70% of the time meetings leave, the share to start with\.' 'the share with nine days kept'
    Assert-Equal 0.63 (Read-Json (Join-Path $ws 'state\free-time.json')).'2026-03-02' 'the free time of today kept, before the share'

    $kept['2026-02-27'] = 1
    Write-Json (Join-Path $ws 'state\free-time.json') $kept
    Invoke-Register $ws morning -Now $StartMorning | Out-Null

    $block = Read-StartBlock $ws
    Assert-Match $block '50% of the time meetings leave, learned from your past tasks\.' 'the share learned'
    Assert-Equal '0.50' (Get-DayValue $block '2026-03-06' 'free') 'a day free of meetings, at the share learned'
}

Test 'the margin and the lead are settings' {
    $ws = New-StartWorkspace @(
        @{ title = 'Review the target journey'; owner = 'the PO'; due_date = '2026-03-05'; estimated_effort = 2 },
        @{ title = 'Brief the branch managers'; owner = 'the PO'; due_date = '2026-03-09'; estimated_effort = 1 }
    ) @{ start_soon = @{ margin = 0; lead = 3 } }

    Invoke-Register $ws morning -Now $StartMorning | Out-Null

    # With no margin: Thu 5 - 2 = Tue 3, and Mon 9 - 1 = Fri 6, within a lead running to Thu 5.
    $block = Read-StartBlock $ws
    Assert-Match (Get-StartRow $block 'C-2026-001') '<b>Tue 3</b>' 'a latest start without a margin'
    Assert-True (-not (Get-StartRow $block 'C-2026-002')) 'a latest start beyond the lead is listed'

    $saved = Read-Json (Join-Path $ws 'settings.json')
    $saved.start_soon.lead = 0
    Write-Json (Join-Path $ws 'settings.json') $saved
    Invoke-Register $ws morning -Now $StartMorning | Out-Null

    # No collect has read the notes, and the calendar is off: the block says both.
    Assert-Equal 'Start soon none, not read: notes Workload: not read: calendar' (Get-StartText (Read-StartBlock $ws)) 'a block with nothing to start within a lead of no day'
}
