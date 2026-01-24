$installDir = "$HOME\AI-Gen-Profile"
$targetFile = "$installDir\script.ps1"
$skeletonFile = "$installDir\skeleton.md"

$sourceUrl = "https://raw.githubusercontent.com/abduznik/AI-Gen-Profile/main/script.ps1"
$skeletonUrl = "https://raw.githubusercontent.com/abduznik/AI-Gen-Profile/main/skeleton.md"

Write-Host "Installing Abduznik's AI Profile Generator..." -ForegroundColor Cyan

# 1. Create Directory
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# 2. Download Tool & Skeleton
try {
    Invoke-WebRequest -Uri $sourceUrl -OutFile $targetFile -ErrorAction Stop
    Invoke-WebRequest -Uri $skeletonUrl -OutFile $skeletonFile -ErrorAction Stop
} catch {
    Write-Host "Failed to download components from GitHub." -ForegroundColor Red
    exit 1
}

# 3. Add to Profile
if (-not (Test-Path $PROFILE)) {
    New-Item -Type File -Path $PROFILE -Force | Out-Null
}

$loadCmd = ". '$targetFile'"
$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -notlike "*$targetFile*") {
    Add-Content -Force $PROFILE "`n$loadCmd"
    Write-Host "Added to PowerShell profile." -ForegroundColor Green
}

# 4. Load for current session
Invoke-Expression $loadCmd

Write-Host "Success! Type 'gen-profile' to start." -ForegroundColor Magenta