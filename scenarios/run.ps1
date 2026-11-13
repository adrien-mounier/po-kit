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
#     "collected": { ... },    when the scenario starts after a collect: the proposal of that
#                              collect, which the register tool applies before the agent starts
#     "prompt": "...",         all that the PO says: nobody answers a question of the agent
#     "expect": [ ... ] }      the expected facts
# and, when the scenario needs them, a folder workspace: its own files (notes for the inbox, a
# pending proposal, settings of its own), laid over the Example Bank workspace. Mail, tickets and
# chat messages are supplied there as folders of exported files, exports\mail, exports\tracker and
# exports\chat, with the connections that declare them and, in state\last-collect.json, how far an earlier collect read
# them.
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
#   { "file": "<path>", "lines": ["<text>", "<text>"] }             lines of the file contain these texts, in this
#                                                                   order, each on a line further down than the one before
#   { "verified": "<path>" }                                        the register tool's verify passes on this stored view
#   { "exported": "<path>", "since": "<date>" }                     every record this stored view cites is in what the
#                                                                   register tool's export prints for the period since that date
#   { "printed": "<command>", "line": "<text>" }                    a line of what the register tool prints for this command,
#                                                                   as "export {today}", contains the text
# A file is named from the workspace: the pending proposal is state/proposal.json, the portfolio
# view is views/portfolio.md. What the agent printed is ../agent-output.txt, beside the workspace:
# its answer, and all that it opened when its command prints that too (for Claude Code,
# --output-format stream-json --verbose in place of --output-format json), so that a fact can
# hold that a file was never opened. A path to a field goes down with dots, and into a list with a
# position from 0, or from -1 for the last: watch_list.people, history[0].field, history[-1].new.
# A value or a text is compared exactly: a text with its case, a list with its order. Name the
# fields of a group one by one.
#
# The register tool numbers a commitment, a decision or a risk in the year it is recorded, and
# files a note under the month it is processed. Anywhere in scenario.json and in the files of the
# scenario's workspace folder, {year}, {month} and {today} stand for those of the day of the run,
# as 2026, 2026-03 and 2026-03-02: the record C-{year}-002, the file inbox/done/{month}/workshop.md,
# a meeting of the calendar that starts at {today}T14:00:00+01:00. {workday+N} stands for the Nth
# working day, Monday to Friday, after the day of the run: a due date of {workday+3}.
#
# For each scenario, in a temporary folder of its own, the runner:
# 1. installs the kit: a workspace and a skills folder, as install.ps1 does on any machine;
# 2. lays the Example Bank workspace over it: the files under example-bank\workspace, the register
#    that example-bank\register.proposal.json describes, applied by the register tool on the day
#    of the run, then the scenario's own files, then the proposal the scenario gives as collected,
#    applied the same way;
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
$RunDay = Get-Date

# The installer and the register tool commit as whoever git knows on the machine, which may know
# nobody. In a scenario the commits are those of a fictional PO.
$env:GIT_AUTHOR_NAME = $env:GIT_COMMITTER_NAME = 'PO Kit scenarios'
$env:GIT_AUTHOR_EMAIL = $env:GIT_COMMITTER_EMAIL = 'scenarios@example.com'

function Read-Json([string]$Path) {
    [IO.File]::ReadAllText($Path) | ConvertFrom-Json
}

function Set-RunDate([string]$Text) {
    # The text with {year}, {month} and {today} written as those of the day of the run, and
    # {workday+N} as the Nth working day after it.
    foreach ($part in @{ '{year}' = 'yyyy'; '{month}' = 'yyyy-MM'; '{today}' = 'yyyy-MM-dd' }.GetEnumerator()) {
        $Text = $Text.Replace($part.Key, $RunDay.ToString($part.Value, [Globalization.CultureInfo]::InvariantCulture))
    }
    [regex]::Replace($Text, '\{workday\+(\d+)\}', {
            param($Found)
            $at = $RunDay.Date
            for ($left = [int]$Found.Groups[1].Value; $left -gt 0) { $at = $at.AddDays(1); if ('Saturday', 'Sunday' -notcontains $at.DayOfWeek) { $left-- } }
            $at.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        })
}

function Invoke-Script {
    # Runs a script of the kit once, as the PO or the agent would: Invoke-Script $path apply
    # Returns its output (standard output and errors together) and its exit code.
    $ErrorActionPreference = 'Continue'
    $lines = & powershell.exe -NoProfile -File @args 2>&1 | ForEach-Object { "$_" }
    @{ Output = ($lines -join "`n"); ExitCode = $LASTEXITCODE }
}

function New-ExampleBankWorkspace([string]$Folder, [string]$Scenario, $Collected) {
    # Steps 1 and 2: the workspace of the scenario, in $Folder\workspace, and the routines in
    # $Folder\skills. $Collected is the proposal the scenario gives as collected, if any.
    $workspace = Join-Path $Folder 'workspace'
    $run = Invoke-Script (Join-Path $Kit 'install.ps1') -Workspace $workspace -SkillsFolder (Join-Path $Folder 'skills')
    if ($run.ExitCode -ne 0) { throw "the kit did not install: $($run.Output)" }
    Copy-Item (Join-Path $ExampleBank 'workspace\*') $workspace -Recurse -Force
    Copy-Item (Join-Path $ExampleBank 'register.proposal.json') (Join-Path $workspace 'state\proposal.json')
    $run = Invoke-Script (Join-Path $workspace 'tools\register.ps1') apply
    if ($run.ExitCode -ne 0) { throw "the register of Example Bank was refused: $($run.Output)" }
    $own = Join-Path $Scenario 'workspace'
    if (Test-Path -LiteralPath $own) {
        Copy-Item (Join-Path $own '*') $workspace -Recurse -Force
        foreach ($file in Get-ChildItem -LiteralPath $own -Recurse -File) {
            $copy = Join-Path $workspace $file.FullName.Substring($own.Length + 1)
            $text = [IO.File]::ReadAllText($copy)
            $dated = Set-RunDate $text
            if ($dated -cne $text) { [IO.File]::WriteAllText($copy, $dated, $Utf8) }
        }
    }
    if ($Collected) {
        [IO.File]::WriteAllText((Join-Path $workspace 'state\proposal.json'), (ConvertTo-Json -InputObject $Collected -Depth 20), $Utf8)
        $run = Invoke-Script (Join-Path $workspace 'tools\register.ps1') apply
        if ($run.ExitCode -ne 0) { throw "the proposal the scenario gives as collected was refused: $($run.Output)" }
    }
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
    if ($Fact.verified) {
        $run = Invoke-Script (Join-Path $Workspace 'tools\register.ps1') verify $Fact.verified
        return @{ What = "the register tool verifies $($Fact.verified)"; Holds = ($run.ExitCode -eq 0); Found = $run.Output }
    }
    if ($Fact.exported) {
        # verify passes on any record that is not superseded, in the period or not. A view cites a
        # record by its identifier in square brackets, and the export prints a record the same way.
        $what = "every record that $($Fact.exported) cites is in the export since $($Fact.since)"
        $view = Join-Path $Workspace $Fact.exported
        if (-not (Test-Path -LiteralPath $view -PathType Leaf)) { return @{ What = $what; Holds = $false; Found = 'nothing: it is absent' } }
        $run = Invoke-Script (Join-Path $Workspace 'tools\register.ps1') export $Fact.since
        if ($run.ExitCode -ne 0) { return @{ What = $what; Holds = $false; Found = $run.Output } }
        $outside = @([regex]::Matches([IO.File]::ReadAllText($view), '\[([^\[\]]*)\]') | ForEach-Object { $_.Groups[1].Value -split ',' } |
                ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $run.Output.Contains("[$_]") } | Select-Object -Unique)
        return @{ What = $what; Holds = (-not $outside); Found = "not in the export: $($outside -join ', ')" }
    }
    if ($Fact.printed) {
        $run = Invoke-Script (Join-Path $Workspace 'tools\register.ps1') @($Fact.printed -split ' ')
        $lines = @($run.Output -split "`n" | Where-Object { $_.Contains($Fact.line) })
        return @{
            What = "what the register tool prints for $($Fact.printed) has a line containing `"$($Fact.line)`""; Holds = ($run.ExitCode -eq 0 -and $lines.Count -gt 0)
            Found = $(if ($run.ExitCode -eq 0) { 'no such line' } else { $run.Output })
        }
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
    else { throw "an expected fact names a record, a file, records, a view to verify, a view against the export or a command whose output to read: $(ConvertTo-FactJson $Fact)" }

    if ($Fact.PSObject.Properties['field']) {
        $expected = ConvertTo-FactJson $Fact.is
        $found = if ($path) { Get-FieldJson (Read-Json $path) $Fact.field } else { 'nothing: it is absent' }
        return @{ What = "${name}: $($Fact.field) is $expected"; Holds = ($found -ceq $expected); Found = $found }
    }
    if ($Fact.PSObject.Properties['lines']) {
        # Each text is looked for further down than the line that holds the text before it.
        $all = @(if ($path) { [IO.File]::ReadAllLines($path) })
        $at = -1
        $missing = foreach ($text in $Fact.lines) {
            do { $at++ } while ($at -lt $all.Count -and -not $all[$at].Contains($text))
            if ($at -ge $all.Count) { $text; break }
        }
        $texts = @($Fact.lines | ForEach-Object { '"' + $_ + '"' }) -join ', '
        return @{
            What = "$name has lines containing, in this order: $texts"; Holds = ($path -and -not $missing)
            Found = $(if ($path) { "no line containing `"$missing`" further down" } else { 'nothing: it is absent' })
        }
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
    $definition = Set-RunDate ([IO.File]::ReadAllText((Join-Path $Scenario 'scenario.json'))) | ConvertFrom-Json
    New-ExampleBankWorkspace $Folder $Scenario $definition.collected
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
