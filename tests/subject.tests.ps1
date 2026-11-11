# A proposed subject is previewed, applied and saved.

Test 'preview prints a numbered table of the operations and changes no file' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation),
            (New-SubjectOperation @{ title = 'Branch appointment booking'; kind = 'contribution'; horizon = 'next' })
        )
    }
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws preview

    Assert-Equal 0 $run.ExitCode 'exit code'
    Assert-Match $run.Output '\|\s*1\s*\|\s*create\s*\|\s*subject\s*\|\s*Mobile onboarding\s*\|.*kind: product' 'line 1'
    Assert-Match $run.Output '\|\s*2\s*\|\s*create\s*\|\s*subject\s*\|\s*Branch appointment booking\s*\|.*horizon: next' 'line 2'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}
