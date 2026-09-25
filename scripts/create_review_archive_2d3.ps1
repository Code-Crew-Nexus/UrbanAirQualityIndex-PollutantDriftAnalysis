$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location
$ArchiveName = "review_archive_phase2D3_light.zip"
$ArchivePath = Join-Path $ProjectRoot $ArchiveName

if (Test-Path $ArchivePath) {
    Remove-Item $ArchivePath -Force
}

$MarkdownFiles = Get-ChildItem -Path . -Filter "phase*.md" | Select-Object -ExpandProperty Name
# Exclude the very old ones or keep them. The user wants the light archive to accumulate.

$MarkdownFiles = Get-ChildItem -Path . -Filter "phase*.md" | Select-Object -ExpandProperty Name
$ItemsToInclude = @(
    "data/metadata/phase2D3_location_sensor_unit_catalog.csv",
    "data/metadata/phase2D3_sensor_semantic_units.csv",
    "data/metadata/phase2D3_source_unit_distribution.csv",
    "data/metadata/phase2D3_unit_trace_examples.csv",
    "data/metadata/phase2D3_severe_policy_impact.csv",
    "data/metadata/phase2D3_unit_audit_manifest.csv",
    "data/metadata/phase2D1_project_aqi_diagnostic_sample.csv",
    "data/metadata/selected_sensor_snapshot.csv",
    "config/aqi_breakpoints_india.csv",
    "config/gas_conversion_factors_india.csv",
    "docs/cpcb_aqi_methodology_verified.md",
    "R/24_aqi_calculation.R",
    "scripts/generate_diagnostic_aqi_sample.R",
    "tests/testthat/test_phase2d3.R",
    "tests/testthat/test_phase2d2.R"
)

$AllItems = $MarkdownFiles + $ItemsToInclude

# Use explicit items array
Write-Host "Creating archive $ArchiveName ..."
Compress-Archive -Path $AllItems -DestinationPath $ArchivePath -Force
Write-Host "Archive created successfully at $ArchivePath."
