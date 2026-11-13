# Stands in for the agent in the tests of the scenario runner. It starts no model: it is started
# in the workspace, reads its prompt on standard input as an agent does, and does as told.
#
#   -Note <name>      saves the prompt as a note of the inbox, as a routine saves a pasted text
#   -Connections <file>
#                     puts this file in place of the connections, as a routine does when it
#                     records the verification of a connector
#   -Proposal <file>  leaves this proposal pending, then has the register tool apply it
#   -Pending          leaves the proposal pending: nothing is applied
#   -Plain            has the register tool apply the plain facts only: the other lines stay pending
#   -Snapshot <file>  leaves this calendar snapshot, as the morning routine writes it from the calendar
#   -MeetingNotes <file>
#                     leaves these notes on the meetings; in both files {today} and {year} stand for
#                     those of the day, and {workday+N} for the Nth working day after it
#   -Check            has the register tool run the check
#   -Morning          has the register tool write the morning page
#   -Weekly <file>    stores this text as the weekly synthesis of the day, with the stamp and the
#                     portfolio view that export prints in place of {stamp} and {portfolio}
#   -ByHand           writes a record itself, which no routine may do
#   -Report <file>    writes down the folder it was started in, then the prompt it received
#   -Say <text>       prints this text, as an agent prints its answer
#   -ExitCode <n>     ends with this exit code
param([string]$Note, [string]$Connections, [string]$Proposal, [switch]$Pending, [switch]$Plain, [switch]$Check, [switch]$Morning, [string]$Weekly, [string]$Snapshot, [string]$MeetingNotes, [switch]$ByHand,
    [string]$Report, [string]$Say, [int]$ExitCode)

$prompt = [Console]::In.ReadToEnd()
if ($Say) { $Say }
if ($Report) { [IO.File]::WriteAllText($Report, (Get-Location).Path + "`n" + $prompt) }
if ($ByHand) { [IO.File]::WriteAllText('register\subjects\written-by-hand.json', '{ "id": "written-by-hand" }') }
if ($Note) { [IO.File]::WriteAllText("inbox\$Note", $prompt) }
if ($Connections) { Copy-Item -LiteralPath $Connections -Destination 'connections.json' }
if ($Proposal) {
    Copy-Item -LiteralPath $Proposal -Destination 'state\proposal.json'
    if (-not $Pending) { & powershell.exe -NoProfile -File tools\register.ps1 apply $(if ($Plain) { 'plain' }) }
}
foreach ($given in @(@($Snapshot, 'state\calendar.json'), @($MeetingNotes, 'state\morning.json')) | Where-Object { $_[0] }) {
    $day = Get-Date
    $text = [IO.File]::ReadAllText($given[0]).Replace('{today}', $day.ToString('yyyy-MM-dd')).Replace('{year}', $day.ToString('yyyy'))
    $text = [regex]::Replace($text, '\{workday\+(\d+)\}', {
            param($Found)
            $at = (Get-Date).Date
            for ($left = [int]$Found.Groups[1].Value; $left -gt 0) { $at = $at.AddDays(1); if ('Saturday', 'Sunday' -notcontains $at.DayOfWeek) { $left-- } }
            $at.ToString('yyyy-MM-dd')
        })
    [IO.File]::WriteAllText($given[1], $text)
}
if ($Check) { & powershell.exe -NoProfile -File tools\register.ps1 check }
if ($Morning) { & powershell.exe -NoProfile -File tools\register.ps1 morning }
if ($Weekly) {
    # The register tool prints UTF-8; read it as such.
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }
    $today = (Get-Date).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $export = @(& powershell.exe -NoProfile -File tools\register.ps1 export $today)
    $stamp = @($export | Where-Object { $_ -like '> *' }) -join "`n"
    $portfolio = (@($export | Select-Object -Skip ([Array]::IndexOf($export, '## Portfolio view') + 1)) -join "`n").Trim()
    [IO.File]::WriteAllText("views\weekly\$today.md", [IO.File]::ReadAllText($Weekly).Replace('{stamp}', $stamp).Replace('{portfolio}', $portfolio))
}
exit $ExitCode
