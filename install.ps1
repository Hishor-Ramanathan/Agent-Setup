# Agent-Setup installer for Windows (PowerShell 5.1+). One command:
#   irm https://raw.githubusercontent.com/Hishor-Ramanathan/Agent-Setup/main/install.ps1 | iex
# Clones/updates the repo to ~/Agent-Setup, copies global/ into ~/.claude, merges global/settings.json
# into ~/.claude/settings.json (your other keys stay), installs the plugins. Safe to re-run.
# Logins (claude, gh, tailscale) stay manual.

$repo   = Join-Path $HOME 'Agent-Setup'
$claude = Join-Path $HOME '.claude'
$src    = Join-Path $repo 'global'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'

if (Test-Path (Join-Path $repo '.git')) { git -C $repo pull --ff-only -q }
else { git clone -q https://github.com/Hishor-Ramanathan/Agent-Setup.git $repo }
if ($LASTEXITCODE) { throw 'git clone/pull of Agent-Setup failed' }

New-Item -ItemType Directory -Force $claude | Out-Null

# CLAUDE.md: back up a different existing one, then replace
$md = Join-Path $claude 'CLAUDE.md'
if ((Test-Path $md) -and (Get-FileHash $md).Hash -ne (Get-FileHash "$src\CLAUDE.md").Hash) {
    Copy-Item $md "$md.bak-$stamp"
}
Copy-Item "$src\CLAUDE.md" $md -Force

# reference/, skills/, output-styles/: add or overwrite the repo's items, keep everything else
foreach ($dir in 'reference', 'skills', 'output-styles') {
    $to = Join-Path $claude $dir
    New-Item -ItemType Directory -Force $to | Out-Null
    foreach ($item in Get-ChildItem (Join-Path $src $dir)) {
        $target = Join-Path $to $item.Name
        if ($item.PSIsContainer -and (Test-Path $target)) { Remove-Item $target -Recurse -Force }
        Copy-Item $item.FullName $target -Recurse -Force
    }
}

# settings.json: deep merge, repo wins on its own keys, arrays are unioned
function Merge-Json($base, $over) {
    foreach ($p in $over.PSObject.Properties) {
        $b = $base.PSObject.Properties[$p.Name]
        if ($b -and $b.Value -is [pscustomobject] -and $p.Value -is [pscustomobject]) { Merge-Json $b.Value $p.Value | Out-Null }
        elseif ($b -and $b.Value -is [array] -and $p.Value -is [array]) { $b.Value = @(@($b.Value) + @($p.Value) | Select-Object -Unique) }
        else { $base | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
    }
    $base
}
$shared = Get-Content "$src\settings.json" -Raw | ConvertFrom-Json
# leave out what this machine cannot run: the CodeGraph hook and the claude-hud status line (node)
if (-not (Get-Command codegraph -ErrorAction SilentlyContinue)) { $shared.PSObject.Properties.Remove('hooks'); Write-Host 'skipped: CodeGraph hook (codegraph not installed)' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { $shared.PSObject.Properties.Remove('statusLine'); Write-Host 'skipped: claude-hud status line (node not installed)' }

$file = Join-Path $claude 'settings.json'
$local = $null
if (Test-Path $file) { Copy-Item $file "$file.bak-$stamp"; $local = Get-Content $file -Raw | ConvertFrom-Json }
if (-not $local) { $local = [pscustomobject]@{} }
$merged = Merge-Json $local $shared
[IO.File]::WriteAllText($file, ($merged | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))

# plugins: marketplaces first, then every plugin set to true
claude plugin marketplace add anthropics/claude-plugins-official *> $null
foreach ($m in $shared.extraKnownMarketplaces.PSObject.Properties) { claude plugin marketplace add $m.Value.source.repo *> $null }
foreach ($p in $shared.enabledPlugins.PSObject.Properties) {
    if (-not $p.Value) { continue }
    $out = claude plugin install $p.Name 2>&1
    if ($LASTEXITCODE) { Write-Host "plugin FAILED: $($p.Name): $($out | Select-Object -Last 1)" } else { Write-Host "plugin ok: $($p.Name)" }
}
Write-Host "Agent-Setup installed into $claude. Restart Claude Code."
