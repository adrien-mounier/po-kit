# The register tool: the only program allowed to write the register. It runs without any model.
#
#   powershell -NoProfile -File tools\register.ps1 <command> [arguments] [-Today yyyy-mm-dd] [-Now timestamp]
#
# It works on the workspace it sits in. -Today sets the date this run treats as today, and -Now
# the moment it treats as now (as 2026-03-02T08:30:00+01:00), which also gives the date.
#
# Each command is one file under tools\commands: adding a command means adding a file. A command
# runs with everything defined here in scope ($Workspace, $Settings, $Connections, $Today, $Now,
# the functions) and its own arguments in $Arguments. It ends a failed run with Stop-Run.
#
# Keep this file and the commands in plain ASCII: Windows PowerShell 5.1 misreads other
# characters in a script saved without a byte order mark.
param(
    [Parameter(Position = 0)][string]$Command,
    [string]$Today,
    [string]$Now,
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

function Read-PoFile([string]$Name) {
    # settings.json or connections.json: a file of the workspace that the PO edits by hand, read
    # before the command runs. When it cannot be read, the run ends with the reason.
    try { Read-JsonFile (Join-Path $Workspace $Name) }
    catch { Stop-Run "$Name cannot be read: it must hold JSON, saved as UTF-8. Nothing was done. Correct it, or save it again as UTF-8, then run the command again." }
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
        $letters = $_.Substring(0, 2)
        $happened = if ($letters -match '[?A]') { 'added' } elseif ($letters -match 'D') { 'deleted' } else { 'modified' }
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
    # Nobody may be there to answer: git and its credential manager must not ask for a password,
    # in the terminal or in a window. A push that cannot authenticate then fails, which is the
    # warning below.
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GCM_INTERACTIVE = 'never'
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

# A timestamp is a date and time that carries its UTC offset. Every timestamp the register tool
# reads goes through Read-Timestamp, and every one it writes through Format-Timestamp. The present
# moment is $Now, already written this way. A field of type "timestamp" in a definition is checked
# and recorded this way.

function Read-Timestamp([string]$Text) {
    # The moment a text states, or nothing when the text is not a timestamp. The offset is
    # written +01:00 or Z, and fractions of a second are accepted.
    $moment = [DateTimeOffset]::MinValue
    if ($Text -cmatch '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?(Z|[+-]\d\d:\d\d)$' -and
        [DateTimeOffset]::TryParse($Text, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$moment)) { $moment }
}

function Format-Timestamp([DateTimeOffset]$Moment) {
    # To the second, in the offset the moment was given in: 2026-03-02T08:30:00+01:00
    $Moment.ToString("yyyy-MM-dd'T'HH:mm:sszzz", [Globalization.CultureInfo]::InvariantCulture)
}

# --- Record definitions -------------------------------------------------------------------------
# tools\definitions holds one data file per record type, plus common.json for the fields every
# record carries. A field is defined by:
#   type          text, date, timestamp, boolean, integer, list or object; any for a value of any kind;
#                 days for an effort: a number of days above zero, as 1.5; number for any number
#   required      true when a record must hold it: a proposal gives it, unless the register tool sets it
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
    list = 'a list'; object = 'a group of fields'; days = 'a number of days above zero (as 1.5)'; number = 'a number (as 40 or 4.5)'
    timestamp = 'a date and time with its UTC offset (as 2026-03-02T08:30:00+01:00)'
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

function Test-Value($Definition, $Value, [string]$Name, [switch]$Partial, [switch]$Stored) {
    # What is wrong with a proposed value, against its definition: one reason per problem, and
    # nothing when the value is valid. -Partial accepts a group that leaves required fields out:
    # the fields an update names. -Stored takes the value as a record of the register: it holds
    # the fields set by the register tool, which a proposal neither gives nor owes.
    if ($null -eq $Value -or ($Value -is [string] -and -not $Value.Trim())) {
        if ($Definition.required) { "missing required field '$Name'"; return }
        # A blank text is no value: it is left out, unless only listed values are allowed, which
        # it is not one of.
        if ($null -eq $Value -or -not ($Definition.allowed -or $Definition.allowed_from)) { return }
    }
    $isGroup = $Value -is [array] -or $Value -is [System.Management.Automation.PSCustomObject]
    $fits = switch ($Definition.type) {
        'text' { $Value -is [string] }
        'date' { $Value -is [string] -and (Test-IsoDate $Value) }
        'timestamp' { $Value -is [string] -and (Read-Timestamp $Value) }
        'boolean' { $Value -is [bool] }
        'integer' { $Value -is [int] -or $Value -is [long] }
        # A number in JSON reads as a whole number, a decimal or, written with an exponent, a double.
        'days' { ($Value -is [int] -or $Value -is [long] -or $Value -is [decimal] -or $Value -is [double]) -and $Value -gt 0 }
        'number' { $Value -is [int] -or $Value -is [long] -or $Value -is [decimal] -or $Value -is [double] }
        'list' { $Value -is [array] }
        'object' { $Value -is [System.Management.Automation.PSCustomObject] }
        'any' { $true }
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
            elseif ($field.Value.set_by -eq 'tool' -and -not $Stored) { "field '$path' is set by the register tool" }
            else { Test-Value $field.Value $given.Value $path -Stored:$Stored }
        }
        foreach ($field in $Definition.fields.PSObject.Properties) {
            if ($field.Value.required -and ($Stored -or $field.Value.set_by -ne 'tool') -and -not $Partial -and -not $Value.PSObject.Properties[$field.Name]) {
                "missing required field '$("$Name.$($field.Name)".TrimStart('.'))'"
            }
        }
        return
    }
    if ($Definition.type -eq 'list') {
        foreach ($item in $Value) {
            if ($null -eq $item) { "field '$Name' holds an empty item" } else { Test-Value $Definition.items $item $Name -Stored:$Stored }
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
    if ($Definition.type -eq 'timestamp') { return Format-Timestamp (Read-Timestamp $Value) }
    $Value
}

function Find-Record([string]$Id) {
    # The record of the register that carries an identifier: its type, its file (path) and its
    # content (record). Nothing when the register holds no such record. The identifier alone says
    # where to look: its shape names the type, and its year the folder.
    foreach ($file in Get-ChildItem (Join-Path $Tools 'definitions\*.json') -Exclude common.json) {
        $filed = Read-JsonFile $file.FullName
        $shape = if ($filed.identifier_prefix) { "^$($filed.identifier_prefix)-([0-9]{4})-[0-9]+$" } else { '^[a-z0-9]+(-[a-z0-9]+)*$' }
        if ($Id -cmatch $shape) {
            $folder = Join-Path $Workspace $filed.folder
            if ($filed.folder_per_year) { $folder = Join-Path $folder $Matches[1] }
            $path = Join-Path $folder "$Id.json"
            if (Test-Path -LiteralPath $path) { return @{ type = $file.BaseName; path = $path; record = Read-JsonFile $path } }
        }
    }
}

function Format-Value($Value) {
    # A field value on one line: lists joined by commas, nested fields between parentheses.
    if ($Value -is [array]) { return (@($Value | ForEach-Object { Format-Value $_ }) -join ', ') }
    # A value completed by the register tool holds its nested fields as a dictionary.
    if ($Value -is [System.Collections.IDictionary]) { $Value = [pscustomobject]$Value }
    if ($Value -is [System.Management.Automation.PSCustomObject]) { return '(' + (Format-Fields $Value) + ')' }
    if ($Value -is [bool]) { return "$Value".ToLower() }
    "$Value" -replace '\s*\r?\n\s*', ' '
}

function Format-Fields($Fields, [string[]]$Except) {
    # The fields that hold something: a record as it is recorded carries every field, most empty.
    $given = $Fields.PSObject.Properties | Where-Object { $Except -notcontains $_.Name -and "$(Format-Value $_.Value)" }
    @($given | ForEach-Object { "$($_.Name): $(Format-Value $_.Value)" }) -join '; '
}

function Format-Change($Change) {
    # A field that changes, with its previous and its new value: a change that an update proposes,
    # or an entry of the history of a record.
    $previous, $new = foreach ($value in $Change.previous, $Change.new) { $text = Format-Value $value; if ($text -and $text -ne '()') { $text } else { '(none)' } }
    "$($Change.field): $previous -> $new"
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
    else { (Find-Record $Subject).type -eq 'subject' }
    if (-not $exists) { "subject '$Subject' exists neither in the register nor earlier in this proposal (the subject that line N creates is named 'line N')" }
}

function Get-WaitingLines($Operations) {
    # The lines of a valid proposal that wait for the PO when the plain facts are applied without
    # asking ("apply plain"), in the order of the proposal:
    # - an interpreted line;
    # - a record attached to the subject that a waiting line creates, or an update of the record
    #   that a waiting line creates;
    # - a line that updates or supersedes a record of the register which a waiting line also updates
    #   or supersedes: what the lines of a proposal leave of a record is judged together
    #   (Test-ProposalResult), so they are applied together.
    $changed = { param($Operation) if ($Operation.op -ceq 'update') { $Operation.id } else { $Operation.fields.supersedes } }
    $waiting = @()
    do {
        $found = $waiting.Count
        $records = @($waiting | ForEach-Object { & $changed $Operations[$_ - 1] } | Where-Object { $_ })
        for ($line = 1; $line -le $Operations.Count; $line++) {
            $operation = $Operations[$line - 1]
            if ($waiting -notcontains $line -and ($operation.interpreted -or $waiting -contains (Get-LineNamed $operation.fields.subject) -or
                    ($operation.op -ceq 'update' -and $waiting -contains (Get-LineNamed $operation.id)) -or
                    $records -ccontains (& $changed $operation))) { $waiting += $line }
        }
    } while ($waiting.Count -ne $found)
    $waiting | Sort-Object
}

# An update changes fields of one record of the register, named by its identifier:
#   { "op": "update", "id": "C-2026-001", "interpreted": true,
#     "source": { "where": "...", "read_on": "yyyy-mm-dd" }, "fields": { "due_date": "2026-04-10" } }
# or of the record that line N, an earlier line of the same proposal, creates, named "line N": the
# estimate the agent proposes for a commitment it records, which waits for the PO when the
# commitment itself is a plain fact. apply updates the identifier that record received.
# "fields" gives each field to change with its whole new value, and "source" the source of the
# change, written as the source of a record. For each field whose value changes, apply adds an
# entry to the history of the record, and it moves the date updated:
#   { "date": "2026-03-10", "field": "due_date", "previous": "2026-03-20", "new": "2026-04-10", "source": { ... } }
# Closing a subject is an update of its status. No operation deletes a record.
#
# A created record supersedes a record of the register, of any type but subject, by naming its
# identifier in the field "supersedes". apply then marks the old record as an update would, with
# the source of the new record: the status "superseded", and the identifier of the new record in
# "superseded_by". Only the register tool does this: a proposal neither gives that status nor
# updates a superseded record.

function Get-Changes($Found, $Fields) {
    # The fields of a record found by Find-Record that would change, each with its previous and its
    # new value. A field given with the value the record already holds is not a change.
    $definition = (Get-Definition $Found.type).record.fields
    foreach ($given in $Fields.PSObject.Properties) {
        $field = $definition.($given.Name)
        $previous = $Found.record.($given.Name)
        $new = Complete-Value $field $given.Value
        # Compared as they would be recorded, so that a list or a group of fields compares by content.
        if ((ConvertTo-Json -InputObject (Complete-Value $field $previous) -Depth 20 -Compress) -cne (ConvertTo-Json -InputObject $new -Depth 20 -Compress)) {
            @{ field = $given.Name; previous = $previous; new = $new }
        }
    }
}

function Test-StatusProposed([string]$Type, $Fields) {
    # Only the register tool marks a record as superseded. A subject is never superseded: its
    # definition already refuses that status.
    if ($Type -ne 'subject' -and $Fields.status -ceq 'superseded') {
        "the status 'superseded' is set by the register tool, on the record that a created record names in 'supersedes'"
    }
}

function Test-Superseding($Operation, [int]$Line, [hashtable]$Superseded) {
    # What is wrong with what a created record says about superseding: nothing when it names no
    # record to supersede, or a record of the register that can be superseded. $Superseded then
    # remembers that this line supersedes it.
    Test-StatusProposed $Operation.type $Operation.fields
    $old = $Operation.fields.supersedes
    if ($old -isnot [string] -or -not $old.Trim()) { return }
    if ($Operation.type -eq 'subject') { 'a subject supersedes no record'; return }
    $found = Find-Record $old
    if (-not $found) { "record '$old' to supersede does not exist in the register" }
    elseif ($found.type -eq 'subject') { "'$old' is a subject: a subject is closed, not superseded" }
    elseif ($found.record.status -ceq 'superseded') { "record '$old' is already superseded by '$($found.record.superseded_by)'" }
    elseif ($Superseded[$old]) { "record '$old' is already superseded by line $($Superseded[$old])" }
    else { $Superseded[$old] = $Line }
}

function Find-ProposedRecord($Id, [int]$Line, $Operations) {
    # The record that the update of a line names, as Find-Record finds it: a record of the register,
    # or the record that an earlier line of the proposal creates, as it would be recorded.
    $named = Get-LineNamed $Id
    if (-not $named) { if ($Id -is [string]) { return Find-Record $Id } else { return } }
    $created = if ($named -lt $Line) { $Operations[$named - 1] }
    if ($created.op -ceq 'create' -and "$($created.type)" -cmatch '^[a-z]+$' -and $created.type -ne 'common' -and
        $created.fields -is [System.Management.Automation.PSCustomObject] -and (Test-Path -LiteralPath (Join-Path $Tools "definitions\$($created.type).json"))) {
        @{ type = $created.type; record = [pscustomobject](Complete-Value (Get-Definition $created.type).record $created.fields) }
    }
}

function Test-Update($Operation, [hashtable]$Superseded, [int]$Line, $Operations) {
    # What is wrong with an update: nothing when it can be applied. $Superseded holds the records
    # that earlier lines of the proposal supersede.
    $found = Find-ProposedRecord $Operation.id $Line $Operations
    if (-not $found) { "record '$($Operation.id)' does not exist in the register nor earlier in this proposal (an update names its record in 'id': its identifier, or 'line N' for the record that line N creates)"; return }
    $by = if ($found.record.status -ceq 'superseded') { "'$($found.record.superseded_by)'" } elseif ($Superseded[$Operation.id]) { "line $($Superseded[$Operation.id])" }
    if ($by) { "record '$($Operation.id)' is superseded by ${by}: it is no longer updated"; return }
    $record = (Get-Definition $found.type).record
    $fields = $Operation.fields
    $problems = @(
        Test-Value $record.fields.source $Operation.source 'source'
        if ($fields -isnot [System.Management.Automation.PSCustomObject]) { 'the operation gives no fields' }
        else {
            Test-Value $record $fields '' -Partial
            if ($record.fields.subject -and $fields.subject -is [string] -and $fields.subject.Trim() -and (Find-Record $fields.subject).type -ne 'subject') {
                "subject '$($fields.subject)' does not exist in the register"
            }
            Test-StatusProposed $found.type $fields
            if ($fields.PSObject.Properties['supersedes']) { "field 'supersedes' is given when a record is created: an update cannot change it" }
            # A new value of a benefit is dated: the date it held before is that of another value.
            if ($found.type -eq 'benefit' -and $fields.PSObject.Properties['current_value'] -and -not $fields.PSObject.Properties['measured_on']) {
                "a new 'current_value' is given with its 'measured_on', the date it was measured"
            }
        }
    )
    $problems
    if (-not $problems -and -not @(Get-Changes $found $fields)) { 'the update changes nothing: the record already holds every value given' }
}

function Test-ProposalResult($Operations, [int[]]$Lines) {
    # What the result of these lines of a proposal, each one valid, would break of the error rules
    # of the check (Test-RecordRules): one reason per rule broken, on the last line that touches the
    # record. A record that several lines update is judged as they leave it together.
    $updated = [ordered]@{}
    foreach ($line in $Lines) {
        $operation = $Operations[$line - 1]
        if ($operation.op -ceq 'create') {
            $record = Complete-Value (Get-Definition $operation.type).record $operation.fields
            Test-RecordRules $operation.type $record | ForEach-Object { "Line ${line}: $($_.reason)" }
            continue
        }
        if (-not $updated[$operation.id]) { $updated[$operation.id] = Find-ProposedRecord $operation.id $line $Operations }
        $found = $updated[$operation.id]
        foreach ($change in @(Get-Changes $found $operation.fields)) { $found.record.($change.field) = $change.new }
        $found.line = $line
    }
    foreach ($found in $updated.Values) { Test-RecordRules $found.type $found.record | ForEach-Object { "Line $($found.line): $($_.reason)" } }
}

function Test-Owner($Fields) {
    # An owner is one person the source names: two people given as alternatives are no owner.
    $owner = $Fields.owner
    if ($owner -is [string] -and $owner -match '\s(or|ou)\s') {
        "field 'owner' is '$owner': an owner is one person the source names; when it names none, leave the owner out and keep an open question"
    }
}

function Get-PendingProposal {
    # The operations of the pending proposal, validated in full. Any problem refuses the proposal
    # whole: the run ends with the reasons and a failure code, and nothing is written.
    if (-not (Test-Path -LiteralPath $ProposalPath)) { Stop-Run 'No proposal is pending.' }
    $reasons = @()
    $operations = @()
    try { $operations = @((Read-JsonFile $ProposalPath).operations | Where-Object { $null -ne $_ }) }
    catch { $reasons += 'The proposal is not valid JSON written as UTF-8.' }
    if (-not $reasons) { $reasons += @(Test-PendingCollect | ForEach-Object { "$_." }) }
    if (-not $reasons -and -not $operations -and -not (Get-PendingCollect)) { $reasons += 'The proposal holds no operation and settles no collect.' }

    $line = 0
    $superseded = @{}
    foreach ($operation in $operations) {
        $line++
        $problems = @(
            if ($operation.interpreted -isnot [bool]) { 'the operation must state "interpreted": true when it is interpreted, false when it is a plain fact' }
            if ($operation.op -ceq 'update') { Test-Update $operation $superseded $line $operations }
            elseif ($operation.op -cne 'create') { "unknown operation '$($operation.op)'; allowed: create, update" }
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
                Test-Superseding $operation $line $superseded
            }
            if ($operation.fields -is [System.Management.Automation.PSCustomObject]) { Test-Owner $operation.fields }
        )
        foreach ($problem in $problems) { $reasons += "Line ${line}: $problem." }
    }
    # The error rules of the check guard the door: the result of a proposal breaks none of them.
    if (-not $reasons -and $operations) { $reasons += @(Test-ProposalResult $operations (1..$operations.Count) | ForEach-Object { "$_." }) }
    if ($reasons) { Stop-Run (@('Proposal refused. Nothing was written.') + @($reasons | ForEach-Object { "- $_" })) }
    $operations
}

# --- Collect ------------------------------------------------------------------------------------
# A proposal that comes from a collect says, beside its operations, what the collect read:
#   "collected_at": "2026-03-02T08:30:00+01:00",
#   "sources_read": [ { "source": "mail", "cutoff": "2026-03-02T08:12:00+01:00", "items": 14,
#                       "cap_reached": true } ],
#   "sources_not_covered": [ "tracker" ],
#   "notes_processed": [ "steering committee.md" ],
#   "unclassified": [ { "source": "mail from the tech lead, 2026-02-27", "text": "..." } ]
# collected_at is the time of the collect, required as soon as one of the others is given. A
# cutoff is how far a source was read, and cap_reached, which may be left out, is true when the
# collect stopped there at the per-source cap of the settings, with more to read. A source is
# named as in connections.json. A note is named by its file name in the inbox. A proposal may hold
# a collect and no operation.
#
# apply settles the collect, whichever lines are kept. It does so once: the lines that "apply plain"
# leaves pending are a proposal that no longer holds a collect. To settle it:
# - the notes processed move to inbox\done\yyyy-mm, the month of the run. No note is ever deleted
#   or replaced.
# - state\last-collect.json, the collect state, says how far each source was read:
#     { "collected_at": "2026-03-02T08:30:00+01:00",
#       "sources": { "mail": { "cutoff": "2026-03-02T08:12:00+01:00", "items": 14,
#                              "collected_at": "2026-03-02T08:30:00+01:00", "cap_reached": true } },
#       "not_covered": [ "tracker" ] }
#   collected_at and not_covered are those of the last collect. A source keeps its entry, with the
#   time of the collect that read it, until a later collect reads it again.
# - state\unclassified.md gains one line per unclassified item:
#     - 2026-03-02 | mail from the tech lead, 2026-02-27 | ...
#   the date it was collected, its source, its text. The PO edits this list by hand.

$CollectDefinition = @'
{ "type": "object", "fields": {
    "collected_at": { "type": "timestamp" },
    "sources_read": { "type": "list", "items": { "type": "object", "fields": {
        "source": { "type": "text", "required": true },
        "cutoff": { "type": "timestamp", "required": true },
        "items": { "type": "integer", "required": true },
        "cap_reached": { "type": "boolean", "default": false } } } },
    "sources_not_covered": { "type": "list", "items": { "type": "text" } },
    "notes_processed": { "type": "list", "items": { "type": "text" } },
    "unclassified": { "type": "list", "items": { "type": "object", "fields": {
        "source": { "type": "text", "required": true },
        "text": { "type": "text", "required": true } } } }
} }
'@ | ConvertFrom-Json

function Format-CapReached($Read) {
    # What preview and apply add to a source read when the collect stopped at the cap.
    if ($Read.cap_reached) { ', cap reached: the rest waits for the next collect' }
}

function Get-PendingCollect {
    # What the pending proposal says of its collect, every part present. Nothing when the
    # proposal comes from no collect.
    $proposal = Read-JsonFile $ProposalPath
    if ($proposal -is [System.Management.Automation.PSCustomObject] -and "$($proposal.collected_at)".Trim()) {
        Complete-Value $CollectDefinition $proposal
    }
}

function Test-PendingCollect {
    # What is wrong with what the pending proposal says of its collect: one reason per problem.
    $proposal = Read-JsonFile $ProposalPath
    if ($proposal -isnot [System.Management.Automation.PSCustomObject]) { return }
    $said = [ordered]@{}
    foreach ($part in $proposal.PSObject.Properties) { if ($part.Name -ne 'operations') { $said[$part.Name] = $part.Value } }
    $collect = [pscustomobject]$said
    Test-Value $CollectDefinition $collect ''
    $parts = @($said.Keys | Where-Object { $_ -ne 'collected_at' -and $CollectDefinition.fields.PSObject.Properties[$_] })
    if ($parts -and -not "$($collect.collected_at)".Trim()) { "missing required field 'collected_at'" }
    # The collect state is kept per source: a source under another name would lose its cutoff.
    $declared = @($Connections.PSObject.Properties | ForEach-Object { $_.Name })
    $named = @($collect.sources_read | ForEach-Object { $_.source }) + @($collect.sources_not_covered)
    foreach ($source in $named | Where-Object { $_ -is [string] -and $declared -cnotcontains $_ }) {
        "source '$source' is not declared in connections.json, which declares: $($declared -join ', ')"
    }
    if ($collect.notes_processed -is [array]) {
        # A note is a file of the inbox itself: a name that is a path would reach outside it.
        foreach ($note in $collect.notes_processed | Where-Object { $_ -is [string] }) {
            if ($note -match '[\\/:]' -or -not (Test-Path -LiteralPath (Join-Path $Workspace "inbox\$note") -PathType Leaf)) {
                "the note '$note' is not in the inbox"
            }
        }
    }
}

function Save-Collect {
    # Settles the collect of the pending proposal, and says what it did, one line per thing.
    # Nothing when the proposal comes from no collect.
    # Where each note filed by this run was in the inbox, and where it is now: apply puts the notes
    # back when the run fails.
    $script:FiledNotes = @{}
    $collect = Get-PendingCollect
    if (-not $collect) { return }
    $statePath = Join-Path $Workspace 'state\last-collect.json'
    $state = [ordered]@{ collected_at = $collect.collected_at; sources = [ordered]@{}; not_covered = $collect.sources_not_covered }
    if (Test-Path -LiteralPath $statePath) {
        foreach ($source in (Read-JsonFile $statePath).sources.PSObject.Properties) { $state.sources[$source.Name] = $source.Value }
    }
    "settle the collect of $($collect.collected_at)"

    $inbox = Join-Path $Workspace 'inbox'
    $done = Join-Path $inbox "done\$($Today.Substring(0, 7))"
    New-Item -ItemType Directory -Path $done -Force | Out-Null
    foreach ($note in $collect.notes_processed | Sort-Object -Unique) {
        # A note already filed this month under the same name stays: the new one is filed beside it.
        $name = $note
        for ($n = 2; Test-Path -LiteralPath (Join-Path $done $name); $n++) {
            $name = [IO.Path]::GetFileNameWithoutExtension($note) + "-$n" + [IO.Path]::GetExtension($note)
        }
        try { [IO.File]::Move((Join-Path $inbox $note), (Join-Path $done $name)) }
        catch {
            # All the notes or none: the notes are filed before anything else is written, and apply
            # puts those already filed back in the inbox, so that it can simply be run again.
            Stop-Run "The note '$note' could not be filed, so nothing was written: $($_.Exception.GetBaseException().Message) Close it if it is open in another program, then apply again."
        }
        $script:FiledNotes[(Join-Path $inbox $note)] = Join-Path $done $name
        "file note $note$(if ($name -ne $note) { " as $name" })"
    }

    foreach ($read in $collect.sources_read) {
        $state.sources[$read.source] = [ordered]@{ cutoff = $read.cutoff; items = $read.items; collected_at = $collect.collected_at; cap_reached = $read.cap_reached }
        "read $($read.source) up to $($read.cutoff): $($read.items) item(s)$(Format-CapReached $read)"
    }
    Write-JsonFile $statePath $state
    if ($state.not_covered) { "not covered: $($state.not_covered -join ', ')" }

    if ($collect.unclassified) {
        # The list is added to and never rewritten, so that what the PO wrote in it stays as it is.
        $listPath = Join-Path $Workspace 'state\unclassified.md'
        $items = @($collect.unclassified | ForEach-Object {
                "- $($collect.collected_at.Substring(0, 10)) | $(($_.source -replace '\s+', ' ').Trim()) | $(($_.text -replace '\s+', ' ').Trim())"
            })
        $text = ($items -join [Environment]::NewLine) + [Environment]::NewLine
        $list = if (Test-Path -LiteralPath $listPath) { [IO.File]::ReadAllText($listPath) }
        if ($list -and -not $list.EndsWith("`n")) { $text = [Environment]::NewLine + $text }
        [IO.File]::AppendAllText($listPath, $text, $Utf8)
        "add $($items.Count) unclassified item(s)"
    }
}

function Get-Coverage {
    # What the collect state says of each source declared in connections.json, in the order
    # declared: its name (source), its mode, its entry of the collect state (read: nothing when it
    # was never read) and whether the last collect covered it (covered).
    #
    # A source is not covered when the last collect did not read it, whether or not the collect
    # said so. A source the last collect read carries the time of that collect.
    #
    # The calendar is no source of the collect: the morning routine reads it into the calendar
    # snapshot (Read-CalendarSnapshot).
    $collectPath = Join-Path $Workspace 'state\last-collect.json'
    $collect = if (Test-Path -LiteralPath $collectPath) { Read-JsonFile $collectPath }
    foreach ($source in $Connections.PSObject.Properties | Where-Object { $_.Name -cne 'calendar' }) {
        $read = $collect.sources.($source.Name)
        @{
            source = $source.Name; mode = $source.Value.mode; read = $read
            covered = $null -ne $read -and $collect.not_covered -cnotcontains $source.Name -and $read.collected_at -ceq $collect.collected_at
        }
    }
}

# --- Views --------------------------------------------------------------------------------------
# A view is a document generated from the register, under views\. It is never edited, and it opens
# with a stamp: the lines Get-Stamp gives.
#
# Its labels exist in several languages. tools\labels holds one data file per language, named
# after it (en.json): one group of labels for the stamp, and one per view. Adding a language means
# adding a file. What a record says is never translated.

function Get-Labels([string]$Language) {
    # The labels of a language. A language without labels ends the run with a failure code.
    $file = Join-Path $Tools "labels\$Language.json"
    if ($Language -cnotmatch '^[a-z]+$' -or -not (Test-Path -LiteralPath $file)) {
        $known = (Get-ChildItem (Join-Path $Tools 'labels\*.json') | ForEach-Object { $_.BaseName }) -join ', '
        Stop-Run "Unsupported language '$Language'. Nothing was written. Languages: $known. view takes the language as an argument. Without one it is, in settings.json, languages.default for view and apply. It is always languages.sponsor for export."
    }
    Read-JsonFile $file
}

function Get-Stamp($Labels, [string]$Bank) {
    # The stamp that opens every view, as lines of Markdown. It is produced here and nowhere else:
    #   > Generated: 2026-03-02T09:15:00+01:00.
    #   > Register state: 4b825dc642cb.
    #   > Last collect: 2026-03-02T08:30:00+01:00.
    #   > Sources not covered by the last collect: mail, tracker.
    # or, in place of the last two lines, that no collect has run yet. A view kept to one client
    # bank adds a line that names it.
    #
    # The register state is the start of the name git gives to the content of register\, which
    # git rev-parse <commit>:register prints for any commit of the workspace history. The same
    # register gives the same name, whatever the commit. It is read from what git has staged, so
    # the caller sees to it that the register on disk is the one staged: a command that only reads
    # the register calls Assert-RegisterCommitted first, and apply stages what it wrote.
    $stamp = $Labels.stamp
    $said = @(
        $stamp.generated -f $Now
        $stamp.register_state -f "$(Invoke-Git write-tree --prefix=register/)".Substring(0, 12)
        $collectPath = Join-Path $Workspace 'state\last-collect.json'
        if (Test-Path -LiteralPath $collectPath) {
            $notCovered = @(Get-Coverage | Where-Object { -not $_.covered } | ForEach-Object { $_.source })
            $stamp.last_collect -f (Read-JsonFile $collectPath).collected_at
            $stamp.not_covered -f $(if ($notCovered) { $notCovered -join ', ' } else { $stamp.none })
        }
        else { $stamp.no_collect }
        if ($Bank) { $stamp.bank -f $Bank }
    )
    $said | ForEach-Object { "> $_" }
}

function Write-Table([string[]]$Header, [object[]]$Rows) {
    # A Markdown table with aligned columns: readable as plain text, and rendered by a chat.
    # The last column holds the long text and is left unpadded.
    $lines = @(, $Header) + $Rows
    $widths = @(0..($Header.Count - 1) | ForEach-Object { $column = $_; ($lines | ForEach-Object { $_[$column].Length } | Measure-Object -Maximum).Maximum })
    $widths[-1] = $Header[-1].Length
    $number = 0
    foreach ($line in $lines) {
        '| ' + ((0..($Header.Count - 1) | ForEach-Object { $line[$_].PadRight($widths[$_]) }) -join ' | ') + ' |'
        if ($number++ -eq 0) { '|' + (($widths | ForEach-Object { '-' * ($_ + 2) }) -join '|') + '|' }
    }
}

function Format-Clearance($Subject, [string]$Clearance, [string]$By, [string]$On) {
    # The clearance of a subject in words, on one line. A cleared subject also says who cleared it
    # and when, as far as its record gives them: $By and $On are the words for it, with {0} where
    # the name and the date go.
    if ($Subject.clearance -ceq 'cleared') {
        if ($Subject.cleared_by) { $Clearance += ' ' + ($By -f (Format-Value $Subject.cleared_by)) }
        if ($Subject.cleared_on) { $Clearance += ' ' + ($On -f $Subject.cleared_on) }
    }
    $Clearance
}

function Get-ActiveSubjects([string]$Bank) {
    # The active subjects, in the order of their identifiers. Given a client bank, only those that
    # name it or name no bank.
    @(Get-RecordFiles | Where-Object { $_.type -eq 'subject' } | ForEach-Object { Read-JsonFile $_.path } |
            Where-Object { $_.status -ceq 'active' -and (-not $Bank -or -not $_.banks -or $_.banks -ccontains $Bank) })
}

function Get-RankedSubjects([string]$Bank) {
    # The active subjects as the ranked portfolio orders them: those with both a value and a
    # feasibility score by value times feasibility, highest first, ties by value, then title
    # (scored); the others by title (others).
    $subjects = Get-ActiveSubjects $Bank
    $isScored = { $null -ne $_.value_score -and $null -ne $_.feasibility_score }
    @{
        scored = @($subjects | Where-Object $isScored | Sort-Object @{ Expression = { $_.value_score * $_.feasibility_score }; Descending = $true },
            @{ Expression = { $_.value_score }; Descending = $true }, @{ Expression = { "$($_.title)" } })
        others = @($subjects | Where-Object { -not (& $isScored) } | Sort-Object { "$($_.title)" })
    }
}

function Get-PortfolioHorizons($Labels, [string]$Bank) {
    # The portfolio view below its title and its stamp, as lines: every active subject under its
    # horizon. export prints these lines too, for the weekly synthesis that opens with them. Given a
    # client bank, only the subjects that name it or name no bank.
    $portfolio = $Labels.portfolio
    $subjects = Get-ActiveSubjects $Bank
    # The benefits in play of each subject, open or achieved, follow its title when it has any.
    $benefits = @{}
    foreach ($benefit in Get-RecordFiles | Where-Object { $_.type -eq 'benefit' } | ForEach-Object { Read-JsonFile $_.path }) {
        if ('open', 'achieved' -ccontains $benefit.status) { $benefits[$benefit.subject]++ }
    }
    $lines = @()
    foreach ($horizon in 'now', 'next', 'later') {
        $lines += '', "## $($portfolio.horizons.$horizon)", ''
        $rows = @(foreach ($subject in $subjects | Where-Object { $_.horizon -ceq $horizon }) {
                $clearance = Format-Clearance $subject $portfolio.clearances.($subject.clearance) $portfolio.cleared_by $portfolio.cleared_on
                # A date that is not confirmed is not shown, so that the view never promises it.
                # The banks of a subject follow its title; a subject that names none concerns everyone.
                $cells = "$($subject.title) [$($subject.id)]$(if ($subject.banks) { " ($(Format-Value $subject.banks))" })$(if ($benefits[$subject.id]) { ', ' + ($portfolio.benefits -f $benefits[$subject.id]) })", $portfolio.kinds.($subject.kind), $clearance,
                    $(if ($subject.next_date_confirmed) { "$($subject.next_date)" } else { '' }), "$($subject.next_step)"
                , @($cells | ForEach-Object { ($_ -replace '\s*\r?\n\s*', ' ').Replace('|', '\|') })
            })
        $lines += if ($rows) { Write-Table $portfolio.subject, $portfolio.kind, $portfolio.clearance, $portfolio.next_date, $portfolio.next_step $rows }
        else { $portfolio.no_subject }
    }
    $lines
}

function Write-PortfolioView($Labels, [string]$Bank) {
    # Writes the portfolio view, views\portfolio.md: its title, its stamp, then its horizons. Given
    # a client bank, the view keeps to its subjects, and its stamp says so.
    $lines = @("# $($Labels.portfolio.title)", '') + @(Get-Stamp $Labels $Bank) + @(Get-PortfolioHorizons $Labels $Bank)
    Write-TextFile (Join-Path $Workspace 'views\portfolio.md') (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Get-Cited([string]$Text) {
    # The records a text cites, once each. A text cites a record by its identifier in square
    # brackets, as the portfolio view does: Title [identifier]. Several identifiers share brackets
    # when commas separate them: [C-2026-001, D-2026-002]. Between square brackets, two things are
    # read as a record cited: a numbered identifier by its shape (C-2026-004), wherever it stands
    # and whether the register holds it or not, and, alone between commas, the identifier of a
    # subject that the register holds. Whatever else the brackets hold is text, as a ticket
    # reference in a title, [REQ#4521].
    $prefixes = @(Get-ChildItem (Join-Path $Tools 'definitions\*.json') -Exclude common.json | ForEach-Object { (Read-JsonFile $_.FullName).identifier_prefix } | Where-Object { $_ })
    $numbered = "(?<![A-Za-z0-9-])(?:$($prefixes -join '|'))-[0-9]{4}-[0-9]+(?![A-Za-z0-9-])"
    @([regex]::Matches($Text, '\[([^\[\]]*)\]') | ForEach-Object {
            $held = $_.Groups[1].Value
            [regex]::Matches($held, $numbered) | ForEach-Object { $_.Value }
            $held -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and (Find-Record $_).type -eq 'subject' }
        } | Select-Object -Unique)
}

function Test-Cited([string[]]$Ids) {
    # What is wrong with the records cited: one line per record that is not in the register or is
    # superseded. A record that is done, dropped or closed is still a record to cite.
    foreach ($id in $Ids) {
        $found = Find-Record $id
        if (-not $found) { "$id is not in the register." }
        elseif ($found.record.status -ceq 'superseded') { "$id is superseded by $($found.record.superseded_by)." }
    }
}

# --- Calendar -----------------------------------------------------------------------------------
# The calendar is read, never written: nothing here creates, changes or cancels an event. It is no
# source of the collect. The morning routine reads the working day before today, today and the
# next ten working days into the calendar
# snapshot, state\calendar.json, in the format the workspace rules (AGENTS.md) give:
#   { "read_at": "2026-03-02T07:05:00+01:00", "from": "2026-03-02", "to": "2026-03-13",
#     "meetings": [ { "start": "2026-03-02T14:00:00+01:00", "end": "2026-03-02T14:45:00+01:00",
#                     "title": "...", "attendees": ["..."], "status": "accepted" } ],
#     "absences": [ { "date": "2026-03-05", "title": "..." } ] }
# A meeting is accepted or tentative. An all-day absence is one entry per day. A time is read as
# written, in the offset it carries.
#
# The agent leaves the parts of the morning page that need judgement in state\morning.json, in the
# format the workspace rules give: its notes on the meetings, the actions to do first, the messages
# awaiting the PO's reply, the signs of progress of what others owe the PO and the backlog alerts:
#   { "meetings": [ { "start": "2026-03-02T14:00:00+01:00", "title": "...", "key": "...",
#                     "lacks": { "D-2026-004": "..." } } ], "first": [...], "messages": [...],
#     "progress": { "C-2026-006": "..." }, "backlog": { "contradictions": [...], ... } }
# key is one sentence on what matters in the meeting, and lacks what each decision awaited still
# lacks. A note goes with the meeting of the same start and title.

function Read-CalendarSnapshot {
    # The calendar snapshot, or nothing when the calendar is off or was never read.
    $path = Join-Path $Workspace 'state\calendar.json'
    if ($Connections.calendar -and $Connections.calendar.mode -cne 'off' -and (Test-Path -LiteralPath $path)) { Read-JsonFile $path }
}

function Get-DayMeetings($Snapshot, [string]$Date) {
    # The meetings of a day in the snapshot, by their start.
    @($Snapshot.meetings | Where-Object { (Read-Timestamp $_.start) -and (Read-Timestamp $_.end) -and $_.start.Substring(0, 10) -eq $Date } | Sort-Object start, title)
}

function Test-SteeringTitle([string]$Title) {
    # Whether a meeting's title shows a steering committee: it holds one of the words of
    # steering_words in settings.json, whatever the case, or "steering committee" without them.
    $listed = @($Settings.steering_words | Where-Object { "$_".Trim() })
    if (-not $listed) { $listed = @('steering committee') }
    @($listed | Where-Object { $Title.IndexOf("$_".Trim(), [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0
}

function Get-SteeringCommittees {
    # The steering committees whose pack to offer: in the calendar snapshot read today, the
    # meetings from today to five working days on whose title shows a steering committee, one per
    # day, the earliest first, until its deck, views\steering\<date>.html, exists. Each with its
    # date and its title.
    $snapshot = Read-CalendarSnapshot
    if (-not $snapshot -or -not "$($snapshot.read_at)".StartsWith($Today)) { return }
    $last = Add-WorkingDays $Today 5
    @($snapshot.meetings | Where-Object { (Read-Timestamp $_.start) -and (Test-SteeringTitle "$($_.title)") } | Sort-Object start, title |
            Group-Object { $_.start.Substring(0, 10) } | Where-Object { $_.Name -ge $Today -and $_.Name -le $last -and -not (Test-Path -LiteralPath (Join-Path $Workspace "views\steering\$($_.Name).html")) } |
            ForEach-Object { @{ date = $_.Name; title = "$($_.Group[0].title)" } })
}

function Get-Texts($Value) {
    # Every text a value read from JSON holds, at any depth.
    if ($Value -is [string]) { $Value }
    elseif ($Value -is [Management.Automation.PSCustomObject]) { foreach ($field in $Value.PSObject.Properties) { Get-Texts $field.Value } }
    elseif ($Value -is [array]) { foreach ($item in $Value) { Get-Texts $item } }
}

function Read-MorningNotes {
    # The agent's file of state\morning.json (items, nothing without one), its notes on meetings
    # (notes), and what is wrong with it (problems): each record it cites missing or superseded,
    # as verify checks a view, and an action that names no record without its button and request.
    # The file is refused whole when anything is wrong: items and notes are then empty.
    $path = Join-Path $Workspace 'state\morning.json'
    if (-not (Test-Path -LiteralPath $path)) { return @{ notes = @(); problems = @() } }
    $file = try { Read-JsonFile $path } catch { return @{ notes = @(); problems = @('state\morning.json cannot be read: it must hold JSON, saved as UTF-8.') } }
    $notes = @($file.meetings | Where-Object { $null -ne $_ })
    # A record is cited in a text between square brackets, and by its identifier alone where the
    # file names one: the decisions of lacks, the record of an action, the commitments of progress,
    # the decision a ticket contradicts.
    $named = @(foreach ($note in $notes) { $note.lacks.PSObject.Properties | ForEach-Object { $_.Name } }) + @($file.progress.PSObject.Properties | ForEach-Object { $_.Name }) +
        @($file.first | ForEach-Object { $_.record }) + @($file.backlog.contradictions | ForEach-Object { $_.decision })
    $texts = @(Get-Texts $file) + @($named | Where-Object { "$_".Trim() } | ForEach-Object { "[$_]" })
    $problems = @(Test-Cited @(Get-Cited ($texts -join "`n"))) + @(
        $number = 0
        foreach ($action in @($file.first | Where-Object { $null -ne $_ })) {
            $number++
            if (-not "$($action.record)".Trim() -and -not ("$($action.button)".Trim() -and "$($action.ask)".Trim())) { "Action $number of first names no record and gives no button and ask." }
        })
    if ($problems) { return @{ notes = @(); problems = $problems } }
    @{ items = $file; notes = $notes; problems = @() }
}

# The agent's open questions, state\questions.json, in the format the workspace rules give: what a
# routine could not settle, each with the record or subject it concerns (about), the question, the
# agent's recommended answer and the date it was added; drop_asked once the agent has asked whether
# to drop it. The file also holds the date of the last briefing and the meetings whose outcome the
# agent has asked, which are the agent's alone.
#   { "last_briefing": "2026-03-02", "meetings_asked": [ { "start": "...", "title": "..." } ],
#     "questions": [ { "about": "C-2026-004", "question": "...", "recommended": "...", "added": "2026-03-02" } ] }

function Read-OpenQuestions {
    # The open questions (questions, nothing without the file) and what is wrong with the file
    # (problems): each record it cites or is about missing or superseded, as verify checks a view, and
    # a question without its text, its recommended answer or a date added. The file is refused whole
    # when anything is wrong: questions is then empty.
    $path = Join-Path $Workspace 'state\questions.json'
    if (-not (Test-Path -LiteralPath $path)) { return @{ questions = @(); problems = @() } }
    $file = try { Read-JsonFile $path } catch { return @{ questions = @(); problems = @('state\questions.json cannot be read: it must hold JSON, saved as UTF-8.') } }
    $questions = @($file.questions | Where-Object { $null -ne $_ })
    $about = @($questions | ForEach-Object { "$($_.about)".Trim() } | Where-Object { $_ })
    $problems = @(Test-Cited @($about + @(Get-Cited ((Get-Texts $questions) -join "`n")) | Select-Object -Unique)) + @(
        $number = 0
        foreach ($question in $questions) {
            $number++
            $lacks = @('question', 'recommended' | Where-Object { -not "$($question.$_)".Trim() }) + @(if (-not (Test-IsoDate "$($question.added)")) { 'added' })
            if ($lacks) { "Question $number lacks: $($lacks -join ', ')." }
        })
    if ($problems) { return @{ questions = @(); problems = $problems } }
    @{ questions = $questions; problems = @() }
}

function Get-WorkingDaysSince([string]$Date) {
    # The working days, Monday to Friday, from a date to today: 0 on the day itself.
    $count = 0
    while ((Add-WorkingDays $Date ($count + 1)) -le $Today) { $count++ }
    $count
}

function Get-MeetingBrief($Meeting, $Records, $Notes) {
    # The brief of a meeting, from the records of the register and the agent's notes:
    # - subjects: the active subjects whose watch list names a person among its attendees, or a
    #   keyword its title holds, as whole words, whatever the case of the letters: the keyword AI
    #   is not in "Daily";
    # - banks: the client banks of the settings that its title or an attendee names. A meeting with
    #   a client bank keeps the subjects that name that bank or none, as view bank does. A meeting
    #   that names none has the banks of its subjects;
    # - commitments and decisions: the open commitments and the pending decisions of its subjects;
    # - note: the agent's note on it.
    $holds = { param($Text, $Part) "$Part".Trim() -and [regex]::IsMatch("$Text", '(?<![\p{L}\p{N}])' + [regex]::Escape("$Part".Trim()) + '(?![\p{L}\p{N}])', 'IgnoreCase') }
    $attendees = @($Meeting.attendees | Where-Object { $_ })
    $named = @($Settings.banks | Where-Object { $bank = $_; (& $holds $Meeting.title $bank) -or @($attendees | Where-Object { & $holds $_ $bank }).Count })
    $subjects = @($Records | Where-Object { $_.type -ceq 'subject' -and $_.status -ceq 'active' } | Where-Object {
            $watch = $_.watch_list
            @($watch.people | Where-Object { $person = $_; @($attendees | Where-Object { & $holds $_ $person }).Count }).Count -or @($watch.keywords | Where-Object { & $holds $Meeting.title $_ }).Count
        } | Where-Object { -not $named -or -not $_.banks -or @($_.banks | Where-Object { $named -ccontains $_ }).Count })
    $ids = @($subjects | ForEach-Object { $_.id })
    $dated = { param($Date) if ($Date) { $Date } else { '9999-99-99' } }
    @{
        subjects    = $subjects
        banks       = $(if ($named) { $named } else { @($subjects | ForEach-Object { $_.banks } | Where-Object { $_ } | Select-Object -Unique) })
        commitments = @($Records | Where-Object { $_.type -ceq 'commitment' -and $_.status -ceq 'open' -and $ids -ccontains $_.subject } | Sort-Object { & $dated $_.due_date }, id)
        decisions   = @($Records | Where-Object { $_.type -ceq 'decision' -and $_.status -ceq 'pending' -and $ids -ccontains $_.subject } | Sort-Object { & $dated $_.needed_by }, id)
        note        = @($Notes | Where-Object { $_.start -ceq $Meeting.start -and $_.title -ceq $Meeting.title }) | Select-Object -First 1
    }
}

# --- Check --------------------------------------------------------------------------------------
# The check verifies the whole register and its staleness, with no model and no network. What it
# finds is an error, which makes the check fail, or a warning, which does not. A finding holds its
# rule, what it is about (a record as "Title [identifier]", a file, a source) and, for some, a
# detail.
#
# A rule is named by a key, listed here in the order of the check report, and labelled under
# check.rules in every language of tools\labels. Adding a rule means adding its key here, its
# label, and the finding itself: in Get-CheckFindings, or in Test-RecordRules when a proposal whose
# result would break the rule must be refused.

$CheckRules = @{
    error   = 'unreadable_record', 'unknown_field_or_value', 'missing_required_field', 'identifier_differs_from_file_name', 'reference_to_missing_record',
        'cleared_without_name_and_date', 'missing_gate_not_out_of_frame', 'taken_decision_without_author', 'effort_of_another_person', 'score_without_reason',
        'value_without_date'
    warning = 'commitment_without_owner', 'commitment_without_due_date', 'commitment_overdue', 'decision_past_its_date', 'subject_stale',
        'inbox_note_old', 'source_stale', 'unclassified_old', 'intake_incomplete', 'benefit_stale'
}

# The five parts of the intake card of a subject, in the order the card and the check name them.
# The client bank is the field banks: a subject that names no bank has not given it.
$IntakeParts = 'problem', 'banks', 'requested_by', 'data_needed', 'expected_gain'

# The scores of a subject and the AI Act mark, each with the field that holds its reason.
$ScoreReasons = [ordered]@{ value_score = 'value_reason'; feasibility_score = 'feasibility_reason'; risk_score = 'risk_reason'; ai_act_high_risk = 'ai_act_reason' }

function Test-RecordRules([string]$Type, $Record) {
    # The error rules that a record breaks by what its fields say together, as it is recorded or
    # as a proposal would leave it: for each, the rule, the reason given when a proposal is refused
    # and, for some, the detail of the finding.
    if ($Type -eq 'subject') {
        if ($Record.clearance -ceq 'cleared' -and -not ("$($Record.cleared_by)".Trim() -and $Record.cleared_on)) {
            @{ rule = 'cleared_without_name_and_date'; reason = "cleared subject without a name and a date: a cleared subject gives 'cleared_by' and 'cleared_on'" }
        }
        $missing = @($Record.gates | Where-Object { $_.state -ceq 'missing' } | ForEach-Object { $_.name }) -join ', '
        if ($Record.horizon -ceq 'now' -and $missing -and $Record.clearance -cne 'out of frame') {
            @{ rule = 'missing_gate_not_out_of_frame'; detail = $missing
                reason = "subject under Now with a missing gate ($missing) and a clearance other than out of frame: its clearance is '$($Record.clearance)'" }
        }
        # A score is a guess until its reason says why.
        $unreasoned = @($ScoreReasons.Keys | Where-Object { $null -ne $Record.$_ -and -not "$($Record.($ScoreReasons[$_]))".Trim() } | ForEach-Object { "'$_' needs '$($ScoreReasons[$_])'" }) -join ', '
        if ($unreasoned) { @{ rule = 'score_without_reason'; detail = $unreasoned; reason = "score without its reason: $unreasoned" } }
    }
    if ($Type -eq 'decision' -and $Record.status -ceq 'taken' -and -not "$($Record.decided_by)".Trim()) {
        @{ rule = 'taken_decision_without_author'; reason = "taken decision without its author: a taken decision gives 'decided_by'" }
    }
    # A value a person measured says when: a benefit's history then dates every value.
    if ($Type -eq 'benefit' -and $null -ne $Record.current_value -and -not $Record.measured_on) {
        @{ rule = 'value_without_date'; reason = "measured value without its date: a benefit that gives 'current_value' gives 'measured_on'" }
    }
    # No record measures another person: effort and start are the PO's own.
    if ($Type -eq 'commitment' -and -not (Test-IsPo $Record.owner) -and @('estimated_effort', 'real_effort', 'started_on' | Where-Object { "$($Record.$_)".Trim() })) {
        $owner = (Format-Value $Record.owner).Trim()
        @{ rule = 'effort_of_another_person'; detail = $owner
            reason = "effort or start recorded on a commitment the PO does not own (owner: $(if ($owner) { $owner } else { 'none' })): the register holds the PO's own effort only" }
    }
}

function Test-IsPo($Name) {
    # A record names the PO "the PO", as the routines write it.
    (Format-Value $Name).Trim() -eq 'the PO'
}

# --- Effort -------------------------------------------------------------------------------------
# The learning is computed here, never by a model, from the PO's own tasks only: per kind of task,
# the ratio of the real to the estimated effort, summed over the done commitments of the PO that
# give both, rounded to one decimal so that the PO can redo the sum. A kind without one has no
# past data, and its estimates stay as they are.

function Get-AdjustedEffort($Commitment) {
    # The effort of a commitment of the PO, as the views state it and as its latest start counts it:
    # its estimate, its kind of task, the ratio learned for that kind (nothing without past data)
    # and the estimate adjusted by it. Nothing when the commitment has no estimate.
    if ($null -eq $Commitment.estimated_effort) { return }
    if ($null -eq $script:EffortRatios) {
        $script:EffortRatios = @{}
        $done = @(Get-RecordFiles | Where-Object { $_.type -eq 'commitment' } | ForEach-Object { Read-JsonFile $_.path } |
                Where-Object { $_.status -ceq 'done' -and (Test-IsPo $_.owner) -and $_.task_kind -and $_.estimated_effort -gt 0 -and $_.real_effort -gt 0 })
        foreach ($kind in $done | Group-Object task_kind) {
            $real = ($kind.Group | Measure-Object real_effort -Sum).Sum
            $estimated = ($kind.Group | Measure-Object estimated_effort -Sum).Sum
            $script:EffortRatios[$kind.Name] = [Math]::Round([decimal]$real / [decimal]$estimated, 1, [MidpointRounding]::AwayFromZero)
        }
    }
    $estimate = [decimal]$Commitment.estimated_effort
    $ratio = if ($Commitment.task_kind) { $script:EffortRatios[$Commitment.task_kind] }
    @{ estimate = $estimate; kind = $Commitment.task_kind; ratio = $ratio
        adjusted = $(if ($ratio) { [Math]::Round($estimate * $ratio, 1, [MidpointRounding]::AwayFromZero) } else { $estimate }) }
}

function Format-Effort($Commitment, $Words, [Globalization.CultureInfo]$Culture) {
    # The effort of a commitment in words, with the ratio it was adjusted by or why it was not:
    # "est. 2 d, adjusted x1.4 from past steering pack: 2.8 d". $Words is the effort group of labels.
    $effort = Get-AdjustedEffort $Commitment
    if (-not $effort) { return }
    $number = { param($Value) ([decimal]$Value).ToString('0.##', $Culture) }
    if ($effort.ratio) { $Words.adjusted -f (& $number $effort.estimate), ([decimal]$effort.ratio).ToString('0.0', $Culture), $effort.kind, (& $number $effort.adjusted) }
    elseif ($effort.kind) { $Words.not_adjusted -f (& $number $effort.estimate), $effort.kind }
    else { $Words.no_kind -f (& $number $effort.estimate) }
}

function Add-WorkingDays([string]$Date, [int]$Days) {
    # The date that many working days, Monday to Friday, after a date, or before it when negative.
    $at = [DateTime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $step = [Math]::Sign($Days)
    for ($left = [Math]::Abs($Days); $left -gt 0) {
        $at = $at.AddDays($step)
        if ('Saturday', 'Sunday' -notcontains $at.DayOfWeek) { $left-- }
    }
    $at.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
}

function Get-StartSoon {
    # The margin and the lead of Start soon, in working days: the settings', or one and two.
    # ponytail: settings written before start_soon read as the template's.
    $set = $Settings.start_soon
    @{ margin = $(if ($null -ne $set.margin) { [int]$set.margin } else { 1 }); lead = $(if ($null -ne $set.lead) { [int]$set.lead } else { 2 }) }
}

function Get-LatestStart($Commitment) {
    # The latest start of a commitment of the PO: its due date minus its adjusted effort in working
    # days, a part of a day counting as a day, minus the margin. Nothing without a due date or an
    # estimate.
    $effort = Get-AdjustedEffort $Commitment
    if (-not $effort -or -not $Commitment.due_date) { return }
    Add-WorkingDays $Commitment.due_date (-([int][Math]::Ceiling($effort.adjusted) + (Get-StartSoon).margin))
}

function Get-CheckDelays {
    # The delay of each staleness rule, in days: three from the settings, and a week for the
    # unclassified items. A thing is stale when it is older than its delay, counted in whole days.
    $set = $Settings.delays_in_days
    @{ subject_stale = $set.subject; inbox_note_old = $set.inbox_note; source_stale = $set.source; unclassified_old = 7; benefit_stale = $set.subject }
}

function Get-DaysSince([string]$Date) {
    # The whole days from a date, or from the date of a timestamp, to today.
    ([DateTime]$Today - [DateTime]$Date.Substring(0, 10)).Days
}

function Get-RecordFiles {
    # Every record file of the register, type after type, in the order of the identifiers that the
    # file names give, compared character by character, which is the same on every machine: its
    # type, its path, its name from the workspace (file) and its identifier (id).
    foreach ($definition in Get-ChildItem (Join-Path $Tools 'definitions\*.json') -Exclude common.json) {
        $folder = Join-Path $Workspace (Read-JsonFile $definition.FullName).folder
        # A workspace made before the kit shipped a type has no folder for it until its first record.
        if (-not (Test-Path -LiteralPath $folder)) { continue }
        $paths = [string[]]@(Get-ChildItem -LiteralPath $folder -Recurse -File -Filter *.json | ForEach-Object { $_.FullName })
        $ids = [string[]]@($paths | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) })
        [Array]::Sort($ids, $paths, [StringComparer]::Ordinal)
        for ($n = 0; $n -lt $paths.Count; $n++) {
            @{ type = $definition.BaseName; path = $paths[$n]; file = $paths[$n].Substring($Workspace.Length + 1).Replace('\', '/'); id = $ids[$n] }
        }
    }
}

function Get-CheckFindings($Labels) {
    # Every finding of the check on the register as it is on disk.
    $details = $Labels.check.details
    $delays = Get-CheckDelays
    $files = @(Get-RecordFiles)
    # The type of every record the register holds, by identifier: identifiers differ by their case.
    $held = New-Object Collections.Hashtable ([StringComparer]::Ordinal)
    foreach ($file in $files) { $held[$file.id] = $file.type }
    # The definition of each type is read once, whatever the number of records.
    $definitions = @{}
    # A commitment, a decision or a risk recorded or updated for a subject counts as an update of
    # that subject: the latest date updated among the records attached to each subject. A subject
    # under Now is judged once every record is read.
    $touched = New-Object Collections.Hashtable ([StringComparer]::Ordinal)
    $underNow = @()

    foreach ($file in $files) {
        $record = try { Read-JsonFile $file.path } catch { }
        if ($record -isnot [System.Management.Automation.PSCustomObject]) {
            @{ rule = 'unreadable_record'; about = "``$($file.file)``" }
            continue
        }
        # A record is named as the portfolio view names a subject, by the identifier that finds it.
        $about = "$(Format-Value $record.title) [$($file.id)]".Trim()

        if (-not $definitions[$file.type]) { $definitions[$file.type] = (Get-Definition $file.type).record }
        $invalid = @(
            Test-Value $definitions[$file.type] $record '' -Stored
            if ($record.type -is [string] -and $record.type -cne $file.type) { "field 'type' is '$($record.type)'; allowed: $($file.type)" }
        )
        foreach ($problem in $invalid) {
            # A field that is missing is named alone, under its rule.
            $field = $problem -replace '^missing required field '
            @{ rule = $(if ($field -ne $problem) { 'missing_required_field' } else { 'unknown_field_or_value' }); about = $about; detail = $field }
        }
        if ($record.id -is [string] -and $record.id -cne $file.id) {
            @{ rule = 'identifier_differs_from_file_name'; about = "``$($file.file)``"; detail = "id '$($record.id)'" }
        }
        foreach ($link in 'subject', 'supersedes', 'superseded_by') {
            $named = $record.$link
            if ($named -isnot [string] -or -not $named.Trim()) { continue }
            if (-not $held[$named] -or ($link -eq 'subject' -and $held[$named] -ne 'subject')) {
                @{ rule = 'reference_to_missing_record'; about = $about; detail = "$link '$named'" }
            }
        }
        foreach ($broken in Test-RecordRules $file.type $record) { @{ rule = $broken.rule; about = $about; detail = $broken.detail } }

        # The warnings are about the records still in play, and read fields that must be valid.
        if ($invalid) { continue }
        if ($file.type -eq 'commitment' -and $record.status -ceq 'open') {
            $owner = (Format-Value $record.owner).Trim()
            $said = @(
                if ($owner) { $details.owner -f $owner }
                if ($record.due_date) { $details.due -f $record.due_date }
            ) -join ', '
            if (-not $owner) { @{ rule = 'commitment_without_owner'; about = $about; detail = $said } }
            if (-not $record.due_date) { @{ rule = 'commitment_without_due_date'; about = $about; detail = $said } }
            elseif ($record.due_date -lt $Today) { @{ rule = 'commitment_overdue'; about = $about; detail = $said } }
        }
        if ($file.type -eq 'decision' -and $record.status -ceq 'pending' -and $record.needed_by -and $record.needed_by -lt $Today) {
            $from = (Format-Value $record.needed_from).Trim()
            $said = @(if ($from) { $details.needed_from -f $from }) + ($details.needed_by -f $record.needed_by) -join ', '
            @{ rule = 'decision_past_its_date'; about = $about; detail = $said }
        }
        # A request taken in sits under Later, pending, until its intake card is whole.
        if ($file.type -eq 'subject' -and $record.status -ceq 'active' -and $record.horizon -ceq 'later' -and $record.clearance -ceq 'pending') {
            $missing = @($IntakeParts | Where-Object { -not (Format-Value $record.$_).Trim() } | ForEach-Object { $Labels.intake.parts.$_ })
            if ($missing) { @{ rule = 'intake_incomplete'; about = $about; detail = $details.missing -f ($missing -join ', ') } }
        }
        # An open benefit waits for a value a person measured: its last one, or one since it was recorded.
        if ($file.type -eq 'benefit' -and $record.status -ceq 'open') {
            $last = if ($record.measured_on) { $record.measured_on } else { $record.date_recorded }
            if ((Get-DaysSince $last) -gt $delays.benefit_stale) {
                @{ rule = 'benefit_stale'; about = $about; detail = $(if ($record.measured_on) { $details.measured } else { $details.never_measured }) -f $last }
            }
        }
        if ($record.subject -and $record.date_updated -gt $touched[$record.subject]) { $touched[$record.subject] = $record.date_updated }
        if ($file.type -eq 'subject' -and $record.status -ceq 'active' -and $record.horizon -ceq 'now') {
            $underNow += @{ id = $file.id; title = (Format-Value $record.title); about = $about; updated = $record.date_updated }
        }
    }
    foreach ($subject in $underNow) {
        $updated = if ($touched[$subject.id] -gt $subject.updated) { $touched[$subject.id] } else { $subject.updated }
        # The morning page lists a stale subject too, from its identifier, title and date updated.
        if ((Get-DaysSince $updated) -gt $delays.subject_stale) {
            @{ rule = 'subject_stale'; about = $subject.about; detail = $details.updated -f $updated; id = $subject.id; title = $subject.title; updated = $updated }
        }
    }

    # A note waits in the inbox itself: the notes filed under inbox\done are processed.
    foreach ($note in Get-ChildItem -LiteralPath (Join-Path $Workspace 'inbox') -File | Sort-Object Name) {
        $dated = $note.LastWriteTime.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        if ((Get-DaysSince $dated) -gt $delays.inbox_note_old) { @{ rule = 'inbox_note_old'; about = $note.Name; detail = $details.dated -f $dated } }
    }

    # A source is read by a collect: the collect state holds, per source, the time of the last
    # collect that read it. A source set to off is not expected to be read.
    foreach ($source in Get-Coverage | Where-Object { $_.mode -cne 'off' }) {
        $read = $source.read.collected_at
        if (-not $read) { @{ rule = 'source_stale'; about = $source.source; detail = $details.never_read } }
        elseif ((Get-DaysSince $read) -gt $delays.source_stale) { @{ rule = 'source_stale'; about = $source.source; detail = $details.read -f $read } }
    }

    # An unclassified item is a line of the list that opens with the date it was collected, as
    # apply writes it. The PO takes an item off the list once it is sorted.
    $listPath = Join-Path $Workspace 'state\unclassified.md'
    if (Test-Path -LiteralPath $listPath) {
        foreach ($line in [IO.File]::ReadAllLines($listPath, $Utf8)) {
            if ($line -cmatch '^- ((\d{4}-\d\d-\d\d) \| .*)$') {
                $item, $collected = $Matches[1], $Matches[2]
                if ((Test-IsoDate $collected) -and (Get-DaysSince $collected) -gt $delays.unclassified_old) { @{ rule = 'unclassified_old'; about = $item.Trim() } }
            }
        }
    }
}

function Write-CheckReport($Labels) {
    # Runs the check and writes the check report, views\check-report.md: the errors, then the
    # warnings, each finding under its rule. Gives the number of errors, and the summary that a
    # command prints.
    $check = $Labels.check
    $findings = @(Get-CheckFindings $Labels)
    $delays = Get-CheckDelays
    $count = @{}
    $lines = @("# $($check.title)", '') + @(Get-Stamp $Labels)
    foreach ($level in 'error', 'warning') {
        $found = @($findings | Where-Object { $CheckRules.$level -contains $_.rule })
        $count[$level] = $found.Count
        $lines += '', "## $($check."${level}s")"
        if (-not $found) { $lines += '', $check."no_$level" }
        foreach ($rule in $CheckRules.$level) {
            $listed = @($found | Where-Object { $_.rule -eq $rule })
            if (-not $listed) { continue }
            # The label of a staleness rule says its delay.
            $lines += '', "### $($check.rules.$rule -f $delays[$rule])", ''
            $lines += $listed | ForEach-Object { "- $($_.about)$(if ($_.detail) { " ($($_.detail))" })" }
        }
    }
    Write-TextFile (Join-Path $Workspace 'views\check-report.md') (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
    @{ errors = $count.error; summary = "Check: $($count.error) error(s), $($count.warning) warning(s). Check report: views\check-report.md" }
}

# --- Run the command ----------------------------------------------------------------------------

# $Now is the moment of the run, as a timestamp, and $Today its date: the clock's, unless -Now sets
# the moment or -Today its date alone. A run never reads the clock anywhere else.
$moment = if ($Now) { Read-Timestamp $Now } else { [DateTimeOffset]::Now }
if ($null -eq $moment) { Stop-Run "The moment given as now must be a date and time with its UTC offset (as 2026-03-02T08:30:00+01:00), not '$Now'." }
$Now = Format-Timestamp $moment
if (-not $Today) { $Today = $Now.Substring(0, 10) }
elseif (-not (Test-IsoDate $Today)) { Stop-Run "The date given as today must be an ISO date (yyyy-mm-dd), not '$Today'." }
else { $Now = $Today + $Now.Substring(10) }

$commandFile = Join-Path $Tools "commands\$Command.ps1"
if ($Command -cnotmatch '^[a-z]+$' -or -not (Test-Path -LiteralPath $commandFile)) {
    $known = (Get-ChildItem (Join-Path $Tools 'commands\*.ps1') | ForEach-Object { $_.BaseName }) -join ', '
    Stop-Run "Unknown command '$Command'. Commands: $known."
}
$Settings = Read-PoFile 'settings.json'
$Connections = Read-PoFile 'connections.json'
# The validation mode says what a routine has applied without asking the PO: nothing (all), or the
# plain facts of a proposal (interpreted). A routine reads it in what preview prints.
if ('all', 'interpreted' -cnotcontains $Settings.validation_mode) {
    Stop-Run "The validation mode must be 'all' or 'interpreted', not '$($Settings.validation_mode)'. Nothing was done. It is validation_mode in settings.json."
}
# An exit inside a command file only leaves that file, so the exit code is carried over here.
$ExitCode = 0
. $commandFile
exit $ExitCode
