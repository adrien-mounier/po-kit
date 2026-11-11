# view: generates the portfolio view, views\portfolio.md, from the register.
#
#   view       with the labels of the default language of settings.json
#   view fr    with the labels of another language; what the records say is never translated
#
# apply regenerates the view after every write, in the default language.

# The stamp of the view names a committed register.
Assert-RegisterCommitted
$language = if ($Arguments) { "$Arguments" } else { $Settings.languages.default }
Write-PortfolioView (Get-Labels $language)
"Portfolio view written in '$language': views\portfolio.md"
