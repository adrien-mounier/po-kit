# The steering pack: a deck of six slides that the register tool writes for a steering committee,
# views\steering\<date>.html, from the register and the agent's commentary, and that the morning
# page offers five working days ahead.

# Monday 2 March 2026; the retail steering committee meets on Monday 9 March, five working days on.
$SteeringNow = '2026-03-02T07:12:00+01:00'
$Committee = '2026-03-09'

function New-SteeringWorkspace {
    # A workspace of Example Bank seen on Monday 2 March 2026:
    #   mobile-onboarding          value 4, feasibility 4, risk 2, work changes: yes
    #   credit-memo-drafting       Harbour Bank; value 5, feasibility 3; high-risk under the AI Act
    #   complaint-triage-assistant not scored
    #   B-2026-001  onboarding time: baseline 40, target 20 minutes, 31 measured on 27 February
    #   D-2026-001  taken on 20 February by the sponsor
    #   D-2026-002  pending, awaited from the retail steering committee by 9 March
    #   D-2026-003  pending, awaited from the architect
    #   D-2026-004  taken, then superseded by D-2026-005
    #   R-2026-001  urgent; R-2026-002 watch
    #   C-2026-001  the tech lead owes the test accounts, due 25 February: late
    #   C-2026-002  the PO owes the pilot report, due 20 March
    # The calendar snapshot, read today, holds the committee and a meeting of today.
    $workspace = New-TestWorkspace
    $settings = Read-Json (Join-Path $workspace 'settings.json')
    $settings.banks = @('Harbour Bank', 'North Bank')
    Write-Json (Join-Path $workspace 'settings.json') $settings
    $scored = { param($Title, $Value, $Feasibility, $More) New-SubjectOperation (@{ title = $Title; value_score = $Value; value_reason = 'It saves hours.'; feasibility_score = $Feasibility; feasibility_reason = 'The data is at hand.' } + $More) }
    Set-Proposal $workspace @{ operations = @(
            (& $scored 'Mobile onboarding' 4 4 @{ risk_score = 2; risk_reason = 'A person checks each file.'; work_changes = 'yes'; work_changes_reason = 'Branch staff stop keying forms.' }),
            (& $scored 'Credit memo drafting' 5 3 @{ banks = @('Harbour Bank'); ai_act_high_risk = $true; ai_act_reason = 'It feeds a credit decision.' }),
            (New-SubjectOperation @{ title = 'Complaint triage assistant'; horizon = 'later' }),
            @{ op = 'create'; type = 'benefit'; interpreted = $false; fields = @{ title = 'Halve the time to open an account'; subject = 'line 1'; metric = 'Time a customer takes to open an account'; unit = 'minutes'
                    baseline = 40; target = 20; current_value = 31; measured_on = '2026-02-27'; owner = 'the head of retail operations'; evidence_level = 'fact'; source = @{ where = 'inbox/pilot review.md'; read_on = '2026-03-02' } } },
            (New-RecordOperation decision @{ title = 'Open the pilot to two branches'; subject = 'line 1'; status = 'taken'; decided_by = 'the sponsor'; date_of_fact = '2026-02-20' }),
            (New-RecordOperation decision @{ title = 'Fund the second wave'; subject = 'line 1'; needed_from = 'the retail steering committee'; needed_by = '2026-03-09' }),
            (New-RecordOperation decision @{ title = 'Choose the hosting'; subject = 'line 2'; needed_from = 'the architect' }),
            (New-RecordOperation decision @{ title = 'Keep the paper option'; subject = 'line 1'; status = 'taken'; decided_by = 'the sponsor'; date_of_fact = '2026-02-24' }),
            (New-RecordOperation risk @{ title = 'The pilot branches are not staffed'; subject = 'line 1'; severity = 'urgent' }),
            (New-RecordOperation risk @{ title = 'The scanner supplier may withdraw'; subject = 'line 1' }),
            (New-RecordOperation commitment @{ title = 'Deliver the test accounts'; subject = 'line 1'; owner = 'the tech lead'; owed_to = 'the PO'; due_date = '2026-02-25' }),
            (New-RecordOperation commitment @{ title = 'Write the pilot report'; subject = 'line 1'; owner = 'the PO'; due_date = '2026-03-20' })
        )
    }
    $run = Invoke-Register $workspace apply -Today 2026-02-27
    Assert-Equal 0 $run.ExitCode "exit code when recording the portfolio, with output: $($run.Output)"
    Set-Proposal $workspace @{ operations = @(New-RecordOperation decision @{ title = 'Drop the paper option'; status = 'taken'; decided_by = 'the sponsor'; date_of_fact = '2026-02-27'; supersedes = 'D-2026-004' }) }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when superseding the decision, with output: $($run.Output)"
    Set-SteeringCalendar $workspace @(
        @{ start = "${Committee}T10:00:00+01:00"; end = "${Committee}T12:00:00+01:00"; title = 'Retail steering committee'; attendees = @('the sponsor'); status = 'accepted' },
        @{ start = '2026-03-02T14:00:00+01:00'; end = '2026-03-02T15:00:00+01:00'; title = 'Onboarding design session'; attendees = @('the tech lead'); status = 'accepted' }
    )
    $workspace
}

function Set-SteeringCalendar([string]$Workspace, [object[]]$Meetings) {
    # Declares the calendar as read from a folder, and leaves the snapshot the morning routine
    # wrote from it today.
    $connections = Read-Json (Join-Path $Workspace 'connections.json')
    $connections | Add-Member -NotePropertyName calendar -NotePropertyValue @{ mode = 'folder'; folder = 'exports\calendar' } -Force
    Write-Json (Join-Path $Workspace 'connections.json') $connections
    Write-Json (Join-Path $Workspace 'state\calendar.json') @{ read_at = '2026-03-02T07:05:00+01:00'; from = '2026-02-27'; to = '2026-03-16'; meetings = @($Meetings); absences = @() }
}

function Read-Deck([string]$Workspace, [string]$Date = $Committee) {
    [IO.File]::ReadAllText((Join-Path $Workspace "views\steering\$Date.html"), $Utf8)
}

function Get-Slide([string]$Deck, [string]$Id) {
    # The text of a slide, as a reader sees it.
    if ($Deck -match "(?s)<section class=`"slide[^`"]*`" id=`"slide-$Id`".*?</section>") { [Net.WebUtility]::HtmlDecode(($Matches[0] -replace '<[^>]+>', ' ' -replace '\s+', ' ' -replace ' ([.,;:])', '$1').Trim()) }
}

Test 'steering <date> writes the deck of that committee, views\steering\<date>.html: six slides in a fixed order, one per landscape page, readable with no script and no network' {
    $ws = New-SteeringWorkspace

    $run = Invoke-Register $ws steering $Committee -Now $SteeringNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'views\\steering\\2026-03-09\.html' 'where the deck is'
    $deck = Read-Deck $ws
    Assert-Equal 'title portfolio value decisions risks next' (@([regex]::Matches($deck, '<section class="slide[^"]*" id="slide-([a-z]+)"') | ForEach-Object { $_.Groups[1].Value }) -join ' ') 'the slides, in order'
    Assert-Match $deck '@page\s*\{\s*size:\s*A4 landscape' 'a landscape page'
    Assert-Match $deck '\.slide\s*\{[^}]*break-after:\s*page' 'one slide per page'
    Assert-Match $deck '\.slide\s*\{[^}]*break-inside:\s*avoid' 'a slide never cut'
    Assert-True ($deck -notmatch '(?i)<script|<link|<img|https?:|@import|url\(') 'the deck needs a script or the network'
    Assert-Match (Get-Slide $deck 'title') 'Retail steering committee .*Monday 9 March 2026' 'the title slide names the meeting of the calendar and its date'
    Assert-Match (Get-Slide $deck 'title') 'Generated: 2026-03-02T07:12:00\+01:00\.' 'the title slide carries the stamp'
    Assert-Match (Get-Slide $deck 'next') '\b6 / 6\b' 'the slide number'
}

Test 'the portfolio slide ranks the scored subjects by value times feasibility with risk, the AI Act mark and whether the work changes beside the score, then names those not scored' {
    $ws = New-SteeringWorkspace

    Invoke-Register $ws steering $Committee -Now $SteeringNow | Out-Null

    $slide = Get-Slide (Read-Deck $ws) 'portfolio'
    Assert-Match $slide 'Rank Use case Value x feasibility Value Feasibility Risk AI Act Work changes 1 Mobile onboarding \[mobile-onboarding\] 16 4 4 2 - Yes 2 Credit memo drafting \[credit-memo-drafting\] Harbour Bank 15 5 3 - High-risk -' 'the ranked rows'
    Assert-Match $slide 'Not scored yet: Complaint triage assistant \[complaint-triage-assistant\]\.' 'the subjects not scored'
}

Test 'the value slide sets each benefit in play against its target: baseline, latest value with the day it was measured, target and who measures it' {
    $ws = New-SteeringWorkspace

    Invoke-Register $ws steering $Committee -Now $SteeringNow | Out-Null

    $slide = Get-Slide (Read-Deck $ws) 'value'
    Assert-Match $slide '^Value delivered Benefit Baseline Latest value Target Measured by Halve the time to open an account \[B-2026-001\] Mobile onboarding . Time a customer takes to open an account 40 minutes 31 minutes measured 27 Feb 2026 20 minutes the head of retail operations' 'the benefit against its target'
}

Test 'the decisions slide lists those taken since the last committee and those awaited, from the committee first; a superseded decision is never shown' {
    $ws = New-SteeringWorkspace

    Invoke-Register $ws steering $Committee -Now $SteeringNow | Out-Null

    $slide = Get-Slide (Read-Deck $ws) 'decisions'
    Assert-Match $slide 'Taken since 9 Feb 2026 Open the pilot to two branches \[D-2026-001\] the sponsor, 20 Feb 2026 Drop the paper option \[D-2026-005\] the sponsor, 27 Feb 2026 Awaited from the committee Fund the second wave \[D-2026-002\] from the retail steering committee, by 9 Mar 2026 Awaited from others Choose the hosting \[D-2026-003\] from the architect' 'the decisions'
    Assert-True ($slide -notmatch 'D-2026-004') "the superseded decision is shown: $slide"

    # With a deck of the last committee stored, the decisions are those taken since it met.
    Copy-Item (Join-Path $ws "views\steering\$Committee.html") (Join-Path $ws 'views\steering\2026-02-23.html')
    Invoke-Register $ws steering $Committee -Now $SteeringNow | Out-Null

    $slide = Get-Slide (Read-Deck $ws) 'decisions'
    Assert-Match $slide 'Taken since 23 Feb 2026 Drop the paper option \[D-2026-005\]' 'the decisions since the last deck'
    Assert-True ($slide -notmatch 'D-2026-001') "a decision taken before the last committee is shown: $slide"
}

Test 'the risks slide lists the open risks, the urgent first, and the commitments late, in red with how late they are' {
    $ws = New-SteeringWorkspace

    Invoke-Register $ws steering $Committee -Now $SteeringNow | Out-Null

    $deck = Read-Deck $ws
    $slide = Get-Slide $deck 'risks'
    Assert-Match $slide 'Open risks Urgent The pilot branches are not staffed \[R-2026-001\] Mobile onboarding Watch The scanner supplier may withdraw \[R-2026-002\] Mobile onboarding Commitments late Deliver the test accounts \[C-2026-001\] the tech lead owes it, due 25 Feb 2026, 5 day\(s\) late' 'the risks and the commitment late'
    Assert-True ($slide -notmatch 'C-2026-002') "a commitment not late is shown: $slide"
    Assert-Match $deck '<span class="late">[^<]*<svg[^>]*>.*?</svg> due 25 Feb 2026' 'the commitment late is in red'
}

Test 'verify checks a deck as it checks the weekly synthesis: it passes on the deck written, and fails once a record it cites is superseded, or when its stamp is cut' {
    $ws = New-SteeringWorkspace
    Invoke-Register $ws steering $Committee -Now $SteeringNow | Out-Null

    $run = Invoke-Register $ws verify "views\steering\$Committee.html"

    Assert-Equal 0 $run.ExitCode "exit code on the deck written, with output: $($run.Output)"
    Assert-Match $run.Output '^Verified: views\\steering\\2026-03-09\.html carries its stamp, and the \d+ record\(s\)' 'output'

    $path = Join-Path $ws "views\steering\$Committee.html"
    $deck = [IO.File]::ReadAllText($path, $Utf8)
    [IO.File]::WriteAllText($path, [regex]::Replace($deck, '<p>Register state: [^<]*</p>', ''), $Utf8)
    $run = Invoke-Register $ws verify "views\steering\$Committee.html"
    Assert-Equal 1 $run.ExitCode "exit code with the stamp cut, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^- The stamp is absent' 'the stamp cut'

    [IO.File]::WriteAllText($path, $deck, $Utf8)
    Set-Proposal $ws @{ operations = @(New-RecordOperation decision @{ title = 'Fund the second wave from the Q3 budget'; status = 'taken'; decided_by = 'the sponsor'; date_of_fact = '2026-03-03'; supersedes = 'D-2026-002' }) }
    Invoke-Register $ws apply -Today 2026-03-03 | Out-Null
    $run = Invoke-Register $ws verify "views\steering\$Committee.html"
    Assert-Equal 1 $run.ExitCode "exit code once a record it cites is superseded, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^- D-2026-002 is superseded by D-2026-006\.$' 'the record superseded'
}

Test 'the agent''s commentary of state\steering.json goes on its slides, citing records as a view does, and the next steps on the last slide; a commentary citing a superseded record is refused and nothing is written' {
    $ws = New-SteeringWorkspace
    Write-Json (Join-Path $ws 'state\steering.json') @{
        headline   = 'Onboarding is on track; the committee is asked to fund the second wave [D-2026-002].'
        portfolio  = 'Mobile onboarding leads the portfolio [mobile-onboarding].'
        value      = 'Onboarding time is down from 40 to 31 minutes [B-2026-001].'
        decisions  = 'One decision is asked of the committee today [D-2026-002].'
        risks      = 'The test accounts are late [C-2026-001].'
        next_steps = @('The PO writes the pilot report by 20 March [C-2026-002].', 'The tech lead delivers the test accounts [C-2026-001].')
    }

    $run = Invoke-Register $ws steering $Committee -Now $SteeringNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $deck = Read-Deck $ws
    Assert-Match (Get-Slide $deck 'title') 'Onboarding is on track; the committee is asked to fund the second wave \[D-2026-002\]\.' 'the headline'
    Assert-Match (Get-Slide $deck 'portfolio') '^The portfolio, ranked Mobile onboarding leads the portfolio \[mobile-onboarding\]\. Rank' 'the sentence of the portfolio slide'
    Assert-Match (Get-Slide $deck 'value') 'Onboarding time is down from 40 to 31 minutes \[B-2026-001\]\.' 'the sentence of the value slide'
    Assert-Match (Get-Slide $deck 'decisions') 'One decision is asked of the committee today \[D-2026-002\]\.' 'the sentence of the decisions slide'
    Assert-Match (Get-Slide $deck 'risks') 'The test accounts are late \[C-2026-001\]\.' 'the sentence of the risks slide'
    Assert-Match (Get-Slide $deck 'next') '^Next steps 1 The PO writes the pilot report by 20 March \[C-2026-002\]\. 2 The tech lead delivers the test accounts \[C-2026-001\]\.' 'the next steps'
    Assert-Equal 0 (Invoke-Register $ws verify "views\steering\$Committee.html").ExitCode 'verify on the deck with its commentary'

    Remove-Item (Join-Path $ws "views\steering\$Committee.html")
    Write-Json (Join-Path $ws 'state\steering.json') @{ headline = 'The paper option is kept [D-2026-004].'; next_steps = @('Ask the architect [D-2026-099].') }
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws steering $Committee -Now $SteeringNow

    Assert-Equal 1 $run.ExitCode "exit code with a superseded record cited, with output: $($run.Output)"
    Assert-Match $run.Output 'Not verified: state\\steering\.json' 'output'
    Assert-Match $run.Output '(?m)^- D-2026-004 is superseded by D-2026-005\.$' 'the superseded record'
    Assert-Match $run.Output '(?m)^- D-2026-099 is not in the register\.$' 'the missing record'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'steering writes no deck that verify would fail, as one whose record text cites a superseded record, and says why; the morning page then still offers the pack' {
    $ws = New-SteeringWorkspace
    Set-Proposal $ws @{ operations = @(New-RecordOperation risk @{ title = 'The branches may reopen the paper option [D-2026-004]'; subject = 'mobile-onboarding' }) }
    $run = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the risk, with output: $($run.Output)"
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws steering $Committee -Now $SteeringNow

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Not verified: views\\steering\\2026-03-09\.html' 'output'
    Assert-Match $run.Output '(?m)^- D-2026-004 is superseded by D-2026-005\.$' 'the superseded record'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
    $run = Invoke-Register $ws morning -Now $SteeringNow
    Assert-Match $run.Output '(?m)^Steering pack to offer: Retail steering committee on 2026-03-09\.$' 'the pack still offered'
}

Test 'the deck takes the sponsor''s language, as the weekly synthesis does: its labels, its dates and its stamp, and verify recognises it' {
    $ws = New-SteeringWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.languages.sponsor = 'fr'
    Write-Json (Join-Path $ws 'settings.json') $settings

    $run = Invoke-Register $ws steering $Committee -Now $SteeringNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $deck = Read-Deck $ws
    Assert-Match $deck '<html lang="fr">' 'the language of the deck'
    $french = Read-Json (Join-Path $KitRoot 'workspace-template\tools\labels\fr.json')
    Assert-Match (Get-Slide $deck 'title') ([regex]::Escape($french.steering.kicker) + ' Retail steering committee lundi 9 mars 2026') 'the title slide in French'
    Assert-Match (Get-Slide $deck 'title') ([regex]::Escape((($french.stamp.generated -f '2026-03-02T07:12:00+01:00') -replace ' ([.,;:])', '$1'))) 'the stamp in French'
    Assert-Match (Get-Slide $deck 'value') ('^' + [regex]::Escape($french.steering.value_heading)) 'a heading in French'
    Assert-Equal 0 (Invoke-Register $ws verify "views\steering\$Committee.html").ExitCode 'verify on the deck in French'
}

Test 'a deck template of the organisation in the workspace replaces the kit''s for that workspace; one that leaves out a place to fill is refused and writes nothing' {
    $ws = New-SteeringWorkspace
    $kitTemplate = Join-Path $ws 'tools\templates\steering.html'
    $kitBefore = (Get-FileHash $kitTemplate).Hash
    New-Item -ItemType Directory -Path (Join-Path $ws 'templates') | Out-Null
    [IO.File]::WriteAllText((Join-Path $ws 'templates\steering.html'), "<!doctype html><html lang=`"{{language}}`"><head><title>Harbour Group | {{title}}</title><style>.slide { break-after: page; }</style></head><body class=`"group-brand`">`n{{slides}}`n</body></html>", $Utf8)

    $run = Invoke-Register $ws steering $Committee -Now $SteeringNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $deck = Read-Deck $ws
    Assert-Match $deck '<title>Harbour Group \| Steering pack, Retail steering committee, Monday 9 March 2026</title>' 'the title of the organisation'
    Assert-Match $deck '<body class="group-brand">\s*<section class="slide cover" id="slide-title"' 'the slides in the organisation''s page'
    Assert-Equal $kitBefore (Get-FileHash $kitTemplate).Hash "the kit's template"

    [IO.File]::WriteAllText((Join-Path $ws 'templates\steering.html'), '<html><body>{{slides}}</body></html>', $Utf8)
    $before = Get-WorkspaceSnapshot $ws
    $run = Invoke-Register $ws steering $Committee -Now $SteeringNow
    Assert-Equal 1 $run.ExitCode "exit code with a template that lacks places, with output: $($run.Output)"
    Assert-Match $run.Output 'templates\\steering\.html lacks \{\{language\}\}, \{\{title\}\}' 'the places it lacks'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'steering alone names the committee whose pack to offer and the day its decisions are taken since, and writes nothing; a date that is not one is refused' {
    $ws = New-SteeringWorkspace
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws steering -Now $SteeringNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'Steering committee to prepare: Retail steering committee on 2026-03-09, decisions taken since 2026-02-09. Write its deck with: steering 2026-03-09' $run.Output 'output'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'

    $run = Invoke-Register $ws steering 'next monday' -Now $SteeringNow
    Assert-Equal 1 $run.ExitCode "exit code with no date, with output: $($run.Output)"
    Assert-Match $run.Output 'steering takes the date of the committee' 'output'
}

function Get-FirstBlockOf([string]$Workspace) {
    $page = [IO.File]::ReadAllText((Join-Path $Workspace 'views\morning.html'), $Utf8)
    if ($page -match '(?s)<section class="block" id="first".*?</section>') { $Matches[0] }
}

Test 'the morning page offers the steering pack in Do first, with a button that asks the agent to draft it, from five working days before a committee of the calendar until its deck exists; morning prints it to offer' {
    $ws = New-SteeringWorkspace

    $run = Invoke-Register $ws morning -Now $SteeringNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Steering pack to offer: Retail steering committee on 2026-03-09\.$' 'what morning prints'
    $block = Get-FirstBlockOf $ws
    Assert-Match $block '<div class="suggest">\s*<p><b>Steering pack:</b> Retail steering committee, Mon 9\. Its pack is not drafted yet\.</p>\s*<span class="btns"><button class="ask" type="button" data-ask="Draft the steering pack for Retail steering committee of 2026-03-09">(?:(?!</button>).)*<span class="lbl">Draft the pack</span></button></span>\s*</div>' 'the offer in Do first'

    # Six working days ahead, the committee is not offered yet.
    Set-SteeringCalendar $ws @(@{ start = '2026-03-10T10:00:00+01:00'; end = '2026-03-10T12:00:00+01:00'; title = 'Retail steering committee'; attendees = @('the sponsor'); status = 'accepted' })
    $run = Invoke-Register $ws morning -Now $SteeringNow
    Assert-True ($run.Output -notmatch 'Steering pack to offer') "a committee six working days ahead is offered: $($run.Output)"
    Assert-True ((Get-FirstBlockOf $ws) -notmatch 'Steering pack') 'a committee six working days ahead is on the page'

    # Once its deck exists, it is no longer offered.
    Set-SteeringCalendar $ws @(@{ start = "${Committee}T10:00:00+01:00"; end = "${Committee}T12:00:00+01:00"; title = 'Retail steering committee'; attendees = @('the sponsor'); status = 'accepted' })
    Invoke-Register $ws steering $Committee -Now $SteeringNow | Out-Null
    $run = Invoke-Register $ws morning -Now $SteeringNow
    Assert-True ($run.Output -notmatch 'Steering pack to offer') "a committee whose deck exists is offered: $($run.Output)"
}

Test 'the words that show a steering committee in a meeting title are a setting, steering_words, "steering committee" by default, whatever the case' {
    $template = Read-Json (Join-Path $KitRoot 'workspace-template\settings.json')
    Assert-Equal 'steering committee' (@($template.steering_words) -join ', ') 'the default words'

    $ws = New-SteeringWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.steering_words = @('Portfolio Board')
    Write-Json (Join-Path $ws 'settings.json') $settings
    Set-SteeringCalendar $ws @(
        @{ start = '2026-03-04T10:00:00+01:00'; end = '2026-03-04T12:00:00+01:00'; title = 'Retail steering committee'; attendees = @('the sponsor'); status = 'accepted' },
        @{ start = '2026-03-06T10:00:00+01:00'; end = '2026-03-06T12:00:00+01:00'; title = 'Q1 portfolio board'; attendees = @('the sponsor'); status = 'accepted' }
    )

    $run = Invoke-Register $ws morning -Now $SteeringNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'Steering pack to offer: Q1 portfolio board on 2026-03-06.' (@($run.Output -split "`n" | Where-Object { $_ -like 'Steering pack to offer*' }) -join ' | ') 'the committee offered'
}

Test 'the kit ships the steering routine and the deck template, and the workspace rules say where a deck template of the organisation goes and how the commentary is written' {
    $rules = Get-Content -LiteralPath (Join-Path $KitRoot 'workspace-template\AGENTS.md') -Raw -Encoding UTF8
    Assert-Match $rules 'A template of the organisation goes in `templates/steering\.html` in this workspace' 'where the deck template of the organisation goes'
    Assert-Match $rules '`steering_words`: as `\["steering committee"\]`' 'the setting'
    Assert-Match $rules '\{ "headline": "\.\.\.", "portfolio": "\.\.\.", "value": "\.\.\.", "decisions": "\.\.\.", "risks": "\.\.\.", "next_steps": \[' 'the commentary'
    $routine = Get-Content -LiteralPath (Join-Path $KitRoot 'routines\steering\SKILL.md') -Raw -Encoding UTF8
    Assert-Match $routine '`verify views/steering/2026-03-09\.html`' 'the routine verifies the deck'
    Assert-Match $routine 'a deck that fails is never offered' 'a deck that fails'
    Assert-True ($routine -notmatch '(?i)delete the deck') 'the routine has the agent delete a deck, a view only the register tool writes'
    Assert-Match $routine 'You send nothing' 'the routine sends nothing'
    $template = Join-Path $KitRoot 'workspace-template\tools\templates\steering.html'
    Assert-True ([IO.File]::ReadAllBytes($template)[0] -ne 0xEF) 'the deck template opens with a byte order mark'
}
