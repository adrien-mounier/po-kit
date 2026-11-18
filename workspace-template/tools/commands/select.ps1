# select: choose a bounded batch from matched metadata before opening message bodies.
#   select mail state\mail-matches.json
# Each candidate has id (native ID, or stable versioned export path), when (timestamp),
# and optionally where (the exact path or native reference). This command writes nothing.
$source = "$($Arguments | Select-Object -First 1)"
$given = "$($Arguments | Select-Object -Skip 1 -First 1)"
if (-not $given) { Stop-Run 'select takes a source and a JSON file of matched metadata.' }
$path = if (Split-Path -IsAbsolute $given) { $given } else { Join-Path $Workspace $given }
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Stop-Run "The matched metadata file '$given' is not available." }
$batch = Select-CollectionBatch $source (Read-JsonFile $path)
ConvertTo-Json -InputObject $batch -Depth 10
