# Today's meetings on the morning page, and the brief of a meeting: read from the calendar
# snapshot, state\calendar.json, that the morning routine writes, and linked to subjects by their
# watch lists.

# Monday 2 March 2026.
$Morning = '2026-03-02T07:12:00+01:00'

function Read-MorningPage([string]$Workspace) {
    [IO.File]::ReadAllText((Join-Path $Workspace 'views\morning.html'), $Utf8)
}

function Get-PageBlock([string]$Page, [string]$Id) {
    if ($Page -match "(?s)<section class=`"block`" id=`"$Id`".*?</section>") { $Matches[0] }
}

function Get-BlockCount([string]$Block) {
    if ($Block -match '(?s)<span class="count">(.*?)</span></h2>') { [Net.WebUtility]::HtmlDecode(($Matches[1] -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()) }
}

function Get-Meeting([string]$Html, [string]$Time) {
    # The HTML of the line of the meeting that starts at a time.
    if ($Html -match "(?s)<li class=`"mtg[^`"]*`">\s*<details>\s*<summary>\s*<span class=`"t`">$Time</span>.*?</li>\s*(?=<li class=`"mtg|</ol>)") { $Matches[0] }
}

function Get-Text([string]$Html) {
    [Net.WebUtility]::HtmlDecode(($Html -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim())
}

function Set-Calendar([string]$Workspace, [object[]]$Meetings, [object[]]$Absences = @(), [string]$ReadAt = '2026-03-02T07:05:00+01:00') {
    # Declares the calendar as read from a folder, and leaves the snapshot the morning routine
    # writes from it.
    $connections = Read-Json (Join-Path $Workspace 'connections.json')
    $connections | Add-Member -NotePropertyName calendar -NotePropertyValue @{ mode = 'folder'; folder = 'exports\calendar' } -Force
    Write-Json (Join-Path $Workspace 'connections.json') $connections
    Write-Json (Join-Path $Workspace 'state\calendar.json') @{ read_at = $ReadAt; from = '2026-03-02'; to = '2026-03-13'; meetings = @($Meetings); absences = @($Absences) }
}

function New-Meeting([string]$Start, [string]$End, [string]$Title, [string[]]$Attendees, [string]$Status = 'accepted') {
    @{ start = "${Start}:00+01:00"; end = "${End}:00+01:00"; title = $Title; attendees = @($Attendees); status = $Status }
}

$TodaysMeetings = @(
    (New-Meeting '2026-03-02T14:00' '2026-03-02T14:45' 'Credit memo pilot check-in' 'the credit risk lead of Harbour Bank', 'the data lead'),
    (New-Meeting '2026-03-02T09:30' '2026-03-02T09:45' 'Stand-up: onboarding' 'the tech lead'),
    (New-Meeting '2026-03-02T11:00' '2026-03-02T12:00' 'Vendor demo' 'the vendor' 'tentative'),
    (New-Meeting '2026-03-03T10:00' '2026-03-03T11:00' 'KYC review' 'the data lead')
)

function New-TestWorkspaceWithMeetings {
    # A workspace of Example Bank seen on Monday 2 March 2026:
    #   mobile-onboarding      every bank; watches the tech lead and "onboarding"
    #   credit-memo-drafting   Harbour Bank; watches the credit risk lead and "credit memo"
    #   kyc-document-reader    North Bank; watches the data lead and "KYC"
    #   C-2026-001  credit memo: the PO owes the credit risk lead the pilot timeline, due Wed 4 Mar
    #   C-2026-002  KYC: the data lead owes the PO the test dataset, due Fri 27 Feb
    #   C-2026-003  credit memo: done
    #   C-2026-004  onboarding: the PO owes the tech lead the test scope, due today
    #   D-2026-001  credit memo: pending, awaited from the sponsor by Fri 6 Mar
    #   D-2026-002  KYC: pending
    # The calendar holds three meetings today, out of order, and one tomorrow.
    $workspace = New-TestWorkspace
    $settings = Read-Json (Join-Path $workspace 'settings.json')
    $settings.banks = @('Harbour Bank', 'North Bank')
    Write-Json (Join-Path $workspace 'settings.json') $settings
    $c = { param($Fields) New-RecordOperation commitment $Fields }
    Set-Proposal $workspace @{ operations = @(
            (New-SubjectOperation @{ watch_list = @{ people = @('the tech lead'); keywords = @('onboarding') } }),
            (New-SubjectOperation @{ title = 'Credit memo drafting'; banks = @('Harbour Bank'); watch_list = @{ people = @('the credit risk lead'); keywords = @('credit memo') } }),
            (New-SubjectOperation @{ title = 'KYC document reader'; banks = @('North Bank'); watch_list = @{ people = @('the data lead'); keywords = @('KYC') } }),
            (& $c @{ title = 'Send the pilot timeline'; subject = 'line 2'; owner = 'the PO'; owed_to = 'the credit risk lead'; due_date = '2026-03-04' }),
            (& $c @{ title = 'Share the test dataset'; subject = 'line 3'; owner = 'the data lead'; owed_to = 'the PO'; due_date = '2026-02-27' }),
            (& $c @{ title = 'Book the pilot room'; subject = 'line 2'; owner = 'the PO'; status = 'done' }),
            (& $c @{ title = 'Confirm the test scope'; subject = 'line 1'; owner = 'the PO'; owed_to = 'the tech lead'; due_date = '2026-03-02' }),
            (New-RecordOperation decision @{ title = 'Choose the pilot scope'; subject = 'line 2'; needed_from = 'the sponsor'; needed_by = '2026-03-06' }),
            (New-RecordOperation decision @{ title = 'Choose the hosting'; subject = 'line 3'; needed_from = 'the architect' })
        )
    }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the day, with output: $($run.Output)"
    Set-Calendar $workspace $TodaysMeetings
    $workspace
}

Test 'the template declares the calendar off, and the settings hold the working hours of the PO, 09:00 to 18:00' {
    $template = Join-Path $KitRoot 'workspace-template'

    Assert-Equal 'off' (Read-Json (Join-Path $template 'connections.json')).calendar.mode 'calendar mode'
    Assert-Equal '[{"from":"09:00","to":"18:00"}]' (ConvertTo-Json -InputObject @((Read-Json (Join-Path $template 'settings.json')).working_hours) -Compress) 'working hours'
}

Test 'with the calendar off, the meetings block opens the page and says the calendar was not read, and the bar says it is off' {
    $ws = New-TestWorkspaceWithSubject

    $run = Invoke-Register $ws morning -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $page = Read-MorningPage $ws
    $order = @([regex]::Matches($page, '<section class="block" id="([a-z]+)"') | ForEach-Object { $_.Groups[1].Value }) -join ' '
    Assert-Equal 'meetings owe owed decisions sort' $order 'blocks of the page, in order'
    Assert-Match $page '(?s)<div class="sheet">\s*<section class="block" id="meetings"[^>]*>.*?</section>\s*</div>' 'the meetings in the white sheet'
    Assert-Equal "Today's meetings not read: calendar" (Get-Text ((Get-PageBlock $page 'meetings') -replace '(?s)^.*?(<h2.*?</h2>).*$', '$1')) 'the meetings block'
    Assert-Match $page '<span class="src">Off: mail, tracker, calendar</span>' 'the bar'
    Assert-Match $run.Output "(?m)^Today's meetings not read: calendar$" 'what morning prints'
}

Test 'the meetings of today are a timeline by start time, each with its duration, and the block counts them with the time they take' {
    $ws = New-TestWorkspaceWithMeetings

    $run = Invoke-Register $ws morning -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Get-PageBlock (Read-MorningPage $ws) 'meetings'
    Assert-Equal '09:30 11:00 14:00' (@([regex]::Matches($block, '<span class="t">([0-9:]+)</span>') | ForEach-Object { $_.Groups[1].Value }) -join ' ') 'meetings of today, in order'
    Assert-Equal '3 meeting(s), 2 h booked. Open a line for its brief.' (Get-BlockCount $block) 'counts of the block'
    Assert-Match (Get-Meeting $block '09:30') '<span class="m-title">Stand-up: onboarding <span class="dur">15 min</span></span>' 'a meeting of a quarter of an hour'
    Assert-Match (Get-Meeting $block '11:00') '<li class="mtg is-tentative">(?s:.*)<span class="dur">1 h, tentative</span>' 'a tentative meeting says so'
    Assert-True ($block -notmatch 'KYC review') "a meeting of another day is listed"
    Assert-Match (Get-Meeting $block '14:00') '<button class="ask" type="button" data-ask="Brief me for the 14:00 Credit memo pilot check-in"><svg class="i" aria-hidden="true"><use href="#i-copy"/></svg><span class="lbl">Brief me</span></button>' 'the button of a meeting'
    Assert-Match $run.Output "(?m)^Today's meetings 3 meeting\(s\), 2 h booked\. Open a line for its brief\.$" 'what morning prints'
    Assert-Match (Read-MorningPage $ws) '<span class="src"><svg class="i" aria-hidden="true"><use href="#i-check"/></svg>Calendar read at 07:05</span>' 'the bar'
}

Test 'the free time for work is the working hours that no meeting takes, tentative ones included, with the longest stretch named' {
    $ws = New-TestWorkspaceWithMeetings

    Invoke-Register $ws morning -Now $Morning | Out-Null

    Assert-Match (Get-PageBlock (Read-MorningPage $ws) 'meetings') '<p class="free"><b>Free for work:</b> 09:00&ndash;09:30 &middot; 09:45&ndash;11:00 &middot; 12:00&ndash;14:00 &middot; 14:45&ndash;18:00, the longest</p>' 'free time within 09:00 to 18:00'

    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.working_hours = @(@{ from = '10:00'; to = '12:00' }, @{ from = '14:00'; to = '18:00' })
    Write-Json (Join-Path $ws 'settings.json') $settings
    Invoke-Register $ws morning -Now $Morning | Out-Null

    Assert-Match (Get-PageBlock (Read-MorningPage $ws) 'meetings') '<p class="free"><b>Free for work:</b> 10:00&ndash;11:00 &middot; 14:45&ndash;18:00, the longest</p>' 'free time within 10:00 to 12:00 and 14:00 to 18:00'
}

Test 'on a day of absence the free time says so; a day without meetings is the heading and none' {
    $ws = New-TestWorkspaceWithMeetings
    Set-Calendar $ws @() @(@{ date = '2026-03-02'; title = 'Leave' })

    Invoke-Register $ws morning -Now $Morning | Out-Null

    $block = Get-PageBlock (Read-MorningPage $ws) 'meetings'
    Assert-Equal "Today's meetings none Free for work: Day off" (Get-Text $block) 'a day of absence'

    Set-Calendar $ws @($TodaysMeetings[3])
    Invoke-Register $ws morning -Now $Morning | Out-Null

    Assert-Match (Get-PageBlock (Read-MorningPage $ws) 'meetings') "^<section class=`"block`" id=`"meetings`" aria-labelledby=`"h-meetings`">\r?\n<h2 id=`"h-meetings`">Today&#39;s meetings <span class=`"count`">none</span></h2>\r?\n</section>$" 'a day without meetings'
}

Test 'a calendar snapshot read on an earlier day is not read today, for the block and for the bar' {
    $ws = New-TestWorkspaceWithMeetings
    Set-Calendar $ws $TodaysMeetings -ReadAt '2026-02-27T07:05:00+01:00'

    Invoke-Register $ws morning -Now $Morning | Out-Null

    $page = Read-MorningPage $ws
    Assert-Equal 'not read: calendar' (Get-BlockCount (Get-PageBlock $page 'meetings')) 'counts of the block'
    Assert-Match $page '<span class="src fail"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg>Not read: calendar</span>' 'the bar'
}

Test 'a meeting is linked to subjects by its attendees and its title against the watch lists, and its brief lists their open commitments and decisions awaited' {
    $ws = New-TestWorkspaceWithMeetings

    Invoke-Register $ws morning -Now $Morning | Out-Null

    $block = Get-PageBlock (Read-MorningPage $ws) 'meetings'
    $standUp = Get-Meeting $block '09:30'
    Assert-Match $standUp '<dt>With</dt><dd>the tech lead</dd>' 'who attends'
    Assert-Match $standUp '<dt>Subjects</dt><dd>Mobile onboarding <span class="id">mobile-onboarding</span></dd>' 'the subject the tech lead and "onboarding" link'
    Assert-Match $standUp '<li>Confirm the test scope <span class="who">the PO owes the tech lead, due Today</span> <span class="id">C-2026-004</span></li>' 'its open commitment'
    Assert-True ($standUp -notmatch 'Decisions awaited') 'a brief without decisions lists them'
    Assert-Match (Get-Meeting $block '11:00') '<dt>Subjects</dt><dd>none of your subjects</dd>' 'a meeting no watch list names'
}

Test 'a meeting with a client bank keeps to that bank''s subjects, and shows the bank; a meeting that names no bank has the banks of its subjects' {
    $ws = New-TestWorkspaceWithMeetings

    Invoke-Register $ws morning -Now $Morning | Out-Null

    $harbour = Get-Meeting (Get-PageBlock (Read-MorningPage $ws) 'meetings') '14:00'
    Assert-Match $harbour '<span class="m-title">Credit memo pilot check-in <span class="bank">Harbour Bank</span> <span class="dur">45 min</span></span>' 'the bank of the meeting'
    Assert-Match $harbour '<dt>Subjects</dt><dd>Credit memo drafting <span class="id">credit-memo-drafting</span></dd>' 'the subjects of Harbour Bank only'
    Assert-Equal 'C-2026-001 D-2026-001' (@([regex]::Matches($harbour, '<span class="id">([CD]-[0-9-]+)</span>') | ForEach-Object { $_.Groups[1].Value }) -join ' ') 'records of the brief'
    Assert-Match $harbour '<li>Choose the pilot scope <span class="who">from the sponsor, by Fri 6</span> <span class="id">D-2026-001</span></li>' 'the decision awaited'

    # Without the bank in its title or attendees, the data lead links the subject of North Bank too.
    Set-Calendar $ws @(New-Meeting '2026-03-02T14:00' '2026-03-02T14:45' 'Credit memo pilot check-in' 'the credit risk lead', 'the data lead')
    Invoke-Register $ws morning -Now $Morning | Out-Null

    $both = Get-Meeting (Get-PageBlock (Read-MorningPage $ws) 'meetings') '14:00'
    Assert-Match $both 'Credit memo pilot check-in <span class="bank">Harbour Bank</span> <span class="bank">North Bank</span> <span class="dur">' 'the banks of its subjects'
    Assert-Match $both '<li>Share the test dataset <span class="who">the data lead owes the PO, <span class="late"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg> due Fri 27, 3 days late</span></span> <span class="id">C-2026-002</span></li>' 'a late commitment of the brief'
}

Test 'the agent''s notes give a meeting its sentence on what matters and each decision what it still lacks' {
    $ws = New-TestWorkspaceWithMeetings
    Write-Json (Join-Path $ws 'state\morning.json') @{ meetings = @(@{
                start = '2026-03-02T14:00:00+01:00'; title = 'Credit memo pilot check-in'
                key   = 'They will ask for the pilot scope [D-2026-001], still undecided.'
                lacks = @{ 'D-2026-001' = "The sponsor's position" }
            }, @{ start = '2026-03-02T09:30:00+01:00'; title = 'Another meeting'; key = 'Not this one.' })
    }

    $run = Invoke-Register $ws morning -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Get-PageBlock (Read-MorningPage $ws) 'meetings'
    Assert-Match (Get-Meeting $block '14:00') '<span class="m-key">They will ask for the pilot scope \[D-2026-001\], still undecided\.</span>' 'the sentence on what matters'
    Assert-Match (Get-Meeting $block '14:00') '<span class="id">D-2026-001</span> <span class="missing">Still lacks: The sponsor&#39;s position</span></li>' 'what the decision lacks'
    Assert-True ((Get-Meeting $block '09:30') -notmatch 'm-key') 'a note goes to the meeting of another title'
}

Test 'notes that cite a record missing or superseded are left off the page, which says why, and morning prints it' {
    $ws = New-TestWorkspaceWithMeetings
    Write-Json (Join-Path $ws 'state\morning.json') @{ meetings = @(@{
                start = '2026-03-02T14:00:00+01:00'; title = 'Credit memo pilot check-in'
                key   = 'Ask for the memos [C-2026-099].'; lacks = @{ 'D-2026-007' = 'Everything' }
            })
    }

    $run = Invoke-Register $ws morning -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Get-PageBlock (Read-MorningPage $ws) 'meetings'
    Assert-True ($block -notmatch 'm-key|Still lacks') 'a note of the refused notes is shown'
    Assert-Match $block '<p class="refused late"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg> The agent&#39;s notes on the meetings are not shown: C-2026-099 is not in the register\. D-2026-007 is not in the register\.</p>' 'what the page says'
    Assert-Match $run.Output '(?m)^Not verified: state\\morning\.json\..*\n- C-2026-099 is not in the register\.\n- D-2026-007 is not in the register\.$' 'what morning prints'
}

Test 'brief prints the brief of a meeting of the snapshot for the chat: of today by its time, of another day by its date and time' {
    $ws = New-TestWorkspaceWithMeetings
    Write-Json (Join-Path $ws 'state\morning.json') @{ meetings = @(@{
                start = '2026-03-02T14:00:00+01:00'; title = 'Credit memo pilot check-in'
                key   = 'They will ask for the pilot scope.'; lacks = @{ 'D-2026-001' = "The sponsor's position" }
            })
    }

    $run = Invoke-Register $ws brief 14:00 -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal (@(
            'Calendar read at 2026-03-02T07:05:00+01:00.'
            ''
            '2026-03-02 14:00-14:45 Credit memo pilot check-in, accepted. Client banks: Harbour Bank.'
            'With: the credit risk lead of Harbour Bank, the data lead'
            'What matters: They will ask for the pilot scope.'
            'Subjects: Credit memo drafting [credit-memo-drafting]'
            'Open commitments:'
            '- Send the pilot timeline [C-2026-001]: the PO owes the credit risk lead, due 2026-03-04'
            'Decisions awaited:'
            "- Choose the pilot scope [D-2026-001]: from the sponsor, by 2026-03-06. Still lacks: The sponsor's position"
        ) -join "`n") $run.Output 'the brief of the 14:00'

    $run = Invoke-Register $ws brief 2026-03-03 10:00 -Now $Morning
    Assert-Equal 0 $run.ExitCode "exit code for another day, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^2026-03-03 10:00-11:00 KYC review, accepted\. Client banks: North Bank\.$' 'the meeting of another day'
    Assert-Match $run.Output '(?m)^- Share the test dataset \[C-2026-002\]: the data lead owes the PO, due 2026-02-27$' 'its commitment'

    $run = Invoke-Register $ws brief -Now $Morning
    Assert-Equal '09:30 11:00 14:00' (@([regex]::Matches($run.Output, '(?m)^2026-03-02 ([0-9:]+)-') | ForEach-Object { $_.Groups[1].Value }) -join ' ') 'without a time, every meeting of today'
    Assert-Match $run.Output '(?m)^Subjects: none of your subjects$' 'a meeting no watch list names'
}

Test 'brief says when no meeting starts at the time asked, or when the calendar is not read, and writes nothing' {
    $ws = New-TestWorkspaceWithMeetings
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws brief 15:00 -Now $Morning

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'No meeting of 2026-03-02 starts at 15:00 in the calendar snapshot\. Its meetings start at 09:30, 11:00, 14:00\.' 'what brief says'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'

    $fresh = New-TestWorkspaceWithSubject
    $run = Invoke-Register $fresh brief 14:00 -Now $Morning
    Assert-Equal 1 $run.ExitCode "exit code without a calendar, with output: $($run.Output)"
    Assert-Match $run.Output 'The calendar is off or was never read' 'what brief says without a calendar'
}
