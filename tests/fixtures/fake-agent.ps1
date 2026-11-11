# Stands in for the agent in the tests of the scenario runner. It starts no model: it is started
# in the workspace, reads its prompt on standard input as an agent does, and does as told.
#
#   -Proposal <file>  leaves this proposal pending, then has the register tool apply it
#   -ByHand           writes a record itself, which no routine may do
#   -Report <file>    writes down the folder it was started in, then the prompt it received
#   -ExitCode <n>     ends with this exit code
param([string]$Proposal, [switch]$ByHand, [string]$Report, [int]$ExitCode)

$prompt = [Console]::In.ReadToEnd()
if ($Report) { [IO.File]::WriteAllText($Report, (Get-Location).Path + "`n" + $prompt) }
if ($ByHand) { [IO.File]::WriteAllText('register\subjects\written-by-hand.json', '{ "id": "written-by-hand" }') }
if ($Proposal) {
    Copy-Item -LiteralPath $Proposal -Destination 'state\proposal.json'
    & powershell.exe -NoProfile -File tools\register.ps1 apply
}
exit $ExitCode
