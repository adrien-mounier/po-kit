# The intake of AI use cases: a request becomes a subject under Later, pending, with an intake card.

function New-IntakeOperation([hashtable]$Fields = @{}) {
    # A request for an AI use case of Example Bank, taken in as a subject with every intake part.
    # $Fields works as in New-SubjectOperation.
    $intake = @{
        title = 'Complaint triage assistant'; horizon = 'later'; clearance = 'pending'; banks = @('Harbour Bank')
        problem = 'Complaints wait three days before anyone reads them.'; requested_by = 'the head of customer care of Harbour Bank'
        data_needed = 'Two years of complaint mails, with their category.'; expected_gain = 'Every complaint routed within one hour.'
    }
    foreach ($name in $Fields.Keys) { $intake[$name] = $Fields[$name] }
    New-SubjectOperation $intake
}

Test 'a subject records whether the work changes, yes, no or unknown, with one sentence; any other answer is refused' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ work_changes = 'maybe' }) }
    Assert-Refused $ws "Line 1: field 'work_changes' is 'maybe'; allowed: yes, no, unknown\."

    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ work_changes = 'yes'; work_changes_reason = 'The analysts review a draft instead of writing from scratch.' }) }
    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $subject = Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')
    Assert-Equal 'yes' $subject.work_changes 'work changes'
    Assert-Equal 'The analysts review a draft instead of writing from scratch.' $subject.work_changes_reason 'its sentence'
}

Test 'a subject recorded before the intake, without its parts or the work changes answer, still passes the check' {
    $ws = New-TestWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    Invoke-Register $ws apply -Today 2026-03-02 | Out-Null
    $path = Join-Path $ws 'register\subjects\mobile-onboarding.json'
    $old = Read-Json $path
    foreach ($field in 'work_changes', 'work_changes_reason', 'problem', 'requested_by', 'data_needed', 'expected_gain') { $old.PSObject.Properties.Remove($field) }
    Write-Json $path $old
    git -C $ws commit -q -am 'A subject of an older workspace'

    $run = Invoke-Register $ws check -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Check: 0 error\(s\)' 'summary'
}

Test 'a request taken in records its intake parts: the problem, who asks, the data needed and the expected gain' {
    $ws = New-TestWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.banks = @('Harbour Bank', 'North Bank')
    Write-Json (Join-Path $ws 'settings.json') $settings
    git -C $ws commit -q -am 'Client banks'
    Set-Proposal $ws @{ operations = @(New-IntakeOperation) }

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $subject = Read-Json (Join-Path $ws 'register\subjects\complaint-triage-assistant.json')
    Assert-Equal 'Complaints wait three days before anyone reads them.' $subject.problem 'problem'
    Assert-Equal 'the head of customer care of Harbour Bank' $subject.requested_by 'who asks'
    Assert-Equal 'Two years of complaint mails, with their category.' $subject.data_needed 'data needed'
    Assert-Equal 'Every complaint routed within one hour.' $subject.expected_gain 'expected gain'
}

function New-IntakeWorkspace([object[]]$Operations) {
    # A workspace whose settings list Harbour Bank, and whose register holds these subjects.
    $ws = New-TestWorkspace
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings.banks = @('Harbour Bank')
    Write-Json (Join-Path $ws 'settings.json') $settings
    git -C $ws commit -q -am 'Client banks'
    Set-Proposal $ws @{ operations = @($Operations) }
    $run = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the subjects, with output: $($run.Output)"
    $ws
}

Test 'check warns of a subject under Later, pending, whose intake parts are incomplete, and names the parts missing' {
    $ws = New-IntakeWorkspace @(
        (New-IntakeOperation),
        (New-IntakeOperation @{ title = 'Credit memo drafting'; banks = $null; data_needed = $null }),
        # Not an intake: under Now, or under Later with another clearance.
        (New-SubjectOperation @{ title = 'Mobile onboarding'; clearance = 'pending' }),
        (New-SubjectOperation @{ title = 'Paper statements'; horizon = 'later' })
    )

    $run = Invoke-Register $ws check -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $report = [IO.File]::ReadAllText((Join-Path $ws 'views\check-report.md'), $Utf8)
    Assert-Match $report '### Subject under Later, pending, with an incomplete intake\r?\n\r?\n- Credit memo drafting \[credit-memo-drafting\] \(missing: client bank, data needed\)\r?\n' 'the warning'
    Assert-True ($report -notmatch 'complaint-triage-assistant|mobile-onboarding|paper-statements') "a subject warned of wrongly:`n$report"
}

$Morning = '2026-03-02T09:15:00+01:00'

function Read-Card([string]$Workspace, [string]$Id) {
    [IO.File]::ReadAllText((Join-Path $Workspace "views\intake\$Id.md"), $Utf8) -replace '\r\n', "`n"
}

Test 'view intake writes the intake card of a subject, stamped as a view: its five parts, whether the work changes, and its clearance' {
    $ws = New-IntakeWorkspace @(New-IntakeOperation @{ work_changes = 'yes'; work_changes_reason = 'Care agents stop sorting complaints by hand.' })

    $run = Invoke-Register $ws view intake complaint-triage-assistant -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'views\\intake\\complaint-triage-assistant\.md' 'output'
    $card = Read-Card $ws 'complaint-triage-assistant'
    Assert-Match $card '^# Intake card: Complaint triage assistant \[complaint-triage-assistant\]\n\n> Generated: 2026-03-02T09:15:00\+01:00\.\n' 'title and stamp'
    foreach ($part in '## Problem\n\nComplaints wait three days before anyone reads them\.', '## Client bank\n\nHarbour Bank', '## Who asks\n\nthe head of customer care of Harbour Bank',
        '## Data needed\n\nTwo years of complaint mails, with their category\.', '## Expected gain\n\nEvery complaint routed within one hour\.',
        '## Does the way people work change\?\n\nYes: Care agents stop sorting complaints by hand\.', '## Clearance\n\nPending\n') {
        Assert-Match $card $part 'a part of the card'
    }
    Assert-True ([IO.File]::ReadAllBytes((Join-Path $ws 'views\intake\complaint-triage-assistant.md'))[0] -ne 0xEF) 'the card opens with a byte order mark'
    $verify = Invoke-Register $ws verify views\intake\complaint-triage-assistant.md
    Assert-Equal 0 $verify.ExitCode "verify of the card, with output: $($verify.Output)"
}

Test 'a part missing from the intake card is shown as not given, never left out, and so is the work changes answer' {
    $ws = New-IntakeWorkspace @(New-IntakeOperation @{ banks = $null; data_needed = $null })

    $run = Invoke-Register $ws view intake complaint-triage-assistant -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $card = Read-Card $ws 'complaint-triage-assistant'
    Assert-Match $card '## Client bank\n\nnot given\n' 'the client bank'
    Assert-Match $card '## Data needed\n\nnot given\n' 'the data needed'
    Assert-Match $card '## Does the way people work change\?\n\nnot given\n' 'the work changes answer'
}

Test 'view intake in French writes the card from the French template and labels; what the record says is not translated' {
    $ws = New-IntakeWorkspace @(New-IntakeOperation @{ data_needed = $null; work_changes = 'unknown' })

    $run = Invoke-Register $ws view intake complaint-triage-assistant fr -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $card = Read-Card $ws 'complaint-triage-assistant'
    Assert-Match $card "\nnon renseign$([char]0xE9)\n" 'a part not given'
    Assert-Match $card "\nInconnu\n" 'the work changes answer'
    Assert-Match $card "\nEn attente\n" 'the clearance'
    Assert-Match $card "\nComplaints wait three days before anyone reads them\.\n" 'the problem, as recorded'
    Assert-Match $card "\n> G$([char]0xE9)n$([char]0xE9)ration : 2026-03-02" 'the stamp in French'
    $verify = Invoke-Register $ws verify views\intake\complaint-triage-assistant.md
    Assert-Equal 0 $verify.ExitCode "verify of the card, with output: $($verify.Output)"
}

Test 'view intake of a subject the register does not hold, or without a subject, is refused and writes nothing' {
    $ws = New-IntakeWorkspace @(New-IntakeOperation)
    $before = Get-WorkspaceSnapshot $ws

    foreach ($given in @('credit-memo-drafting'), @()) {
        $run = Invoke-Register $ws view intake @given -Now $Morning
        Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
        Assert-Match $run.Output 'view intake <subject>' 'how to call it'
    }
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'a template of the organisation in the workspace replaces the kit''s for that workspace; the kit''s stays in tools' {
    $ws = New-IntakeWorkspace @(New-IntakeOperation)
    $kitTemplate = Join-Path $ws 'tools\templates\intake-en.md'
    $kitBefore = (Get-FileHash $kitTemplate).Hash
    New-Item -ItemType Directory -Path (Join-Path $ws 'templates') | Out-Null
    [IO.File]::WriteAllText((Join-Path $ws 'templates\intake-en.md'), "# Use case request {title} [{id}]`n`n{stamp}`n`nPain: {problem}`nBank: {banks}`nRequester: {requested_by}`nData: {data_needed}`nValue: {expected_gain}`nNew way of working: {work_changes}`nGo-ahead: {clearance}`n", $Utf8)

    $run = Invoke-Register $ws view intake complaint-triage-assistant -Now $Morning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $card = Read-Card $ws 'complaint-triage-assistant'
    Assert-Match $card '^# Use case request Complaint triage assistant \[complaint-triage-assistant\]\n' 'the title of the organisation'
    Assert-Match $card '\nRequester: the head of customer care of Harbour Bank\nData: Two years' 'the parts, as the organisation lays them out'
    Assert-Match $card '\nNew way of working: not given\nGo-ahead: Pending\n' 'the work changes answer and the clearance'
    Assert-Equal $kitBefore (Get-FileHash $kitTemplate).Hash "the kit's template"
}

Test 'the kit ships an intake card template in every language it has labels for, each written as UTF-8 without a byte order mark' {
    foreach ($language in Get-ChildItem (Join-Path $KitRoot 'workspace-template\tools\labels\*.json')) {
        $path = Join-Path $KitRoot "workspace-template\tools\templates\intake-$($language.BaseName).md"
        Assert-True (Test-Path -LiteralPath $path) "no intake card template in '$($language.BaseName)'"
        Assert-True ([IO.File]::ReadAllBytes($path)[0] -ne 0xEF) "the template in '$($language.BaseName)' opens with a byte order mark"
    }
}

Test 'the workspace rules say where a template of the organisation goes, that it replaces the kit''s there only, and that every new subject gets the work changes question' {
    $rules = Get-Content -LiteralPath (Join-Path $KitRoot 'workspace-template\AGENTS.md') -Raw -Encoding UTF8

    Assert-Match $rules 'A template of the organisation goes in `templates/intake-<language>\.md` in this workspace' 'where the template of the organisation goes'
    Assert-Match $rules 'replaces the kit''s for this workspace only' 'what it replaces'
    Assert-Match $rules '`view intake <subject>`' 'how the card is written'
    Assert-Match $rules 'For every new subject, a request or not, ask whether the way people work changes' 'the work changes question'
}

Test 'a refused request is closed with its reason in its history, and leaves the portfolio view' {
    $ws = New-IntakeWorkspace @(New-IntakeOperation)
    Set-Proposal $ws @{ operations = @(@{ op = 'update'; id = 'complaint-triage-assistant'; interpreted = $false
                source = @{ where = 'conversation with the PO'; read_on = '2026-03-09' }
                fields = @{ status = 'closed'; notes = 'Refused on 2026-03-09: the complaint mails cannot leave Harbour Bank.' } })
    }

    $run = Invoke-Register $ws apply -Today 2026-03-09

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $subject = Read-Json (Join-Path $ws 'register\subjects\complaint-triage-assistant.json')
    Assert-Equal 'closed' $subject.status 'status'
    Assert-Equal 'Refused on 2026-03-09: the complaint mails cannot leave Harbour Bank.' @($subject.history | Where-Object { $_.field -eq 'notes' })[0].new 'the reason in the history'
    Assert-True ([IO.File]::ReadAllText((Join-Path $ws 'views\portfolio.md')) -notmatch 'complaint-triage-assistant') 'the refused request is still in the portfolio view'
}

Test 'a template that leaves out a part of the card is refused, with the parts it lacks, and writes nothing' {
    $ws = New-IntakeWorkspace @(New-IntakeOperation)
    New-Item -ItemType Directory -Path (Join-Path $ws 'templates') | Out-Null
    [IO.File]::WriteAllText((Join-Path $ws 'templates\intake-en.md'), "# {title} [{id}]`n`n{stamp}`n`n{problem} {banks} {requested_by} {expected_gain} {clearance}`n", $Utf8)
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws view intake complaint-triage-assistant -Now $Morning

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'templates\\intake-en\.md lacks \{data_needed\}, \{work_changes\}' 'the parts it lacks'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}
