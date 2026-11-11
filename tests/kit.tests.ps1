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

Test 'the default settings hold the delays, the validation mode, the languages, the cap and empty gates, objectives and sponsor' {
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
    Assert-Equal '' $settings.sponsor.name "sponsor's name"
    Assert-Equal '' $settings.sponsor.email "sponsor's address"
}

Test 'the default connections read notes from the inbox folder and set mail and tracker to off' {
    $connections = Read-Json (Join-Path $Template 'connections.json')

    Assert-Equal 'folder' $connections.notes.mode 'notes mode'
    Assert-Equal 'inbox' $connections.notes.folder 'notes folder'
    Assert-Equal 'off' $connections.mail.mode 'mail mode'
    Assert-Equal 'off' $connections.tracker.mode 'tracker mode'
}

Test 'every script of the kit is plain ASCII, so Windows PowerShell 5.1 reads it right' {
    $scripts = @(git -C $KitRoot ls-files --cached --others --exclude-standard -- '*.ps1')
    Assert-True ($scripts.Count -gt 0) 'no script found'
    foreach ($script in $scripts) {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $KitRoot $script))
        Assert-True (@($bytes | Where-Object { $_ -gt 127 }).Count -eq 0) "$script holds a character outside ASCII"
    }
}
