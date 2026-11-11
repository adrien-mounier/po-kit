# Two protections around the register: it refuses outside edits, and it is pushed to the backup.

function New-WorkspaceWithSubject {
    # A workspace whose register holds one committed subject, and where a new proposal is pending.
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    $applied = Invoke-Register $ws apply
    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ title = 'Branch appointment booking' }) }
    $ws
}

function Assert-RefusedForOutsideEdits([string]$Workspace, [string[]]$Files) {
    # preview and apply must both refuse to run: every file listed and no other, a failure exit
    # code, no file written and no commit made.
    $before = Get-WorkspaceSnapshot $Workspace
    $head = git -C $Workspace rev-parse HEAD
    foreach ($command in 'preview', 'apply') {
        $run = Invoke-Register $Workspace $command
        Assert-Equal 1 $run.ExitCode "exit code of $command, with output: $($run.Output)"
        foreach ($file in $Files) { Assert-Match $run.Output ('(?m)^- ' + [regex]::Escape($file) + '$') "file listed by $command" }
        Assert-Equal $Files.Count @($run.Output -split "`n" | Where-Object { $_ -like '- *' }).Count "number of files listed by $command, with output: $($run.Output)"
        Assert-Equal $before (Get-WorkspaceSnapshot $Workspace) "files of the workspace after $command"
        Assert-Equal $head (git -C $Workspace rev-parse HEAD) "last commit after $command"
    }
}

Test 'preview and apply refuse to run when a record was modified outside the register tool, and list it' {
    $ws = New-WorkspaceWithSubject
    $record = Join-Path $ws 'register\subjects\mobile-onboarding.json'
    [IO.File]::WriteAllText($record, [IO.File]::ReadAllText($record).Replace('"now"', '"later"'))

    Assert-RefusedForOutsideEdits $ws @('modified: register/subjects/mobile-onboarding.json')
}

Test 'a record added or deleted outside the register tool is refused the same way, each file named with what happened to it' {
    $ws = New-WorkspaceWithSubject
    Remove-Item (Join-Path $ws 'register\subjects\mobile-onboarding.json')
    New-Item -ItemType Directory -Path (Join-Path $ws 'register\commitments\2026') | Out-Null
    [IO.File]::WriteAllText((Join-Path $ws 'register\commitments\2026\2026-001.json'), '{}')
    [IO.File]::WriteAllText((Join-Path $ws 'register\commitments\2026\2026-002.json'), '{}')

    Assert-RefusedForOutsideEdits $ws @(
        'deleted: register/subjects/mobile-onboarding.json',
        'added: register/commitments/2026/2026-001.json',
        'added: register/commitments/2026/2026-002.json'
    )
}

Test 'differences outside the register, such as a new inbox note or a pending proposal, do not cause the refusal' {
    $ws = New-WorkspaceWithSubject
    [IO.File]::WriteAllText((Join-Path $ws 'inbox\call-with-the-tech-lead.md'), 'The tech lead confirms the release date on Friday.')
    [IO.File]::AppendAllText((Join-Path $ws 'settings.json'), "`n")
    Remove-Item (Join-Path $ws 'views\weekly\.gitkeep')

    foreach ($command in 'preview', 'apply') {
        $run = Invoke-Register $ws $command
        Assert-Equal 0 $run.ExitCode "exit code of $command, with output: $($run.Output)"
    }
    Assert-True (Test-Path (Join-Path $ws 'register\subjects\branch-appointment-booking.json')) 'the proposal was not applied'
}
