param(
    [string]$GodotPath = '',
    [switch]$Editor,
    [switch]$Test,
    [switch]$Gallery,
    [string]$Balance = ''
)

$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
if (-not $GodotPath) {
    $candidateCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidateCommand) { $GodotPath = $candidateCommand.Source }
}
if (-not $GodotPath) {
    $downloadDirectory = Join-Path $env:USERPROFILE 'Downloads'
    $candidateExecutable = Get-ChildItem -LiteralPath $downloadDirectory -Directory -Filter 'Godot*' -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter '*win64_console.exe' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($candidateExecutable) { $GodotPath = $candidateExecutable.FullName }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot 4 was not found. Run .\launch.ps1 -GodotPath C:\path\to\godot.exe'
}

# Keep this prototype's editor cache and saves local. Restore the shell afterwards.
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $projectDirectory '.runtime'
    $env:LOCALAPPDATA = Join-Path $projectDirectory '.runtime/local'
    if ($Balance) {
        & $GodotPath --headless --path $projectDirectory --script res://tests/balance_runs.gd --log-file balance-runs.log -- "--label=$Balance"
        if ($LASTEXITCODE -ne 0) { throw 'Balance simulations failed.' }
    } elseif ($Gallery) {
        & $GodotPath --path $projectDirectory --script res://tests/location_architecture_gallery.gd --log-file architecture-gallery.log
        if ($LASTEXITCODE -ne 0) { throw 'Location architecture gallery failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/environment_inventory_test.gd --log-file environment-inventory-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Environment/inventory UI tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/style_refresh_test.gd --log-file style-refresh-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Style/world UI tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/asset_gallery.gd --log-file asset-gallery.log
        if ($LASTEXITCODE -ne 0) { throw 'Asset gallery rendering failed.' }
    } elseif ($Test) {
        & $GodotPath --headless --path $projectDirectory --editor --import --quit --log-file import.log
        if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/start_screen_test.gd --log-file start-screen-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Start screen tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/naming_screen_test.gd --log-file naming-screen-test.log
        if ($LASTEXITCODE -ne 0) { throw 'Naming screen tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/character_creation_test.gd --log-file character-creation-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Character creation tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/character_gender_test.gd --log-file character-gender-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Character gender tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/simulation_test.gd --log-file tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Simulation tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/npc_naming_test.gd --log-file npc-naming-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'NPC naming tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/npc_sex_test.gd --log-file npc-sex-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'NPC sex tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/npc_starting_skills_test.gd --log-file npc-starting-skills-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'NPC starting skills tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/barricade_test.gd --log-file barricade-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Barricade tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/survival_test.gd --log-file survival-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Survival tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/npc_balance_test.gd --log-file npc-balance-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'NPC balance/rule tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/search_test.gd --log-file search-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Search tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/loot_and_trust_test.gd --log-file loot-trust-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Loot/trust tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/content_expansion_test.gd --log-file content-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Content expansion tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/encumbrance_test.gd --log-file encumbrance-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Encumbrance/door tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/world_test.gd --log-file world-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'World tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/location_architecture_test.gd --log-file architecture-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Location architecture tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/fort_rules_test.gd --log-file fort-rules-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Fort rules tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/free_running_test.gd --log-file free-running-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Free Running tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/environment_rules_test.gd --log-file environment-rules-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Environment and dark building tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/ruin_debt_test.gd --log-file ruin_debt-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'ruin_debt tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/sleep_test.gd --log-file sleep-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'sleep tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/search_coverage_test.gd --log-file search_coverage-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'search_coverage tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/widescreen_test.gd --log-file widescreen-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Widescreen and powered-ruin tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/minimap_movement_test.gd --log-file minimap-movement-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Minimap movement tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/interface_test.gd --log-file interface-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Interface tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/damage_feedback_test.gd --log-file damage-feedback-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Damage feedback tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/location_transition_test.gd --log-file location-transition-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Location transition tests failed.' }
        & $GodotPath --headless --path $projectDirectory --script res://tests/map_labels_test.gd --log-file map-labels-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Map label tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/connected_minimap_test.gd --log-file connected-minimap-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Connected minimap tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/environment_inventory_test.gd --log-file environment-inventory-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Environment/inventory UI tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/style_refresh_test.gd --log-file style-refresh-tests.log
        if ($LASTEXITCODE -ne 0) { throw 'Style/world UI tests failed.' }
        & $GodotPath --path $projectDirectory --script res://tests/asset_gallery.gd --log-file asset-gallery.log
        if ($LASTEXITCODE -ne 0) { throw 'Asset gallery rendering failed.' }
    } elseif ($Editor) {
        & $GodotPath --path $projectDirectory --editor
    } else {
        & $GodotPath --headless --path $projectDirectory --editor --import --quit --log-file import.log
        if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
        & $GodotPath --path $projectDirectory --log-file play.log
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
