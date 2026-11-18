Test 'a changed register offers the committee pack again even though its old file exists' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
        (New-SubjectOperation),
        (New-RecordOperation commitment @{ subject = 'line 1'; due_date = '2026-03-20'; owner = 'the PO' })
    ) }
    $run = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $run.ExitCode "seed, $($run.Output)"
    $connections = Read-Json (Join-Path $ws 'connections.json')
    $connections.calendar = @{ mode = 'folder'; folder = 'exports/calendar' }
    Write-Json (Join-Path $ws 'connections.json') $connections
    Write-Json (Join-Path $ws 'state\calendar.json') @{ read_at = '2026-03-10T08:00:00+01:00'; from = '2026-03-09'; to = '2026-03-24'; meetings = @(@{ start = '2026-03-16T10:00:00+01:00'; end = '2026-03-16T11:00:00+01:00'; title = 'Retail steering committee'; attendees = @(); status = 'accepted' }); absences = @() }
    $deck = Invoke-Register $ws steering 2026-03-16 -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $deck.ExitCode "deck, $($deck.Output)"
    $fresh = Invoke-Register $ws morning -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $fresh.ExitCode "fresh, $($fresh.Output)"
    Assert-True ($fresh.Output -notmatch 'Steering pack to offer') 'fresh deck is not offered again'
    Set-Proposal $ws @{ operations = @((New-UpdateOperation 'C-2026-001' @{ due_date = '2026-04-10' })) }
    $update = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $update.ExitCode "update, $($update.Output)"
    $stale = Invoke-Register $ws morning -Now '2026-03-10T09:00:00+01:00'
    Assert-Equal 0 $stale.ExitCode "stale, $($stale.Output)"
    Assert-Match $stale.Output 'Steering pack to offer: Retail steering committee' 'stale deck is offered again'
}
