# select: where the searches of a collect start in a source, and which of their matches to open.
#   select mail                         the cutoff of mail and its catch-ups, to search from
#   select mail state\mail-matches.json  the batch to open, and the sources_read entry of the proposal
# Each match has id (its identifier and version, or the path of its file), when (its date and
# time, with its UTC offset), where (what finds it again) and, for a catch-up, matched_by (the
# watch-list entries its search was for, as "people: the tech lead"). It writes nothing.
$source = "$($Arguments | Select-Object -First 1)"
$given = "$($Arguments | Select-Object -Skip 1 -First 1)"
if (-not $given) {
    $window = Get-CollectWindow $source
    ConvertTo-Json -Depth 10 -InputObject ([ordered]@{
            source    = $source
            search_from = Format-Timestamp $window.cutoff
            first_read = -not $window.prior.cutoff
            catch_up  = @($window.catch_up)
        })
    return
}
$path = if (Split-Path -IsAbsolute $given) { $given } else { Join-Path $Workspace $given }
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Stop-Run "There is no file of matches at '$given'." }
$batch = Select-CollectionBatch $source (Read-JsonFile $path)
ConvertTo-Json -InputObject $batch -Depth 10
