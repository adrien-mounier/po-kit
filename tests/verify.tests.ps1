# verify: the safeguard that stops a stored view citing a record that is missing or superseded.

function Get-ExportedStamp([string]$Workspace) {
    # The stamp that export gives for the view to write from it, as lines.
    $run = Invoke-Register $Workspace export 2026-03-10 -Now 2026-03-10T09:15:00+01:00
    Assert-Equal 0 $run.ExitCode "exit code of export, with output: $($run.Output)"
    @($run.Output -split "`n" | Where-Object { $_ -like '> *' })
}

function Set-StoredView([string]$Workspace, [string[]]$Lines) {
    # Stores a view as the weekly synthesis routine would, and gives its path from the workspace.
    $path = 'views\weekly\2026-03-10.md'
    [IO.File]::WriteAllText((Join-Path $Workspace $path), ($Lines -join "`r`n") + "`r`n", $Utf8)
    $path
}

Test 'verify succeeds on a stored view that carries its stamp and cites, in brackets, records that exist and are not superseded' {
    $ws = New-TestWorkspaceWithWeek
    $view = Set-StoredView $ws (@('# Weekly synthesis', '') + (Get-ExportedStamp $ws) + @(
            '', '## Progress and commitments', '',
            'The sponsor suspended the presentation of the pilot [D-2026-005].',
            'The kiosks are ordered for 16 April and the branch managers are briefed on 24 March [C-2026-003, C-2026-006].',
            # A record that is done or closed is still a record to cite: only a superseded one is not.
            'The committee room is booked [C-2026-005], and the print contract is no longer a risk [R-2026-003].',
            'Mobile onboarding [mobile-onboarding] stays cleared [D-2026-005].'
        ))
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws verify $view

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '^Verified: views\\weekly\\2026-03-10\.md\b' 'output'
    Assert-Match $run.Output '\b6 record\(s\)' 'records cited, each counted once'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'verify fails when a cited record is superseded or missing, and lists each identifier concerned' {
    $ws = New-TestWorkspaceWithWeek
    $view = Set-StoredView $ws (@('# Weekly synthesis', '') + (Get-ExportedStamp $ws) + @(
            '', '## Progress and commitments', '',
            'The onboarding pilot is presented to the retail steering committee on 20 March [C-2026-001].',
            'The kiosks are ordered [C-2026-003, C-2026-099] for the branch network [branch-network].',
            'The presentation of 20 March is confirmed [C-2026-001], as agreed with [the sponsor].'
        ))
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws verify $view

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '^Not verified: views\\weekly\\2026-03-10\.md' 'output'
    $problems = @($run.Output -split "`n" | Where-Object { $_ -like '- *' })
    Assert-Equal (@(
            '- C-2026-001 is superseded by D-2026-005.'
            '- C-2026-099 is not in the register.'
            '- branch-network is not in the register.'
            '- the sponsor is not in the register.'
        ) -join "`n") ($problems -join "`n") 'problems listed'
    Assert-True ($run.Output -notmatch 'C-2026-003') "the output names a record that is cited rightly: $($run.Output)"
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'verify fails when the stamp is absent, or is not whole as the register tool gives it' {
    $ws = New-TestWorkspaceWithWeek
    $stamp = Get-ExportedStamp $ws
    $cut = @($stamp | Where-Object { $_ -notlike '> Register state:*' })
    Assert-Equal ($stamp.Count - 1) $cut.Count 'lines of the stamp once the register state is cut'
    $reworded = @($stamp | ForEach-Object { $_.Replace('> Generated: ', '> Generated on ') })

    foreach ($lines in @(), $cut, $reworded) {
        $view = Set-StoredView $ws (@('# Weekly synthesis', '') + $lines + @('', 'The sponsor suspended the presentation of the pilot [D-2026-005].'))

        $run = Invoke-Register $ws verify $view

        Assert-Equal 1 $run.ExitCode "exit code with the stamp '$($lines -join ' ')', with output: $($run.Output)"
        Assert-Match $run.Output '(?m)^- The stamp is absent' "output with the stamp '$($lines -join ' ')'"
        Assert-Equal 1 @($run.Output -split "`n" | Where-Object { $_ -like '- *' }).Count "problems listed with the stamp '$($lines -join ' '): $($run.Output)'"
    }
}

Test 'verify recognises the stamp of the views that the register tool writes, in English and in French, before and after a collect' {
    foreach ($ws in (New-TestWorkspaceWithSubject), (New-TestWorkspaceWithWeek)) {
        foreach ($language in 'en', 'fr') {
            $written = Invoke-Register $ws view $language
            Assert-Equal 0 $written.ExitCode "exit code of view $language, with output: $($written.Output)"

            # The path of the view is taken from the workspace, or absolute.
            $path = if ($language -eq 'en') { 'views\portfolio.md' } else { Join-Path $ws 'views\portfolio.md' }
            $run = Invoke-Register $ws verify $path

            Assert-Equal 0 $run.ExitCode "exit code for the view in '$language', with output: $($run.Output)"
            Assert-Match $run.Output '^Verified: ' "output for the view in '$language'"
        }
    }
}

Test 'verify without a view, or with a path that holds no file, is refused' {
    $ws = New-TestWorkspaceWithWeek

    foreach ($arguments in @(), @('views\weekly\2026-03-17.md'), @('views\weekly')) {
        $run = Invoke-Register $ws verify @arguments

        Assert-Equal 1 $run.ExitCode "exit code of verify $arguments, with output: $($run.Output)"
        Assert-Match $run.Output 'verify takes the path of a stored view' "output of verify $arguments"
        if ($arguments) { Assert-Match $run.Output "no file at '$([regex]::Escape($arguments[0]))'" "path named by verify $arguments" }
    }
}

Test 'verify refuses to run when the register differs from its last commit: its verdict is on a committed register' {
    $ws = New-TestWorkspaceWithWeek
    $record = Join-Path $ws 'register\commitments\2026\C-2026-001.json'
    [IO.File]::WriteAllText($record, [IO.File]::ReadAllText($record).Replace('"superseded"', '"open"'), $Utf8)
    $view = Set-StoredView $ws (@('# Weekly synthesis', '') + (Get-ExportedStamp (New-TestWorkspaceWithWeek)) + @('', 'The pilot is presented on 20 March [C-2026-001].'))

    $run = Invoke-Register $ws verify $view

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'The register differs from its last commit' 'output'
    Assert-Match $run.Output '- modified: register/commitments/2026/C-2026-001\.json' 'file listed'
}
