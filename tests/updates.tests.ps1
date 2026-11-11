# A correction keeps its history, and a new record supersedes an old one.

function New-UpdateOperation([string]$Id, [hashtable]$Fields) {
    # One valid operation updating a record of Example Bank: the fields to change, and the source
    # of the change.
    @{
        op = 'update'; id = $Id; interpreted = $false; fields = $Fields
        source = @{ where = 'inbox/call-with-the-tech-lead.md'; read_on = '2026-03-10' }
    }
}

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
    $committed = @(git -C $ws show --name-only --format= HEAD)
    Assert-Equal 'register/commitments/2026/C-2026-001.json' ($committed -join ' ') 'files of the last commit'
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
