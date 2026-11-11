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
#   allowed_from  the list in settings.json that holds the values accepted: its name, or
#                 name.field when the list holds groups of fields (objectives.number)
#   default       the value recorded when a proposal gives none
#   set_by        "tool" when only the register tool writes it
#   items         the definition of each item of a list
#   fields        the definitions of the fields of an object
#
# A type's file also says how its records are filed and identified:
#   folder             the folder of the type, in the workspace
#   folder_per_year    true when its records are filed in one folder per year recorded
#   identifier_prefix  the letter that opens its identifiers: C gives C-2026-001, the year recorded
#                      then a number. A type without one is identified by a slug of the title.
# An identifier equals the file name, so a record is found from its identifier alone.

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
    @{
        folder = $own.folder; folder_per_year = $own.folder_per_year; identifier_prefix = $own.identifier_prefix
        record = [pscustomobject]@{ type = 'object'; fields = [pscustomobject]$fields }
    }
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
        $listed = $Settings
        foreach ($part in $Definition.allowed_from.Split('.')) { $listed = $listed.$part }
        $listed = @($listed | Where-Object { $null -ne $_ })
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
#   { "operations": [ { "op": "create", "type": "subject", "interpreted": false, "fields": { ... } } ] }
# A line of a proposal is an operation, numbered from 1 as preview shows it. Each one states
# "interpreted": true when the routine interpreted its source (a decision, a status change, an
# inferred deadline), false when it is a plain fact quoted from the source.
#
# A record other than a subject names its subject in the field "subject": the identifier of a
# subject of the register, or "line N" for the subject that line N, an earlier line of the same
# proposal, creates. apply records the identifier that subject received.

function Get-LineNamed($Subject) {
    # N when a record names "line N" as its subject, nothing when it names a subject of the register.
    if ($Subject -is [string] -and $Subject -cmatch '^line ([1-9][0-9]{0,5})$') { [int]$Matches[1] }
}

function Test-Subject([string]$Subject, [int]$Line, $Operations) {
    # What is wrong with the subject named by the record of a line: nothing when it exists.
    $named = Get-LineNamed $Subject
    $exists = if ($named) { $named -lt $Line -and $Operations[$named - 1].op -ceq 'create' -and $Operations[$named - 1].type -ceq 'subject' }
    else {
        # Identifiers of subjects are slugs: anything else is not looked for among the files.
        $Subject -cmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -and
        (Test-Path -LiteralPath (Join-Path $Workspace "$((Get-Definition 'subject').folder)\$Subject.json"))
    }
    if (-not $exists) { "subject '$Subject' exists neither in the register nor earlier in this proposal (the subject that line N creates is named 'line N')" }
}

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
            if ($operation.interpreted -isnot [bool]) { 'the operation must state "interpreted": true when it is interpreted, false when it is a plain fact' }
            if ($operation.op -cne 'create') { "unknown operation '$($operation.op)'; allowed: create" }
            elseif ("$($operation.type)" -cnotmatch '^[a-z]+$' -or $operation.type -eq 'common' -or
                -not (Test-Path -LiteralPath (Join-Path $Tools "definitions\$($operation.type).json"))) {
                "unknown record type '$($operation.type)'"
            }
            elseif ($operation.fields -isnot [System.Management.Automation.PSCustomObject]) { 'the operation gives no fields' }
            else {
                $record = (Get-Definition $operation.type).record
                Test-Value $record $operation.fields ''
                $subject = $operation.fields.subject
                if ($record.fields.subject -and $subject -is [string] -and $subject.Trim()) { Test-Subject $subject $line $operations }
            }
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
