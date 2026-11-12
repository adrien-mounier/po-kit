# Stands in for the agent in the tests of the scenario runner. It starts no model: it is started
# in the workspace, reads its prompt on standard input as an agent does, and does as told.
#
#   -Note <name>      saves the prompt as a note of the inbox, as a routine saves a pasted text
#   -Connections <file>
#                     puts this file in place of the connections, as a routine does when it
#                     records the verification of a connector
#   -Proposal <file>  leaves this proposal pending, then has the register tool apply it
#   -Pending          leaves the proposal pending: nothing is applied
#   -ByHand           writes a record itself, which no routine may do
#   -Report <file>    writes down the folder it was started in, then the prompt it received
#   -ExitCode <n>     ends with this exit code
param([string]$Note, [string]$Connections, [string]$Proposal, [switch]$Pending, [switch]$ByHand, [string]$Report, [int]$ExitCode)

$prompt = [Console]::In.ReadToEnd()
if ($Report) { [IO.File]::WriteAllText($Report, (Get-Location).Path + "`n" + $prompt) }
if ($ByHand) { [IO.File]::WriteAllText('register\subjects\written-by-hand.json', '{ "id": "written-by-hand" }') }
if ($Note) { [IO.File]::WriteAllText("inbox\$Note", $prompt) }
if ($Connections) { Copy-Item -LiteralPath $Connections -Destination 'connections.json' }
if ($Proposal) {
    Copy-Item -LiteralPath $Proposal -Destination 'state\proposal.json'
    if (-not $Pending) { & powershell.exe -NoProfile -File tools\register.ps1 apply }
}
exit $ExitCode
