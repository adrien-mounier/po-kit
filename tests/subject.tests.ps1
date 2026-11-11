# A proposed subject is previewed, applied and saved.

Test 'preview prints a numbered table of the operations and changes no file' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation),
            (New-SubjectOperation @{ title = 'Branch appointment booking'; kind = 'contribution'; horizon = 'next' })
        )
    }
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws preview

    Assert-Equal 0 $run.ExitCode 'exit code'
    Assert-Match $run.Output '\|\s*1\s*\|\s*create\s*\|\s*subject\s*\|\s*Mobile onboarding\s*\|.*kind: product' 'line 1'
    Assert-Match $run.Output '\|\s*2\s*\|\s*create\s*\|\s*subject\s*\|\s*Branch appointment booking\s*\|.*horizon: next' 'line 2'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'preview shows a single operation, with its accents intact' {
    $ws = New-TestWorkspace
    Set-Proposal $ws 'create-subject.proposal.json'
    $title = (Read-Json (Join-Path $Fixtures 'create-subject.proposal.json')).operations[0].fields.title

    $run = Invoke-Register $ws preview

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output ('\|\s*1\s*\|\s*create\s*\|\s*subject\s*\|\s*' + [regex]::Escape($title) + '\s*\|') 'line 1'
}

Test 'apply writes the subject as one record whose identifier is a slug of the title and equals the file name' {
    $ws = New-TestWorkspace
    Set-Proposal $ws 'create-subject.proposal.json'

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $files = @(Get-ChildItem (Join-Path $ws 'register') -Recurse -File -Filter *.json)
    Assert-Equal 1 $files.Count 'records written'
    Assert-Equal (Join-Path $ws 'register\subjects\refonte-de-l-entree-en-relation.json') $files[0].FullName 'record file'
    Assert-Equal 'refonte-de-l-entree-en-relation' (Read-Json $files[0].FullName).id 'identifier'
}

Test 'the record carries the common fields and every subject field, with its dates set by the register tool' {
    $ws = New-TestWorkspace
    Set-Proposal $ws 'create-subject.proposal.json'
    $proposed = (Read-Json (Join-Path $Fixtures 'create-subject.proposal.json')).operations[0].fields

    $run = Invoke-Register $ws apply -Today 2026-03-02

    $record = Read-Json (Join-Path $ws 'register\subjects\refonte-de-l-entree-en-relation.json')
    $expected = 'id', 'type', 'title', 'status', 'date_recorded', 'date_updated', 'evidence_level', 'source', 'objectives',
        'notes', 'supersedes', 'superseded_by', 'history',
        'kind', 'horizon', 'clearance', 'cleared_by', 'cleared_on', 'owning_entity', 'sponsor', 'decider', 'gates',
        'next_step', 'next_date', 'next_date_confirmed', 'watch_list', 'links'
    $actual = @($record.PSObject.Properties | ForEach-Object { $_.Name })
    Assert-Equal (($expected | Sort-Object) -join ' ') (($actual | Sort-Object) -join ' ') 'fields of the record'

    Assert-Equal 'subject' $record.type 'type'
    Assert-Equal '2026-03-02' $record.date_recorded 'date recorded'
    Assert-Equal '2026-03-02' $record.date_updated 'date updated'
    foreach ($name in 'title', 'kind', 'horizon', 'clearance', 'cleared_by', 'cleared_on', 'evidence_level', 'notes',
        'owning_entity', 'sponsor', 'decider', 'next_step', 'next_date', 'next_date_confirmed') {
        Assert-Equal $proposed.$name $record.$name $name
    }
    Assert-Equal 'conversation with the PO' $record.source.where 'source'
    Assert-Equal '2026-03-02' $record.source.read_on 'date the source was read'
    Assert-True ($record.watch_list.people -is [array]) 'a list of one item is no longer a list'
    Assert-Equal 'the tech lead' ($record.watch_list.people -join ', ') 'people watched'
    Assert-Equal ($proposed.watch_list.keywords -join ', ') ($record.watch_list.keywords -join ', ') 'keywords watched'
    Assert-Equal 'ONB' ($record.watch_list.tracker_projects -join ', ') 'tracker projects watched'
    Assert-Equal 'https://example.com/onboarding' ($record.links -join ', ') 'links'
}

Test 'a subject proposed with its required fields only is recorded with the defaults' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }

    $run = Invoke-Register $ws apply -Today 2026-03-02

    $record = Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')
    Assert-Equal 'active' $record.status 'status'
    Assert-Equal 'none' $record.clearance 'clearance'
    Assert-Equal $false $record.next_date_confirmed 'next date confirmed'
    Assert-True ($null -eq $record.next_date) 'a next date was recorded'
    foreach ($list in $record.objectives, $record.history, $record.gates, $record.links,
        $record.watch_list.people, $record.watch_list.keywords, $record.watch_list.tracker_projects) {
        Assert-True ($list -is [array] -and $list.Count -eq 0) 'a list left out of the proposal is not recorded as an empty list'
    }
}

Test 'a second subject with the same title gets a distinct identifier' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @((New-SubjectOperation), (New-SubjectOperation @{ kind = 'service' })) }
    $first = Invoke-Register $ws apply
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }

    $run = Invoke-Register $ws apply

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $files = @(Get-ChildItem (Join-Path $ws 'register\subjects') -Filter *.json | Sort-Object Name)
    Assert-Equal 'mobile-onboarding mobile-onboarding-2 mobile-onboarding-3' (($files | ForEach-Object { $_.BaseName }) -join ' ') 'record files'
    foreach ($file in $files) { Assert-Equal $file.BaseName (Read-Json $file.FullName).id 'identifier' }
}

Test 'an identifier stays readable and usable as a file name whatever the title' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation @{ title = 'Mise en ' + [char]0x153 + 'uvre du KYC : phase 2 !' }),
            (New-SubjectOperation @{ title = '???' }),
            (New-SubjectOperation @{ title = 'Payments ' * 20 })
        )
    }

    $run = Invoke-Register $ws apply

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $ids = @(Get-ChildItem (Join-Path $ws 'register\subjects') -Filter *.json | ForEach-Object { $_.BaseName })
    Assert-True ($ids -ccontains 'mise-en-oeuvre-du-kyc-phase-2') "identifiers: $ids"
    Assert-True ($ids -ccontains 'subject') "identifiers: $ids"
    $long = @($ids | Where-Object { $_ -like 'payments-*' })
    Assert-True ($long.Count -eq 1 -and $long[0].Length -le 60 -and $long[0] -cmatch '^[a-z0-9]+(-[a-z0-9]+)*$') "identifiers: $ids"
}

Test 'when the commit cannot be made, apply fails, says so and leaves the proposal pending' {
    $ws = New-TestWorkspace
    [IO.File]::WriteAllText((Join-Path $ws '.git\hooks\pre-commit'), "#!/bin/sh`nexit 1`n")
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    $head = git -C $ws rev-parse HEAD

    $run = Invoke-Register $ws apply

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'The last commit of the workspace is the recovery point' 'output'
    Assert-Equal $head (git -C $ws rev-parse HEAD) 'last commit'
    Assert-True (Test-Path (Join-Path $ws 'state\proposal.json')) 'the proposal is no longer pending'
}

Test 'after apply, the last commit holds the new record and no proposal is pending' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }

    $run = Invoke-Register $ws apply

    $committed = @(git -C $ws show --name-only --format= HEAD)
    Assert-True ($committed -contains 'register/subjects/mobile-onboarding.json') "the last commit holds: $committed"
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'the proposal is still pending'
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
}

Test 'the record is written as UTF-8 without a byte order mark' {
    $ws = New-TestWorkspace
    Set-Proposal $ws 'create-subject.proposal.json'
    $title = (Read-Json (Join-Path $Fixtures 'create-subject.proposal.json')).operations[0].fields.title

    $run = Invoke-Register $ws apply

    $bytes = [IO.File]::ReadAllBytes((Join-Path $ws 'register\subjects\refonte-de-l-entree-en-relation.json'))
    Assert-True (-not ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) 'the record starts with a byte order mark'
    $strictUtf8 = New-Object System.Text.UTF8Encoding $false, $true
    Assert-Equal $title ($strictUtf8.GetString($bytes) | ConvertFrom-Json).title 'title read back as UTF-8'
}

Test 'the date treated as today can be set for one run' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    $set = Invoke-Register $ws apply -Today 2025-12-31
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    $machineDate = Get-Date -Format 'yyyy-MM-dd'

    $unset = Invoke-Register $ws apply

    $record = Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')
    Assert-Equal '2025-12-31' $record.date_recorded 'date recorded on the run with a set date'
    Assert-Equal '2025-12-31' $record.date_updated 'date updated on the run with a set date'
    Assert-Equal $machineDate (Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding-2.json')).date_recorded 'date recorded on the next run'
}

Test 'a date given as today that is not an ISO date stops the run' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws apply -Today 31/12/2025

    Assert-Equal 1 $run.ExitCode 'exit code'
    Assert-Match $run.Output 'yyyy-mm-dd' 'reason'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'a proposal with a missing required field, an unknown field and a value outside the allowed ones is refused whole' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation),
            (New-SubjectOperation @{ horizon = $null; colour = 'blue' }),
            (New-SubjectOperation @{ kind = 'project' })
        )
    }

    Assert-Refused $ws @(
        "Line 2: missing required field 'horizon'",
        "Line 2: unknown field 'colour'",
        "Line 3: field 'kind' is 'project'; allowed: product, contribution, service"
    )
}

Test 'the allowed values come from the record definition: changing one changes what is accepted' {
    $ws = New-TestWorkspace
    $definition = Join-Path $ws 'tools\definitions\subject.json'
    [IO.File]::WriteAllText($definition, [IO.File]::ReadAllText($definition).Replace('"service"', '"study"'))

    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ kind = 'study' }) }
    $run = Invoke-Register $ws apply
    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'study' (Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')).kind 'kind recorded'

    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ kind = 'service' }) }
    Assert-Refused $ws @("Line 1: field 'kind' is 'service'; allowed: product, contribution, study")
}

Test 'a gate is accepted when the workspace settings name it, in any of the five states' {
    $ws = New-TestWorkspace
    $states = 'unknown', 'not required', 'missing', 'planned', 'done'
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.gates = @($states | ForEach-Object { "review $_" })
    Write-Json (Join-Path $ws 'settings.json') $settings
    $gates = @($states | ForEach-Object { @{ name = "review $_"; state = $_ } })
    $gates[4].link = 'https://example.com/review-minutes'
    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ gates = $gates }) }

    $run = Invoke-Register $ws apply

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $recorded = (Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')).gates
    Assert-Equal ($states -join ', ') (($recorded | ForEach-Object { $_.state }) -join ', ') 'gate states recorded'
    Assert-Equal 'review missing' $recorded[2].name 'gate name recorded'
    Assert-True ($null -eq $recorded[2].link) 'a gate without evidence carries a link'
    Assert-Equal 'https://example.com/review-minutes' $recorded[4].link 'link to the evidence of a gate'
}

Test 'a gate the workspace settings do not name, or a gate state outside the five, is refused' {
    $ws = New-TestWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.gates = @('architecture review')
    Write-Json (Join-Path $ws 'settings.json') $settings
    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ gates = @(
                    @{ name = 'security review'; state = 'done' },
                    @{ name = 'architecture review'; state = 'skipped' }
                )
            })
    }

    Assert-Refused $ws @(
        "Line 1: field 'gates.name' is 'security review'; settings.json lists under 'gates': architecture review",
        "Line 1: field 'gates.state' is 'skipped'; allowed: unknown, not required, missing, planned, done"
    )
}

Test 'a field only the register tool writes cannot be proposed' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ id = 'chosen-by-the-routine'; date_recorded = '2020-01-01' }) }

    Assert-Refused $ws @(
        "Line 1: field 'id' is set by the register tool",
        "Line 1: field 'date_recorded' is set by the register tool"
    )
}

Test 'a value of the wrong kind is refused: dates are ISO dates' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{
                next_date           = '16/03/2026'
                cleared_on          = '2026-02-30'
                next_date_confirmed = 'yes'
                owning_entity       = 42
                links               = 'https://example.com/onboarding'
                watch_list          = @{ people = 'the tech lead'; teams = @('retail') }
                source              = @{ where = 'conversation with the PO' }
            })
    }

    Assert-Refused $ws @(
        "Line 1: field 'next_date' must be an ISO date \(yyyy-mm-dd\), not '16/03/2026'",
        "Line 1: field 'cleared_on' must be an ISO date \(yyyy-mm-dd\), not '2026-02-30'",
        "Line 1: field 'next_date_confirmed' must be true or false, not 'yes'",
        "Line 1: field 'owning_entity' must be text, not '42'",
        "Line 1: field 'links' must be a list",
        "Line 1: field 'watch_list.people' must be a list",
        "Line 1: unknown field 'watch_list.teams'",
        "Line 1: missing required field 'source.read_on'"
    )
}

Test 'a proposal the register tool cannot read as operations is refused' {
    $ws = New-TestWorkspace
    $path = Join-Path $ws 'state\proposal.json'

    [IO.File]::WriteAllText($path, '{ "operations": [ { "op": "create" ')
    Assert-Refused $ws @('The proposal is not valid JSON written as UTF-8')

    Set-Proposal $ws @{ operation = @(New-SubjectOperation) }
    Assert-Refused $ws @("unknown field 'operation'")

    $unknownOperation = New-SubjectOperation
    $unknownOperation.op = 'delete'
    $unknownType = New-SubjectOperation
    $unknownType.type = 'project'
    Set-Proposal $ws @{ operations = @($unknownOperation, $unknownType, @{ op = 'create'; type = 'subject'; interpreted = $false }) }
    Assert-Refused $ws @(
        "Line 1: unknown operation 'delete'; allowed: create",
        "Line 2: unknown record type 'project'",
        "Line 3: the operation gives no fields"
    )
}

Test 'a proposal saved in another encoding than UTF-8 is refused instead of being misread' {
    $ws = New-TestWorkspace
    $path = Join-Path $ws 'state\proposal.json'
    $text = [IO.File]::ReadAllText((Join-Path $Fixtures 'create-subject.proposal.json'))

    [IO.File]::WriteAllText($path, $text, [Text.Encoding]::GetEncoding(1252))
    Assert-Refused $ws @('The proposal is not valid JSON written as UTF-8')

    # A byte order mark is tolerated on the way in.
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding $true))
    $run = Invoke-Register $ws preview
    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
}

Test 'with no pending proposal, preview and apply say so and fail' {
    $ws = New-TestWorkspace

    foreach ($command in 'preview', 'apply') {
        $run = Invoke-Register $ws $command
        Assert-Equal 1 $run.ExitCode "exit code of $command"
        Assert-Match $run.Output 'No proposal is pending' "output of $command"
    }
}
