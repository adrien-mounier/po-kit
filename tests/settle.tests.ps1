# Applying a proposal settles the collect it comes from: the lines the PO keeps, the notes filed,
# how far each source was read, and the unclassified items.

function New-CollectProposal([hashtable]$Parts = @{}) {
    # A valid proposal of a collect at Example Bank on the morning of 2 March 2026: notes and mail
    # were read, the tracker was not covered, and nothing else came out of it.
    # $Parts replaces or adds parts of the proposal.
    $proposal = @{
        collected_at        = '2026-03-02T08:30:00+01:00'
        sources_read        = @(
            @{ source = 'notes'; cutoff = '2026-03-02T08:30:00+01:00'; items = 2 },
            @{ source = 'mail'; cutoff = '2026-03-02T08:12:00+01:00'; items = 14 }
        )
        sources_not_covered = @('tracker')
    }
    foreach ($name in $Parts.Keys) { $proposal[$name] = $Parts[$name] }
    $proposal
}

function Add-InboxNote([string]$Workspace, [string]$Name, [string]$Text = 'Steering committee of Example Bank: the tech lead presents the target journey on 16 March.') {
    # Drops a raw note in the inbox, as the PO would.
    [IO.File]::WriteAllText((Join-Path $Workspace "inbox\$Name"), $Text, $Utf8)
}

Test 'apply with a selection applies those lines only, drops the others, and no proposal stays pending' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation),
            (New-SubjectOperation @{ title = 'Branch appointment booking' }),
            (New-SubjectOperation @{ title = 'Card dispute handling' })
        )
    }

    $run = Invoke-Register $ws apply 1 3

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $records = @(Get-ChildItem (Join-Path $ws 'register\subjects') -Filter *.json | ForEach-Object { $_.BaseName } | Sort-Object)
    Assert-Equal 'card-dispute-handling mobile-onboarding' ($records -join ' ') 'records written'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending'
    Assert-Match $run.Output 'Dropped: line 2\b' 'output'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
}

Test 'a selection naming something that is not a line of the proposal is refused whole' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @((New-SubjectOperation), (New-SubjectOperation @{ title = 'Branch appointment booking' })) }
    $before = Get-WorkspaceSnapshot $ws

    foreach ($wrong in '3', '0', 'two') {
        $run = Invoke-Register $ws apply 1 $wrong

        Assert-Equal 1 $run.ExitCode "exit code for $wrong, with output: $($run.Output)"
        Assert-Match $run.Output 'Selection refused\. Nothing was written\.' "output for $wrong"
        Assert-Match $run.Output "- '$wrong' is not a line of the proposal, which has lines 1 to 2\." "reason for $wrong"
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for $wrong"
    }
}

Test 'the lines kept are applied in the order of the proposal, however the selection is written' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(1..11 | ForEach-Object { New-SubjectOperation @{ kind = $(if ($_ -eq 11) { 'service' } else { 'product' }) } }) }

    $run = Invoke-Register $ws apply '11,2'

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'product' (Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')).kind 'kind of the first subject recorded'
    Assert-Equal 'service' (Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding-2.json')).kind 'kind of the second subject recorded'
}

Test 'apply files the notes listed as processed in the done folder of the current month, content unchanged' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'steering committee.md'
    Add-InboxNote $ws 'call with the sponsor.txt' "The sponsor asks for a date.`r`n`r`nNo date is confirmed.`n"
    Add-InboxNote $ws 'not read yet.md'
    $notes = 'steering committee.md', 'call with the sponsor.txt'
    $hashes = $notes | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $ws "inbox\$_")).Hash }
    Set-Proposal $ws @{ collected_at = '2026-02-28T18:00:00+01:00'; operations = @(New-SubjectOperation); notes_processed = $notes }

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($index in 0, 1) {
        $filed = Join-Path $ws "inbox\done\2026-03\$($notes[$index])"
        Assert-True (Test-Path -LiteralPath $filed) "$($notes[$index]) is not in the done folder of March 2026"
        Assert-Equal $hashes[$index] (Get-FileHash -LiteralPath $filed).Hash "content of $($notes[$index])"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $ws "inbox\$($notes[$index])"))) "$($notes[$index]) is still in the inbox"
    }
    Assert-True (Test-Path -LiteralPath (Join-Path $ws 'inbox\not read yet.md')) 'a note the proposal does not list left the inbox'
}

Test 'a note listed as processed that is not in the inbox makes the proposal refused before any write' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'steering committee.md'
    $absent = 'call with the sponsor.txt', '..\settings.json', 'done'
    Set-Proposal $ws @{
        collected_at    = '2026-03-02T08:30:00+01:00'
        operations      = @(New-SubjectOperation)
        notes_processed = @('steering committee.md') + $absent
    }

    Assert-Refused $ws @($absent | ForEach-Object { [regex]::Escape("the note '$_' is not in the inbox") })
}

Test 'after apply, the collect state holds the time of the collect, how far each source was read with its item count, and the sources not covered' {
    $ws = New-TestWorkspace
    Set-Proposal $ws (New-CollectProposal @{ operations = @(New-SubjectOperation) })

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $state = Read-Json (Join-Path $ws 'state\last-collect.json')
    Assert-Equal '2026-03-02T08:30:00+01:00' $state.collected_at 'time of the collect'
    Assert-Equal 'notes mail' (@($state.sources.PSObject.Properties | ForEach-Object { $_.Name }) -join ' ') 'sources read'
    Assert-Equal '2026-03-02T08:30:00+01:00' $state.sources.notes.cutoff 'cutoff of the notes'
    Assert-Equal 2 $state.sources.notes.items 'items read from the notes'
    Assert-Equal '2026-03-02T08:12:00+01:00' $state.sources.mail.cutoff 'cutoff of the mail'
    Assert-Equal 14 $state.sources.mail.items 'items read from the mail'
    Assert-Equal '2026-03-02T08:30:00+01:00' $state.sources.mail.collected_at 'time of the collect that read the mail'
    Assert-True ($state.not_covered -is [array]) 'the sources not covered are not a list'
    Assert-Equal 'tracker' ($state.not_covered -join ', ') 'sources not covered'
}

Test 'a source the next proposal did not read keeps its previous cutoff in the collect state' {
    $ws = New-TestWorkspace
    Set-Proposal $ws (New-CollectProposal @{ operations = @(New-SubjectOperation) })
    $first = Invoke-Register $ws apply -Today 2026-03-02
    Set-Proposal $ws (New-CollectProposal @{
            collected_at        = '2026-03-03T08:45:00+01:00'
            sources_read        = @(@{ source = 'notes'; cutoff = '2026-03-03T08:45:00+01:00'; items = 1 })
            sources_not_covered = @('mail', 'tracker')
            operations          = @(New-SubjectOperation)
        })

    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $state = Read-Json (Join-Path $ws 'state\last-collect.json')
    Assert-Equal '2026-03-03T08:45:00+01:00' $state.collected_at 'time of the collect'
    Assert-Equal '2026-03-03T08:45:00+01:00' $state.sources.notes.cutoff 'cutoff of the notes'
    Assert-Equal 1 $state.sources.notes.items 'items read from the notes'
    Assert-Equal '2026-03-02T08:12:00+01:00' $state.sources.mail.cutoff 'cutoff of the mail'
    Assert-Equal 14 $state.sources.mail.items 'items read from the mail'
    Assert-Equal '2026-03-02T08:30:00+01:00' $state.sources.mail.collected_at 'time of the collect that read the mail'
    Assert-Equal 'mail, tracker' ($state.not_covered -join ', ') 'sources not covered'
}

Test 'a time of the collect or a cutoff that does not carry its UTC offset is refused' {
    $ws = New-TestWorkspace
    Set-Proposal $ws (New-CollectProposal @{
            collected_at = '2026-03-02T08:30:00'
            sources_read = @(
                @{ source = 'notes'; cutoff = '2026-03-02'; items = 2 },
                @{ source = 'mail'; cutoff = '2026-02-30T08:12:00+01:00'; items = 14 }
            )
            operations   = @(New-SubjectOperation)
        })

    $kind = [regex]::Escape('must be a date and time with its UTC offset (as 2026-03-02T08:30:00+01:00)')
    Assert-Refused $ws @(
        "field 'collected_at' $kind, not '2026-03-02T08:30:00'",
        "field 'sources_read.cutoff' $kind, not '2026-03-02'",
        "field 'sources_read.cutoff' $kind, not '2026-02-30T08:12:00\+01:00'"
    )
}

Test 'the collect state states every time one way, with its UTC offset' {
    $ws = New-TestWorkspace
    Set-Proposal $ws (New-CollectProposal @{
            collected_at = '2026-03-02T07:30:00Z'
            sources_read = @(@{ source = 'mail'; cutoff = '2026-03-01T23:12:00.1234567-05:00'; items = 14 })
            operations   = @(New-SubjectOperation)
        })

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $state = Read-Json (Join-Path $ws 'state\last-collect.json')
    Assert-Equal '2026-03-02T07:30:00+00:00' $state.collected_at 'time of the collect'
    Assert-Equal '2026-03-01T23:12:00-05:00' $state.sources.mail.cutoff 'cutoff of the mail'
    Assert-Equal '2026-03-02T07:30:00+00:00' $state.sources.mail.collected_at 'time of the collect that read the mail'
}

Test 'what a proposal says of its collect is validated like its operations: one reason per problem' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{
        sources_read        = @(@{ source = 'mail'; items = 'many'; pages = 3 })
        sources_not_covered = 'tracker'
        note_processed      = @('steering committee.md')
        unclassified        = @(@{ text = 'Who owns the branch kiosk pilot?' })
        operations          = @((New-SubjectOperation), (New-SubjectOperation @{ kind = 'project' }))
    }

    Assert-Refused $ws @(
        "- unknown field 'sources_read.pages'",
        "- field 'sources_read.items' must be a whole number, not 'many'",
        "- missing required field 'sources_read.cutoff'",
        "- field 'sources_not_covered' must be a list",
        "- unknown field 'note_processed'",
        "- missing required field 'unclassified.source'",
        "- missing required field 'collected_at'",
        "- Line 2: field 'kind' is 'project'"
    )
}
