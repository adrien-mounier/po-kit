# Helpers of the register tool, dot-sourced by register.ps1: the PO's time zone, the register state
# a view names, the batch a collect opens in a source, and the path of a note once filed.

function Convert-WorkspaceMoment([DateTimeOffset]$Moment) {
    if (-not "$($Settings.timezone)".Trim()) { return $Moment }
    try { $zone = [TimeZoneInfo]::FindSystemTimeZoneById($Settings.timezone) }
    catch { Stop-Run "Unknown workspace timezone '$($Settings.timezone)'. Use a Windows timezone ID in settings.json." }
    [TimeZoneInfo]::ConvertTime($Moment, $zone)
}

function Convert-CalendarSnapshot($Snapshot) {
    $read = Read-Timestamp $Snapshot.read_at
    if ($read) { $Snapshot.read_at = Format-Timestamp (Convert-WorkspaceMoment $read) }
    foreach ($meeting in $Snapshot.meetings) {
        foreach ($part in 'start', 'end') {
            $moment = Read-Timestamp $meeting.$part
            if ($moment) { $meeting.$part = Format-Timestamp (Convert-WorkspaceMoment $moment) }
        }
    }
    $Snapshot
}

function Get-ViewRegisterRevision([string]$Text, [switch]$Html) {
    if ($Html) { $Text = [Net.WebUtility]::HtmlDecode(($Text -replace '<[^>]*>', '')) }
    $lines = ($Text -split '\r?\n' | ForEach-Object { $_.Trim() }) -join "`n"
    foreach ($file in Get-ChildItem (Join-Path $Tools 'labels\*.json')) {
        $label = (Read-JsonFile $file.FullName).stamp.register_state
        $pattern = '(?m)^(?:> )?' + [regex]::Escape($label).Replace('\{0}', '(?<revision>[a-f0-9]{12,64})') + '$'
        if ($lines -cmatch $pattern) { return $Matches.revision }
    }
}

function Test-CurrentViewRevision([string]$Text, [switch]$Html) {
    $revision = Get-ViewRegisterRevision $Text -Html:$Html
    $current = "$(Invoke-Git rev-parse 'HEAD:register')".Trim()
    if (-not $revision -or -not $current.StartsWith($revision, [StringComparison]::Ordinal)) {
        'The view is stale: its register revision differs from the current committed register. Regenerate the current draft; use verify <path> --historical for an archive.'
    }
}

function Test-HistoricalCited([string[]]$Ids, [string]$Revision) {
    if ($Revision -cnotmatch '^[a-f0-9]{12,64}$') { 'The historical register revision is absent or invalid.'; return }
    $ErrorActionPreference = 'Continue'
    $tree = @(& git -C $Workspace rev-parse --verify ($Revision + '^{tree}') 2>$null)
    if ($LASTEXITCODE -ne 0) { 'The register tree named by the archive is not available in this workspace history.'; return }
    $paths = @(& git -C $Workspace ls-tree -r --name-only "$tree")
    foreach ($id in $Ids) {
        $path = @($paths | Where-Object { [IO.Path]::GetFileNameWithoutExtension($_) -ceq $id -and $_ -like '*.json' }) | Select-Object -First 1
        if (-not $path) { "$id is not in the historical register."; continue }
        $record = (& git -C $Workspace show "${tree}:$path" | Out-String) | ConvertFrom-Json
        if ($record.status -ceq 'superseded') { "$id is superseded in the historical register by $($record.superseded_by)." }
    }
}

function Test-UsableSteeringDeck([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $text = [IO.File]::ReadAllText($Path)
    @((Test-View $text -Html -RequireCurrent)).Count -eq 0
}

function Resolve-ArchivedSourcePath([string]$Where) {
    $wherePath = $Where.Replace('/', '\')
    if ($wherePath.StartsWith('inbox\', [StringComparison]::OrdinalIgnoreCase)) {
        $original = [IO.Path]::GetFullPath((Join-Path $Workspace $wherePath))
        if ($FiledNotes.ContainsKey($original)) { return $FiledNotes[$original].Substring($Workspace.Length + 1).Replace('\', '/') }
    }
    $Where
}

function Set-ArchivedSourcePaths($Operations) {
    foreach ($operation in $Operations) {
        foreach ($source in @($operation.source, $operation.fields.source) | Where-Object { $null -ne $_ }) {
            $source.where = Resolve-ArchivedSourcePath "$($source.where)"
        }
    }
}

function Select-CollectionBatch([string]$Source, $Candidates) {
    if (@('mail', 'tracker', 'chat') -cnotcontains $Source) { Stop-Run 'select takes mail, tracker or chat, and a JSON file of matched metadata.' }
    $path = Join-Path $Workspace 'state\last-collect.json'
    $prior = if (Test-Path -LiteralPath $path) { (Read-JsonFile $path).sources.$Source }
    $cutoff = if ($prior.cutoff) { Read-Timestamp $prior.cutoff } else { (Read-Timestamp $Now).AddDays(-7) }
    $nowMoment = Read-Timestamp $Now
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($id in @($prior.cursor_ids)) { if ($id) { [void]$seen.Add($id) } }
    $ids = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $valid = @(foreach ($item in @($Candidates)) {
        $when = Read-Timestamp $item.when
        if (-not "$($item.id)".Trim() -or -not $when -or -not $ids.Add("$($item.id)")) {
            Stop-Run 'Each candidate needs a distinct stable id and a timestamp with offset in when. Only matched metadata belongs in this file.'
        }
        if ($when -ge $cutoff -and $when -le $nowMoment -and -not ($when -eq $cutoff -and $seen.Contains("$($item.id)"))) { $item }
    })
    $cap = if ($Settings.per_source_cap -gt 0) { [int]$Settings.per_source_cap } else { 50 }
    $selected = @($valid | Sort-Object @{ Expression = { (Read-Timestamp $_.when).UtcDateTime.Ticks } }, id | Select-Object -First $cap)
    $capped = $valid.Count -gt $cap
    $next = if ($capped) { "$($selected[-1].when)" } else { $Now }
    $boundary = Read-Timestamp $next
    $cursor = @($selected | Where-Object { (Read-Timestamp $_.when) -eq $boundary } | ForEach-Object { "$($_.id)" })
    if ($cutoff -eq $boundary) { $cursor = @($prior.cursor_ids) + $cursor }
    [ordered]@{
        selected = $selected
        sources_read = [ordered]@{ source = $Source; cutoff = $next; items = $selected.Count; cap_reached = $capped; cursor_ids = @($cursor | Where-Object { $_ } | Select-Object -Unique) }
    }
}
