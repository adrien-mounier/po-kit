# Backlog health: the alerts the agent keeps in state\backlog-alerts.json on the tickets of the
# watched projects (a ticket open for work a decision dropped, two tickets for the same need, a
# ticket not ready for a refinement session near, a stale ticket), checked by the register tool and
# counted on the morning page.

# Monday 2 March 2026; the onboarding refinement meets on Wednesday 4 March.
$AlertsNow = '2026-03-02T07:12:00+01:00'

function New-AlertsWorkspace {
    # A workspace of Example Bank seen on Monday 2 March 2026, its tracker read from a folder:
    #   D-2026-001  taken: the paper form is dropped
    #   D-2026-002  taken, then superseded by D-2026-003
    # The calendar snapshot, read today, holds the onboarding refinement of Wednesday 4.
    $workspace = New-TestWorkspace
    $connections = Read-Json (Join-Path $workspace 'connections.json')
    $connections.tracker = @{ mode = 'folder'; folder = 'exports/tracker' }
    $connections | Add-Member -NotePropertyName calendar -NotePropertyValue @{ mode = 'folder'; folder = 'exports\calendar' } -Force
    Write-Json (Join-Path $workspace 'connections.json') $connections
    $d = { param($Fields) New-RecordOperation decision (@{ subject = 'line 1'; status = 'taken'; decided_by = 'the sponsor' } + $Fields) }
    Set-Proposal $workspace @{ operations = @(
            (New-SubjectOperation @{ watch_list = @{ people = @('the tech lead'); tracker_projects = @('ONB') } }),
            (& $d @{ title = 'Drop the paper form' }),
            (& $d @{ title = 'Keep the branch finder out of the pilot' })
        )
    }
    $run = Invoke-Register $workspace apply -Today 2026-03-01
    Assert-Equal 0 $run.ExitCode "exit code when recording the portfolio, with output: $($run.Output)"
    Set-Proposal $workspace @{ operations = @(New-RecordOperation decision @{ title = 'Put the branch finder in the pilot'; status = 'taken'; decided_by = 'the sponsor'; supersedes = 'D-2026-002' }) }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when superseding the decision, with output: $($run.Output)"
    Set-AlertsCalendar $workspace @(@{ start = '2026-03-04T10:00:00+01:00'; end = '2026-03-04T11:00:00+01:00'; title = 'Onboarding refinement'; attendees = @('the tech lead'); status = 'accepted' })
    $workspace
}

function Set-AlertsCalendar([string]$Workspace, [object[]]$Meetings) {
    Write-Json (Join-Path $Workspace 'state\calendar.json') @{ read_at = '2026-03-02T07:05:00+01:00'; from = '2026-02-27'; to = '2026-03-16'; meetings = @($Meetings); absences = @() }
}

function New-Alerts([hashtable]$Parts = @{}) {
    # Valid alerts, one of each kind. $Parts replaces a kind.
    $alerts = @{
        contradictions = @(@{ ticket = 'ONB-150'; title = 'Build the paper form fallback'; decision = 'D-2026-001'; why = 'the paper form is dropped' })
        duplicates     = @(@{ ticket = 'ONB-163'; title = 'Find the nearest branch'; same_as = 'ONB-151'; why = 'both let the customer find the branch nearest to them' })
        not_ready      = @(@{ ticket = 'ONB-151'; title = 'Branch finder'; missing = @('acceptance criteria', 'estimate') }, @{ ticket = 'ONB-152'; title = 'Selfie check'; missing = @('dependency'); waits_for = 'ONB-140' })
        stale          = @(@{ ticket = 'ONB-120'; title = 'Language switch'; updated = '2025-12-15' })
    }
    foreach ($name in $Parts.Keys) { $alerts[$name] = $Parts[$name] }
    $alerts
}

function Set-Alerts([string]$Workspace, [hashtable]$Alerts) {
    Write-Json (Join-Path $Workspace 'state\backlog-alerts.json') $Alerts
}

Test 'backlog alerts checks the alerts of state\backlog-alerts.json, lists them, and names the refinement session near whose tickets not ready to list' {
    $ws = New-AlertsWorkspace
    Set-Alerts $ws (New-Alerts)
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws backlog alerts -Now $AlertsNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Backlog alerts: 1 contradiction\(s\), 1 duplicate\(s\), 2 not ready, 1 stale; valid\.$' 'the counts'
    Assert-Match $run.Output '(?m)^- ONB-150 is open for work D-2026-001 dropped: the paper form is dropped$' 'a contradiction'
    Assert-Match $run.Output '(?m)^- ONB-163 describes the same need as ONB-151: both let the customer find the branch nearest to them$' 'a duplicate'
    Assert-Match $run.Output '(?m)^- ONB-152 is not ready: waits for ONB-140$' 'a ticket not ready'
    Assert-Match $run.Output '(?m)^- ONB-120 is stale: no update for 77 days$' 'a stale ticket'
    Assert-Match $run.Output '(?m)^Refinement session to prepare: Onboarding refinement on 2026-03-04\. List under not_ready the tickets not ready for it\.$' 'the refinement session'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'backlog alerts refuses the file whole, saying why: a decision missing, superseded or no decision, a ticket updated within the delay of a stale ticket, a ticket its own duplicate, a dependency without the ticket it waits for, and any field that names who works on a ticket' {
    $ws = New-AlertsWorkspace
    $refused = {
        param([hashtable]$Parts, [string]$Reason)
        Set-Alerts $ws (New-Alerts $Parts)
        $run = Invoke-Register $ws backlog alerts -Now $AlertsNow
        Assert-Equal 1 $run.ExitCode "exit code for $Reason, with output: $($run.Output)"
        Assert-Match $run.Output '(?m)^Backlog alerts refused: state\\backlog-alerts\.json is left off the morning page\.$' "the refusal for $Reason"
        Assert-Match $run.Output "(?m)^- $Reason$" 'the reason'
    }
    $against = { param($Decision) @{ contradictions = @(@{ ticket = 'ONB-150'; title = 'Paper form'; decision = $Decision; why = 'dropped' }) } }

    & $refused (& $against 'D-2026-009') 'D-2026-009 is not in the register\.'
    & $refused (& $against 'D-2026-002') 'D-2026-002 is superseded by D-2026-003\.'
    & $refused (& $against 'mobile-onboarding') 'ONB-150: mobile-onboarding is no decision\.'
    & $refused @{ stale = @(@{ ticket = 'ONB-120'; title = 'Language switch'; updated = '2026-01-05' }) } 'ONB-120: updated 56 day\(s\) ago, it is not stale: a ticket is stale after 60 days without an update\.'
    & $refused @{ duplicates = @(@{ ticket = 'ONB-151'; title = 'Branch finder'; same_as = 'ONB-151'; why = 'same' }) } 'ONB-151: a ticket is no duplicate of itself\.'
    & $refused @{ not_ready = @(@{ ticket = 'ONB-152'; title = 'Selfie check'; missing = @('dependency') }) } 'ONB-152: a dependency not cleared names the ticket it waits for in waits_for\.'
    & $refused @{ not_ready = @(@{ ticket = 'ONB-152'; title = 'Selfie check'; missing = @('owner') }) } 'Alerts: field ''not_ready\.missing'' is ''owner''; allowed: acceptance criteria, estimate, dependency\.'
    & $refused @{ stale = @(@{ ticket = 'ONB-120'; title = 'Language switch'; updated = '2025-12-15'; assignee = 'the tech lead' }) } 'Alerts: unknown field ''stale\.assignee''\.'
}

Test 'the delay of a stale ticket is delays_in_days.ticket of the settings, 60 days in the template, and the words that show a refinement session in a meeting title are refinement_words, "refinement" and "backlog grooming" in the template, whatever the case' {
    $template = Read-Json (Join-Path $KitRoot 'workspace-template\settings.json')
    Assert-Equal 60 $template.delays_in_days.ticket 'the default delay'
    Assert-Equal 'refinement, backlog grooming' (@($template.refinement_words) -join ', ') 'the default words'

    $ws = New-AlertsWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.delays_in_days | Add-Member -NotePropertyName ticket -NotePropertyValue 30 -Force
    $settings | Add-Member -NotePropertyName refinement_words -NotePropertyValue @('Sprint Planning') -Force
    Write-Json (Join-Path $ws 'settings.json') $settings
    Set-Alerts $ws (New-Alerts @{ stale = @(@{ ticket = 'ONB-120'; title = 'Language switch'; updated = '2026-01-05' }) })
    Set-AlertsCalendar $ws @(
        @{ start = '2026-03-04T10:00:00+01:00'; end = '2026-03-04T11:00:00+01:00'; title = 'Onboarding refinement'; attendees = @(); status = 'accepted' },
        @{ start = '2026-03-05T10:00:00+01:00'; end = '2026-03-05T11:00:00+01:00'; title = 'Onboarding sprint planning'; attendees = @(); status = 'accepted' },
        @{ start = '2026-03-12T10:00:00+01:00'; end = '2026-03-12T11:00:00+01:00'; title = 'Payments sprint planning'; attendees = @(); status = 'accepted' }
    )

    $run = Invoke-Register $ws backlog alerts -Now $AlertsNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^- ONB-120 is stale: no update for 56 days$' 'stale after the delay of the settings'
    Assert-Match $run.Output '(?m)^Refinement session to prepare: Onboarding sprint planning on 2026-03-05\.' 'the session the settings'' words show'
    Assert-True ($run.Output -notmatch 'Onboarding refinement|Payments sprint planning') "a meeting the words do not show, or one beyond five working days, is named: $($run.Output)"

    Remove-Item (Join-Path $ws 'state\backlog-alerts.json')
    Set-AlertsCalendar $ws @()
    $run = Invoke-Register $ws backlog alerts -Now $AlertsNow
    Assert-Equal 0 $run.ExitCode "exit code without alerts, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^No backlog alerts: state\\backlog-alerts\.json does not exist\.$' 'without the file'
    Assert-Match $run.Output '(?m)^No refinement session within five working days' 'without a session near'
}

function Get-AlertsBlock([string]$Workspace) {
    $page = [IO.File]::ReadAllText((Join-Path $Workspace 'views\morning.html'), $Utf8)
    if ($page -match '(?s)<section class="block" id="backlog".*?</section>') { $Matches[0] }
}

function Get-AlertsCount([string]$Block) {
    if ($Block -match '(?s)<span class="count">(.*?)</span></h2>') { [Net.WebUtility]::HtmlDecode(($Matches[1] -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()) }
}

function Get-AlertsRows([string]$Block) {
    # Each line of the block as a reader sees it.
    @([regex]::Matches($Block, '(?s)<li class="row[^"]*">.*?</li>') | ForEach-Object { [Net.WebUtility]::HtmlDecode(($_.Value -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim()) })
}

Test 'the morning page counts the backlog alerts: a red line per ticket open for work a decision dropped, then the duplicates, the tickets not ready for the refinement session near and the stale ones, folded' {
    $ws = New-AlertsWorkspace
    Set-Alerts $ws (New-Alerts)

    $run = Invoke-Register $ws morning -Now $AlertsNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Get-AlertsBlock $ws
    Assert-Equal '1 contradict(s) a decision, 1 possible duplicate(s), 2 not ready for Onboarding refinement, Wed 4, 1 stale, not read: tracker' (Get-AlertsCount $block) 'counts of the backlog alerts'
    Assert-Match $block '<span class="count"><span class="late">1 contradict\(s\) a decision</span>' 'the contradiction counted in red'
    Assert-Equal (@(
        'ONB-150 Build the paper form fallback against D-2026-001: the paper form is dropped mobile-onboarding Show conflict'
        'ONB-163 Find the nearest branch same need as ONB-151: both let the customer find the branch nearest to them Compare'
        'ONB-151 Branch finder not ready: no acceptance criteria, no estimate What it needs'
        'ONB-152 Selfie check not ready: waits for ONB-140 What it needs'
        'ONB-120 Language switch stale: no update for 77 days Close or keep'
    ) -join "`n") ((Get-AlertsRows $block) -join "`n") 'the lines, in order'
    Assert-Match $block '(?s)</ul>\s*<details class="more">.*ONB-163' 'the lines after the contradictions folded'
    Assert-Match $block 'data-ask="Compare ONB-163 with ONB-151 and tell me which to keep"' 'the PO decides on a duplicate'
    Assert-Match $run.Output '(?m)^Backlog alerts 1 contradict\(s\) a decision, 1 possible duplicate\(s\), 2 not ready for Onboarding refinement, Wed 4, 1 stale, not read: tracker$' 'what morning prints'

    # With no refinement session near, the tickets not ready are left off.
    Set-AlertsCalendar $ws @()
    Invoke-Register $ws morning -Now $AlertsNow | Out-Null
    $block = Get-AlertsBlock $ws
    Assert-Equal '1 contradict(s) a decision, 1 possible duplicate(s), 1 stale, not read: tracker' (Get-AlertsCount $block) 'counts without a session near'
    Assert-True ($block -notmatch 'ONB-152') "a ticket not ready is shown with no session near: $block"
}

Test 'without backlog alerts the block says the agent wrote none; alerts refused leave the block saying they could not be written, and morning prints why' {
    $ws = New-AlertsWorkspace

    Invoke-Register $ws morning -Now $AlertsNow | Out-Null

    Assert-Equal 'the agent wrote nothing for it, not read: tracker' (Get-AlertsCount (Get-AlertsBlock $ws)) 'without the file'

    Set-Alerts $ws (New-Alerts @{ contradictions = @(@{ ticket = 'ONB-150'; title = 'Paper form'; decision = 'D-2026-002'; why = 'dropped' }) })
    $run = Invoke-Register $ws morning -Now $AlertsNow

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $block = Get-AlertsBlock $ws
    Assert-Equal 'could not be written, not read: tracker' (Get-AlertsCount $block) 'refused'
    Assert-True ($block -notmatch 'ONB-1') "a line of the refused file is shown: $block"
    Assert-Match $run.Output '(?m)^Not verified: state\\backlog-alerts\.json\..*\n- D-2026-002 is superseded by D-2026-003\.$' 'what morning prints'
}
