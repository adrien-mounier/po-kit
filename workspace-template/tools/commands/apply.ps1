# apply: validates the pending proposal again, writes its records, commits and pushes to the backup.

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

function New-NumberedIdentifier([string]$Prefix, [string]$Folder) {
    # The prefix, the year recorded and a number: one more than the highest already filed for that
    # year, so that a number is never taken twice. Records are never deleted, so the files hold
    # every number taken and no counter is kept.
    $start = "$Prefix-$($Today.Substring(0, 4))-"
    $highest = 0
    foreach ($file in Get-ChildItem -LiteralPath $Folder -Filter "$start*.json") {
        $number = 0
        if ([int]::TryParse($file.BaseName.Substring($start.Length), [ref]$number) -and $number -gt $highest) { $highest = $number }
    }
    $start + ($highest + 1).ToString('000')
}

Assert-RegisterCommitted

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

$settled = @(Save-Collect)

# A line keeps the number preview gave it, whatever the selection.
$line = 0
$identifiers = @{}
$applied = @(foreach ($operation in $operations) {
        $line++
        if ($dropped -contains $line) { continue }
        $definition = Get-Definition $operation.type
        $folder = Join-Path $Workspace $definition.folder
        if ($definition.folder_per_year) { $folder = Join-Path $folder $Today.Substring(0, 4) }
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $record = Complete-Value $definition.record $operation.fields
        $record.id = if ($definition.identifier_prefix) { New-NumberedIdentifier $definition.identifier_prefix $folder }
        else { New-Identifier $record.title $folder }
        $identifiers[$line] = $record.id
        $named = Get-LineNamed $record.subject
        if ($named) { $record.subject = $identifiers[$named] }
        $record.type = $operation.type
        $record.date_recorded = $Today
        $record.date_updated = $Today
        Write-JsonFile (Join-Path $folder "$($record.id).json") $record
        "$($operation.op) $($operation.type) $($record.id)"
    }) + $settled

# The proposal stays pending until the commit is made, so that a failed run can be applied again
# from the last commit.
Invoke-Git add -A register inbox state ':(exclude)state/proposal.json'
Invoke-Git commit -q -m "Apply proposal: $($operations.Count - $dropped.Count) operation(s)" -m ($applied -join "`n")
Remove-Item -LiteralPath $ProposalPath

'Applied and committed:'
$applied | ForEach-Object { "- $_" }
if ($dropped) { "Dropped: line $($dropped -join ', ')." }
Push-ToBackup
