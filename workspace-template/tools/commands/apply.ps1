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

function Update-Record($Found, $Fields, $Source) {
    # Rewrites a record found by Find-Record with the fields that change. Each one adds an entry to
    # the history of the record, and the date updated moves.
    $record = $Found.record
    foreach ($change in @(Get-Changes $Found $Fields)) {
        $record.history = @($record.history) + [ordered]@{ date = $Today; field = $change.field; previous = $change.previous; new = $change.new; source = $Source }
        $record.($change.field) = $change.new
    }
    $record.date_updated = $Today
    Write-JsonFile $Found.path $record
}

Assert-RegisterCommitted
$line = 0
$identifiers = @{}
$applied = @(foreach ($operation in @(Get-PendingProposal)) {
        $line++
        if ($operation.op -ceq 'update') {
            $found = Find-Record $operation.id
            Update-Record $found $operation.fields $operation.source
            "update $($found.type) $($operation.id)"
            continue
        }
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
    })

# The proposal stays pending until the commit is made, so that a failed run can be applied again
# from the last commit.
Invoke-Git add -A register
Invoke-Git commit -q -m "Apply proposal: $($applied.Count) operation(s)" -m ($applied -join "`n")
Remove-Item -LiteralPath $ProposalPath

'Applied and committed:'
$applied | ForEach-Object { "- $_" }
Push-ToBackup
