# The blocks of the morning page that need the agent's judgement: Do first, the messages awaiting
# the PO's reply and the backlog alerts, which the agent leaves in state\morning.json beside its
# notes on the meetings, and the reminders and nudges for what others owe the PO.

# Monday 2 March 2026.
$ItemsMorning = '2026-03-02T07:12:00+01:00'

function Read-ItemsPage([string]$Workspace) {
    [IO.File]::ReadAllText((Join-Path $Workspace 'views\morning.html'), $Utf8)
}

function Get-ItemsBlock([string]$Page, [string]$Id) {
    if ($Page -match "(?s)<section class=`"block`" id=`"$Id`".*?</section>") { $Matches[0] }
}

function Get-ItemsCount([string]$Block) {
    if ($Block -match '(?s)<span class="count">(.*?)</span></h2>') { [Net.WebUtility]::HtmlDecode(($Matches[1] -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()) }
}

function Get-ItemsText([string]$Html) {
    [Net.WebUtility]::HtmlDecode(($Html -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim())
}

function Get-Action([string]$Block, [int]$Number) {
    # The HTML of one action of Do first, by its number.
    if ($Block -match "(?s)<li id=`"first-$Number`">.*?</li>") { $Matches[0] }
}

function Get-ItemsRow([string]$Html, [string]$Id) {
    # The HTML of the line of a ruled block that names a record.
    if ($Html -match "(?s)<li class=`"row[^`"]*`"[^>]*>(?:(?!</li>).)*(<span class=`"id`">|<span class=`"ref`">)$Id</span>.*?</li>") { $Matches[0] }
}

function Get-ItemsButton([string]$Html) {
    # The label and the request of the first button of some HTML.
    if ($Html -match '<button class="ask[^"]*" type="button" data-ask="([^"]*)"><svg class="i" aria-hidden="true"><use href="#i-copy"/></svg><span class="lbl">([^<]*)</span></button>') { [Net.WebUtility]::HtmlDecode("$($Matches[2]) | $($Matches[1])") }
}

function Set-Items([string]$Workspace, [hashtable]$Items) {
    Write-Json (Join-Path $Workspace 'state\morning.json') $Items
}

function New-ItemsWorkspace {
    # A workspace of Example Bank seen on Monday 2 March 2026:
    #   C-2026-001  the PO owes the sponsor, due Thu 26 Feb: late
    #   C-2026-002  the PO owes, due Thu 5, 2 days of effort, not started: to start today
    #   C-2026-003  the tech lead owes the PO, due Fri 27 Feb: late
    #   C-2026-004  the architect owes the PO, due Wed 4: within three working days
    #   C-2026-005  the data lead owes the PO, due Thu 5: within three working days
    #   C-2026-006  the head of payments owes the PO, due Fri 6: beyond three working days
    #   D-2026-001  pending, awaited from the PO by Wed 4
    #   D-2026-002  taken: the paper form is dropped
    $workspace = New-TestWorkspace
    $c = { param($Fields) New-RecordOperation commitment (@{ subject = 'line 1' } + $Fields) }
    $d = { param($Fields) New-RecordOperation decision (@{ subject = 'line 1' } + $Fields) }
    Set-Proposal $workspace @{ operations = @(
            (New-SubjectOperation @{ watch_list = @{ people = @('the tech lead'); keywords = @('onboarding'); tracker_projects = @('ONB'); chat_channels = @('onboarding squad') } }),
            (& $c @{ title = 'Send the onboarding figures'; owner = 'the PO'; owed_to = 'the sponsor'; due_date = '2026-02-26' }),
            (& $c @{ title = 'Review the target journey'; owner = 'the PO'; due_date = '2026-03-05'; estimated_effort = 2 }),
            (& $c @{ title = 'Deliver the test accounts'; owner = 'the tech lead'; owed_to = 'the PO'; due_date = '2026-02-27' }),
            (& $c @{ title = 'Send the hosting options'; owner = 'the architect'; owed_to = 'the PO'; due_date = '2026-03-04' }),
            (& $c @{ title = 'Share the test dataset'; owner = 'the data lead'; owed_to = 'the PO'; due_date = '2026-03-05' }),
            (& $c @{ title = 'Confirm the rates'; owner = 'the head of payments'; owed_to = 'the PO'; due_date = '2026-03-06' }),
            (& $d @{ title = 'Choose the pilot branches'; needed_from = 'the PO'; needed_by = '2026-03-04' }),
            (& $d @{ title = 'Drop the paper form'; status = 'taken'; decided_by = 'the sponsor' })
        )
    }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the day, with output: $($run.Output)"
    $workspace
}

Test 'Do first opens the white sheet, left of the meetings, and the blocks follow in the order of the spec' {
    $ws = New-ItemsWorkspace

    $run = Invoke-Register $ws morning -Now $ItemsMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $page = Read-ItemsPage $ws
    $order = @([regex]::Matches($page, '<section class="block" id="([a-z]+)"') | ForEach-Object { $_.Groups[1].Value }) -join ' '
    Assert-Equal 'first meetings start owe owed decisions messages backlog sort' $order 'blocks of the page, in order'
    Assert-Match $page '(?s)<div class="sheet">\s*<section class="block" id="first"[^>]*>.*?</section>\s*<section class="block" id="meetings"[^>]*>.*?</section>\s*</div>' 'Do first and the meetings in the white sheet'
}

Test 'Do first shows the actions the agent wrote, numbered, each with one line of why and a filled button: a record''s own button, or the one an action gives' {
    $ws = New-ItemsWorkspace
    Set-Items $ws @{ first = @(
            @{ record = 'C-2026-002'; title = 'Start the target journey review'; why = 'Due Thursday, two days of work [C-2026-002].' },
            @{ record = 'C-2026-003'; title = 'Chase the tech lead for the test accounts'; why = 'The pilot waits on them.'; button = 'Ignored'; ask = 'Ignored' },
            @{ title = 'Prepare the 14:00 with Harbour Bank'; why = 'They will ask for the pilot scope.'; button = 'Brief me'; ask = 'Brief me for the 14:00 with Harbour Bank' }
        )
    }

    $run = Invoke-Register $ws morning -Now $ItemsMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Get-ItemsBlock (Read-ItemsPage $ws) 'first'
    Assert-Equal '3 action(s), not read: notes' (Get-ItemsCount $block) 'counts of Do first'
    Assert-Match (Get-Action $block 1) '(?s)<span class="pick" aria-hidden="true">1</span>\s*<div><p class="a-title"><span class="sr">1\. </span>Start the target journey review</p><p class="a-why">Due Thursday, two days of work \(<span class="id">C-2026-002</span>\)\.</p></div>' 'the first action, its record shown discreetly'
    Assert-Equal 'What it needs | Tell me what C-2026-002 needs: Review the target journey' (Get-ItemsButton (Get-Action $block 1)) 'the button of a commitment to start'
    Assert-Match (Get-Action $block 1) '<button class="ask strong"' 'a filled button'
    Assert-Equal 'Draft reminder | Draft the reminder for C-2026-003' (Get-ItemsButton (Get-Action $block 2)) 'the button of a commitment owed late, whatever the action gives'
    Assert-Equal 'Brief me | Brief me for the 14:00 with Harbour Bank' (Get-ItemsButton (Get-Action $block 3)) 'the button an action without a record gives'
}

Test 'an action about a record no longer awaited gets no button that says it is still awaited: the action''s own button, or a neutral one' {
    $ws = New-ItemsWorkspace
    Set-Items $ws @{ first = @(
            @{ record = 'D-2026-002'; title = 'Tell the branches the paper form is dropped'; why = 'Taken by the sponsor [D-2026-002].' },
            @{ record = 'D-2026-002'; title = 'Announce the paper form is dropped'; why = 'The branches ask.'; button = 'Draft the note'; ask = 'Draft the note to the branches on D-2026-002' }
        )
    }

    $run = Invoke-Register $ws morning -Now $ItemsMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Get-ItemsBlock (Read-ItemsPage $ws) 'first'
    Assert-Equal 'Show it | Show me D-2026-002: Drop the paper form' (Get-ItemsButton (Get-Action $block 2)) 'the neutral button of a decision taken'
    Assert-Equal 'Draft the note | Draft the note to the branches on D-2026-002' (Get-ItemsButton (Get-Action $block 3)) 'the button the action gives, for a decision taken'
    Assert-True ($block -notmatch 'still waiting for') "a decision taken is said to be still waiting: $block"
}

Test 'the reference of a line shows its subject and its identifier apart, so that a long subject is cut and the identifier never is' {
    $ws = New-ItemsWorkspace

    Invoke-Register $ws morning -Now $ItemsMorning | Out-Null

    Assert-Match (Get-ItemsRow (Get-ItemsBlock (Read-ItemsPage $ws) 'owe') 'C-2026-001') '<span class="ref"><span class="subj">mobile-onboarding</span> &middot; <span class="id">C-2026-001</span></span>' 'the reference of a line'
    Assert-Match (Read-ItemsPage $ws) '\.ref:has\(> \.subj\) \{ display: flex;' 'the reference laid out so that only the subject shrinks'
    Assert-Match (Read-ItemsPage $ws) '\.ref \.subj \{ min-width: 0; overflow: hidden; text-overflow: ellipsis; \}' 'the subject cut with an ellipsis'
}

Test 'a commitment of the PO to start today or late to start, not started, is always among the actions: first, in the page''s words, when the agent left it out' {
    $ws = New-ItemsWorkspace
    Set-Items $ws @{ first = @(
            @{ record = 'C-2026-003'; title = 'Chase the tech lead'; why = 'The pilot waits.' },
            @{ record = 'D-2026-001'; title = 'Choose the pilot branches'; why = 'Awaited from you by Wednesday.' },
            @{ record = 'C-2026-001'; title = 'Send the figures'; why = 'Late.' }
        )
    }

    $run = Invoke-Register $ws morning -Now $ItemsMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Get-ItemsBlock (Read-ItemsPage $ws) 'first'
    Assert-Equal '1 1. Review the target journey Due Thu 5, 2 d of work, not started: today is the latest start. What it needs' (Get-ItemsText (Get-Action $block 1)) 'the action to start today'
    Assert-Equal 'C-2026-003 D-2026-001' (@(2, 3 | ForEach-Object { if ((Get-ItemsButton (Get-Action $block $_)) -match '(C|D)-2026-00\d') { $Matches[0] } }) -join ' ') 'the agent''s actions after it, up to three'
    Assert-True (-not (Get-Action $block 4)) 'a fourth action'
    Assert-Match $run.Output '(?m)^Start today: Review the target journey \[C-2026-002\]$' 'what morning prints'

    # Late to start, it says so in red.
    Set-Proposal $ws @{ operations = @((New-UpdateOperation 'C-2026-002' @{ due_date = '2026-03-04' })) }
    Invoke-Register $ws apply -Today 2026-03-02 | Out-Null
    Invoke-Register $ws morning -Now $ItemsMorning | Out-Null
    Assert-Match (Get-Action (Get-ItemsBlock (Read-ItemsPage $ws) 'first') 1) '<p class="a-why"><span class="late"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg> Due Wed 4, 2 d of work, not started: the latest start was Fri 27\.</span></p>' 'an action late to start'
}

Test 'an item has its button once, in its highest block: elsewhere its line keeps its place with a pointer to that block' {
    $ws = New-ItemsWorkspace
    Set-Items $ws @{ first = @(@{ record = 'C-2026-003'; title = 'Chase the tech lead'; why = 'The pilot waits.' }) }

    Invoke-Register $ws morning -Now $ItemsMorning | Out-Null

    $page = Read-ItemsPage $ws
    $owed = Get-ItemsRow (Get-ItemsBlock $page 'owed') 'C-2026-003'
    Assert-Match $owed '<span class="act"><a class="up" href="#first-2"><span class="pick" aria-hidden="true">2</span><span>In Do first<span class="sr">, number 2</span></span><svg class="i" aria-hidden="true"><use href="#i-up"/></svg></a></span>' 'the line owed points to Do first'
    Assert-True ($owed -notmatch '<button') 'the line owed has a second button'
    $start = Get-ItemsRow (Get-ItemsBlock $page 'start') 'C-2026-002'
    Assert-Match $start '<a class="up" href="#first-1">' 'Start soon points to Do first'
    Assert-Match (Get-ItemsRow (Get-ItemsBlock $page 'owe') 'C-2026-002') '<a class="up" href="#first-1">' 'What you owe points to Do first'
    Assert-Match (Get-ItemsRow (Get-ItemsBlock $page 'decisions') 'D-2026-001') '<button class="ask"' 'a decision in no higher block keeps its button'
}

Test 'a commitment under Start soon and not in Do first keeps its button there, and What you owe points to it' {
    $ws = New-ItemsWorkspace
    Set-Proposal $ws @{ operations = @((New-UpdateOperation 'C-2026-002' @{ due_date = '2026-03-06' })) }
    Invoke-Register $ws apply -Today 2026-03-02 | Out-Null

    Invoke-Register $ws morning -Now $ItemsMorning | Out-Null

    $page = Read-ItemsPage $ws
    Assert-Match (Get-ItemsRow (Get-ItemsBlock $page 'start') 'C-2026-002') '<li class="row start is-soon" id="start-C-2026-002">(?s:.*)<button class="ask"' 'Start soon keeps the button, in amber for this week'
    Assert-Match (Get-ItemsRow (Get-ItemsBlock $page 'owe') 'C-2026-002') '<a class="up" href="#start-C-2026-002"><span>In Start soon</span>' 'What you owe points to Start soon'
}

Test 'a file of items that cites a missing or superseded record is refused: Do first, the messages and the backlog alerts say they could not be written, and morning prints why' {
    $ws = New-ItemsWorkspace
    Set-Items $ws @{ first = @(@{ record = 'C-2026-099'; title = 'Chase'; why = 'Late.' }); messages = @(); backlog = @{ contradictions = @(@{ ticket = 'ONB-150'; title = 'Paper form'; decision = 'D-2026-007'; why = 'dropped' }) } }

    $run = Invoke-Register $ws morning -Now $ItemsMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $page = Read-ItemsPage $ws
    $first = Get-ItemsBlock $page 'first'
    Assert-Equal '1 action(s), could not be written, not read: notes' (Get-ItemsCount $first) 'counts of Do first'
    Assert-Match $first 'Review the target journey' 'the action to start today stays'
    Assert-Match $first '<p class="refused warn"><svg class="i" aria-hidden="true"><use href="#i-warn"/></svg> The agent&#39;s notes are not shown: C-2026-099 is not in the register\. D-2026-007 is not in the register\.</p>' 'why, as a warning, not in red'
    Assert-Match $first '<span class="warn"><svg class="i" aria-hidden="true"><use href="#i-warn"/></svg> could not be written</span>' 'the count says it could not be written, as a warning, not in red'
    Assert-True ($page -notmatch 'class="late">[^<]*(<svg[^>]*><use[^>]*/></svg>)? ?(could not be written|not read)') 'a block not written or a source not read is said in red'
    Assert-Equal 'could not be written, not read: mail, chat' (Get-ItemsCount (Get-ItemsBlock $page 'messages')) 'counts of the messages'
    Assert-Equal 'could not be written, not read: tracker' (Get-ItemsCount (Get-ItemsBlock $page 'backlog')) 'counts of the backlog alerts'
    Assert-True ($page -notmatch 'ONB-150') 'a line of the refused file is shown'
    Assert-Match $run.Output '(?m)^Not verified: state\\morning\.json\..*\n- C-2026-099 is not in the register\.\n- D-2026-007 is not in the register\.$' 'what morning prints'
}

Test 'an action that names no record and gives no button and request is refused' {
    $ws = New-ItemsWorkspace
    Set-Items $ws @{ first = @(@{ title = 'Think about it'; why = 'Because.' }) }

    $run = Invoke-Register $ws morning -Now $ItemsMorning

    Assert-Match $run.Output '(?m)^- Action 1 of first names no record and gives no button and ask\.$' 'what morning prints'
}

Test 'without the agent''s file, the blocks of the agent say it wrote nothing for them' {
    $ws = New-ItemsWorkspace

    Invoke-Register $ws morning -Now $ItemsMorning | Out-Null

    $page = Read-ItemsPage $ws
    Assert-Equal '1 action(s), the agent wrote nothing for it, not read: notes' (Get-ItemsCount (Get-ItemsBlock $page 'first')) 'counts of Do first'
    Assert-Equal 'the agent wrote nothing for it, not read: tracker' (Get-ItemsCount (Get-ItemsBlock $page 'backlog')) 'counts of the backlog alerts'
}

function Set-ItemsSources([string]$Workspace, [string[]]$Read) {
    # Declares mail, the tracker and chat read from folders, and leaves a collect that read these.
    $connections = Read-Json (Join-Path $Workspace 'connections.json')
    foreach ($source in 'mail', 'tracker', 'chat') { $connections.$source = @{ mode = 'folder'; folder = "exports\$source" } }
    Write-Json (Join-Path $Workspace 'connections.json') $connections
    Set-CollectProposal $Workspace '2026-03-02T06:50:00+01:00' (@('notes') + $Read)
    $run = Invoke-Register $Workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code of the collect, with output: $($run.Output)"
}

Test 'the messages awaiting the PO''s reply are a line each, the oldest first, with who asked, where and a button to draft the reply; a source not read is said' {
    $ws = New-ItemsWorkspace
    Set-ItemsSources $ws 'mail', 'chat', 'tracker'
    Set-Items $ws @{ messages = @(
            @{ source = 'chat'; from = 'the tech lead'; where = 'onboarding squad'; sent = '2026-03-02T06:15:00+01:00'; text = 'Can you confirm the pilot branches?' },
            @{ source = 'mail'; from = 'the architect'; where = 'Hosting options'; sent = '2026-02-27T16:40:00+01:00'; text = 'Which hosting do you prefer?' }
        )
    }

    Invoke-Register $ws morning -Now $ItemsMorning | Out-Null

    $block = Get-ItemsBlock (Read-ItemsPage $ws) 'messages'
    Assert-Equal '1 in mail, 1 in chat' (Get-ItemsCount $block) 'counts of the messages'
    Assert-Equal 'Fri 27 16:40 Which hosting do you prefer? from the architect in Hosting options mail Draft reply 06:15 Can you confirm the pilot branches? from the tech lead in onboarding squad chat Draft reply' (Get-ItemsText ($block -replace '(?s)^.*?</h2>', '')) 'the lines'
    Assert-Equal 'Draft reply | Draft my reply to the tech lead in onboarding squad: Can you confirm the pilot branches?' (Get-ItemsButton ($block -replace '(?s)^.*?onboarding squad', '')) 'the button of a message'

    # Chat off, the block says it was not read rather than disappearing.
    $connections = Read-Json (Join-Path $ws 'connections.json')
    $connections.chat = @{ mode = 'off' }
    Write-Json (Join-Path $ws 'connections.json') $connections
    Set-Items $ws @{ messages = @() }
    Set-CollectProposal $ws '2026-03-02T07:00:00+01:00' 'notes', 'mail', 'tracker'
    Invoke-Register $ws apply -Today 2026-03-02 | Out-Null
    Invoke-Register $ws morning -Now $ItemsMorning | Out-Null
    Assert-Equal 'none, not read: chat' (Get-ItemsCount (Get-ItemsBlock (Read-ItemsPage $ws) 'messages')) 'counts with chat off'
}

Test 'the backlog alerts are one count line, a red line per ticket that contradicts a recorded decision, and the tickets not ready or stale folded' {
    $ws = New-ItemsWorkspace
    Set-ItemsSources $ws 'mail', 'chat', 'tracker'
    Set-Items $ws @{ backlog = @{
            contradictions = @(@{ ticket = 'ONB-150'; title = 'Build the paper form fallback'; decision = 'D-2026-002'; why = 'the paper form is dropped' })
            not_ready      = @(@{ ticket = 'ONB-151'; title = 'Branch finder'; why = 'no acceptance criteria' }, @{ ticket = 'ONB-152'; title = 'Selfie check'; why = 'no estimate' })
            stale          = @(@{ ticket = 'ONB-120'; title = 'Language switch'; why = 'no update for 34 days' })
        }
    }

    $run = Invoke-Register $ws morning -Now $ItemsMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Get-ItemsBlock (Read-ItemsPage $ws) 'backlog'
    Assert-Equal '1 contradict(s) a decision, 2 not ready for the next refinement, 1 stale' (Get-ItemsCount $block) 'counts of the backlog alerts'
    Assert-Match $block '<span class="count"><span class="late">1 contradict\(s\) a decision</span>' 'the contradiction counted in red'
    Assert-True ($block -match '(?s)^(.*)<details class="more">(.*)$') 'nothing folds'
    $shown, $folded = $Matches[1], $Matches[2]
    Assert-Match $shown '<li class="row is-late">\s*<span class="when"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg><b>ONB-150</b></span>\s*<span class="what"><span class="t">Build the paper form fallback</span> <span class="who">against D-2026-002: the paper form is dropped</span></span>\s*<span class="ref">mobile-onboarding</span>' 'the line of the contradiction'
    Assert-Equal 'Show conflict | Show me how ONB-150 contradicts D-2026-002' (Get-ItemsButton $shown) 'its button'
    Assert-Equal 'ONB-151 ONB-152 ONB-120' (@([regex]::Matches($folded, '<b>([A-Z]+-\d+)</b>') | ForEach-Object { $_.Groups[1].Value }) -join ' ') 'the tickets folded'
    Assert-Match $folded '<span class="who">not ready: no acceptance criteria</span>' 'a ticket not ready'
    Assert-Match $run.Output '(?m)^Backlog alerts 1 contradict\(s\) a decision, 2 not ready for the next refinement, 1 stale$' 'what morning prints'
}

Test 'a reminder is offered for what is owed late, a nudge for what is due within three working days with no sign of progress; morning prints them' {
    $ws = New-ItemsWorkspace
    Set-Items $ws @{ progress = @{ 'C-2026-005' = 'the data lead shared a first extract on Friday' } }

    $run = Invoke-Register $ws morning -Now $ItemsMorning

    $owed = Get-ItemsBlock (Read-ItemsPage $ws) 'owed'
    Assert-Equal 'Draft reminder | Draft the reminder for C-2026-003' (Get-ItemsButton (Get-ItemsRow $owed 'C-2026-003')) 'late'
    Assert-Equal 'Nudge | Draft a nudge for C-2026-004' (Get-ItemsButton (Get-ItemsRow $owed 'C-2026-004')) 'due within three working days'
    Assert-Equal 'Show it | Show me where C-2026-005 stands' (Get-ItemsButton (Get-ItemsRow $owed 'C-2026-005')) 'due within three working days, with a sign of progress'
    Assert-Match (Get-ItemsRow $owed 'C-2026-005') '<span class="who">from the data lead, progress: the data lead shared a first extract on Friday</span>' 'the sign of progress'
    Assert-Equal 'Show it | Show me where C-2026-006 stands' (Get-ItemsButton (Get-ItemsRow $owed 'C-2026-006')) 'due beyond three working days'
    Assert-Match $run.Output '(?m)^Reminder to offer: Deliver the test accounts \[C-2026-003\], from the tech lead, due 2026-02-27\.$' 'the reminder printed'
    Assert-Match $run.Output '(?m)^Nudge to offer: Send the hosting options \[C-2026-004\], from the architect, due 2026-03-04\.$' 'the nudge printed'
    Assert-True ($run.Output -notmatch 'C-2026-005\], from') 'a commitment with progress is offered'
}
