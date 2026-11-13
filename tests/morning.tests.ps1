# The morning page: views\morning.html, written by the register tool from the register, under the
# stamp of a view, in the look of docs\design\morning.html.

# Monday 2 March 2026: its week runs to Sunday 8 March.
$Early = '2026-03-02T07:12:00+01:00'

function Read-Page([string]$Workspace) {
    [IO.File]::ReadAllText((Join-Path $Workspace 'views\morning.html'), $Utf8)
}

function Get-Block([string]$Page, [string]$Id) {
    # The HTML of one block of the page, found by its identifier. Nothing when it is absent.
    if ($Page -match "(?s)<section class=`"block`" id=`"$Id`".*?</section>") { $Matches[0] }
}

Test 'morning writes views\morning.html: one self-contained file, UTF-8 without a byte order mark, its blocks in order' {
    $ws = New-TestWorkspaceWithSubject

    $run = Invoke-Register $ws morning -Now $Early

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'views\\morning\.html' 'output'
    $bytes = [IO.File]::ReadAllBytes((Join-Path $ws 'views\morning.html'))
    Assert-True ($bytes[0] -ne 0xEF) 'the page opens with a byte order mark'
    $page = Read-Page $ws
    Assert-Match $page '^<!doctype html>' 'first line of the page'
    Assert-Match $page '<meta charset="utf-8">' 'the page says its encoding'
    Assert-Match $page '<style>' 'inline styles'
    Assert-Match $page '<script>' 'inline script'
    Assert-True ($page -notmatch '(?i)(src|href)="(https?:)?//|<link|@import|url\(') 'the page loads something from elsewhere'
    $order = @([regex]::Matches($page, '<section class="block" id="([a-z]+)"') | ForEach-Object { $_.Groups[1].Value }) -join ' '
    Assert-Equal 'owe owed decisions sort' $order 'blocks of the page, in order'
}

function Get-Count([string]$Block) {
    # The counts that open a block, as text.
    if ($Block -match '(?s)<span class="count">(.*?)</span></h2>') { [Net.WebUtility]::HtmlDecode(($Matches[1] -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()) }
}

function Get-Ids([string]$Html) {
    # The identifiers of the records the lines of some HTML name, in order.
    @([regex]::Matches($Html, '<span class="ref">[^<]*&middot; ([^<]+)</span>') | ForEach-Object { $_.Groups[1].Value }) -join ' '
}

function Get-Row([string]$Html, [string]$Id) {
    # The HTML of the line that names a record.
    if ($Html -match "(?s)<li class=`"row[^`"]*`">(?:(?!</li>).)*&middot; $Id</span>.*?</li>") { $Matches[0] }
}

function New-TestWorkspaceWithDay {
    # A workspace of Example Bank seen on Monday 2 March 2026, whose week runs to Sunday 8 March:
    #   C-2026-001  the PO owes the sponsor, due Thu 26 Feb: late
    #   C-2026-002  the PO owes the tech lead, due today
    #   C-2026-003  the PO owes, due Thu 5 Mar: this week
    #   C-2026-004  the PO owes, due Fri 13 Mar: later
    #   C-2026-005  the tech lead owes the PO, due Fri 27 Feb: late
    #   C-2026-006  the architect owes the PO, due Wed 4 Mar: this week
    #   C-2026-007  the tech lead owes the architect: not the PO's
    #   C-2026-008  the PO owed it, done
    #   D-2026-001  pending, awaited from the PO by Wed 4 Mar
    #   D-2026-002  pending, awaited from the sponsor by Fri 27 Mar
    #   D-2026-003  taken
    $workspace = New-TestWorkspace
    $c = { param($Fields) New-RecordOperation commitment (@{ subject = 'line 1' } + $Fields) }
    $d = { param($Fields) New-RecordOperation decision (@{ subject = 'line 1' } + $Fields) }
    # The notes were read this morning, and the other sources are off.
    Set-Proposal $workspace @{ collected_at = '2026-03-02T06:50:00+01:00'; sources_read = @(@{ source = 'notes'; cutoff = '2026-03-02T06:50:00+01:00'; items = 0 })
        operations = @(
            (New-SubjectOperation),
            (& $c @{ title = 'Send the onboarding figures'; owner = 'the PO'; owed_to = 'the sponsor'; due_date = '2026-02-26' }),
            (& $c @{ title = 'Confirm the test scope'; owner = 'the PO'; owed_to = 'the tech lead'; due_date = '2026-03-02' }),
            (& $c @{ title = 'Review the target journey'; owner = 'the PO'; due_date = '2026-03-05' }),
            (& $c @{ title = 'Draft the pilot timeline'; owner = 'the PO'; due_date = '2026-03-13' }),
            (& $c @{ title = 'Deliver the test accounts'; owner = 'the tech lead'; owed_to = 'the PO'; due_date = '2026-02-27' }),
            (& $c @{ title = 'Send the hosting options'; owner = 'the architect'; owed_to = 'the PO'; due_date = '2026-03-04' }),
            (& $c @{ title = 'Share the sequence diagrams'; owner = 'the tech lead'; owed_to = 'the architect'; due_date = '2026-03-03' }),
            (& $c @{ title = 'Book the committee room'; owner = 'the PO'; due_date = '2026-03-03'; status = 'done' }),
            (& $d @{ title = 'Choose the pilot branches'; needed_from = 'the PO'; needed_by = '2026-03-04' }),
            (& $d @{ title = 'Fund the second pilot'; needed_from = 'the sponsor'; needed_by = '2026-03-27' }),
            (& $d @{ title = 'Keep the paper option'; status = 'taken'; decided_by = 'the sponsor' })
        )
    }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the day, with output: $($run.Output)"
    $workspace
}

Test 'each line is in its block, the earliest date first: what the PO owes, what is owed to the PO, the decisions awaited from the PO and from others' {
    $ws = New-TestWorkspaceWithDay

    $run = Invoke-Register $ws morning -Now $Early

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $page = Read-Page $ws
    Assert-Equal 'C-2026-001 C-2026-002 C-2026-003 C-2026-004' (Get-Ids (Get-Block $page 'owe')) 'lines of What you owe'
    Assert-Equal 'C-2026-005 C-2026-006' (Get-Ids (Get-Block $page 'owed')) 'lines of What others owe you'
    $decisions = Get-Block $page 'decisions'
    Assert-Match $decisions '(?s)<h3 class="grp">Awaited from you</h3>\s*<ul class="rows">(?:(?!<h3).)*D-2026-001</span>(?:(?!<h3).)*<h3 class="grp">You are waiting for</h3>(?:(?!<h3).)*D-2026-002</span>' 'decisions under their groups'
    Assert-True ($decisions -notmatch 'D-2026-003') 'a taken decision is listed'
    Assert-True ($page -notmatch 'C-2026-007|C-2026-008') 'a commitment that is not the PO, or is done, is listed'
    Assert-Match (Get-Row $page 'C-2026-001') 'Send the onboarding figures</span> <span class="who">to the sponsor</span>' 'who a line of What you owe is for'
    Assert-Match (Get-Row $page 'C-2026-005') '<span class="who">from the tech lead</span>' 'who owes a line of What others owe you'
    Assert-Match (Get-Row $page 'D-2026-002') '<span class="who">from the sponsor</span>' 'who a decision is awaited from'
}

Test 'each block opens on its counts, and the command prints them, one block per line' {
    $ws = New-TestWorkspaceWithDay

    $run = Invoke-Register $ws morning -Now $Early

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $page = Read-Page $ws
    Assert-Equal '1 late, 1 due today, 1 this week, 1 later' (Get-Count (Get-Block $page 'owe')) 'counts of What you owe'
    Assert-Equal '1 late, 1 this week' (Get-Count (Get-Block $page 'owed')) 'counts of What others owe you'
    Assert-Equal '1 awaited from you, 1 you are waiting for, 1 this week, 1 later' (Get-Count (Get-Block $page 'decisions')) 'counts of Decisions'
    Assert-Match $run.Output '(?m)^What you owe 1 late, 1 due today, 1 this week, 1 later$' 'counts printed for What you owe'
    Assert-Match $run.Output '(?m)^Decisions 1 awaited from you, 1 you are waiting for, 1 this week, 1 later$' 'counts printed for Decisions'
}

Test 'a late line is red with a warning icon and how late it is, a line due today or this week amber with a clock icon and its word, a later line neither' {
    $ws = New-TestWorkspaceWithDay

    Invoke-Register $ws morning -Now $Early | Out-Null

    $page = Read-Page $ws
    Assert-Match (Get-Row $page 'C-2026-001') '<li class="row is-late">\s*<span class="when"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg><b>Thu 26</b> <span class="lag">4 days late</span>' 'the late line'
    Assert-Match (Get-Row $page 'C-2026-005') '<span class="lag">3 days late</span>' 'how late the line owed is'
    Assert-Match (Get-Row $page 'C-2026-002') '<li class="row is-soon">\s*<span class="when"><svg class="i" aria-hidden="true"><use href="#i-clock"/></svg><b>Today</b>' 'the line due today'
    Assert-Match (Get-Row $page 'C-2026-003') '<li class="row is-soon">\s*<span class="when"><svg class="i" aria-hidden="true"><use href="#i-clock"/></svg><b>Thu 5</b> <span class="lag">this week</span>' 'the line due this week'
    Assert-Match (Get-Row $page 'C-2026-004') '<li class="row">\s*<span class="when"><b>Fri 13</b></span>' 'the later line'
}

Test 'each line carries a button that copies a request for the agent: a reminder for what is owed late, a nudge for what is owed this week' {
    $ws = New-TestWorkspaceWithDay

    Invoke-Register $ws morning -Now $Early | Out-Null

    $page = Read-Page $ws
    $button = { param($Id) if ((Get-Row $page $Id) -match '<button class="ask" type="button" data-ask="([^"]*)"><svg class="i" aria-hidden="true"><use href="#i-copy"/></svg><span class="lbl">([^<]*)</span></button>') { [Net.WebUtility]::HtmlDecode("$($Matches[2]) | $($Matches[1])") } }
    Assert-Equal 'Prepare it | Help me prepare C-2026-001: Send the onboarding figures' (& $button 'C-2026-001') 'button of a line the PO owes'
    Assert-Equal 'Draft reminder | Draft the reminder for C-2026-005' (& $button 'C-2026-005') 'button of a line owed late'
    Assert-Equal 'Nudge | Draft a nudge for C-2026-006' (& $button 'C-2026-006') 'button of a line owed this week'
    Assert-Equal 'Prepare it | Help me prepare decision D-2026-001: Choose the pilot branches' (& $button 'D-2026-001') 'button of a decision awaited from the PO'
    Assert-Equal "What's missing | Show what D-2026-002 is still waiting for" (& $button 'D-2026-002') 'button of a later decision awaited from others'
    # The button keeps its width when it says it copied, and a request the clipboard refuses shows in
    # a field to copy by hand.
    Assert-Match $page "b\.style\.minWidth = b\.offsetWidth \+ 'px'" 'the button keeps its width'
    Assert-Match $page '<input id="req" readonly value=' 'the field to copy by hand'
}

Test 'a block that holds nothing, its sources all read, is its heading and none on one line' {
    $ws = New-TestWorkspaceWithSubject
    Set-CollectProposal $ws '2026-03-02T06:50:00+01:00' 'notes'
    Invoke-Register $ws apply -Today 2026-03-02 | Out-Null

    $run = Invoke-Register $ws morning -Now $Early

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $page = Read-Page $ws
    foreach ($block in @(@('owe', 'What you owe'), @('owed', 'What others owe you'), @('decisions', 'Decisions'), @('sort', 'To sort'))) {
        Assert-Match (Get-Block $page $block[0]) "^<section class=`"block`" id=`"$($block[0])`" aria-labelledby=`"h-$($block[0])`">\r?\n<h2 id=`"h-$($block[0])`">$($block[1]) <span class=`"count`">none</span></h2>\r?\n</section>$" "the empty block $($block[0])"
    }
}

Test 'when the last collect did not read a source, each block says so, empty or not, and so does the bar' {
    $ws = New-TestWorkspaceWithDay
    $connections = Read-Json (Join-Path $ws 'connections.json')
    $connections.mail = @{ mode = 'folder'; folder = 'exports\mail' }
    Write-Json (Join-Path $ws 'connections.json') $connections

    Invoke-Register $ws morning -Now $Early | Out-Null

    $page = Read-Page $ws
    Assert-Equal '1 late, 1 due today, 1 this week, 1 later, not read: mail' (Get-Count (Get-Block $page 'owe')) 'counts of What you owe'
    Assert-Equal 'none, not read: mail' (Get-Count (Get-Block $page 'sort')) 'counts of To sort'
    Assert-Match (Get-Block $page 'sort') '<span class="late"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg> not read: mail</span>' 'what To sort says in red, with an icon'
    Assert-Match $page '<span class="src fail"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg>Not read: mail</span>' 'what the bar says'
}

Test 'the bar is the stamp of the page: the date, when it was written, the sources read and by which collect, those not read or off, and the register state' {
    $ws = New-TestWorkspaceWithDay
    $connections = Read-Json (Join-Path $ws 'connections.json')
    $connections.mail = @{ mode = 'folder'; folder = 'exports\mail' }
    Write-Json (Join-Path $ws 'connections.json') $connections

    Invoke-Register $ws morning -Now $Early | Out-Null

    $page = Read-Page $ws
    $state = "$(git -C $ws rev-parse HEAD:register)".Substring(0, 12)
    Assert-Match $page '<h1>Monday 2 March <span class="sub">Morning page, written <time datetime="2026-03-02T07:12:00\+01:00">07:12</time></span></h1>' 'the date and when the page was written'
    Assert-Match $page "<p class=`"sources`"><span class=`"src`">[^\n]*Read by the collect of 06:50: notes</span> <span class=`"src fail`">[^\n]*Not read: mail</span> <span class=`"src`">Off: tracker</span> <span class=`"src`">Register state $state</span></p>" 'the sources and the register state'
    Assert-Match $page '<title>Morning page, 2 Mar 2026</title>' 'the title of the page'

    $fresh = New-TestWorkspaceWithSubject
    Invoke-Register $fresh morning -Now $Early | Out-Null
    Assert-Match (Read-Page $fresh) 'No collect has run yet: no source is read' 'the bar before any collect'
}

Test 'To sort is one count line that opens in place: the pending proposal, each unclassified item and each stale subject' {
    $ws = New-TestWorkspaceWithDay
    [IO.File]::WriteAllText((Join-Path $ws 'state\unclassified.md'), "- 2026-02-27 | mail from the tech lead | Who owns the queue screens?`n- 2026-03-02 | inbox/corridor.md | The branch network asks for a demo.`n", $Utf8)
    Set-Proposal $ws @{ operations = @((New-RecordOperation commitment @{ title = 'Send the demo dates' })) }

    # The subject was last updated on 2 March, and is stale more than seven days later.
    $run = Invoke-Register $ws morning -Now 2026-03-12T07:12:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $sort = Get-Block (Read-Page $ws) 'sort'
    Assert-Match $sort '(?s)^<section class="block" id="sort"[^>]*>\s*<details class="fold">\s*<summary>\s*<h2 id="h-sort">To sort <span class="count">' 'the count line opens in place'
    Assert-Equal '4: 1 proposal waiting for your yes, 2 unclassified, 1 stale subject(s)' (Get-Count $sort) 'counts of To sort'
    Assert-Match $sort '<b>Proposal</b></span>\s*<span class="what"><span class="t">1 line\(s\) waiting for your yes</span></span>' 'the pending proposal'
    Assert-Match $sort '<span class="t">Who owns the queue screens\?</span> <span class="who">mail from the tech lead</span></span>\s*<span class="ref">collected Fri 27</span>' 'an unclassified item'
    Assert-Match $sort '<b>10 days</b></span>\s*<span class="what"><span class="t">Mobile onboarding</span> <span class="who">stale subject: no update since Mon 2</span></span>\s*<span class="ref">mobile-onboarding</span>' 'the stale subject'
    Assert-Match $sort 'data-ask="Show what is still open on mobile-onboarding"' 'the request for the stale subject'
}

Test 'the lines due later than this week fold beyond a short list, while late, today and this-week lines never fold' {
    $ws = New-TestWorkspace
    $later = @(1..6 | ForEach-Object { New-RecordOperation commitment @{ title = "Later task $_"; subject = 'line 1'; owner = 'the PO'; due_date = "2026-03-1$_" } })
    $late = @(1..6 | ForEach-Object { New-RecordOperation commitment @{ title = "Late task $_"; subject = 'line 1'; owner = 'the PO'; due_date = "2026-02-1$_" } })
    Set-Proposal $ws @{ operations = @((New-SubjectOperation)) + $later + $late }
    Invoke-Register $ws apply -Today 2026-03-02 | Out-Null

    Invoke-Register $ws morning -Now $Early | Out-Null

    $owe = Get-Block (Read-Page $ws) 'owe'
    Assert-True ($owe -match '(?s)^(.*)<details class="more">(.*)$') 'nothing folds'
    $shown, $folded = $Matches[1], $Matches[2]
    Assert-Equal 'C-2026-007 C-2026-008 C-2026-009 C-2026-010 C-2026-011 C-2026-012' (Get-Ids $shown) 'lines shown'
    Assert-Match $folded '<span class="closed-label">Show 6 more</span>' 'what the fold says'
    Assert-Equal 'C-2026-001 C-2026-002 C-2026-003 C-2026-004 C-2026-005 C-2026-006' (Get-Ids $folded) 'lines folded'
}

Test 'the labels are in the default language of the settings, and another language can be asked for; what the records say is not translated' {
    $ws = New-TestWorkspaceWithDay
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.languages.default = 'fr'
    Write-Json (Join-Path $ws 'settings.json') $settings

    $run = Invoke-Register $ws morning -Now $Early

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $page = Read-Page $ws
    Assert-Match $page '<html lang="fr">' 'language of the page'
    Assert-Match $page '<h1>lundi 2 mars ' 'the date'
    Assert-Match $page "<h2 id=`"h-owe`">Ce que vous devez <span class=`"count`"><span class=`"late`">1 en retard</span>" 'heading of What you owe'
    Assert-Match (Get-Row $page 'C-2026-001') '<b>jeu\. 26</b> <span class="lag">4 jours de retard</span>' 'a late line'
    Assert-Match (Get-Row $page 'C-2026-001') 'Send the onboarding figures' 'the title of a record'

    $run = Invoke-Register $ws morning en -Now $Early
    Assert-Match (Read-Page $ws) '<html lang="en">' 'language asked for'
    $run = Invoke-Register $ws morning xx -Now $Early
    Assert-Equal 1 $run.ExitCode 'exit code in a language without labels'
}

Test 'what a record says is shown as text: markup or a place of the page in a title stays as written' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @((New-SubjectOperation), (New-RecordOperation commitment @{ title = 'Check <b>bold</b> & {{blocks}} "quotes"'; subject = 'line 1'; owner = 'the PO' })) }
    Invoke-Register $ws apply -Today 2026-03-02 | Out-Null

    Invoke-Register $ws morning -Now $Early | Out-Null

    $row = Get-Row (Read-Page $ws) 'C-2026-001'
    Assert-Match $row '<span class="t">Check &lt;b&gt;bold&lt;/b&gt; &amp; \{\{blocks\}\} &quot;quotes&quot;</span>' 'the title on the page'
    Assert-Match $row 'data-ask="Help me prepare C-2026-001: Check &lt;b&gt;bold&lt;/b&gt; &amp; \{\{blocks\}\} &quot;quotes&quot;"' 'the title in the request'
    Assert-Match $row '<li class="row">\s*<span class="when"></span>' 'a line without a date'
}

Test 'morning replaces the page at each run, and apply commits it with the rest of the views' {
    $ws = New-TestWorkspaceWithDay
    Invoke-Register $ws morning -Now $Early | Out-Null
    Invoke-Register $ws morning -Now 2026-03-03T07:12:00+01:00 | Out-Null
    Assert-Match (Read-Page $ws) '<h1>Tuesday 3 March ' 'the page of the second run'

    Set-CollectProposal $ws '2026-03-03T07:00:00+01:00' 'notes'
    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code of apply, with output: $($run.Output)"
    Assert-Equal '' "$(git -C $ws status --porcelain views)" 'views left uncommitted'
    Assert-Match "$(git -C $ws show --stat --format= HEAD)" 'views/morning\.html' 'files of the commit'
}
