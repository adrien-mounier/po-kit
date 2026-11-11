# preview: shows the pending proposal as a numbered table. It writes nothing.

function Format-Value($Value) {
    # A field value on one line: lists joined by commas, nested fields between parentheses.
    if ($Value -is [array]) { return (@($Value | ForEach-Object { Format-Value $_ }) -join ', ') }
    # A value completed by the register tool holds its nested fields as a dictionary.
    if ($Value -is [System.Collections.IDictionary]) { $Value = [pscustomobject]$Value }
    if ($Value -is [System.Management.Automation.PSCustomObject]) { return '(' + (Format-Fields $Value) + ')' }
    if ($Value -is [bool]) { return "$Value".ToLower() }
    "$Value" -replace '\s*\r?\n\s*', ' '
}

function Format-Fields($Fields, [string[]]$Except) {
    # The fields that hold something: a record as it is recorded carries every field, most empty.
    $given = $Fields.PSObject.Properties | Where-Object { $Except -notcontains $_.Name -and "$(Format-Value $_.Value)" }
    @($given | ForEach-Object { "$($_.Name): $(Format-Value $_.Value)" }) -join '; '
}

function Format-Change($Change) {
    # A field that an update changes, with its current and its proposed value.
    $current, $proposed = foreach ($value in $Change.previous, $Change.new) { $text = Format-Value $value; if ($text -and $text -ne '()') { $text } else { '(none)' } }
    "$($Change.field): $current -> $proposed"
}

Assert-RegisterCommitted
$operations = @(Get-PendingProposal)
$number = 0
$rows = @(foreach ($operation in $operations) {
        $number++
        $type = $operation.type
        $fields = $operation.fields
        if ($operation.op -ceq 'update') {
            # An update shows the record as it is, then each field that changes.
            $found = Find-Record $operation.id
            $type = $found.type
            $fields = $found.record
            $details = @("record: $($operation.id)") + @(Get-Changes $found $operation.fields | ForEach-Object { Format-Change $_ }) +
                "source of the change: $(Format-Value $operation.source)"
        }
        else {
            $details = @(
                if ($fields.supersedes) { $old = Find-Record $fields.supersedes; "supersedes: $($fields.supersedes) ($($old.type): $(Format-Value $old.record.title))" }
                Format-Fields $fields 'title', 'subject', 'evidence_level', 'supersedes'
            )
        }
        $cells = "$number", $operation.op, $type, (Format-Value $fields.title), (Format-Value $fields.subject),
            (Format-Value $fields.evidence_level), $(if ($operation.interpreted) { 'yes' } else { 'no' }),
            (@($details | Where-Object { $_ }) -join '; ')
        , @($cells | ForEach-Object { $_.Replace('|', '\|') })
    })

"Pending proposal: $($operations.Count) operation(s). Nothing is written until it is applied."
''
Write-Table '#', 'Operation', 'Type', 'Title', 'Subject', 'Evidence', 'Interpreted', 'Details' $rows

# Under the table, what applying the proposal settles of its collect.
$collect = Get-PendingCollect
if ($collect) {
    $parts = [ordered]@{
        'Notes to file'       = $collect.notes_processed
        'Sources read'        = @($collect.sources_read | ForEach-Object { "$($_.source): $($_.items) item(s), up to $($_.cutoff)" })
        'Sources not covered' = $collect.sources_not_covered
        'Unclassified items'  = @($collect.unclassified | ForEach-Object { "$(Format-Value $_.source) | $(Format-Value $_.text)" })
    }
    ''
    "Collect of $($collect.collected_at). It is settled when the proposal is applied, whichever lines are kept."
    foreach ($part in $parts.GetEnumerator()) {
        ''
        if ($part.Value) { "$($part.Key):"; $part.Value | ForEach-Object { "- $_" } } else { "$($part.Key): none" }
    }
}
