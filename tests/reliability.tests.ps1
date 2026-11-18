# The time zone of the PO, the register state of a view, the batch a collect opens in a source,
# the path of a filed note, and a Git index the PO left staged.

function New-ReliabilityWorkspace {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
        (New-SubjectOperation @{ title = 'Reliability subject'; horizon = 'later'; clearance = 'pending' }),
        (New-RecordOperation commitment @{ title = 'Review the pilot'; subject = 'line 1'; owner = 'the PO'; due_date = '2026-03-20'; source = @{ where = 'the PO in a test'; read_on = '2026-03-10' } })
    ) }
    $run = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $run.ExitCode "seed, $($run.Output)"
    $ws
}

Test 'a changed due date makes a same-ID draft stale while its historical references remain valid' {
    $ws = New-ReliabilityWorkspace
    $stamp = @((Get-Content (Join-Path $ws 'views\portfolio.md')) | Where-Object { $_ -like '> *' })
    Write-Json (Join-Path $ws 'state\test-data.json') @{}
    [IO.File]::WriteAllText((Join-Path $ws 'views\archive.md'), (($stamp + '', 'Due on 20 March [C-2026-001].') -join "`n"), $Utf8)
    $good = Invoke-Register $ws verify views\archive.md
    Assert-Equal 0 $good.ExitCode "initial verify, $($good.Output)"
    Set-Proposal $ws @{ operations = @((New-UpdateOperation 'C-2026-001' @{ due_date = '2026-04-10' })) }
    $changed = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $changed.ExitCode "update, $($changed.Output)"
    $stale = Invoke-Register $ws verify views\archive.md
    Assert-Equal 1 $stale.ExitCode 'stale draft is refused'
    Assert-Match $stale.Output 'view is stale' 'reason'
    $history = Invoke-Register $ws verify views\archive.md --historical
    Assert-Equal 0 $history.ExitCode "archive, $($history.Output)"
    Assert-Match $history.Output 'Historical references verified' 'archive verdict'
}

Test 'an archive is checked at its old tree even after a cited commitment is superseded' {
    $ws = New-ReliabilityWorkspace
    $stamp = @((Get-Content (Join-Path $ws 'views\portfolio.md')) | Where-Object { $_ -like '> *' })
    [IO.File]::WriteAllText((Join-Path $ws 'views\archive.md'), (($stamp + '', 'Original plan [C-2026-001].') -join "`n"), $Utf8)
    Set-Proposal $ws @{ operations = @((New-RecordOperation commitment @{ title = 'New plan'; subject = 'reliability-subject'; supersedes = 'C-2026-001' })) }
    $applied = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $applied.ExitCode "supersede, $($applied.Output)"
    $archive = Invoke-Register $ws verify views\archive.md --historical
    Assert-Equal 0 $archive.ExitCode "historical record, $($archive.Output)"
    $current = Invoke-Register $ws verify views\archive.md
    Assert-Equal 1 $current.ExitCode 'old plan is not a current draft'
}

Test '51 equal-timestamp messages are all read once, none lost and none read twice, to the fraction of a second' {
    $ws = New-TestWorkspace
    $when = '2026-03-10T08:00:00.1234567+07:00'
    $now = '2026-03-10T09:00:00+07:00'
    $matches = @(1..51 | ForEach-Object { @{ id = 'mail-' + $_.ToString('000'); when = $when; where = 'mail: fictional-' + $_ } })
    Write-Json (Join-Path $ws 'state\matches.json') $matches
    $run = Invoke-Register $ws select mail state\matches.json -Now $now
    Assert-Equal 0 $run.ExitCode "select first, $($run.Output)"
    $first = $run.Output | ConvertFrom-Json
    Assert-Equal 50 $first.selected.Count 'first batch'
    Assert-Equal $true $first.sources_read.cap_reached 'cap'
    Set-Proposal $ws @{ operations = @(); collected_at = $now; sources_read = @($first.sources_read) }
    $applied = Invoke-Register $ws apply -Now $now
    Assert-Equal 0 $applied.ExitCode "first cursor, $($applied.Output)"
    $state = Read-Json (Join-Path $ws 'state\last-collect.json')
    Assert-Equal $when $state.sources.mail.cutoff 'native fractional cutoff'
    $run = Invoke-Register $ws select mail state\matches.json -Now $now
    Assert-Equal 0 $run.ExitCode "select second, $($run.Output)"
    $second = $run.Output | ConvertFrom-Json
    Assert-Equal 1 @($second.selected).Count 'remaining message'
    Assert-Equal 'mail-051' $second.selected[0].id 'remaining ID'
    Set-Proposal $ws @{ operations = @(); collected_at = $now; sources_read = @($second.sources_read) }
    $applied = Invoke-Register $ws apply -Now $now
    Assert-Equal 0 $applied.ExitCode "second cursor, $($applied.Output)"
    $run = Invoke-Register $ws select mail state\matches.json -Now $now
    Assert-Equal 0 $run.ExitCode "select settled, $($run.Output)"
    Assert-Equal 0 @((($run.Output | ConvertFrom-Json).selected)).Count 'no replay'
}

Test 'selection compares actual instants across offsets and rejects repeated metadata IDs' {
    $ws = New-TestWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.per_source_cap = 1
    Write-Json (Join-Path $ws 'settings.json') $settings
    Write-Json (Join-Path $ws 'state\matches.json') @(
        @{ id = 'later'; when = '2026-03-10T10:00:00+01:00' },
        @{ id = 'earlier'; when = '2026-03-10T10:30:00+07:00' }
    )
    $run = Invoke-Register $ws select mail state\matches.json -Now '2026-03-10T19:00:00+07:00'
    Assert-Equal 0 $run.ExitCode "selection, $($run.Output)"
    Assert-Equal 'earlier' ($run.Output | ConvertFrom-Json).selected[0].id 'UTC ordering'
    Write-Json (Join-Path $ws 'state\matches.json') @(@{ id = 'same'; when = '2026-03-10T10:00:00Z' }, @{ id = 'same'; when = '2026-03-10T11:00:00Z' })
    $run = Invoke-Register $ws select mail state\matches.json -Now '2026-03-10T19:00:00+07:00'
    Assert-Equal 1 $run.ExitCode 'ambiguous IDs refused'
}

Test 'archived note sources and update history point at the real collision-safe files' {
    $ws = New-TestWorkspace
    Add-InboxNote $ws 'note.md' 'Fictional first note.'
    Set-Proposal $ws @{ operations = @(
        (New-SubjectOperation @{ title = 'Reliability subject'; horizon = 'later' }),
        (New-RecordOperation commitment @{ subject = 'line 1'; source = @{ where = 'inbox/note.md'; read_on = '2026-03-10' } })
    ); collected_at = '2026-03-10T09:00:00+07:00'; notes_processed = @('note.md') }
    $run = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $run.ExitCode "first note, $($run.Output)"
    $recordPath = Join-Path $ws 'register\commitments\2026\C-2026-001.json'
    $record = Read-Json $recordPath
    Assert-Equal 'inbox/done/2026-03/note.md' $record.source.where 'initial source'
    Assert-True (Test-Path -LiteralPath (Join-Path $ws $record.source.where)) 'initial source exists'
    Add-InboxNote $ws 'note.md' 'Fictional second note.'
    $update = New-UpdateOperation 'C-2026-001' @{ title = 'Corrected commitment' }
    $update.source.where = 'inbox/note.md'
    Set-Proposal $ws @{ operations = @($update); collected_at = '2026-03-10T10:00:00+07:00'; notes_processed = @('note.md'); unclassified = @(@{ source = 'inbox/note.md'; text = 'Fictional unmatched line' }) }
    $run = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $run.ExitCode "second note, $($run.Output)"
    $record = Read-Json $recordPath
    Assert-Equal 'inbox/done/2026-03/note-2.md' $record.history[-1].source.where 'history source'
    Assert-True (Test-Path -LiteralPath (Join-Path $ws $record.history[-1].source.where)) 'history source exists'
    Assert-Match ([IO.File]::ReadAllText((Join-Path $ws 'state\unclassified.md'))) 'inbox/done/2026-03/note-2.md' 'unclassified provenance'
}

Test 'apply refuses a foreign staged file without changing its index or the register' {
    $ws = New-ReliabilityWorkspace
    [IO.File]::WriteAllText((Join-Path $ws 'user-note.txt'), 'Fictional user edit.', $Utf8)
    & git -C $ws add -- user-note.txt
    $before = Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')
    Set-Proposal $ws @{ operations = @((New-UpdateOperation 'C-2026-001' @{ due_date = '2026-04-10' })) }
    $run = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 1 $run.ExitCode 'staged work blocks apply'
    Assert-Match $run.Output 'index already holds staged changes' 'operator reason'
    Assert-Equal 'user-note.txt' "$(& git -C $ws diff --cached --name-only)" 'index preserved'
    Assert-Equal $before.due_date (Read-Json (Join-Path $ws 'register\commitments\2026\C-2026-001.json')).due_date 'register unchanged'
}

function Set-ReliabilityCalendar([string]$Workspace, [string]$Zone, [string]$ReadAt, [string]$Start, [string]$End) {
    $settings = Read-Json (Join-Path $Workspace 'settings.json')
    $settings | Add-Member NoteProperty timezone $Zone -Force
    Write-Json (Join-Path $Workspace 'settings.json') $settings
    $connections = Read-Json (Join-Path $Workspace 'connections.json')
    $connections.calendar = @{ mode = 'folder'; folder = 'exports/calendar' }
    Write-Json (Join-Path $Workspace 'connections.json') $connections
    Write-Json (Join-Path $Workspace 'state\calendar.json') @{ read_at = $ReadAt; from = '2026-03-09'; to = '2026-04-10'; meetings = @(@{ start = $Start; end = $End; title = 'Fictional timezone meeting'; status = 'accepted'; attendees = @() }); absences = @() }
}

Test 'a calendar in UTC and the same calendar in the time zone of the PO give the same hours and free time' {
    $ws = New-TestWorkspace
    Set-ReliabilityCalendar $ws 'Tokyo Standard Time' '2026-03-10T01:00:00Z' '2026-03-10T03:00:00Z' '2026-03-10T04:00:00Z'
    $run = Invoke-Register $ws morning -Now '2026-03-10T11:00:00+09:00'
    Assert-Equal 0 $run.ExitCode "UTC calendar, $($run.Output)"
    $utc = [IO.File]::ReadAllText((Join-Path $ws 'views\morning.html'))
    $free = [IO.File]::ReadAllText((Join-Path $ws 'state\free-time.json'))
    Assert-Match $utc '12:00' 'hour of the meeting in Tokyo'
    Assert-True ($utc -notmatch '03:00') 'the hour of the meeting in UTC is not shown'
    Set-ReliabilityCalendar $ws 'Tokyo Standard Time' '2026-03-10T10:00:00+09:00' '2026-03-10T12:00:00+09:00' '2026-03-10T13:00:00+09:00'
    $run = Invoke-Register $ws morning -Now '2026-03-10T11:00:00+09:00'
    Assert-Equal 0 $run.ExitCode "local calendar, $($run.Output)"
    Assert-Equal $free ([IO.File]::ReadAllText((Join-Path $ws 'state\free-time.json'))) 'free time invariant'
}

Test 'a meeting the day before in UTC is on the day of the PO in their time zone' {
    $ws = New-TestWorkspace
    Set-ReliabilityCalendar $ws 'Tokyo Standard Time' '2026-03-09T23:00:00Z' '2026-03-09T23:30:00Z' '2026-03-10T00:15:00Z'
    $run = Invoke-Register $ws morning -Now '2026-03-10T11:00:00+09:00'
    Assert-Equal 0 $run.ExitCode "midnight calendar, $($run.Output)"
    $page = [IO.File]::ReadAllText((Join-Path $ws 'views\morning.html'))
    Assert-Match $page '08:30' 'local day and hour'
    Assert-Match $page 'Fictional timezone meeting' 'meeting retained'
}

Test 'the hour of a message and of the last collect are shown in the time zone of the PO' {
    $ws = New-TestWorkspace
    Set-ReliabilityCalendar $ws 'Tokyo Standard Time' '2026-03-10T01:00:00Z' '2026-03-10T03:00:00Z' '2026-03-10T04:00:00Z'
    $connections = Read-Json (Join-Path $ws 'connections.json')
    $connections.mail = @{ mode = 'folder'; folder = 'exports\mail' }
    Write-Json (Join-Path $ws 'connections.json') $connections
    Set-Proposal $ws @{ collected_at = '2026-03-10T00:40:00Z'; sources_read = @(@{ source = 'notes'; cutoff = '2026-03-10T00:40:00Z'; items = 0 }, @{ source = 'mail'; cutoff = '2026-03-10T00:40:00Z'; items = 0 }); sources_not_covered = @('tracker'); notes_processed = @(); operations = @() }
    $run = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $run.ExitCode "collect, $($run.Output)"
    Write-Json (Join-Path $ws 'state\morning.json') @{ messages = @(@{ source = 'mail'; from = 'the architect'; where = 'Hosting options'; sent = '2026-03-10T01:15:00Z'; text = 'Which hosting do you prefer?' }) }

    $run = Invoke-Register $ws morning -Now '2026-03-10T11:00:00+09:00'

    Assert-Equal 0 $run.ExitCode "morning, $($run.Output)"
    $page = [IO.File]::ReadAllText((Join-Path $ws 'views\morning.html'))
    Assert-Match $page '<b>10:15</b>' 'hour of the message in Tokyo'
    Assert-Match $page 'Read by the collect of 09:40' 'hour of the last collect in Tokyo'
    Assert-True ($page -notmatch '01:15|00:40') "an hour in UTC is shown: $([regex]::Matches($page, '.{0,60}(01:15|00:40).{0,60}') | ForEach-Object { $_.Value -replace '[\r\n]', ' ' })"
}

Test 'a time zone with summer time uses its summer offset, and an unknown time zone stops the run before it writes' {
    $ws = New-TestWorkspace
    Set-ReliabilityCalendar $ws 'GMT Standard Time' '2026-03-30T07:00:00Z' '2026-03-30T10:00:00Z' '2026-03-30T11:00:00Z'
    $run = Invoke-Register $ws morning -Now '2026-03-30T07:30:00Z'
    Assert-Equal 0 $run.ExitCode "summer calendar, $($run.Output)"
    $page = [IO.File]::ReadAllText((Join-Path $ws 'views\morning.html'))
    Assert-Match $page '11:00' 'hour of the meeting in London summer time'
    Assert-True ($page -notmatch '10:00') 'the hour of the meeting in UTC is not shown'
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.timezone = 'A fictional invalid zone'
    Write-Json (Join-Path $ws 'settings.json') $settings
    $before = Get-WorkspaceSnapshot $ws
    $run = Invoke-Register $ws morning -Now '2026-03-30T07:30:00Z'
    Assert-Equal 1 $run.ExitCode 'invalid zone refused'
    Assert-Match $run.Output 'Unknown workspace timezone' 'timezone reason'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}
