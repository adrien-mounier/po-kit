# export: the digest of the register that the weekly synthesis is written from.

$Tuesday = '2026-03-10T09:15:00+01:00'

function Get-WeekExport {
    # What export prints for the week of New-TestWorkspaceWithWeek, since 2026-03-10. export writes
    # nothing, so the command is run once and each test reads the part it is about.
    if (-not $script:WeekExport) {
        $run = Invoke-Register (New-TestWorkspaceWithWeek) export 2026-03-10 -Now $Tuesday
        Assert-Equal 0 $run.ExitCode "exit code of export, with output: $($run.Output)"
        $script:WeekExport = $run.Output
    }
    $script:WeekExport
}

function Get-Section([string]$Export, [string]$Heading) {
    # The lines an export holds under a heading, the empty ones left out.
    $under = $false
    @(foreach ($line in $Export -split '\r?\n') {
            if ($line -like '## *') { $under = $line -ceq "## $Heading" }
            elseif ($under -and $line) { $line }
        }) -join "`n"
}

Test 'export lists the active subjects, each with its horizon, its clearance and its client banks' {
    Assert-Equal (@(
            '- Branch kiosks pilot [branch-kiosks-pilot] | subject | reported | horizon: next | clearance: out of frame | banks: all'
            '- Mobile onboarding [mobile-onboarding] | subject | fact | horizon: now | clearance: cleared by the sponsor on 2026-02-20 | banks: all'
        ) -join "`n") (Get-Section (Get-WeekExport) 'Active subjects') 'active subjects'
}

Test 'export lists what changed since the date given, that date included: each record recorded since, and each field corrected since with its previous and its new value' {
    Assert-Equal (@(
            '- Order the kiosks [C-2026-003] | commitment | fact | subject: branch-kiosks-pilot | date of fact: 2026-03-02 | status: open | owner: the tech lead | due date: 2026-04-16 | changed 2026-03-10: due_date: 2026-04-02 -> 2026-04-16'
            '- Book the committee room [C-2026-005] | commitment | fact | subject: mobile-onboarding | date of fact: 2026-03-02 | status: done | owner: the PO | due date: 2026-03-06 | changed 2026-03-10: status: open -> done'
            '- Brief the branch managers [C-2026-006] | commitment | fact | subject: branch-kiosks-pilot | date of fact: 2026-03-09 | status: open | owner: the PO | due date: 2026-03-24 | recorded 2026-03-10'
            '- Suspend the presentation of the pilot [D-2026-005] | decision | fact | subject: mobile-onboarding | date of fact: 2026-03-09 | status: taken | decided by: the sponsor | recorded 2026-03-10'
            '- Customers keep asking for paper [R-2026-004] | risk | fact | subject: mobile-onboarding | date of fact: 2026-03-02 | status: open | severity: watch | changed 2026-03-10: subject'
        ) -join "`n") (Get-Section (Get-WeekExport) 'Changes since 2026-03-10') 'changes since the day of the second apply'

    $ws = New-TestWorkspaceWithWeek
    $run = Invoke-Register $ws export 2026-03-11 -Now $Tuesday
    Assert-Equal 0 $run.ExitCode "exit code since the day after, with output: $($run.Output)"
    Assert-Equal 'None.' (Get-Section $run.Output 'Changes since 2026-03-11') 'changes since the day after'

    # Since the day of the first apply, every record the export lists was recorded or changed.
    $run = Invoke-Register $ws export 2026-03-03 -Now $Tuesday
    Assert-Equal 0 $run.ExitCode "exit code since the first apply, with output: $($run.Output)"
    $changes = @((Get-Section $run.Output 'Changes since 2026-03-03') -split "`n")
    Assert-Equal 15 $changes.Count "records changed since the first apply, in: $($changes -join "`n")"
    Assert-True ($changes -ccontains '- Order the kiosks [C-2026-003] | commitment | fact | subject: branch-kiosks-pilot | date of fact: 2026-03-02 | status: open | owner: the tech lead | due date: 2026-04-16 | recorded 2026-03-03 | changed 2026-03-10: due_date: 2026-04-02 -> 2026-04-16') "the record recorded then corrected, in: $($changes -join "`n")"
}

Test 'export lists the open commitments with owner and due date, and says so when either is missing' {
    Assert-Equal (@(
            '- Send the onboarding figures to the sponsor [C-2026-002] | commitment | reported | subject: mobile-onboarding | date of fact: 2026-03-02 | status: open | owner: missing | due date: missing'
            '- Order the kiosks [C-2026-003] | commitment | fact | subject: branch-kiosks-pilot | date of fact: 2026-03-02 | status: open | owner: the tech lead | due date: 2026-04-16'
            # Still open on a subject that is closed: someone still owes it.
            '- Archive the paper statement templates [C-2026-004] | commitment | fact | subject: paper-statements (closed) | date of fact: 2026-03-02 | status: open | owner: the PO | due date: missing'
            '- Brief the branch managers [C-2026-006] | commitment | fact | subject: branch-kiosks-pilot | date of fact: 2026-03-09 | status: open | owner: the PO | due date: 2026-03-24'
        ) -join "`n") (Get-Section (Get-WeekExport) 'Open commitments') 'open commitments'
}

Test 'export lists the pending decisions grouped by the person awaited, whatever the case of the name, and says so when the person or the date is missing' {
    Assert-Equal (@(
            '### Awaited from: missing'
            '- Keep or drop the paper option at onboarding [D-2026-004] | decision | fact | subject: mobile-onboarding | date of fact: 2026-03-02 | status: pending | needed from: missing | needed by: 2026-04-30'
            '### Awaited from: the sponsor'
            '- Choose the pilot branches [D-2026-001] | decision | fact | subject: mobile-onboarding | date of fact: 2026-03-02 | status: pending | needed from: the sponsor | needed by: 2026-03-27'
            '- Name the kiosk supplier [D-2026-003] | decision | fact | subject: branch-kiosks-pilot | date of fact: 2026-03-02 | status: pending | needed from: The sponsor | needed by: missing'
            '### Awaited from: the tech lead'
            '- Fund the kiosk maintenance [D-2026-002] | decision | fact | subject: branch-kiosks-pilot | date of fact: 2026-03-02 | status: pending | needed from: the tech lead | needed by: missing'
        ) -join "`n") (Get-Section (Get-WeekExport) 'Pending decisions') 'pending decisions'
}

Test 'export says how each source is covered: its mode, whether the last collect read it, and how far it was last read' {
    Assert-Equal (@(
            '- notes | mode: folder | covered: yes | read up to 2026-03-10T08:12:00+01:00 by the collect of 2026-03-10T08:30:00+01:00: 2 item(s)'
            '- mail | mode: folder | covered: no | read up to 2026-03-03T08:20:00+01:00 by the collect of 2026-03-03T08:30:00+01:00: 14 item(s)'
            '- tracker | mode: off | covered: no | never read'
            '- chat | mode: off | covered: no | never read'
        ) -join "`n") (Get-Section (Get-WeekExport) 'Coverage per source') 'coverage after two collects'

    $ws = New-TestWorkspaceWithSubject
    $run = Invoke-Register $ws export 2026-03-02 -Now $Tuesday
    Assert-Equal 0 $run.ExitCode "exit code before any collect, with output: $($run.Output)"
    Assert-Equal (@(
            '- notes | mode: folder | covered: no | never read'
            '- mail | mode: off | covered: no | never read'
            '- tracker | mode: off | covered: no | never read'
            '- chat | mode: off | covered: no | never read'
        ) -join "`n") (Get-Section $run.Output 'Coverage per source') 'coverage before any collect'
}

Test 'export says of a source that the last collect stopped at the cap, so that the synthesis can say it was read only in part' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{
        collected_at = '2026-03-10T08:30:00+01:00'
        sources_read = @(
            @{ source = 'notes'; cutoff = '2026-03-10T08:30:00+01:00'; items = 1 },
            @{ source = 'mail'; cutoff = '2026-03-09T16:45:00+01:00'; items = 50; cap_reached = $true }
        )
    }
    $collect = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $collect.ExitCode "exit code of the collect, with output: $($collect.Output)"

    $run = Invoke-Register $ws export 2026-03-10 -Now $Tuesday

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal (@(
            '- notes | mode: folder | covered: yes | read up to 2026-03-10T08:30:00+01:00 by the collect of 2026-03-10T08:30:00+01:00: 1 item(s)'
            '- mail | mode: off | covered: yes | read up to 2026-03-09T16:45:00+01:00 by the collect of 2026-03-10T08:30:00+01:00: 50 item(s), cap reached: the rest waits for the next collect'
            '- tracker | mode: off | covered: no | never read'
            '- chat | mode: off | covered: no | never read'
        ) -join "`n") (Get-Section $run.Output 'Coverage per source') 'coverage after a collect that stopped at the cap'
}

Test 'export ends with the portfolio view as view writes it under its stamp, in the language of the sponsor' {
    $ws = New-TestWorkspaceWithWeek

    foreach ($sponsor in @{ language = 'fr'; now = 'Maintenant' }, @{ language = 'en'; now = 'Now' }) {
        $settings = Read-Json (Join-Path $ws 'settings.json')
        $settings.languages.sponsor = $sponsor.language
        Write-Json (Join-Path $ws 'settings.json') $settings
        $run = Invoke-Register $ws export 2026-03-10 -Now $Tuesday
        Assert-Equal 0 $run.ExitCode "exit code of export for a sponsor who reads '$($sponsor.language)', with output: $($run.Output)"
        $view = Invoke-Register $ws view $sponsor.language -Now $Tuesday
        Assert-Equal 0 $view.ExitCode "exit code of view $($sponsor.language), with output: $($view.Output)"

        # The view: its title, its stamp, then every subject under its horizon.
        $written = [IO.File]::ReadAllText((Join-Path $ws 'views\portfolio.md'), $Utf8) -replace '\r\n', "`n"
        $horizons = $written.Substring($written.IndexOf("## $($sponsor.now)`n"))
        Assert-Match $horizons '\| Mobile onboarding \[mobile-onboarding\] +\| ' "the view written in '$($sponsor.language)'"
        Assert-True ($run.Output + "`n").EndsWith("`n## Portfolio view`n`n$horizons") "the export does not end with the portfolio view in '$($sponsor.language)':`n$($run.Output)"
    }
}

Test 'export counts the records attached to each objective of the settings' {
    # Three records name the objective 3: one is closed. The record that names the objective 5 is a
    # commitment still open on a closed subject.
    Assert-Equal (@(
            '- Objective 1, Halve the time to open an account: 3 record(s)'
            '- Objective 3, Bring the branch network on board: 1 record(s)'
            '- Objective 5, Retire the paper statements: 1 record(s)'
        ) -join "`n") (Get-Section (Get-WeekExport) 'Records per objective') 'records per objective'
}

Test 'a record that is superseded or closed, and a closed subject, are listed in no section, and their identifiers are cited nowhere in the export' {
    # Since the first apply, so that the export says all it can of every record.
    $run = Invoke-Register (New-TestWorkspaceWithWeek) export 2026-03-03 -Now $Tuesday

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $left = 'C-2026-001', 'Present the onboarding pilot', 'R-2026-003', 'The print contract', '[paper-statements]', 'Paper statements'
    foreach ($text in $left) { Assert-True ($run.Output -cnotmatch [regex]::Escape($text)) "'$text' appears in the export: $($run.Output)" }
    # The record that supersedes, and the record that left the closed subject, are listed.
    Assert-Match $run.Output '(?m)^- Suspend the presentation of the pilot \[D-2026-005\] ' 'the decision that supersedes the commitment'
    Assert-Match $run.Output '(?m)^- Customers keep asking for paper \[R-2026-004\] ' 'the risk that left the closed subject'
}

Test 'a commitment, a decision or a risk still open on a closed subject is listed, and its line says that its subject is closed; what is done, taken or closed on that subject stays out' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(
            (New-RecordOperation commitment @{ title = 'Hand the onboarding guide over to the branch network'; owner = 'the PO' }),
            (New-RecordOperation commitment @{ title = 'Book the committee room'; status = 'done' }),
            (New-RecordOperation decision @{ title = 'Choose who maintains the onboarding guide'; needed_from = 'the sponsor' }),
            (New-RecordOperation decision @{ title = 'Stop the pilot'; status = 'taken'; decided_by = 'the sponsor' }),
            (New-RecordOperation risk @{ title = 'Nobody maintains the onboarding guide' }),
            (New-RecordOperation risk @{ title = 'The pilot branches are not staffed'; status = 'closed' }),
            (New-UpdateOperation 'mobile-onboarding' @{ status = 'closed' })
        )
    }
    $applied = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $applied.ExitCode "exit code of apply, with output: $($applied.Output)"

    $run = Invoke-Register $ws export 2026-03-10 -Now $Tuesday

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $said = 'fact | subject: mobile-onboarding (closed) | date of fact: 2026-03-02'
    Assert-Equal "- Hand the onboarding guide over to the branch network [C-2026-001] | commitment | $said | status: open | owner: the PO | due date: missing" (Get-Section $run.Output 'Open commitments') 'open commitments'
    Assert-Equal "### Awaited from: the sponsor`n- Choose who maintains the onboarding guide [D-2026-001] | decision | $said | status: pending | needed from: the sponsor | needed by: missing" (Get-Section $run.Output 'Pending decisions') 'pending decisions'
    Assert-Equal "- Nobody maintains the onboarding guide [R-2026-001] | risk | $said | status: open | severity: watch" (Get-Section $run.Output 'Open risks') 'open risks'
    Assert-Equal 'None.' (Get-Section $run.Output 'Active subjects') 'active subjects'
    $left = 'C-2026-002', 'Book the committee room', 'D-2026-002', 'Stop the pilot', 'R-2026-002', 'not staffed', '[mobile-onboarding]', 'Mobile onboarding'
    foreach ($text in $left) { Assert-True ($run.Output -cnotmatch [regex]::Escape($text)) "'$text' appears in the export: $($run.Output)" }
}

Test 'export includes the stamp of the view to write from it, as view writes it, in the language of the sponsor' {
    $ws = New-TestWorkspaceWithWeek
    $state = "$(git -C $ws rev-parse HEAD:register)".Substring(0, 12)
    $english = "> Generated: $Tuesday.`n> Register state: $state.`n> Last collect: 2026-03-10T08:30:00+01:00.`n> Sources not covered by the last collect: mail, tracker, chat."
    Assert-Equal $english (Get-Section (Get-WeekExport) 'Stamp') 'stamp when the sponsor reads English'

    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.languages.sponsor = 'fr'
    Write-Json (Join-Path $ws 'settings.json') $settings
    $run = Invoke-Register $ws export 2026-03-10 -Now $Tuesday
    Assert-Equal 0 $run.ExitCode "exit code when the sponsor reads French, with output: $($run.Output)"
    $view = Invoke-Register $ws view fr -Now $Tuesday
    Assert-Equal 0 $view.ExitCode "exit code of view fr, with output: $($view.Output)"
    $french = @([IO.File]::ReadAllText((Join-Path $ws 'views\portfolio.md'), $Utf8) -split '\r?\n' | Where-Object { $_ -like '> *' }) -join "`n"
    Assert-Match $french 'registre : ' 'the stamp of the French portfolio view'
    Assert-Equal $french (Get-Section $run.Output 'Stamp') 'stamp when the sponsor reads French'
    # Only the stamp is in the language: the export is read by the agent, as the preview is.
    Assert-Equal (Get-Section (Get-WeekExport) 'Open commitments') (Get-Section $run.Output 'Open commitments') 'open commitments when the sponsor reads French'
}

Test 'export writes nothing in the workspace, and prints the same for the same register state and the same dates' {
    $ws = New-TestWorkspaceWithWeek
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws export 2026-03-10 -Now $Tuesday

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '^# Export of the register since 2026-03-10\n' 'first line of the export'
    # Get-WeekExport ran the same command on another workspace that holds the same register.
    Assert-Equal (Get-WeekExport) $run.Output 'the export printed a second time'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'export without the date its period starts on, with a date that is not an ISO date or for a sponsor whose language has no labels is refused' {
    $ws = New-TestWorkspaceWithWeek
    $before = Get-WorkspaceSnapshot $ws
    $refusals = @(
        @{ arguments = @(); reason = 'export takes the date its period starts on, as an ISO date \(yyyy-mm-dd\)' },
        @{ arguments = @('10/03/2026'); reason = "as an ISO date \(yyyy-mm-dd\), not '10/03/2026'" },
        @{ arguments = @('fr'); reason = "as an ISO date \(yyyy-mm-dd\), not 'fr'" },
        @{ arguments = @('2026-03-10'); sponsor = 'de'; reason = "Unsupported language 'de'.*Languages: en, fr\..*languages\.sponsor for export" }
    )
    foreach ($refusal in $refusals) {
        if ($refusal.sponsor) {
            $settings = Read-Json (Join-Path $ws 'settings.json')
            $settings.languages.sponsor = $refusal.sponsor
            Write-Json (Join-Path $ws 'settings.json') $settings
            $before = Get-WorkspaceSnapshot $ws
        }
        $arguments = $refusal.arguments
        $run = Invoke-Register $ws export @arguments -Now $Tuesday

        Assert-Equal 1 $run.ExitCode "exit code of export $arguments, with output: $($run.Output)"
        Assert-Match $run.Output $refusal.reason "output of export $arguments"
        Assert-True ($run.Output -notmatch '## ') "export $arguments printed a section: $($run.Output)"
    }
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'export refuses to run when the register differs from its last commit, as its stamp names a committed register' {
    $ws = New-TestWorkspaceWithWeek
    $record = Join-Path $ws 'register\commitments\2026\C-2026-001.json'
    [IO.File]::WriteAllText($record, [IO.File]::ReadAllText($record).Replace('"superseded"', '"open"'), $Utf8)

    $run = Invoke-Register $ws export 2026-03-10 -Now $Tuesday

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'The register differs from its last commit' 'output'
    Assert-Match $run.Output '- modified: register/commitments/2026/C-2026-001\.json' 'file listed'
    Assert-True ($run.Output -notmatch '## ') "export printed a section: $($run.Output)"
}

Test 'export shows the next date of a subject only once it is confirmed, as the portfolio view does: among the changes too' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(New-UpdateOperation 'mobile-onboarding' @{ next_step = 'Present the target journey'; next_date = '2026-04-01' }) }
    $dated = Invoke-Register $ws apply -Today 2026-03-10
    Assert-Equal 0 $dated.ExitCode "exit code when the date is recorded, with output: $($dated.Output)"

    $run = Invoke-Register $ws export 2026-03-10 -Now 2026-03-10T09:15:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'changed 2026-03-10: next_step: \(none\) -> Present the target journey' 'the change of the next step'
    Assert-True ($run.Output -notmatch '2026-04-01') "the date that is not confirmed appears in the export: $($run.Output)"

    Set-Proposal $ws @{ operations = @(New-UpdateOperation 'mobile-onboarding' @{ next_date_confirmed = $true }) }
    $confirmed = Invoke-Register $ws apply -Today 2026-03-11
    Assert-Equal 0 $confirmed.ExitCode "exit code when the date is confirmed, with output: $($confirmed.Output)"

    $run = Invoke-Register $ws export 2026-03-10 -Now 2026-03-11T09:15:00+01:00

    Assert-Match $run.Output 'changed 2026-03-10: next_date: \(none\) -> 2026-04-01' 'the change of the next date, once confirmed'
}

Test 'export lists the open risks with their severity, the urgent ones first' {
    Assert-Equal (@(
            '- The kiosk supplier may withdraw [R-2026-002] | risk | fact | subject: branch-kiosks-pilot | date of fact: 2026-03-02 | status: open | severity: urgent | owner: the tech lead'
            '- The pilot branches are not staffed [R-2026-001] | risk | hypothesis | subject: mobile-onboarding | date of fact: 2026-03-02 | status: open | severity: watch'
            '- Customers keep asking for paper [R-2026-004] | risk | fact | subject: mobile-onboarding | date of fact: 2026-03-02 | status: open | severity: watch'
        ) -join "`n") (Get-Section (Get-WeekExport) 'Open risks') 'open risks'
}
