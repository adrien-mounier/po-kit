# Scores and the ranked portfolio: value, feasibility and risk from 1 to 5, each with its reason, the
# AI Act mark with its reason, and the view that ranks the subjects by value times feasibility.

function New-ScoredOperation([string]$Title, $Value, $Feasibility, [hashtable]$Fields = @{}) {
    # A subject of Example Bank with a value and a feasibility score, each with its reason. A $null
    # score is left out. $Fields works as in New-SubjectOperation.
    $scored = @{ title = $Title }
    if ($null -ne $Value) { $scored.value_score = $Value; $scored.value_reason = 'It saves the analysts hours each week.' }
    if ($null -ne $Feasibility) { $scored.feasibility_score = $Feasibility; $scored.feasibility_reason = 'The data is at hand.' }
    foreach ($name in $Fields.Keys) { $scored[$name] = $Fields[$name] }
    New-SubjectOperation $scored
}

Test 'a subject records a value, a feasibility and a risk score from 1 to 5 and the AI Act mark, each with its reason' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-ScoredOperation 'Credit memo drafting' 4 3 @{
                risk_score = 2; risk_reason = 'A person reviews every draft.'
                ai_act_high_risk = $false; ai_act_reason = 'It drafts a memo; it does not assess creditworthiness.'
            })
    }

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $subject = Read-Json (Join-Path $ws 'register\subjects\credit-memo-drafting.json')
    Assert-Equal 4 $subject.value_score 'value score'
    Assert-Equal 3 $subject.feasibility_score 'feasibility score'
    Assert-Equal 2 $subject.risk_score 'risk score'
    Assert-Equal 'A person reviews every draft.' $subject.risk_reason 'its reason'
    Assert-Equal $false $subject.ai_act_high_risk 'the AI Act mark'
    Assert-Equal 'It drafts a memo; it does not assess creditworthiness.' $subject.ai_act_reason 'its reason'
}

Test 'a score outside 1 to 5 or that is not a whole number is refused, with its reason, and nothing is written' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
            (New-ScoredOperation 'Credit memo drafting' 0 6),
            (New-ScoredOperation 'Complaint triage assistant' 2.5 '3'),
            (New-SubjectOperation @{ title = 'Payment dispute triage'; ai_act_high_risk = 'yes'; ai_act_reason = 'It sorts disputes.' })
        )
    }

    Assert-Refused $ws @(
        "Line 1: field 'value_score' is '0'; allowed: 1, 2, 3, 4, 5",
        "Line 1: field 'feasibility_score' is '6'; allowed: 1, 2, 3, 4, 5",
        "Line 2: field 'value_score' must be a whole number, not '2.5'",
        "Line 2: field 'feasibility_score' must be a whole number, not '3'",
        "Line 3: field 'ai_act_high_risk' must be true or false, not 'yes'"
    )
}

Test 'a score or the AI Act mark without its reason is refused, as a subject created or as a proposal leaves it, and is an error of the check' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-ScoredOperation 'Credit memo drafting' 4 3) }
    Invoke-Register $ws apply -Today 2026-03-02 | Out-Null
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation @{ title = 'Complaint triage assistant'; value_score = 4; risk_score = 3; risk_reason = ' ' }),
            (New-SubjectOperation @{ title = 'Payment dispute triage'; ai_act_high_risk = $true }),
            (New-UpdateOperation 'credit-memo-drafting' @{ value_reason = '' })
        )
    }

    Assert-Refused $ws @(
        "Line 1: score without its reason: 'value_score' needs 'value_reason', 'risk_score' needs 'risk_reason'",
        "Line 2: score without its reason: 'ai_act_high_risk' needs 'ai_act_reason'",
        "Line 3: score without its reason: 'value_score' needs 'value_reason'"
    )

    $path = Join-Path $ws 'register\subjects\credit-memo-drafting.json'
    $record = Read-Json $path
    $record.feasibility_reason = $null
    Write-Json $path $record
    git -C $ws commit -q -am 'A reason lost outside the register tool'
    $run = Invoke-Register $ws check -Today 2026-03-02

    Assert-Equal 1 $run.ExitCode "exit code of the check, with output: $($run.Output)"
    Assert-Match ([IO.File]::ReadAllText((Join-Path $ws 'views\check-report.md'), $Utf8)) "### Score without its reason\r?\n\r?\n- Credit memo drafting \[credit-memo-drafting\] \('feasibility_score' needs 'feasibility_reason'\)" 'the check report'
}

$Morning = '2026-03-02T09:15:00+01:00'

function New-RankedWorkspace([object[]]$Operations) {
    # A workspace whose settings list the client banks of Example Bank, and whose register holds
    # these subjects, recorded on 2 March 2026.
    $ws = New-TestWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.banks = @('Harbour Bank', 'North Bank')
    Write-Json (Join-Path $ws 'settings.json') $settings
    git -C $ws commit -q -am 'Client banks'
    Set-Proposal $ws @{ operations = @($Operations) }
    $run = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the subjects, with output: $($run.Output)"
    $ws
}

function Read-Ranking([string]$Workspace) {
    [IO.File]::ReadAllText((Join-Path $Workspace 'views\ranking.md'), $Utf8) -replace '\r\n', "`n"
}

function Get-RankingRows([string]$View, [string]$Heading) {
    # The rows of the table under a heading of the view, cells joined by ' | ', header left out.
    $under = $false
    $rows = @(foreach ($line in $View -split "`n") {
            if ($line -like '#*') { $under = $line -ceq "## $Heading" }
            elseif ($under -and $line -like '|*') { (@($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }) -join ' | ') }
        })
    @($rows | Select-Object -Skip 2)
}

Test 'view ranking orders the subjects by value times feasibility, highest first, ties by value then title, with risk and whether the work changes in their own columns, under a stamp' {
    $ws = New-RankedWorkspace @(
        (New-ScoredOperation 'Paper statements' 2 5 @{ risk_score = 1; risk_reason = 'Nothing sensitive.' }),
        (New-ScoredOperation 'Credit memo drafting' 5 2 @{ work_changes = 'yes'; work_changes_reason = 'Analysts review a draft.' }),
        (New-ScoredOperation 'Complaint triage assistant' 4 4 @{ banks = @('Harbour Bank'); risk_score = 3; risk_reason = 'Customer data.' }),
        (New-ScoredOperation 'Branch kiosks pilot' 5 2 @{ work_changes = 'no'; work_changes_reason = 'A screen is added.' }),
        (New-ScoredOperation 'Card dispute handling' 4 $null),
        (New-SubjectOperation @{ title = 'Mobile onboarding'; work_changes = 'unknown' })
    )

    $run = Invoke-Register $ws view ranking -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'views\\ranking\.md' 'output'
    $view = Read-Ranking $ws
    Assert-Match $view "^# Ranked portfolio\n\n> Generated: 2026-03-02T09:15:00\+01:00\.\n" 'title and stamp'
    Assert-Match $view '\| Rank \| Subject +\| Value x feasibility \| Value \| Feasibility \| Risk \| AI Act \| Work changes \|' 'header of the ranked table'
    Assert-Equal (@(
            '1 | Complaint triage assistant [complaint-triage-assistant] (Harbour Bank) | 16 | 4 | 4 | 3 | - | -',
            '2 | Branch kiosks pilot [branch-kiosks-pilot] | 10 | 5 | 2 | - | - | No',
            '3 | Credit memo drafting [credit-memo-drafting] | 10 | 5 | 2 | - | - | Yes',
            '4 | Paper statements [paper-statements] | 10 | 2 | 5 | 1 | - | -') -join "`n") ((Get-RankingRows $view 'Ranked') -join "`n") 'the subjects ranked'
    Assert-Equal (@(
            'Card dispute handling [card-dispute-handling] | 4 | - | - | - | -',
            'Mobile onboarding [mobile-onboarding] | - | - | - | - | Unknown') -join "`n") ((Get-RankingRows $view 'Not scored') -join "`n") 'the subjects not scored, after'
    Assert-True ([IO.File]::ReadAllBytes((Join-Path $ws 'views\ranking.md'))[0] -ne 0xEF) 'the view opens with a byte order mark'
    $verify = Invoke-Register $ws verify views\ranking.md
    Assert-Equal 0 $verify.ExitCode "verify of the view, with output: $($verify.Output)"
}

$HighRisk = "**$([char]0x26A0) High-risk**"

Test 'a subject marked high-risk under the AI Act is shown marked, in a word and an icon, whatever its score: at the top of the ranking and among those not scored' {
    $credit = @{ ai_act_high_risk = $true; ai_act_reason = 'It scores the creditworthiness of retail customers.' }
    $ws = New-RankedWorkspace @(
        (New-ScoredOperation 'Instant credit scoring' 5 5 $credit),
        (New-ScoredOperation 'Credit memo drafting' 3 3 @{ ai_act_high_risk = $false; ai_act_reason = 'It drafts a memo for an analyst.' }),
        (New-SubjectOperation @{ title = 'Loan applicant screening'; ai_act_high_risk = $true; ai_act_reason = 'It screens loan applicants.' })
    )

    $run = Invoke-Register $ws view ranking -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-Ranking $ws
    $ranked = @(Get-RankingRows $view 'Ranked')
    Assert-Equal "1 | Instant credit scoring [instant-credit-scoring] | 25 | 5 | 5 | - | $HighRisk | -" $ranked[0] 'the high-risk subject ranked first, marked'
    Assert-Equal '2 | Credit memo drafting [credit-memo-drafting] | 9 | 3 | 3 | - | No | -' $ranked[1] 'the subject not high-risk'
    Assert-Equal "Loan applicant screening [loan-applicant-screening] | - | - | - | $HighRisk | -" (@(Get-RankingRows $view 'Not scored') -join "`n") 'the high-risk subject not scored, marked'
}

Test 'view ranking keeps to the subjects of one client bank and those that name none, says so in its stamp, and writes its labels in French' {
    $ws = New-RankedWorkspace @(
        (New-ScoredOperation 'Complaint triage assistant' 4 4 @{ banks = @('Harbour Bank'); work_changes = 'yes'; work_changes_reason = 'Agents stop sorting by hand.' }),
        (New-ScoredOperation 'Payment dispute triage' 5 5 @{ banks = @('North Bank') }),
        (New-ScoredOperation 'Instant credit scoring' 3 2 @{ ai_act_high_risk = $true; ai_act_reason = 'It scores the creditworthiness of retail customers.' })
    )

    $run = Invoke-Register $ws view ranking fr bank Harbour Bank -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-Ranking $ws
    $e = [char]0xE9
    Assert-Match $view "^# Portefeuille class$e\n" 'the title in French'
    Assert-Match $view "\n> Filtr${e}e sur la banque cliente Harbour Bank" 'the stamp names the bank'
    Assert-Equal (@(
            "1 | Complaint triage assistant [complaint-triage-assistant] (Harbour Bank) | 16 | 4 | 4 | - | - | Oui",
            "2 | Instant credit scoring [instant-credit-scoring] | 6 | 3 | 2 | - | **$([char]0x26A0) Haut risque** | -") -join "`n") ((Get-RankingRows $view "Class${e}s") -join "`n") 'the subjects of Harbour Bank and those of every bank'
    Assert-True ($view -notmatch 'payment-dispute-triage') 'the subject of North Bank is shown'
    Assert-Match $view "## Non not${e}s\n\nAucun sujet\." 'none left unscored'
}

Test 'export gives the scores of each subject and its AI Act mark, each with its reason, so that the weekly synthesis and the steering pack can cite them' {
    $ws = New-RankedWorkspace @(
        (New-ScoredOperation 'Instant credit scoring' 5 4 @{ horizon = 'later'; risk_score = 4; risk_reason = 'A refused loan hurts a customer.'
                ai_act_high_risk = $true; ai_act_reason = 'It scores the creditworthiness of retail customers.' }),
        (New-SubjectOperation @{ title = 'Mobile onboarding'; ai_act_high_risk = $false; ai_act_reason = 'No AI decides anything.' }),
        (New-SubjectOperation @{ title = 'Paper statements' })
    )

    $run = Invoke-Register $ws export 2026-03-02 -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $lines = @($run.Output -split "`n")
    Assert-True ($lines -ccontains ('- Instant credit scoring [instant-credit-scoring] | subject | fact | horizon: later | clearance: none | banks: all | value: 5, It saves the analysts hours each week. | ' +
            'feasibility: 4, The data is at hand. | risk: 4, A refused loan hurts a customer. | AI Act high-risk: yes, It scores the creditworthiness of retail customers.')) "the scored subject, in:`n$($run.Output)"
    Assert-True ($lines -ccontains '- Mobile onboarding [mobile-onboarding] | subject | fact | horizon: now | clearance: none | banks: all | AI Act high-risk: no, No AI decides anything.') "the subject not high-risk, in:`n$($run.Output)"
    Assert-True ($lines -ccontains '- Paper statements [paper-statements] | subject | fact | horizon: now | clearance: none | banks: all') "the subject without scores, in:`n$($run.Output)"
}

Test 'the collect and subject routines propose scores on a line of their own, interpreted, each with its reason, and the AI Act mark as a mark to check from the areas of Annex III, never as legal advice' {
    foreach ($routine in 'collect', 'subject') {
        $text = Get-Content -LiteralPath (Join-Path $KitRoot "routines\$routine\SKILL.md") -Raw -Encoding UTF8
        foreach ($said in '`"interpreted": true`', '`value_reason`', '`feasibility_reason`', '`risk_reason`', '`ai_act_reason`', 'Annex III',
            'creditworthiness or the credit score of natural persons', 'safety component', 'never legal advice', 'drop them', '`view ranking`') {
            Assert-True $text.Contains($said) "the $routine routine does not say $said"
        }
    }
    $rules = Get-Content -LiteralPath (Join-Path $KitRoot 'workspace-template\AGENTS.md') -Raw -Encoding UTF8
    Assert-Match $rules '`view ranking` writes the ranked portfolio, `views/ranking\.md`' 'the workspace rules name the ranked portfolio'
}
