# The scenario runner: what it builds, what it checks and what it reports, proven without any
# agent. A script stands in for the agent: it starts no model, costs nothing and does as told.
# The scenarios themselves, which do start an agent, are run by scenarios\run.ps1.

$FakeAgent = "powershell -NoProfile -File `"$(Join-Path $Fixtures 'fake-agent.ps1')`""

function Invoke-Scenarios {
    # Runs the scenario runner once: Invoke-Scenarios -Agent $FakeAgent subject-create
    # Returns its output (standard output and errors together) and its exit code.
    $ErrorActionPreference = 'Continue'
    # Windows PowerShell 5.1 hands a quote inside an argument to a program only when it is escaped.
    $arguments = @($args | ForEach-Object { "$_".Replace('"', '\"') })
    # The runner works in the temporary folder of the machine: under the test root, for these tests.
    $temp = $env:TMP
    $env:TMP = $TestRoot
    try { $lines = & powershell.exe -NoProfile -File (Join-Path $KitRoot 'scenarios\run.ps1') @arguments 2>&1 | ForEach-Object { "$_" } }
    finally { $env:TMP = $temp }
    @{ Output = ($lines -join "`n"); ExitCode = $LASTEXITCODE }
}

Test 'the scenario "create" passes when the agent records the subject the PO describes, through the register tool' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenario-create.proposal.json`"" subject-create

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'kind is "product"', 'horizon is "next"', 'clearance is "cleared"', 'cleared_by is "the sponsor"',
        'watch_list.people is \["the tech lead","the head of savings"\]') {
        Assert-Match $run.Output "  ok    record savings-simulator: $fact" 'expected fact reported as passed'
    }
    Assert-Match $run.Output '  ok    register/subjects holds 4 record\(s\)' 'the register gains one subject'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
    Assert-Match $run.Output '1 scenario\(s\): 1 passed, 0 failed' 'verdict'
}

Test 'the scenario "modify" passes when one subject moves to Now with a history entry and the other is closed and kept' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenario-modify.proposal.json`"" subject-modify

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    foreach ($fact in 'horizon is "now"', 'history\[0\]\.field is "horizon"', 'history\[0\]\.previous is "next"', 'history\[0\]\.new is "now"') {
        Assert-Match $run.Output "  ok    record payments-api-contribution: $fact" 'expected fact reported as passed'
    }
    Assert-Match $run.Output '  ok    record branch-opening-hours-page: status is "closed"' 'the closed subject is still a record'
    Assert-Match $run.Output '  ok    register/subjects holds 3 record\(s\)' 'no subject is added or lost'
    Assert-True ($run.Output -cnotmatch 'FAIL') "a fact is reported as failed: $($run.Output)"
}
