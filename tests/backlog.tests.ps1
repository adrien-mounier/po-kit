# The change proposal for the tracker: the agent only creates a ticket or edits its text, one
# change at a time, once the PO has approved that exact change; every applied change is logged.

function New-BacklogWorkspace([hashtable]$Tracker = @{ mode = 'folder'; folder = 'exports/tracker' }) {
    # A workspace whose tracker is declared as given, read from a folder of exported tickets by default,
    # with one ticket: ONB-142.
    $workspace = New-TestWorkspace
    $connections = Read-Json (Join-Path $workspace 'connections.json')
    $connections.tracker = $Tracker
    Write-Json (Join-Path $workspace 'connections.json') $connections
    $folder = Join-Path $workspace 'exports\tracker'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $folder 'ONB-142.txt'), "Key: ONB-142`nProject: ONB`nTitle: Scan screen`nStatus: In progress`n`nThe customer scans an identity document.`n", $Utf8)
    $workspace
}

function New-Change([hashtable]$Fields = @{}) {
    # One valid change: an edit of the title of ONB-142, approved by the PO. $Fields replaces or adds
    # fields; a $null value removes the field.
    $change = @{
        id = '1'; kind = 'edit'; ticket = 'ONB-142'; field = 'title'; before = 'Scan screen'; after = 'Identity document scan screen'
        reason = 'The title does not say what is scanned.'; source = @{ where = 'the PO, in conversation'; read_on = '2026-03-02' }; state = 'approved'
    }
    foreach ($name in $Fields.Keys) {
        if ($null -eq $Fields[$name]) { $change.Remove($name) } else { $change[$name] = $Fields[$name] }
    }
    $change
}

function Set-Changes([string]$Workspace, [object[]]$Changes, [switch]$Shown) {
    # Leaves the change proposal; -Shown has backlog show give each change to the PO, as the routine
    # does before the PO approves it.
    Write-Json (Join-Path $Workspace 'state\backlog-changes.json') @{ changes = $Changes }
    if ($Shown) {
        foreach ($change in $Changes) {
            $run = Invoke-Register $Workspace backlog show $change.id
            Assert-Equal 0 $run.ExitCode "exit code of backlog show $($change.id), with output: $($run.Output)"
        }
    }
}

function Get-Code([string]$Workspace, [string]$Id = '1') {
    # The approval code backlog show printed for a change, as the PO gives it back: the first six
    # characters of its fingerprint, in upper case.
    @((Read-Json (Join-Path $Workspace 'state\backlog-changes.json')).changes | Where-Object { $_.id -eq $Id })[0].shown.Substring(0, 6).ToUpper()
}

Test 'backlog check accepts a change proposal that creates a ticket and edits the text of another' {
    $ws = New-BacklogWorkspace
    Set-Changes $ws @(
        (New-Change),
        (New-Change @{ id = '2'; kind = 'create'; ticket = $null; field = $null; before = $null; project = 'ONB'; state = 'proposed'
                after = @{ title = 'Branch finder'; description = 'The customer finds the nearest branch.'; 'acceptance criteria' = 'Given a postcode, the three nearest branches are listed.' } })
    )

    $run = Invoke-Register $ws backlog check

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Change proposal: 2 change\(s\), valid\.' 'output'
}

Test 'backlog show gives one change as the exact text before and after, lines kept, and writes nothing but the fingerprint of that text on the change' {
    $ws = New-BacklogWorkspace
    Set-Changes $ws @(
        (New-Change @{ field = 'description'; before = "The customer scans an identity document."; after = "The customer scans an identity document.`nThe scan is checked before the account opens." }),
        (New-Change @{ id = '2'; kind = 'create'; ticket = $null; field = $null; before = $null; project = 'ONB'; state = 'proposed'
                after = @{ title = 'Branch finder'; 'acceptance criteria' = 'Given a postcode, the three nearest branches are listed.' } })
    )
    $changesPath = Join-Path $ws 'state\backlog-changes.json'
    $proposed = (Read-Json $changesPath).changes | ConvertTo-Json -Depth 20
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws backlog show 1

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $shown = "Change 1: edit ticket ONB-142, field Description`nWhy: The title does not say what is scanned.`nSource: the PO, in conversation, read on 2026-03-02`n`n" +
        "Text before:`nThe customer scans an identity document.`n`nText after:`nThe customer scans an identity document.`nThe scan is checked before the account opens."
    # The fingerprint is the SHA-256 of the text shown; its first six characters are the code the
    # PO answers with to approve that exact text.
    $sha = [Security.Cryptography.SHA256]::Create()
    $fingerprint = -join @($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($shown)) | ForEach-Object { $_.ToString('x2') })
    $code = $fingerprint.Substring(0, 6).ToUpper()
    Assert-Equal "$shown`n`nApproval code: $code. To approve this exact text, answer with this code." $run.Output 'the change shown, then its approval code'
    Assert-Equal $fingerprint @((Read-Json $changesPath).changes)[0].shown 'the fingerprint recorded on the change'

    $run = Invoke-Register $ws backlog show 2

    Assert-Equal 0 $run.ExitCode "exit code of the create, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Change 2: create a ticket in project ONB$' 'the create shown'
    Assert-Match $run.Output "(?m)^Title:`n^Branch finder$" 'its title'
    Assert-Match $run.Output "(?m)^Acceptance criteria:`n^Given a postcode, the three nearest branches are listed\.$" 'its acceptance criteria'
    $changes = (Read-Json $changesPath).changes
    Assert-True ($changes[1].shown -match '^[0-9a-f]{64}$') "no fingerprint on the create: $($changes[1].shown)"
    foreach ($change in $changes) { $change.PSObject.Properties.Remove('shown') }
    Assert-Equal $proposed ($changes | ConvertTo-Json -Depth 20) 'the changes but for their fingerprint'
    $others = { param($Snapshot) $Snapshot -replace '(?m)^\\state\\backlog-changes\.json .*$' }
    Assert-Equal (& $others $before) (& $others (Get-WorkspaceSnapshot $ws)) 'the other files of the workspace'

    $run = Invoke-Register $ws backlog show 3

    Assert-Equal 1 $run.ExitCode "exit code for a change not proposed, with output: $($run.Output)"
    Assert-Match $run.Output "The change proposal holds no change '3'" 'output for a change not proposed'
}

# --- Ticket drafts: a create change written from the ticket template ---------------------------

Test 'backlog template gives the kit''s ticket template as the texts of a create change: a title, a user story with a definition of ready, and acceptance criteria as a checklist; it writes nothing and needs no change proposal' {
    $ws = New-BacklogWorkspace
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws backlog template

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Ticket template: tools/templates/ticket-en\.md, the kit''s\.' 'which template'
    Assert-Match $run.Output "(?m)^`"title`":`n^\{title\}$" 'the title'
    Assert-Match $run.Output "(?ms)^`"description`":`n^As a \{role\}, I want \{need\}, so that \{benefit\}\..+^Definition of ready:`n^- \[ \] " 'the user story and the definition of ready'
    Assert-Match $run.Output "(?m)^`"acceptance criteria`":`n^- \[ \] \{criterion\}$" 'the acceptance criteria'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'

    $run = Invoke-Register $ws backlog template fr

    Assert-Equal 0 $run.ExitCode "exit code in French, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Ticket template: tools/templates/ticket-fr\.md, the kit''s\.' 'the French template'
    Assert-Match $run.Output "(?m)^`"description`":`n^En tant que \{role\}, je veux \{need\}, afin de \{benefit\}\." 'the French user story'
    Assert-Match $run.Output "(?m)^`"acceptance criteria`":`n^- \[ \] \{criterion\}$" 'the French acceptance criteria, under the name of the text'
}

Test 'a ticket template of the organisation in the workspace replaces the kit''s for that workspace; one whose sections are not the texts of a ticket is refused and writes nothing' {
    $ws = New-BacklogWorkspace
    New-Item -ItemType Directory -Path (Join-Path $ws 'templates') | Out-Null
    [IO.File]::WriteAllText((Join-Path $ws 'templates\ticket-en.md'), "## Title`n`n[ONB] {title}`n`n## Description`n`nStory: as {role}, I need {need} for {benefit}.`n`n## Acceptance criteria`n`nGiven {context}, when {action}, then {outcome}.`n", $Utf8)

    $run = Invoke-Register $ws backlog template

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Ticket template: templates/ticket-en\.md, the organisation''s\.' 'which template'
    Assert-Match $run.Output "(?m)^`"title`":`n^\[ONB\] \{title\}$" 'the title of the organisation'
    Assert-Match $run.Output "(?m)^`"acceptance criteria`":`n^Given \{context\}, when \{action\}, then \{outcome\}\.$" 'its acceptance criteria'
    Assert-True ($run.Output -notmatch 'Definition of ready') "the kit's template is shown too"

    foreach ($case in @(
            @{ text = "## Title`n`n{title}`n`n## Description`n`n{need}`n"; reason = 'lacks the section(s) ## Acceptance criteria' }
            @{ text = "## Title`n`n{title}`n`n## Description`n`n{need}`n`n## Acceptance criteria`n`n- [ ] {criterion}`n`n## Sprint`n`n{sprint}`n"; reason = "holds the section(s) ## Sprint, which are no text of a ticket" })) {
        [IO.File]::WriteAllText((Join-Path $ws 'templates\ticket-en.md'), $case.text, $Utf8)
        $before = Get-WorkspaceSnapshot $ws

        $run = Invoke-Register $ws backlog template

        Assert-Equal 1 $run.ExitCode "exit code when it $($case.reason), with output: $($run.Output)"
        Assert-Match $run.Output ('The template templates/ticket-en\.md ' + [regex]::Escape($case.reason)) 'why'
        Assert-Match $run.Output 'one section per text of a ticket, headed ## Title, ## Description, ## Acceptance criteria' 'how to correct it'
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace when it $($case.reason)"
    }
}

Test 'the kit ships a ticket template in every language it has labels for, each written as UTF-8 without a byte order mark' {
    foreach ($language in Get-ChildItem (Join-Path $KitRoot 'workspace-template\tools\labels\*.json')) {
        $path = Join-Path $KitRoot "workspace-template\tools\templates\ticket-$($language.BaseName).md"
        Assert-True (Test-Path -LiteralPath $path) "no ticket template in '$($language.BaseName)'"
        Assert-True ([IO.File]::ReadAllBytes($path)[0] -ne 0xEF) "the template in '$($language.BaseName)' opens with a byte order mark"
    }
}

Test 'a ticket draft names the subject of the register it serves, shown with the change; a subject the register does not hold refuses the proposal' {
    $ws = New-BacklogWorkspace
    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    $run = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the subject, with output: $($run.Output)"
    $draft = @{ id = '1'; kind = 'create'; ticket = $null; field = $null; before = $null; project = 'ONB'; subject = 'mobile-onboarding'; state = 'proposed'
        source = @{ where = 'inbox/onboarding workshop.md'; read_on = '2026-03-02' }
        after = @{ title = 'Branch finder'; description = 'As a customer, I want to find a branch, so that I can open my account there.'; 'acceptance criteria' = '- [ ] Given a postcode, the three nearest branches are listed.' } }
    Set-Changes $ws @(New-Change $draft)

    $run = Invoke-Register $ws backlog show 1

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^Subject: mobile-onboarding$' 'the subject shown'

    $draft.subject = 'branch-finder'
    Set-Changes $ws @(New-Change $draft)
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws backlog check

    Assert-Equal 1 $run.ExitCode "exit code for a subject not held, with output: $($run.Output)"
    Assert-Match $run.Output "- Change 1: the subject 'branch-finder' is no subject of the register" 'the reason'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}

Test 'the backlog routine drafts tickets from a note, the collect only offers to, and the workspace rules say where a ticket template of the organisation goes' {
    $routine = Get-Content -LiteralPath (Join-Path $KitRoot 'routines\backlog\SKILL.md') -Raw -Encoding UTF8
    Assert-Match $routine '(?m)^## Draft tickets from a note\r?$' 'the step of the backlog routine'
    Assert-Match $routine 'One draft per need the note states' 'one draft per need'
    Assert-Match $routine 'A need one of them already covers is not drafted again: tell the PO which ticket covers it' 'a duplicate'
    Assert-Match $routine 'A criterion, a role or a benefit the note leaves unclear is never invented\*\*: leave it out, and keep an open question' 'an unclear need'
    Assert-Match $routine '`backlog template`' 'the template'
    Assert-Match (Get-Content -LiteralPath (Join-Path $KitRoot 'routines\collect\SKILL.md') -Raw -Encoding UTF8) 'describes work for the team.+offer to draft its tickets.+the collect drafts no ticket' 'the offer of the collect'
    $rules = Get-Content -LiteralPath (Join-Path $KitRoot 'workspace-template\AGENTS.md') -Raw -Encoding UTF8
    Assert-Match $rules 'A template of the organisation goes in `templates/ticket-<language>\.md` in this workspace\*\*, never under `tools/`, which every update replaces: it then replaces the kit''s for this workspace only' 'where the template of the organisation goes'
}

Test 'with the tracker read from a folder, backlog apply writes the approved change in the outbox, marks it applied and logs it, once, leaving the other changes as they are' {
    $ws = New-BacklogWorkspace
    Set-Changes $ws @((New-Change), (New-Change @{ id = '2'; after = 'Document scan'; state = 'proposed' })) -Shown

    $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws) -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Change 1 applied: written to outbox/tracker/1\.md, and logged in state/backlog-log\.json\.' 'output'
    $outbox = [IO.File]::ReadAllText((Join-Path $ws 'outbox\tracker\1.md'))
    Assert-Match $outbox "(?m)^Change 1: edit ticket ONB-142, field Title$" 'the outbox file'
    Assert-Match $outbox "(?m)^Text after:`n^Identity document scan screen$" 'the text after, in the outbox file'
    Assert-Equal 1 @(Get-ChildItem (Join-Path $ws 'outbox\tracker')).Count 'files of the outbox'
    $changes = @((Read-Json (Join-Path $ws 'state\backlog-changes.json')).changes)
    Assert-Equal 'applied proposed' "$($changes[0].state) $($changes[1].state)" 'states of the changes'
    $log = @((Read-Json (Join-Path $ws 'state\backlog-log.json')).applied)
    Assert-Equal 1 $log.Count 'entries of the log'
    Assert-Equal '2026-03-03|1|edit|ONB-142|title|Scan screen|Identity document scan screen|the PO|outbox/tracker/1.md' (
        @('date', 'change', 'kind', 'ticket', 'field', 'before', 'after', 'approved_by', 'applied' | ForEach-Object { $log[0].$_ }) -join '|') 'the entry of the log'
    Assert-Equal "Scan screen" (([IO.File]::ReadAllText((Join-Path $ws 'exports\tracker\ONB-142.txt')) -split "`n")[2] -replace '^Title: ') 'the ticket itself is left as it is'

    $before = Get-WorkspaceSnapshot $ws
    $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws) -Today 2026-03-03

    Assert-Equal 1 $run.ExitCode "exit code when applied again, with output: $($run.Output)"
    Assert-Match $run.Output 'Change 1 is applied already, on 2026-03-03: a change is applied once\. Nothing was done\.' 'output when applied again'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace when applied again'
}

Test 'backlog apply refuses a change the PO has not approved, writing nothing' {
    $ws = New-BacklogWorkspace
    foreach ($state in 'proposed', 'accepted', 'refused') {
        Set-Changes $ws @(New-Change @{ state = $state })
        $before = Get-WorkspaceSnapshot $ws

        $run = Invoke-Register $ws backlog apply 1

        Assert-Equal 1 $run.ExitCode "exit code for a change $state, with output: $($run.Output)"
        Assert-Match $run.Output "Change 1 is $state, not approved: a change is applied only once the PO has approved it as backlog show gives it\. Nothing was done\." "output for a change $state"
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for a change $state"
    }
}

Test 'backlog apply refuses a change approved without being shown, or changed since backlog show gave it, so that the PO approves only the text they saw' {
    $ws = New-BacklogWorkspace
    $cases = @(
        @{ why = 'never shown'; changes = @(New-Change); shown = $false }
        @{ why = 'its text after changed since'; changes = @(New-Change @{ after = 'Identity document scan screen and selfie' }); shown = $true }
        @{ why = 'its reason changed since'; changes = @(New-Change @{ reason = 'The team asked for it.' }); shown = $true }
    )
    foreach ($case in $cases) {
        Set-Changes $ws @(New-Change @{ state = 'accepted' }) -Shown
        $shown = @((Read-Json (Join-Path $ws 'state\backlog-changes.json')).changes)[0].shown
        $change = $case.changes[0]
        if ($case.shown) { $change.shown = $shown }
        Set-Changes $ws @($change)
        $before = Get-WorkspaceSnapshot $ws

        $run = Invoke-Register $ws backlog apply 1

        Assert-Equal 1 $run.ExitCode "exit code for a change $($case.why), with output: $($run.Output)"
        Assert-Match $run.Output 'Change 1 is not applied: it is not the text backlog show last gave the PO\. Nothing was done\. Show it again with backlog show 1, and apply it only once the PO approved that exact text\.' "output for a change $($case.why)"
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for a change $($case.why)"
    }
}

Test 'backlog apply takes the approval code the PO gave back for the text backlog show printed, and refuses without it, with a wrong one or with the code of an older text' {
    $ws = New-BacklogWorkspace
    Set-Changes $ws @(New-Change @{ after = 'Document scan screen' }) -Shown
    $old = Get-Code $ws
    Set-Changes $ws @(New-Change) -Shown
    $wrong = if ((Get-Code $ws) -ceq 'ABC123') { 'ABC124' } else { 'ABC123' }
    $refused = @(
        @{ why = 'without a code'; code = @(); reason = 'Change 1 is not applied: no approval code\. The PO approves a change by answering with the code backlog show printed for it: backlog apply 1 <code>\. Nothing was done\. Show the change to the PO again with backlog show 1\.' }
        @{ why = 'with a wrong code'; code = @($wrong); reason = "Change 1 is not applied: the approval code $wrong is not the code of its text as it stands\. Nothing was done\. Show the change to the PO again with backlog show 1, and apply it only with the code the PO gives back\." }
        @{ why = 'with the code of an older text'; code = @($old); reason = "Change 1 is not applied: the approval code $old is not the code of its text as it stands\." }
    )
    foreach ($case in $refused) {
        $before = Get-WorkspaceSnapshot $ws

        $words = @('backlog', 'apply', '1') + $case.code
        $run = Invoke-Register $ws @words

        Assert-Equal 1 $run.ExitCode "exit code $($case.why), with output: $($run.Output)"
        Assert-Match $run.Output $case.reason "output $($case.why)"
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace $($case.why)"
    }

    $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws).ToLower()

    Assert-Equal 0 $run.ExitCode "exit code with the right code, in any case, with output: $($run.Output)"

    # The text to paste, given with the code, is recorded as done only while the change is that text.
    $ws = New-BacklogWorkspace @{ mode = 'off' }
    Set-Changes $ws @(New-Change) -Shown
    $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws)
    Assert-Equal 0 $run.ExitCode "exit code of the text to paste, with output: $($run.Output)"
    $changes = Read-Json (Join-Path $ws 'state\backlog-changes.json')
    $changes.changes[0].after = 'Document scan screen'
    Write-Json (Join-Path $ws 'state\backlog-changes.json') $changes

    $run = Invoke-Register $ws backlog apply 1 done

    Assert-Equal 1 $run.ExitCode "exit code of done for a change changed since, with output: $($run.Output)"
    Assert-True (-not (Test-Path (Join-Path $ws 'state\backlog-log.json'))) 'a change changed since was logged'
}

Test 'backlog apply refuses an edit whose text before is not the whole field as the ticket now holds it, so that the agent proposes it again' {
    $ws = New-BacklogWorkspace
    $refused = @(
        @{ why = 'another text'; change = @{ before = 'Scan page' } }
        @{ why = 'a part of the title'; change = @{ before = 'Scan' } }
        @{ why = 'an empty text for a field that holds one'; change = @{ field = 'description'; before = ''; after = 'The customer scans a passport.' } }
        @{ why = 'a part of the description'; change = @{ field = 'description'; before = 'The customer scans'; after = 'The customer scans a passport.' } }
    )
    foreach ($case in $refused) {
        Set-Changes $ws @(New-Change $case.change) -Shown
        $before = Get-WorkspaceSnapshot $ws

        $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws)

        Assert-Equal 1 $run.ExitCode "exit code for $($case.why), with output: $($run.Output)"
        Assert-Match $run.Output 'Change 1 is not applied: ticket ONB-142, as last read in exports/tracker/ONB-142\.txt, no longer holds its text before\. Nothing was done\. Tell the PO, read the ticket again and propose the change again\.' "output for $($case.why)"
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for $($case.why)"
    }

    # The whole field passes, whatever the line endings and the spaces at its ends; an empty text
    # passes for a field the ticket does not hold.
    $accepted = @(
        @{ why = 'the description with other line endings'; change = @{ field = 'description'; before = "  The customer scans an identity document.`r`n"; after = 'The customer scans a passport.' } }
        @{ why = 'empty acceptance criteria for a ticket that has none'; change = @{ field = 'acceptance criteria'; before = ''; after = '- [ ] Given a passport, the scan is accepted.' } }
    )
    foreach ($case in $accepted) {
        $ws = New-BacklogWorkspace
        Set-Changes $ws @(New-Change $case.change) -Shown

        $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws)

        Assert-Equal 0 $run.ExitCode "exit code for $($case.why), with output: $($run.Output)"
    }

    # The acceptance criteria of a ticket follow its description, under their heading; "none" there
    # is no criterion.
    foreach ($case in @(
            @{ held = "Acceptance criteria:`n- Given a passport, the scan is accepted.`n- Given a blurred image, the customer scans again.`n"; field = 'acceptance criteria'; before = "- Given a passport, the scan is accepted.`n- Given a blurred image, the customer scans again." }
            @{ held = "Acceptance criteria:`n- Given a passport, the scan is accepted.`n"; field = 'description'; before = 'The customer scans an identity document.' }
            @{ held = "Acceptance criteria: none`n"; field = 'acceptance criteria'; before = '' })) {
        $ws = New-BacklogWorkspace
        [IO.File]::WriteAllText((Join-Path $ws 'exports\tracker\ONB-142.txt'), "Key: ONB-142`nProject: ONB`nTitle: Scan screen`nStatus: In progress`n`nThe customer scans an identity document.`n`n$($case.held)", $Utf8)
        Set-Changes $ws @(New-Change @{ field = $case.field; before = $case.before; after = 'Reworded.' }) -Shown

        $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws)

        Assert-Equal 0 $run.ExitCode "exit code for the $($case.field) of a ticket holding '$($case.held)', with output: $($run.Output)"
    }
}

Test 'with a tracker connector that may write, backlog apply records the change the routine applied through it, and writes no outbox' {
    $ws = New-BacklogWorkspace @{ mode = 'connector'; connector = 'tracker'; writes = $true }
    Set-Changes $ws @(New-Change) -Shown

    $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws) -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Change 1 recorded as applied through the connector, and logged' 'output'
    Assert-Equal 'through the connector' @((Read-Json (Join-Path $ws 'state\backlog-log.json')).applied)[0].applied 'how it was applied'
    Assert-True (-not (Test-Path (Join-Path $ws 'outbox'))) 'an outbox was written'
}

Test 'with a tracker that may not write, backlog apply gives the text to paste and where it goes, and records the change only once the PO says it is done' {
    foreach ($tracker in @{ mode = 'connector'; connector = 'tracker' }, @{ mode = 'connector'; connector = 'tracker'; writes = $false }, @{ mode = 'off' }) {
        $ws = New-BacklogWorkspace $tracker
        Set-Changes $ws @(New-Change) -Shown
        $before = Get-WorkspaceSnapshot $ws

        # Done is recorded only once the text to paste was given with the PO's code.
        $run = Invoke-Register $ws backlog apply 1 done -Today 2026-03-03

        Assert-Equal 1 $run.ExitCode "exit code of done before the text was given, with output: $($run.Output)"
        Assert-Match $run.Output 'Change 1 is not recorded: its text to paste was not given with the PO''s approval code, or it changed since\. Nothing was done\. Show the change to the PO again with backlog show 1\.' 'output of done before the text was given'
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace after done before the text was given, tracker $($tracker.mode) $($tracker.writes)"

        $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws) -Today 2026-03-03

        Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
        Assert-Match $run.Output "(?m)^Text after:`n^Identity document scan screen$" 'the text to paste'
        Assert-Match $run.Output '(?m)^To paste in the tracker: in ticket ONB-142, replace the text before of the field Title with the text after\.' 'where it goes'
        Assert-Match $run.Output 'once the PO says it is done, record it: backlog apply 1 done' 'how it is recorded'
        $others = { param($Snapshot) $Snapshot -replace '(?m)^\\state\\backlog-changes\.json .*$' }
        Assert-Equal (& $others $before) (& $others (Get-WorkspaceSnapshot $ws)) "files of the workspace but the change proposal before the PO pasted it, tracker $($tracker.mode) $($tracker.writes)"
        Assert-Equal 'approved' @((Read-Json (Join-Path $ws 'state\backlog-changes.json')).changes)[0].state 'state of the change before the PO pasted it'

        $run = Invoke-Register $ws backlog apply 1 done -Today 2026-03-04

        Assert-Equal 0 $run.ExitCode "exit code once pasted, with output: $($run.Output)"
        Assert-Equal '2026-03-04 pasted by the PO' (@((Read-Json (Join-Path $ws 'state\backlog-log.json')).applied | ForEach-Object { "$($_.date) $($_.applied)" }) -join ', ') 'the log'
        Assert-Equal 'applied' @((Read-Json (Join-Path $ws 'state\backlog-changes.json')).changes)[0].state 'state of the change'
    }
}

Test 'the applied-change log is committed with the next apply of the register' {
    $ws = New-BacklogWorkspace
    git -C $ws add -A
    git -C $ws commit -q -m 'The tracker, read from a folder'
    Set-Changes $ws @(New-Change) -Shown
    $run = Invoke-Register $ws backlog apply 1 (Get-Code $ws) -Today 2026-03-03
    Assert-Equal 0 $run.ExitCode "exit code of backlog apply, with output: $($run.Output)"
    Assert-True (@(git -C $ws status --porcelain) -match 'state/backlog-log.json') 'backlog apply committed the log itself: the next apply of the register commits it'

    Set-Proposal $ws @{ operations = @(New-SubjectOperation) }
    $run = Invoke-Register $ws apply -Today 2026-03-03

    Assert-Equal 0 $run.ExitCode "exit code of apply, with output: $($run.Output)"
    $committed = @(git -C $ws show --name-only --format= HEAD)
    Assert-True ($committed -contains 'state/backlog-log.json') "the commit lacks the log; it holds: $($committed -join ', ')"
}

Test 'the workspace rules, the backlog routine and the collect routine state the exception and its limits, and the rules give the change proposal its format' {
    $limits = '(?s)create a ticket or edit its text.+only after the PO.s approval of that exact change, one at a time.+never delete, close or move a ticket, never change another field'
    $rules = Get-Content -LiteralPath (Join-Path $KitRoot 'workspace-template\AGENTS.md') -Raw -Encoding UTF8
    Assert-Match $rules '(?s)you create a ticket or edit its text.+only after the PO approved that exact change, one change at a time; you never delete, close, reopen or move a ticket, and never change another field' 'the exception in the workspace rules'
    Assert-Match $rules '"id": "1", "kind": "edit", "ticket": "ONB-142", "field": "title"' 'the format of the change proposal'
    Assert-Match $rules '"writes": true' 'a tracker that may write'
    Assert-Match (Get-Content -LiteralPath (Join-Path $KitRoot 'routines\collect\SKILL.md') -Raw -Encoding UTF8) $limits 'the exception in the collect routine'
    $routine = Get-Content -LiteralPath (Join-Path $KitRoot 'routines\backlog\SKILL.md') -Raw -Encoding UTF8
    Assert-Match $routine 'Only after the PO approved that exact change, one change at a time' 'the approval in the backlog routine'
    Assert-Match $routine 'never delete, close, reopen or move a ticket, and you never change another field' 'the limits in the backlog routine'
    Assert-Match $routine '(?s)## 3\. Show.+`backlog show <id>`.+approval code.+then stop: wait for the PO''s next message.+## 4\. Record.+gives back the approval code.+never type a code the PO did not give.+Never show and apply a change in the same turn.+## 5\. Apply.+`backlog apply <id> <code>`' 'the approval code in the backlog routine'
    Assert-Match $rules '(?s)`shown`: the fingerprint `backlog show` writes.+approval code.+An approval given before the change was shown, or without its code, is no approval' 'the approval code in the workspace rules'
}

Test 'backlog check refuses a change that would delete, close, reopen or move a ticket, or touch any field but its text, and says why, writing nothing' {
    $ws = New-BacklogWorkspace
    $refused = @(
        @{ change = (New-Change @{ kind = 'delete' }); reason = "field 'kind' is 'delete'; allowed: create, edit" }
        @{ change = (New-Change @{ kind = 'close' }); reason = "field 'kind' is 'close'" }
        @{ change = (New-Change @{ kind = 'reopen' }); reason = "field 'kind' is 'reopen'" }
        @{ change = (New-Change @{ kind = 'move' }); reason = "field 'kind' is 'move'" }
        @{ change = (New-Change @{ field = 'status' }); reason = "field 'field' is 'status'; allowed: title, description, acceptance criteria" }
        @{ change = (New-Change @{ field = 'assignee' }); reason = "field 'field' is 'assignee'" }
        @{ change = (New-Change @{ field = 'estimate' }); reason = "field 'field' is 'estimate'" }
        @{ change = (New-Change @{ field = 'sprint' }); reason = "field 'field' is 'sprint'" }
        @{ change = (New-Change @{ field = 'priority' }); reason = "field 'field' is 'priority'" }
        @{ change = (New-Change @{ field = 'labels' }); reason = "field 'field' is 'labels'" }
        @{ change = (New-Change @{ status = 'Done' }); reason = "unknown field 'status'" }
        @{ change = (New-Change @{ kind = 'create'; ticket = $null; field = $null; before = $null; project = 'ONB'; after = @{ title = 'Branch finder'; sprint = 'Sprint 12' } }); reason = "field 'after.sprint' is not a text of a ticket" }
    )
    foreach ($case in $refused) {
        Set-Changes $ws @($case.change)
        $before = Get-WorkspaceSnapshot $ws

        $run = Invoke-Register $ws backlog check

        Assert-Equal 1 $run.ExitCode "exit code for $($case.reason), with output: $($run.Output)"
        Assert-Match $run.Output 'Change proposal refused\.' "output for $($case.reason)"
        Assert-Match $run.Output ("- Change 1: " + [regex]::Escape($case.reason)) 'the reason'
        Assert-Match $run.Output 'deleting, closing, reopening or moving a ticket, and its status, assignee, estimate, sprint and priority, stay the PO''s' 'why'
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for $($case.reason)"
    }
}

Test 'the backlog routine splits a ticket too large into two to four created tickets and an edit of the original, never closing it, and proposes an order of the top of the backlog that moves nothing' {
    $routine = Get-Content -LiteralPath (Join-Path $KitRoot 'routines\backlog\SKILL.md') -Raw -Encoding UTF8
    Assert-Match $routine '(?s)## Split a ticket too large.+estimate is above `split_estimate_above`.+several needs.+two to four smaller tickets.+`create` change.+written from the ticket template.+`backlog template`.+one `edit` change.+what remains.+never closed' 'the split'
    Assert-Match $routine '(?s)## Propose an order for the top of the backlog.+Reordering is a move, which stays the PO.s.+`backlog_top`.+10 when it is not set.+cites by its identifier.+`"inferred": true`.+`backlog order`.+nothing was moved in the tracker' 'the order'
    Assert-Match (Get-Content -LiteralPath (Join-Path $KitRoot 'workspace-template\AGENTS.md') -Raw -Encoding UTF8) '(?s)"order": \[.+"inferred": true.+`inferred`' 'the inferred link in the workspace rules'
    Assert-Match (Get-Content -LiteralPath (Join-Path $KitRoot 'workspace-template\AGENTS.md') -Raw -Encoding UTF8) '(?s)`backlog_top`: as `10`.+`split_estimate_above`: as `8`' 'the settings in the workspace rules'
}

function Set-Order([string]$Workspace, [object[]]$Order) {
    Write-Json (Join-Path $Workspace 'state\backlog-order.json') @{ order = $Order }
}

Test 'backlog order writes the order the agent proposes for the top of the backlog as a stamped view, each ticket with its reason citing the register, that verify passes, and says reordering is the PO''s' {
    $ws = New-TestWorkspaceWithWeek
    Set-Order $ws @(
        @{ ticket = 'ONB-160'; title = 'Choose a pilot branch'; why = 'The pilot branches are awaited by 2026-03-27 [D-2026-002], and the subject is under Now [mobile-onboarding].' },
        @{ ticket = 'ONB-142'; title = 'Identity document scan screen'; why = 'The subject is under Now [mobile-onboarding].'; inferred = $true }
    )

    $run = Invoke-Register $ws backlog order -Now 2026-03-11T09:00:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Proposed order written: views/backlog-order\.md, 2 ticket\(s\)\. Nothing was moved in the tracker' 'output'
    $view = [IO.File]::ReadAllText((Join-Path $ws 'views\backlog-order.md'))
    Assert-Match $view '(?m)^# Proposed order of the backlog' 'its title'
    Assert-Match $view '(?m)^> Generated: 2026-03-11T09:00:00\+01:00\.' 'its stamp'
    Assert-Match $view 'Nothing is moved in the tracker: reordering the backlog is yours, in the tracker\.' 'who reorders'
    Assert-Match $view '(?s)\| 1 +\| ONB-160 \| Choose a pilot branch +\| The pilot branches are awaited by 2026-03-27 \[D-2026-002\].+\| 2 +\| ONB-142 \| Identity document scan screen \| The subject is under Now \[mobile-onboarding\]\. \(inferred\) \|' 'the tickets in order, each with its reason, the one the agent inferred marked so'
    Assert-True ($view -notmatch 'D-2026-002\][^|]*\(inferred\)') 'a reason read in the tracker is marked inferred'
    Assert-Equal "d$([char]0xE9)duit" (Read-Json (Join-Path $KitRoot 'workspace-template\tools\labels\fr.json')).backlog_order.inferred 'the mark in French'
    $run = Invoke-Register $ws verify views\backlog-order.md
    Assert-Equal 0 $run.ExitCode "verify, with output: $($run.Output)"
}

Test 'backlog order refuses an order citing a record missing or superseded, a ticket placed without a record cited, and more tickets than the top of the backlog, 10 by default, saying why and writing nothing' {
    Assert-Equal 10 (Read-Json (Join-Path $KitRoot 'workspace-template\settings.json')).backlog_top 'the top of the backlog by default'
    $ws = New-TestWorkspaceWithWeek
    $settings = Read-Json (Join-Path $ws 'settings.json')
    $settings | Add-Member backlog_top 2 -Force
    Write-Json (Join-Path $ws 'settings.json') $settings
    Set-Order $ws @(
        @{ ticket = 'ONB-160'; why = 'The pilot is presented to the committee [C-2026-001].' },
        @{ ticket = 'ONB-142'; why = 'The team asked for it.' },
        @{ ticket = 'ONB-150'; why = 'The branches are chosen [D-2026-099].' }
    )
    $before = Get-WorkspaceSnapshot $ws

    $run = Invoke-Register $ws backlog order

    Assert-Equal 1 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Order refused: state\\backlog-order\.json\. Nothing was written' 'output'
    Assert-Match $run.Output '(?m)^- C-2026-001 is superseded by D-2026-005\.$' 'the record superseded'
    Assert-Match $run.Output '(?m)^- D-2026-099 is not in the register\.$' 'the record missing'
    Assert-Match $run.Output '(?m)^- the reason of ticket ONB-142 cites no record' 'the ticket placed without a record'
    Assert-Match $run.Output '(?m)^- the order holds 3 tickets, and the top of the backlog is 2, as backlog_top in settings\.json says$' 'the top'
    Assert-Equal $before (Get-WorkspaceSnapshot $ws) 'files of the workspace'
}
