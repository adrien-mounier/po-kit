# The client banks a subject concerns: listed in the settings, named by the subject, shown by the
# views and used to keep to one bank's subjects.

function Set-Banks([string]$Workspace, [string[]]$Banks) {
    # Lists the client banks in the settings, as the PO would.
    $path = Join-Path $Workspace 'settings.json'
    $settings = Read-Json $path
    $settings.banks = $Banks
    Write-Json $path $settings
}

function Read-Portfolio([string]$Workspace) {
    [IO.File]::ReadAllText((Join-Path $Workspace 'views\portfolio.md'), $Utf8)
}

Test 'a subject names the client banks it concerns, among those the settings list' {
    $ws = New-TestWorkspace
    Set-Banks $ws 'Harbour Bank', 'North Bank', 'Alpine Bank'
    Set-Proposal $ws @{ operations = @(New-SubjectOperation @{ banks = @('Harbour Bank', 'North Bank') }) }

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Equal 'Harbour Bank, North Bank' ((Read-Json (Join-Path $ws 'register\subjects\mobile-onboarding.json')).banks -join ', ') 'banks recorded'
}

Test 'a workspace from before the client banks keeps working: settings that list none, a subject recorded without them, a subject proposed without them' {
    $ws = New-TestWorkspaceWithSubject
    # As tranche 1 left them: no list of banks in the settings, no field on the subject.
    $path = Join-Path $ws 'settings.json'
    $settings = Read-Json $path
    $settings.PSObject.Properties.Remove('banks')
    Write-Json $path $settings
    $record = Join-Path $ws 'register\subjects\mobile-onboarding.json'
    $old = Read-Json $record
    $old.PSObject.Properties.Remove('banks')
    Write-Json $record $old
    git -C $ws commit -q -am 'A workspace of tranche 1'
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation @{ title = 'Card dispute handling' }),
            (New-UpdateOperation 'mobile-onboarding' @{ horizon = 'next' })
        )
    }

    $run = Invoke-Register $ws apply -Today 2026-03-10

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output 'Check: 0 error\(s\)' 'check after apply'
    $new = Read-Json (Join-Path $ws 'register\subjects\card-dispute-handling.json')
    Assert-True ($new.banks -is [array] -and $new.banks.Count -eq 0) 'a subject proposed without banks is not recorded with an empty list'
    Assert-Match (Read-Portfolio $ws) '\| Card dispute handling \[card-dispute-handling\] +\| Product \|' 'the subject without banks in the portfolio view'
}

Test 'the portfolio view shows the banks of a subject beside its title, and nothing beside a subject that concerns everyone' {
    $ws = New-TestWorkspace
    Set-Banks $ws 'Harbour Bank', 'North Bank', 'Alpine Bank'
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation @{ banks = @('North Bank', 'Harbour Bank') }),
            (New-SubjectOperation @{ title = 'Card dispute handling' })
        )
    }

    $run = Invoke-Register $ws apply -Today 2026-03-02

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-Portfolio $ws
    Assert-Match $view '\| Mobile onboarding \[mobile-onboarding\] \(North Bank, Harbour Bank\) +\| Product \|' 'the subject with banks'
    Assert-Match $view '\| Card dispute handling \[card-dispute-handling\] +\| Product \|' 'the subject without banks'
}

function New-TestWorkspaceWithBanks {
    # A workspace of Example Bank whose settings list three client banks, and whose subjects concern
    # Harbour Bank, North Bank, everyone, and Harbour Bank with Alpine Bank.
    $ws = New-TestWorkspace
    Set-Banks $ws 'Harbour Bank', 'North Bank', 'Alpine Bank'
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation @{ banks = @('Harbour Bank') }),
            (New-SubjectOperation @{ title = 'Branch kiosks pilot'; banks = @('North Bank') }),
            (New-SubjectOperation @{ title = 'Card dispute handling' }),
            (New-SubjectOperation @{ title = 'Loan calculator'; horizon = 'later'; banks = @('Alpine Bank', 'Harbour Bank') })
        )
    }
    $run = Invoke-Register $ws apply -Today 2026-03-02
    Assert-Equal 0 $run.ExitCode "exit code when recording the subjects, with output: $($run.Output)"
    $ws
}

Test 'view for one bank lists that bank''s subjects and those that name no bank, and its stamp says which bank it was filtered on' {
    $ws = New-TestWorkspaceWithBanks

    $run = Invoke-Register $ws view bank Harbour Bank -Now 2026-03-02T09:15:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-Portfolio $ws
    Assert-Match $view '\[mobile-onboarding\] \(Harbour Bank\)' 'the subject of the bank'
    Assert-Match $view '\[card-dispute-handling\] +\|' 'the subject that names no bank'
    Assert-Match $view '\[loan-calculator\] \(Alpine Bank, Harbour Bank\)' 'the subject of the bank and another'
    Assert-True ($view -notmatch 'branch-kiosks-pilot') 'the subject of another bank is in the view'
    Assert-Match $view '\n> Filtered on the client bank Harbour Bank: its subjects and those that name no bank\.\r?\n\r?\n## Now' 'stamp'
    Assert-Match $run.Output 'views\\portfolio\.md' 'output'
}

Test 'view for one bank in another language, with the name given whole; a bank that the settings do not list is refused and nothing is written' {
    $ws = New-TestWorkspaceWithBanks

    $run = Invoke-Register $ws view fr bank 'North Bank' -Now 2026-03-02T09:15:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    $view = Read-Portfolio $ws
    Assert-Match $view '^# Vue portefeuille' 'title of the view'
    Assert-Match $view '\[branch-kiosks-pilot\] \(North Bank\)' 'the subject of the bank'
    Assert-True ($view -notmatch 'mobile-onboarding|loan-calculator') 'a subject of another bank is in the view'
    Assert-Match $view '\n> Filtr.e sur la banque cliente North Bank : ses sujets et ceux qui ne nomment aucune banque\.\r?\n' 'stamp'

    $before = Get-WorkspaceSnapshot $ws
    foreach ($bank in 'South Bank', 'harbour bank', '') {
        $run = Invoke-Register $ws view bank $bank -Now 2026-03-02T09:15:00+01:00

        Assert-Equal 1 $run.ExitCode "exit code for '$bank', with output: $($run.Output)"
        Assert-Match $run.Output "settings\.json lists these client banks under 'banks': Harbour Bank, North Bank, Alpine Bank" "output for '$bank'"
        Assert-Equal $before (Get-WorkspaceSnapshot $ws) "files of the workspace for '$bank'"
    }
}

Test 'export gives the banks of each subject, and says "all" of a subject that names none' {
    $ws = New-TestWorkspaceWithBanks

    $run = Invoke-Register $ws export 2026-03-01 -Now 2026-03-02T09:15:00+01:00

    Assert-Equal 0 $run.ExitCode "exit code, with output: $($run.Output)"
    Assert-Match $run.Output '(?m)^- Loan calculator \[loan-calculator\] \| subject \| fact \| horizon: later \| clearance: none \| banks: Alpine Bank, Harbour Bank$' 'a subject of two banks'
    Assert-Match $run.Output '(?m)^- Card dispute handling \[card-dispute-handling\] \| subject \| fact \| horizon: now \| clearance: none \| banks: all$' 'a subject that names no bank'
}

Test 'a client bank that the settings do not list is refused at preview and at apply, on a new subject and on an update' {
    $ws = New-TestWorkspaceWithSubject
    Set-Banks $ws 'Harbour Bank', 'North Bank'
    git -C $ws commit -q -am 'The PO lists the client banks'
    Set-Proposal $ws @{ operations = @(
            (New-SubjectOperation @{ title = 'Card dispute handling'; banks = @('Harbour Bank', 'Alpine Bank') }),
            (New-UpdateOperation 'mobile-onboarding' @{ banks = @('harbour bank') })
        )
    }

    Assert-Refused $ws "Line 1: field 'banks' is 'Alpine Bank'; settings.json lists under 'banks': Harbour Bank, North Bank",
        "Line 2: field 'banks' is 'harbour bank'; settings.json lists under 'banks': Harbour Bank, North Bank"
}
