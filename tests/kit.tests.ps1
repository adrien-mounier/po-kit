# What the kit ships: the empty workspace template and its defaults.

$Template = Join-Path $KitRoot 'workspace-template'

Test 'the workspace template has the full layout, and a new workspace starts empty' {
    $ws = New-TestWorkspace
    $folders = 'inbox\done', 'register\subjects', 'register\commitments', 'register\decisions', 'register\risks',
        'views\weekly', 'state', 'tools'
    $tracked = git -C $ws ls-files
    foreach ($folder in $folders) {
        Assert-True (Test-Path (Join-Path $Template $folder) -PathType Container) "the template lacks the folder $folder"
        # Version control keeps a folder only when it holds a file.
        $prefix = $folder.Replace('\', '/') + '/'
        Assert-True (@($tracked | Where-Object { $_.StartsWith($prefix) }).Count -gt 0) "version control would lose the folder $folder"
    }
    foreach ($file in 'settings.json', 'connections.json', 'tools\register.ps1') {
        Assert-True (Test-Path (Join-Path $Template $file) -PathType Leaf) "the template lacks the file $file"
    }
    Assert-Equal 0 @(Get-ChildItem (Join-Path $ws 'register') -Recurse -File -Filter *.json).Count 'records in a new workspace'
    Assert-True (-not (Test-Path (Join-Path $ws 'state\proposal.json'))) 'a new workspace has a pending proposal'
}

Test 'the default settings hold the delays, the validation mode, the languages, the cap and empty gates, objectives, client banks and sponsor' {
    $settings = Read-Json (Join-Path $Template 'settings.json')

    Assert-Equal 1 $settings.format_version 'format version'
    Assert-Equal 7 $settings.delays_in_days.subject 'delay for subjects'
    Assert-Equal 2 $settings.delays_in_days.inbox_note 'delay for inbox notes'
    Assert-Equal 3 $settings.delays_in_days.source 'delay for sources'
    Assert-Equal 'all' $settings.validation_mode 'validation mode'
    Assert-Equal 'en' $settings.languages.default 'default language'
    Assert-Equal 'en' $settings.languages.sponsor "sponsor's language"
    Assert-True ($settings.per_source_cap -is [int] -and $settings.per_source_cap -gt 0) 'the per-source cap is not a positive number'
    Assert-Equal 0 @($settings.gates).Count 'gates'
    Assert-Equal 0 @($settings.objectives).Count 'objectives'
    Assert-True ($null -ne $settings.PSObject.Properties['banks'] -and @($settings.banks).Count -eq 0) 'client banks'
    Assert-Equal '' $settings.sponsor.name "sponsor's name"
    Assert-Equal '' $settings.sponsor.email "sponsor's address"
}

Test 'the default connections read notes from a folder, which is always the inbox, and set mail and tracker to off' {
    $connections = Read-Json (Join-Path $Template 'connections.json')

    Assert-Equal 'folder' $connections.notes.mode 'notes mode'
    Assert-Equal 'off' $connections.mail.mode 'mail mode'
    Assert-Equal 'off' $connections.tracker.mode 'tracker mode'
}

Test 'every routine is a folder that an agent loads as a skill: its SKILL.md opens with its name and a description, and names no agent and no connector' {
    $routines = @(Get-ChildItem (Join-Path $KitRoot 'routines') -Directory)
    Assert-True ($routines.Count -gt 0) 'the kit ships no routine'
    foreach ($routine in $routines) {
        $text = Get-Content -LiteralPath (Join-Path $routine.FullName 'SKILL.md') -Raw -Encoding UTF8
        Assert-True ($text -match '(?s)^---\r?\n(.+?)\r?\n---\r?\n') "the routine $($routine.Name) does not open with its name and description between two lines of three dashes"
        $opening = $Matches[1]
        Assert-Match $opening "(?m)^name: $([regex]::Escape($routine.Name))\s*$" "name of the routine $($routine.Name)"
        Assert-Match $opening '(?m)^description: \S' "description of the routine $($routine.Name)"
        foreach ($file in Get-ChildItem -LiteralPath $routine.FullName -Recurse -File) {
            $named = [regex]::Matches((Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8), '(?i)\b(Claude|Codex|Copilot|Gemini|MCP|Outlook|Gmail|Exchange|Jira|Azure DevOps)\b') | ForEach-Object { $_.Value }
            Assert-Equal '' "$named" "agents and connectors named in routines\$($routine.Name)\$($file.Name)"
        }
    }
}

Test 'the workspace rules say how the settings list the gates, the objectives and the client banks' {
    $rules = Get-Content -LiteralPath (Join-Path $Template 'AGENTS.md') -Raw -Encoding UTF8

    Assert-Match $rules '`gates`: .*\["architecture review", "security review"\]' 'how gates are listed'
    Assert-Match $rules '`objectives`: .*\{ "number": 1, "title": "[^"]+" \}' 'how objectives are listed'
    Assert-Match $rules '`banks`: .*\["Harbour Bank", "North Bank"\]' 'how client banks are listed'
    Assert-Match $rules 'view bank Harbour Bank' 'how the portfolio view keeps to one client bank'
}

Test 'the workspace rules say how the connections declare a source: off, read from a folder, or read through a connector with what its verification gave' {
    $rules = Get-Content -LiteralPath (Join-Path $Template 'AGENTS.md') -Raw -Encoding UTF8

    Assert-Match $rules '\{ "mode": "off" \}' 'a source that is off'
    Assert-Match $rules '\{ "mode": "folder", "folder": "[^"]+" \}' 'a source read from a folder'
    Assert-Match $rules '\{ "mode": "connector", "connector": "[^"]+" \}' 'a source read through a connector'
    Assert-Match $rules '"verified": \{ "result": "ok", "on": "\d{4}-\d\d-\d\d" \}' 'what the verification of a connector gave, and when'
    Assert-Match $rules '"result": "failed"' 'a verification that failed'
}

Test 'the workspace rules name the weekly synthesis as the one view the agent drafts, and say how the connections allow a mail draft and where the settings name the sponsor' {
    $rules = Get-Content -LiteralPath (Join-Path $Template 'AGENTS.md') -Raw -Encoding UTF8

    Assert-Match $rules 'weekly synthesis, `views/weekly/<date>\.md`, is the one view you draft' 'the view the agent drafts'
    Assert-Match $rules '`verify`' 'the command that makes the synthesis count'
    Assert-Match $rules '\{ "mode": "connector", "connector": "[^"]+", "drafts": true \}' 'a mail source that can create drafts'
    Assert-Match $rules '`sponsor`: .*\{ "name": "[^"]+", "email": "[^"]+" \}' 'how the settings name the sponsor'
    Assert-Match $rules '`languages`: .*\{ "default": "en", "sponsor": "fr" \}' 'how the settings give the languages'
}

Test 'the weekly routine ships a template of the six blocks in every language of the kit, each opening with the title the portfolio view carries in that language' {
    $languages = @(Get-ChildItem (Join-Path $Template 'tools\labels\*.json') | Sort-Object Name)
    Assert-Equal 'en fr' (@($languages | ForEach-Object { $_.BaseName }) -join ' ') 'languages of the kit'
    foreach ($language in $languages) {
        $path = Join-Path $KitRoot "routines\weekly\template-$($language.BaseName).md"
        Assert-True (Test-Path -LiteralPath $path) "the weekly routine has no template in '$($language.BaseName)'"
        Assert-True ([IO.File]::ReadAllBytes($path)[0] -ne 0xEF) "the template in '$($language.BaseName)' opens with a byte order mark"
        $blocks = @([IO.File]::ReadAllLines($path, $Utf8) | Where-Object { $_ -like '# *' })
        Assert-Equal 6 $blocks.Count "blocks of the template in '$($language.BaseName)': $($blocks -join ' | ')"
        Assert-Equal "# $((Read-Json $language.FullName).portfolio.title)" $blocks[0] "first block of the template in '$($language.BaseName)'"
        if ($language.BaseName -eq 'en') {
            Assert-Equal '# Portfolio view | # Progress and commitments | # Proposed priorities | # Blockers and decisions expected from the sponsor | # Team capacity | # Not covered this week' ($blocks -join ' | ') 'the six blocks, in order'
        }
    }
}

Test 'every script of the kit is plain ASCII, so Windows PowerShell 5.1 reads it right' {
    $scripts = @(git -C $KitRoot ls-files --cached --others --exclude-standard -- '*.ps1')
    Assert-True ($scripts.Count -gt 0) 'no script found'
    foreach ($script in $scripts) {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $KitRoot $script))
        Assert-True (@($bytes | Where-Object { $_ -gt 127 }).Count -eq 0) "$script holds a character outside ASCII"
    }
}
