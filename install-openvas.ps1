<#
.SYNOPSIS
    One-stop OpenVAS (Greenbone) installer for Windows.

.DESCRIPTION
    Automatically installs all prerequisites and deploys OpenVAS via Docker.
    Handles Chocolatey, WSL2, Docker Desktop, and Greenbone container setup.

.PARAMETER CheckOnly
    Show current OpenVAS status without making changes.

.PARAMETER Uninstall
    Remove OpenVAS containers and optionally volumes.

.PARAMETER LogPath
    Path to write log file. If not specified, logs to console only.

.EXAMPLE
    .\install-openvas.ps1
    Full installation with all prerequisites.

.EXAMPLE
    .\install-openvas.ps1 -CheckOnly
    Check current status.

.EXAMPLE
    .\install-openvas.ps1 -Uninstall
    Remove OpenVAS installation.
#>

[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$Uninstall,
    [string]$LogPath
)

$ErrorActionPreference = "Stop"
$script:LogFile = $LogPath

#region Logging
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
    }

    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $color

    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logMessage
    }
}
#endregion

#region Admin Elevation
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Elevation {
    if (-not (Test-Administrator)) {
        Write-Log "Requesting administrator privileges..." -Level WARN

        $scriptPath = $MyInvocation.PSCommandPath
        if (-not $scriptPath) {
            $scriptPath = $PSCommandPath
        }

        $arguments = @()
        if ($CheckOnly) { $arguments += "-CheckOnly" }
        if ($Uninstall) { $arguments += "-Uninstall" }
        if ($LogPath) { $arguments += "-LogPath `"$LogPath`"" }

        $argString = $arguments -join " "

        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" $argString"
            exit 0
        }
        catch {
            Write-Log "Failed to elevate. Please run as Administrator." -Level ERROR
            exit 1
        }
    }
    Write-Log "Running with administrator privileges" -Level SUCCESS
}
#endregion

#region Chocolatey
function Install-Chocolatey {
    Write-Log "Checking Chocolatey..."

    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if ($chocoPath) {
        Write-Log "Chocolatey already installed" -Level SUCCESS
        return $true
    }

    Write-Log "Installing Chocolatey..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # Verify
        $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoPath) {
            Write-Log "Chocolatey installed successfully" -Level SUCCESS
            return $true
        }
        else {
            Write-Log "Chocolatey installation failed - command not found" -Level ERROR
            return $false
        }
    }
    catch {
        Write-Log "Failed to install Chocolatey: $_" -Level ERROR
        return $false
    }
}
#endregion

#region WSL2
function Install-WSL2 {
    Write-Log "Checking WSL2..."

    # Check if WSL is installed and version
    try {
        $wslVersion = wsl --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $wslVersion -match "WSL") {
            Write-Log "WSL2 already installed" -Level SUCCESS
            return $true
        }
    }
    catch {
        # WSL not installed
    }

    Write-Log "Installing WSL2..."
    try {
        # Enable WSL feature
        Write-Log "Enabling Windows Subsystem for Linux..."
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null

        # Enable Virtual Machine Platform
        Write-Log "Enabling Virtual Machine Platform..."
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null

        # Install WSL via wsl --install (Windows 10 2004+)
        Write-Log "Running WSL install..."
        wsl --install --no-distribution 2>&1 | Out-Null

        # Set WSL2 as default
        wsl --set-default-version 2 2>&1 | Out-Null

        Write-Log "WSL2 installation initiated. A restart may be required." -Level WARN
        return $true
    }
    catch {
        Write-Log "Failed to install WSL2: $_" -Level ERROR
        return $false
    }
}
#endregion

#region Docker
function Install-Docker {
    Write-Log "Checking Docker Desktop..."

    # Check if Docker is running
    try {
        $dockerVersion = docker version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Docker Desktop already running" -Level SUCCESS
            return $true
        }
    }
    catch {
        # Docker not running
    }

    # Check if Docker Desktop is installed but not running
    $dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Write-Log "Docker Desktop installed but not running. Starting..."
        Start-Process $dockerDesktopPath

        # Wait for Docker to start
        $maxWait = 120
        $waited = 0
        while ($waited -lt $maxWait) {
            Start-Sleep -Seconds 5
            $waited += 5
            try {
                docker version 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Docker Desktop started" -Level SUCCESS
                    return $true
                }
            }
            catch {}
            Write-Log "Waiting for Docker to start... ($waited/$maxWait seconds)"
        }
        Write-Log "Docker Desktop failed to start in time" -Level ERROR
        return $false
    }

    # Install Docker Desktop via Chocolatey
    Write-Log "Installing Docker Desktop via Chocolatey..."
    try {
        choco install docker-desktop -y

        Write-Log "Docker Desktop installed. Starting..." -Level SUCCESS

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # Start Docker Desktop
        $dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerDesktopPath) {
            Start-Process $dockerDesktopPath
        }

        # Wait for Docker
        $maxWait = 180
        $waited = 0
        while ($waited -lt $maxWait) {
            Start-Sleep -Seconds 10
            $waited += 10
            try {
                docker version 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Docker Desktop ready" -Level SUCCESS
                    return $true
                }
            }
            catch {}
            Write-Log "Waiting for Docker to initialize... ($waited/$maxWait seconds)"
        }

        Write-Log "Docker installed but may need restart. Please restart and run again." -Level WARN
        return $false
    }
    catch {
        Write-Log "Failed to install Docker Desktop: $_" -Level ERROR
        return $false
    }
}
#endregion

#region OpenVAS Container
function Get-OpenVASComposeFile {
    return @"
version: '3.8'

services:
  openvas:
    image: greenbone/community-container
    container_name: openvas
    restart: unless-stopped
    ports:
      - "9392:9392"
      - "9390:9390"
    volumes:
      - openvas_data:/var/lib/gvm
      - openvas_logs:/var/log/gvm
    environment:
      - PASSWORD=PLACEHOLDER_PASSWORD
    deploy:
      resources:
        limits:
          memory: 8G

volumes:
  openvas_data:
  openvas_logs:
"@
}

function Install-OpenVAS {
    $composeDir = "$env:USERPROFILE\.openvas"
    $composeFile = "$composeDir\docker-compose.yml"

    # Create directory
    if (-not (Test-Path $composeDir)) {
        New-Item -ItemType Directory -Path $composeDir -Force | Out-Null
    }

    # Pull image
    Write-Log "Pulling Greenbone Community Container (this may take several minutes)..."
    docker pull greenbone/community-container
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to pull container image" -Level ERROR
        return $false
    }
    Write-Log "Container image pulled" -Level SUCCESS

    # Generate password
    $password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object { [char]$_ })

    # Create compose file
    $composeContent = Get-OpenVASComposeFile
    $composeContent = $composeContent -replace "PLACEHOLDER_PASSWORD", $password
    Set-Content -Path $composeFile -Value $composeContent
    Write-Log "Docker Compose file created" -Level SUCCESS

    # Start container
    Write-Log "Starting OpenVAS container..."
    Push-Location $composeDir
    docker-compose up -d
    $startResult = $LASTEXITCODE
    Pop-Location

    if ($startResult -ne 0) {
        Write-Log "Failed to start container" -Level ERROR
        return $false
    }

    # Wait for container health
    Write-Log "Waiting for OpenVAS to initialize (this takes several minutes)..."
    $maxWait = 300
    $waited = 0
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 15
        $waited += 15

        $health = docker inspect --format='{{.State.Health.Status}}' openvas 2>&1
        if ($health -eq "healthy") {
            Write-Log "OpenVAS container is healthy" -Level SUCCESS
            break
        }
        Write-Log "Container initializing... ($waited/$maxWait seconds) Status: $health"
    }

    # Save credentials
    $credFile = "$composeDir\credentials.txt"
    @"
OpenVAS Admin Credentials
=========================
Username: admin
Password: $password

Web UI: https://localhost:9392
Generated: $(Get-Date)

IMPORTANT: Change this password after first login!
"@ | Set-Content -Path $credFile

    Write-Log "========================================" -Level SUCCESS
    Write-Log "OpenVAS Installation Complete!" -Level SUCCESS
    Write-Log "========================================" -Level SUCCESS
    Write-Log ""
    Write-Log "Web UI: https://localhost:9392" -Level INFO
    Write-Log "Username: admin" -Level INFO
    Write-Log "Password: $password" -Level INFO
    Write-Log ""
    Write-Log "Credentials saved to: $credFile" -Level INFO
    Write-Log ""
    Write-Log "NOTE: Initial feed sync may take 30-60 minutes." -Level WARN
    Write-Log "The scanner won't have full vulnerability data until sync completes." -Level WARN

    return $true
}
#endregion

#region Status Check
function Show-Status {
    Write-Log "OpenVAS Status Check" -Level INFO
    Write-Log "===================="

    $composeDir = "$env:USERPROFILE\.openvas"

    # Check if installed
    if (-not (Test-Path "$composeDir\docker-compose.yml")) {
        Write-Log "OpenVAS is not installed" -Level WARN
        return
    }

    # Check container status
    try {
        $containerStatus = docker inspect --format='{{.State.Status}}' openvas 2>&1
        $health = docker inspect --format='{{.State.Health.Status}}' openvas 2>&1

        Write-Log "Container Status: $containerStatus"
        Write-Log "Health: $health"

        if ($containerStatus -eq "running") {
            # Get resource usage
            $stats = docker stats openvas --no-stream --format "CPU: {{.CPUPerc}}, Memory: {{.MemUsage}}"
            Write-Log "Resources: $stats"
        }
    }
    catch {
        Write-Log "Container not found or Docker not running" -Level WARN
    }

    # Check credentials file
    $credFile = "$composeDir\credentials.txt"
    if (Test-Path $credFile) {
        Write-Log ""
        Write-Log "Credentials file: $credFile" -Level INFO
    }
}
#endregion

#region Uninstall
function Uninstall-OpenVAS {
    Write-Log "Uninstalling OpenVAS..." -Level WARN

    $composeDir = "$env:USERPROFILE\.openvas"

    # Stop and remove container
    try {
        docker stop openvas 2>&1 | Out-Null
        docker rm openvas 2>&1 | Out-Null
        Write-Log "Container removed" -Level SUCCESS
    }
    catch {
        Write-Log "Container not running or already removed" -Level INFO
    }

    # Ask about volumes
    $removeVolumes = Read-Host "Remove data volumes? This will delete all scan data. (y/N)"
    if ($removeVolumes -eq "y" -or $removeVolumes -eq "Y") {
        docker volume rm openvas_data openvas_logs 2>&1 | Out-Null
        Write-Log "Volumes removed" -Level SUCCESS
    }

    # Remove compose file
    if (Test-Path $composeDir) {
        Remove-Item -Path $composeDir -Recurse -Force
        Write-Log "Configuration removed" -Level SUCCESS
    }

    Write-Log "OpenVAS uninstalled" -Level SUCCESS
}
#endregion

#region Main
function Main {
    Write-Log "========================================"
    Write-Log "OpenVAS Installer for Windows"
    Write-Log "========================================"

    # Check mode
    if ($CheckOnly) {
        Show-Status
        return
    }

    if ($Uninstall) {
        Request-Elevation
        Uninstall-OpenVAS
        return
    }

    # Full installation
    Request-Elevation

    # Step 1: Chocolatey
    if (-not (Install-Chocolatey)) {
        Write-Log "Cannot continue without Chocolatey" -Level ERROR
        exit 1
    }

    # Step 2: WSL2
    if (-not (Install-WSL2)) {
        Write-Log "WSL2 installation may require restart" -Level WARN
    }

    # Step 3: Docker
    if (-not (Install-Docker)) {
        Write-Log "Cannot continue without Docker" -Level ERROR
        exit 1
    }

    # Step 4: OpenVAS
    if (-not (Install-OpenVAS)) {
        Write-Log "OpenVAS installation failed" -Level ERROR
        exit 1
    }

    Write-Log ""
    Write-Log "Installation complete! Open https://localhost:9392 in your browser." -Level SUCCESS
}

Main
#endregion
