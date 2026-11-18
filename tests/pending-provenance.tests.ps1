Test 'an archived note remains findable for a plain line and the interpreted line still awaiting approval' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @((New-SubjectOperation)) }
    $seed = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $seed.ExitCode "seed, $($seed.Output)"
    Add-InboxNote $ws 'shared.md' 'Two fictional commitments.'
    $source = @{ where = 'inbox/shared.md'; read_on = '2026-03-10' }
    $plain = New-RecordOperation commitment @{ title = 'Plain task'; source = $source }
    $interpreted = New-RecordOperation commitment @{ title = 'Interpretation to approve'; source = $source }
    $interpreted.interpreted = $true
    Set-Proposal $ws @{ operations = @($plain, $interpreted); collected_at = '2026-03-10T09:00:00+01:00'; notes_processed = @('shared.md') }
    $run = Invoke-Register $ws apply plain -Today 2026-03-10
    Assert-Equal 0 $run.ExitCode "plain apply, $($run.Output)"
    $pending = Read-Json (Join-Path $ws 'state\proposal.json')
    Assert-Equal 'inbox/done/2026-03/shared.md' $pending.operations[0].fields.source.where 'pending provenance'
    Assert-True (Test-Path -LiteralPath (Join-Path $ws $pending.operations[0].fields.source.where)) 'pending source exists'
    $later = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $later.ExitCode "later approval, $($later.Output)"
    $record = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-002.json')
    Assert-True (Test-Path -LiteralPath (Join-Path $ws $record.source.where)) 'approved record source exists'
}
