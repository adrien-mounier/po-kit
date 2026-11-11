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

Test 'when the agent does nothing, each fact is reported as passed or failed with what was found, the folder is kept and the run fails' {
    $run = Invoke-Scenarios -Agent $FakeAgent subject-modify

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '  FAIL  record payments-api-contribution: horizon is "now"\n        found: "next"' 'a field that holds another value'
    Assert-Match $run.Output '  FAIL  record payments-api-contribution: history\[0\]\.field is "horizon"\n        found: null' 'a field that holds nothing'
    Assert-Match $run.Output '  FAIL  record branch-opening-hours-page: status is "closed"\n        found: "active"' 'the subject that was to be closed'
    Assert-Match $run.Output '  ok    record payments-api-contribution: status is "active"' 'a fact that holds all the same'
    Assert-Match $run.Output '  ok    register/subjects holds 3 record\(s\)' 'a fact that holds all the same'
    Assert-Match $run.Output '1 scenario\(s\): 0 passed, 1 failed' 'verdict'
    Assert-True ($run.Output -match '(?m)^Kept: (.+)$') "the run does not say where its folder is kept: $($run.Output)"
    $kept = $Matches[1].Trim()
    Assert-True (Test-Path (Join-Path $kept 'subject-modify\workspace\register\subjects\payments-api-contribution.json')) 'the workspace of the failed scenario was not kept'
}

Test 'the agent is started in a temporary Example Bank workspace, and its prompt names the routine installed for the scenario and gives what the PO says' {
    $report = Join-Path $TestRoot 'agent-report.txt'

    $run = Invoke-Scenarios -Agent "$FakeAgent -Report `"$report`"" subject-modify

    $startedIn, $prompt = (Get-Content -LiteralPath $report -Raw -Encoding UTF8) -split "`n", 2
    Assert-Match $startedIn ('^' + [regex]::Escape($TestRoot) + '\\po-kit-scenarios-\w+\\subject-modify\\workspace$') 'folder the agent is started in'
    Assert-True ($prompt -match '(?m)^Follow the routine written in this file: (.+)$') "the prompt names no routine: $prompt"
    $routine = $Matches[1].Trim()
    Assert-Match $routine ('^' + [regex]::Escape($TestRoot) + '\\po-kit-scenarios-\w+\\subject-modify\\skills\\subject\\SKILL\.md$') 'routine named in the prompt'
    Assert-Equal (Get-FileHash (Join-Path $KitRoot 'routines\subject\SKILL.md')).Hash (Get-FileHash $routine).Hash "the routine installed against the kit's"
    Assert-Match $prompt 'The PO says:\nTwo changes to my subjects\. Move the Payments API contribution from Next to Now\.' 'what the PO says'

    $workspace = $startedIn.Trim()
    $settings = Read-Json (Join-Path $workspace 'settings.json')
    Assert-Equal 'architecture review, security review' ($settings.gates -join ', ') 'gates of Example Bank'
    Assert-Equal 2 @($settings.objectives).Count 'objectives of Example Bank'
    Assert-Equal 'The sponsor' $settings.sponsor.name 'sponsor of Example Bank'
    Assert-Equal 'mobile-onboarding' (Read-Json (Join-Path $workspace 'register\subjects\mobile-onboarding.json')).id 'a subject of Example Bank, recorded by the register tool'
    Assert-Equal '' "$(git -C $workspace status --porcelain register)" 'changes to the register left out of its history'
}

Test 'a scenario given as a folder lays its own files over the workspace, and every kind of fact is checked exactly: records, fields, files and lines' {
    $run = Invoke-Scenarios -Agent $FakeAgent (Join-Path $Fixtures 'scenarios\every-kind-of-fact')

    $expected = @(
        'every-kind-of-fact'
        '  ok    the agent ran to its end'
        '  ok    record mobile-onboarding is there'
        '  FAIL  record card-dispute-portal is there'
        '        found: it is absent'
        '  ok    record card-dispute-portal is absent'
        '  FAIL  record mobile-onboarding is absent'
        '        found: it is there'
        '  ok    record mobile-onboarding: gates[-1].state is "planned"'
        '  ok    record mobile-onboarding: next_date is null'
        '  FAIL  record mobile-onboarding: watch_list.people is ["the architect","the tech lead"]'
        '        found: ["the tech lead","the architect"]'
        '  FAIL  record mobile-onboarding: kind is "Product"'
        '        found: "product"'
        '  FAIL  record card-dispute-portal: kind is "product"'
        '        found: nothing: it is absent'
        '  FAIL  register/subjects holds 2 record(s)'
        '        found: 3 record(s)'
        '  ok    file inbox/steering committee.md is there'
        '  FAIL  file inbox/done/steering committee.md is there'
        '        found: it is absent'
        '  ok    file state/proposal.json: operations[0].fields.title is "Card dispute portal"'
        '  ok    file views/weekly/2026-03-02.md has a line containing "Mobile onboarding"'
        '  FAIL  file views/weekly/2026-03-02.md has a line containing "mobile onboarding"'
        '        found: no such line'
        '  ok    file views/weekly/2026-03-02.md has no line containing "Savings simulator"'
        '  FAIL  file views/weekly/2026-03-02.md has no line containing "Mobile onboarding"'
        '        found: - Mobile onboarding: cleared by the sponsor.'
        '  FAIL  file views/weekly/2026-03-09.md has a line containing "Mobile onboarding"'
        '        found: nothing: it is absent'
        '  ok    the register holds only what the register tool committed'
    ) -join "`n"
    Assert-True $run.Output.Contains($expected) "the report differs from:`n$expected`ngot:`n$($run.Output)"
    Assert-Equal 1 $run.ExitCode 'exit code'
}

Test 'a record that the agent writes itself, without the register tool, fails the scenario' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -ByHand" (Join-Path $Fixtures 'scenarios\every-kind-of-fact')

    Assert-Match $run.Output '  FAIL  the register holds only what the register tool committed\n        found: \?\? register/subjects/written-by-hand\.json' 'the record written by hand'
    Assert-Equal 1 $run.ExitCode 'exit code'
}

Test 'an agent that ends on a failure code fails the scenario, whatever the register holds' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenario-create.proposal.json`" -ExitCode 3" subject-create

    Assert-Match $run.Output '  FAIL  the agent ran to its end\n        found: exit code 3' 'the failure of the agent'
    Assert-Match $run.Output '  ok    record savings-simulator: kind is "product"' 'the facts are checked all the same'
    Assert-Match $run.Output '1 scenario\(s\): 0 passed, 1 failed' 'verdict'
    Assert-Equal 1 $run.ExitCode 'exit code'
}

Test 'several scenarios run in one go, each with its own verdict; a name that is no scenario is a failure' {
    $run = Invoke-Scenarios -Agent "$FakeAgent -Proposal `"$Fixtures\scenario-create.proposal.json`"" subject-create no-such-scenario

    Assert-Match $run.Output 'subject-create\n  ok    the agent ran to its end' 'the scenario that exists'
    Assert-Match $run.Output "no-such-scenario\n  FAIL  no scenario 'no-such-scenario'" 'the name that is no scenario'
    Assert-Match $run.Output '2 scenario\(s\): 1 passed, 1 failed' 'verdict'
    Assert-Equal 1 $run.ExitCode 'exit code'
}

Test 'without the command that starts the agent, the runner explains itself and runs nothing' {
    $run = Invoke-Scenarios subject-create

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'scenarios\\run\.ps1 -Agent "<command>"' 'how to call the runner'
    Assert-True ($run.Output -notmatch 'subject-create') "a scenario was run: $($run.Output)"
}

Test 'the Example Bank settings carry every setting of the template, so the register tool reads them as it reads any workspace' {
    $names = { param($Path) ((Read-Json $Path).PSObject.Properties | ForEach-Object { $_.Name }) -join ', ' }

    Assert-Equal (& $names (Join-Path $KitRoot 'workspace-template\settings.json')) (& $names (Join-Path $KitRoot 'scenarios\example-bank\workspace\settings.json')) 'settings of Example Bank'
}
