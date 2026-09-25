<#
.SYNOPSIS
Creates a lightweight review archive.

.DESCRIPTION
NORMAL EXTERNAL REVIEW:
run:
.\scripts\create_review_archive_light.ps1

FULL RAW REVIEW ONLY WHEN EXPLICITLY NEEDED:
run:
.\scripts\create_review_archive.ps1

The light archive should be the default artifact uploaded for future ChatGPT review.
#>

$ErrorActionPreference = "Stop"

$ProjectRoot = Get-Location
$ArchiveName = "review_archive_phase2D1_light.zip"
$StagingDir = Join-Path $ProjectRoot ".staging_archive_light_temp"

if (Test-Path $ArchiveName) { Remove-Item $ArchiveName -Force }
if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
New-Item -ItemType Directory -Path $StagingDir | Out-Null

Write-Host "Copying files to staging directory..."

# Items to explicitly copy
$ItemsToCopy = @(
    "config",
    "data\metadata",
    "data\interim",
    "R",
    "scripts",
    "tests",
    "docs",
    "README.md",
    "phase_2A_pilot_report.md",
    "phase_2A1_kolkata_review_report.md",
    "phase_2B_full_acquisition_report.md",
    "phase_2B1_closure_report.md",
    "phase_2B2_normalization_integrity_report.md",
    "phase_2C_daily_preaqi_report.md",
    "phase_2D_cpcb_methodology_report.md",
    "phase_2D1_cpcb_methodology_closure_report.md"
)

foreach ($item in $ItemsToCopy) {
    if (Test-Path $item) {
        if ((Get-Item $item) -is [System.IO.FileInfo]) {
            Copy-Item -Path $item -Destination $StagingDir -Force
        } else {
            $dest = Join-Path $StagingDir (Split-Path $item -Leaf)
            Copy-Item -Path $item -Destination $dest -Recurse -Force
        }
    }
}

# Remove excluded items from staging just in case they slipped in
Get-ChildItem -Path $StagingDir -Recurse -Force | Where-Object {
    $_.Name -eq ".Renviron" -or $_.Name -eq ".env" -or $_.Name -like "*.secret" -or $_.Name -eq ".git" -or $_.Name -eq "data\raw" -or $_.Name -eq "data\quarantine" -or $_.Name -eq "logs" -or $_.Name -like "review_archive*.zip"
} | Remove-Item -Recurse -Force

Write-Host "Compressing staging directory..."
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ArchiveName -Force

Write-Host "Cleaning up staging directory..."
Remove-Item $StagingDir -Recurse -Force

# Verify no sensitive or excluded files made it in
$zip = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $ProjectRoot $ArchiveName))
$badFound = $false
foreach ($entry in $zip.Entries) {
    $name = $entry.Name
    if ($name -eq ".Renviron" -or $name -eq ".env" -or $name -like "*.secret" -or $name -match "data/raw/" -or $name -match "data/quarantine/" -or $name -match "logs/") {
        Write-Error "CRITICAL: Excluded file found in light archive: $name"
        $badFound = $true
    }
}
$zip.Dispose()

if ($badFound) {
    Remove-Item $ArchiveName -Force
    Write-Error "Archive creation aborted and deleted."
    exit 1
}

Write-Host "Created $ArchiveName successfully."
