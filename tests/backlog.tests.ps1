# The change proposal for the tracker: the agent only creates a ticket or edits its text, one
# change at a time, once the PO has approved that exact change; every applied change is logged.

function New-BacklogWorkspace([hashtable]$Tracker = @{ mode = 'folder'; folder = 'exports/tracker' }) {
    # A workspace whose tracker is declared as given, read from a folder of exported tickets by default,
    # with one ticket: ONB-142.
    $workspace = New-TestWorkspace
    $connections = Read-Json (Join-Path $workspace 'connections.json')
    $connections.tracker = $Tracker
    Write-Json (Join-Path $workspace 'connections.json') $connections
    $folder = Join-Path $workspace 'exports\tracker'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $folder 'ONB-142.txt'), "Key: ONB-142`nProject: ONB`nTitle: Scan screen`nStatus: In progress`n`nThe customer scans an identity document.`n", $Utf8)
    $workspace
}

function New-Change([hashtable]$Fields = @{}) {
    # One valid change: an edit of the title of ONB-142, approved by the PO. $Fields replaces or adds
    # fields; a $null value removes the field.
    $change = @{
        id = '1'; kind = 'edit'; ticket = 'ONB-142'; field = 'title'; before = 'Scan screen'; after = 'Identity document scan screen'
        reason = 'The title does not say what is scanned.'; source = @{ where = 'the PO, in conversation'; read_on = '2026-03-02' }; state = 'approved'
    }
    foreach ($name in $Fields.Keys) {
        if ($null -eq $Fields[$name]) { $change.Remove($name) } else { $change[$name] = $Fields[$name] }
    }
    $change
}

function Set-Changes([string]$Workspace, [object[]]$Changes) {
    Write-Json (Join-Path $Workspace 'state\backlog-changes.json') @{ changes = $Changes }
}

Test 'backlog check accepts a change proposal that creates a ticket and edits the text of another' {
    $ws = New-BacklogWorkspace
    Set-Changes $ws @(
        (New-Change),
        (New-Change @{ id = '2'; kind = 'create'; ticket = $null; field = $null; before = $null; project = 'ONB'; state = 'proposed'
                after = @{ title = 'Branch finder'; description = 'The customer finds the nearest branch.'; 'acceptance criteria' = 'Given a postcode, the three nearest branches are listed.' } })
    )

    $run = Invoke-Register $ws backlog check

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Change proposal: 2 change\(s\), valid\.' 'output'
}

Test 'backlog show gives one change as the exact text before and after, lines kept, and writes nothing' {
    $ws = New-BacklogWorkspace
    Set-Changes $ws @(
        (New-Change @{ field = 'description'; before = "The customer scans an identity document."; after = "The customer scans an identity document.`nThe scan is checked before the account opens." }),
        (New-Change @{ id = '2'; kind = 'create'; ticket = $null; field = $null; before = $null; project = 'ONB'; state = 'proposed'
                after = @{ title = 'Branch finder'; 'acceptance criteria' = 'Given a postcode, the three nearest branches are listed.' } })
    )
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws backlog show 1

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal ("Change 1: edit ticket ONB-142, field Description`nWhy: The title does not say what is scanned.`nSource: the PO, in conversation, read on 2026-03-02`n`n" +
        "Text before:`nThe customer scans an identity document.`n`nText after:`nThe customer scans an identity document.`nThe scan is checked before the account opens.") $run.Output 'the change shown'

    $run = Invoke-Register $ws backlog show 2

    Assert-Equal 0 $run.ExitCode "exit code of the create, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Change 2: create a ticket in project ONB$' 'the create shown'
    Assert-Match $run.Output "(?m)^Title:`n^Branch finder$" 'its title'
    Assert-Match $run.Output "(?m)^Acceptance criteria:`n^Given a postcode, the three nearest branches are listed\.$" 'its acceptance criteria'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'

    $run = Invoke-Register $ws backlog show 3

    Assert-Equal 1 $run.ExitCode "exit code for a change not proposed, with output: $($run.Output)"
    Assert-Match $run.Output "The change proposal holds no change '3'" 'output for a change not proposed'
}

Test 'with the tracker read from a folder, backlog apply writes the approved change in the outbox, marks it applied and logs it, once, leaving the other changes as they are' {
    $ws = New-BacklogWorkspace
    Set-Changes $ws @((New-Change), (New-Change @{ id = '2'; after = 'Document scan'; state = 'proposed' }))

    $run = Invoke-Register $ws backlog apply 1 -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Change 1 applied: written to outbox/tracker/1\.md, and logged in state/backlog-log\.json\.' 'output'
    $outbox = [IO.File]::ReadAllText((Join-Path $ws 'outbox\tracker\1.md'))
    Assert-Match $outbox "(?m)^Change 1: edit ticket ONB-142, field Title$" 'the outbox file'
    Assert-Match $outbox "(?m)^Text after:`n^Identity document scan screen$" 'the text after, in the outbox file'
    Assert-Equal 1 @(Get-ChildItem (Join-Path $ws 'outbox\tracker')).Count 'files of the outbox'
    $changes = @((Read-Json (Join-Path $ws 'state\backlog-changes.json')).changes)
    Assert-Equal 'applied proposed' "$($changes[0].state) $($changes[1].state)" 'states of the changes'
    $log = @((Read-Json (Join-Path $ws 'state\backlog-log.json')).applied)
    Assert-Equal 1 $log.Count 'entries of the log'
    Assert-Equal '2026-03-03|1|edit|ONB-142|title|Scan screen|Identity document scan screen|the PO|outbox/tracker/1.md' (
        @('date', 'change', 'kind', 'ticket', 'field', 'before', 'after', 'approved_by', 'applied' | ForEach-Object { $log[0].$_ }) -join '|') 'the entry of the log'
    Assert-Equal "Scan screen" (([IO.File]::ReadAllText((Join-Path $ws 'exports\tracker\ONB-142.txt')) -split "`n")[2] -replace '^Title: ') 'the ticket itself is left as it is'

    $before = Get-WorkspaceSnapshot $ws
    $run = Invoke-Register $ws backlog apply 1 -Today 2026-03-03

    Assert-Equal 1 $run.ExitCode "exit code when applied again, with output: $($run.Output)"
    Assert-Match $run.Output 'Change 1 is applied already, on 2026-03-03: a change is applied once\. Nothing was done\.' 'output when applied again'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace when applied again'
}

Test 'backlog apply refuses a change the PO has not approved, writing nothing' {
    $ws = New-BacklogWorkspace
    foreach ($state in 'proposed', 'accepted', 'refused') {
        Set-Changes $ws @(New-Change @{ state = $state })
        $before = Get-WorkspaceSnapshot $ws

        $run = Invoke-Register $ws backlog apply 1

        Assert-Equal 1 $run.ExitCode "exit code for a change $state, with output: $($run.Output)"
        Assert-Match $run.Output "Change 1 is $state, not approved: a change is applied only once the PO has approved it as backlog show gives it\. Nothing was done\." "output for a change $state"
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for a change $state"
    }
}

Test 'backlog apply refuses an edit whose text before the ticket no longer holds, so that the agent proposes it again' {
    $ws = New-BacklogWorkspace
    Set-Changes $ws @(New-Change @{ before = 'Scan page' })
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws backlog apply 1

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Change 1 is not applied: ticket ONB-142, as last read in exports/tracker/ONB-142\.txt, no longer holds its text before\. Nothing was done\. Tell the PO, read the ticket again and propose the change again\.' 'output'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'with a tracker connector that may write, backlog apply records the change the routine applied through it, and writes no outbox' {
    $ws = New-BacklogWorkspace @{ mode = 'connector'; connector = 'tracker'; writes = $true }
    Set-Changes $ws @(New-Change)

    $run = Invoke-Register $ws backlog apply 1 -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Change 1 recorded as applied through the connector, and logged' 'output'
    Assert-Equal 'through the connector' @((Read-Json (Join-Path $ws 'state\backlog-log.json')).applied)[0].applied 'how it was applied'
    Assert-True (-not (Test-Path (Join-Path $ws 'outbox'))) 'an outbox was written'
}

Test 'with a tracker that may not write, backlog apply gives the text to paste and where it goes, and records the change only once the PO says it is done' {
    foreach ($tracker in @{ mode = 'connector'; connector = 'tracker' }, @{ mode = 'connector'; connector = 'tracker'; writes = $false }, @{ mode = 'off' }) {
        $ws = New-BacklogWorkspace $tracker
        Set-Changes $ws @(New-Change)
        $before = Get-WorkspaceSnapshot $ws

        $run = Invoke-Register $ws backlog apply 1 -Today 2026-03-03

        Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
        Assert-Match $run.Output "(?m)^Text after:`n^Identity document scan screen$" 'the text to paste'
        Assert-Match $run.Output '(?m)^To paste in the tracker: in ticket ONB-142, replace the text before of the field Title with the text after\.' 'where it goes'
        Assert-Match $run.Output 'once the PO says it is done, record it: backlog apply 1 done' 'how it is recorded'
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace before the PO pasted it, tracker $($tracker.mode) $($tracker.writes)"

        $run = Invoke-Register $ws backlog apply 1 done -Today 2026-03-04

        Assert-Equal 0 $run.ExitCode "exit code once pasted, with output: $($run.Output)"
        Assert-Equal '2026-03-04 pasted by the PO' (@((Read-Json (Join-Path $ws 'state\backlog-log.json')).applied | ForEach-Object { "$($_.date) $($_.applied)" }) -join ', ') 'the log'
        Assert-Equal 'applied' @((Read-Json (Join-Path $ws 'state\backlog-changes.json')).changes)[0].state 'state of the change'
    }
}

Test 'the applied-change log is committed with the next apply of the register' {
    $ws = New-BacklogWorkspace
    git -C $ws add -A
    git -C $ws commit -q -m 'The tracker, read from a folder'
    Set-Changes $ws @(New-Change)
    $run = Invoke-Register $ws backlog apply 1 -Today 2026-03-03
    Assert-Equal 0 $run.ExitCode "exit code of backlog apply, with output: $($run.Output)"
    Assert-True (@(git -C $ws status --porcelain) -match 'state/backlog-log.json') 'the log is committed by backlog apply itself'

    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code of apply, with output: $($run.Output)"
    $committed = @(git -C $ws show --name-only --format= HEAD)
    Assert-True ($committed -contains 'state/backlog-log.json') "the commit lacks the log; it holds: $($committed -join ', ')"
}

Test 'the workspace rules, the backlog routine and the collect routine state the exception and its limits, and the rules give the change proposal its format' {
    $limits = '(?s)create a ticket or edit its text.+only after the PO.s approval of that exact change, one at a time.+never delete, close or move a ticket, never change another field'
    $rules = Get-Content -LiteralPath (Join-Path $KitRoot 'workspace-template\AGENTS.md') -Raw -Encoding UTF8
    Assert-Match $rules '(?s)you create a ticket or edit its text.+only after the PO approved that exact change, one change at a time; you never delete, close, reopen or move a ticket, and never change another field' 'the exception in the workspace rules'
    Assert-Match $rules '"id": "1", "kind": "edit", "ticket": "ONB-142", "field": "title"' 'the format of the change proposal'
    Assert-Match $rules '"writes": true' 'a tracker that may write'
    Assert-Match (Get-Content -LiteralPath (Join-Path $KitRoot 'routines\collect\SKILL.md') -Raw -Encoding UTF8) $limits 'the exception in the collect routine'
    $routine = Get-Content -LiteralPath (Join-Path $KitRoot 'routines\backlog\SKILL.md') -Raw -Encoding UTF8
    Assert-Match $routine 'Only after the PO approved that exact change, one change at a time' 'the approval in the backlog routine'
    Assert-Match $routine 'never delete, close, reopen or move a ticket, and you never change another field' 'the limits in the backlog routine'
}

Test 'backlog check refuses a change that would delete, close, reopen or move a ticket, or touch any field but its text, and says why, writing nothing' {
    $ws = New-BacklogWorkspace
    $refused = @(
        @{ change = (New-Change @{ kind = 'delete' }); reason = "field 'kind' is 'delete'; allowed: create, edit" }
        @{ change = (New-Change @{ kind = 'close' }); reason = "field 'kind' is 'close'" }
        @{ change = (New-Change @{ kind = 'reopen' }); reason = "field 'kind' is 'reopen'" }
        @{ change = (New-Change @{ kind = 'move' }); reason = "field 'kind' is 'move'" }
        @{ change = (New-Change @{ field = 'status' }); reason = "field 'field' is 'status'; allowed: title, description, acceptance criteria" }
        @{ change = (New-Change @{ field = 'assignee' }); reason = "field 'field' is 'assignee'" }
        @{ change = (New-Change @{ field = 'estimate' }); reason = "field 'field' is 'estimate'" }
        @{ change = (New-Change @{ field = 'sprint' }); reason = "field 'field' is 'sprint'" }
        @{ change = (New-Change @{ field = 'priority' }); reason = "field 'field' is 'priority'" }
        @{ change = (New-Change @{ field = 'labels' }); reason = "field 'field' is 'labels'" }
        @{ change = (New-Change @{ status = 'Done' }); reason = "unknown field 'status'" }
        @{ change = (New-Change @{ kind = 'create'; ticket = $null; field = $null; before = $null; project = 'ONB'; after = @{ title = 'Branch finder'; sprint = 'Sprint 12' } }); reason = "field 'after.sprint' is not a text of a ticket" }
    )
    foreach ($case in $refused) {
        Set-Changes $ws @($case.change)
        $before = Get-WorkspaceSnapshot $ws

        $run = Invoke-Register $ws backlog check

        Assert-Equal 1 $run.ExitCode "exit code for $($case.reason), with output: $($run.Output)"
        Assert-Match $run.Output 'Change proposal refused\.' "output for $($case.reason)"
        Assert-Match $run.Output ("- Change 1: " + [regex]::Escape($case.reason)) 'the reason'
        Assert-Match $run.Output 'deleting, closing, reopening or moving a ticket, and its status, assignee, estimate, sprint and priority, stay the PO''s' 'why'
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for $($case.reason)"
    }
}
