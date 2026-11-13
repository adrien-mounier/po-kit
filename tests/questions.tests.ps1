# The agent's open questions: the list the agent keeps in state\questions.json of what it could not
# settle, each with the record or subject it concerns and its recommended answer. The morning page
# counts them under To sort, each with its age, and morning prints them for the briefing.

# Monday 9 March 2026.
$QuestionsMorning = '2026-03-09T07:12:00+01:00'

function New-QuestionsWorkspace {
    # A workspace of Example Bank: the subject mobile-onboarding, the commitment C-2026-001 the
    # tech lead owes the PO, and C-2026-002, superseded by the decision D-2026-001.
    $workspace = New-TestWorkspace
    Set-Proposal $workspace @{ operations = @(
            (New-SubjectOperation),
            (New-RecordOperation commitment @{ title = 'Write the security file'; subject = 'line 1'; owed_to = 'the PO' }),
            (New-RecordOperation commitment @{ title = 'Present the paper form'; subject = 'line 1'; owner = 'the PO' })
        )
    }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the register, with output: $($run.Output)"
    Set-Proposal $workspace @{ operations = @((New-RecordOperation decision @{ title = 'Drop the paper form'; status = 'taken'; decided_by = 'the sponsor'; supersedes = 'C-2026-002' })) }
    $run = Invoke-Register $workspace apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when superseding, with output: $($run.Output)"
    $workspace
}

function Set-Questions([string]$Workspace, $Questions) {
    Write-Json (Join-Path $Workspace 'state\questions.json') @{ questions = @($Questions) }
}

function Get-QuestionsSort([string]$Workspace) {
    $page = [IO.File]::ReadAllText((Join-Path $Workspace 'views\morning.html'), $Utf8)
    if ($page -match '(?s)<section class="block" id="sort".*?</section>') { $Matches[0] }
}

function Get-QuestionsText([string]$Html) {
    [Net.WebUtility]::HtmlDecode(($Html -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim())
}

Test 'the open questions are counted under To sort, the oldest first, each a line with its age in working days, its recommended answer, what it concerns and a button to answer it' {
    $ws = New-QuestionsWorkspace
    Set-Questions $ws @(
        @{ about = 'C-2026-001'; question = 'Who writes the security file?'; recommended = 'The architect.'; added = '2026-03-09' },
        @{ about = 'mobile-onboarding'; question = 'Is the selfie check still in the pilot [mobile-onboarding]?'; recommended = 'Yes: keep it.'; added = '2026-03-04' },
        @{ question = 'Which subject does the card dispute mail belong to?'; recommended = 'None: leave it unclassified.'; added = '2026-03-06' }
    )

    $run = Invoke-Register $ws morning -Now $QuestionsMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $sort = Get-QuestionsSort $ws
    Assert-Match (Get-QuestionsText ($sort -replace '(?s)</h2>.*$', '')) 'To sort 3: 3 open question\(s\)' 'the count of To sort'
    $rows = @([regex]::Matches($sort, '(?s)<li class="row">.*?</li>') | ForEach-Object { Get-QuestionsText $_.Value })
    Assert-Equal 3 $rows.Count "lines of To sort: $($rows -join ' / ')"
    Assert-Equal '3 working day(s) Is the selfie check still in the pilot [mobile-onboarding]? recommended: Yes: keep it. mobile-onboarding Answer' $rows[0] 'the oldest question'
    Assert-Equal '1 working day(s) Which subject does the card dispute mail belong to? recommended: None: leave it unclassified. Answer' $rows[1] 'a question about no record'
    Assert-Equal 'New Who writes the security file? recommended: The architect. C-2026-001 Answer' $rows[2] 'a question of today'
    Assert-Match $sort 'data-ask="Ask me your open question: Who writes the security file\?"' 'the request of the button'
    Assert-Match $run.Output '(?m)^To sort 3: 3 open question\(s\), not read: notes$' 'the count printed'
    Assert-Match $run.Output '(?m)^Open question on \[mobile-onboarding\], open 3 working day\(s\): Is the selfie check still in the pilot \[mobile-onboarding\]\? Recommended: Yes: keep it\.$' 'a question printed for the briefing'
    Assert-Match $run.Output '(?m)^Open question, open 1 working day\(s\): Which subject does the card dispute mail belong to\? Recommended: None: leave it unclassified\.$' 'a question about no record printed'
    Assert-Match $run.Output '(?m)^Open question on \[C-2026-001\], new today: Who writes the security file\? Recommended: The architect\.$' 'a question of today printed'
}

Test 'a question open five working days or more is printed with the request to ask once whether to drop it, until the agent has asked' {
    $ws = New-QuestionsWorkspace
    Set-Questions $ws @(
        @{ about = 'C-2026-001'; question = 'Who writes the security file?'; recommended = 'The architect.'; added = '2026-03-02' },
        @{ about = 'C-2026-001'; question = 'Is the security file due in April?'; recommended = 'Yes.'; added = '2026-03-03' },
        @{ about = 'mobile-onboarding'; question = 'Is the selfie check still in the pilot?'; recommended = 'Yes.'; added = '2026-02-27'; drop_asked = $true }
    )

    $run = Invoke-Register $ws morning -Now $QuestionsMorning

    Assert-Match $run.Output '(?m)^Open question on \[C-2026-001\], open 5 working day\(s\): Who writes the security file\? Recommended: The architect\. Ask once whether to drop it\.$' 'five working days'
    Assert-Match $run.Output '(?m)^Open question on \[C-2026-001\], open 4 working day\(s\): Is the security file due in April\? Recommended: Yes\.$' 'four working days'
    Assert-Match $run.Output '(?m)^Open question on \[mobile-onboarding\], open 6 working day\(s\): Is the selfie check still in the pilot\? Recommended: Yes\.$' 'already asked whether to drop it'
}

Test 'a file of questions that cites a record missing or superseded, or a question without its text, its recommended answer or the date it was added, is refused: To sort says so in red and morning prints why' {
    $ws = New-QuestionsWorkspace
    Set-Questions $ws @(
        @{ about = 'C-2026-099'; question = 'Who writes it?'; recommended = 'The architect.'; added = '2026-03-09' },
        @{ about = 'mobile-onboarding'; question = 'Still presenting [C-2026-002]?'; recommended = 'No.'; added = '2026-03-09' },
        @{ about = 'mobile-onboarding'; question = 'Who owns the pilot?'; added = 'Monday' }
    )

    $run = Invoke-Register $ws morning -Now $QuestionsMorning

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $sort = Get-QuestionsSort $ws
    Assert-Match $sort '<span class="late"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg> open questions could not be read</span>' 'the count of To sort'
    Assert-True ($sort -notmatch 'Who writes it') 'a question of the refused file is shown'
    Assert-Match $run.Output '(?m)^Not verified: state\\questions\.json\..*\n- C-2026-099 is not in the register\.\n- C-2026-002 is superseded by D-2026-001\.\n- Question 3 lacks: recommended, added\.$' 'what morning prints'
    Assert-True ($run.Output -notmatch '(?m)^Open question') 'a question of the refused file printed'
}

Test 'without open questions, To sort says nothing of them' {
    $ws = New-QuestionsWorkspace
    Set-Questions $ws @()

    $run = Invoke-Register $ws morning -Now $QuestionsMorning

    Assert-Match $run.Output '(?m)^To sort none, not read: notes$' 'the count printed'
}
