$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location
$ArchiveName = "review_archive_phase2D2_light.zip"
$ArchivePath = Join-Path $ProjectRoot $ArchiveName

if (Test-Path $ArchivePath) {
    Remove-Item $ArchivePath -Force
}

$MarkdownFiles = Get-ChildItem -Path . -Filter "phase*.md" | Select-Object -ExpandProperty Name

$ItemsToInclude = @(
    "data/metadata/cpcb_methodology_source_registry.csv",
    "data/metadata/cpcb_aqi_test_vectors.csv",
    "data/metadata/selected_sensor_snapshot.csv",
    "data/metadata/project_measurement_unit_provenance.csv",
    "data/metadata/phase2D2_sensor_unit_audit.csv",
    "data/metadata/phase2D2_source_unit_distribution.csv",
    "data/metadata/phase2D2_severe_policy_impact.csv",
    "data/metadata/phase2D1_project_aqi_diagnostic_sample.csv",
    "config/aqi_breakpoints_india.csv",
    "config/gas_conversion_factors_india.csv",
    "docs/cpcb_aqi_methodology_verified.md",
    "R/24_aqi_calculation.R",
    "tests/testthat/test_phase2d1.R",
    "tests/testthat/test_phase2d2.R"
)

$AllItems = $MarkdownFiles + $ItemsToInclude

Write-Host "Creating archive $ArchiveName ..."
Compress-Archive -Path $AllItems -DestinationPath $ArchivePath -Force
Write-Host "Archive created successfully at $ArchivePath."
