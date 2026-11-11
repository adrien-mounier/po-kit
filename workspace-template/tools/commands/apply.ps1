# apply: validates the pending proposal again, writes its records and commits.

function New-Identifier([string]$Title, [string]$Folder) {
    # A readable slug of the title, made distinct from the records already filed.
    $text = $Title.ToLowerInvariant().Replace([string][char]0x153, 'oe').Replace([string][char]0xE6, 'ae')
    $slug = ($text.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '' -replace '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).Trim('-') }
    if (-not $slug) { $slug = 'subject' }
    $id = $slug
    for ($n = 2; Test-Path -LiteralPath (Join-Path $Folder "$id.json"); $n++) { $id = "$slug-$n" }
    $id
}

Assert-RegisterCommitted
$applied = @(foreach ($operation in @(Get-PendingProposal)) {
        $definition = Get-Definition $operation.type
        $folder = Join-Path $Workspace $definition.folder
        $record = Complete-Value $definition.record $operation.fields
        $record.id = New-Identifier $record.title $folder
        $record.type = $operation.type
        $record.date_recorded = $Today
        $record.date_updated = $Today
        Write-JsonFile (Join-Path $folder "$($record.id).json") $record
        "$($operation.op) $($operation.type) $($record.id)"
    })

# The proposal stays pending until the commit is made, so that a failed run can be applied again
# from the last commit.
Invoke-Git add -A register
Invoke-Git commit -q -m "Apply proposal: $($applied.Count) operation(s)" -m ($applied -join "`n")
Remove-Item -LiteralPath $ProposalPath

'Applied and committed:'
$applied | ForEach-Object { "- $_" }
