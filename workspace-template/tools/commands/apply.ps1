# apply: validates the pending proposal again, settles its collect, writes its records,
# regenerates the portfolio view, runs the check, commits and pushes to the backup. The commit
# also saves the weekly syntheses stored since the last apply.
#
#   apply          every line of the proposal
#   apply 1 3      lines 1 and 3 only, numbered as preview shows them; the others are dropped
#   apply none     no line: every line is dropped
#   apply plain    the plain facts only: the lines that wait for the PO (Get-WaitingLines) stay
#                  pending, as a proposal of their own, and are shown

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

function Assert-CommitterKnown {
    # apply ends with a commit, and git refuses to commit when it does not know who commits: asked
    # here, before anything is written. git answers on its error stream, so errors may continue in
    # this function, as in Push-ToBackup.
    # ponytail: the committer alone is asked. git takes the author from the same two settings,
    # unless a machine sets the two apart.
    $ErrorActionPreference = 'Continue'
    & git -C $Workspace var GIT_COMMITTER_IDENT 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Stop-Run 'git does not know who commits on this machine, and apply saves the register with a commit. Nothing was done.',
            'Tell git once, with your own name and address, then apply again:',
            '  git config --global user.name "Your Name"', '  git config --global user.email "you@example.com"'
    }
}

Assert-RegisterCommitted
Assert-CommitterKnown
# The portfolio view is regenerated in the default language. Its labels are read before anything
# is written, so that a language without labels refuses the run whole.
$labels = Get-Labels $Settings.languages.default

$operations = @(Get-PendingProposal)
$lines = @(for ($line = 1; $line -le $operations.Count; $line++) { $line })
$selection = @($Arguments | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ })
# A selection is the numbers of the lines kept, or one word: none or plain. A line is a number from
# here on: what was given as a number is read as one, once, and the rest is refused below.
$word = if ('none', 'plain' -ccontains "$selection") { "$selection" }
$kept = @(if (-not $word) { $selection | ForEach-Object { $number = 0; if ([int]::TryParse($_, [ref]$number)) { $number } else { $_ } } })
# The lines this run does not apply: dropped for good, or left pending because they wait for the PO.
$dropped = @(if ($word -eq 'none') { $lines } elseif ($kept.Count) { $lines | Where-Object { $kept -notcontains $_ } })
$waiting = @(if ($word -eq 'plain') { Get-WaitingLines $operations })
$left = $dropped + $waiting
$wrong = @(
    $kept | Where-Object { $lines -notcontains $_ } |
        ForEach-Object { "'$_' is not a line of the proposal, which has $(if ($lines) { "lines 1 to $($lines.Count)" } else { 'no line' })" }
    # A record kept needs its subject: the line that creates it cannot be dropped.
    foreach ($line in $lines | Where-Object { $dropped -notcontains $_ }) {
        $named = Get-LineNamed ($operations[$line - 1].fields.subject)
        if ($dropped -contains $named) { "Line $line is attached to the subject that line $named creates, and the selection drops line $named" }
    }
)
# The proposal was validated with every line: what the lines applied leave must hold on its own.
if (-not $wrong -and $left) { $wrong = @(Test-ProposalResult $operations ($lines | Where-Object { $left -notcontains $_ })) }
if ($wrong) { Stop-Run (@('Selection refused. Nothing was written.') + @($wrong | ForEach-Object { "- $_." })) }

if ($left.Count -eq $lines.Count -and -not (Get-PendingCollect)) {
    # No line to apply and no collect to settle: nothing is written, so nothing is committed.
    if ($waiting) { "No plain fact to record: the $($waiting.Count) line(s) of the proposal wait for the PO." }
    else {
        Remove-Item -LiteralPath $ProposalPath
        "Dropped: line $($dropped -join ', '). Nothing was recorded, and no proposal is pending."
    }
    return
}

# A run that fails once it has started to write is undone, so that apply can simply be run again:
# no note is lost, and the last commit is the recovery point. The register is as its last commit
# when the run starts (Assert-RegisterCommitted). What the run rewrites outside the register is
# kept here as it is before the first write, a file that is absent as nothing.
$rewritten = @{}
foreach ($file in 'state\last-collect.json', 'state\unclassified.md', 'views\portfolio.md', 'views\check-report.md') {
    $path = Join-Path $Workspace $file
    $rewritten[$path] = $null
    if (Test-Path -LiteralPath $path) { $rewritten[$path] = [IO.File]::ReadAllBytes($path) }
}
$committed = $false
try {
    # The notes are filed first, all or none, so that a note that cannot be moved stops the run
    # before anything else is written.
    $settled = @(Save-Collect)

    # A line keeps the number preview gave it, whatever the selection.
    $line = 0
    $identifiers = @{}
    $applied = @(foreach ($operation in $operations) {
            $line++
            if ($left -contains $line) { continue }
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
            $said = "$($operation.op) $($operation.type) $($record.id)"
            if ($record.supersedes) {
                # The record superseded is kept: it is marked and linked to the new one, and its history
                # shows it, with the source of the new record as the source of the change.
                Update-Record (Find-Record $record.supersedes) ([pscustomobject]@{ status = 'superseded'; superseded_by = $record.id }) $record.source
                $said += ", which supersedes $($record.supersedes)"
            }
            $said
        }) + $settled

    # The proposal stays pending until the commit is made, so that a failed run can be applied again
    # from the last commit. The commit holds all that the run wrote: the records, the notes filed, the
    # collect state and the unclassified list, and never the proposal. It also saves the settings
    # and the connections as they are, so that a change to them reaches the backup.
    Invoke-Git add -A register inbox state settings.json connections.json ':(exclude)state/proposal.json'
    # The portfolio view is generated from the register as staged, and goes in the same commit: the
    # view of a commit is never behind its register.
    Write-PortfolioView $labels
    # So is the check report. What the check finds never undoes the apply: it is said, and committed.
    $check = Write-CheckReport $labels
    # The commit takes every view: a weekly synthesis stored since the last apply, under views\weekly,
    # is saved and pushed with the rest. The next synthesis starts its period from it.
    Invoke-Git add -A views
    Invoke-Git commit -q -m "Apply proposal: $($operations.Count - $left.Count) operation(s)" -m ($applied -join "`n")
    $committed = $true
}
finally {
    if (-not $committed) {
        foreach ($note in $FiledNotes.Keys) { [IO.File]::Move($FiledNotes[$note], $note) }
        foreach ($path in $rewritten.Keys) {
            if ($null -ne $rewritten[$path]) { [IO.File]::WriteAllBytes($path, $rewritten[$path]) }
            elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
        }
        # Nothing stays staged, and the register is again the one of the last commit.
        & git -C $Workspace reset -q
        & git -C $Workspace checkout -q -- register
        & git -C $Workspace clean -fdq -- register
        Write-Host 'Nothing was applied: the register, the notes, the collect state and the views are as they were before this run, and the proposal is still pending. Apply again once the cause is settled.'
    }
}
if ($waiting) {
    # The lines that wait become the pending proposal, numbered again from 1. Each one still names
    # its subject: by the identifier the subject received, or by the new number of the line that
    # creates it. The collect is settled, so the proposal no longer holds it.
    foreach ($line in $waiting) {
        $fields = $operations[$line - 1].fields
        $named = Get-LineNamed $fields.subject
        if ($named) { $fields.subject = if ($identifiers[$named]) { $identifiers[$named] } else { "line $($waiting.IndexOf($named) + 1)" } }
    }
    Write-JsonFile $ProposalPath @{ operations = @($waiting | ForEach-Object { $operations[$_ - 1] }) }
}
else { Remove-Item -LiteralPath $ProposalPath }

'Applied and committed:'
$applied | ForEach-Object { "- $_" }
if ($dropped) { "Dropped: line $($dropped -join ', ')." }
'Portfolio view regenerated: views\portfolio.md'
$check.summary
Push-ToBackup
if ($waiting) {
    # The lines that wait are shown as preview shows any pending proposal, which validates them too.
    ''
    "Waiting for the PO: $($waiting.Count) line(s), still pending."
    . (Join-Path $Tools 'commands\preview.ps1')
}
