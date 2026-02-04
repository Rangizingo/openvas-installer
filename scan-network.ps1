<#
.SYNOPSIS
    Auto-discover and scan entire network with OpenVAS.

.DESCRIPTION
    Detects all local subnets, discovers live hosts via nmap,
    creates OpenVAS target and launches comprehensive scan.

.PARAMETER SkipDiscovery
    Skip nmap discovery, scan entire subnets directly.

.PARAMETER ExcludeSubnets
    Comma-separated subnets to exclude (e.g., "172.17.0.0/16,172.18.0.0/16")

.PARAMETER ScanConfig
    OpenVAS scan config: "full_fast", "full_deep", "discovery"
    Default: full_fast

.EXAMPLE
    .\scan-network.ps1
    Auto-discover and scan all networks.

.EXAMPLE
    .\scan-network.ps1 -ExcludeSubnets "172.17.0.0/16"
    Exclude Docker networks.
#>

[CmdletBinding()]
param(
    [switch]$SkipDiscovery,
    [string]$ExcludeSubnets = "",
    [ValidateSet("full_fast", "full_deep", "discovery")]
    [string]$ScanConfig = "full_fast",
    [switch]$GUI
)

$ErrorActionPreference = "Stop"

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
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}
#endregion

#region Prerequisites
function Install-Nmap {
    Write-Log "Checking nmap..."

    $nmap = Get-Command nmap -ErrorAction SilentlyContinue
    if ($nmap) {
        Write-Log "nmap already installed" -Level SUCCESS
        return $true
    }

    Write-Log "Installing nmap via Chocolatey..."
    choco install nmap -y

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    $nmap = Get-Command nmap -ErrorAction SilentlyContinue
    if ($nmap) {
        Write-Log "nmap installed" -Level SUCCESS
        return $true
    }

    Write-Log "Failed to install nmap" -Level ERROR
    return $false
}

function Test-OpenVAS {
    Write-Log "Checking OpenVAS container..."

    $container = docker ps --filter "name=openvas" --format "{{.Status}}" 2>&1
    if ($container -match "Up") {
        Write-Log "OpenVAS container running" -Level SUCCESS
        return $true
    }

    Write-Log "OpenVAS container not running. Start it first." -Level ERROR
    return $false
}
#endregion

#region Network Discovery
function Get-VPNAdapters {
    Write-Log "Detecting VPN adapters..."

    $vpnKeywords = @(
        "NordLynx", "OpenVPN", "WireGuard", "Mullvad",
        "ProtonVPN", "Windscribe", "TAP-", "TUN-"
    )

    $vpnAdapters = @()

    $allAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

    foreach ($adapter in $allAdapters) {
        foreach ($keyword in $vpnKeywords) {
            if ($adapter.Name -like "*$keyword*" -or $adapter.InterfaceDescription -like "*$keyword*") {
                $vpnAdapters += $adapter
                Write-Log "Found VPN adapter: $($adapter.Name)" -Level WARN
                break
            }
        }
    }

    return $vpnAdapters
}

function Get-LocalSubnets {
    Write-Log "Detecting local subnets..."

    $excludeList = @()
    if ($ExcludeSubnets) {
        $excludeList = $ExcludeSubnets -split "," | ForEach-Object { $_.Trim() }
    }

    # Always exclude common virtual networks
    $defaultExcludes = @(
        "172.17.", "172.18.", "172.19.", "172.20.",  # Docker
        "172.31.", "172.26.",                          # WSL
        "127."                                          # Loopback
    )

    # Get VPN adapters and add their IPs to excludes
    $vpnAdapters = Get-VPNAdapters
    $vpnIPs = @()
    foreach ($vpnAdapter in $vpnAdapters) {
        $vpnIP = Get-NetIPAddress -InterfaceIndex $vpnAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($vpnIP) {
            $vpnIPs += $vpnIP.IPAddress
            Write-Log "Excluding VPN subnet: $($vpnIP.IPAddress)/$($vpnIP.PrefixLength)" -Level WARN
        }
    }

    $subnets = @()

    $adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -notmatch "^169\.254\." -and  # APIPA
        $_.PrefixOrigin -ne "WellKnown"
    }

    foreach ($adapter in $adapters) {
        $ip = $adapter.IPAddress
        $prefix = $adapter.PrefixLength

        # Check VPN excludes
        $skip = $false
        if ($vpnIPs -contains $ip) {
            Write-Log "Skipping VPN network: $ip/$prefix" -Level WARN
            $skip = $true
        }

        # Check default excludes
        if (-not $skip) {
            foreach ($exclude in $defaultExcludes) {
                if ($ip.StartsWith($exclude)) {
                    Write-Log "Skipping virtual network: $ip/$prefix" -Level WARN
                    $skip = $true
                    break
                }
            }
        }

        # Check user excludes
        if (-not $skip) {
            foreach ($exclude in $excludeList) {
                $excludeNet = $exclude -replace "/\d+$", ""
                if ($ip.StartsWith($excludeNet.TrimEnd(".0"))) {
                    Write-Log "Skipping excluded network: $ip/$prefix" -Level WARN
                    $skip = $true
                    break
                }
            }
        }

        if (-not $skip) {
            # Calculate network address using simple approach
            $ipParts = $ip.Split(".")
            $network = switch ([int][Math]::Ceiling($prefix / 8)) {
                1 { "$($ipParts[0]).0.0.0/$prefix" }
                2 { "$($ipParts[0]).$($ipParts[1]).0.0/$prefix" }
                3 { "$($ipParts[0]).$($ipParts[1]).$($ipParts[2]).0/$prefix" }
                4 { "$ip/$prefix" }
                default { "$($ipParts[0]).$($ipParts[1]).$($ipParts[2]).0/$prefix" }
            }

            if ($network -notin $subnets) {
                $subnets += $network
                Write-Log "Found subnet: $network"
            }
        }
    }

    return $subnets
}

function Find-LiveHosts {
    param([string[]]$Subnets)

    Write-Log "Discovering live hosts (this may take a few minutes)..."

    $allHosts = @()

    foreach ($subnet in $Subnets) {
        Write-Log "Scanning $subnet..."

        # Use nmap ping scan
        $nmapPath = "C:\Program Files (x86)\Nmap\nmap.exe"
        if (-not (Test-Path $nmapPath)) {
            $nmapPath = "nmap"
        }

        # Add --min-rate for larger subnets (prefix <= 24)
        $nmapArgs = @("-sn", "-T4")
        if ($subnet -match "/(\d+)$") {
            $prefixLen = [int]$Matches[1]
            if ($prefixLen -le 24) {
                $nmapArgs += "--min-rate"
                $nmapArgs += "1000"
                Write-Log "Using --min-rate 1000 for large subnet" -Level INFO
            }
        }
        $nmapArgs += $subnet

        $result = & $nmapPath $nmapArgs 2>&1

        # Parse nmap output for IPs
        $hosts = $result | Select-String -Pattern "Nmap scan report for (\S+)" | ForEach-Object {
            $match = $_.Matches[0].Groups[1].Value
            # Extract IP if hostname is shown
            if ($match -match "\((\d+\.\d+\.\d+\.\d+)\)") {
                $Matches[1]
            } elseif ($match -match "^\d+\.\d+\.\d+\.\d+$") {
                $match
            }
        }

        $allHosts += $hosts
        Write-Log "Found $($hosts.Count) hosts in $subnet"
    }

    $uniqueHosts = $allHosts | Sort-Object -Unique
    Write-Log "Total unique hosts discovered: $($uniqueHosts.Count)" -Level SUCCESS

    return $uniqueHosts
}
#endregion

#region OpenVAS GMP API
function Get-OpenVASCredentials {
    $credFile = "$env:USERPROFILE\.openvas\credentials.txt"
    if (Test-Path $credFile) {
        $content = Get-Content $credFile -Raw
        if ($content -match "Password:\s*(\S+)") {
            return @{
                Username = "admin"
                Password = $Matches[1]
            }
        }
    }

    Write-Log "Could not find OpenVAS credentials" -Level ERROR
    return $null
}

function Invoke-GMP {
    param(
        [string]$Command,
        [hashtable]$Credentials
    )

    # Flatten XML to single line
    $flatXml = ($Command -replace "`r`n", "" -replace "`n", "" -replace "\s+", " ").Trim()

    # Execute via Start-Process to capture output properly
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "docker"
    $psi.Arguments = "exec -u gvm openvas gvm-cli --gmp-username $($Credentials.Username) --gmp-password $($Credentials.Password) tls --hostname 127.0.0.1 --port 9390 --xml `"$flatXml`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return $stdout
}

function New-OpenVASTarget {
    param(
        [string]$Name,
        [string[]]$Hosts,
        [hashtable]$Credentials
    )

    Write-Log "Creating OpenVAS target: $Name"

    $hostList = $Hosts -join ","

    # Get default port list ID (All TCP and Nmap top 100 UDP)
    $portListXml = Invoke-GMP -Command "<get_port_lists/>" -Credentials $Credentials
    $portListId = ""
    if ($portListXml -match 'port_list id="([^"]+)"[^>]*>.*?<name>All TCP and Nmap top 100 UDP</name>') {
        $portListId = $Matches[1]
    } else {
        # Fallback to first port list
        if ($portListXml -match 'port_list id="([^"]+)"') {
            $portListId = $Matches[1]
        }
    }

    $createCmd = @"
<create_target>
  <name>$Name</name>
  <hosts>$hostList</hosts>
  <port_list id='$portListId'/>
  <alive_tests>Consider Alive</alive_tests>
</create_target>
"@

    $result = Invoke-GMP -Command $createCmd -Credentials $Credentials

    if ($result -match 'status="201".*id="([a-f0-9-]+)"') {
        $targetId = $Matches[1]
        Write-Log "Target created: $targetId" -Level SUCCESS
        return $targetId
    }

    Write-Log "Failed to create target: $result" -Level ERROR
    return $null
}

function Get-ScanConfigId {
    param(
        [string]$ConfigName,
        [hashtable]$Credentials
    )

    $configsXml = Invoke-GMP -Command "<get_configs/>" -Credentials $Credentials

    $searchName = switch ($ConfigName) {
        "full_fast" { "Full and fast" }
        "full_deep" { "Full and very deep" }
        "discovery" { "Discovery" }
    }

    if ($configsXml -match "config id=`"([^`"]+)`"[^>]*>.*?<name>$searchName</name>") {
        return $Matches[1]
    }

    # Fallback
    if ($configsXml -match 'config id="([^"]+)"') {
        return $Matches[1]
    }

    return $null
}

function Get-ScannerId {
    param([hashtable]$Credentials)

    $scannersXml = Invoke-GMP -Command "<get_scanners/>" -Credentials $Credentials

    # Find scanner blocks and look for OpenVAS Default
    $allMatches = [regex]::Matches($scannersXml, '<scanner id="([^"]+)">.*?</scanner>')
    foreach ($m in $allMatches) {
        $block = $m.Value
        if ($block -match '<name>OpenVAS Default</name>') {
            if ($block -match '<scanner id="([^"]+)">') {
                return $Matches[1]
            }
        }
    }

    # Fallback: look for type 2 scanner (OSP/OpenVAS)
    foreach ($m in $allMatches) {
        $block = $m.Value
        if ($block -match '<type>2</type>') {
            if ($block -match '<scanner id="([^"]+)">') {
                return $Matches[1]
            }
        }
    }

    return $null
}

function New-OpenVASScan {
    param(
        [string]$Name,
        [string]$TargetId,
        [string]$ConfigName,
        [hashtable]$Credentials
    )

    Write-Log "Creating scan task: $Name"

    $configId = Get-ScanConfigId -ConfigName $ConfigName -Credentials $Credentials
    $scannerId = Get-ScannerId -Credentials $Credentials

    if (-not $configId -or -not $scannerId) {
        Write-Log "Could not get scan config or scanner ID" -Level ERROR
        return $null
    }

    $createCmd = @"
<create_task>
  <name>$Name</name>
  <target id='$TargetId'/>
  <config id='$configId'/>
  <scanner id='$scannerId'/>
</create_task>
"@

    $result = Invoke-GMP -Command $createCmd -Credentials $Credentials

    if ($result -match 'status="201".*id="([a-f0-9-]+)"') {
        $taskId = $Matches[1]
        Write-Log "Task created: $taskId" -Level SUCCESS
        return $taskId
    }

    Write-Log "Failed to create task: $result" -Level ERROR
    return $null
}

function Start-OpenVASScan {
    param(
        [string]$TaskId,
        [hashtable]$Credentials
    )

    Write-Log "Starting scan..."

    $result = Invoke-GMP -Command "<start_task task_id='$TaskId'/>" -Credentials $Credentials

    if ($result -match 'status="202"') {
        Write-Log "Scan started!" -Level SUCCESS
        return $true
    }

    Write-Log "Failed to start scan: $result" -Level ERROR
    return $false
}
#endregion

#region Main
function Main {
    Write-Log "========================================"
    Write-Log "OpenVAS Network Auto-Scanner"
    Write-Log "========================================"

    # Prerequisites
    if (-not (Test-OpenVAS)) { exit 1 }
    if (-not (Install-Nmap)) { exit 1 }

    # Get credentials
    $creds = Get-OpenVASCredentials
    if (-not $creds) { exit 1 }

    # Discover subnets
    $subnets = Get-LocalSubnets
    if ($subnets.Count -eq 0) {
        Write-Log "No subnets found to scan" -Level ERROR
        exit 1
    }

    Write-Log "Subnets to scan: $($subnets -join ', ')"

    # Discover hosts or use subnets directly
    if ($SkipDiscovery) {
        $hosts = $subnets
        Write-Log "Skipping discovery, will scan entire subnets"
    } else {
        $hosts = Find-LiveHosts -Subnets $subnets
        if ($hosts.Count -eq 0) {
            Write-Log "No live hosts found" -Level WARN
            $hosts = $subnets
        }
    }

    # Create target
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $targetName = "Auto-Discovery-$timestamp"
    $targetId = New-OpenVASTarget -Name $targetName -Hosts $hosts -Credentials $creds
    if (-not $targetId) { exit 1 }

    # Create and start scan
    $taskName = "Full-Network-Scan-$timestamp"
    $taskId = New-OpenVASScan -Name $taskName -TargetId $targetId -ConfigName $ScanConfig -Credentials $creds
    if (-not $taskId) { exit 1 }

    if (Start-OpenVASScan -TaskId $taskId -Credentials $creds) {
        Write-Log ""
        Write-Log "========================================"
        Write-Log "Scan Started Successfully!" -Level SUCCESS
        Write-Log "========================================"
        Write-Log ""
        Write-Log "Target: $targetName"
        Write-Log "Hosts: $($hosts.Count) targets"
        Write-Log "Scan Config: $ScanConfig"
        Write-Log ""
        Write-Log "Monitor progress at: http://localhost:9392"
        Write-Log "Go to: Scans -> Tasks -> $taskName"
    }
}

# Only run Main if not dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
    if ($GUI) {
        # Launch GUI from same directory
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $guiScript = Join-Path $scriptDir "scan-network-gui.ps1"

        if (Test-Path $guiScript) {
            Write-Log "Launching GUI..." -Level INFO
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guiScript
        } else {
            Write-Log "GUI script not found at: $guiScript" -Level ERROR
            exit 1
        }
    } else {
        Main
    }
}
#endregion
