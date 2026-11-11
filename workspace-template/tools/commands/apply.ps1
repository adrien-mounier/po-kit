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

# A selection keeps some lines only, numbered as preview shows them: apply 1 3
# The other lines are dropped with the proposal.
$operations = @(Get-PendingProposal)
$lines = @(for ($line = 1; $line -le $operations.Count; $line++) { "$line" })
$selection = @($Arguments | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ })
$wrong = @($selection | Where-Object { $lines -notcontains $_ })
if ($wrong) {
    Stop-Run (@('Selection refused. Nothing was written.') +
        @($wrong | ForEach-Object { "- '$_' is not a line of the proposal, which has lines 1 to $($operations.Count)." }))
}
$dropped = @(if ($selection) { $lines | Where-Object { $selection -notcontains $_ } })
$operations = @($lines | Where-Object { $dropped -notcontains $_ } | ForEach-Object { $operations[$_ - 1] })

$settled = @(Save-Collect)

$applied = @(foreach ($operation in $operations) {
        $definition = Get-Definition $operation.type
        $folder = Join-Path $Workspace $definition.folder
        $record = Complete-Value $definition.record $operation.fields
        $record.id = New-Identifier $record.title $folder
        $record.type = $operation.type
        $record.date_recorded = $Today
        $record.date_updated = $Today
        Write-JsonFile (Join-Path $folder "$($record.id).json") $record
        "$($operation.op) $($operation.type) $($record.id)"
    }) + $settled

# The proposal stays pending until the commit is made, so that a failed run can be applied again
# from the last commit.
Invoke-Git add -A register inbox state ':(exclude)state/proposal.json'
Invoke-Git commit -q -m "Apply proposal: $($operations.Count) operation(s)" -m ($applied -join "`n")
Remove-Item -LiteralPath $ProposalPath

'Applied and committed:'
$applied | ForEach-Object { "- $_" }
if ($dropped) { "Dropped: line $($dropped -join ', ')." }
