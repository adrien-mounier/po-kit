# verify: checks a stored view against the register, so that it cites no record that is missing
# or superseded. It writes nothing.
#
#   verify views\weekly\2026-03-10.md    the path of the view, from the workspace or absolute
#
# A view is verified when both hold:
# - it carries the stamp, whole, as the register tool gives it in one of its languages. export
#   prints the stamp of the view to write from it;
# - every record it cites is in the register and is not superseded. A record that is done, dropped
#   or closed is still a record to cite.
#
# A view cites a record by its identifier in square brackets, as Get-Cited reads it in the register
# tool: Title [identifier]. The agent's notes on the meetings, which the morning page shows, are
# checked the same way.
#
# A view that is not verified ends the run with a failure code, and one line per problem: the
# stamp, then each identifier concerned, once.

# The verdict is on a committed register, the one a stamp names.
Assert-RegisterCommitted
$given = "$($Arguments | Select-Object -First 1)"
$path = if ($given -and (Split-Path -IsAbsolute $given)) { $given } else { Join-Path $Workspace $given }
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Stop-Run "verify takes the path of a stored view, from the workspace or absolute$(if ($given) { ", and there is no file at '$given'" }): verify views\weekly\2026-03-10.md"
}
$text = [IO.File]::ReadAllText($path)
# A deck, views\steering\<date>.html, is read as its reader sees it, as Test-View says.
$html = $path -match '\.html$'
$problems = @(Test-View $text -Html:$html)
if ($problems) { Stop-Run (@("Not verified: $given") + @($problems | ForEach-Object { "- $_" })) }
if ($html) { $text = [Net.WebUtility]::HtmlDecode(($text -replace '<[^>]*>', '')) }
"Verified: $given carries its stamp, and the $(@(Get-Cited $text).Count) record(s) it cites are in the register and not superseded."
