# The governance checklist, every subject with the state of each gate of the organisation, and the
# objectives evidence, the records that show each objective of the PO.

$Morning = '2026-03-02T09:15:00+01:00'

function New-GovernanceWorkspace([object[]]$Operations) {
    # A workspace whose settings list the gates, the objectives and the client banks of Example
    # Bank, and whose register holds these records, recorded on 2 March 2026.
    $ws = New-TestWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.gates = @('architecture review', 'security review')
    $settings.objectives = @(@{ number = 1; title = 'Halve the time to open an account' }, @{ number = 2; title = 'Serve every client bank from one platform' })
    $settings.banks = @('Harbour Bank', 'North Bank')
    Write-Json (Join-Path $ws 'settings.json') $settings
    git -C $ws commit -q -am 'Gates, objectives and client banks'
    Set-Proposal $ws @{ operations = @($Operations) }
    $run = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording, with output: $($run.Output)"
    $ws
}

function Read-View([string]$Workspace, [string]$Name) {
    [IO.File]::ReadAllText((Join-Path $Workspace "views\$Name"), $Utf8) -replace '\r\n', "`n"
}

function Get-Section([string]$View, [string]$Heading) {
    # The lines under a heading of the view, up to the next heading of the same or a higher level,
    # blank lines left out. Table rows come with their cells joined by ' | ', header rows left out.
    $level = ($Heading -split ' ')[0]
    $under = $false
    $rows = @(foreach ($line in $View -split "`n") {
            if ($line -ceq $Heading) { $under = $true; continue }
            if ($under -and $line -match '^(#+) ' -and $Matches[1].Length -le $level.Length) { $under = $false }
            if ($under -and $line.Trim()) { $line }
        })
    $table = @($rows | Where-Object { $_ -like '|*' })
    if ($table) { return @($table | Select-Object -Skip 2 | ForEach-Object { @($_.Trim('|').Split('|') | ForEach-Object { $_.Trim() }) -join ' | ' }) }
    $rows
}

$Gates = { param([string]$Architecture, [string]$Security)
    # A list even when it holds one gate.
    , @(if ($Architecture) { @{ name = 'architecture review'; state = $Architecture } }
        if ($Security) { @{ name = 'security review'; state = $Security } })
}

Test 'view governance shows every active subject with its clearance and the state of each gate the settings list, and lists apart those missing a gate or out of frame' {
    $ws = New-GovernanceWorkspace @(
        (New-SubjectOperation @{ title = 'Mobile onboarding'; clearance = 'out of frame'; gates = (& $Gates 'done' 'missing') }),
        (New-SubjectOperation @{ title = 'Credit memo drafting'; horizon = 'next'; clearance = 'cleared'; cleared_by = 'the sponsor'; cleared_on = '2026-02-20'; gates = (& $Gates 'done' 'planned') }),
        (New-SubjectOperation @{ title = 'Complaint triage assistant'; horizon = 'later'; clearance = 'pending'; gates = (& $Gates 'missing' $null) }),
        (New-SubjectOperation @{ title = 'Paper statements'; horizon = 'later'; gates = (& $Gates 'not required' 'unknown') })
    )

    $run = Invoke-Register $ws view governance -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'views\\governance\.md' 'output'
    $view = Read-View $ws 'governance.md'
    Assert-Match $view "^# Governance checklist\n\n> Generated: 2026-03-02T09:15:00\+01:00\.\n" 'title and stamp'
    Assert-Match $view '\| Subject +\| Clearance +\| architecture review \| security review \|' 'one column per gate of the settings'
    Assert-Equal (@(
            'Complaint triage assistant [complaint-triage-assistant] | Pending | **Missing** | -',
            'Credit memo drafting [credit-memo-drafting] | Cleared by the sponsor on 2026-02-20 | Done | Planned',
            'Mobile onboarding [mobile-onboarding] | **Out of frame** | Done | **Missing**',
            'Paper statements [paper-statements] | None | Not required | Unknown') -join "`n") ((Get-Section $view '## Gates') -join "`n") 'every subject by title, each gate in its column'
    Assert-Equal (@(
            '- Complaint triage assistant [complaint-triage-assistant]: missing: architecture review',
            '- Mobile onboarding [mobile-onboarding]: out of frame; missing: security review') -join "`n") ((Get-Section $view '## Needs attention') -join "`n") 'the subjects missing a gate or out of frame'
    Assert-True ([IO.File]::ReadAllBytes((Join-Path $ws 'views\governance.md'))[0] -ne 0xEF) 'the view opens with a byte order mark'
    $verify = Invoke-Register $ws verify views\governance.md
    Assert-Equal 0 $verify.ExitCode "verify of the view, with output: $($verify.Output)"
}

Test 'view governance keeps to one client bank and writes in French, and says so when nothing needs attention or the settings list no gate' {
    $ws = New-GovernanceWorkspace @(
        (New-SubjectOperation @{ title = 'Mobile onboarding'; banks = @('Harbour Bank'); gates = (& $Gates 'done' 'done') }),
        (New-SubjectOperation @{ title = 'Payment dispute triage'; banks = @('North Bank'); clearance = 'out of frame'; gates = (& $Gates 'missing' $null) })
    )

    $run = Invoke-Register $ws view governance fr bank Harbour Bank -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-View $ws 'governance.md'
    $e = [char]0xE9
    Assert-Match $view "> Filtr${e}e sur la banque cliente Harbour Bank" 'the stamp names the bank'
    Assert-Equal "Mobile onboarding [mobile-onboarding] (Harbour Bank) | Aucun | Fait | Fait" ((Get-Section $view "## Validations") -join "`n") 'the subject of Harbour Bank, in French'
    Assert-True ($view -notmatch 'payment-dispute-triage') 'the subject of North Bank is shown'
    Assert-Match $view "## $([char]0xC0) traiter\n\nRien $([char]0xE0) traiter\." 'nothing needs attention'

    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.gates = @()
    Write-Json (Join-Path $ws 'settings.json') $settings
    git -C $ws commit -q -am 'No gate'
    $run = Invoke-Register $ws view governance -Now $Morning
    Assert-Equal 0 $run.ExitCode "exit code without gates, with output: $($run.Output)"
    Assert-Match (Read-View $ws 'governance.md') 'settings\.json lists no gate under "gates"' 'says the settings list no gate'
}

Test 'view objectives shows, for each objective, the active subjects, taken decisions, benefits, commitments and open risks that name it or whose subject names it, and leaves out what is superseded, dropped or closed' {
    $ws = New-GovernanceWorkspace @(
        (New-SubjectOperation @{ title = 'Mobile onboarding'; objectives = @(1) }),
        (New-SubjectOperation @{ title = 'Paper statements'; horizon = 'later' })
    )
    Set-Proposal $ws @{ operations = @(
        (New-RecordOperation decision @{ title = 'Drop the paper form'; status = 'taken'; decided_by = 'the sponsor' }),
        (New-RecordOperation decision @{ title = 'Choose the pilot branches'; status = 'pending' }),
        (New-RecordOperation commitment @{ title = 'Send the pilot figures'; owner = 'the PO'; due_date = '2026-03-20' }),
        (New-RecordOperation commitment @{ title = 'Brief the branch staff'; owner = 'the PO'; status = 'done' }),
        (New-RecordOperation commitment @{ title = 'Print new leaflets'; owner = 'the PO'; status = 'dropped' }),
        (New-RecordOperation risk @{ title = 'Branch staff not trained in time' }),
        (New-RecordOperation risk @{ title = 'Scanner shortage'; status = 'closed' }),
        (New-RecordOperation commitment @{ title = 'Share the platform roadmap'; subject = 'paper-statements'; owner = 'the PO'; objectives = @(2) }),
        @{ op = 'create'; type = 'benefit'; interpreted = $false; fields = @{ title = 'Halve the time to open an account'; subject = 'mobile-onboarding'; metric = 'Minutes to open an account'; unit = 'minutes'
                baseline = 40; target = 20; current_value = 18; measured_on = '2026-02-27'; status = 'achieved'; owner = 'the head of retail operations'; evidence_level = 'fact'; source = @{ where = 'inbox/pilot review.md'; read_on = '2026-03-02' } } },
        @{ op = 'create'; type = 'benefit'; interpreted = $false; fields = @{ title = 'Fewer abandoned applications'; subject = 'mobile-onboarding'; metric = 'Abandoned applications'; unit = '%'
                baseline = 30; owner = 'the head of retail operations'; evidence_level = 'fact'; source = @{ where = 'inbox/pilot review.md'; read_on = '2026-03-02' } } }
    ) }
    $run = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the records, with output: $($run.Output)"

    $run = Invoke-Register $ws view objectives -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'views\\objectives\.md' 'output'
    $view = Read-View $ws 'objectives.md'
    Assert-Match $view "^# Objectives evidence\n\n> Generated: 2026-03-02T09:15:00\+01:00\.\n" 'title and stamp'
    $one = (Get-Section $view '## 1. Halve the time to open an account') -join "`n"
    Assert-Equal (@(
            '### Subjects', '- Mobile onboarding [mobile-onboarding]',
            '### Decisions taken', '- Drop the paper form [D-2026-001], 2026-03-02',
            '### Benefits achieved', '- Halve the time to open an account [B-2026-001]: 18 minutes on 2026-02-27 (baseline 40 minutes, target 20 minutes)',
            '### Benefits open', '- Fewer abandoned applications [B-2026-002]: not measured yet (baseline 30 %)',
            '### Commitments done', '- Brief the branch staff [C-2026-002]',
            '### Commitments open', '- Send the pilot figures [C-2026-001], due 2026-03-20',
            '### Open risks', '- Branch staff not trained in time [R-2026-001]') -join "`n") $one 'the evidence of objective 1, its records and those of its subject'
    foreach ($left in 'Choose the pilot branches', 'Print new leaflets', 'Scanner shortage') { Assert-True ($view -notmatch $left) "$left is shown" }
    Assert-Equal (@('### Commitments open', '- Share the platform roadmap [C-2026-004]') -join "`n") ((Get-Section $view '## 2. Serve every client bank from one platform') -join "`n") 'a record that names the objective itself'
    Assert-True ($view -notmatch 'the head of retail operations|the sponsor') 'the view names a person'
    $verify = Invoke-Register $ws verify views\objectives.md
    Assert-Equal 0 $verify.ExitCode "verify of the view, with output: $($verify.Output)"
}

Test 'view objectives says when an objective has no evidence yet and when the settings list no objective, and writes in French' {
    $ws = New-GovernanceWorkspace @((New-SubjectOperation @{ title = 'Mobile onboarding' }))

    $run = Invoke-Register $ws view objectives fr -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-View $ws 'objectives.md'
    Assert-Match $view "## 1\. Halve the time to open an account\n\nAucune preuve enregistr$([char]0xE9)e pour l'instant\." 'no evidence, in French'

    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.objectives = @()
    Write-Json (Join-Path $ws 'settings.json') $settings
    git -C $ws commit -q -am 'No objective'
    $run = Invoke-Register $ws view objectives -Now $Morning
    Assert-Equal 0 $run.ExitCode "exit code without objectives, with output: $($run.Output)"
    Assert-Match (Read-View $ws 'objectives.md') 'settings\.json lists no objective under "objectives"' 'says the settings list no objective'
}

Test 'the workspace rules and the subject routine name both views' {
    $rules = Get-Content -LiteralPath (Join-Path $KitRoot 'workspace-template\AGENTS.md') -Raw -Encoding UTF8
    Assert-Match $rules '`view governance` writes the governance checklist, `views/governance\.md`' 'the workspace rules name the governance checklist'
    Assert-Match $rules '`view objectives` writes the objectives evidence, `views/objectives\.md`' 'the workspace rules name the objectives evidence'
    $routine = Get-Content -LiteralPath (Join-Path $KitRoot 'routines\subject\SKILL.md') -Raw -Encoding UTF8
    foreach ($said in '`view governance`', '`view objectives`') { Assert-True $routine.Contains($said) "the subject routine does not say $said" }
}
