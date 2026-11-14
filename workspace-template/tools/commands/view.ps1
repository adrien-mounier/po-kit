# view: generates the portfolio view, views\portfolio.md, from the register.
#
#   view                     with the labels of the default language of settings.json
#   view fr                  with the labels of another language; what the records say is never translated
#   view bank Harbour Bank   the subjects of one client bank of settings.json and those that name no
#                            bank; its stamp says so. view fr bank Harbour Bank does both.
#   view intake <subject>    the intake card of a subject, views\intake\<subject>.md; view intake
#                            <subject> fr in another language
#   view ranking             the ranked portfolio, views\ranking.md; it takes a language and a client
#                            bank as the portfolio view does: view ranking fr bank Harbour Bank
#
# apply regenerates the portfolio view after every write, in the default language, with every
# subject. The ranked portfolio, the governance checklist and the objectives evidence are written
# on request only.
#
# The ranked portfolio orders the active subjects by value times feasibility, highest first, ties
# by value, then title; those without both scores follow, under "not scored", by title. Risk, the
# AI Act mark and whether the work changes have their own columns: they never weigh on the rank,
# and a subject marked high-risk under the AI Act is shown so, in a word and an icon, wherever it
# stands.
#
# The intake card is written from a template: templates\intake-<language>.md in the workspace when
# the organisation has its own, otherwise the kit's, tools\templates\intake-<language>.md. Each
# {name} of the template is replaced by its value: {title}, {id}, {stamp}, the five parts
# ($IntakeParts), {work_changes} and {clearance}. A part the subject does not give is shown as not
# given. A template that leaves out one of them is refused, so that a card always holds them all.

function Write-IntakeCard($Subject, [string]$Language) {
    $labels = Get-Labels $Language
    $words = $labels.intake
    $name = "templates\intake-$Language.md"
    $template = Join-Path $Workspace $name
    if (-not (Test-Path -LiteralPath $template)) { $name = "tools\$name"; $template = Join-Path $Workspace $name }
    $text = [IO.File]::ReadAllText($template, $Utf8)
    $values = [ordered]@{ title = (Format-Value $Subject.title); id = $Subject.id; stamp = (@(Get-Stamp $labels) -join [Environment]::NewLine) }
    foreach ($part in $IntakeParts) {
        $said = (Format-Value $Subject.$part).Trim()
        $values[$part] = if ($said) { $said } else { $words.not_given }
    }
    $values.work_changes = if (-not $Subject.work_changes) { $words.not_given }
    else { $words.work_changes.($Subject.work_changes) + $(if ("$($Subject.work_changes_reason)".Trim()) { ": $(Format-Value $Subject.work_changes_reason)" }) }
    $values.clearance = Format-Clearance $Subject $labels.portfolio.clearances.($Subject.clearance) $labels.portfolio.cleared_by $labels.portfolio.cleared_on
    $lacking = @($values.Keys | Where-Object { -not $text.Contains("{$_}") })
    if ($lacking) {
        Stop-Run "The template $name lacks $(@($lacking | ForEach-Object { "{$_}" }) -join ', '). Nothing was written. An intake card always holds every part: put each one in the template."
    }
    # In one pass, so that a value holding braces is left as it is.
    $card = [regex]::Replace($text, '\{([a-z_]+)\}', { param($Found) if ($values.Contains($Found.Groups[1].Value)) { $values[$Found.Groups[1].Value] } else { $Found.Value } })
    $folder = Join-Path $Workspace 'views\intake'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Write-TextFile (Join-Path $folder "$($Subject.id).md") $card
    "Intake card written in '$Language': views\intake\$($Subject.id).md"
}

function Write-RankingView($Labels, [string]$Bank) {
    $words = $Labels.ranking
    $given = { param($Value) if ($null -ne $Value) { "$Value" } else { '-' } }
    # The cells of a subject after its rank and its score: itself, its scores, its AI Act mark and
    # whether the work changes.
    $cells = {
        param($Subject)
        "$($Subject.title) [$($Subject.id)]$(if ($Subject.banks) { " ($(Format-Value $Subject.banks))" })"
        foreach ($score in 'value_score', 'feasibility_score', 'risk_score') { & $given $Subject.$score }
        Format-AiActMark $Subject $words.high_risk $words.not_high_risk '-'
        if ($Subject.work_changes) { $Labels.intake.work_changes.($Subject.work_changes) } else { '-' }
    }
    $escape = { param($Cells) , @($Cells | ForEach-Object { ($_ -replace '\s*\r?\n\s*', ' ').Replace('|', '\|') }) }
    $ranked = Get-RankedSubjects $Bank
    $scored = $ranked.scored
    $rank = 0
    $rows = @(foreach ($subject in $scored) {
            $all = @(& $cells $subject)
            & $escape (@("$((++$rank))", $all[0], "$($subject.value_score * $subject.feasibility_score)") + $all[1..5])
        })
    $others = @($ranked.others | ForEach-Object { & $escape @(& $cells $_) })
    $columns = $words.value, $words.feasibility, $words.risk, $words.ai_act, $words.work_changes
    $lines = @("# $($words.title)", '') + @(Get-Stamp $Labels $Bank) + @('', $words.note, '', "## $($words.ranked)", '')
    $lines += if ($rows) { Write-Table (@($words.rank, $Labels.portfolio.subject, $words.score) + $columns) $rows } else { $Labels.portfolio.no_subject }
    $lines += '', "## $($words.not_scored)", ''
    $lines += if ($others) { Write-Table (@($Labels.portfolio.subject) + $columns) $others } else { $Labels.portfolio.no_subject }
    Write-TextFile (Join-Path $Workspace 'views\ranking.md') (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Write-GovernanceView($Labels, [string]$Bank) {
    # The governance checklist, views\governance.md: every active subject by title, its clearance
    # and the state of each gate settings.json lists, one column each, "-" for a gate it does not
    # state; then each subject missing a gate or out of frame, with the gates it lacks.
    $words = $Labels.governance
    $gates = @($Settings.gates | Where-Object { $_ })
    $escape = { param($Cells) , @($Cells | ForEach-Object { ($_ -replace '\s*\r?\n\s*', ' ').Replace('|', '\|') }) }
    $subjects = @(Get-ActiveSubjects $Bank | Sort-Object { "$($_.title)" })
    $rows = @(foreach ($subject in $subjects) {
            $cells = @("$($subject.title) [$($subject.id)]$(if ($subject.banks) { " ($(Format-Value $subject.banks))" })"
                Format-Clearance $subject $Labels.portfolio.clearances.($subject.clearance) $Labels.portfolio.cleared_by $Labels.portfolio.cleared_on)
            foreach ($gate in $gates) {
                $state = @($subject.gates | Where-Object { $_.name -ceq $gate })[0].state
                $cells += if ($state) { $words.states.$state } else { '-' }
            }
            & $escape $cells
        })
    $attention = @(foreach ($subject in $subjects) {
            $missing = @($subject.gates | Where-Object { $_.state -ceq 'missing' } | ForEach-Object { $_.name })
            $out = $subject.clearance -ceq 'out of frame'
            if ($out -or $missing) {
                $why = @($(if ($out) { $words.out_of_frame }), $(if ($missing) { $words.missing -f ($missing -join ', ') })) | Where-Object { $_ }
                "- $($subject.title) [$($subject.id)]: $(@($why) -join '; ')"
            }
        })
    $lines = @("# $($words.title)", '') + @(Get-Stamp $Labels $Bank) + @('', $words.note, '', "## $($words.gates)", '')
    if (-not $gates) { $lines += $words.no_gate, '' }
    $lines += if ($rows) { Write-Table (@($Labels.portfolio.subject, $Labels.portfolio.clearance) + $gates) $rows } else { $Labels.portfolio.no_subject }
    $lines += '', "## $($words.attention)", ''
    $lines += if ($attention) { $attention } else { $words.nothing }
    Write-TextFile (Join-Path $Workspace 'views\governance.md') (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Write-ObjectivesView($Labels, [string]$Language) {
    # The objectives evidence, views\objectives.md: for each objective of settings.json, the
    # records that show it. A record counts for an objective when it names it, or when its subject
    # names it. Only what is in play counts: active subjects, taken decisions, achieved and open
    # benefits, done and open commitments, open risks. No person is named.
    $words = $Labels.objectives
    $culture = [Globalization.CultureInfo]::GetCultureInfo($Language)
    $records = @(Get-RecordFiles | ForEach-Object { Read-JsonFile $_.path })
    $subjects = @{}
    foreach ($record in $records | Where-Object { $_.type -eq 'subject' }) { $subjects[$record.id] = $record }
    $benefitLine = {
        param($Benefit)
        $value = if ($null -ne $Benefit.current_value) { $words.measured -f (Format-Measure $Benefit $Benefit.current_value $culture), $Benefit.measured_on } else { $words.not_measured }
        # A baseline or a target the benefit does not give is left out.
        $ends = @(foreach ($end in 'baseline', 'target') { if ($null -ne $Benefit.$end) { $words.$end -f (Format-Measure $Benefit $Benefit.$end $culture) } })
        "$value$(if ($ends) { " ($($ends -join ', '))" })"
    }
    # Each part of an objective: its heading, the records it holds and what follows each title.
    $parts = @(
        @{ name = 'subjects'; type = 'subject'; status = 'active'; after = { } }
        @{ name = 'decisions'; type = 'decision'; status = 'taken'; after = { param($R) if ($R.date_of_fact) { ", $($R.date_of_fact)" } } }
        @{ name = 'benefits_achieved'; type = 'benefit'; status = 'achieved'; after = { param($R) ": $(& $benefitLine $R)" } }
        @{ name = 'benefits_open'; type = 'benefit'; status = 'open'; after = { param($R) ": $(& $benefitLine $R)" } }
        @{ name = 'commitments_done'; type = 'commitment'; status = 'done'; after = { } }
        @{ name = 'commitments_open'; type = 'commitment'; status = 'open'; after = { param($R) if ($R.due_date) { ", $($words.due -f $R.due_date)" } } }
        @{ name = 'risks'; type = 'risk'; status = 'open'; after = { } }
    )
    $lines = @("# $($words.title)", '') + @(Get-Stamp $Labels) + @('', $words.note)
    $objectives = @($Settings.objectives | Where-Object { $_ })
    if (-not $objectives) { $lines += '', $words.no_objective }
    foreach ($objective in $objectives) {
        $lines += '', "## $($objective.number). $(Format-Value $objective.title)"
        $serves = { param($R) @($R.objectives) -contains $objective.number -or ($R.subject -and @($subjects[$R.subject].objectives) -contains $objective.number) }
        $shown = $false
        foreach ($part in $parts) {
            $found = @($records | Where-Object { $_.type -eq $part.type -and $_.status -ceq $part.status -and (& $serves $_) })
            if (-not $found) { continue }
            $shown = $true
            $lines += '', "### $($words.($part.name))", ''
            $lines += @($found | ForEach-Object { "- $(Format-Value $_.title) [$($_.id)]$(& $part.after $_)" })
        }
        if (-not $shown) { $lines += '', $words.no_evidence }
    }
    Write-TextFile (Join-Path $Workspace 'views\objectives.md') (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

# The stamp of the view names a committed register.
Assert-RegisterCommitted
$words = @($Arguments | Where-Object { $null -ne $_ })
if ($words.Count -and $words[0] -ceq 'intake') {
    $found = if ($words.Count -gt 1) { Find-Record "$($words[1])" }
    if ($found.type -ne 'subject') {
        Stop-Run "view intake takes the identifier of a subject of the register$(if ($words.Count -gt 1) { ", and '$($words[1])' is none" }). Nothing was written: view intake <subject>"
    }
    Write-IntakeCard $found.record $(if ($words.Count -gt 2) { "$($words[2])" } else { $Settings.languages.default })
    return
}
$kind = if ($words.Count -and 'ranking', 'governance', 'objectives' -ccontains $words[0]) { $words[0] }
if ($kind) { $words = @($words | Select-Object -Skip 1) }
$at = [Array]::IndexOf([string[]]$words, 'bank')
$bank = $null
if ($at -ge 0) {
    $bank = (@($words | Select-Object -Skip ($at + 1)) -join ' ').Trim()
    $words = @($words | Select-Object -First $at)
}
$language = if ($words) { "$words" } else { $Settings.languages.default }
$labels = Get-Labels $language
if ($null -ne $bank) {
    $listed = @($Settings.banks | Where-Object { $_ })
    if ($listed -cnotcontains $bank) {
        Stop-Run "The client bank '$bank' is not listed. Nothing was written. settings.json lists these client banks under 'banks': $(if ($listed) { $listed -join ', ' } else { 'none' }). A bank the PO names that is not listed, the PO adds there first."
    }
}
if ($kind -ceq 'objectives') {
    if ($null -ne $bank) { Stop-Run "view objectives takes a language, not a client bank. Nothing was written: view objectives [language]" }
    Write-ObjectivesView $labels $language
    "Objectives evidence written in '$language': views\objectives.md"
    return
}
if ($kind -ceq 'governance') {
    Write-GovernanceView $labels $bank
    "Governance checklist written in '$language'$(if ($bank) { " for the client bank $bank" }): views\governance.md"
    return
}
if ($kind) {
    Write-RankingView $labels $bank
    "Ranked portfolio written in '$language'$(if ($bank) { " for the client bank $bank" }): views\ranking.md"
    return
}
Write-PortfolioView $labels $bank
"Portfolio view written in '$language'$(if ($bank) { " for the client bank $bank" }): views\portfolio.md"
