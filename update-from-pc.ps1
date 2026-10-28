# Run on the Windows PC to refresh this repo with the latest VS Code / Claude setup, then push.
#   powershell -ExecutionPolicy Bypass -File update-from-pc.ps1
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$bones = "$env:USERPROFILE\Documents\Projects\Bones INC"

Copy-Item "$env:APPDATA\Code\User\settings.json" "$here\vscode\settings.json"
if (Test-Path "$env:APPDATA\Code\User\keybindings.json") { Copy-Item "$env:APPDATA\Code\User\keybindings.json" "$here\vscode\keybindings.json" }
if (Test-Path "$env:APPDATA\Code\User\snippets\*") { Copy-Item "$env:APPDATA\Code\User\snippets" "$here\vscode\" -Recurse -Force }
code --list-extensions | Where-Object { $_ -notmatch '^ms-vscode\.powershell$|^meech\.bones-inc$' } |
  Set-Content "$here\vscode\extensions.txt" -Encoding ascii

Copy-Item "$env:USERPROFILE\.claude\settings.json" "$here\claude\settings.json"

# Newest Bones INC build
$vsix = Get-ChildItem "$bones\bones-inc-*.vsix" | Sort-Object { [version]($_.BaseName -replace 'bones-inc-','') } | Select-Object -Last 1
if ($vsix) { Remove-Item "$here\vscode\bones-inc-*.vsix"; Copy-Item $vsix.FullName "$here\vscode\" }

git -C $here add -A
git -C $here diff --cached --quiet
if ($LASTEXITCODE -ne 0) { git -C $here commit -q -m "Update from PC"; git -C $here push -q; "Pushed updates." } else { "Already up to date." }
