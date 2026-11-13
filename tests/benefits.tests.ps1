# Benefits: the gains a subject promises, and the values a person measured of them.

function New-BenefitOperation([hashtable]$Fields = @{}) {
    # One valid operation creating a benefit of Example Bank, attached to the subject
    # New-SubjectOperation creates. $Fields works as in New-SubjectOperation.
    $benefit = @{
        title          = 'Halve the time to open an account'
        subject        = 'mobile-onboarding'
        metric         = 'Time a customer takes to open an account'
        unit           = 'minutes'
        baseline       = 40
        target         = 20
        owner          = 'the head of retail operations'
        evidence_level = 'fact'
        source         = @{ where = 'conversation with the PO'; read_on = '2026-03-02' }
    }
    foreach ($name in $Fields.Keys) {
        if ($null -eq $Fields[$name]) { $benefit.Remove($name) } else { $benefit[$name] = $Fields[$name] }
    }
    @{ op = 'create'; type = 'benefit'; interpreted = $false; fields = $benefit }
}

Test 'apply writes a benefit filed under its year, identified as B, the year and a number, with its metric, unit, baseline, target, owner, value and status' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(New-BenefitOperation @{ current_value = 38; measured_on = '2026-03-01'; objectives = @() }) }

    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $record = Read-Json (Join-Path $ws 'register\benefits\2026\B-2026-001.json')
    Assert-Equal 'B-2026-001' $record.id 'identifier'
    Assert-Equal 'benefit' $record.type 'type'
    Assert-Equal 'mobile-onboarding' $record.subject 'subject'
    Assert-Equal 'Time a customer takes to open an account' $record.metric 'metric'
    Assert-Equal 'minutes' $record.unit 'unit'
    Assert-Equal 40 $record.baseline 'baseline'
    Assert-Equal 20 $record.target 'target'
    Assert-Equal 'the head of retail operations' $record.owner 'owner'
    Assert-Equal 38 $record.current_value 'current value'
    Assert-Equal '2026-03-01' $record.measured_on 'measured on'
    Assert-Equal 'open' $record.status 'status'
    $expected = 'id', 'type', 'title', 'status', 'date_recorded', 'date_updated', 'evidence_level', 'source', 'objectives',
        'notes', 'supersedes', 'superseded_by', 'history', 'subject', 'metric', 'unit', 'baseline', 'target', 'owner', 'current_value', 'measured_on'
    Assert-Equal (($expected | Sort-Object) -join ' ') ((@($record.PSObject.Properties | ForEach-Object { $_.Name }) | Sort-Object) -join ' ') 'fields of the record'
}

Test 'a subject holds several benefits, each with its own number' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-BenefitOperation),
            (New-BenefitOperation @{ title = 'Fewer onboarding files sent back'; metric = 'Onboarding files sent back for an error'; unit = 'files per week'; baseline = 30; target = 5 })
        )
    }

    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($id in 'B-2026-001', 'B-2026-002') {
        Assert-Equal 'mobile-onboarding' (Read-Json (Join-Path $ws "register\benefits\2026\$id.json")).subject "subject of $id"
    }
}

Test 'a benefit whose subject does not exist, whose status is not listed, with a value that is no number, or with a value and no date it was measured is refused' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(New-BenefitOperation @{ subject = 'card-dispute-portal' }) }
    Assert-Refused $ws @("Line 1: subject 'card-dispute-portal' exists neither in the register nor earlier in this proposal")

    Set-Proposal $ws @{ operations = @(New-BenefitOperation @{ status = 'delivered' }) }
    Assert-Refused $ws @("Line 1: field 'status' is 'delivered'; allowed: open, achieved, dropped, superseded")

    Set-Proposal $ws @{ operations = @(New-BenefitOperation @{ baseline = 'about forty' }) }
    Assert-Refused $ws @("Line 1: field 'baseline' must be a number \(as 40 or 4\.5\), not 'about forty'")

    Set-Proposal $ws @{ operations = @(New-BenefitOperation @{ current_value = 35 }) }
    Assert-Refused $ws @("Line 1: measured value without its date: a benefit that gives 'current_value' gives 'measured_on'")
}

function New-TestWorkspaceWithBenefit([hashtable]$Fields = @{}) {
    # A workspace whose register holds the subject mobile-onboarding and its benefit B-2026-001,
    # recorded on 3 March 2026.
    $workspace = New-TestWorkspaceWithSubject
    Set-Proposal $workspace @{ operations = @(New-BenefitOperation $Fields) }
    $run = Invoke-Register $workspace apply -Today 2026-03-03
    Assert-Equal 0 $run.ExitCode "exit code when recording the benefit, with output: $($run.Output)"
    $workspace
}

function New-MeasureOperation([string]$Value, [string]$On, [string]$Note) {
    # The update of B-2026-001 with a value a person stated in a note, and the date it was measured.
    $update = New-UpdateOperation 'B-2026-001' @{ current_value = [int]$Value; measured_on = $On }
    $update.source = @{ where = "inbox/$Note"; read_on = $On }
    $update
}

Test 'each new measured value is an update with its source, and the history keeps every value and the date it was measured' {
    $ws = New-TestWorkspaceWithBenefit
    Set-Proposal $ws @{ operations = @(New-MeasureOperation 35 '2026-03-09' 'pilot review.md') }
    $run = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $run.ExitCode "exit code of the first value, with output: $($run.Output)"
    Set-Proposal $ws @{ operations = @(New-MeasureOperation 31 '2026-03-16' 'pilot figures.md') }
    $run = Invoke-Register $ws apply -Today 2026-03-17
    Assert-Equal 0 $run.ExitCode "exit code of the second value, with output: $($run.Output)"

    $record = Read-Json (Join-Path $ws 'register\benefits\2026\B-2026-001.json')
    Assert-Equal 31 $record.current_value 'current value'
    Assert-Equal '2026-03-16' $record.measured_on 'measured on'
    $values = @($record.history | Where-Object { $_.field -eq 'current_value' } | ForEach-Object { "$($_.previous) -> $($_.new) from $($_.source.where)" })
    Assert-Equal ' -> 35 from inbox/pilot review.md | 35 -> 31 from inbox/pilot figures.md' ($values -join ' | ') 'values in the history'
    $dates = @($record.history | Where-Object { $_.field -eq 'measured_on' } | ForEach-Object { $_.new })
    Assert-Equal '2026-03-09 2026-03-16' "$dates" 'dates measured in the history'
}

Test 'an update that gives a new value without the date it was measured is refused, even when the benefit holds an earlier date' {
    $ws = New-TestWorkspaceWithBenefit @{ current_value = 38; measured_on = '2026-03-01' }
    Set-Proposal $ws @{ operations = @(New-UpdateOperation 'B-2026-001' @{ current_value = 33 }) }

    Assert-Refused $ws @("Line 1: a new 'current_value' is given with its 'measured_on', the date it was measured")
}

Test 'export lists the benefits of the period with baseline, target, the latest value and its date, and each value recorded in the period with its source' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-BenefitOperation @{ current_value = 38; measured_on = '2026-03-01' }),
            (New-BenefitOperation @{ title = 'Fewer onboarding files sent back'; metric = 'Onboarding files sent back for an error'; unit = 'files per week'; baseline = $null; target = 5; owner = $null }),
            (New-BenefitOperation @{ title = 'Paper forms retired'; metric = 'Paper forms printed per month'; unit = $null; status = 'achieved' })
        )
    }
    $run = Invoke-Register $ws apply -Today 2026-03-03
    Assert-Equal 0 $run.ExitCode "exit code when recording the benefits, with output: $($run.Output)"
    Set-Proposal $ws @{ operations = @(New-MeasureOperation 35 '2026-03-09' 'pilot review.md') }
    $run = Invoke-Register $ws apply -Today 2026-03-10
    Set-Proposal $ws @{ operations = @(New-MeasureOperation 31 '2026-03-16' 'pilot figures.md') }
    $run = Invoke-Register $ws apply -Today 2026-03-17

    $run = Invoke-Register $ws export 2026-03-10 -Today 2026-03-17

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $section = [regex]::Match($run.Output, '(?s)\n## Benefits\n\n(.*?)\n\n## ').Groups[1].Value
    Assert-Equal ((
            '- Halve the time to open an account [B-2026-001] | benefit | fact | subject: mobile-onboarding | status: open | metric: Time a customer takes to open an account | baseline: 40 minutes | target: 20 minutes | latest value: 31 minutes, measured 2026-03-16 | measured by: the head of retail operations | values recorded since 2026-03-10: 35 minutes measured 2026-03-09 (inbox/pilot review.md); 31 minutes measured 2026-03-16 (inbox/pilot figures.md)',
            '- Fewer onboarding files sent back [B-2026-002] | benefit | fact | subject: mobile-onboarding | status: open | metric: Onboarding files sent back for an error | baseline: missing | target: 5 files per week | latest value: none measured yet | measured by: missing | values recorded since 2026-03-10: none',
            '- Paper forms retired [B-2026-003] | benefit | fact | subject: mobile-onboarding | status: achieved | metric: Paper forms printed per month | baseline: 40 | target: 20 | latest value: none measured yet | measured by: the head of retail operations | values recorded since 2026-03-10: none'
        ) -join "`n") $section 'the benefits of the period: every open or achieved one, the one achieved before it too'
}

Test 'export lists every open or achieved benefit, not a dropped one, those measured in the period first, by the day they were measured, the latest first, not by the day the value was recorded' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-BenefitOperation),
            (New-BenefitOperation @{ title = 'Fewer onboarding files sent back' }),
            (New-BenefitOperation @{ title = 'Fewer branch visits' }),
            (New-BenefitOperation @{ title = 'Paper forms retired'; status = 'dropped' })
        )
    }
    Invoke-Register $ws apply -Today 2026-03-03 | Out-Null
    $measure = { param($Id, $Value, $On) $update = New-UpdateOperation $Id @{ current_value = $Value; measured_on = $On }; $update.source = @{ where = 'inbox/pilot figures.md'; read_on = $On }; $update }
    # B-2026-002 is recorded in the period with a value measured before it; B-2026-003 is measured
    # in the period; B-2026-001 is measured earlier in the period, and recorded last.
    Set-Proposal $ws @{ operations = @((& $measure 'B-2026-002' 33 '2026-03-05'), (& $measure 'B-2026-003' 12 '2026-03-12')) }
    Invoke-Register $ws apply -Today 2026-03-12 | Out-Null
    Set-Proposal $ws @{ operations = @(& $measure 'B-2026-001' 31 '2026-03-11') }
    Invoke-Register $ws apply -Today 2026-03-13 | Out-Null

    $run = Invoke-Register $ws export 2026-03-10 -Today 2026-03-13

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $section = [regex]::Match($run.Output, '(?s)\n## Benefits\n\n(.*?)\n\n## ').Groups[1].Value
    Assert-Equal 'B-2026-003 B-2026-001 B-2026-002' "$(@([regex]::Matches($section, '\[(B-2026-\d+)\]') | ForEach-Object { $_.Groups[1].Value }))" 'the order of the benefits'
}

Test 'verify accepts a view that cites a benefit, and refuses one that cites a superseded or a missing benefit' {
    $ws = New-TestWorkspaceWithBenefit
    Set-Proposal $ws @{ operations = @(New-BenefitOperation @{ title = 'Open an account in a quarter of an hour'; target = 15; supersedes = 'B-2026-001' }) }
    $run = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $run.ExitCode "exit code of the superseding benefit, with output: $($run.Output)"
    $stamp = @((Invoke-Register $ws export 2026-03-10 -Today 2026-03-10).Output -split "`n" | Where-Object { $_ -like '> *' }) -join "`n"
    $view = Join-Path $ws 'views\weekly\2026-03-10.md'

    [IO.File]::WriteAllText($view, "# Value`n`n$stamp`n`nTarget lowered to 15 minutes [B-2026-002].`n", $Utf8)
    $run = Invoke-Register $ws verify 'views\weekly\2026-03-10.md' -Today 2026-03-10
    Assert-Equal 0 $run.ExitCode "exit code on a current benefit, with output: $($run.Output)"

    [IO.File]::WriteAllText($view, "# Value`n`n$stamp`n`nHalve the time [B-2026-001], and [B-2026-009].`n", $Utf8)
    $run = Invoke-Register $ws verify 'views\weekly\2026-03-10.md' -Today 2026-03-10
    Assert-Equal 1 $run.ExitCode "exit code on a superseded and a missing benefit, with output: $($run.Output)"
    Assert-Match $run.Output '- B-2026-001 is superseded by B-2026-002\.' 'the superseded benefit'
    Assert-Match $run.Output '- B-2026-009 is not in the register\.' 'the missing benefit'
}

Test 'the portfolio view gives each subject the count of its benefits in play, open or achieved' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation @{ title = 'Card dispute handling'; horizon = 'next' }),
            (New-BenefitOperation),
            (New-BenefitOperation @{ title = 'Fewer files sent back'; status = 'achieved' }),
            (New-BenefitOperation @{ title = 'Fewer branch visits'; status = 'dropped' })
        )
    }

    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = [IO.File]::ReadAllText((Join-Path $ws 'views\portfolio.md'), $Utf8)
    Assert-Match $view '\| Mobile onboarding \[mobile-onboarding\], 2 benefit\(s\) +\|' 'the subject with two benefits in play'
    Assert-Match $view '\| Card dispute handling \[card-dispute-handling\] +\|' 'the subject without a benefit'
    $run = Invoke-Register $ws view fr -Today 2026-03-03
    Assert-Match ([IO.File]::ReadAllText((Join-Path $ws 'views\portfolio.md'), $Utf8)) ('Mobile onboarding \[mobile-onboarding\], 2 b' + [char]0xE9 + 'n' + [char]0xE9 + 'fice\(s\)') 'the count in French'
}

Test 'a workspace made before the kit shipped benefits, without their folder, is checked and exported as any other' {
    $ws = New-TestWorkspaceWithSubject
    Remove-Item (Join-Path $ws 'register\benefits') -Recurse -Force
    git -C $ws commit -q -am 'A workspace of an earlier kit'

    foreach ($command in 'check', 'export 2026-03-01') {
        $run = Invoke-Register $ws @($command -split ' ') -Today 2026-03-03
        Assert-Equal 0 $run.ExitCode "exit code of $command, with output: $($run.Output)"
    }
}

Test 'check warns about an open benefit that has had no value for longer than the subject delay, and not about one measured within it or one no longer open' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-BenefitOperation @{ title = 'Never measured' }),
            (New-BenefitOperation @{ title = 'Measured long ago'; current_value = 38; measured_on = '2026-02-20' }),
            (New-BenefitOperation @{ title = 'Measured this week'; current_value = 36; measured_on = '2026-03-09' }),
            (New-BenefitOperation @{ title = 'Achieved without a value'; status = 'achieved' })
        )
    }
    $run = Invoke-Register $ws apply -Today 2026-03-03
    Assert-Equal 0 $run.ExitCode "exit code when recording the benefits, with output: $($run.Output)"

    $run = Invoke-Register $ws check -Today 2026-03-10
    $report = [IO.File]::ReadAllText((Join-Path $ws 'views\check-report.md'), $Utf8)
    Assert-True ($report -notmatch 'B-2026-001') "the benefit recorded 7 days ago is stale within the delay of 7 days:`n$report"

    $run = Invoke-Register $ws check -Today 2026-03-13
    Assert-Equal 0 $run.ExitCode "exit code: a stale benefit is a warning, with output: $($run.Output)"
    $report = [IO.File]::ReadAllText((Join-Path $ws 'views\check-report.md'), $Utf8)
    Assert-Match $report '### Open benefit without a measured value for more than 7 day\(s\)\r?\n\r?\n- Never measured \[B-2026-001\] \(never measured, recorded 2026-03-03\)\r?\n- Measured long ago \[B-2026-002\] \(last measured: 2026-02-20\)\r?\n(\r?\n|$)' 'the stale benefits, each once'
}
