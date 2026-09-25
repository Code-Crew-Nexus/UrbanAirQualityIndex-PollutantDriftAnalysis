$ErrorActionPreference = "Stop"

$ProjectRoot = Get-Location
$ArchiveName = "review_archive.zip"
$StagingDir = Join-Path $ProjectRoot ".staging_archive_temp"

# Remove old archive and old staging dir if they exist
if (Test-Path $ArchiveName) { Remove-Item $ArchiveName -Force }
if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }

# Create staging dir
New-Item -ItemType Directory -Path $StagingDir | Out-Null

Write-Host "Copying files to staging directory..."
# Use Robocopy to copy all files excluding sensitive and unnecessary ones
# Robocopy exit codes < 8 are considered success
$RobocopyArgs = @(
    $ProjectRoot,
    $StagingDir,
    "/E",
    "/XD", ".git", ".Rproj.user", "logs", "data\quarantine", ".staging_archive_temp",
    "/XF", ".Renviron", ".env", "*.secret", "review_archive*.zip", "*.log", "*.tmp", "*.bak", "*.RData", "*.Rhistory"
)
& robocopy $RobocopyArgs | Out-Null

# Create zip from staging directory
Write-Host "Compressing staging directory..."
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ArchiveName -Force

# Clean up staging directory
Write-Host "Cleaning up staging directory..."
Remove-Item $StagingDir -Recurse -Force

# Verify archive does not contain sensitive files
Write-Host "Verifying archive safety..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $ProjectRoot $ArchiveName))
$sensitiveFound = $false
foreach ($entry in $zip.Entries) {
    $name = $entry.Name
    if ($name -eq ".Renviron" -or $name -eq ".env" -or $name -like "*.secret") {
        Write-Error "CRITICAL: Sensitive file found in archive: $name"
        $sensitiveFound = $true
    }
}
$zip.Dispose()

if ($sensitiveFound) {
    Remove-Item $ArchiveName -Force
    Write-Error "Archive creation aborted and deleted due to sensitive file inclusion."
    exit 1
}

Write-Host "Archive created successfully at $ArchiveName"
