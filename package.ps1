# GCM Plugin Packaging Script for Windows
# This script packages a GCM plugin into a zip file ready for deployment

$ErrorActionPreference = "Stop"

# Read plugin metadata from manifest.json
if (-not (Test-Path "manifest.json")) {
    Write-Host "Error: manifest.json not found in current directory" -ForegroundColor Red
    exit 1
}

try {
    $manifest = Get-Content manifest.json | ConvertFrom-Json
    $pluginCode = $manifest.code
    $pluginVersion = $manifest.version
} catch {
    Write-Host "Error: Could not read 'code' or 'version' from manifest.json" -ForegroundColor Red
    exit 1
}

if (-not $pluginCode -or -not $pluginVersion) {
    Write-Host "Error: 'code' or 'version' missing in manifest.json" -ForegroundColor Red
    exit 1
}

$pluginDir = "${pluginCode}_${pluginVersion}"
$zipName = "${pluginCode}-${pluginVersion}.zip"

Write-Host "Packaging plugin: $pluginCode v$pluginVersion" -ForegroundColor Cyan

# Verify .bundleignore exists
if (-not (Test-Path ".bundleignore")) {
    Write-Host "Error: .bundleignore file not found" -ForegroundColor Red
    exit 1
}

# Clean up old files
Write-Host "Cleaning up old files..." -ForegroundColor Yellow
Remove-Item -Force $zipName -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $pluginDir -ErrorAction SilentlyContinue

# Create temp directory
Write-Host "Creating temporary directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null

# Read .bundleignore patterns
$ignorePatterns = @()
if (Test-Path '.bundleignore') {
    $ignorePatterns = Get-Content '.bundleignore' | Where-Object {
        $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$'
    }
}

# Function to check if path matches ignore patterns
function Should-Ignore {
    param($Path, $Patterns)
    foreach ($pattern in $Patterns) {
        $pattern = $pattern.Trim()
        if ($Path -like "*$pattern*") {
            return $true
        }
    }
    return $false
}

# Copy all files and directories, excluding patterns from .bundleignore
Write-Host "Copying files (excluding patterns from .bundleignore)..." -ForegroundColor Yellow
Get-ChildItem -Path . -Recurse -Force | Where-Object {
    $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1)
    -not (Should-Ignore $relativePath $ignorePatterns) -and
    $_.FullName -notlike "*$pluginDir*" -and
    $_.Name -ne $zipName
} | ForEach-Object {
    $targetPath = Join-Path $pluginDir $_.FullName.Substring((Get-Location).Path.Length + 1)
    $targetDir = Split-Path $targetPath -Parent
    
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    if (-not $_.PSIsContainer) {
        Copy-Item $_.FullName -Destination $targetPath -Force -ErrorAction SilentlyContinue
    }
}

# Create zip from contents of temp directory (files at root level)
Write-Host "Creating zip file..." -ForegroundColor Yellow
$filesToZip = Get-ChildItem -Path $pluginDir -Recurse -Force
Compress-Archive -Path $filesToZip.FullName -DestinationPath $zipName -Force

# Cleanup temp directory
Write-Host "Cleaning up temporary directory..." -ForegroundColor Yellow
Remove-Item -Recurse -Force $pluginDir

# Report success
Write-Host ""
Write-Host "Plugin packaged successfully!" -ForegroundColor Green
Write-Host "Zip file: $zipName" -ForegroundColor Cyan
Get-Item $zipName | Select-Object Name, Length | Format-Table

# Verify structure (if unzip available)
Write-Host ""
Write-Host "Package structure:" -ForegroundColor Cyan
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $zipName))
    $zip.Entries | Select-Object -First 20 | ForEach-Object {
        Write-Host "  $($_.FullName)"
    }
    $zip.Dispose()
} catch {
    Write-Host "  (Install 7-Zip or use 'unzip -l' to view contents)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Package ready for deployment!" -ForegroundColor Green

# Made with Bob
