# steering: writes the steering pack of a steering committee, views\steering\<date>.html: one
# self-contained HTML deck of six slides, one A4 landscape page each, that the PO presents and
# prints to PDF from the browser.
#
#   steering              names each steering committee whose pack to offer, as the morning page
#                         does, and the day its decisions are taken since. It writes nothing.
#   steering 2026-03-09   writes the deck of the committee of that date, replacing the last one
#
# The slides, in this order: the title, with the meeting and its date as the calendar snapshot
# names them, and the stamp; the portfolio ranked as view ranking ranks it, with risk, the AI Act
# mark and whether the work changes beside the score; each benefit open or achieved against its
# target; the decisions taken since the last committee and those awaited, from the committee first;
# the open risks and the commitments late; the next steps. The labels are those of the sponsor's
# language, languages.sponsor of settings.json, as for the weekly synthesis.
#
# The last committee is the latest deck of views\steering before that date, or four weeks before
# it when there is none. The agent's commentary is state\steering.json, written as UTF-8 without a
# byte order mark:
#   { "headline": "...", "portfolio": "...", "value": "...", "decisions": "...", "risks": "...",
#     "next_steps": [ "...", "..." ] }
# one sentence for the title slide and for each slide named, then the next steps. Each cites the
# records it speaks of as a view does, [identifier]; one that cites a record missing or superseded
# is refused, and nothing is written. The deck itself is checked as verify checks it before it is
# written: one that would fail, as when the text of a record cites a superseded one, is not.
#
# The deck is written from a template: templates\steering.html in the workspace when the
# organisation has its own, otherwise the kit's, tools\templates\steering.html. Its {{language}},
# {{title}} and {{slides}} are replaced, in one pass; a template that leaves one out is refused, and
# so is one that holds a script or calls the network.

# The stamp of the deck names a committed register.
Assert-RegisterCommitted
$labels = Get-Labels $Settings.languages.sponsor
$words = $labels.steering
$culture = [Globalization.CultureInfo]::GetCultureInfo($labels.morning.culture)
$invariant = [Globalization.CultureInfo]::InvariantCulture
$date = "$($Arguments | Select-Object -First 1)"

function Get-Since([string]$Date) {
    # The day the last committee met: the latest deck before this one, or four weeks before.
    $folder = Join-Path $Workspace 'views\steering'
    $before = @(if (Test-Path -LiteralPath $folder) { Get-ChildItem -LiteralPath $folder -Filter *.html | ForEach-Object { $_.BaseName } | Where-Object { (Test-IsoDate $_) -and $_ -lt $Date } | Sort-Object })
    if ($before) { $before[-1] } else { ([DateTime]::ParseExact($Date, 'yyyy-MM-dd', $invariant)).AddDays(-28).ToString('yyyy-MM-dd', $invariant) }
}

if (-not $date) {
    $committees = @(Get-SteeringCommittees)
    if (-not $committees) { 'No steering committee of the calendar snapshot of today, within five working days, lacks its pack. To write one for another date: steering 2026-03-09' }
    foreach ($committee in $committees) { "Steering committee to prepare: $($committee.title) on $($committee.date), decisions taken since $(Get-Since $committee.date). Write its deck with: steering $($committee.date)" }
    return
}
if (-not (Test-IsoDate $date)) { Stop-Run "steering takes the date of the committee, as an ISO date (yyyy-mm-dd), not '$date'. Nothing was written: steering 2026-03-09" }
$since = Get-Since $date

# The agent's commentary, verified as verify checks a view.
$notesPath = Join-Path $Workspace 'state\steering.json'
$notes = $null
if (Test-Path -LiteralPath $notesPath) {
    $notes = try { Read-JsonFile $notesPath } catch { Stop-Run 'state\steering.json cannot be read: it must hold JSON, saved as UTF-8. Nothing was written.' }
    $problems = @(Test-Cited @(Get-Cited ((@(Get-Texts $notes)) -join "`n")))
    if ($problems) { Stop-Run (@('Not verified: state\steering.json. Nothing was written; correct it, then run steering again.') + @($problems | ForEach-Object { "- $_" })) }
}

# The meeting as the calendar snapshot names it, or in the deck's own words.
$snapshot = Read-CalendarSnapshot
$meeting = @(Get-DayMeetings $snapshot $date | Where-Object { Test-SteeringTitle "$($_.title)" } | ForEach-Object { "$($_.title)" }) | Select-Object -First 1
if (-not $meeting) { $meeting = $words.meeting }
$day = [DateTime]::ParseExact($date, 'yyyy-MM-dd', $invariant)
$when = $day.ToString($words.date, $culture)

function Format-Day([string]$Date) { [DateTime]::ParseExact($Date, 'yyyy-MM-dd', $invariant).ToString($labels.morning.far_date, $culture) }

function Format-Cited($Record) { "$(Html $Record.title) <span class=`"id`">[$(Html $Record.id)]</span>" }

function Format-Note([string]$Text) {
    # A text of the agent as HTML: a record it cites keeps its brackets, discreet, so that verify
    # reads it in the deck.
    [regex]::Replace((Html $Text), '\[([^\[\]]*)\]', { param($Found) if (@(Get-Cited $Found.Value).Count) { "<span class=`"id`">$($Found.Value)</span>" } else { $Found.Value } })
}

function Format-Key([string]$Name) { $said = "$($notes.$Name)".Trim(); if ($said) { "<p class=`"key`">$(Format-Note $said)</p>" } }

function Format-Items($Items, [int]$Most) {
    # A list of items, each its title and a line below, at most $Most and the number left over.
    $Items = @($Items)
    if (-not $Items) { return "<p class=`"none`">$(Html $words.none)</p>" }
    '<ul class="items">'
    $Items | Select-Object -First $Most | ForEach-Object { "<li>$($_.tag)<span class=`"t`">$($_.title)</span><span class=`"meta`">$($_.meta)</span></li>" }
    '</ul>'
    if ($Items.Count -gt $Most) { "<p class=`"note`">$(Html ($words.more -f ($Items.Count - $Most)))</p>" }
}

$icon = @{
    warn  = '<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5v5.5"/><path d="M12 16.5v.01"/></svg>'
    alert = '<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3.5l9.5 16.5h-19z"/><path d="M12 10v4.5"/><path d="M12 17.5v.01"/></svg>'
    check = '<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
}
$script:number = 0

function New-Slide([string]$Id, [string]$Heading, [string[]]$Body, [string]$Class = '') {
    $script:number++
    "<section class=`"slide$Class`" id=`"slide-$Id`" aria-labelledby=`"h-$Id`">"
    if ($Heading) { "<header class=`"s-head`"><h2 id=`"h-$Id`">$(Html $Heading)</h2></header>" }
    $Body | Where-Object { $_ }
    # The number of slides is known once they are all built: the mark takes it then.
    "<footer class=`"s-foot`"><span>$(Html $meeting) &middot; $(Html $when)</span><span>$([string]::Format((Html $words.page), $script:number, '<!--slides-->'))</span></footer>"
    '</section>'
}

$records = @(Get-RecordFiles | ForEach-Object { Read-JsonFile $_.path })
$active = @($records | Where-Object { $_.type -ceq 'subject' -and $_.status -ceq 'active' } | ForEach-Object { $_.id })
$titles = @{}
foreach ($subject in $records | Where-Object { $_.type -ceq 'subject' }) { $titles[$subject.id] = Format-Value $subject.title }

# --- The title --------------------------------------------------------------------------------
$cover = @(
    "<p class=`"kicker`">$(Html $words.kicker)</p>"
    "<h1 id=`"h-title`">$(Html $meeting)</h1>"
    "<p class=`"when`">$(Html $when)</p>"
    $(if ("$($notes.headline)".Trim()) { "<p class=`"headline`">$(Format-Note $notes.headline)</p>" })
    '<div class="stamp">'
    "<h3>$(Html $words.stamp)</h3>"
    @(Get-Stamp $labels | ForEach-Object { "<p>$(Html $_.Substring(2))</p>" })
    '</div>'
)
$slides = @(New-Slide 'title' '' $cover ' cover')

# --- The portfolio, ranked ----------------------------------------------------------------------
$ranked = Get-RankedSubjects
$given = { param($Value) if ($null -ne $Value) { Html $Value } else { Html $words.not_given } }
$rows = @(
    $rank = 0
    foreach ($subject in $ranked.scored | Select-Object -First 7) {
        $rank++
        $score = $subject.value_score * $subject.feasibility_score
        $banks = @($subject.banks | Where-Object { $_ } | ForEach-Object { "<span class=`"bank`">$(Html $_)</span>" }) -join ''
        $mark = Format-AiActMark $subject "<span class=`"mark`">$($icon.warn) $(Html $words.high_risk)</span>" (Html $words.not_high_risk) (Html $words.not_given)
        $changes = if ($subject.work_changes) { Html $labels.intake.work_changes.($subject.work_changes) } else { Html $words.not_given }
        '<tr>'
        "<td><span class=`"rank`">$rank</span></td>"
        "<td class=`"t`">$(Format-Cited $subject)$banks</td>"
        "<td><span class=`"score`">$(Html $score)<span class=`"gauge`" aria-hidden=`"true`"><i style=`"width: $([int]($score * 4))%`"></i></span></span></td>"
        "<td class=`"n`">$(Html $subject.value_score)</td><td class=`"n`">$(Html $subject.feasibility_score)</td><td class=`"n`">$(& $given $subject.risk_score)</td>"
        "<td>$mark</td><td>$changes</td>"
        '</tr>'
    }
)
$portfolio = @(
    Format-Key 'portfolio'
    '<div class="s-body">'
    if ($rows) {
        '<table class="tbl">'
        "<thead><tr><th>$(Html $words.rank)</th><th>$(Html $words.subject)</th><th>$(Html $words.score)</th><th class=`"n`">$(Html $words.value)</th><th class=`"n`">$(Html $words.feasibility)</th><th class=`"n`">$(Html $words.risk)</th><th>$(Html $words.ai_act)</th><th>$(Html $words.work_changes)</th></tr></thead>"
        '<tbody>'; $rows; '</tbody></table>'
    }
    else { "<p class=`"none`">$(Html $words.none)</p>" }
    if ($ranked.scored.Count -gt 7) { "<p class=`"note`">$(Html ($words.more -f ($ranked.scored.Count - 7)))</p>" }
    if ($ranked.others) { '<p class="note">' + (Html $words.not_scored).Replace('{0}', (@($ranked.others | ForEach-Object { Format-Cited $_ }) -join ', ')) + '</p>' }
    "<p class=`"note`">$(Html $words.portfolio_note)</p>"
    '</div>'
)
$slides += New-Slide 'portfolio' $words.portfolio $portfolio

# --- Value delivered against target -------------------------------------------------------------
$measure = { param($Benefit, $Value) Format-Measure $Benefit $Value $culture }
$benefits = @($records | Where-Object { $_.type -ceq 'benefit' -and 'open', 'achieved' -ccontains $_.status -and $active -ccontains $_.subject } | Sort-Object { $titles[$_.subject] }, id)
$rows = @(foreach ($benefit in $benefits | Select-Object -First 5) {
        $latest = if ($null -ne $benefit.current_value) { "<b>$(Html (& $measure $benefit $benefit.current_value))</b><span class=`"sub`">$(Html ($words.measured_on -f (Format-Day $benefit.measured_on)))</span>" } else { "<span class=`"sub`">$(Html $words.not_measured)</span>" }
        # How far the latest value stands from the baseline towards the target, as a bar only.
        $bar = if ($benefit.status -ceq 'achieved') { "<span class=`"done`">$($icon.check) $(Html $words.achieved)</span>" }
        elseif ($null -ne $benefit.current_value -and $null -ne $benefit.baseline -and $null -ne $benefit.target -and $benefit.target -ne $benefit.baseline) {
            $share = [Math]::Max([double]0, [Math]::Min([double]1, [double]($benefit.current_value - $benefit.baseline) / ($benefit.target - $benefit.baseline)))
            "<span class=`"track`" aria-hidden=`"true`"><i style=`"width: $([int]($share * 100))%`"></i></span>"
        }
        '<tr>'
        "<td class=`"t`">$(Format-Cited $benefit)<span class=`"sub one`">$(Html $titles[$benefit.subject]) &middot; $(Html $benefit.metric)</span></td>"
        "<td class=`"nw`">$(if ($null -ne $benefit.baseline) { Html (& $measure $benefit $benefit.baseline) } else { Html $words.not_given })</td>"
        "<td class=`"nw`">$latest</td>"
        "<td class=`"nw`">$(if ($null -ne $benefit.target) { Html (& $measure $benefit $benefit.target) } else { Html $words.not_given })</td>"
        "<td>$bar</td>"
        "<td>$(if ("$($benefit.owner)".Trim()) { Html $benefit.owner } else { Html $words.not_given })</td>"
        '</tr>'
    })
$value = @(
    Format-Key 'value'
    '<div class="s-body">'
    if ($rows) {
        '<table class="tbl fixed"><colgroup><col style="width: 34%"><col style="width: 11%"><col style="width: 14%"><col style="width: 11%"><col style="width: 13%"><col style="width: 17%"></colgroup>'
        "<thead><tr><th>$(Html $words.benefit)</th><th>$(Html $words.baseline)</th><th>$(Html $words.latest)</th><th>$(Html $words.target)</th><th></th><th>$(Html $words.measured_by)</th></tr></thead>"
        '<tbody>'; $rows; '</tbody></table>'
    }
    else { "<p class=`"none`">$(Html $words.none)</p>" }
    if ($benefits.Count -gt 5) { "<p class=`"note`">$(Html ($words.more -f ($benefits.Count - 5)))</p>" }
    '</div>'
)
$slides += New-Slide 'value' $words.value_heading $value

# --- Decisions ----------------------------------------------------------------------------------
$taken = @($records | Where-Object { $_.type -ceq 'decision' -and $_.status -ceq 'taken' -and $_.date_of_fact -ge $since -and $_.date_of_fact -le $date -and $active -ccontains $_.subject } | Sort-Object date_of_fact, id |
        ForEach-Object { @{ title = Format-Cited $_; meta = Html ($words.decided -f $(if ("$($_.decided_by)".Trim()) { Format-Value $_.decided_by } else { $words.not_given }), (Format-Day $_.date_of_fact)) } })
$pending = @($records | Where-Object { $_.type -ceq 'decision' -and $_.status -ceq 'pending' } | Sort-Object { if ($_.needed_by) { $_.needed_by } else { '9999' } }, id)
$awaited = {
    param($Decisions)
    foreach ($decision in $Decisions) {
        $meta = @(
            if ("$($decision.needed_from)".Trim()) { Html ($words.from -f (Format-Value $decision.needed_from)) }
            if ($decision.needed_by) { $by = Html ($words.by -f (Format-Day $decision.needed_by)); if ($decision.needed_by -lt $Today) { "<span class=`"late`">$($icon.alert) $(Html ($words.overdue -f ($words.by -f (Format-Day $decision.needed_by))))</span>" } else { $by } }
        ) -join ', '
        @{ title = Format-Cited $decision; meta = $meta }
    }
}
# A decision is awaited from the committee when who it is needed from names it: "committee" or a
# word of steering_words, as a whole word, whatever the case.
$committeeWords = '\b(?:' + ((@('committee') + @($Settings.steering_words | Where-Object { "$_".Trim() } | ForEach-Object { [regex]::Escape("$_".Trim()) })) -join '|') + ')\b'
$fromCommittee = @($pending | Where-Object { "$($_.needed_from)" -imatch $committeeWords })
$fromOthers = @($pending | Where-Object { "$($_.needed_from)" -inotmatch $committeeWords })
$decisions = @(
    Format-Key 'decisions'
    '<div class="s-body cols">'
    "<div><h3>$(Html ($words.taken -f (Format-Day $since)))</h3>"; Format-Items $taken 6; '</div>'
    "<div><h3>$(Html $words.awaited)</h3>"; Format-Items @(& $awaited $fromCommittee) 4
    if ($fromOthers) { "<h3>$(Html $words.awaited_others)</h3>"; Format-Items @(& $awaited $fromOthers) 2 }
    '</div>'
    '</div>'
)
$slides += New-Slide 'decisions' $words.decisions_heading $decisions

# --- Risks and commitments late -----------------------------------------------------------------
$risks = @(foreach ($urgent in $true, $false) {
        $records | Where-Object { $_.type -ceq 'risk' -and $_.status -ceq 'open' -and ($_.severity -ceq 'urgent') -eq $urgent } | ForEach-Object {
            @{ tag = "<span class=`"tag$(if ($urgent) { ' strong' })`">$(Html $words.($_.severity))</span>"; title = Format-Cited $_; meta = Html ((@($titles[$_.subject], $(if ("$($_.owner)".Trim()) { Format-Value $_.owner })) | Where-Object { $_ }) -join ' - ') }
        }
    })
$late = @($records | Where-Object { $_.type -ceq 'commitment' -and $_.status -ceq 'open' -and $_.due_date -and $_.due_date -lt $Today } | Sort-Object due_date, id | ForEach-Object {
        $owner = if ("$($_.owner)".Trim()) { (Html ($words.owner -f (Format-Value $_.owner))) + ', ' }
        @{ title = Format-Cited $_; meta = "$owner<span class=`"late`">$($icon.alert) $(Html ($words.late_by -f (Format-Day $_.due_date), (Get-DaysSince $_.due_date)))</span>" }
    })
$riskSlide = @(
    Format-Key 'risks'
    '<div class="s-body cols">'
    "<div><h3>$(Html $words.risks)</h3>"; Format-Items $risks 6; '</div>'
    "<div><h3>$(Html $words.late)</h3>"; Format-Items $late 6; '</div>'
    '</div>'
)
$slides += New-Slide 'risks' $words.risks_heading $riskSlide

# --- Next steps ---------------------------------------------------------------------------------
$steps = @($notes.next_steps | Where-Object { "$_".Trim() })
$next = @(
    '<div class="s-body">'
    if ($steps) {
        '<ol class="steps">'
        $n = 0
        foreach ($step in $steps) { $n++; "<li><span class=`"rank`">$n</span><span>$(Format-Note $step)</span></li>" }
        '</ol>'
    }
    else { "<p class=`"none`">$(Html $words.none)</p>" }
    '</div>'
)
$slides += New-Slide 'next' $words.next_heading $next

# --- The deck -----------------------------------------------------------------------------------
$name = 'templates\steering.html'
$template = Join-Path $Workspace $name
if (-not (Test-Path -LiteralPath $template)) { $name = "tools\$name"; $template = Join-Path $Workspace $name }
$page = [IO.File]::ReadAllText($template, $Utf8)
$lacking = @('{{language}}', '{{title}}', '{{slides}}' | Where-Object { -not $page.Contains($_) })
if ($lacking) { Stop-Run "The template $name lacks $($lacking -join ', '). Nothing was written. A deck template holds each of {{language}}, {{title}} and {{slides}}." }
# The deck holds no script and calls no network, whoever wrote its template.
if ($page -imatch '<script|(?:\b(?:src|href)\s*=\s*["'']?|url\(\s*["'']?)\s*https?:') { Stop-Run "The template $name holds a script or calls the network. Nothing was written. A deck template holds no <script> and no http:// or https:// address in a src, an href or a url(): the deck is read with no script and no network." }
# In one pass, so that a text of a record or of the calendar holding a place to fill is left as it is.
$values = @{ language = $Settings.languages.sponsor; title = (Html ($words.title -f $meeting, $when)); slides = ($slides -join [Environment]::NewLine).Replace('<!--slides-->', "$script:number") }
$page = [regex]::Replace($page, '\{\{(language|title|slides)\}\}', { param($Found) $values[$Found.Groups[1].Value] })
# A deck that verify would fail is never written: the morning page offers the pack until one is.
$problems = @(Test-View $page -Html)
if ($problems) { Stop-Run (@("Not verified: views\steering\$date.html. Nothing was written; correct what it names, then run steering again.") + @($problems | ForEach-Object { "- $_" })) }
$folder = Join-Path $Workspace 'views\steering'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
Write-TextFile (Join-Path $folder "$date.html") $page
"Steering pack written in '$($Settings.languages.sponsor)': views\steering\$date.html, for $meeting on $date, with the decisions taken since $since."
