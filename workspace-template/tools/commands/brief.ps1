# brief: prints the brief of a meeting of the calendar snapshot, for the agent to give in the chat.
# It writes nothing.
#
#   brief                    every meeting of today
#   brief 14:00              the meeting of today that starts at 14:00
#   brief 2026-03-04 14:00   the meeting of that day that starts at 14:00
#   brief 2026-03-03         every meeting of that day, as yesterday's for the briefing
#
# A brief is the one the morning page shows (Get-MeetingBrief): the subjects the meeting concerns,
# their open commitments, the decisions awaited and, from the agent's notes in state\morning.json,
# what matters and what each decision still lacks. Notes that cite a record missing or superseded
# are left out, and brief says why. A record is cited as a view cites it: Title [identifier].

$given = @($Arguments | Where-Object { $_ })
$dateOnly = $given.Count -eq 1 -and $given[0] -match '^\d{4}-'
$date = if ($given.Count -eq 2 -or $dateOnly) { $given[0] } else { $Today }
$time = if ($given -and -not $dateOnly) { $given[-1] }
if ($given.Count -gt 2 -or -not (Test-IsoDate $date) -or ($time -and $time -cnotmatch '^\d\d:\d\d$')) {
    Stop-Run 'brief takes the time a meeting starts, and its date when it is not today: brief 14:00, or brief 2026-03-04 14:00; or a date alone for every meeting of that day: brief 2026-03-04.'
}
$calendar = Read-CalendarSnapshot
if (-not $calendar) { Stop-Run 'The calendar is off or was never read: there is no calendar snapshot, state\calendar.json. The morning routine writes it.' }

$day = @(Get-DayMeetings $calendar $date)
$meetings = @($day | Where-Object { -not $time -or $_.start.Substring(11, 5) -eq $time })
if ($time -and -not $meetings) {
    $starts = @($day | ForEach-Object { $_.start.Substring(11, 5) }) -join ', '
    Stop-Run "No meeting of $date starts at $time in the calendar snapshot. $(if ($starts) { "Its meetings start at $starts." } else { 'It holds no meeting that day.' })"
}

$records = @(Get-RecordFiles | ForEach-Object { Read-JsonFile $_.path })
$notes = Read-MorningNotes
"Calendar read at $($calendar.read_at)."
foreach ($meeting in $meetings) {
    $brief = Get-MeetingBrief $meeting $records $notes.notes
    ''
    "$date $($meeting.start.Substring(11, 5))-$($meeting.end.Substring(11, 5)) $(Format-Value $meeting.title), $($meeting.status).$(if ($brief.banks) { " Client banks: $($brief.banks -join ', ')." })"
    if ($meeting.attendees) { "With: $(Format-Value $meeting.attendees)" }
    if ("$($brief.note.key)".Trim()) { "What matters: $(Format-Value $brief.note.key)" }
    "Subjects: $(if ($brief.subjects) { @($brief.subjects | ForEach-Object { "$(Format-Value $_.title) [$($_.id)]" }) -join ', ' } else { 'none of your subjects' })"
    if ($brief.commitments) {
        'Open commitments:'
        foreach ($commitment in $brief.commitments) {
            $said = @(
                if ("$($commitment.owed_to)".Trim()) { "$(Format-Value $commitment.owner) owes $(Format-Value $commitment.owed_to)" } else { Format-Value $commitment.owner }
                if ($commitment.due_date) { "due $($commitment.due_date)" }
            ) | Where-Object { "$_".Trim() }
            "- $(Format-Value $commitment.title) [$($commitment.id)]$(if ($said) { ': ' + ($said -join ', ') })"
        }
    }
    if ($brief.decisions) {
        'Decisions awaited:'
        foreach ($decision in $brief.decisions) {
            $said = @(
                if ("$($decision.needed_from)".Trim()) { "from $(Format-Value $decision.needed_from)" }
                if ($decision.needed_by) { "by $($decision.needed_by)" }
            ) -join ', '
            $lacks = "$($brief.note.lacks.($decision.id))".Trim()
            "- $(Format-Value $decision.title) [$($decision.id)]$(if ($said) { ': ' + $said }).$(if ($lacks) { ' Still lacks: ' + $lacks })"
        }
    }
}
if ($notes.problems) { @('', 'Not verified: state\morning.json. Its notes are left out; correct them, then ask again.') + @($notes.problems | ForEach-Object { "- $_" }) }
