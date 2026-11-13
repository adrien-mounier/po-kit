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
#                     those of the day, and {workday+N} for the Nth working day after it, {workday-N}
#                     before it
#   -Questions <file> leaves these open questions, dated the same way
#   -Alerts <file>    leaves these backlog alerts, dated the same way
#   -Check            has the register tool run the check
#   -Morning          has the register tool write the morning page
#   -Now <moment>     with -Morning, as of this moment rather than the clock's
#   -Intake <subject> has the register tool write the intake card of this subject
#   -Ranking          has the register tool write the ranked portfolio
#   -SteeringNotes <file>
#                     leaves this commentary of the steering pack, dated as the notes on the meetings
#   -Steering         has the register tool write the steering pack of the first committee it names
#   -Changes <file>   leaves this change proposal for the tracker
#   -BacklogApply <id>
#                     has the register tool apply this change of the change proposal
#   -Order <file>     leaves this order for the top of the backlog, dated as the notes on the
#                     meetings, then has the register tool write it as a view
#   -Weekly <file>    stores this text as the weekly synthesis of the day, with the stamp and the
#                     portfolio view that export prints in place of {stamp} and {portfolio}
#   -ByHand           writes a record itself, which no routine may do
#   -Report <file>    writes down the folder it was started in, then the prompt it received
#   -Say <text>       prints this text, as an agent prints its answer
#   -ExitCode <n>     ends with this exit code
#   -Stream           prints all it prints as a transcript does, one line of JSON per step, as
#                     Claude Code does with --output-format stream-json --verbose: last, the line
#                     of the result, which gives the text of -Say as its final answer
#   -Read <file>      with -Stream, shows this file in the transcript, as a file the agent opened
param([string]$Note, [string]$Connections, [string]$Proposal, [switch]$Pending, [switch]$Plain, [switch]$Check, [switch]$Morning, [string]$Weekly, [string]$Snapshot, [string]$MeetingNotes, [string]$Questions, [switch]$ByHand,
    [string]$Report, [string]$Say, [int]$ExitCode, [switch]$Stream, [string]$Intake, [switch]$Ranking, [string]$SteeringNotes, [switch]$Steering, [string]$Read, [string]$Changes, [string]$BacklogApply, [string]$Order, [string]$Alerts, [string]$Now)

$prompt = [Console]::In.ReadToEnd()
$steps = {
if ($Say) { $Say }
if ($Report) { [IO.File]::WriteAllText($Report, (Get-Location).Path + "`n" + $prompt) }
if ($ByHand) { [IO.File]::WriteAllText('register\subjects\written-by-hand.json', '{ "id": "written-by-hand" }') }
if ($Note) { [IO.File]::WriteAllText("inbox\$Note", $prompt) }
if ($Connections) { Copy-Item -LiteralPath $Connections -Destination 'connections.json' }
if ($Proposal) {
    Copy-Item -LiteralPath $Proposal -Destination 'state\proposal.json'
    if (-not $Pending) { & powershell.exe -NoProfile -File tools\register.ps1 apply $(if ($Plain) { 'plain' }) }
}
foreach ($given in @(@($Snapshot, 'state\calendar.json'), @($MeetingNotes, 'state\morning.json'), @($Questions, 'state\questions.json'), @($SteeringNotes, 'state\steering.json'), @($Order, 'state\backlog-order.json'), @($Alerts, 'state\backlog-alerts.json')) | Where-Object { $_[0] }) {
    $day = Get-Date
    $text = [IO.File]::ReadAllText($given[0]).Replace('{today}', $day.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)).Replace('{year}', $day.ToString('yyyy', [Globalization.CultureInfo]::InvariantCulture))
    $text = [regex]::Replace($text, '\{workday([+-])(\d+)\}', {
            param($Found)
            $at = (Get-Date).Date
            $step = if ($Found.Groups[1].Value -eq '-') { -1 } else { 1 }
            for ($left = [int]$Found.Groups[2].Value; $left -gt 0) { $at = $at.AddDays($step); if ('Saturday', 'Sunday' -notcontains $at.DayOfWeek) { $left-- } }
            $at.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        })
    [IO.File]::WriteAllText($given[1], $text)
}
if ($Changes) { Copy-Item -LiteralPath $Changes -Destination 'state\backlog-changes.json' }
if ($BacklogApply) { & powershell.exe -NoProfile -File tools\register.ps1 backlog apply $BacklogApply }
if ($Order) { & powershell.exe -NoProfile -File tools\register.ps1 backlog order }
if ($Check) { & powershell.exe -NoProfile -File tools\register.ps1 check }
if ($Morning) { & powershell.exe -NoProfile -File tools\register.ps1 morning $(if ($Now) { '-Now'; $Now }) }
if ($Intake) { & powershell.exe -NoProfile -File tools\register.ps1 view intake $Intake }
if ($Ranking) { & powershell.exe -NoProfile -File tools\register.ps1 view ranking }
if ($Steering) {
    $named = @(& powershell.exe -NoProfile -File tools\register.ps1 steering | Where-Object { $_ -match 'steering (\d{4}-\d\d-\d\d)$' } | ForEach-Object { $Matches[1] })
    if ($named) { & powershell.exe -NoProfile -File tools\register.ps1 steering $named[0] }
}
if ($Weekly) {
    # The register tool prints UTF-8; read it as such.
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }
    $today = (Get-Date).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $export = @(& powershell.exe -NoProfile -File tools\register.ps1 export $today)
    $stamp = @($export | Where-Object { $_ -like '> *' }) -join "`n"
    $portfolio = (@($export | Select-Object -Skip ([Array]::IndexOf($export, '## Portfolio view') + 1)) -join "`n").Trim()
    [IO.File]::WriteAllText("views\weekly\$today.md", [IO.File]::ReadAllText($Weekly).Replace('{stamp}', $stamp).Replace('{portfolio}', $portfolio))
}
}
if ($Stream) {
    '{"type":"system","subtype":"init"}'
    if ($Read) { '{"type":"user","tool_result":' + (ConvertTo-Json -InputObject ([IO.File]::ReadAllText($Read)) -Compress) + '}' }
    & $steps 2>&1 | ForEach-Object { '{"type":"assistant","text":' + (ConvertTo-Json -InputObject "$_" -Compress) + '}' }
    '{"type":"result","result":' + (ConvertTo-Json -InputObject "$Say" -Compress) + '}'
}
else { & $steps }
exit $ExitCode
