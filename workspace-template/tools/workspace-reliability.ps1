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

function Get-CollectWindow([string]$Source) {
    # Where the searches of a source start: its cutoff, or seven days back for a source never read;
    # and its catch-ups, the watch-list entries added since, each searched from its own day.
    if (@('mail', 'tracker', 'chat') -cnotcontains $Source) { Stop-Run 'select takes mail, tracker or chat, then the JSON file of the matches of its searches.' }
    $path = Join-Path $Workspace 'state\last-collect.json'
    $prior = if (Test-Path -LiteralPath $path) { (Read-JsonFile $path).sources.$Source }
    @{
        prior    = $prior
        cutoff   = if ($prior.cutoff) { Read-Timestamp $prior.cutoff } else { (Read-Timestamp $Now).AddDays(-7) }
        catch_up = @($prior.catch_up | Where-Object { $_ })
    }
}

function Select-CollectionBatch([string]$Source, $Candidates) {
    # The batch a collect opens in a source, from the matches of its searches: those dated from the
    # cutoff on, but those read at the cutoff itself, and those a catch-up matched from its own day;
    # the catch-ups first, then the oldest, up to the cap. A capped catch-up never moves the cutoff
    # back: the source goes on from where it stood, and the catch-up from where it stopped.
    $window = Get-CollectWindow $Source
    $prior, $cutoff, $catchUp = $window.prior, $window.cutoff, $window.catch_up
    $nowMoment = Read-Timestamp $Now
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($id in @($prior.cursor_ids)) { if ($id) { [void]$seen.Add($id) } }
    $ids = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $new = @()
    $older = @()
    foreach ($item in @($Candidates)) {
        $when = Read-Timestamp $item.when
        if (-not "$($item.id)".Trim() -or -not $when -or -not $ids.Add("$($item.id)")) {
            Stop-Run 'Each match needs an id of its own and, in when, a date and time with its UTC offset. Only matches of the searches belong in this file.'
        }
        if ($when -gt $nowMoment) { continue }
        if ($when -ge $cutoff) { if (-not ($when -eq $cutoff -and $seen.Contains("$($item.id)"))) { $new += $item } }
        elseif (@($catchUp | Where-Object { @($item.matched_by) -ccontains $_.entry -and $when -ge (Read-Timestamp $_.from) }).Count) { $older += $item }
    }
    $byTime = @{ Expression = { (Read-Timestamp $_.when).UtcDateTime.Ticks } }, 'id'
    $older = @($older | Sort-Object $byTime)
    $new = @($new | Sort-Object $byTime)
    $cap = if ($Settings.per_source_cap -gt 0) { [int]$Settings.per_source_cap } else { 50 }
    $takenOld = @($older | Select-Object -First $cap)
    $takenNew = @($new | Select-Object -First ($cap - $takenOld.Count))
    $capped = $older.Count + $new.Count -gt $cap
    foreach ($item in $takenOld) { $item | Add-Member -NotePropertyName catch_up -NotePropertyValue $true -Force }
    if ($takenNew) {
        $next = if ($capped) { "$($takenNew[-1].when)" } else { $Now }
        $boundary = Read-Timestamp $next
        $cursor = @($takenNew | Where-Object { (Read-Timestamp $_.when) -eq $boundary } | ForEach-Object { "$($_.id)" })
        if ($cutoff -eq $boundary) { $cursor = @($prior.cursor_ids) + $cursor }
    }
    elseif ($capped) {
        # The cap went to the catch-ups: the source stays at its cutoff.
        $next = "$($prior.cutoff)"
        $cursor = @($prior.cursor_ids)
    }
    else {
        $next = $Now
        $cursor = @(if ($cutoff -eq $nowMoment) { $prior.cursor_ids })
    }
    # ponytail: a capped catch-up goes on from the date of the first match left, so a match of the
    # same date and time already taken is taken again. Keep cursor ids per catch-up if that matters.
    $left = @($older | Select-Object -Skip $takenOld.Count)
    $read = [ordered]@{ source = $Source; cutoff = $next; items = $takenOld.Count + $takenNew.Count; cap_reached = $capped; cursor_ids = @($cursor | Where-Object { $_ } | Select-Object -Unique) }
    if ($catchUp) {
        $read.caught_up = @($catchUp | Where-Object { $entry = $_.entry; -not @($left | Where-Object { @($_.matched_by) -ccontains $entry }).Count } | ForEach-Object { $_.entry })
        $read.catch_up = @(foreach ($entry in $catchUp) {
                $first = @($left | Where-Object { @($_.matched_by) -ccontains $entry.entry }) | Select-Object -First 1
                if ($first) { [ordered]@{ entry = $entry.entry; from = "$($first.when)" } }
            })
    }
    [ordered]@{ selected = @($takenOld) + @($takenNew); sources_read = $read }
}
