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
# A view cites a record by its identifier in square brackets, as the portfolio view does:
# Title [identifier]. Several identifiers share brackets when commas separate them:
# [C-2026-001, D-2026-002]. A pair of square brackets is a citation only when every part between
# its commas is the identifier of a record: a numbered identifier by its shape (C-2026-004),
# whether the register holds it or not, or the identifier of a subject that the register holds.
# Any other pair is text, as a ticket reference in a title, [REQ#4521], and is not read.
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

# The stamp is the lines Get-Stamp gives, one under the other, in the labels of one language.
$lines = ($text -split '\r?\n' | ForEach-Object { $_.TrimEnd() }) -join "`n"
$stamped = $false
foreach ($file in Get-ChildItem (Join-Path $Tools 'labels\*.json')) {
    $stamp = (Read-JsonFile $file.FullName).stamp
    $generated, $state, $collect, $notCovered, $noCollect = $stamp.generated, $stamp.register_state, $stamp.last_collect, $stamp.not_covered, $stamp.no_collect |
        ForEach-Object { '> ' + [regex]::Escape($_).Replace('\{0}', '.+') }
    if ($lines -cmatch "(?m)^$generated\n$state\n(?:$noCollect|$collect\n$notCovered)$") { $stamped = $true }
}

# The shape of a numbered identifier, whatever its type: the prefix of a type, a year, a number.
$prefixes = @(Get-ChildItem (Join-Path $Tools 'definitions\*.json') -Exclude common.json | ForEach-Object { (Read-JsonFile $_.FullName).identifier_prefix } | Where-Object { $_ })
$numbered = "^($($prefixes -join '|'))-[0-9]{4}-[0-9]+$"
$cited = @([regex]::Matches($text, '\[([^\[\]]*)\]') | ForEach-Object {
        $parts = @($_.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() })
        # Text, unless every part is an identifier.
        if (-not @($parts | Where-Object { $_ -cnotmatch $numbered -and (Find-Record $_).type -ne 'subject' }).Count) { $parts }
    } | Select-Object -Unique)
$problems = @(
    if (-not $stamped) { 'The stamp is absent, or not whole as the register tool gives it. export prints the stamp of the view to write from it.' }
    foreach ($id in $cited) {
        $found = Find-Record $id
        if (-not $found) { "$id is not in the register." }
        elseif ($found.record.status -ceq 'superseded') { "$id is superseded by $($found.record.superseded_by)." }
    }
)
if ($problems) { Stop-Run (@("Not verified: $given") + @($problems | ForEach-Object { "- $_" })) }
"Verified: $given carries its stamp, and the $($cited.Count) record(s) it cites are in the register and not superseded."
