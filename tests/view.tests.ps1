# The portfolio view: every active subject under its horizon, with its clearance, under a stamp.

$Morning = '2026-03-02T09:15:00+01:00'

function New-TestWorkspaceWithSubjects([hashtable[]]$Subjects) {
    # A workspace whose register holds these subjects of Example Bank, recorded on 2 March 2026.
    # Each one is given as the fields New-SubjectOperation replaces or adds.
    $workspace = New-TestWorkspace
    Set-Proposal $workspace @{ operations = @($Subjects | ForEach-Object { New-SubjectOperation $_ }) }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the subjects, with output: $($run.Output)"
    $workspace
}

function Read-View([string]$Workspace) {
    [IO.File]::ReadAllText((Join-Path $Workspace 'views\portfolio.md'), $Utf8)
}

function Get-Rows([string]$View, [string]$Heading) {
    # The subjects a view shows under a heading: one line per subject, its cells joined by ' | '.
    # Nothing when the heading is absent or has no table.
    $under = $false
    $rows = @(foreach ($line in $View -split '\r?\n') {
            if ($line -like '#*') { $under = $line -ceq "## $Heading" }
            elseif ($under -and $line -like '|*') { (@($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }) -join ' | ') }
        })
    # A table opens with its header and the line under it.
    @($rows | Select-Object -Skip 2) -join "`n"
}

Test 'view writes the portfolio view: an active subject under its horizon, with its kind, its clearance and its next step' {
    $ws = New-TestWorkspaceWithSubjects @{ kind = 'contribution'; clearance = 'pending'; next_step = 'Draft the target journey' }

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-View $ws
    Assert-Match $view '^# Portfolio view\r?\n' 'title of the view'
    Assert-Equal 'Mobile onboarding [mobile-onboarding] | Contribution | Pending |  | Draft the target journey' (Get-Rows $view 'Now') 'subjects under Now'
    Assert-Match $run.Output 'views\\portfolio\.md' 'output'
    Assert-True ([IO.File]::ReadAllBytes((Join-Path $ws 'views\portfolio.md'))[0] -ne 0xEF) 'the view opens with a byte order mark'
}

Test 'every subject is under its own horizon, the horizons come as Now, Next, Later, and one without subject says so' {
    $ws = New-TestWorkspaceWithSubjects @{ title = 'Card dispute handling'; horizon = 'later' },
        @{ title = 'Mobile onboarding'; horizon = 'now' }, @{ title = 'Branch appointment booking'; horizon = 'now' }

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-View $ws
    Assert-Equal '## Now ## Next ## Later' (@($view -split '\r?\n' | Where-Object { $_ -like '## *' }) -join ' ') 'horizons of the view'
    Assert-Equal "Branch appointment booking [branch-appointment-booking] | Product | None |  | `nMobile onboarding [mobile-onboarding] | Product | None |  | " (Get-Rows $view 'Now') 'subjects under Now'
    Assert-Equal '' (Get-Rows $view 'Next') 'subjects under Next'
    Assert-Match $view '## Next\r?\n\r?\nNo subject\.\r?\n\r?\n## Later' 'what the view says under Next'
    Assert-Equal 'Card dispute handling [card-dispute-handling] | Product | None |  | ' (Get-Rows $view 'Later') 'subjects under Later'
}

Test 'a closed subject does not appear in the portfolio view: it leaves the view at the apply that closes it' {
    $ws = New-TestWorkspaceWithSubjects @{ title = 'Paper statements' }, @{ title = 'Mobile onboarding' }
    Assert-Match (Read-View $ws) 'paper-statements' 'the view before the subject is closed'
    Set-Proposal $ws @{ operations = @(@{ op = 'update'; id = 'paper-statements'; interpreted = $true; fields = @{ status = 'closed' }
                source = @{ where = 'conversation with the PO'; read_on = '2026-03-03' } })
    }

    $run = Invoke-Register $ws apply -Now 2026-03-03T09:15:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-View $ws
    Assert-Equal 'Mobile onboarding [mobile-onboarding] | Product | None |  | ' (Get-Rows $view 'Now') 'subjects under Now'
    Assert-True ($view -notmatch 'Paper statements|paper-statements') 'the closed subject appears in the view'
}

Test 'a cleared subject says who cleared it and when, and a subject out of frame is shown as such, unlike a pending or a cleared one' {
    $ws = New-TestWorkspaceWithSubjects @{ title = 'Mobile onboarding'; clearance = 'cleared'; cleared_by = 'the sponsor'; cleared_on = '2026-02-20' },
        @{ title = 'Branch kiosks pilot'; clearance = 'out of frame' },
        # Who cleared a subject is shown when it is cleared, and only then.
        @{ title = 'Card dispute handling'; clearance = 'pending'; cleared_by = 'the tech lead'; cleared_on = '2026-01-10' }

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $rows = (Get-Rows (Read-View $ws) 'Now') -split "`n"
    Assert-Equal 'Branch kiosks pilot [branch-kiosks-pilot] | Product | **Out of frame** |  | ' $rows[0] 'the subject out of frame'
    Assert-Equal 'Card dispute handling [card-dispute-handling] | Product | Pending |  | ' $rows[1] 'the pending subject'
    Assert-Equal 'Mobile onboarding [mobile-onboarding] | Product | Cleared by the sponsor on 2026-02-20 |  | ' $rows[2] 'the cleared subject'
}

Test 'the next date of a subject appears only when it is marked confirmed' {
    $ws = New-TestWorkspaceWithSubjects @{ title = 'Mobile onboarding'; next_step = 'Present the target journey to the committee'; next_date = '2026-03-16'; next_date_confirmed = $true },
        @{ title = 'Card dispute handling'; next_step = 'Agree a date with the tech lead'; next_date = '2026-04-01' }

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-View $ws
    $rows = (Get-Rows $view 'Now') -split "`n"
    Assert-Equal 'Card dispute handling [card-dispute-handling] | Product | None |  | Agree a date with the tech lead' $rows[0] 'the subject whose date is not confirmed'
    Assert-Equal 'Mobile onboarding [mobile-onboarding] | Product | None | 2026-03-16 | Present the target journey to the committee' $rows[1] 'the subject whose date is confirmed'
    Assert-True ($view -notmatch '2026-04-01') 'the date that is not confirmed appears in the view'
}

Test 'what a subject says stays in its cell: a bar or a line break does not break the table' {
    $ws = New-TestWorkspaceWithSubjects @{ next_step = "Choose: web | app`nthen brief the tech lead" }

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match (Read-View $ws) '\| Choose: web \\\| app then brief the tech lead \|\r?\n' 'the next step in the view'
}

function Read-Stamp([string]$Workspace, [string]$Title = 'Portfolio view', [string]$Now = 'Now') {
    # The stamp of the portfolio view: the lines between its title and its first horizon.
    $lines = (Read-View $Workspace) -split '\r?\n'
    Assert-Equal "# $Title" $lines[0] 'first line of the view'
    $first = [Array]::IndexOf($lines, "## $Now")
    Assert-Equal '' "$($lines[1])$($lines[$first - 1])" 'lines around the stamp'
    $lines[2..($first - 2)] -join "`n"
}

function Set-CollectProposal([string]$Workspace, [string]$CollectedAt, [string[]]$Read, [string[]]$NotCovered = @()) {
    # Leaves the proposal of a collect that read these sources, and says it did not cover those.
    Set-Proposal $Workspace @{
        collected_at        = $CollectedAt
        sources_read        = @($Read | ForEach-Object { @{ source = $_; cutoff = $CollectedAt; items = 3 } })
        sources_not_covered = $NotCovered
    }
}

Test 'the view opens with a stamp: when it was generated, the register state as the workspace history names it, and that no collect has run yet' {
    $ws = New-TestWorkspaceWithSubject

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    # The history of the workspace names the register of any commit this way.
    $state = "$(git -C $ws rev-parse HEAD:register)".Substring(0, 12)
    Assert-Equal "> Generated: $Morning.`n> Register state: $state.`n> No collect has run yet: no source is covered." (Read-Stamp $ws) 'stamp'
}

Test 'the stamp names the last collect and the sources it did not cover, whether the collect said so or left them unread' {
    $ws = New-TestWorkspaceWithSubject
    Set-CollectProposal $ws '2026-03-02T08:30:00+01:00' 'notes', 'mail' 'tracker'
    $first = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $first.ExitCode "exit code of the first collect, with output: $($first.Output)"

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match (Read-Stamp $ws) '\n> Last collect: 2026-03-02T08:30:00\+01:00\.\n> Sources not covered by the last collect: tracker\.$' 'stamp after the first collect'

    # The next collect reads the notes only and says nothing of the rest: the mail an earlier
    # collect read is not covered by this one.
    Set-CollectProposal $ws '2026-03-03T08:30:00+01:00' 'notes'
    $second = Invoke-Register $ws apply -Today 2026-03-03
    Assert-Equal 0 $second.ExitCode "exit code of the second collect, with output: $($second.Output)"

    $run = Invoke-Register $ws view -Now 2026-03-03T09:15:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match (Read-Stamp $ws) '\n> Last collect: 2026-03-03T08:30:00\+01:00\.\n> Sources not covered by the last collect: mail, tracker\.$' 'stamp after the second collect'
}

Test 'after a collect that read every source, the stamp says that none is left uncovered' {
    $ws = New-TestWorkspaceWithSubject
    Set-CollectProposal $ws '2026-03-02T08:30:00+01:00' 'notes', 'mail', 'tracker'
    $collect = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $collect.ExitCode "exit code of the collect, with output: $($collect.Output)"

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match (Read-Stamp $ws) '\n> Sources not covered by the last collect: none\.$' 'stamp'
}

Test 'a run given a date as today stamps its view on that date, and a moment given as now without its UTC offset is refused' {
    $ws = New-TestWorkspaceWithSubject

    $run = Invoke-Register $ws view -Today 2026-03-05

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match (Read-Stamp $ws) '^> Generated: 2026-03-05T\d\d:\d\d:\d\d[+-]\d\d:\d\d\.\n' 'stamp of a run given a date as today'

    $before = Get-WorkspaceSnapshot $ws
    $run = Invoke-Register $ws view -Now 2026-03-02T09:15:00

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "must be a date and time with its UTC offset \(as 2026-03-02T08:30:00\+01:00\), not '2026-03-02T09:15:00'" 'output'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

function Set-DefaultLanguage([string]$Workspace, [string]$Language) {
    # Sets the default language of the workspace, as the PO would in the settings.
    $path = Join-Path $Workspace 'settings.json'
    $settings = Read-Json $path
    $settings.languages.default = $Language
    Write-Json $path $settings
}

# This file is plain ASCII: the accents of the French labels are written by their code.
$e = [string][char]0xE9

Test 'view fr writes every label in French, and leaves what the subject says as it is' {
    $ws = New-TestWorkspaceWithSubjects @{ kind = 'service'; horizon = 'next'; clearance = 'cleared'; cleared_by = 'the sponsor'; cleared_on = '2026-02-20'
        next_step = 'Present the target journey'; next_date = '2026-03-16'; next_date_confirmed = $true }

    $run = Invoke-Register $ws view fr -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-View $ws
    $state = "$(git -C $ws rev-parse HEAD:register)".Substring(0, 12)
    Assert-Equal "> G${e}n${e}ration : $Morning.`n> $([char]0xC9)tat du registre : $state.`n> Aucune collecte n'a encore eu lieu : aucune source n'est couverte." (Read-Stamp $ws 'Vue portefeuille' 'Maintenant') 'stamp'
    Assert-Equal '## Maintenant ## Ensuite ## Plus tard' (@($view -split '\r?\n' | Where-Object { $_ -like '## *' }) -join ' ') 'horizons of the view'
    Assert-Match $view '## Maintenant\r?\n\r?\nAucun sujet\.\r?\n' 'what the view says under Now'
    Assert-Match $view "\| Sujet +\| Nature +\| Feu vert +\| Prochaine date \| Prochaine ${e}tape \|" 'header of the table'
    Assert-Equal "Mobile onboarding [mobile-onboarding] | Service | Accord${e} par the sponsor le 2026-02-20 | 2026-03-16 | Present the target journey" (Get-Rows $view 'Ensuite') 'subjects under Next'
}

Test 'a French view says of each subject its kind and its clearance in French, and names the sources the last collect did not cover' {
    $ws = New-TestWorkspaceWithSubjects @{ title = 'Mobile onboarding'; kind = 'product'; clearance = 'pending' },
        @{ title = 'Branch kiosks pilot'; kind = 'contribution'; clearance = 'out of frame' }, @{ title = 'Card dispute handling' }
    Set-CollectProposal $ws '2026-03-02T08:30:00+01:00' 'notes', 'mail', 'tracker'
    $collect = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $collect.ExitCode "exit code of the collect, with output: $($collect.Output)"

    $run = Invoke-Register $ws view fr -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $rows = (Get-Rows (Read-View $ws) 'Maintenant') -split "`n"
    Assert-Equal 'Branch kiosks pilot [branch-kiosks-pilot] | Contribution | **Hors cadre** |  | ' $rows[0] 'the subject out of frame'
    Assert-Equal 'Card dispute handling [card-dispute-handling] | Produit | Aucun |  | ' $rows[1] 'the subject without clearance'
    Assert-Equal 'Mobile onboarding [mobile-onboarding] | Produit | En attente |  | ' $rows[2] 'the pending subject'
    $last = "Derni$([char]0xE8)re collecte"
    Assert-Match (Read-Stamp $ws 'Vue portefeuille' 'Maintenant') "\n> $last : 2026-03-02T08:30:00\+01:00\.\n> Sources non couvertes par la $($last.ToLower()) : aucune\.$" 'stamp'
}

Test 'view without a language writes the view in the default language of the settings' {
    $ws = New-TestWorkspaceWithSubject
    Set-DefaultLanguage $ws 'fr'

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match (Read-View $ws) '^# Vue portefeuille\r?\n' 'title of the view in the default language'

    $run = Invoke-Register $ws view en -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match (Read-View $ws) '^# Portfolio view\r?\n' 'title of the view in the language asked'
}

Test 'view in a language the kit has no labels for is refused, with the languages it has, and writes nothing' {
    $ws = New-TestWorkspaceWithSubject
    $before = Get-WorkspaceSnapshot $ws

    foreach ($language in 'de', '..\labels\fr') {
        $run = Invoke-Register $ws view $language -Now $Morning

        Assert-Equal 1 $run.ExitCode "exit code for $language, with output: $($run.Output)"
        Assert-Match $run.Output "Unsupported language '$([regex]::Escape($language))'" "output for $language"
        Assert-Match $run.Output 'Languages: en, fr\.' "languages listed for $language"
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for $language"
    }
}

Test 'apply regenerates the portfolio view for the register it leaves, in the same commit as the records it wrote' {
    $ws = New-TestWorkspaceWithSubject
    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ title = 'Branch appointment booking'; horizon = 'next' }) }

    $run = Invoke-Register $ws apply -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-View $ws
    Assert-Equal 'Mobile onboarding [mobile-onboarding] | Product | None |  | ' (Get-Rows $view 'Now') 'subjects under Now'
    Assert-Equal 'Branch appointment booking [branch-appointment-booking] | Product | None |  | ' (Get-Rows $view 'Next') 'subjects under Next'
    $state = "$(git -C $ws rev-parse HEAD:register)".Substring(0, 12)
    Assert-Match (Read-Stamp $ws) "^> Generated: $([regex]::Escape($Morning))\.\n> Register state: $state\.\n" 'stamp'
    $committed = @(git -C $ws show --name-only --format= HEAD)
    Assert-True ($committed -contains 'register/subjects/branch-appointment-booking.json') "the last commit lacks the record: $committed"
    Assert-True ($committed -contains 'views/portfolio.md') "the last commit lacks the portfolio view: $committed"
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes left out of the commit'
    Assert-Match $run.Output 'views\\portfolio\.md' 'output'
}

Test 'apply writes the portfolio view in the default language of the settings' {
    $ws = New-TestWorkspace
    Set-DefaultLanguage $ws 'fr'
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }

    $run = Invoke-Register $ws apply -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-View $ws
    Assert-Match $view '^# Vue portefeuille\r?\n' 'title of the view'
    Assert-Equal 'Mobile onboarding [mobile-onboarding] | Produit | Aucun |  | ' (Get-Rows $view 'Maintenant') 'subjects under Now'
}

Test 'apply is refused before anything is written when the kit has no labels for the default language of the settings' {
    $ws = New-TestWorkspace
    Set-DefaultLanguage $ws 'de'
    [IO.File]::WriteAllText((Join-Path $ws 'inbox\steering committee.md'), 'The sponsor of Example Bank asks for a date.', $Utf8)
    Set-Proposal $ws @{ collected_at = '2026-03-02T08:30:00+01:00'; notes_processed = @('steering committee.md'); operations = @(New-SubjectOperation) }
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws apply -Now $Morning

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output "Unsupported language 'de'" 'output'
    Assert-Match $run.Output 'languages\.default' 'where the output says the language is set'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'generated twice from the same register state, the view is the same apart from the time it was generated' {
    $ws = New-TestWorkspaceWithSubjects @{ title = 'Mobile onboarding'; clearance = 'cleared'; cleared_by = 'the sponsor'; cleared_on = '2026-02-20' },
        @{ title = 'Card dispute handling'; horizon = 'later' }
    Set-CollectProposal $ws '2026-03-02T08:30:00+01:00' 'notes' 'mail'
    $applied = Invoke-Register $ws apply -Now $Morning
    Assert-Equal 0 $applied.ExitCode "exit code of apply, with output: $($applied.Output)"
    $first = Read-View $ws

    # At the same moment the view is the very one apply committed.
    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal '' (@(git -C $ws status --porcelain) -join ' ') 'changes to the view apply committed'

    $run = Invoke-Register $ws view -Now 2026-03-02T17:40:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $second = Read-View $ws
    Assert-True ($second -cne $first) 'the view does not say it was generated later'
    Assert-Equal $first $second.Replace('2026-03-02T17:40:00+01:00', $Morning) 'the view generated later, its time of generation set aside'
}

Test 'view refuses to run when the register differs from its last commit, as its stamp names a committed register' {
    $ws = New-TestWorkspaceWithSubject
    $record = Join-Path $ws 'register\subjects\mobile-onboarding.json'
    [IO.File]::WriteAllText($record, [IO.File]::ReadAllText($record).Replace('"now"', '"later"'), $Utf8)
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws view -Now $Morning

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'The register differs from its last commit' 'output'
    Assert-Match $run.Output '- modified: register/subjects/mobile-onboarding\.json' 'file listed'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

function Get-LabelNames($Labels, [string]$Under = '') {
    # Every label of a language, named by its place in the file, with the places it keeps for values.
    foreach ($label in $Labels.PSObject.Properties) {
        if ($label.Value -is [System.Management.Automation.PSCustomObject]) { Get-LabelNames $label.Value "$Under$($label.Name)." }
        else { "$Under$($label.Name)$(([regex]::Matches($label.Value, '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object) -join '')" }
    }
}

Test 'every language of the kit carries the same labels, none empty, each with the same places for values' {
    $files = @(Get-ChildItem (Join-Path $KitRoot 'workspace-template\tools\labels\*.json') | Sort-Object Name)
    Assert-Equal 'en fr' (@($files | ForEach-Object { $_.BaseName }) -join ' ') 'languages of the kit'
    $english = @(Get-LabelNames (Read-Json $files[0].FullName) | Sort-Object) -join "`n"
    Assert-Match $english '(?m)^stamp\.generated\{0\}$' 'labels of en'
    Assert-Equal $english (@(Get-LabelNames (Read-Json $files[1].FullName) | Sort-Object) -join "`n") 'labels of fr'
    foreach ($file in $files) {
        Assert-True ((Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8) -notmatch '":\s*""') "$($file.Name) holds an empty label"
        Assert-True ([IO.File]::ReadAllBytes($file.FullName)[0] -ne 0xEF) "$($file.Name) opens with a byte order mark"
    }
}
