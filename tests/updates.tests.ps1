# A correction keeps its history, and a new record supersedes an old one.

function New-TestWorkspaceWithRecords {
    # A workspace whose register holds, recorded on 2026-03-03, the subject mobile-onboarding and,
    # attached to it, the commitment C-2026-001, the decision D-2026-001 and the risk R-2026-001.
    $workspace = New-TestWorkspace
    Set-Proposal $workspace @{ operations = @(
            (New-SubjectOperation),
            (New-RecordOperation commitment @{ title = 'Present the onboarding pilot to the retail steering committee'; subject = 'line 1'; due_date = '2026-03-20' }),
            (New-RecordOperation decision @{ title = 'Open the pilot to ten branches'; subject = 'line 1'; status = 'taken'; decided_by = 'the sponsor' }),
            (New-RecordOperation risk @{ title = 'The pilot branches are not staffed'; subject = 'line 1' })
        )
    }
    $run = Invoke-Register $workspace apply -Today 2026-03-03
    Assert-Equal 0 $run.ExitCode "exit code when recording the records, with output: $($run.Output)"
    $workspace
}

function Get-RecordFiles([string]$Workspace) {
    # The record files of the register, as paths from the workspace.
    @(Get-ChildItem (Join-Path $Workspace 'register') -Recurse -File -Filter *.json | ForEach-Object { $_.FullName.Substring($Workspace.Length + 1) } | Sort-Object)
}

Test 'an update changes the named fields of one record, adds a history entry for each and moves the date updated' {
    $ws = New-TestWorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(New-UpdateOperation 'C-2026-001' @{ due_date = '2026-04-10'; owner = 'the tech lead' }) }

    $run = Invoke-Register $ws apply -Today 2026-03-10

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $record = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    Assert-Equal '2026-04-10' $record.due_date 'due date'
    Assert-Equal 'the tech lead' $record.owner 'owner'
    Assert-Equal '2026-03-10' $record.date_updated 'date updated'
    Assert-Equal 'C-2026-001 commitment 2026-03-03 open' "$($record.id) $($record.type) $($record.date_recorded) $($record.status)" 'what the update does not name'
    Assert-Equal 'Present the onboarding pilot to the retail steering committee' $record.title 'title'

    Assert-Equal 2 @($record.history).Count 'history entries'
    $dueDate = $record.history | Where-Object { $_.field -eq 'due_date' }
    Assert-Equal '2026-03-10 2026-03-20 2026-04-10' "$($dueDate.date) $($dueDate.previous) $($dueDate.new)" 'date, previous and new value of the due date'
    Assert-Equal 'inbox/call-with-the-tech-lead.md 2026-03-10' "$($dueDate.source.where) $($dueDate.source.read_on)" 'source of the change of due date'
    $owner = $record.history | Where-Object { $_.field -eq 'owner' }
    Assert-True ($owner.date -eq '2026-03-10' -and $null -eq $owner.previous -and $owner.new -eq 'the tech lead') "history of the owner: $($owner | ConvertTo-Json -Compress)"
    Assert-Equal 'inbox/call-with-the-tech-lead.md' $owner.source.where 'source of the change of owner'

    $decision = Read-Json (Join-Path $ws 'register\decisions\2026\D-2026-001.json')
    Assert-True ($decision.date_updated -eq '2026-03-03' -and @($decision.history).Count -eq 0) 'a record the update does not name was changed'
    # The commit also holds the portfolio view, regenerated at every apply.
    $committed = @(git -C $ws show --name-only --format= HEAD -- register)
    Assert-Equal 'register/commitments/2026/C-2026-001.json' ($committed -join ' ') 'records of the last commit'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending'
}

Test 'an update naming a missing record, an unknown field or a value outside the allowed ones makes the whole proposal refused' {
    $ws = New-TestWorkspaceWithRecords
    $noRecord = New-UpdateOperation 'C-2026-001' @{ owner = 'the tech lead' }
    $noRecord.Remove('id')
    Set-Proposal $ws @{ operations = @(
            (New-UpdateOperation 'C-2026-001' @{ owner = 'the tech lead' }),
            (New-UpdateOperation 'C-2026-002' @{ owner = 'the tech lead' }),
            (New-UpdateOperation 'C-2025-001' @{ owner = 'the tech lead' }),
            (New-UpdateOperation 'c-2026-001' @{ owner = 'the tech lead' }),
            (New-UpdateOperation '..\..\settings' @{ owner = 'the tech lead' }),
            $noRecord,
            (New-UpdateOperation 'mobile-onboarding' @{ colour = 'blue' }),
            (New-UpdateOperation 'mobile-onboarding' @{ due_date = '2026-04-10' }),
            (New-UpdateOperation 'C-2026-001' @{ status = 'closed' }),
            (New-UpdateOperation 'R-2026-001' @{ severity = 'high' }),
            (New-UpdateOperation 'D-2026-001' @{ needed_by = 'end of March' }),
            (New-UpdateOperation 'D-2026-001' @{ title = $null }),
            (New-UpdateOperation 'R-2026-001' @{ source = @{ where = 'inbox/steering-notes.md' } })
        )
    }

    Assert-Refused $ws @(
        "Line 2: record 'C-2026-002' does not exist in the register",
        "Line 3: record 'C-2025-001' does not exist in the register",
        "Line 4: record 'c-2026-001' does not exist in the register",
        "Line 5: record '\.\.\\\.\.\\settings' does not exist in the register",
        "Line 6: record '' does not exist in the register",
        "Line 7: unknown field 'colour'",
        "Line 8: unknown field 'due_date'",
        "Line 9: field 'status' is 'closed'; allowed: open, done, dropped, superseded",
        "Line 10: field 'severity' is 'high'; allowed: urgent, watch",
        "Line 11: field 'needed_by' must be an ISO date \(yyyy-mm-dd\), not 'end of March'",
        "Line 12: missing required field 'title'",
        "Line 13: missing required field 'source.read_on'"
    )
}

Test 'an update cannot change the identifier, the type or the history of a record, nor its other fields set by the register tool' {
    $ws = New-TestWorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(
            (New-UpdateOperation 'C-2026-001' @{ id = 'C-2026-009' }),
            (New-UpdateOperation 'C-2026-001' @{ type = 'decision' }),
            (New-UpdateOperation 'C-2026-001' @{ history = @() }),
            (New-UpdateOperation 'mobile-onboarding' @{ id = 'mobile-onboarding-v2'; date_recorded = '2020-01-01'; date_updated = '2020-01-01'; superseded_by = 'C-2026-001' })
        )
    }

    Assert-Refused $ws @(
        "Line 1: field 'id' is set by the register tool",
        "Line 2: field 'type' is set by the register tool",
        "Line 3: field 'history' is set by the register tool",
        "Line 4: field 'id' is set by the register tool",
        "Line 4: field 'date_recorded' is set by the register tool",
        "Line 4: field 'date_updated' is set by the register tool",
        "Line 4: field 'superseded_by' is set by the register tool"
    )
}

Test 'an update that does not state its source, changes nothing or attaches a record to a missing subject is refused' {
    $ws = New-TestWorkspaceWithRecords
    $noSource = New-UpdateOperation 'C-2026-001' @{ owner = 'the tech lead' }
    $noSource.Remove('source')
    $halfSource = New-UpdateOperation 'C-2026-001' @{ owner = 'the tech lead' }
    $halfSource.source = @{ where = 'inbox/call-with-the-tech-lead.md' }
    $noFields = New-UpdateOperation 'C-2026-001' @{}
    $noFields.Remove('fields')
    Set-Proposal $ws @{ operations = @(
            $noSource,
            $halfSource,
            $noFields,
            (New-UpdateOperation 'C-2026-001' @{}),
            (New-UpdateOperation 'C-2026-001' @{ due_date = '2026-03-20'; status = 'open'; owner = $null; objectives = @() }),
            (New-UpdateOperation 'R-2026-001' @{ subject = 'branch-network' }),
            (New-UpdateOperation 'R-2026-001' @{ subject = 'C-2026-001' })
        )
    }

    Assert-Refused $ws @(
        "Line 1: missing required field 'source'",
        "Line 2: missing required field 'source.read_on'",
        "Line 3: the operation gives no fields",
        "Line 4: the update changes nothing",
        "Line 5: the update changes nothing",
        "Line 6: subject 'branch-network' does not exist in the register",
        "Line 7: subject 'C-2026-001' does not exist in the register"
    )
}

Test 'a later correction adds to the history, and a field given with the value the record already holds adds no entry' {
    $ws = New-TestWorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(New-UpdateOperation 'mobile-onboarding' @{ horizon = 'next'; kind = 'product'; watch_list = @{ people = @('the tech lead') } }) }
    $first = Invoke-Register $ws apply -Today 2026-03-10
    Set-Proposal $ws @{ operations = @(New-UpdateOperation 'mobile-onboarding' @{ horizon = 'later'; watch_list = @{ people = @('the tech lead') } }) }

    $run = Invoke-Register $ws apply -Today 2026-03-12

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $record = Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')
    Assert-Equal 'later product 2026-03-12' "$($record.horizon) $($record.kind) $($record.date_updated)" 'horizon, kind and date updated'
    Assert-True ($record.watch_list.people -is [array] -and $record.watch_list.keywords -is [array]) 'the lists of the watch list are no longer lists'
    Assert-Equal 'the tech lead' ($record.watch_list.people -join ', ') 'people watched'

    $entries = @($record.history | ForEach-Object { "$($_.date) $($_.field)" } | Sort-Object)
    Assert-Equal '2026-03-10 horizon, 2026-03-10 watch_list, 2026-03-12 horizon' ($entries -join ', ') 'history entries'
    Assert-Equal '2026-03-12' $record.history[2].date 'the latest entry is not the last of the history'
    Assert-Equal 'next later' "$($record.history[2].previous) $($record.history[2].new)" 'previous and new value of the later correction'
    $watchList = $record.history | Where-Object { $_.field -eq 'watch_list' }
    Assert-Equal 0 @($watchList.previous.people).Count 'people watched before the correction'
    Assert-Equal 'the tech lead' ($watchList.new.people -join ', ') 'people watched after the correction'
}

Test 'a correction leaves every field it does not name as it was, accents and lists of one item included' {
    $ws = New-TestWorkspace
    Set-Proposal $ws 'create-subject.proposal.json'
    $first = Invoke-Register $ws apply -Today 2026-03-02
    $path = Join-Path $ws 'register\subjects\refonte-de-l-entree-en-relation.json'
    $before = Read-Json $path
    Set-Proposal $ws @{ operations = @(New-UpdateOperation 'refonte-de-l-entree-en-relation' @{ horizon = 'later' }) }

    $run = Invoke-Register $ws apply -Today 2026-03-10

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $bytes = [IO.File]::ReadAllBytes($path)
    Assert-True (-not ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) 'the record starts with a byte order mark'
    $after = (New-Object System.Text.UTF8Encoding $false, $true).GetString($bytes) | ConvertFrom-Json
    Assert-Equal 'later 2026-03-10 1' "$($after.horizon) $($after.date_updated) $(@($after.history).Count)" 'horizon, date updated and history entries'
    Assert-Equal (($before.PSObject.Properties | ForEach-Object { $_.Name }) -join ' ') (($after.PSObject.Properties | ForEach-Object { $_.Name }) -join ' ') 'fields of the record, in order'
    foreach ($field in $before.PSObject.Properties | Where-Object { 'horizon', 'date_updated', 'history' -notcontains $_.Name }) {
        Assert-Equal (ConvertTo-Json -InputObject $field.Value -Depth 20 -Compress) (ConvertTo-Json -InputObject $after.($field.Name) -Depth 20 -Compress) $field.Name
    }
}

Test 'a created record that names the record it supersedes marks it superseded and links the two, and both are kept' {
    $ws = New-TestWorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(New-RecordOperation commitment @{
                title      = 'Present the onboarding pilot to the retail steering committee of April'
                due_date   = '2026-04-17'
                supersedes = 'C-2026-001'
                source     = @{ where = 'inbox/steering-notes-of-march.md'; read_on = '2026-03-10' }
            })
    }

    $run = Invoke-Register $ws apply -Today 2026-03-10

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'register\commitments\2026\C-2026-001.json register\commitments\2026\C-2026-002.json register\decisions\2026\D-2026-001.json register\risks\R-2026-001.json register\subjects\mobile-onboarding.json' ((Get-RecordFiles $ws) -join ' ') 'record files'
    $old = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    $new = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-002.json')
    Assert-Equal 'superseded C-2026-002' "$($old.status) $($old.superseded_by)" 'status of the old record and the record it points to'
    Assert-Equal 'open C-2026-001' "$($new.status) $($new.supersedes)" 'status of the new record and the record it points to'
    Assert-True ($null -eq $new.superseded_by -and $null -eq $old.supersedes) 'a link was recorded the wrong way round'
    Assert-Equal '2026-03-10 2026-03-03' "$($old.date_updated) $($old.date_recorded)" 'date updated and date recorded of the old record'
    Assert-Equal 'Present the onboarding pilot to the retail steering committee 2026-03-20' "$($old.title) $($old.due_date)" 'what the old record said'

    Assert-Equal 2 @($old.history).Count 'history entries of the old record'
    $status = $old.history | Where-Object { $_.field -eq 'status' }
    Assert-Equal '2026-03-10 open superseded' "$($status.date) $($status.previous) $($status.new)" 'history of the status'
    Assert-Equal 'inbox/steering-notes-of-march.md 2026-03-10' "$($status.source.where) $($status.source.read_on)" 'source of the change'
    $link = $old.history | Where-Object { $_.field -eq 'superseded_by' }
    Assert-True ($null -eq $link.previous -and $link.new -eq 'C-2026-002') "history of the link: $($link | ConvertTo-Json -Compress)"
    Assert-Equal 0 @($new.history).Count 'history entries of the new record'

    $committed = @(git -C $ws show --name-only --format= HEAD -- register | Sort-Object)
    Assert-Equal 'register/commitments/2026/C-2026-001.json register/commitments/2026/C-2026-002.json' ($committed -join ' ') 'records of the last commit'
    Assert-Match $run.Output '(?m)^- create commitment C-2026-002, which supersedes C-2026-001$' 'output'
}

Test 'a decision can supersede a commitment, after a correction of that commitment in the same proposal' {
    $ws = New-TestWorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(
            (New-UpdateOperation 'C-2026-001' @{ owner = 'the PO' }),
            (New-RecordOperation decision @{ title = 'Suspend the presentation of the pilot'; status = 'taken'; decided_by = 'the sponsor'; supersedes = 'C-2026-001' })
        )
    }

    $run = Invoke-Register $ws apply -Today 2026-03-10

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $commitment = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    $decision = Read-Json (Join-Path $ws 'register\decisions\2026\D-2026-002.json')
    Assert-Equal 'superseded D-2026-002 the PO' "$($commitment.status) $($commitment.superseded_by) $($commitment.owner)" 'the commitment'
    Assert-Equal 'taken C-2026-001' "$($decision.status) $($decision.supersedes)" 'the decision'
    Assert-Equal 'owner status superseded_by' (($commitment.history | ForEach-Object { $_.field }) -join ' ') 'history of the commitment'
}

Test 'naming a missing record, an already superseded record or a subject as the record to supersede makes the whole proposal refused' {
    $ws = New-TestWorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(New-RecordOperation commitment @{ supersedes = 'C-2026-001' }) }
    $first = Invoke-Register $ws apply -Today 2026-03-10
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ supersedes = 'C-2026-009' }),
            (New-RecordOperation decision @{ supersedes = 'C-2026-001' }),
            (New-RecordOperation risk @{ supersedes = 'mobile-onboarding' }),
            (New-RecordOperation decision @{ supersedes = 'R-2026-001' }),
            (New-RecordOperation risk @{ supersedes = 'R-2026-001' }),
            (New-RecordOperation commitment @{ supersedes = 'line 4' }),
            (New-SubjectOperation @{ title = 'Branch network'; supersedes = 'D-2026-001' }),
            (New-RecordOperation commitment @{ supersedes = 5 })
        )
    }

    Assert-Refused $ws @(
        "Line 1: record 'C-2026-009' to supersede does not exist in the register",
        "Line 2: record 'C-2026-001' is already superseded by 'C-2026-002'",
        "Line 3: 'mobile-onboarding' is a subject: a subject is closed, not superseded",
        "Line 5: record 'R-2026-001' is already superseded by line 4",
        "Line 6: record 'line 4' to supersede does not exist in the register",
        "Line 7: a subject supersedes no record",
        "Line 8: field 'supersedes' must be text, not '5'"
    )
}

Test 'only the register tool marks a record as superseded: a proposal cannot give that status, update a superseded record or change what a record supersedes' {
    $ws = New-TestWorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(New-RecordOperation commitment @{ supersedes = 'C-2026-001' }) }
    $first = Invoke-Register $ws apply -Today 2026-03-10
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ status = 'superseded' }),
            (New-RecordOperation decision @{ status = 'superseded' }),
            (New-RecordOperation risk @{ status = 'superseded' }),
            (New-UpdateOperation 'C-2026-002' @{ status = 'superseded' }),
            (New-UpdateOperation 'C-2026-001' @{ status = 'open' }),
            (New-UpdateOperation 'C-2026-001' @{ owner = 'the tech lead' }),
            (New-UpdateOperation 'D-2026-001' @{ supersedes = 'R-2026-001' }),
            (New-UpdateOperation 'C-2026-002' @{ supersedes = $null; owner = 'the tech lead' }),
            (New-RecordOperation decision @{ supersedes = 'R-2026-001' }),
            (New-UpdateOperation 'R-2026-001' @{ severity = 'urgent' }),
            (New-SubjectOperation @{ status = 'superseded' })
        )
    }

    Assert-Refused $ws @(
        "Line 1: the status 'superseded' is set by the register tool",
        "Line 2: the status 'superseded' is set by the register tool",
        "Line 3: the status 'superseded' is set by the register tool",
        "Line 4: the status 'superseded' is set by the register tool",
        "Line 5: record 'C-2026-001' is superseded by 'C-2026-002': it is no longer updated",
        "Line 6: record 'C-2026-001' is superseded by 'C-2026-002': it is no longer updated",
        "Line 7: field 'supersedes' is given when a record is created: an update cannot change it",
        "Line 8: field 'supersedes' is given when a record is created: an update cannot change it",
        "Line 10: record 'R-2026-001' is superseded by line 9: it is no longer updated",
        "Line 11: field 'status' is 'superseded'; allowed: active, closed"
    )
}

Test 'a subject is closed by an update: its record and the records attached to it remain' {
    $ws = New-TestWorkspaceWithRecords
    $before = Get-RecordFiles $ws
    Set-Proposal $ws @{ operations = @(New-UpdateOperation 'mobile-onboarding' @{ status = 'closed' }) }

    $run = Invoke-Register $ws apply -Today 2026-03-10

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $subject = Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')
    Assert-Equal 'closed 2026-03-10 Mobile onboarding now' "$($subject.status) $($subject.date_updated) $($subject.title) $($subject.horizon)" 'the subject'
    Assert-Equal 'status active closed' "$($subject.history[0].field) $($subject.history[0].previous) $($subject.history[0].new)" 'history of the subject'
    Assert-Equal ($before -join ' ') ((Get-RecordFiles $ws) -join ' ') 'record files'
    foreach ($attached in 'commitments\2026\C-2026-001', 'decisions\2026\D-2026-001', 'risks\R-2026-001') {
        $record = Read-Json (Join-Path $ws "register\$attached.json")
        Assert-Equal 'mobile-onboarding 2026-03-03 0' "$($record.subject) $($record.date_updated) $(@($record.history).Count)" "subject, date updated and history entries of $attached"
    }
}

Test 'a selection applies the corrections and the superseding it keeps, and leaves the record of each dropped line as it was' {
    $ws = New-TestWorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(
            (New-UpdateOperation 'C-2026-001' @{ owner = 'the PO' }),
            (New-UpdateOperation 'R-2026-001' @{ severity = 'urgent' }),
            (New-RecordOperation decision @{ title = 'Open the pilot to twenty branches'; status = 'taken'; supersedes = 'D-2026-001' }),
            (New-RecordOperation commitment @{ title = 'Present the onboarding pilot to the retail steering committee of April'; supersedes = 'C-2026-001' }),
            (New-UpdateOperation 'mobile-onboarding' @{ horizon = 'next' })
        )
    }
    $untouched = 'register\risks\R-2026-001.json', 'register\decisions\2026\D-2026-001.json'
    $before = $untouched | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $ws $_)).Hash }

    $run = Invoke-Register $ws apply 1 4 5 -Today 2026-03-10

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'register\commitments\2026\C-2026-001.json register\commitments\2026\C-2026-002.json register\decisions\2026\D-2026-001.json register\risks\R-2026-001.json register\subjects\mobile-onboarding.json' ((Get-RecordFiles $ws) -join ' ') 'record files'
    $commitment = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    Assert-Equal 'the PO superseded C-2026-002' "$($commitment.owner) $($commitment.status) $($commitment.superseded_by)" 'the commitment, corrected then superseded'
    Assert-Equal 'owner status superseded_by' (($commitment.history | ForEach-Object { $_.field }) -join ' ') 'history of the commitment'
    Assert-Equal 'C-2026-001' (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-002.json')).supersedes 'record that the new commitment supersedes'
    Assert-Equal 'next' (Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')).horizon 'horizon of the subject'
    Assert-Equal ($before -join ' ') (($untouched | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $ws $_)).Hash }) -join ' ') 'records of the dropped lines'

    $committed = @(git -C $ws show --name-only --format= HEAD -- register | Sort-Object)
    Assert-Equal 'register/commitments/2026/C-2026-001.json register/commitments/2026/C-2026-002.json register/subjects/mobile-onboarding.json' ($committed -join ' ') 'records of the last commit'
    Assert-Match $run.Output 'Dropped: line 2, 3\.' 'output'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending'
}

Test 'corrections of one record kept by a selection are applied in the order of the proposal, and a dropped one leaves no trace in the history' {
    $ws = New-TestWorkspaceWithRecords
    Set-Proposal $ws @{ operations = @(
            (New-UpdateOperation 'C-2026-001' @{ due_date = '2026-04-10' }),
            (New-UpdateOperation 'C-2026-001' @{ due_date = '2026-04-24' }),
            (New-UpdateOperation 'C-2026-001' @{ due_date = '2026-05-04' })
        )
    }

    $run = Invoke-Register $ws apply '3,1' -Today 2026-03-10

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $record = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    Assert-Equal '2026-05-04' $record.due_date 'due date'
    Assert-Equal '2026-03-20 -> 2026-04-10, 2026-04-10 -> 2026-05-04' (($record.history | ForEach-Object { "$($_.previous) -> $($_.new)" }) -join ', ') 'history of the due date'
}

Test 'preview shows, for an update, each field that changes with its current and proposed values and, for a superseding record, the record that will be superseded' {
    $ws = New-TestWorkspaceWithRecords
    $update = New-UpdateOperation 'C-2026-001' @{ due_date = '2026-04-10'; owner = 'the tech lead'; status = 'open' }
    $update.interpreted = $true
    Set-Proposal $ws @{ operations = @(
            $update,
            (New-RecordOperation decision @{ title = 'Suspend the presentation of the pilot'; status = 'taken'; supersedes = 'C-2026-001' }),
            (New-UpdateOperation 'mobile-onboarding' @{ status = 'closed'; watch_list = @{ people = @('the tech lead', 'the sponsor') } })
        )
    }
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws preview

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $lines = @($run.Output -split "`n")
    $first = $lines | Where-Object { $_ -match '^\|\s*1\s*\|' }
    Assert-Match $first '^\|\s*1\s*\|\s*update\s*\|\s*commitment\s*\|\s*Present the onboarding pilot to the retail steering committee\s*\|\s*mobile-onboarding\s*\|\s*fact\s*\|\s*yes\s*\|\s*record: C-2026-001; ' 'line 1'
    Assert-Match $first '; due_date: 2026-03-20 -> 2026-04-10[;|\s]' 'current and proposed due date'
    Assert-Match $first '; owner: \(none\) -> the tech lead[;|\s]' 'current and proposed owner'
    Assert-Match $first '; source of the change: \([^)]*where: inbox/call-with-the-tech-lead\.md[;)]' 'source of the change'
    Assert-Match $first '; source of the change: \([^)]*read_on: 2026-03-10[;)]' 'date the source of the change was read'
    Assert-True ($first -notmatch 'status') "line 1 shows a field that does not change: $first"
    $second = $lines | Where-Object { $_ -match '^\|\s*2\s*\|' }
    Assert-Match $second '^\|\s*2\s*\|\s*create\s*\|\s*decision\s*\|\s*Suspend the presentation of the pilot\s*\|\s*mobile-onboarding\s*\|\s*fact\s*\|\s*no\s*\|\s*supersedes: C-2026-001 \(commitment: Present the onboarding pilot to the retail steering committee\); ' 'line 2'
    Assert-Equal 1 ([regex]::Matches($second, 'supersedes')).Count 'times line 2 says what it supersedes'
    $third = $lines | Where-Object { $_ -match '^\|\s*3\s*\|' }
    Assert-Match $third '^\|\s*3\s*\|\s*update\s*\|\s*subject\s*\|\s*Mobile onboarding\s*\|\s*\|\s*fact\s*\|\s*no\s*\|\s*record: mobile-onboarding; ' 'line 3'
    Assert-Match $third '; status: active -> closed[;|\s]' 'current and proposed status'
    Assert-Match $third '; watch_list: \(none\) -> \(people: the tech lead, the sponsor\)[;|\s]' 'current and proposed watch list'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'no command deletes a record: after corrections, a superseding and a closing, every record ever recorded is still in the register' {
    $ws = New-TestWorkspaceWithRecords
    $recorded = Get-RecordFiles $ws
    Set-Proposal $ws @{ operations = @(@{ op = 'delete'; id = 'C-2026-001'; interpreted = $false }) }
    Assert-Refused $ws @("Line 1: unknown operation 'delete'; allowed: create, update")

    foreach ($operations in @(
            @((New-UpdateOperation 'C-2026-001' @{ status = 'dropped' }), (New-UpdateOperation 'R-2026-001' @{ status = 'closed' })),
            @((New-RecordOperation decision @{ supersedes = 'D-2026-001' }), (New-RecordOperation commitment @{ supersedes = 'C-2026-001' })),
            @(, (New-UpdateOperation 'mobile-onboarding' @{ status = 'closed' }))
        )) {
        Set-Proposal $ws @{ operations = $operations }
        $preview = Invoke-Register $ws preview
        $run = Invoke-Register $ws apply -Today 2026-03-10
        Assert-Equal '0 0' "$($preview.ExitCode) $($run.ExitCode)" "exit codes of preview and apply, with output: $($preview.Output) $($run.Output)"
    }

    $files = Get-RecordFiles $ws
    foreach ($file in $recorded) { Assert-True ($files -contains $file) "$file is no longer in the register" }
    Assert-Equal 6 $files.Count 'record files'
    Assert-Equal '' (@(git -C $ws log --diff-filter=D --name-only --format= -- register) -join ' ') 'record files deleted by a commit'
}
