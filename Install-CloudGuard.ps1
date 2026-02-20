# Cloud CLI Guard - PowerShell Installer
# Installs the CloudCliGuard module and configures the PowerShell profile

$ErrorActionPreference = 'Stop'

Write-Host '=================================='
Write-Host 'Cloud CLI Guard - PowerShell Setup'
Write-Host '=================================='
Write-Host ''

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$moduleSource = Join-Path $scriptDir 'CloudCliGuard.psm1'

if (-not (Test-Path $moduleSource)) {
    Write-Host "ERROR: CloudCliGuard.psm1 not found at: $moduleSource" -ForegroundColor Red
    Write-Host 'Please run this script from the cloud-cli-guard directory.'
    exit 1
}

# Determine module install path (user-scoped Modules folder, version-aware)
$psFolder = if ($PSVersionTable.PSVersion.Major -ge 6) { 'PowerShell' } else { 'WindowsPowerShell' }
$modulesRoot = Join-Path (Join-Path ([Environment]::GetFolderPath('MyDocuments')) $psFolder) 'Modules'
$moduleDest = Join-Path $modulesRoot 'CloudCliGuard'

Write-Host "Module source: $moduleSource"
Write-Host "Install path:  $moduleDest"
Write-Host ''

# Create directories
Write-Host 'Creating directories...'
$azureDir = Join-Path $HOME '.azure'
$approvalsDir = Join-Path $azureDir 'approvals'
foreach ($dir in @($azureDir, $approvalsDir, $moduleDest)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Copy module
Write-Host 'Installing CloudCliGuard module...'
Copy-Item -Path $moduleSource -Destination (Join-Path $moduleDest 'CloudCliGuard.psm1') -Force
Write-Host "  Module installed to $moduleDest" -ForegroundColor Green
Write-Host ''

# Detect CLIs
Write-Host 'Detecting CLI installations...'
$azCmd = Get-Command 'az' -ErrorAction SilentlyContinue
$ghCmd = Get-Command 'gh' -ErrorAction SilentlyContinue

if ($azCmd) { Write-Host "  Azure CLI found: $($azCmd.Source)" -ForegroundColor Green }
else        { Write-Host '  WARNING: Azure CLI (az) not found' -ForegroundColor Yellow }

if ($ghCmd) { Write-Host "  GitHub CLI found: $($ghCmd.Source)" -ForegroundColor Green }
else        { Write-Host '  WARNING: GitHub CLI (gh) not found' -ForegroundColor Yellow }

Write-Host ''

# Add to profile
Write-Host 'Configuring PowerShell profile...'
$profilePath = $PROFILE.CurrentUserCurrentHost
$profileDir = Split-Path -Parent $profilePath

if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($profileContent -and $profileContent -match 'CloudCliGuard') {
    Write-Host '  CloudCliGuard already in profile -- skipping' -ForegroundColor Yellow
} else {
    $importLine = @'

# Cloud CLI Guard - Safety wrappers for az and gh
Import-Module CloudCliGuard
'@
    Add-Content -Path $profilePath -Value $importLine -Encoding UTF8
    Write-Host "  Added Import-Module to: $profilePath" -ForegroundColor Green
}

Write-Host ''
Write-Host '=================================='
Write-Host 'Setup Complete!'
Write-Host '=================================='
Write-Host ''
Write-Host 'Next steps:'
Write-Host '1. Reload your PowerShell profile:'
Write-Host "   . `$PROFILE"
Write-Host ''
Write-Host '2. Test the installation:'
Write-Host '   az --guard-status'
Write-Host '   gh --guard-status'
Write-Host ''
Write-Host '3. Try a blocked command:'
Write-Host '   az group delete -n fake-resource-group'
Write-Host '   gh repo delete fake-repo'
Write-Host ''
Write-Host 'Files installed:'
Write-Host "  $moduleDest\CloudCliGuard.psm1"
Write-Host "  $azureDir\az-guard-config (configuration)"
Write-Host "  $azureDir\az-guard-audit.log (audit trail)"
Write-Host ''
# Auto-install bash guard if Git Bash is available
$bashInstaller = Join-Path $scriptDir 'install-cloud-guard.sh'
$gitBash = 'C:\Program Files\Git\bin\bash.exe'

if ($env:CLOUD_GUARD_CROSS_INSTALL) {
    # Called from bash installer -- skip to avoid recursion
} elseif ((Test-Path $bashInstaller) -and (Test-Path $gitBash)) {
    Write-Host 'Detected Git Bash. Installing bash guard...'
    $bashPath = $scriptDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
    $bashPath = $bashPath.Substring(0, 2).ToLower() + $bashPath.Substring(2)
    try {
        $env:CLOUD_GUARD_CROSS_INSTALL = '1'
        $output = & $gitBash -c "cd '$bashPath' && CLOUD_GUARD_CROSS_INSTALL=1 bash install-cloud-guard.sh 2>&1" 2>&1
        Remove-Item Env:\CLOUD_GUARD_CROSS_INSTALL -ErrorAction SilentlyContinue
        $output | ForEach-Object { Write-Host "  [Bash] $_" }
    } catch {
        Write-Host '  Bash install had issues (non-fatal). You can retry:' -ForegroundColor Yellow
        Write-Host "  & `"$gitBash`" -c `"cd '$bashPath' && bash install-cloud-guard.sh`""
    }
    Write-Host ''
} elseif (Test-Path $bashInstaller) {
    Write-Host 'Git Bash not detected. To also protect Git Bash, run in Git Bash:' -ForegroundColor Yellow
    Write-Host '  bash install-cloud-guard.sh'
    Write-Host ''
}

Write-Host 'To uninstall:'
Write-Host "  1. Remove 'Import-Module CloudCliGuard' from $profilePath"
Write-Host "  2. Remove-Item -Recurse '$moduleDest'"
Write-Host ''
