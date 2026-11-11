# check: verifies the whole register and its staleness, and writes the check report,
# views\check-report.md, in the default language of settings.json. It uses no model.
#
# It ends with a failure code when it finds at least one error, and with a success when it finds
# warnings only. apply runs the same check after every write.

Assert-RegisterCommitted
$check = Write-CheckReport (Get-Labels $Settings.languages.default)
$check.summary
if ($check.errors) { $ExitCode = 1 }
