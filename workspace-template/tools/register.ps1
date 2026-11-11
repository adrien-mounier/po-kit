# The register tool: the only program allowed to write the register. It runs without any model.
#
#   powershell -NoProfile -File tools\register.ps1 <command> [arguments] [-Today yyyy-mm-dd]
#
# It works on the workspace it sits in. -Today sets the date this run treats as today.
#
# Each command is one file under tools\commands: adding a command means adding a file. A command
# runs with everything defined here in scope ($Workspace, $Settings, $Today, the functions) and
# its own arguments in $Arguments. It ends a failed run with Stop-Run.
#
# Keep this file and the commands in plain ASCII: Windows PowerShell 5.1 misreads other
# characters in a script saved without a byte order mark.
param(
    [Parameter(Position = 0)][string]$Command,
    [string]$Today,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
)

$ErrorActionPreference = 'Stop'
$Utf8 = New-Object System.Text.UTF8Encoding $false
# Agents read the output as UTF-8. A run without a console cannot set this, and does not need to.
try { [Console]::OutputEncoding = $Utf8 } catch { }

$Tools = $PSScriptRoot
$Workspace = Split-Path -Parent $Tools
$ProposalPath = Join-Path $Workspace 'state\proposal.json'

function Stop-Run([string[]]$Lines) {
    # Says why the run cannot go on, and ends it with a failure code. Write-Host, so that the
    # lines are printed even when the caller is collecting the result of a function.
    $Lines | ForEach-Object { Write-Host $_ }
    $script:ExitCode = 1
    exit 1
}

function Read-JsonFile([string]$Path) {
    # Strictly UTF-8: a file saved in another encoding stops the run instead of being misread.
    # A byte order mark is tolerated on the way in.
    $strictUtf8 = New-Object System.Text.UTF8Encoding $false, $true
    $strictUtf8.GetString([IO.File]::ReadAllBytes($Path)).TrimStart([char]0xFEFF) | ConvertFrom-Json
}

function Write-TextFile([string]$Path, [string]$Text) {
    # Every file the register tool writes goes through here: UTF-8 without a byte order mark.
    [IO.File]::WriteAllText($Path, $Text, $Utf8)
}

function Write-JsonFile([string]$Path, $Value) {
    # ponytail: the shell's own JSON layout is wide and writes an apostrophe as a unicode escape.
    # It is valid, and the PO reads views, not records. Write a formatter here if records must
    # read well.
    Write-TextFile $Path ((ConvertTo-Json -InputObject $Value -Depth 20) + [Environment]::NewLine)
}

function Invoke-Git {
    # Runs git in the workspace, and stops the run when git fails.
    & git -C $Workspace @args
    if ($LASTEXITCODE -ne 0) { Stop-Run "git $($args[0]) failed. The last commit of the workspace is the recovery point." }
}

function Assert-RegisterCommitted {
    # The refusal shared by the commands that must not run on a register edited outside the
    # register tool. preview and apply call it before anything else, and so does any command added
    # later that validates or writes records. When a file under the register differs from the last
    # commit, the run ends with the list of these files and a failure code.
    $changes = @(Invoke-Git status --porcelain --untracked-files=all register)
    if (-not $changes) { return }
    $files = $changes | ForEach-Object {
        # A line of git status: two letters for what happened to the file, a space, its path.
        $happened = if ($_ -match '^(\?\?|.?A)') { 'added' } elseif ($_ -match '^.?D') { 'deleted' } else { 'modified' }
        "- ${happened}: $($_.Substring(3))"
    }
    Stop-Run (@('The register differs from its last commit: these files were changed outside the register tool, or left by a run that failed. Nothing was done.') +
        $files + 'Put them back as they are in the last commit, then run the command again. A change that is wanted goes through a proposal.')
}

function Push-ToBackup {
    # Pushes the last commit to the PO's backup: every remote of the workspace. The commit is what
    # saves the register, so a push that fails is a warning and never a failed run.
    #
    # git push reports on its error stream even when all goes well. Captured, each of these lines
    # is an error for Windows PowerShell 5.1, and would stop the run: errors may continue, in this
    # function only.
    $ErrorActionPreference = 'Continue'
    $remotes = @(Invoke-Git remote)
    if (-not $remotes) { 'Not pushed: the workspace has no remote.' }
    foreach ($remote in $remotes) {
        $said = @(& git -C $Workspace push $remote HEAD 2>&1 | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.Exception.Message } })
        if ($LASTEXITCODE -eq 0) { "Pushed to '$remote'." }
        else {
            "Warning: the push to '$remote' failed, so this backup is behind the workspace. The commit is saved in the workspace; the next apply pushes again. git said:"
            $said | Where-Object { $_ } | ForEach-Object { "  $_" }
        }
    }
}

function Test-IsoDate([string]$Text) {
    $parsed = [DateTime]::MinValue
    [DateTime]::TryParseExact($Text, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)
}

# --- Record definitions -------------------------------------------------------------------------
# tools\definitions holds one data file per record type, plus common.json for the fields every
# record carries. A field is defined by:
#   type          text, date, boolean, integer, list or object
#   required      true when a proposal must give it
#   allowed       the values accepted
#   allowed_from  the name of the list in settings.json that holds the values accepted
#   default       the value recorded when a proposal gives none
#   set_by        "tool" when only the register tool writes it
#   items         the definition of each item of a list
#   fields        the definitions of the fields of an object

$KindsOfValue = @{
    text = 'text'; date = 'an ISO date (yyyy-mm-dd)'; boolean = 'true or false'; integer = 'a whole number'
    list = 'a list'; object = 'a group of fields'
}

function Get-Definition([string]$Type) {
    # Where the records of a type are filed, and the definition of one record: the common fields,
    # then the type's own. A type's field replaces the common field of the same name.
    $own = Read-JsonFile (Join-Path $Tools "definitions\$Type.json")
    $fields = [ordered]@{}
    foreach ($part in (Read-JsonFile (Join-Path $Tools 'definitions\common.json')), $own) {
        foreach ($field in $part.fields.PSObject.Properties) { $fields[$field.Name] = $field.Value }
    }
    @{ folder = $own.folder; record = [pscustomobject]@{ type = 'object'; fields = [pscustomobject]$fields } }
}

function Test-Value($Definition, $Value, [string]$Name) {
    # What is wrong with a proposed value, against its definition: one reason per problem, and
    # nothing when the value is valid.
    if ($null -eq $Value -or ($Value -is [string] -and -not $Value.Trim())) {
        if ($Definition.required) { "missing required field '$Name'" }
        return
    }
    $isGroup = $Value -is [array] -or $Value -is [System.Management.Automation.PSCustomObject]
    $fits = switch ($Definition.type) {
        'text' { $Value -is [string] }
        'date' { $Value -is [string] -and (Test-IsoDate $Value) }
        'boolean' { $Value -is [bool] }
        'integer' { $Value -is [int] -or $Value -is [long] }
        'list' { $Value -is [array] }
        'object' { $Value -is [System.Management.Automation.PSCustomObject] }
    }
    if (-not $fits) {
        "field '$Name' must be $($KindsOfValue[$Definition.type])$(if (-not $isGroup) { ", not '$Value'" })"
        return
    }
    if ($Definition.type -eq 'object') {
        foreach ($given in $Value.PSObject.Properties) {
            $path = "$Name.$($given.Name)".TrimStart('.')
            $field = $Definition.fields.PSObject.Properties[$given.Name]
            if (-not $field) { "unknown field '$path'" }
            elseif ($field.Value.set_by -eq 'tool') { "field '$path' is set by the register tool" }
            else { Test-Value $field.Value $given.Value $path }
        }
        foreach ($field in $Definition.fields.PSObject.Properties) {
            if ($field.Value.required -and -not $Value.PSObject.Properties[$field.Name]) {
                "missing required field '$("$Name.$($field.Name)".TrimStart('.'))'"
            }
        }
        return
    }
    if ($Definition.type -eq 'list') {
        foreach ($item in $Value) {
            if ($null -eq $item) { "field '$Name' holds an empty item" } else { Test-Value $Definition.items $item $Name }
        }
        return
    }
    if ($Definition.allowed -and $Definition.allowed -cnotcontains $Value) {
        "field '$Name' is '$Value'; allowed: $($Definition.allowed -join ', ')"
    }
    if ($Definition.allowed_from) {
        $listed = @($Settings.($Definition.allowed_from))
        if ($listed -cnotcontains $Value) {
            "field '$Name' is '$Value'; settings.json lists under '$($Definition.allowed_from)': $(if ($listed) { $listed -join ', ' } else { 'nothing' })"
        }
    }
}

function Complete-Value($Definition, $Value) {
    # The value as it is recorded: every field of the definition present, with its default when
    # the proposal gave none.
    if ($Definition.type -eq 'object') {
        $object = [ordered]@{}
        foreach ($field in $Definition.fields.PSObject.Properties) {
            $given = if ($null -ne $Value) { $Value.PSObject.Properties[$field.Name] }
            $object[$field.Name] = Complete-Value $field.Value $(if ($given) { $given.Value })
        }
        return $object
    }
    if ($Definition.type -eq 'list') {
        $items = @()
        foreach ($item in $Value) { $items += , (Complete-Value $Definition.items $item) }
        return , $items
    }
    if ($null -eq $Value) { return $Definition.default }
    $Value
}

# --- Proposals ----------------------------------------------------------------------------------
# A routine never writes a record. It leaves one proposal in state\proposal.json:
#   { "operations": [ { "op": "create", "type": "subject", "fields": { ... } } ] }
# A line of a proposal is an operation, numbered from 1 as preview shows it.

function Get-PendingProposal {
    # The operations of the pending proposal, validated in full. Any problem refuses the proposal
    # whole: the run ends with the reasons and a failure code, and nothing is written.
    if (-not (Test-Path -LiteralPath $ProposalPath)) { Stop-Run 'No proposal is pending.' }
    $reasons = @()
    $operations = @()
    try { $operations = @((Read-JsonFile $ProposalPath).operations | Where-Object { $null -ne $_ }) }
    catch { $reasons += 'The proposal is not valid JSON written as UTF-8.' }
    if (-not $reasons -and -not $operations) { $reasons += 'The proposal holds no operation.' }

    $line = 0
    foreach ($operation in $operations) {
        $line++
        $problems = @(
            if ($operation.op -cne 'create') { "unknown operation '$($operation.op)'; allowed: create" }
            elseif ("$($operation.type)" -cnotmatch '^[a-z]+$' -or $operation.type -eq 'common' -or
                -not (Test-Path -LiteralPath (Join-Path $Tools "definitions\$($operation.type).json"))) {
                "unknown record type '$($operation.type)'"
            }
            elseif ($operation.fields -isnot [System.Management.Automation.PSCustomObject]) { 'the operation gives no fields' }
            else { Test-Value (Get-Definition $operation.type).record $operation.fields '' }
        )
        foreach ($problem in $problems) { $reasons += "Line ${line}: $problem." }
    }
    if ($reasons) { Stop-Run (@('Proposal refused. Nothing was written.') + @($reasons | ForEach-Object { "- $_" })) }
    $operations
}

# --- Run the command ----------------------------------------------------------------------------

if (-not $Today) { $Today = [DateTime]::Today.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) }
elseif (-not (Test-IsoDate $Today)) { Stop-Run "The date given as today must be an ISO date (yyyy-mm-dd), not '$Today'." }

$commandFile = Join-Path $Tools "commands\$Command.ps1"
if ($Command -cnotmatch '^[a-z]+$' -or -not (Test-Path -LiteralPath $commandFile)) {
    $known = (Get-ChildItem (Join-Path $Tools 'commands\*.ps1') | ForEach-Object { $_.BaseName }) -join ', '
    Stop-Run "Unknown command '$Command'. Commands: $known."
}
$Settings = Read-JsonFile (Join-Path $Workspace 'settings.json')
# An exit inside a command file only leaves that file, so the exit code is carried over here.
$ExitCode = 0
. $commandFile
exit $ExitCode
