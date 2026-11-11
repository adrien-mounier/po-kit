# preview: shows the pending proposal as a numbered table. It writes nothing.

function Format-Value($Value) {
    # A field value on one line: lists joined by commas, nested fields between parentheses.
    if ($Value -is [array]) { return (@($Value | ForEach-Object { Format-Value $_ }) -join ', ') }
    if ($Value -is [System.Management.Automation.PSCustomObject]) { return '(' + (Format-Fields $Value) + ')' }
    if ($Value -is [bool]) { return "$Value".ToLower() }
    "$Value" -replace '\s*\r?\n\s*', ' '
}

function Format-Fields($Fields, [string[]]$Except) {
    $given = $Fields.PSObject.Properties | Where-Object { $Except -notcontains $_.Name -and $null -ne $_.Value }
    @($given | ForEach-Object { "$($_.Name): $(Format-Value $_.Value)" }) -join '; '
}

function Write-Table([string[]]$Header, [object[]]$Rows) {
    # A Markdown table with aligned columns: readable as plain text, and rendered by a chat.
    # The last column holds the long text and is left unpadded.
    $lines = @(, $Header) + $Rows
    $widths = @(0..($Header.Count - 1) | ForEach-Object { $column = $_; ($lines | ForEach-Object { $_[$column].Length } | Measure-Object -Maximum).Maximum })
    $widths[-1] = $Header[-1].Length
    $number = 0
    foreach ($line in $lines) {
        '| ' + ((0..($Header.Count - 1) | ForEach-Object { $line[$_].PadRight($widths[$_]) }) -join ' | ') + ' |'
        if ($number++ -eq 0) { '|' + (($widths | ForEach-Object { '-' * ($_ + 2) }) -join '|') + '|' }
    }
}

Assert-RegisterCommitted
$operations = @(Get-PendingProposal)
$number = 0
$rows = @(foreach ($operation in $operations) {
        $number++
        $fields = $operation.fields
        $cells = "$number", $operation.op, $operation.type, (Format-Value $fields.title), (Format-Value $fields.subject),
            (Format-Value $fields.evidence_level), $(if ($operation.interpreted) { 'yes' } else { 'no' }),
            (Format-Fields $fields 'title', 'subject', 'evidence_level')
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
