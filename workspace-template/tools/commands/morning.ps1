# morning: writes the morning page, views\morning.html, from the register: one self-contained HTML
# file that the PO reads in a browser, replaced at each run.
#
#   morning       with the labels of the default language of settings.json
#   morning fr    with the labels of another language; what the records say is never translated
#
# The page opens on the stamp of a view, in a bar: the date, when the page was written, the
# register state, the sources the last collect read and those it did not. Its blocks follow, in
# this order:
#   owe        What you owe: the open commitments whose owner is the PO
#   owed       What others owe you: the open commitments owed to the PO
#   decisions  Decisions: the pending decisions awaited from the PO, then those awaited from others
#   sort       To sort: the pending proposal, the unclassified items and the stale subjects, as one
#              count line that opens in place
# Each block is one function below that gives its HTML, and $blocks puts them in order: adding a
# block means adding its function and its place in that list. The styles and the script of the
# page are in tools\templates\morning.html, after docs\design\morning.html in the kit.
#
# A record names the PO "the PO", as the routines write it. A line is late when its date is past,
# then due today, this week (up to Sunday), later, or without a date, in that order. The late,
# today and this-week lines are always shown; the others fill the list up to five lines, and the
# rest fold. Each line carries a button that copies a request for the agent: the page changes
# nothing itself. Each block opens on its counts; a block that holds nothing says "none". When the
# last collect did not read a source that is not off, every block says so: what that source holds
# may be missing from the register.
#
# It prints where the page is, then the heading of each block with its counts, one per line.

# The stamp of the page names a committed register.
Assert-RegisterCommitted
$language = if ($Arguments) { "$Arguments" } else { $Settings.languages.default }
$labels = Get-Labels $language
$words = $labels.morning
$culture = [Globalization.CultureInfo]::GetCultureInfo($words.culture)
$invariant = [Globalization.CultureInfo]::InvariantCulture
$day = [DateTime]::ParseExact($Today, 'yyyy-MM-dd', $invariant)
$sunday = $day.AddDays((7 - [int]$day.DayOfWeek) % 7).ToString('yyyy-MM-dd', $invariant)
$shortList = 5

function Html($Text) { [Net.WebUtility]::HtmlEncode((Format-Value $Text)) }

function Icon([string]$Name, [string]$Class = 'i') { "<svg class=`"$Class`" aria-hidden=`"true`"><use href=`"#i-$Name`"/></svg>" }

function Format-Day([string]$Date) {
    # Today, a weekday and its number within two weeks of today, or a full date further away.
    $when = [DateTime]::ParseExact($Date, 'yyyy-MM-dd', $invariant)
    $gap = ($when - $day).Days
    if ($gap -eq 0) { $words.today } elseif ([Math]::Abs($gap) -le 13) { $when.ToString($words.near_date, $culture) } else { $when.ToString($words.far_date, $culture) }
}

function Format-Moment([string]$Timestamp) {
    # The time of a moment of today, or its day and time.
    $moment = Read-Timestamp $Timestamp
    $time = $moment.ToString('HH:mm', $invariant)
    $date = $moment.ToString('yyyy-MM-dd', $invariant)
    if ($date -eq $Today) { $time } else { "$(Format-Day $date) $time" }
}

function Get-Dated([string]$Date) {
    if (-not $Date) { 'none' } elseif ($Date -lt $Today) { 'late' } elseif ($Date -eq $Today) { 'today' } elseif ($Date -le $sunday) { 'week' } else { 'later' }
}

function Test-IsPo($Name) { (Format-Value $Name).Trim() -eq 'the PO' }

function New-Line([string]$Date, [string]$Id, [string]$Title, [string]$Who, [string]$Subject, [string]$Button, [string]$Ask) {
    # One dated line of a block: its date, its title and who it concerns, its subject and its
    # identifier, and its button.
    $dated = Get-Dated $Date
    $when = switch ($dated) {
        'late' {
            $days = Get-DaysSince $Date
            "$(Icon alert)<b>$(Html (Format-Day $Date))</b> <span class=`"lag`">$(Html $(if ($days -eq 1) { $words.late_one } else { $words.late_many -f $days }))</span>"
        }
        'today' { "$(Icon clock)<b>$(Html $words.today)</b>" }
        'week' { "$(Icon clock)<b>$(Html (Format-Day $Date))</b> <span class=`"lag`">$(Html $words.this_week)</span>" }
        'later' { "<b>$(Html (Format-Day $Date))</b>" }
        default { '' }
    }
    $class = @{ late = ' is-late'; today = ' is-soon'; week = ' is-soon' }[$dated]
    @{
        date = $Date; id = $Id; dated = $dated
        html = New-Row $class $when $Title $Who "$(Html $Subject) &middot; $(Html $Id)" $Button $Ask
    }
}

function New-Row([string]$Class, [string]$When, [string]$Title, [string]$Who, [string]$Ref, [string]$Button, [string]$Ask) {
    # A line of a block, as HTML lines: one for the line, one per column.
    "<li class=`"row$Class`">"
    "<span class=`"when`">$When</span>"
    $who = if ($Who) { ' <span class="who">' + (Html $Who) + '</span>' }
    "<span class=`"what`"><span class=`"t`">$(Html $Title)</span>$who</span>"
    "<span class=`"ref`">$Ref</span>"
    "<span class=`"act`"><button class=`"ask`" type=`"button`" data-ask=`"$(Html $Ask)`">$(Icon copy)<span class=`"lbl`">$(Html $Button)</span></button></span>"
    '</li>'
}

function Format-Lines($Lines) {
    # The lines of a list, the earliest date first: the late, today and this-week lines shown, the
    # others shown up to the short list, and the rest folded.
    $Lines = @($Lines | Sort-Object @{ Expression = { if ($_.date) { $_.date } else { '9999-99-99' } } }, @{ Expression = { $_.id } })
    $shown = [Math]::Max(@($Lines | Where-Object { 'late', 'today', 'week' -contains $_.dated }).Count, $shortList)
    '<ul class="rows">'
    $Lines | Select-Object -First $shown | ForEach-Object { $_.html }
    '</ul>'
    $rest = $Lines.Count - $shown
    if ($rest -gt 0) {
        '<details class="more">'
        "<summary>$(Icon chev 'i chev')<span class=`"lbl-t`"><span class=`"closed-label`">$(Html ($words.show_more -f $rest))</span><span class=`"open-label`">$(Html ($words.hide_more -f $rest))</span></span></summary>"
        '<ul class="rows">'
        $Lines | Select-Object -Skip $shown | ForEach-Object { $_.html }
        '</ul>'
        '</details>'
    }
}

function Format-Count([string[]]$Counts, $Lines) {
    # The counts that open a block: those given, then its lines by date, then the sources not read.
    $parts = @($Counts)
    foreach ($kind in @(@('late', 'count_late', 'late'), @('today', 'count_today', 'soon'), @('week', 'count_week', 'soon'), @('later', 'count_later', ''), @('none', 'count_no_date', ''))) {
        $count = @($Lines | Where-Object { $_.dated -eq $kind[0] }).Count
        if ($count) { $parts += $(if ($kind[2]) { "<span class=`"$($kind[2])`">$(Html ($words.($kind[1]) -f $count))</span>" } else { Html ($words.($kind[1]) -f $count) }) }
    }
    if (-not $parts) { $parts = , (Html $words.none) }
    if ($unread) { $parts += "<span class=`"late`">$(Icon alert) $(Html ($words.block_not_read -f ($unread -join ', ')))</span>" }
    $parts -join ', '
}

function Format-Block([string]$Id, [string]$Heading, [string]$Count, [string[]]$Body) {
    "<section class=`"block`" id=`"$Id`" aria-labelledby=`"h-$Id`">"
    "<h2 id=`"h-$Id`">$(Html $Heading) <span class=`"count`">$Count</span></h2>"
    $Body | Where-Object { $_ }
    '</section>'
}

# --- The blocks ---------------------------------------------------------------------------------

$records = @(Get-RecordFiles | Where-Object { 'commitment', 'decision' -contains $_.type } | ForEach-Object { Read-JsonFile $_.path })
$commitments = @($records | Where-Object { $_.type -ceq 'commitment' -and $_.status -ceq 'open' })
$decisions = @($records | Where-Object { $_.type -ceq 'decision' -and $_.status -ceq 'pending' })
# The sources the collects should read and the last one did not.
$unread = @(Get-Coverage | Where-Object { $_.mode -cne 'off' -and -not $_.covered } | ForEach-Object { $_.source })

function Get-OweBlock {
    $owe = $words.owe
    $lines = @(foreach ($commitment in $commitments | Where-Object { Test-IsPo $_.owner }) {
            $to = if ("$($commitment.owed_to)".Trim()) { $owe.to -f (Format-Value $commitment.owed_to) }
            New-Line $commitment.due_date $commitment.id $commitment.title $to $commitment.subject $owe.button ($owe.ask -f $commitment.id, (Format-Value $commitment.title))
        })
    Format-Block 'owe' $owe.heading (Format-Count @() $lines) $(if ($lines) { Format-Lines $lines })
}

function Get-OwedBlock {
    $owed = $words.owed
    $lines = @(foreach ($commitment in $commitments | Where-Object { (Test-IsPo $_.owed_to) -and -not (Test-IsPo $_.owner) }) {
            $from = if ("$($commitment.owner)".Trim()) { $owed.from -f (Format-Value $commitment.owner) }
            $button, $ask = switch (Get-Dated $commitment.due_date) {
                'late' { $owed.reminder, $owed.ask_reminder }
                { 'today', 'week' -contains $_ } { $owed.nudge, $owed.ask_nudge }
                default { $owed.show, $owed.ask_show }
            }
            New-Line $commitment.due_date $commitment.id $commitment.title $from $commitment.subject $button ($ask -f $commitment.id)
        })
    Format-Block 'owed' $owed.heading (Format-Count @() $lines) $(if ($lines) { Format-Lines $lines })
}

function Get-DecisionsBlock {
    $said = $words.decisions
    $fromYou = @(foreach ($decision in $decisions | Where-Object { Test-IsPo $_.needed_from }) {
            New-Line $decision.needed_by $decision.id $decision.title '' $decision.subject $said.prepare ($said.ask_prepare -f $decision.id, (Format-Value $decision.title))
        })
    $fromOthers = @(foreach ($decision in $decisions | Where-Object { -not (Test-IsPo $_.needed_from) }) {
            $from = if ("$($decision.needed_from)".Trim()) { $said.from -f (Format-Value $decision.needed_from) }
            $button, $ask = if ('late', 'today', 'week' -contains (Get-Dated $decision.needed_by)) { $said.nudge, $said.ask_nudge } else { $said.missing, $said.ask_missing }
            New-Line $decision.needed_by $decision.id $decision.title $from $decision.subject $button ($ask -f $decision.id)
        })
    $counts = @(if ($fromYou -or $fromOthers) { Html ($said.count_from_you -f $fromYou.Count); Html ($said.count_from_others -f $fromOthers.Count) })
    $body = if ($fromYou -or $fromOthers) {
        foreach ($group in @(@($said.from_you, $fromYou), @($said.from_others, $fromOthers))) {
            "<h3 class=`"grp`">$(Html $group[0])</h3>"
            if ($group[1]) { Format-Lines $group[1] } else { "<p class=`"grp-none`">$(Html $words.none)</p>" }
        }
    }
    Format-Block 'decisions' $said.heading (Format-Count $counts @($fromYou + $fromOthers)) $body
}

function Get-SortBlock {
    $said = $words.sort
    $counts = @()
    $rows = @()
    if (Test-Path -LiteralPath $ProposalPath) {
        $operations = try { @((Read-JsonFile $ProposalPath).operations | Where-Object { $null -ne $_ }).Count } catch { 0 }
        $counts += Html $said.count_proposal
        $rows += New-Row '' "<b>$(Html $said.proposal)</b>" ($said.proposal_lines -f $operations) '' '' $said.review $said.ask_review
    }
    # An unclassified item is a line of the list as apply writes it: the date collected, the source,
    # the text.
    $listPath = Join-Path $Workspace 'state\unclassified.md'
    $items = @(if (Test-Path -LiteralPath $listPath) { [IO.File]::ReadAllLines($listPath, $Utf8) | Where-Object { $_ -cmatch '^- \d{4}-\d\d-\d\d \| .+ \| .+$' } })
    if ($items) { $counts += Html ($said.count_unclassified -f $items.Count) }
    foreach ($item in $items) {
        $null = $item -cmatch '^- (\d{4}-\d\d-\d\d) \| (.+?) \| (.+)$'
        $source, $text = $Matches[2], $Matches[3]
        $rows += New-Row '' "<b>$(Html $said.unclassified)</b>" $text $source (Html ($said.collected -f (Format-Day $Matches[1]))) $said.classify ($said.ask_classify -f $source, $text)
    }
    $stale = @(Get-CheckFindings $labels | Where-Object { $_.rule -eq 'subject_stale' })
    if ($stale) { $counts += Html ($said.count_stale -f $stale.Count) }
    foreach ($subject in $stale) {
        $rows += New-Row '' "<b>$(Html ($said.stale_days -f (Get-DaysSince $subject.updated)))</b>" $subject.title ($said.stale -f (Format-Day $subject.updated)) (Html $subject.id) $said.open ($said.ask_open -f $subject.id)
    }
    $total = $(if (Test-Path -LiteralPath $ProposalPath) { 1 } else { 0 }) + $items.Count + $stale.Count
    $count = if ($total) { "${total}: " + (Format-Count $counts @()) } else { Format-Count @() @() }
    if (-not $rows) { return Format-Block 'sort' $said.heading $count @() }
    # One count line that opens in place.
    "<section class=`"block`" id=`"sort`" aria-labelledby=`"h-sort`">"
    '<details class="fold">'
    '<summary>'
    "<h2 id=`"h-sort`">$(Html $said.heading) <span class=`"count`">$count</span></h2>"
    "<span class=`"tog`">$(Icon chev 'i chev')<span class=`"closed-label`">$(Html $said.show)</span><span class=`"open-label`">$(Html $said.hide)</span></span>"
    '</summary>'
    '<ul class="rows">'
    $rows
    '</ul>'
    '</details>'
    '</section>'
}

# --- The page -----------------------------------------------------------------------------------

function Get-Header {
    # The stamp of the page.
    $collectPath = Join-Path $Workspace 'state\last-collect.json'
    $coverage = @(Get-Coverage)
    $sources = @(
        if (Test-Path -LiteralPath $collectPath) {
            $read = @($coverage | Where-Object { $_.covered } | ForEach-Object { $_.source })
            if ($read) { "<span class=`"src`">$(Icon check)$(Html ($words.read -f ($read -join ', '), (Format-Moment (Read-JsonFile $collectPath).collected_at)))</span>" }
            if ($unread) { "<span class=`"src fail`">$(Icon alert)$(Html ($words.not_read -f ($unread -join ', ')))</span>" }
        }
        else { "<span class=`"src fail`">$(Icon alert)$(Html $words.no_collect)</span>" }
        $off = @($coverage | Where-Object { $_.mode -ceq 'off' } | ForEach-Object { $_.source })
        if ($off) { "<span class=`"src`">$(Html ($words.off -f ($off -join ', ')))</span>" }
        "<span class=`"src`">$(Html ($words.register_state -f "$(Invoke-Git write-tree --prefix=register/)".Substring(0, 12)))</span>"
    )
    $written = (Html $words.written).Replace('{0}', '<time datetime="' + $Now + '">' + (Format-Moment $Now) + '</time>')
    '<header class="bar">'
    '<div class="wrap">'
    "<h1>$(Html $day.ToString($words.long_date, $culture)) <span class=`"sub`">$written</span></h1>"
    "<p class=`"sources`">$($sources -join ' ')</p>"
    '</div>'
    '</header>'
}

$blocks = @(Get-OweBlock) + @(Get-OwedBlock) + @(Get-DecisionsBlock) + @(Get-SortBlock)
$newLine = [Environment]::NewLine
$page = [IO.File]::ReadAllText((Join-Path $Tools 'templates\morning.html'), $Utf8)
# What a record says goes in last, so that no text of a record is read as a place to fill.
$page = $page.Replace('{{language}}', $language).Replace('{{title}}', (Html ($words.title -f $day.ToString($words.far_date, $culture)))).
    Replace('{{script}}', (ConvertTo-Json -InputObject $words.script -Compress)).Replace('{{footer}}', (Html $words.footer)).
    Replace('{{header}}', (@(Get-Header) -join $newLine)).Replace('{{blocks}}', ($blocks -join $newLine))
Write-TextFile (Join-Path $Workspace 'views\morning.html') $page

"Morning page written in '$language': views\morning.html"
foreach ($heading in [regex]::Matches(($blocks -join $newLine), '<h2 id="h-[a-z]+">(.*?)</h2>')) {
    [Net.WebUtility]::HtmlDecode(($heading.Groups[1].Value -replace '<[^>]+>', '' -replace '\s+', ' ').Trim())
}
