# Commitments, decisions and risks are recorded against a subject.

Test 'apply writes a commitment as one record, filed under its year, whose identifier is the year and a number and equals the file name' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(New-RecordOperation commitment) }

    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $files = @(Get-ChildItem (Join-Path $ws 'register\commitments') -Recurse -File -Filter *.json)
    Assert-Equal 1 $files.Count 'commitments written'
    Assert-Equal (Join-Path $ws 'register\commitments\2026\C-2026-001.json') $files[0].FullName 'record file'
    $record = Read-Json $files[0].FullName
    Assert-Equal 'C-2026-001' $record.id 'identifier'
    Assert-Equal 'commitment' $record.type 'type'
    Assert-Equal 'mobile-onboarding' $record.subject 'subject'
    $committed = @(git -C $ws show --name-only --format= HEAD)
    Assert-True ($committed -contains 'register/commitments/2026/C-2026-001.json') "the last commit holds: $committed"
}

Test 'a commitment carries the common fields, its subject, the date of the fact, its owner, whom it is owed to and its due date' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(New-RecordOperation commitment @{
                title    = 'Send the onboarding figures'
                owner    = 'the tech lead'
                owed_to  = 'the sponsor'
                due_date = '2026-03-20'
                notes    = 'Asked for in the steering committee.'
            })
    }

    $run = Invoke-Register $ws apply -Today 2026-03-03

    $record = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    $expected = 'id', 'type', 'title', 'status', 'date_recorded', 'date_updated', 'evidence_level', 'source', 'objectives',
        'notes', 'supersedes', 'superseded_by', 'history', 'subject', 'date_of_fact', 'owner', 'owed_to', 'due_date'
    $actual = @($record.PSObject.Properties | ForEach-Object { $_.Name })
    Assert-Equal (($expected | Sort-Object) -join ' ') (($actual | Sort-Object) -join ' ') 'fields of the record'
    Assert-Equal 'Send the onboarding figures' $record.title 'title'
    Assert-Equal 'open' $record.status 'status'
    Assert-Equal '2026-03-03' $record.date_recorded 'date recorded'
    Assert-Equal '2026-03-02' $record.date_of_fact 'date of the fact'
    Assert-Equal 'fact' $record.evidence_level 'evidence level'
    Assert-Equal 'inbox/steering-notes.md' $record.source.where 'source'
    Assert-Equal '2026-03-03' $record.source.read_on 'date the source was read'
    Assert-Equal 'the tech lead' $record.owner 'owner'
    Assert-Equal 'the sponsor' $record.owed_to 'owed to'
    Assert-Equal '2026-03-20' $record.due_date 'due date'
    Assert-Equal 'Asked for in the steering committee.' $record.notes 'notes'
}

Test 'a commitment without an owner or without a due date is recorded all the same' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ due_date = '2026-03-20' }),
            (New-RecordOperation commitment @{ owner = 'the tech lead' }),
            (New-RecordOperation commitment)
        )
    }

    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $records = @('C-2026-001', 'C-2026-002', 'C-2026-003' | ForEach-Object { Read-Json (Join-Path $ws "register\commitments\2026\$_.json") })
    Assert-True ($null -eq $records[0].owner -and $records[0].due_date -eq '2026-03-20') 'the commitment without an owner'
    Assert-True ($records[1].owner -eq 'the tech lead' -and $null -eq $records[1].due_date) 'the commitment without a due date'
    Assert-True ($null -eq $records[2].owner -and $null -eq $records[2].due_date) 'the commitment with neither'
}

Test 'a decision is filed under its year and a risk in the risks folder, each with its own fields and numbering' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation decision @{ status = 'taken'; decided_by = 'the retail steering committee' }),
            (New-RecordOperation decision @{ status = 'pending'; needed_from = 'the sponsor'; needed_by = '2026-03-27' }),
            (New-RecordOperation risk @{ severity = 'urgent'; owner = 'the PO' }),
            (New-RecordOperation commitment)
        )
    }

    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $files = @(Get-ChildItem (Join-Path $ws 'register') -Recurse -File -Filter *.json | ForEach-Object { $_.FullName.Substring($ws.Length + 1) } | Sort-Object)
    Assert-Equal 'register\commitments\2026\C-2026-001.json register\decisions\2026\D-2026-001.json register\decisions\2026\D-2026-002.json register\risks\R-2026-001.json register\subjects\mobile-onboarding.json' ($files -join ' ') 'record files'

    $common = 'id', 'type', 'title', 'status', 'date_recorded', 'date_updated', 'evidence_level', 'source', 'objectives',
        'notes', 'supersedes', 'superseded_by', 'history', 'subject', 'date_of_fact'
    $taken = Read-Json (Join-Path $ws 'register\decisions\2026\D-2026-001.json')
    Assert-Equal (($common + 'decided_by', 'needed_from', 'needed_by' | Sort-Object) -join ' ') ((@($taken.PSObject.Properties | ForEach-Object { $_.Name }) | Sort-Object) -join ' ') 'fields of a decision'
    Assert-Equal 'D-2026-001 decision taken' "$($taken.id) $($taken.type) $($taken.status)" 'the decision taken'
    Assert-Equal 'the retail steering committee' $taken.decided_by 'decided by'
    $pending = Read-Json (Join-Path $ws 'register\decisions\2026\D-2026-002.json')
    Assert-Equal 'pending the sponsor 2026-03-27' "$($pending.status) $($pending.needed_from) $($pending.needed_by)" 'the decision awaited'

    $risk = Read-Json (Join-Path $ws 'register\risks\R-2026-001.json')
    Assert-Equal (($common + 'severity', 'owner' | Sort-Object) -join ' ') ((@($risk.PSObject.Properties | ForEach-Object { $_.Name }) | Sort-Object) -join ' ') 'fields of a risk'
    Assert-Equal 'R-2026-001 risk open urgent the PO' "$($risk.id) $($risk.type) $($risk.status) $($risk.severity) $($risk.owner)" 'the risk'
    Assert-Equal 'mobile-onboarding 2026-03-02' "$($risk.subject) $($risk.date_of_fact)" 'subject and date of the fact of the risk'
}

Test 'each type accepts its own statuses only, a decision must give its status and a risk its severity' {
    $ws = New-TestWorkspaceWithSubject
    $accepted = @(
        'open', 'done', 'dropped' | ForEach-Object { New-RecordOperation commitment @{ status = $_ } }
        'taken', 'pending' | ForEach-Object { New-RecordOperation decision @{ status = $_ } }
        'open', 'closed' | ForEach-Object { New-RecordOperation risk @{ status = $_ } }
        'urgent', 'watch' | ForEach-Object { New-RecordOperation risk @{ severity = $_ } }
    )
    Set-Proposal $ws @{ operations = $accepted }
    $run = Invoke-Register $ws preview
    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"

    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ status = 'closed' }),
            (New-RecordOperation decision @{ status = 'open' }),
            (New-RecordOperation decision @{ status = $null }),
            (New-RecordOperation risk @{ status = 'done' }),
            (New-RecordOperation risk @{ severity = 'high' }),
            (New-RecordOperation risk @{ severity = $null })
        )
    }
    Assert-Refused $ws @(
        "Line 1: field 'status' is 'closed'; allowed: open, done, dropped, superseded",
        "Line 2: field 'status' is 'open'; allowed: taken, pending, superseded",
        "Line 3: missing required field 'status'",
        "Line 4: field 'status' is 'done'; allowed: open, closed, superseded",
        "Line 5: field 'severity' is 'high'; allowed: urgent, watch",
        "Line 6: missing required field 'severity'"
    )
}

Test 'a record that does not state its evidence level, its source, when the source was read or the date of the fact is refused' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ evidence_level = $null }),
            (New-RecordOperation decision @{ evidence_level = 'certain' }),
            (New-RecordOperation risk @{ source = $null }),
            (New-RecordOperation commitment @{ source = @{ where = 'inbox/steering-notes.md' } }),
            (New-RecordOperation decision @{ source = @{ read_on = '2026-03-03' } }),
            (New-RecordOperation risk @{ date_of_fact = $null }),
            (New-RecordOperation commitment @{ date_of_fact = 'last Monday' })
        )
    }

    Assert-Refused $ws @(
        "Line 1: missing required field 'evidence_level'",
        "Line 2: field 'evidence_level' is 'certain'; allowed: fact, reported, hypothesis",
        "Line 3: missing required field 'source'",
        "Line 4: missing required field 'source.read_on'",
        "Line 5: missing required field 'source.where'",
        "Line 6: missing required field 'date_of_fact'",
        "Line 7: field 'date_of_fact' must be an ISO date \(yyyy-mm-dd\), not 'last Monday'"
    )
}

Test 'a record whose subject is neither in the register nor created earlier in the proposal makes the whole proposal refused' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment),
            (New-RecordOperation commitment @{ subject = 'branch-network' }),
            (New-RecordOperation decision @{ subject = 'line 5' }),
            (New-RecordOperation risk @{ subject = 'line 1' }),
            (New-SubjectOperation @{ title = 'Branch network' }),
            (New-RecordOperation risk @{ subject = 'line 6' }),
            (New-RecordOperation commitment @{ subject = 'Mobile-Onboarding' }),
            (New-RecordOperation commitment @{ subject = '..\..\settings' }),
            (New-RecordOperation decision @{ subject = $null }),
            (New-RecordOperation risk @{ subject = 5 }),
            (New-SubjectOperation @{ subject = 'branch-network' })
        )
    }

    Assert-Refused $ws @(
        "Line 2: subject 'branch-network' exists neither in the register nor earlier in this proposal",
        "Line 3: subject 'line 5' exists neither in the register nor earlier in this proposal",
        "Line 4: subject 'line 1' exists neither in the register nor earlier in this proposal",
        "Line 6: subject 'line 6' exists neither in the register nor earlier in this proposal",
        "Line 7: subject 'Mobile-Onboarding' exists neither in the register nor earlier in this proposal",
        "Line 8: subject '\.\.\\\.\.\\settings' exists neither in the register nor earlier in this proposal",
        "Line 9: missing required field 'subject'",
        "Line 10: field 'subject' must be text, not '5'",
        "Line 11: unknown field 'subject'"
    )
}

Test 'a record named after an earlier line is attached to the subject that line creates, whatever identifier it receives' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation),
            (New-SubjectOperation @{ title = 'Branch appointment booking' }),
            (New-RecordOperation commitment @{ subject = 'line 1' }),
            (New-RecordOperation decision @{ subject = 'line 2' }),
            (New-RecordOperation risk @{ subject = 'mobile-onboarding' })
        )
    }

    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-True (Test-Path (Join-Path $ws 'register\subjects\mobile-onboarding-2.json')) 'the second subject of the same title was not recorded'
    Assert-Equal 'mobile-onboarding-2' (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')).subject 'subject of the commitment'
    Assert-Equal 'branch-appointment-booking' (Read-Json (Join-Path $ws 'register\decisions\2026\D-2026-001.json')).subject 'subject of the decision'
    Assert-Equal 'mobile-onboarding' (Read-Json (Join-Path $ws 'register\risks\R-2026-001.json')).subject 'subject of the risk'
}

Test 'an objective is accepted only when its number exists in the workspace settings' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(New-RecordOperation commitment @{ objectives = @(1) }) }
    Assert-Refused $ws @("Line 1: field 'objectives' is '1'; settings.json lists under 'objectives.number': nothing")

    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.objectives = @(
        @{ number = 1; title = 'Halve the time to open an account' },
        @{ number = 3; title = 'Bring the branch network on board' }
    )
    Write-Json (Join-Path $ws 'settings.json') $settings
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ objectives = @(1, 3) }),
            (New-RecordOperation decision @{ objectives = @(2) }),
            (New-RecordOperation risk @{ objectives = @(3, 4) }),
            (New-SubjectOperation @{ objectives = @(5) }),
            (New-RecordOperation risk @{ objectives = @('1') })
        )
    }
    Assert-Refused $ws @(
        "Line 2: field 'objectives' is '2'; settings.json lists under 'objectives.number': 1, 3",
        "Line 3: field 'objectives' is '4'; settings.json lists under 'objectives.number': 1, 3",
        "Line 4: field 'objectives' is '5'; settings.json lists under 'objectives.number': 1, 3",
        "Line 5: field 'objectives' must be a whole number, not '1'"
    )

    Set-Proposal $ws @{ operations = @((New-RecordOperation commitment @{ objectives = @(1, 3) }), (New-RecordOperation risk @{ objectives = @(3) })) }
    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal '1, 3' ((Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')).objectives -join ', ') 'objectives of the commitment'
    $objectives = (Read-Json (Join-Path $ws 'register\risks\R-2026-001.json')).objectives
    Assert-True ($objectives -is [array] -and $objectives.Count -eq 1 -and $objectives[0] -eq 3) 'the single objective of the risk is no longer a list of one number'
}

Test 'every operation must say whether it is interpreted or a plain fact' {
    $ws = New-TestWorkspaceWithSubject
    $operations = @((New-SubjectOperation @{ title = 'Branch network' }), (New-RecordOperation commitment), (New-RecordOperation decision), (New-RecordOperation risk))
    $operations[0].Remove('interpreted')
    $operations[1].interpreted = 'yes'
    $operations[2].interpreted = $true
    Set-Proposal $ws @{ operations = $operations }

    Assert-Refused $ws @(
        'Line 1: the operation must state "interpreted": true when it is interpreted, false when it is a plain fact',
        'Line 2: the operation must state "interpreted": true when it is interpreted, false when it is a plain fact'
    )
}

Test 'preview shows on each line the type, the title, the subject, the evidence level and whether the operation is interpreted' {
    $ws = New-TestWorkspaceWithSubject
    $operations = @(
        (New-SubjectOperation @{ title = 'Branch network' }),
        (New-RecordOperation commitment @{ title = 'Send the list of pilot branches'; subject = 'line 1'; evidence_level = 'reported'; owner = 'the tech lead' }),
        (New-RecordOperation decision @{ title = 'Postpone the pilot'; evidence_level = 'hypothesis' }),
        (New-RecordOperation risk @{ title = 'The pilot branches are not staffed' })
    )
    $operations[1].interpreted = $true
    Set-Proposal $ws @{ operations = $operations }
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws preview

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '\|\s*#\s*\|\s*Operation\s*\|\s*Type\s*\|\s*Title\s*\|\s*Subject\s*\|\s*Evidence\s*\|\s*Interpreted\s*\|\s*Details\s*\|' 'header'
    Assert-Match $run.Output '\|\s*1\s*\|\s*create\s*\|\s*subject\s*\|\s*Branch network\s*\|\s*\|\s*fact\s*\|\s*no\s*\|.*kind: product' 'line 1'
    Assert-Match $run.Output '\|\s*2\s*\|\s*create\s*\|\s*commitment\s*\|\s*Send the list of pilot branches\s*\|\s*line 1\s*\|\s*reported\s*\|\s*yes\s*\|.*owner: the tech lead' 'line 2'
    Assert-Match $run.Output '\|\s*3\s*\|\s*create\s*\|\s*decision\s*\|\s*Postpone the pilot\s*\|\s*mobile-onboarding\s*\|\s*hypothesis\s*\|\s*no\s*\|.*status: pending' 'line 3'
    Assert-Match $run.Output '\|\s*4\s*\|\s*create\s*\|\s*risk\s*\|\s*The pilot branches are not staffed\s*\|\s*mobile-onboarding\s*\|\s*fact\s*\|\s*no\s*\|.*severity: watch' 'line 4'
    Assert-True ($run.Output -notmatch 'evidence_level:|subject:') "the details repeat what the columns show: $($run.Output)"
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'with one invalid operation among several valid ones, nothing is written and the reason names its line' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment),
            (New-SubjectOperation @{ title = 'Branch network' }),
            (New-RecordOperation decision @{ needed_by = 'end of March' }),
            (New-RecordOperation risk @{ subject = 'line 2' })
        )
    }

    Assert-Refused $ws @("Line 3: field 'needed_by' must be an ISO date \(yyyy-mm-dd\), not 'end of March'")

    Assert-Equal 'mobile-onboarding.json' ((Get-ChildItem (Join-Path $ws 'register') -Recurse -File -Filter *.json | ForEach-Object { $_.Name }) -join ' ') 'records of the register'
    Assert-Equal '' (@(git -C $ws status --porcelain -- register) -join ' ') 'changes to the register'
}

Test 'numbers run per type and per year recorded, and a number already taken is never given again' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @((New-RecordOperation commitment), (New-RecordOperation commitment), (New-RecordOperation commitment), (New-RecordOperation risk)) }
    $first = Invoke-Register $ws apply -Today 2026-12-30
    Set-Proposal $ws @{ operations = @((New-RecordOperation commitment), (New-RecordOperation risk), (New-RecordOperation decision)) }
    $nextYear = Invoke-Register $ws apply -Today 2027-01-04
    # A register whose first commitments of 2026 are gone: their numbers stay taken.
    git -C $ws rm -q register/commitments/2026/C-2026-001.json register/commitments/2026/C-2026-002.json
    git -C $ws commit -q -m 'Two commitments lost'
    Set-Proposal $ws @{ operations = @((New-RecordOperation commitment @{ title = 'Recorded late' }), (New-RecordOperation commitment)) }

    $run = Invoke-Register $ws apply -Today 2026-12-31

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $ids = @(Get-ChildItem (Join-Path $ws 'register') -Recurse -File -Filter *.json | ForEach-Object { $_.FullName.Substring($ws.Length + 1) } | Sort-Object)
    $expected = 'register\commitments\2026\C-2026-003.json', 'register\commitments\2026\C-2026-004.json', 'register\commitments\2026\C-2026-005.json',
        'register\commitments\2027\C-2027-001.json', 'register\decisions\2027\D-2027-001.json',
        'register\risks\R-2026-001.json', 'register\risks\R-2027-001.json', 'register\subjects\mobile-onboarding.json'
    Assert-Equal ($expected -join ' ') ($ids -join ' ') 'record files'
    Assert-Equal 'Recorded late' (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-004.json')).title 'title of the commitment recorded late'
    Assert-Equal 'C-2027-001' (Read-Json (Join-Path $ws 'register\commitments\2027\C-2027-001.json')).id 'identifier of the first commitment of 2027'
}
