# backlog: checks, shows and applies the changes to the tracker the agent proposes, kept in
# state\backlog-changes.json, the change proposal, apart from the proposal of the register.
#
#   backlog check          validates the change proposal and lists its changes
#   backlog show <id>      one change as the exact text before and after, for the PO to review
#   backlog apply <id>     applies one approved change, once (see Invoke-Apply below)
#
# The one exception to "the agent modifies nothing in a source": a change creates a ticket or
# edits one of its texts (title, description, acceptance criteria), nothing else. A change that
# would delete, close, reopen or move a ticket, or touch any other field, refuses the proposal whole.
#   { "changes": [ { "id": "1", "kind": "edit", "ticket": "ONB-142", "field": "title",
#                    "before": "...", "after": "...", "reason": "...",
#                    "source": { "where": "...", "read_on": "2026-03-02" }, "state": "proposed" } ] }
# A create names the tracker project of the new ticket in "project", and gives its texts in "after":
#   "after": { "title": "...", "description": "...", "acceptance criteria": "..." }
# The agent moves a change from proposed to accepted (the PO said yes) and to approved (the PO
# approved the exact change it showed), or to refused. Only this command sets applied.

$ChangesPath = Join-Path $Workspace 'state\backlog-changes.json'
$TicketTexts = 'title', 'description', 'acceptance criteria'
$ChangeDefinition = @'
{ "type": "object", "fields": {
    "id": { "type": "text", "required": true },
    "kind": { "type": "text", "required": true, "allowed": ["create", "edit"] },
    "ticket": { "type": "text" },
    "project": { "type": "text" },
    "field": { "type": "text", "allowed": ["title", "description", "acceptance criteria"] },
    "before": { "type": "text" },
    "after": { "type": "any", "required": true },
    "reason": { "type": "text", "required": true },
    "state": { "type": "text", "required": true, "allowed": ["proposed", "accepted", "approved", "applied", "refused"] }
} }
'@ | ConvertFrom-Json
# The source of a change is written as the source of a record.
$ChangeDefinition.fields | Add-Member source (Read-JsonFile (Join-Path $Tools 'definitions\common.json')).fields.source

function Test-Change($Change) {
    # What is wrong with one change, beyond its fields: what its kind needs.
    $given = { param($Name) $null -ne $Change.PSObject.Properties[$Name] -and $null -ne $Change.$Name }
    # The identifier names the change's file in the outbox.
    if ($Change.id -is [string] -and $Change.id -cnotmatch '^[A-Za-z0-9-]+$') { "the identifier '$($Change.id)' holds other characters than letters, digits and dashes" }
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
if ('check', 'show', 'apply' -cnotcontains $action) { Stop-Run 'backlog takes check, show <id> or apply <id>.' }
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
        if ($Change.kind -ceq 'edit') { '', $labels.before, $Change.before, '', $labels.after, $Change.after }
        else { foreach ($text in $TicketTexts | Where-Object { "$($Change.after.$_)".Trim() }) { '', "$($labels.fields.$text):", $Change.after.$text } }
    ) -join "`n"
}

$id = if ($words.Count -eq 2 -or ($action -ceq 'apply' -and $words.Count -eq 3 -and $words[2] -ceq 'done')) { $words[1] }
$change = @($changes | Where-Object { $_.id -ceq $id }) | Select-Object -First 1
if (-not $change) { Stop-Run "The change proposal holds no change '$id'. backlog $action takes the identifier of one change: backlog $action 1." }

if ($action -ceq 'show') {
    Format-BacklogChange $change
    return
}

# --- apply ----------------------------------------------------------------------------------------
# One approved change, once. How depends on the tracker's entry in connections.json:
# - folder (the scenarios): the change is written as a file of the outbox, outbox\tracker\<id>.md,
#   never in the tracker, once the ticket as last read, <folder>\<ticket>.txt, still holds the text
#   before of an edit;
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

$tracker = $Connections.tracker
if ($tracker.mode -ceq 'folder') {
    if ($change.kind -ceq 'edit') {
        $shown = "$($tracker.folder)/$($change.ticket).txt".Replace('\', '/')
        $ticket = if ([IO.Path]::IsPathRooted($tracker.folder)) { Join-Path $tracker.folder "$($change.ticket).txt" } else { Join-Path $Workspace "$($tracker.folder)\$($change.ticket).txt" }
        $read = if (Test-Path -LiteralPath $ticket -PathType Leaf) { [IO.File]::ReadAllText($ticket, $Utf8).Replace("`r`n", "`n") }
        if ($null -eq $read -or -not $read.Contains($change.before.Replace("`r`n", "`n"))) {
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
