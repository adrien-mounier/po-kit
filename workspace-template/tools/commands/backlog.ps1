# backlog: checks, shows and applies the changes to the tracker the agent proposes, kept in
# state\backlog-changes.json, the change proposal, apart from the proposal of the register.
#
#   backlog check          validates the change proposal and lists its changes
#   backlog show <id>      one change as the exact text before and after, for the PO to review
#   backlog apply <id>     applies one approved change, once (see Invoke-Apply below)
#   backlog alerts         checks the backlog alerts, state\backlog-alerts.json, and names the
#                          refinement sessions near
#   backlog order          writes the order the agent proposes for the top of the backlog as a view
#   backlog template [fr]  the ticket template a ticket draft is written from (see below)
#
# The one exception to "the agent modifies nothing in a source": a change creates a ticket or
# edits one of its texts (title, description, acceptance criteria), nothing else. A change that
# would delete, close, reopen or move a ticket, or touch any other field, refuses the proposal whole.
#   { "changes": [ { "id": "1", "kind": "edit", "ticket": "ONB-142", "field": "title",
#                    "before": "...", "after": "...", "reason": "...",
#                    "source": { "where": "...", "read_on": "2026-03-02" }, "state": "proposed" } ] }
# A create names the tracker project of the new ticket in "project", and gives its texts in "after":
#   "after": { "title": "...", "description": "...", "acceptance criteria": "..." }
# A change may name in "subject" the subject of the register it serves.
# The agent moves a change from proposed to accepted (the PO said yes) and to approved (the PO
# approved the exact change it showed), or to refused. Only this command sets applied.
# backlog show writes in "shown" the fingerprint of the text it printed: apply refuses a change
# whose text is no longer that one, so that the PO approves only what they saw.

$ChangesPath = Join-Path $Workspace 'state\backlog-changes.json'
$TicketTexts = 'title', 'description', 'acceptance criteria'
$ChangeDefinition = @'
{ "type": "object", "fields": {
    "id": { "type": "text", "required": true },
    "kind": { "type": "text", "required": true, "allowed": ["create", "edit"] },
    "ticket": { "type": "text" },
    "project": { "type": "text" },
    "subject": { "type": "text" },
    "field": { "type": "text" },
    "before": { "type": "text" },
    "after": { "type": "any", "required": true },
    "reason": { "type": "text", "required": true },
    "state": { "type": "text", "required": true, "allowed": ["proposed", "accepted", "approved", "applied", "refused"] },
    "shown": { "type": "text" }
} }
'@ | ConvertFrom-Json
$ChangeDefinition.fields.field | Add-Member allowed $TicketTexts
# The source of a change is written as the source of a record.
$ChangeDefinition.fields | Add-Member source (Read-JsonFile (Join-Path $Tools 'definitions\common.json')).fields.source

function Test-Change($Change) {
    # What is wrong with one change, beyond its fields: what its kind needs.
    $given = { param($Name) $null -ne $Change.PSObject.Properties[$Name] -and $null -ne $Change.$Name }
    # The identifier names the change's file in the outbox.
    if ($Change.id -is [string] -and $Change.id -cnotmatch '^[A-Za-z0-9-]+$') { "the identifier '$($Change.id)' holds other characters than letters, digits and dashes" }
    if ($Change.subject -is [string] -and (Find-Record $Change.subject).type -ne 'subject') { "the subject '$($Change.subject)' is no subject of the register" }
    if ($Change.kind -ceq 'edit') {
        if (-not ((& $given 'ticket') -and (& $given 'field') -and (& $given 'before'))) { "an edit names its 'ticket', its 'field' and its text 'before'" }
        if (& $given 'project') { "an edit names no 'project': its ticket has one" }
        if ($Change.after -isnot [string]) { "field 'after' of an edit is its new text" }
        elseif ($Change.after -ceq $Change.before) { 'the text after is the text before: the change changes nothing' }
    }
    if ($Change.kind -ceq 'create') {
        if (-not (& $given 'project')) { "a create names the tracker 'project' of the new ticket" }
        if ((& $given 'ticket') -or (& $given 'field') -or (& $given 'before')) { "a create names no 'ticket', 'field' or 'before': it gives the texts of the new ticket in 'after'" }
        if ($Change.after -isnot [System.Management.Automation.PSCustomObject]) { "field 'after' of a create holds the texts of the new ticket, as { `"title`": `"...`" }" }
        else {
            foreach ($text in $Change.after.PSObject.Properties) {
                if ($TicketTexts -cnotcontains $text.Name) { "field 'after.$($text.Name)' is not a text of a ticket: $($TicketTexts -join ', ')" }
                elseif ($text.Value -isnot [string]) { "field 'after.$($text.Name)' must be text" }
            }
            if (-not "$($Change.after.title)".Trim()) { "missing required field 'after.title'" }
        }
    }
}

function Get-BacklogChanges {
    # The changes of the change proposal, validated in full. Any problem refuses it whole: the run
    # ends with the reasons, and nothing is done.
    if (-not (Test-Path -LiteralPath $ChangesPath)) { Stop-Run 'No change proposal: state\backlog-changes.json does not exist.' }
    $changes = @()
    $reasons = @()
    try { $changes = @((Read-JsonFile $ChangesPath).changes | Where-Object { $null -ne $_ }) }
    catch { $reasons += 'The change proposal is not valid JSON written as UTF-8.' }
    $number = 0
    $seen = @{}
    foreach ($change in $changes) {
        $number++
        $name = if ($change.id -is [string] -and $change.id.Trim()) { $change.id } else { "$number" }
        $problems = @(
            if ($change -isnot [System.Management.Automation.PSCustomObject]) { 'a change is a group of fields' }
            else {
                Test-Value $ChangeDefinition $change ''
                Test-Change $change
                if ($seen[$name]) { "the identifier '$name' is given to another change" }
            }
        )
        $seen[$name] = $true
        foreach ($problem in $problems) { $reasons += "Change ${name}: $problem." }
    }
    if ($reasons) {
        Stop-Run (@('Change proposal refused. Nothing was done.') + @($reasons | ForEach-Object { "- $_" }) +
            "The agent only creates a ticket or edits its text ($($TicketTexts -join ', ')): deleting, closing, reopening or moving a ticket, and its status, assignee, estimate, sprint and priority, stay the PO's. Correct the change proposal, then run the command again.")
    }
    $changes
}

$words = @($Arguments | Where-Object { $_ })
$action = if ($words) { $words[0] }

if ($action -ceq 'alerts') {
    # backlog alerts: checks the backlog alerts of state\backlog-alerts.json (see Read-BacklogAlerts)
    # and lists them, then names each refinement session near, whose tickets not ready to list.
    $read = Read-BacklogAlerts
    if ($read.problems) { Stop-Run (@('Backlog alerts refused: state\backlog-alerts.json is left off the morning page.') + @($read.problems | ForEach-Object { "- $_" }) + 'Correct it, then run backlog alerts again.') }
    $alerts = $read.alerts
    if (-not $alerts) { 'No backlog alerts: state\backlog-alerts.json does not exist.' }
    else {
        $kinds = 'contradictions', 'duplicates', 'not_ready', 'stale' | ForEach-Object { @($alerts.$_ | Where-Object { $_ }).Count }
        "Backlog alerts: $($kinds[0]) contradiction(s), $($kinds[1]) duplicate(s), $($kinds[2]) not ready, $($kinds[3]) stale; valid."
        foreach ($alert in @($alerts.contradictions | Where-Object { $_ })) { "- $($alert.ticket) is open for work $($alert.decision) dropped: $($alert.why)" }
        foreach ($alert in @($alerts.duplicates | Where-Object { $_ })) { "- $($alert.ticket) describes the same need as $($alert.same_as): $($alert.why)" }
        foreach ($alert in @($alerts.not_ready | Where-Object { $_ })) {
            "- $($alert.ticket) is not ready: " + (@($alert.missing | ForEach-Object { if ($_ -ceq 'dependency') { "waits for $($alert.waits_for)" } else { "no $_" } }) -join ', ')
        }
        foreach ($alert in @($alerts.stale | Where-Object { $_ })) { "- $($alert.ticket) is stale: no update for $(Get-DaysSince $alert.updated) days" }
    }
    $sessions = @(Get-RefinementSessions)
    foreach ($session in $sessions) { "Refinement session to prepare: $($session.title) on $($session.date). List under not_ready the tickets not ready for it." }
    if (-not $sessions) { 'No refinement session within five working days in the calendar snapshot of today: not_ready stays empty, and the morning page shows none.' }
    return
}
if ($action -ceq 'order') {
    # The order the agent proposes for the top of the backlog, state\backlog-order.json, written as
    # a view, views\backlog-order.md. It moves nothing in the tracker: reordering is the PO's.
    #   { "order": [ { "ticket": "ONB-160", "title": "...", "why": "... [D-2026-002]" } ] }
    # first the ticket to take first. Each one says why it stands there, citing a record as a view
    # does; "inferred": true marks a reason whose link from the ticket to that record the agent
    # inferred rather than read in the tracker, and the view says so beside it. A record cited
    # missing or superseded, a reason that cites none, a ticket placed twice or more tickets than
    # backlog_top of settings.json (10 when not set) refuses the order whole.
    Assert-RegisterCommitted
    $orderPath = Join-Path $Workspace 'state\backlog-order.json'
    if (-not (Test-Path -LiteralPath $orderPath)) { Stop-Run 'No order proposed: state\backlog-order.json does not exist.' }
    $file = try { Read-JsonFile $orderPath } catch { Stop-Run 'state\backlog-order.json cannot be read: it must hold JSON, saved as UTF-8. Nothing was written.' }
    $definition = '{ "type": "object", "fields": { "order": { "type": "list", "required": true, "items": { "type": "object", "fields": {
        "ticket": { "type": "text", "required": true }, "title": { "type": "text" }, "why": { "type": "text", "required": true },
        "inferred": { "type": "boolean" } } } } } }' | ConvertFrom-Json
    $top = if ($Settings.backlog_top -is [int] -and $Settings.backlog_top -gt 0) { $Settings.backlog_top } else { 10 }
    $tickets = @($file.order | Where-Object { $null -ne $_ })
    $placed = @{}
    $problems = @(
        Test-Value $definition $file ''
        if (-not $tickets) { 'the order holds no ticket' }
        if ($tickets.Count -gt $top) { "the order holds $($tickets.Count) tickets, and the top of the backlog is $top, as backlog_top in settings.json says" }
        foreach ($ticket in $tickets) {
            if (-not @(Get-Cited "$($ticket.why)").Count) { "the reason of ticket $($ticket.ticket) cites no record: it cites the subject, the commitment or the decision that places it, as [D-2026-002]" }
            if ($placed["$($ticket.ticket)"]) { "ticket $($ticket.ticket) is placed twice" }
            $placed["$($ticket.ticket)"] = $true
        }
    ) + @(Test-Cited @(Get-Cited (@(Get-Texts $file) -join "`n")))
    if ($problems) { Stop-Run (@('Order refused: state\backlog-order.json. Nothing was written; correct it, then run backlog order again.') + @($problems | ForEach-Object { "- $_" })) }
    $labels = Get-Labels $Settings.languages.default
    $words = $labels.backlog_order
    $rank = 0
    $rows = @(foreach ($ticket in $tickets) {
            $why = "$($ticket.why)" + $(if ($ticket.inferred -eq $true) { " ($($words.inferred))" })
            , @("$((++$rank))", "$($ticket.ticket)", "$($ticket.title)", $why | ForEach-Object { ($_ -replace '\s*\r?\n\s*', ' ').Replace('|', '\|') })
        })
    $lines = @("# $($words.title)", '') + @(Get-Stamp $labels) + @('', $words.note, '') + @(Write-Table $words.rank, $words.ticket, $words.ticket_title, $words.why $rows)
    Write-TextFile (Join-Path $Workspace 'views\backlog-order.md') (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
    "Proposed order written: views/backlog-order.md, $($tickets.Count) ticket(s). Nothing was moved in the tracker: reordering the backlog is the PO's, in the tracker."
    return
}

if ('check', 'show', 'apply', 'template' -cnotcontains $action) { Stop-Run 'backlog takes check, show <id>, apply <id>, order, alerts or template.' }

if ($action -ceq 'template') {
    # The ticket template, for a ticket draft: templates\ticket-<language>.md in the workspace when the
    # organisation has its own, otherwise the kit's, in the default language unless one is given. Each
    # "## <name>" heads one text of a ticket, named as the labels of that language name it; it is
    # printed under the name the text has in "after" of a create change.
    $language = if ($words.Count -gt 1) { $words[1] } else { $Settings.languages.default }
    $names = (Get-Labels $language).backlog.fields
    $name, $whose = "templates/ticket-$language.md", "the organisation's"
    if (-not (Test-Path -LiteralPath (Join-Path $Workspace $name))) { $name, $whose = "tools/$name", "the kit's" }
    $sections = [ordered]@{}
    $heading = $null
    foreach ($line in [IO.File]::ReadAllText((Join-Path $Workspace $name), $Utf8).Replace("`r`n", "`n").Split("`n")) {
        if ($line -match '^## (.+?)\s*$') { $heading = $Matches[1]; $sections[$heading] = @() }
        elseif ($null -ne $heading) { $sections[$heading] += $line }
    }
    $headings = @($TicketTexts | ForEach-Object { $names.$_ })
    $lacking = @($headings | Where-Object { -not $sections.Contains($_) } | ForEach-Object { "## $_" })
    $other = @($sections.Keys | Where-Object { $headings -notcontains $_ } | ForEach-Object { "## $_" })
    if ($lacking -or $other) {
        Stop-Run (@(
                if ($lacking) { "The template $name lacks the section(s) $($lacking -join ', ')." }
                if ($other) { "The template $name holds the section(s) $($other -join ', '), which are no text of a ticket." }
            ) + "Nothing was done. A ticket template holds one section per text of a ticket, headed $(@($headings | ForEach-Object { "## $_" }) -join ', '), and no other.")
    }
    "Ticket template: $name, $whose."
    'Each text below goes in "after" of a create change, under its name, with its places in braces filled.'
    foreach ($text in $TicketTexts) { '', "`"$text`":", ($sections[$names.$text] -join "`n").Trim() }
    return
}

$changes = @(Get-BacklogChanges)

if ($action -ceq 'check') {
    "Change proposal: $($changes.Count) change(s), valid."
    foreach ($change in $changes) {
        $what = if ($change.kind -ceq 'edit') { "edit $($change.ticket), $($change.field)" } else { "create a ticket in $($change.project)" }
        "- $($change.id): $what ($($change.state))"
    }
    return
}

function Format-BacklogChange($Change) {
    # One change as the PO reviews it and as the team will see it: its texts exactly, lines kept.
    $labels = (Get-Labels $Settings.languages.default).backlog
    $what = if ($Change.kind -ceq 'edit') { $labels.edit -f $Change.ticket, $labels.fields.($Change.field) } else { $labels.create -f $Change.project }
    @(
        "$($labels.change -f $Change.id): $what"
        $labels.reason -f $Change.reason
        $labels.source -f $Change.source.where, $Change.source.read_on
        if ($Change.subject) { $labels.subject -f $Change.subject }
        if ($Change.kind -ceq 'edit') { '', $labels.before, $Change.before, '', $labels.after, $Change.after }
        else { foreach ($text in $TicketTexts | Where-Object { "$($Change.after.$_)".Trim() }) { '', "$($labels.fields.$text):", $Change.after.$text } }
    ) -join "`n"
}

function Get-Fingerprint($Change) {
    # The SHA-256 of the change as backlog show prints it.
    $sha = [Security.Cryptography.SHA256]::Create()
    -join @($sha.ComputeHash($Utf8.GetBytes((Format-BacklogChange $Change))) | ForEach-Object { $_.ToString('x2') })
}

function Get-TicketText([string]$Read, [string]$Field) {
    # One text of a ticket as its file in the tracker's folder holds it: the title on its line
    # "Title:", the description after the first blank line, and the acceptance criteria after the
    # line that opens with "Acceptance criteria:", which ends the description. "" when it holds none.
    $head, $body = $Read.Split(@("`n`n"), 2, [StringSplitOptions]::None)
    $description, $criteria = [regex]::Split("$body", '(?im)^Acceptance criteria:[ \t]*', 2)
    $text = switch ($Field) {
        'title' { if ($head -match '(?m)^Title:[ \t]*(.*)$') { $Matches[1] } }
        'description' { $description }
        'acceptance criteria' { $criteria }
    }
    $text = "$text".Trim()
    # ponytail: an export that says "none" for no criterion reads as none; other words for it do not.
    if ($Field -ceq 'acceptance criteria' -and $text -eq 'none') { '' } else { $text }
}

$id = if ($words.Count -eq 2 -or ($action -ceq 'apply' -and $words.Count -eq 3 -and $words[2] -ceq 'done')) { $words[1] }
$change = @($changes | Where-Object { $_.id -ceq $id }) | Select-Object -First 1
if (-not $change) { Stop-Run "The change proposal holds no change '$id'. backlog $action takes the identifier of one change: backlog $action 1." }

if ($action -ceq 'show') {
    Format-BacklogChange $change
    $file = Read-JsonFile $ChangesPath
    @($file.changes | Where-Object { $_.id -ceq $id })[0] | Add-Member shown (Get-Fingerprint $change) -Force
    Write-JsonFile $ChangesPath $file
    return
}

# --- apply ----------------------------------------------------------------------------------------
# One approved change, once. How depends on the tracker's entry in connections.json:
# - folder (the scenarios): the change is written as a file of the outbox, outbox\tracker\<id>.md,
#   never in the tracker, once the field of the ticket as last read, <folder>\<ticket>.txt, is still
#   the text before of an edit, whole (see Get-TicketText);
# - connector with "writes": true: the routine has applied it through the connector; this records it;
# - otherwise: this prints the text to paste and where it goes, and records nothing. Once the PO
#   says it is done, "backlog apply <id> done" records it.
# Each change recorded as applied is added to the applied-change log, state\backlog-log.json, which
# the next apply of the register commits with the rest of the state.
$logPath = Join-Path $Workspace 'state\backlog-log.json'
$log = if (Test-Path -LiteralPath $logPath) { @((Read-JsonFile $logPath).applied | Where-Object { $null -ne $_ }) } else { @() }
$done = @($log | Where-Object { $_.change -ceq $id }) | Select-Object -First 1
if ($done) { Stop-Run "Change $id is applied already, on $($done.date): a change is applied once. Nothing was done." }
if ($change.state -cne 'approved') {
    Stop-Run "Change $id is $($change.state), not approved: a change is applied only once the PO has approved it as backlog show gives it. Nothing was done."
}
if ($change.shown -cne (Get-Fingerprint $change)) {
    Stop-Run "Change $id is not applied: it is not the text backlog show last gave the PO. Nothing was done. Show it again with backlog show $id, and apply it only once the PO approved that exact text."
}

$tracker = $Connections.tracker
if ($tracker.mode -ceq 'folder') {
    if ($change.kind -ceq 'edit') {
        $shown = "$($tracker.folder)/$($change.ticket).txt".Replace('\', '/')
        $ticket = if ([IO.Path]::IsPathRooted($tracker.folder)) { Join-Path $tracker.folder "$($change.ticket).txt" } else { Join-Path $Workspace "$($tracker.folder)\$($change.ticket).txt" }
        $read = if (Test-Path -LiteralPath $ticket -PathType Leaf) { [IO.File]::ReadAllText($ticket, $Utf8).Replace("`r`n", "`n") }
        if ($null -eq $read -or (Get-TicketText $read $change.field) -cne $change.before.Replace("`r`n", "`n").Trim()) {
            Stop-Run "Change $id is not applied: ticket $($change.ticket), as last read in $shown, no longer holds its text before. Nothing was done. Tell the PO, read the ticket again and propose the change again."
        }
    }
    $outbox = Join-Path $Workspace 'outbox\tracker'
    New-Item -ItemType Directory -Path $outbox -Force | Out-Null
    Write-TextFile (Join-Path $outbox "$id.md") ((Format-BacklogChange $change) + "`n")
    $how = "outbox/tracker/$id.md"
    $said = "Change $id applied: written to $how"
}
elseif ($tracker.mode -ceq 'connector' -and $tracker.writes -eq $true) {
    $how = 'through the connector'
    $said = "Change $id recorded as applied through the connector"
}
elseif ($words.Count -eq 3 -and $words[2] -ceq 'done') {
    $how = 'pasted by the PO'
    $said = "Change $id recorded as pasted by the PO"
}
else {
    # The tracker does not let the agent write: the PO pastes the change.
    $labels = (Get-Labels $Settings.languages.default).backlog
    Format-BacklogChange $change
    ''
    if ($change.kind -ceq 'edit') { $labels.paste_edit -f $change.ticket, $labels.fields.($change.field) } else { $labels.paste_create -f $change.project }
    ''
    "Not recorded: the tracker does not let the agent write. Give the PO this text to paste, word for word; once the PO says it is done, record it: backlog apply $id done"
    return
}

$entry = [ordered]@{ date = $Today; change = $id; kind = $change.kind; ticket = $change.ticket; project = $change.project; field = $change.field
    before = $change.before; after = $change.after; approved_by = 'the PO'; applied = $how }
Write-JsonFile $logPath @{ applied = @($log) + $entry }
$file = Read-JsonFile $ChangesPath
@($file.changes | Where-Object { $_.id -ceq $id })[0].state = 'applied'
Write-JsonFile $ChangesPath $file
"$said, and logged in state/backlog-log.json. The next apply of the register commits the log."
