# Runs the kit's scenarios: in each one the agent follows a routine on the fictional workspace of
# Example Bank, then the expected facts are checked against what the workspace holds. No model
# grades the result. From a clone of the kit:
#
#   powershell -NoProfile -File scenarios\run.ps1 -Agent "<command>" [scenario ...] [-Keep]
#
#   -Agent     the command that starts the agent of this machine in non-interactive mode. It is
#              started in the scenario's workspace and reads its prompt on standard input.
#   scenario   the scenarios to run: the name of a folder beside this file, or the path of a
#              scenario folder. Every scenario beside this file when none is named.
#   -Keep      keeps the temporary folder of the run even when every scenario passed.
#
# Each scenario starts the agent once, and the agent costs money: the tests of the kit, which are
# free, are tests\run.ps1.
#
# The command is the machine's own. On the machine where the kit is built the agent is Claude
# Code, started without that machine's plugins, hooks and connectors, with the tools a routine
# needs and a spending limit per scenario:
#   -Agent "claude -p --model haiku --output-format json --no-session-persistence --setting-sources project --strict-mcp-config --allowedTools Read,Write,Edit,Glob,Grep,Bash,PowerShell --max-budget-usd 0.25"
#
# A scenario is a folder that holds scenario.json:
#   { "routine": "subject",    the routine to follow: the name of a folder under routines
#     "prompt": "...",         all that the PO says: nobody answers a question of the agent
#     "expect": [ ... ] }      the expected facts
# and, when the scenario needs them, a folder workspace: its own files (notes for the inbox, a
# pending proposal), laid over the Example Bank workspace. Mail and tickets are supplied there as
# folders of exported files, exports\mail and exports\tracker, with the connections that declare
# them and, in state\last-collect.json, how far an earlier collect read them.
#
# An expected fact is one of:
#   { "record": "<identifier>" }                                    the register holds the record
#   { "record": "<identifier>", "absent": true }                    it does not
#   { "record": "<identifier>", "field": "<path>", "is": <value> }  the record holds this value
#   { "records": "subjects", "count": 4 }                           how many records a folder of the register holds
#   { "file": "<path>" }                                            the workspace holds the file
#   { "file": "<path>", "absent": true }                            it does not
#   { "file": "<path>", "field": "<path>", "is": <value> }          the file, read as JSON, holds this value
#   { "file": "<path>", "line": "<text>" }                          a line of the file contains the text
#   { "file": "<path>", "line": "<text>", "absent": true }          no line of the file does
# A file is named from the workspace: the pending proposal is state/proposal.json, the portfolio
# view is views/portfolio.md. A path to a field goes down with dots, and into a list with a
# position from 0, or from -1 for the last: watch_list.people, history[0].field, history[-1].new.
# A value or a text is compared exactly: a text with its case, a list with its order. Name the
# fields of a group one by one.
#
# The register tool numbers a commitment, a decision or a risk in the year it is recorded, and
# files a note under the month it is processed. Anywhere in scenario.json, {year}, {month} and
# {today} stand for those of the day of the run, as 2026, 2026-03 and 2026-03-02: the record
# C-{year}-002, the file inbox/done/{month}/workshop.md.
#
# For each scenario, in a temporary folder of its own, the runner:
# 1. installs the kit: a workspace and a skills folder, as install.ps1 does on any machine;
# 2. lays the Example Bank workspace over it: the files under example-bank\workspace, the register
#    that example-bank\register.proposal.json describes, applied by the register tool on the day
#    of the run, then the scenario's own files;
# 3. starts the agent in the workspace, with a prompt that names the routine and gives what the PO
#    says. What the agent prints is kept beside the workspace, in agent-output.txt;
# 4. checks each expected fact, and that the register holds only what the register tool committed.
# Nothing outside that temporary folder is touched. When a fact fails, the folder is kept and the
# exit code is 1.
#
# ponytail: a run lasts as long as its agent. Give the agent's own command its limits (turns,
# budget); add a timeout here if an agent ever hangs.
#
# Keep this file in plain ASCII: Windows PowerShell 5.1 misreads other characters in a script
# saved without a byte order mark.
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Agent,
    [switch]$Keep,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Scenarios
)

$ErrorActionPreference = 'Stop'
$Kit = Split-Path -Parent $PSScriptRoot
$ExampleBank = Join-Path $PSScriptRoot 'example-bank'
$Utf8 = New-Object System.Text.UTF8Encoding $false
try { [Console]::OutputEncoding = $Utf8 } catch { }

# The installer and the register tool commit as whoever git knows on the machine, which may know
# nobody. In a scenario the commits are those of a fictional PO.
$env:GIT_AUTHOR_NAME = $env:GIT_COMMITTER_NAME = 'PO Kit scenarios'
$env:GIT_AUTHOR_EMAIL = $env:GIT_COMMITTER_EMAIL = 'scenarios@example.com'

function Read-Json([string]$Path) {
    [IO.File]::ReadAllText($Path) | ConvertFrom-Json
}

function Invoke-Script {
    # Runs a script of the kit once, as the PO or the agent would: Invoke-Script $path apply
    # Returns its output (standard output and errors together) and its exit code.
    $ErrorActionPreference = 'Continue'
    $lines = & powershell.exe -NoProfile -File @args 2>&1 | ForEach-Object { "$_" }
    @{ Output = ($lines -join "`n"); ExitCode = $LASTEXITCODE }
}

function New-ExampleBankWorkspace([string]$Folder, [string]$Scenario) {
    # Steps 1 and 2: the workspace of the scenario, in $Folder\workspace, and the routines in
    # $Folder\skills.
    $workspace = Join-Path $Folder 'workspace'
    $run = Invoke-Script (Join-Path $Kit 'install.ps1') -Workspace $workspace -SkillsFolder (Join-Path $Folder 'skills')
    if ($run.ExitCode -ne 0) { throw "the kit did not install: $($run.Output)" }
    Copy-Item (Join-Path $ExampleBank 'workspace\*') $workspace -Recurse -Force
    Copy-Item (Join-Path $ExampleBank 'register.proposal.json') (Join-Path $workspace 'state\proposal.json')
    $run = Invoke-Script (Join-Path $workspace 'tools\register.ps1') apply
    if ($run.ExitCode -ne 0) { throw "the register of Example Bank was refused: $($run.Output)" }
    $own = Join-Path $Scenario 'workspace'
    if (Test-Path -LiteralPath $own) { Copy-Item (Join-Path $own '*') $workspace -Recurse -Force }
}

function Start-Agent([string]$Folder, [string]$Prompt) {
    # Step 3: runs the agent's command in the workspace, the prompt on its standard input, and
    # returns its exit code. The command line is handed over as it was given, quotes included.
    $in, $out, $err = 'prompt.txt', 'agent-output.txt', 'agent-errors.txt' | ForEach-Object { Join-Path $Folder $_ }
    [IO.File]::WriteAllText($in, $Prompt, $Utf8)
    $start = New-Object Diagnostics.ProcessStartInfo 'cmd.exe', "/d /s /c `"$Agent < `"$in`" > `"$out`" 2> `"$err`"`""
    $start.WorkingDirectory = Join-Path $Folder 'workspace'
    $start.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($start)
    $process.WaitForExit()
    $process.ExitCode
}

function Get-FieldJson($Document, [string]$Path) {
    # The value a JSON document holds at a path, written as JSON on one line.
    $value = $Document
    foreach ($step in $Path.Split('.')) {
        if ($step -notmatch '^([^\[\]]+)(\[(-?[0-9]+)\])?$') { throw "'$Path' is not a path to a field" }
        $value = $value.($Matches[1])
        if ($Matches[2]) { $value = @($value)[[int]$Matches[3]] }
    }
    ConvertTo-FactJson $value
}

function ConvertTo-FactJson($Value) {
    if ($null -eq $Value) { 'null' } else { ConvertTo-Json -InputObject $Value -Depth 20 -Compress }
}

function Test-Fact($Fact, [string]$Workspace) {
    # Step 4, for one expected fact: what it expects, in words (What), whether the workspace
    # agrees (Holds), and what the workspace holds when it does not (Found).
    if ($Fact.records) {
        $count = @(Get-ChildItem -LiteralPath (Join-Path $Workspace "register\$($Fact.records)") -Recurse -File -Filter *.json).Count
        return @{ What = "register/$($Fact.records) holds $($Fact.count) record(s)"; Holds = ($count -eq $Fact.count); Found = "$count record(s)" }
    }
    if ($Fact.record) {
        # An identifier is the file name of its record, wherever the register files it.
        $name = "record $($Fact.record)"
        $path = Get-ChildItem -LiteralPath (Join-Path $Workspace 'register') -Recurse -File -Filter "$($Fact.record).json" |
            Select-Object -First 1 | ForEach-Object { $_.FullName }
    }
    elseif ($Fact.file) {
        $name = "file $($Fact.file)"
        $path = Join-Path $Workspace $Fact.file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $path = $null }
    }
    else { throw "an expected fact names a record, a file or records: $(ConvertTo-FactJson $Fact)" }

    if ($Fact.PSObject.Properties['field']) {
        $expected = ConvertTo-FactJson $Fact.is
        $found = if ($path) { Get-FieldJson (Read-Json $path) $Fact.field } else { 'nothing: it is absent' }
        return @{ What = "${name}: $($Fact.field) is $expected"; Holds = ($found -ceq $expected); Found = $found }
    }
    if ($Fact.PSObject.Properties['line']) {
        $lines = @(if ($path) { [IO.File]::ReadAllLines($path) | Where-Object { $_.Contains($Fact.line) } })
        if ($Fact.absent) { return @{ What = "$name has no line containing `"$($Fact.line)`""; Holds = ($lines.Count -eq 0); Found = ($lines -join "`n") } }
        return @{ What = "$name has a line containing `"$($Fact.line)`""; Holds = ($lines.Count -gt 0); Found = $(if ($path) { 'no such line' } else { 'nothing: it is absent' }) }
    }
    if ($Fact.absent) { return @{ What = "$name is absent"; Holds = (-not $path); Found = 'it is there' } }
    @{ What = "$name is there"; Holds = [bool]$path; Found = 'it is absent' }
}

function Invoke-Scenario([string]$Scenario, [string]$Folder) {
    # Runs one scenario in its temporary folder, and returns what Test-Fact returns for each
    # expected fact.
    $text = [IO.File]::ReadAllText((Join-Path $Scenario 'scenario.json'))
    $day = Get-Date
    foreach ($part in @{ '{year}' = 'yyyy'; '{month}' = 'yyyy-MM'; '{today}' = 'yyyy-MM-dd' }.GetEnumerator()) {
        $text = $text.Replace($part.Key, $day.ToString($part.Value, [Globalization.CultureInfo]::InvariantCulture))
    }
    $definition = $text | ConvertFrom-Json
    New-ExampleBankWorkspace $Folder $Scenario
    $workspace = Join-Path $Folder 'workspace'
    $routine = Join-Path $Folder "skills\$($definition.routine)\SKILL.md"
    if (-not (Test-Path -LiteralPath $routine)) { throw "the kit has no routine '$($definition.routine)'" }

    $exit = Start-Agent $Folder "Follow the routine written in this file: $routine`n`nThe PO says:`n$($definition.prompt)`n"

    @{ What = 'the agent ran to its end'; Holds = ($exit -eq 0); Found = "exit code $exit, and what it printed is in $Folder" }
    foreach ($fact in $definition.expect) { Test-Fact $fact $workspace }
    $outside = @(git -C $workspace status --porcelain --untracked-files=all register)
    @{ What = 'the register holds only what the register tool committed'; Holds = (-not $outside); Found = ($outside -join '; ') }
}

if (-not $Agent) {
    Write-Host 'Give the command that starts the agent of this machine in non-interactive mode:'
    Write-Host '  powershell -NoProfile -File scenarios\run.ps1 -Agent "<command>" [scenario ...]'
    exit 1
}
if (-not $Scenarios) {
    $Scenarios = @(Get-ChildItem -LiteralPath $PSScriptRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'scenario.json') } | ForEach-Object { $_.Name })
}

$root = Join-Path ([IO.Path]::GetTempPath()) ('po-kit-scenarios-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$passed = 0
foreach ($scenario in $Scenarios) {
    $folder = if (Test-Path -LiteralPath $scenario -PathType Container) { (Resolve-Path -LiteralPath $scenario).Path } else { Join-Path $PSScriptRoot $scenario }
    $name = Split-Path -Leaf $folder
    Write-Host ''
    Write-Host $name
    $failed = 0
    try {
        if (-not (Test-Path -LiteralPath (Join-Path $folder 'scenario.json'))) { throw "no scenario '$scenario': a scenario is a folder that holds scenario.json" }
        foreach ($fact in Invoke-Scenario $folder (Join-Path $root $name)) {
            if ($fact.Holds) { Write-Host "  ok    $($fact.What)" }
            else {
                $failed++
                Write-Host "  FAIL  $($fact.What)"
                Write-Host "        found: $($fact.Found)"
            }
        }
    }
    catch {
        $failed++
        Write-Host "  FAIL  $($_.Exception.Message)"
    }
    if (-not $failed) { $passed++ }
}

Write-Host ''
Write-Host "$($Scenarios.Count) scenario(s): $passed passed, $($Scenarios.Count - $passed) failed"
if (Test-Path -LiteralPath $root) {
    if ($passed -eq $Scenarios.Count -and -not $Keep) { Remove-Item -LiteralPath $root -Recurse -Force }
    else { Write-Host "Kept: $root" }
}
if ($passed -ne $Scenarios.Count) { exit 1 }
