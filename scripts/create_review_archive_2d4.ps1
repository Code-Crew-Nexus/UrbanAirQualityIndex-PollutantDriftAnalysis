$ErrorActionPreference = "Stop"
$ProjectRoot = Get-Location
$ArchiveName = "review_archive_phase2D4_light.zip"
$ArchivePath = Join-Path $ProjectRoot $ArchiveName

if (Test-Path $ArchivePath) {
    Remove-Item $ArchivePath -Force
}

$ItemsToInclude = @(
    "phase_2D4_final_input_policy_report.md",
    "config/final_aqi_input_policy.yml",
    "data/metadata/phase2D4_final_sensor_semantic_units.csv",
    "data/metadata/phase2D4_verified_subset_feasibility.csv",
    "docs/cpcb_aqi_methodology_verified.md",
    "tests/testthat/test_phase2d4.R",
    "tests/testthat/test_phase2d2.R",
    "tests/testthat/test_phase2d3.R",
    "R/24_aqi_calculation.R"
)

Write-Host "Creating archive $ArchiveName ..."
Compress-Archive -Path $ItemsToInclude -DestinationPath $ArchivePath -Force
Write-Host "Archive created successfully at $ArchivePath."
