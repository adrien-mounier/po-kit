# preview: shows the pending proposal as a numbered table. It writes nothing.

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
        'Sources read'        = @($collect.sources_read | ForEach-Object { "$($_.source): $($_.items) item(s), up to $($_.cutoff)$(Format-CapReached $_)" })
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
