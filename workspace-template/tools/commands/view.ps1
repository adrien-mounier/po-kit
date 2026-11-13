# view: generates the portfolio view, views\portfolio.md, from the register.
#
#   view                     with the labels of the default language of settings.json
#   view fr                  with the labels of another language; what the records say is never translated
#   view bank Harbour Bank   the subjects of one client bank of settings.json and those that name no
#                            bank; its stamp says so. view fr bank Harbour Bank does both.
#
# apply regenerates the view after every write, in the default language, with every subject.

# The stamp of the view names a committed register.
Assert-RegisterCommitted
$words = @($Arguments | Where-Object { $null -ne $_ })
$at = [Array]::IndexOf([string[]]$words, 'bank')
$bank = $null
if ($at -ge 0) {
    $bank = (@($words | Select-Object -Skip ($at + 1)) -join ' ').Trim()
    $words = @($words | Select-Object -First $at)
}
$language = if ($words) { "$words" } else { $Settings.languages.default }
$labels = Get-Labels $language
if ($null -ne $bank) {
    $listed = @($Settings.banks | Where-Object { $_ })
    if ($listed -cnotcontains $bank) {
        Stop-Run "The client bank '$bank' is not listed. Nothing was written. settings.json lists these client banks under 'banks': $(if ($listed) { $listed -join ', ' } else { 'none' }). A bank the PO names that is not listed, the PO adds there first."
    }
}
Write-PortfolioView $labels $bank
"Portfolio view written in '$language'$(if ($bank) { " for the client bank $bank" }): views\portfolio.md"
