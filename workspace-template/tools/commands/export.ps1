# export: prints the digest of the register that the weekly synthesis is written from. It writes
# nothing.
#
#   export 2026-03-03    the register as it is, and what changed since that date, included
#
# The same register state, the same date and the same moment given as -Now print the same export.
#
# What it prints, in this order:
#   # Export of the register since <date>
#   ## Stamp                  the stamp of the view to write from this export, ready to copy
#   ## Active subjects        with horizon and clearance
#   ## Changes since <date>   each record recorded since, each field corrected since
#   ## Open commitments       with owner and due date
#   ## Pending decisions      under one "### Awaited from: <person>" per person awaited
#   ## Open risks             with severity, the urgent ones first
#   ## Coverage per source    one line per source of connections.json, with the cap when the last
#                             collect that read the source stopped there
#   ## Records per objective  one line per objective of settings.json
#   ## Portfolio view         the portfolio view as view writes it under its stamp, ready to copy:
#                             from its first horizon to the last line of the export
# A section that holds nothing says "None."
#
# A record is one line: its title, its identifier in brackets as a view cites it, its type, its
# evidence level, then what it says. A value the synthesis must state and the record does not give
# is written "missing". Only the stamp and the portfolio view are in the language of the sponsor,
# languages.sponsor of settings.json: the rest is read by the agent, as the preview is.

function Get-OrMissing($Value) {
    # A value on one line, or the word that says the record does not give it.
    $text = (Format-Value $Value).Trim()
    if ($text) { $text } else { 'missing' }
}

function Format-Record($Record, [string[]]$More = @()) {
    # One record as a line of the export, followed by anything more to say of it.
    $says = @(
        if ($Record.type -ceq 'subject') {
            "horizon: $($Record.horizon)"
            "clearance: $(Format-Clearance $Record $Record.clearance 'by {0}' 'on {0}')"
        }
        else { "subject: $($Record.subject)$(if ($closed -ccontains $Record.subject) { ' (closed)' })"; "date of fact: $($Record.date_of_fact)"; "status: $($Record.status)" }
        if ($Record.type -ceq 'commitment') { "owner: $(Get-OrMissing $Record.owner)"; "due date: $(Get-OrMissing $Record.due_date)" }
        if ($Record.type -ceq 'decision') {
            if ($Record.status -ceq 'pending') { "needed from: $(Get-OrMissing $Record.needed_from)"; "needed by: $(Get-OrMissing $Record.needed_by)" }
            else { "decided by: $(Get-OrMissing $Record.decided_by)" }
        }
        if ($Record.type -ceq 'risk') { "severity: $($Record.severity)"; if ($Record.owner) { "owner: $(Format-Value $Record.owner)" } }
    )
    '- ' + ((@("$(Format-Value $Record.title) [$($Record.id)]", $Record.type, $Record.evidence_level) + $says + $More) -join ' | ')
}

function Write-Section([string]$Heading, [string[]]$Lines) {
    '', "## $Heading", ''
    if ($Lines) { $Lines } else { 'None.' }
}

# The stamp of the export names a committed register.
Assert-RegisterCommitted
$since = "$($Arguments | Select-Object -First 1)"
if (-not (Test-IsoDate $since)) {
    Stop-Run "export takes the date its period starts on, as an ISO date (yyyy-mm-dd)$(if ($since) { ", not '$since'" }): export 2026-03-03"
}
$labels = Get-Labels $Settings.languages.sponsor

# Every record of the register, type after type, in the order of the identifiers.
$all = @(Get-RecordFiles | ForEach-Object { Read-JsonFile $_.path })

# What the export leaves out, so that an abandoned plan cannot resurface: a record that is
# superseded or closed, and a record attached to a closed subject unless it is still open. An open
# commitment, a pending decision or an open risk is listed whatever the state of its subject,
# because someone still owes something, as the check keeps its warnings on it: its line says that
# its subject is closed. The identifier of a record left out is cited nowhere: no line says which
# record another supersedes.
$closed = @($all | Where-Object { $_.type -ceq 'subject' -and $_.status -ceq 'closed' } | ForEach-Object { $_.id })
$records = @($all | Where-Object { 'superseded', 'closed' -cnotcontains $_.status -and ($closed -cnotcontains $_.subject -or 'open', 'pending' -ccontains $_.status) })

"# Export of the register since $since"
''
'Each record is one line: Title [identifier] | type | evidence level | what it says. The records that are superseded or closed are left out, and so are those of a closed subject unless they are still open: an open commitment, a pending decision or an open risk of a closed subject is listed, and its line says "(closed)" after its subject.'
Write-Section 'Stamp' (Get-Stamp $labels)
Write-Section 'Active subjects' @($records | Where-Object { $_.type -ceq 'subject' } | ForEach-Object { Format-Record $_ })

Write-Section "Changes since $since" @(foreach ($record in $records) {
        $changes = @(
            if ($record.date_recorded -ge $since) { "recorded $($record.date_recorded)" }
            foreach ($entry in $record.history | Where-Object { $_.date -ge $since }) {
                # A next date that is not confirmed is not shown, as in the portfolio view: the
                # synthesis never promises it.
                if ($entry.field -ceq 'next_date' -and -not $record.next_date_confirmed) { continue }
                # A change of subject is named without its values: the subject left may be closed
                # since, and the line already says the subject of the record.
                "changed $($entry.date): $(if ($entry.field -ceq 'subject') { 'subject' } else { Format-Change $entry })"
            }
        )
        if ($changes) { Format-Record $record $changes }
    })

Write-Section 'Open commitments' @($records | Where-Object { $_.type -ceq 'commitment' -and $_.status -ceq 'open' } | ForEach-Object { Format-Record $_ })

# One group per person awaited, whatever the case of the name, in the order of the names.
$awaited = New-Object 'System.Collections.Generic.SortedDictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($decision in $records | Where-Object { $_.type -ceq 'decision' -and $_.status -ceq 'pending' }) {
    $from = Get-OrMissing $decision.needed_from
    if (-not $awaited.ContainsKey($from)) { $awaited[$from] = @() }
    $awaited[$from] += Format-Record $decision
}
Write-Section 'Pending decisions' @($awaited.GetEnumerator() | ForEach-Object { "### Awaited from: $($_.Key)"; $_.Value })

$risks = @($records | Where-Object { $_.type -ceq 'risk' -and $_.status -ceq 'open' })
Write-Section 'Open risks' @(foreach ($urgent in $true, $false) { $risks | Where-Object { ($_.severity -ceq 'urgent') -eq $urgent } | ForEach-Object { Format-Record $_ } })

# "covered" is whether the last collect read the source, as the stamp counts it.
Write-Section 'Coverage per source' @(Get-Coverage | ForEach-Object {
        $read = if ($_.read) { "read up to $($_.read.cutoff) by the collect of $($_.read.collected_at): $($_.read.items) item(s)$(Format-CapReached $_.read)" } else { 'never read' }
        "- $($_.source) | mode: $($_.mode) | covered: $(if ($_.covered) { 'yes' } else { 'no' }) | $read"
    })

Write-Section 'Records per objective' @($Settings.objectives | Where-Object { $_ } | ForEach-Object {
        $number = $_.number
        "- Objective $number, $(Format-Value $_.title): $(@($records | Where-Object { $_.objectives -contains $number }).Count) record(s)"
    })

'', '## Portfolio view'
Get-PortfolioHorizons $labels
