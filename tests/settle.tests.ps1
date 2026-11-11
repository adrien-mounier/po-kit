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

Test 'a selection that keeps a record and drops the line creating its subject is refused whole, with the reason' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'steering committee.md'
    Set-Proposal $ws (New-CollectProposal @{
            notes_processed = @('steering committee.md')
            operations      = @(
                (New-SubjectOperation),
                (New-SubjectOperation @{ title = 'Branch appointment booking' }),
                (New-RecordOperation commitment @{ subject = 'line 1' }),
                (New-RecordOperation risk @{ subject = 'line 2' }),
                (New-RecordOperation decision @{ subject = 'line 1' })
            )
        })
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws apply 2 3 4 5 -Today 2026-03-02

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Selection refused\. Nothing was written\.' 'output'
    Assert-Match $run.Output '- Line 3 is attached to the subject that line 1 creates, and the selection drops line 1\.' 'reason for line 3'
    Assert-Match $run.Output '- Line 5 is attached to the subject that line 1 creates, and the selection drops line 1\.' 'reason for line 5'
    Assert-Equal 2 @($run.Output -split "`n" | Where-Object { $_ -like '- *' }).Count "number of reasons, with output: $($run.Output)"
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'a record kept with the line creating its subject is attached to that subject, whichever lines are dropped' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation),
            (New-RecordOperation commitment @{ subject = 'line 1' }),
            (New-SubjectOperation @{ title = 'Branch appointment booking' }),
            (New-RecordOperation risk @{ subject = 'line 3' })
        )
    }

    $run = Invoke-Register $ws apply 3 4 -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $records = @(Get-ChildItem (Join-Path $ws 'register') -Recurse -File -Filter *.json | ForEach-Object { $_.BaseName } | Sort-Object)
    Assert-Equal 'branch-appointment-booking R-2026-001' ($records -join ' ') 'records written'
    Assert-Equal 'branch-appointment-booking' (Read-Json (Join-Path $ws 'register\risks\R-2026-001.json')).subject 'subject of the risk'
    Assert-Match $run.Output 'Dropped: line 1, 2\.' 'output'
}

Test 'apply files the notes listed as processed in the done folder of the current month, content unchanged' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'steering committee.md'
    Add-InboxNote $ws 'call with the sponsor.txt' "The sponsor asks for a date.`r`n`r`nNo date is confirmed.`n"
    Add-InboxNote $ws 'not read yet.md'
    $notes = 'steering committee.md', 'call with the sponsor.txt'
    $hashes = $notes | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $ws "inbox\$_")).Hash }
    # A note listed twice is filed once.
    Set-Proposal $ws @{ collected_at = '2026-02-28T18:00:00+01:00'; operations = @(New-SubjectOperation); notes_processed = $notes + 'Steering Committee.md' }

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

Test 'a note with the name of a note already filed this month is filed beside it: no note is ever replaced' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'notes.md' 'Monday: the sponsor asks for a date.'
    Set-Proposal $ws (New-CollectProposal @{ notes_processed = @('notes.md') })
    $first = Invoke-Register $ws apply -Today 2026-03-02
    Add-InboxNote $ws 'notes.md' 'Tuesday: no date is confirmed.'
    Set-Proposal $ws (New-CollectProposal @{ collected_at = '2026-03-03T08:30:00+01:00'; notes_processed = @('notes.md') })

    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'Monday: the sponsor asks for a date.' ([IO.File]::ReadAllText((Join-Path $ws 'inbox\done\2026-03\notes.md'))) 'note filed on Monday'
    Assert-Equal 'Tuesday: no date is confirmed.' ([IO.File]::ReadAllText((Join-Path $ws 'inbox\done\2026-03\notes-2.md'))) 'note filed on Tuesday'
    Assert-Match $run.Output 'file note notes\.md as notes-2\.md' 'output'
    Assert-True (-not (Test-Path (Join-Path $ws 'inbox\notes.md'))) 'the note is still in the inbox'
}

Test 'when a note cannot be filed, apply writes nothing and every note stays in the inbox' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'a first note.md'
    Add-InboxNote $ws 'b note open elsewhere.md'
    Set-Proposal $ws (New-CollectProposal @{
            notes_processed = @('a first note.md', 'b note open elsewhere.md')
            operations      = @(New-SubjectOperation)
        })
    $before = Get-WorkspaceSnapshot $ws

    # Another program holds the second note open.
    $held = [IO.File]::Open((Join-Path $ws 'inbox\b note open elsewhere.md'), 'Open', 'Read', 'None')
    try { $run = Invoke-Register $ws apply -Today 2026-03-02 } finally { $held.Close() }

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "The note 'b note open elsewhere\.md' could not be filed, so nothing was written" 'output'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
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

Test 'a source that the connections do not declare is refused, whether read or not covered' {
    $ws = New-TestWorkspace
    Set-Proposal $ws (New-CollectProposal @{
            sources_read        = @(@{ source = 'email'; cutoff = '2026-03-02T08:12:00+01:00'; items = 14 })
            sources_not_covered = @('tracker', 'chat')
        })

    Assert-Refused $ws @(
        "source 'email' is not declared in connections\.json, which declares: notes, mail, tracker",
        "source 'chat' is not declared in connections\.json, which declares: notes, mail, tracker"
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

Test 'the unclassified items of a proposal are added to the unclassified list, each with its source and the date it was collected; earlier items stay' {
    $ws = New-TestWorkspace
    Set-Proposal $ws (New-CollectProposal @{
            unclassified = @(
                @{ source = 'mail from the tech lead, 2026-02-27'; text = 'Asks who owns the branch kiosk pilot.' },
                @{ source = 'tracker ticket KSK-12'; text = "The kiosk vendor contract`r`n  is up for renewal in June." }
            )
        })
    $first = Invoke-Register $ws apply -Today 2026-03-02
    Set-Proposal $ws (New-CollectProposal @{
            collected_at = '2026-03-03T23:30:00-05:00'
            unclassified = @(@{ source = 'mail from the sponsor, 2026-03-03'; text = 'Mentions a possible merger of two branches.' })
        })

    $run = Invoke-Register $ws apply -Today 2026-03-04

    Assert-Equal 0 $first.ExitCode "exit code of the first apply, with output: $($first.Output)"
    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $items = @(Get-Content -LiteralPath (Join-Path $ws 'state\unclassified.md') -Encoding UTF8 | Where-Object { $_ })
    Assert-Equal 3 $items.Count 'items of the unclassified list'
    Assert-Equal '- 2026-03-02 | mail from the tech lead, 2026-02-27 | Asks who owns the branch kiosk pilot.' $items[0] 'first item'
    Assert-Equal '- 2026-03-02 | tracker ticket KSK-12 | The kiosk vendor contract is up for renewal in June.' $items[1] 'second item'
    Assert-Equal '- 2026-03-03 | mail from the sponsor, 2026-03-03 | Mentions a possible merger of two branches.' $items[2] 'third item'
}

Test 'an unclassified list the PO edited by hand keeps its content as it is, and the new items start on their own line' {
    $ws = New-TestWorkspace
    $edited = "Sorted on Monday.`r`n- 2026-02-27 | call with the sponsor | Asks about the kiosks."
    [IO.File]::WriteAllText((Join-Path $ws 'state\unclassified.md'), $edited, $Utf8)
    Set-Proposal $ws (New-CollectProposal @{
            unclassified = @(@{ source = 'mail from the tech lead, 2026-02-27'; text = 'Asks who owns the branch kiosk pilot.' })
        })

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $expected = $edited + "`r`n- 2026-03-02 | mail from the tech lead, 2026-02-27 | Asks who owns the branch kiosk pilot.`r`n"
    Assert-Equal $expected ([IO.File]::ReadAllText((Join-Path $ws 'state\unclassified.md'))) 'unclassified list'
}

Test 'a proposal with no operation but with notes, cutoffs or unclassified items is valid and is settled the same way' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'steering committee.md'
    Set-Proposal $ws (New-CollectProposal @{
            notes_processed = @('steering committee.md')
            unclassified    = @(@{ source = 'inbox note steering committee.md'; text = 'Mentions a possible merger of two branches.' })
        })

    $preview = Invoke-Register $ws preview
    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $preview.ExitCode "exit code of preview, with output: $($preview.Output)"
    Assert-Equal 0 $run.ExitCode "exit code of apply, with output: $($run.Output)"
    Assert-True (Test-Path -LiteralPath (Join-Path $ws 'inbox\done\2026-03\steering committee.md')) 'the note is not filed'
    Assert-Equal 14 (Read-Json (Join-Path $ws 'state\last-collect.json')).sources.mail.items 'items read from the mail'
    Assert-Match ([IO.File]::ReadAllText((Join-Path $ws 'state\unclassified.md'))) 'a possible merger of two branches' 'unclassified list'
    Assert-Equal 0 @(Get-ChildItem (Join-Path $ws 'register') -Recurse -File -Filter *.json).Count 'records written'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
}

Test 'a proposal with no operation and no collect to settle is refused, and so is a selection of lines it does not have' {
    $ws = New-TestWorkspace
    foreach ($empty in @{ operations = @() }, @{ collected_at = ' ' }) {
        Set-Proposal $ws $empty
        Assert-Refused $ws @('The proposal holds no operation and settles no collect')
    }

    Set-Proposal $ws (New-CollectProposal)
    $before = Get-WorkspaceSnapshot $ws
    $run = Invoke-Register $ws apply 1
    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "- '1' is not a line of the proposal, which has no line\." 'reason'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'the records, the filed notes, the collect state and the unclassified list of one apply are committed together' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'steering committee.md'
    git -C $ws add -A inbox
    git -C $ws commit -q -m 'A note saved before it was read'
    Add-InboxNote $ws 'call with the sponsor.txt'
    Set-Proposal $ws (New-CollectProposal @{
            notes_processed = @('steering committee.md', 'call with the sponsor.txt')
            unclassified    = @(@{ source = 'inbox note call with the sponsor.txt'; text = 'Mentions a possible merger of two branches.' })
            operations      = @(New-SubjectOperation)
        })
    $head = git -C $ws rev-parse HEAD

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal $head (git -C $ws rev-parse HEAD~1) 'the commit before the last one'
    $committed = @(git -C $ws show --name-only --format= HEAD)
    foreach ($path in 'register/subjects/mobile-onboarding.json', 'inbox/done/2026-03/steering committee.md',
        'inbox/done/2026-03/call with the sponsor.txt', 'state/last-collect.json', 'state/unclassified.md') {
        Assert-True ($committed -contains $path) "the last commit lacks $path; it holds: $($committed -join ', ')"
    }
    Assert-True ($committed -notcontains 'state/proposal.json') 'the proposal was committed'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
}

Test 'preview shows, under the operations table, the notes that will be filed, the sources read with their counts, the sources not covered and the unclassified items' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'steering committee.md'
    Set-Proposal $ws (New-CollectProposal @{
            notes_processed = @('steering committee.md')
            unclassified    = @(@{ source = 'mail from the tech lead, 2026-02-27'; text = "Asks who owns`r`nthe branch kiosk pilot." })
            operations      = @(New-SubjectOperation)
        })
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws preview

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $under = ($run.Output -split '(?m)^\| 1 .*$', 2)[1]
    Assert-Match $under 'Collect of 2026-03-02T08:30:00\+01:00' 'under the table'
    Assert-Match $under 'Notes to file:\s*\n- steering committee\.md' 'under the table'
    Assert-Match $under 'Sources read:\s*\n- notes: 2 item\(s\), up to 2026-03-02T08:30:00\+01:00\s*\n- mail: 14 item\(s\), up to 2026-03-02T08:12:00\+01:00' 'under the table'
    Assert-Match $under 'Sources not covered:\s*\n- tracker' 'under the table'
    Assert-Match $under 'Unclassified items:\s*\n- mail from the tech lead, 2026-02-27 \| Asks who owns the branch kiosk pilot\.' 'under the table'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'a collect that filed no note, read no source and held nothing unclassified is previewed as such and settled' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ collected_at = '2026-03-02T08:30:00+01:00' }

    $preview = Invoke-Register $ws preview
    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $preview.ExitCode "exit code of preview, with output: $($preview.Output)"
    foreach ($part in 'Notes to file', 'Sources read', 'Sources not covered', 'Unclassified items') {
        Assert-Match $preview.Output "${part}: none" 'output of preview'
    }
    Assert-Equal 0 $run.ExitCode "exit code of apply, with output: $($run.Output)"
    Assert-Equal '2026-03-02T08:30:00+01:00' (Read-Json (Join-Path $ws 'state\last-collect.json')).collected_at 'time of the collect'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
}

Test 'a collect with accents is previewed and settled with its accents intact, in files written as UTF-8 without a byte order mark' {
    $ws = New-TestWorkspace
    $proposed = Read-Json (Join-Path $Fixtures 'collect.proposal.json')
    $note = $proposed.notes_processed[0]
    Add-InboxNote $ws $note
    Set-Proposal $ws 'collect.proposal.json'

    $preview = Invoke-Register $ws preview
    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $preview.Output ([regex]::Escape("- $note")) 'note shown by preview'
    Assert-Match $preview.Output ([regex]::Escape("- $($proposed.unclassified[0].source) | $($proposed.unclassified[0].text)")) 'unclassified item shown by preview'
    Assert-True (Test-Path -LiteralPath (Join-Path $ws "inbox\done\2026-03\$note")) 'the note is not filed'
    $strictUtf8 = New-Object System.Text.UTF8Encoding $false, $true
    foreach ($file in 'state\unclassified.md', 'state\last-collect.json') {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $ws $file))
        Assert-True (-not ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) "$file starts with a byte order mark"
        $text = $strictUtf8.GetString($bytes)
    }
    $list = $strictUtf8.GetString([IO.File]::ReadAllBytes((Join-Path $ws 'state\unclassified.md')))
    Assert-Equal "- 2026-03-02 | $($proposed.unclassified[0].source) | $($proposed.unclassified[0].text)" $list.Trim() 'unclassified list'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
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
