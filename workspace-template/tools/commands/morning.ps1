# morning: writes the morning page, views\morning.html, from the register: one self-contained HTML
# file that the PO reads in a browser, replaced at each run.
#
#   morning       with the labels of the default language of settings.json
#   morning fr    with the labels of another language; what the records say is never translated
#
# The page opens on the stamp of a view, in a bar: the date, when the page was written, the
# register state, the sources the last collect read and those it did not, and the calendar. Its
# blocks follow, in this order:
#   meetings   Today's meetings, in the white sheet of the day: a timeline of the meetings of the
#              calendar snapshot, each with its duration, the agent's sentence on what matters and
#              its brief opening in place, then the free time for work within the PO's working
#              hours. A calendar off, or not read today, is a block that says it was not read.
#   start      Start soon, after the white sheet: the commitments of the PO whose latest start falls
#              within the lead, under named columns, then the workload of the next ten working
#              days in half-days, one sentence per week, a day that does not fit in red, and one
#              way out when one does not. The calendar not read, the workload says so.
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

function New-Line([string]$Date, [string]$Id, [string]$Title, [string]$Who, [string]$Subject, [string]$Button, [string]$Ask, [string]$Effort) {
    # One dated line of a block: its date, its title, who it concerns and its effort, its subject
    # and its identifier, and its button.
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
        html = New-Row $class $when $Title $Who "$(Html $Subject) &middot; $(Html $Id)" $Button $Ask $Effort
    }
}

function New-Row([string]$Class, [string]$When, [string]$Title, [string]$Who, [string]$Ref, [string]$Button, [string]$Ask, [string]$Effort) {
    # A line of a block, as HTML lines: one for the line, one per column.
    "<li class=`"row$Class`">"
    "<span class=`"when`">$When</span>"
    $who = -join @($Who, $Effort | Where-Object { $_ } | ForEach-Object { ' <span class="who">' + (Html $_) + '</span>' })
    "<span class=`"what`"><span class=`"t`">$(Html $Title)</span>$who</span>"
    "<span class=`"ref`">$Ref</span>"
    "<span class=`"act`"><button class=`"ask`" type=`"button`" data-ask=`"$(Html $Ask)`">$(Icon copy)<span class=`"lbl`">$(Html $Button)</span></button></span>"
    '</li>'
}

function Format-Lines($Lines, [int]$Short = $shortList) {
    # The lines of a list, the earliest date first: the late, today and this-week lines shown, the
    # others shown up to the short list, and the rest folded.
    $Lines = @($Lines | Sort-Object @{ Expression = { if ($_.date) { $_.date } else { '9999-99-99' } } }, @{ Expression = { $_.id } })
    $shown = [Math]::Max(@($Lines | Where-Object { 'late', 'today', 'week' -contains $_.dated }).Count, $Short)
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
# The calendar snapshot when it was read today: one of an earlier day says nothing of today.
$calendar = Read-CalendarSnapshot
if ($calendar -and -not "$($calendar.read_at)".StartsWith($Today)) { $calendar = $null }

function Get-Minutes([string]$Timestamp) {
    $moment = Read-Timestamp $Timestamp
    $moment.Hour * 60 + $moment.Minute
}

function Format-Minutes([int]$Minutes) { '{0:00}:{1:00}' -f [Math]::Floor($Minutes / 60), ($Minutes % 60) }

function Format-Duration([int]$Minutes) {
    $hours = [int][Math]::Floor($Minutes / 60)
    if (-not $hours) { "$Minutes min" } elseif ($Minutes % 60) { "$hours h $(($Minutes % 60).ToString('00'))" } else { "$hours h" }
}

function Get-FreeTime($Meetings) {
    # The stretches of the PO's working hours that no meeting takes, each as its start and end in
    # minutes. A tentative meeting takes its time as an accepted one does.
    # ponytail: settings written before the working hours have none, and read as the template's.
    $hours = if ($Settings.working_hours) { $Settings.working_hours } else { @([pscustomobject]@{ from = '09:00'; to = '18:00' }) }
    $busy = @($Meetings | ForEach-Object { @{ start = Get-Minutes $_.start; end = Get-Minutes $_.end } } | Sort-Object { $_.start })
    foreach ($range in $hours) {
        $at, $until = foreach ($time in $range.from, $range.to) { [int]$time.Substring(0, 2) * 60 + [int]$time.Substring(3, 2) }
        foreach ($meeting in $busy) {
            if ($meeting.start -gt $at -and $at -lt $until) { @{ start = $at; end = [Math]::Min($meeting.start, $until) } }
            $at = [Math]::Max($at, $meeting.end)
        }
        if ($at -lt $until) { @{ start = $at; end = $until } }
    }
}

function Get-MeetingsBlock {
    $said = $words.meetings
    if (-not $calendar) { return Format-Block 'meetings' $said.heading "<span class=`"late`">$(Icon alert) $(Html ($words.block_not_read -f 'calendar'))</span>" @() }
    $meetings = @(Get-DayMeetings $calendar $Today)
    $dayOff = @($calendar.absences | Where-Object { $_.date -eq $Today }).Count
    if (-not $meetings -and -not $dayOff) { return Format-Block 'meetings' $said.heading (Html $words.none) @() }
    $records = @(Get-RecordFiles | ForEach-Object { Read-JsonFile $_.path })
    $booked = 0
    $lines = foreach ($meeting in $meetings) {
        $brief = Get-MeetingBrief $meeting $records $notes.notes
        $time = Format-Minutes (Get-Minutes $meeting.start)
        $length = (Get-Minutes $meeting.end) - (Get-Minutes $meeting.start)
        $booked += $length
        $banks = @($brief.banks | ForEach-Object { " <span class=`"bank`">$(Html $_)</span>" }) -join ''
        $duration = (Format-Duration $length) + $(if ($meeting.status -ceq 'tentative') { ", $($said.tentative)" })
        "<li class=`"mtg$(if ($meeting.status -ceq 'tentative') { ' is-tentative' })`">"
        '<details>'
        '<summary>'
        "<span class=`"t`">$time</span>"
        "<span class=`"opener`">$(Icon chev 'i chev')</span>"
        '<span class="m">'
        "<span class=`"m-title`">$(Html $meeting.title)$banks <span class=`"dur`">$(Html $duration)</span></span>"
        if ("$($brief.note.key)".Trim()) { "<span class=`"m-key`">$(Html $brief.note.key)</span>" }
        '</span>'
        '</summary>'
        '<dl class="brief">'
        if ($meeting.attendees) { "<dt>$(Html $said.with)</dt><dd>$(Html $meeting.attendees)</dd>" }
        $subjects = if ($brief.subjects) { @($brief.subjects | ForEach-Object { "$(Html $_.title) <span class=`"id`">$(Html $_.id)</span>" }) -join ', ' } else { Html $said.no_subject }
        "<dt>$(Html $said.subjects)</dt><dd>$subjects</dd>"
        if ($brief.commitments) {
            "<dt>$(Html $said.commitments)</dt><dd><ul>"
            foreach ($commitment in $brief.commitments) {
                $who = if ("$($commitment.owed_to)".Trim()) { $said.owes -f (Format-Value $commitment.owner), (Format-Value $commitment.owed_to) } else { Format-Value $commitment.owner }
                $due = if ($commitment.due_date) {
                    $text = Html ($said.due -f (Format-Day $commitment.due_date))
                    if ($commitment.due_date -lt $Today) {
                        $days = Get-DaysSince $commitment.due_date
                        ", <span class=`"late`">$(Icon alert) $text, $(Html $(if ($days -eq 1) { $words.late_one } else { $words.late_many -f $days }))</span>"
                    }
                    else { ", $text" }
                }
                "<li>$(Html $commitment.title) <span class=`"who`">$(Html $who)$due</span> <span class=`"id`">$(Html $commitment.id)</span></li>"
            }
            '</ul></dd>'
        }
        if ($brief.decisions) {
            "<dt>$(Html $said.decisions)</dt><dd><ul>"
            foreach ($decision in $brief.decisions) {
                $who = @(
                    if ("$($decision.needed_from)".Trim()) { $said.from -f (Format-Value $decision.needed_from) }
                    if ($decision.needed_by) { $said.by -f (Format-Day $decision.needed_by) }
                ) -join ', '
                $lacks = "$($brief.note.lacks.($decision.id))".Trim()
                if ($lacks) { $lacks = ' <span class="missing">' + (Html ($said.lacks -f $lacks)) + '</span>' }
                "<li>$(Html $decision.title) <span class=`"who`">$(Html $who)</span> <span class=`"id`">$(Html $decision.id)</span>$lacks</li>"
            }
            '</ul></dd>'
        }
        '</dl>'
        '</details>'
        "<button class=`"ask`" type=`"button`" data-ask=`"$(Html ($said.ask -f $time, (Format-Value $meeting.title)))`">$(Icon copy)<span class=`"lbl`">$(Html $said.button)</span></button>"
        '</li>'
    }
    $free = @(Get-FreeTime $meetings)
    $longest = ($free | Sort-Object { $_.start - $_.end } | Select-Object -First 1)
    $stretches = @($free | ForEach-Object { "$(Format-Minutes $_.start)&ndash;$(Format-Minutes $_.end)$(if ($free.Count -gt 1 -and $_ -eq $longest) { ', ' + (Html $said.longest) })" }) -join ' &middot; '
    $count = if ($meetings) { Html ($said.count -f $meetings.Count, (Format-Duration $booked)) } else { Html $words.none }
    $body = @(
        if ($lines) { '<ol class="tt">'; $lines; '</ol>' }
        if ($notes.problems) { "<p class=`"refused late`">$(Icon alert) $(Html ($said.refused -f ($notes.problems -join ' ')))</p>" }
        "<p class=`"free`"><b>$(Html $said.free)</b> $(if ($dayOff) { Html $said.day_off } elseif ($stretches) { $stretches } else { Html $said.no_free })</p>"
    )
    Format-Block 'meetings' $said.heading $count $body
}

function Get-FreeDays([string]$Date) {
    # The free time of a day for work, in days of the PO's working hours: the working hours less
    # its accepted meetings and half its tentative ones, and none on a day of absence.
    if (@($calendar.absences | Where-Object { $_.date -eq $Date }).Count) { return 0.0 }
    $meetings = @(Get-DayMeetings $calendar $Date)
    $sum = { param($Stretches) [double](@($Stretches | ForEach-Object { $_.end - $_.start }) | Measure-Object -Sum).Sum }
    $all = & $sum @(Get-FreeTime $meetings)
    $accepted = & $sum @(Get-FreeTime @($meetings | Where-Object { $_.status -cne 'tentative' }))
    ($all + $accepted) / 2 / (& $sum @(Get-FreeTime @()))
}

function Get-UsableShare {
    # The share of free time really usable for tasks: 70% to start with, then learned once the PO's
    # own done tasks span ten working days of free time kept in state\free-time.json: the real
    # effort they took over the free time of the working days they spanned, from their start to
    # the day they were done. A task that spans a day whose free time was not kept is left out.
    $kept = @{}
    $path = Join-Path $Workspace 'state\free-time.json'
    if (Test-Path -LiteralPath $path) { foreach ($entry in (Read-JsonFile $path).PSObject.Properties) { $kept[$entry.Name] = [double]$entry.Value } }
    $spanned = @{}
    $real = 0.0
    foreach ($commitment in @(Get-RecordFiles | Where-Object { $_.type -eq 'commitment' } | ForEach-Object { Read-JsonFile $_.path } |
                Where-Object { $_.status -ceq 'done' -and (Test-IsPo $_.owner) -and $_.started_on -and $_.real_effort -gt 0 })) {
        $done = @($commitment.history | Where-Object { $_.field -eq 'status' -and $_.new -ceq 'done' } | ForEach-Object { $_.date }) | Select-Object -Last 1
        if (-not $done) { continue }
        $span = @(for ($at = [DateTime]::ParseExact($commitment.started_on, 'yyyy-MM-dd', $invariant); $at.ToString('yyyy-MM-dd', $invariant) -le $done; $at = $at.AddDays(1)) {
                if ('Saturday', 'Sunday' -notcontains $at.DayOfWeek) { $at.ToString('yyyy-MM-dd', $invariant) }
            })
        if (@($span | Where-Object { -not $kept.ContainsKey($_) }).Count) { continue }
        $real += $commitment.real_effort
        foreach ($date in $span) { $spanned[$date] = $true }
    }
    $free = [double](@($spanned.Keys | ForEach-Object { $kept[$_] }) | Measure-Object -Sum).Sum
    if ($spanned.Count -lt 10 -or $free -le 0) { return @{ share = 0.7; learned = $false } }
    @{ share = [Math]::Min([double]1, [Math]::Max([double]0.1, [Math]::Round($real / $free, 2, [MidpointRounding]::AwayFromZero))); learned = $true }
}

function Save-FreeTime([double]$Days) {
    # Keeps the free time of today, before the usable share, in state\free-time.json.
    $path = Join-Path $Workspace 'state\free-time.json'
    $kept = [ordered]@{}
    if (Test-Path -LiteralPath $path) { foreach ($entry in (Read-JsonFile $path).PSObject.Properties) { $kept[$entry.Name] = $entry.Value } }
    $kept[$Today] = [Math]::Round($Days, 2, [MidpointRounding]::AwayFromZero)
    $sorted = [ordered]@{}
    foreach ($date in @($kept.Keys | Sort-Object)) { $sorted[$date] = $kept[$date] }
    Write-JsonFile $path $sorted
}

function Get-Plan($Tasks, [string[]]$Days, [hashtable]$Room) {
    # The work planned on each day and the work that does not fit, in days. Day after day, the
    # usable free time goes to the tasks begun, the earliest due first. What a task still needs
    # after its last day does not fit, on that day. A task is a commitment of the PO as the plan
    # sees it: its identifier, due date, effort, first and last day.
    $plan = @{ work = @{}; over = @{}; late = @() }
    $left = @{}
    foreach ($task in $Tasks) { $left[$task.id] = [double]$task.effort }
    foreach ($date in $Days) {
        $free = $Room[$date]
        $plan.work[$date] = 0.0
        $plan.over[$date] = 0.0
        foreach ($task in @($Tasks | Where-Object { $_.start -le $date -and $left[$_.id] -gt 0 } | Sort-Object { $_.due }, { $_.id })) {
            $done = [Math]::Min($free, $left[$task.id])
            $free -= $done
            $left[$task.id] -= $done
            $plan.work[$date] += $done
        }
        foreach ($task in @($Tasks | Where-Object { $_.last -eq $date -and $left[$_.id] -gt 1e-9 })) {
            $plan.over[$date] += $left[$task.id]
            $plan.late += @{ id = $task.id; day = $date }
            $left[$task.id] = 0
        }
    }
    $plan
}

function Get-WayOut($Tasks, [string[]]$Days, [hashtable]$Room, $Plan) {
    # One way out of the first day that does not fit, tried in this order: begin today a task that
    # waits for its latest start, drop or hand over a task marked optional, or move the due date of
    # the task that does not fit to the first working day that lets it fit. A way out holds when
    # no work is left over up to that day and the task that did not fit fits. Nothing when none holds.
    $first = @($Plan.late | Sort-Object { $_.day }, { $_.id })[0]
    $stuck = @($Tasks | Where-Object { $_.id -eq $first.id })[0]
    $holds = { param($Changed) -not @((Get-Plan $Changed $Days $Room).late | Where-Object { $_.day -le $first.day -or $_.id -eq $stuck.id }).Count }
    $with = { param($Task, [hashtable]$Fields) @($Tasks | ForEach-Object { if ($_.id -eq $Task.id) { $copy = $_.Clone(); foreach ($name in $Fields.Keys) { $copy[$name] = $Fields[$name] }; $copy } else { $_ } }) }
    foreach ($task in @($Tasks | Where-Object { $_.start -gt $Days[0] } | Sort-Object { $_.due }, { $_.id })) {
        if (& $holds (& $with $task @{ start = $Days[0] })) { return @{ kind = 'earlier'; task = $task; day = $first.day } }
    }
    foreach ($task in @($Tasks | Where-Object { $_.record.optional -eq $true } | Sort-Object { $_.due }, { $_.id })) {
        if (& $holds @($Tasks | Where-Object { $_.id -ne $task.id })) { return @{ kind = 'optional'; task = $task; day = $first.day } }
    }
    for ($later = 1; $later -le 10; $later++) {
        $due = Add-WorkingDays $stuck.due $later
        $last = @($Days[0], (Add-WorkingDays $due -1)) | Sort-Object | Select-Object -Last 1
        if (& $holds (& $with $stuck @{ due = $due; last = $last })) { return @{ kind = 'move'; task = $stuck; day = $first.day; due = $due } }
    }
}

function Format-WayOut($Way) {
    # The suggestion of the page, with its button, and the same sentence for morning to print.
    if (-not $Way) { return }
    $said = $words.start
    $record = $Way.task.record
    $title = Format-Value $record.title
    $owner = "$(Format-Value $record.owed_to)".Trim()
    $fits = Format-Day $Way.day
    # The words of the sentence, $null where it names the task, and its button.
    switch ($Way.kind) {
        'earlier' { $sentence = $said.earlier; $parts = $null, (Format-Day $Way.task.start), $fits; $button = $said.earlier_button; $ask = $said.ask_earlier -f $record.id, $title }
        'optional' { $sentence = $said.optional; $parts = $null, $fits; $button = $said.optional_button; $ask = $said.ask_optional -f $record.id, $title }
        'move' {
            $due = Format-Day $Way.due
            $button = $said.move_button
            if ($owner) { $sentence = $said.move; $parts = $owner, $null, $due, $fits; $ask = $said.ask_move -f $owner, $record.id, $due }
            else { $sentence = $said.move_own; $parts = $null, $due, $fits; $ask = $said.ask_move_own -f $record.id, $due }
        }
    }
    # What a record says fills the sentence, and is never read as a place to fill.
    $script:WayOut = "$($said.suggestion) " + [string]::Format($sentence, [object[]]@($parts | ForEach-Object { if ($null -eq $_) { "$title [$($record.id)]" } else { $_ } }))
    $html = [string]::Format((Html $sentence), [object[]]@($parts | ForEach-Object { if ($null -eq $_) { (Html $title) + ' <span class="id">' + (Html $record.id) + '</span>' } else { Html $_ } }))
    '<div class="suggest">'
    "<p><b>$(Html $said.suggestion)</b> $html</p>"
    "<span class=`"btns`"><button class=`"ask`" type=`"button`" data-ask=`"$(Html $ask)`">$(Icon copy)<span class=`"lbl`">$(Html $button)</span></button></span>"
    '</div>'
}

function Format-HalfDays([double]$Days) {
    # An amount of days rounded to the half-day, in words.
    $said = $words.start
    $half = [Math]::Round($Days * 2, [MidpointRounding]::AwayFromZero) / 2
    if ($half -eq 0) { $said.nothing } elseif ($half -eq 0.5) { $said.half_day } elseif ($half -eq 1) { $said.one_day } else { $said.many_days -f $half.ToString('0.#', $culture) }
}

function Get-Workload($Days, [hashtable]$Room, $Plan, $Share) {
    # The workload view: the ten days by week, one sentence each, one square per half-day of usable
    # free time.
    $said = $words.start
    $count = { param($Days) [int][Math]::Round($Days * 2, [MidpointRounding]::AwayFromZero) }
    $monday = { param($Date) $at = [DateTime]::ParseExact($Date, 'yyyy-MM-dd', $invariant); $at.AddDays(-(([int]$at.DayOfWeek + 6) % 7)) }
    $thisMonday = & $monday $Today
    '<div class="load" role="group" aria-labelledby="h-load">'
    "<h3 id=`"h-load`">$(Html $said.workload) <span class=`"note`">$(Html ($said.note -f $Share.share.ToString('P0', $culture), $(if ($Share.learned) { $said.share_learned } else { $said.share_start })))</span></h3>"
    '<div class="weeks">'
    foreach ($week in $Days | Group-Object { (& $monday $_).ToString('yyyy-MM-dd', $invariant) }) {
        $weeks = [int](([DateTime](& $monday $week.Group[0]) - [DateTime]$thisMonday).Days / 7)
        $label = if ($weeks -eq 0) { $said.this_week } elseif ($weeks -eq 1) { $said.next_week } else { $said.week_of -f (Format-Day $week.Name) }
        $free = [double]($week.Group | ForEach-Object { $Room[$_] } | Measure-Object -Sum).Sum
        $work = [double]($week.Group | ForEach-Object { $Plan.work[$_] } | Measure-Object -Sum).Sum
        $over = [double]($week.Group | ForEach-Object { $Plan.over[$_] } | Measure-Object -Sum).Sum
        $sentence = [string]::Format((Html $said.week), "<b>$(Html $label)</b>", (Html $(if ($work + $over -gt 0) { $said.work -f (Format-HalfDays ($work + $over)) } else { $said.no_work })), (Html (Format-HalfDays $free)))
        $fits = if ((& $count $over) -le 2) { $said.over_one } else { $said.over_many }
        if ($over -gt 0) { $sentence += " <span class=`"late`">$(Icon alert) $(Html ($fits -f (Format-HalfDays $over)))</span>" }
        elseif (& $count ($free - $work)) { $sentence += ' ' + (Html ($said.open -f (Format-HalfDays ($free - $work)))) }
        '<div>'
        "<p class=`"week-cap`">$sentence</p>"
        '<ol class="days">'
        foreach ($date in $week.Group) {
            $squares = & $count $Room[$date]
            $planned = [Math]::Min($squares, (& $count $Plan.work[$date]))
            $beyond = if ($Plan.over[$date] -gt 0) { [Math]::Max(1, (& $count $Plan.over[$date])) } else { 0 }
            $class = @(if ($date -eq $Today) { 'is-today' }; if ($beyond) { 'over' }) -join ' '
            $cell = if (@($calendar.absences | Where-Object { $_.date -eq $date }).Count -and -not $beyond) { "<span class=`"sq`"><span class=`"none`">$(Html $said.day_off)</span></span>" }
            elseif (-not $squares -and -not $beyond) { "<span class=`"sq`"><span class=`"none`">$(Html $said.no_free)</span></span>" }
            else {
                $marks = @(@('p') * $planned) + @(@('o') * ($squares - $planned)) + @(@('x') * $beyond) | ForEach-Object { "<i class=`"$_`"></i>" }
                "<span class=`"sq`" aria-hidden=`"true`">$($marks -join '')</span><span class=`"sr`">$(Html ($said.sr_day -f $squares, $planned))$(if ($beyond) { Html ($said.sr_over -f $beyond) })</span>"
            }
            $values = foreach ($name in 'free', 'work', 'over') { " data-$name=`"$((@{ free = $Room[$date]; work = $Plan.work[$date]; over = $Plan.over[$date] }[$name]).ToString('0.00', $invariant))`"" }
            $name = if ($date -eq $Today) { $words.today } else { Format-Day $date }
            $mark = if ($beyond) { '<span class="late">' + (Icon alert) + ' ' + (Html $said.does_not_fit) + '</span>' }
            $class = if ($class) { ' class="' + $class + '"' }
            "<li$class data-day=`"$date`"$(-join $values)><span class=`"d`">$(Html $name)</span>$mark$cell</li>"
        }
        '</ol>'
        '</div>'
    }
    '</div>'
    "<p class=`"legend`" aria-hidden=`"true`"><span><i class=`"p`"></i>$(Html $said.legend_planned)</span><span><i class=`"o`"></i>$(Html $said.legend_open)</span><span><i class=`"x`"></i>$(Html $said.legend_over)</span></p>"
    '</div>'
}

function Get-StartBlock {
    $said = $words.start
    $lead = Add-WorkingDays $Today (Get-StartSoon).lead
    $number = { param($Value) ([decimal]$Value).ToString('0.##', $culture) }
    $lines = @(foreach ($commitment in $commitments | Where-Object { Test-IsPo $_.owner }) {
            $start = Get-LatestStart $commitment
            if (-not $start -or $start -gt $lead) { continue }
            $dated = if ($start -lt $Today) { 'late' } elseif ($start -eq $Today) { 'today' } else { 'later' }
            $when = switch ($dated) {
                'late' {
                    $days = Get-DaysSince $start
                    "$(Icon alert)<span class=`"sr k`">$(Html $said.start_by) </span><b>$(Html (Format-Day $start))</b> <span class=`"lag`">$(Html $(if ($days -eq 1) { $words.late_one } else { $words.late_many -f $days }))</span>"
                }
                'today' { "$(Icon clock)<span class=`"sr k`">$(Html $said.start_by) </span><b>$(Html $words.today)</b>" }
                default { "<span class=`"sr k`">$(Html $said.start_by) </span><b>$(Html (Format-Day $start))</b>" }
            }
            $started = "$($commitment.started_on)".Trim()
            $button, $ask = if ($started) { $said.where, $said.ask_where } else { $said.need, $said.ask_need }
            @{
                date = $start; id = $commitment.id; dated = $dated
                html = @(
                    "<li class=`"row start$(@{ late = ' is-late'; today = ' is-soon' }[$dated])`">"
                    "<span class=`"when`">$when</span>"
                    "<span class=`"what`"><span class=`"t`">$(Html $commitment.title)</span> <span class=`"ref`">$(Html $commitment.id)</span></span>"
                    "<span class=`"eff`"><span class=`"sr k`">$(Html $said.effort) </span><b>$(Html ($said.days -f (& $number (Get-AdjustedEffort $commitment).adjusted)))</b> <span class=`"adj`">$(Html (Format-Effort $commitment $labels.effort $culture))</span></span>"
                    "<span class=`"due`"><span class=`"sr k`">$(Html $said.due) </span>$(Html (Format-Day $commitment.due_date))</span>"
                    "<span class=`"status`"><span class=`"dot$(if ($started) { ' on' })`" aria-hidden=`"true`"></span>$(Html $(if ($started) { $said.started } else { $said.not_started }))</span>"
                    "<span class=`"act`"><button class=`"ask`" type=`"button`" data-ask=`"$(Html ($ask -f $commitment.id, (Format-Value $commitment.title)))`">$(Icon copy)<span class=`"lbl`">$(Html $button)</span></button></span>"
                    '</li>'
                )
            }
        })
    $counts = @(
        foreach ($kind in @(@('late', 'count_late', 'late'), @('today', 'count_today', 'soon'), @('later', 'count_more', ''))) {
            $count = @($lines | Where-Object { $_.dated -eq $kind[0] }).Count
            if ($count) { $(if ($kind[2]) { "<span class=`"$($kind[2])`">$(Html ($said.($kind[1]) -f $count))</span>" } else { Html ($said.($kind[1]) -f $count) }) }
        }
    )
    # The workload of the next ten working days, from the calendar snapshot of today: every open
    # commitment of the PO with an estimate and a due date, begun when it is started or its latest
    # start has come, on its latest start otherwise.
    if ($calendar) {
        $days = @()
        for ($at = $day; $days.Count -lt 10; $at = $at.AddDays(1)) { if ('Saturday', 'Sunday' -notcontains $at.DayOfWeek) { $days += $at.ToString('yyyy-MM-dd', $invariant) } }
        $share = Get-UsableShare
        $room = @{}
        foreach ($date in $days) { $room[$date] = (Get-FreeDays $date) * $share.share }
        if ($days[0] -eq $Today) { Save-FreeTime (Get-FreeDays $Today) }
        $tasks = @(foreach ($commitment in $commitments | Where-Object { Test-IsPo $_.owner }) {
                $start = Get-LatestStart $commitment
                if (-not $start) { continue }
                @{
                    id = $commitment.id; due = $commitment.due_date; effort = (Get-AdjustedEffort $commitment).adjusted; record = $commitment
                    start = $(if ("$($commitment.started_on)".Trim() -or $start -lt $days[0]) { $days[0] } else { $start })
                    last = $(@($days[0], (Add-WorkingDays $commitment.due_date -1)) | Sort-Object | Select-Object -Last 1)
                }
            })
        $plan = Get-Plan $tasks $days $room
        $planned = ($days | Where-Object { $plan.work[$_] -gt 0 -or $plan.over[$_] -gt 0 })
        $overDays = @($days | Where-Object { $plan.over[$_] -gt 0 })
        if ($overDays) { $counts += "<span class=`"late`">$(Icon alert) $(Html ($said.count_over -f (@($overDays | ForEach-Object { Format-Day $_ }) -join ', ')))</span>" }
    }
    # The earliest starts first: four lines shown on a day of up to five meetings, three beyond, and
    # never a start of today or past folded.
    $short = if ($calendar -and @(Get-DayMeetings $calendar $Today).Count -gt 5) { 3 } else { 4 }
    $body = @(
        if ($lines) {
            "<div class=`"cols start`" aria-hidden=`"true`"><span>$(Html $said.start_by)</span><span>$(Html $said.task)</span><span>$(Html $said.effort)<span class=`"adj-h`">$(Html $said.adjusted_from)</span></span><span>$(Html $said.due)</span><span>$(Html $said.status)</span><span></span></div>"
            Format-Lines $lines $short
        }
        if (-not $calendar) { "<p class=`"free`"><b>$(Html $said.workload_short)</b> <span class=`"late`">$(Icon alert) $(Html ($words.block_not_read -f 'calendar'))</span></p>" }
        elseif ($lines -or $planned) { Get-Workload $days $room $plan $share }
        if ($overDays) { Format-WayOut (Get-WayOut $tasks $days $room $plan) }
    )
    Format-Block 'start' $said.heading (Format-Count $counts @()) $body
}

function Get-OweBlock {
    $owe = $words.owe
    $lines = @(foreach ($commitment in $commitments | Where-Object { Test-IsPo $_.owner }) {
            $to = if ("$($commitment.owed_to)".Trim()) { $owe.to -f (Format-Value $commitment.owed_to) }
            New-Line $commitment.due_date $commitment.id $commitment.title $to $commitment.subject $owe.button ($owe.ask -f $commitment.id, (Format-Value $commitment.title)) (Format-Effort $commitment $labels.effort $culture)
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
        if ($calendar) { "<span class=`"src`">$(Icon check)$(Html ($words.calendar_read -f (Format-Moment $calendar.read_at)))</span>" }
        elseif ($Connections.calendar -and $Connections.calendar.mode -cne 'off') { "<span class=`"src fail`">$(Icon alert)$(Html ($words.not_read -f 'calendar'))</span>" }
        $off = @($Connections.PSObject.Properties | Where-Object { $_.Value.mode -ceq 'off' } | ForEach-Object { $_.Name })
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

$notes = Read-MeetingNotes
# The white sheet holds the day: the blocks of today side by side, then the ruled blocks below.
$blocks = @('<div class="sheet">') + @(Get-MeetingsBlock) + @('</div>') + @(Get-StartBlock) + @(Get-OweBlock) + @(Get-OwedBlock) + @(Get-DecisionsBlock) + @(Get-SortBlock)
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
if ($script:WayOut) { $script:WayOut }
if ($notes.problems) { @('Not verified: state\morning.json. The notes on the meetings are left off the page; correct them, then run morning again.') + @($notes.problems | ForEach-Object { "- $_" }) }
