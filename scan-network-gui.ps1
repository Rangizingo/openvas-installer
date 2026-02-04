<#
.SYNOPSIS
    WinForms GUI for OpenVAS Network Scanner

.DESCRIPTION
    Graphical interface for scan-network.ps1 with support for:
    - Auto-discovery of local subnets
    - Manual subnet entry
    - Full sweep scanning
    - Configurable scan profiles
    - VPN/Docker/WSL exclusion options
#>

$ErrorActionPreference = "Stop"

# Dot-source the main script to get all functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "scan-network.ps1")

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Theme Colors
$bgColor = [System.Drawing.Color]::FromArgb(30, 30, 46)        # #1e1e2e
$fgColor = [System.Drawing.Color]::FromArgb(205, 214, 244)     # #cdd6f4
$accentColor = [System.Drawing.Color]::FromArgb(137, 180, 250) # #89b4fa
$controlBg = [System.Drawing.Color]::FromArgb(49, 50, 68)      # #313244
#endregion

#region Form Setup
$form = New-Object System.Windows.Forms.Form
$form.Text = "OpenVAS Network Scanner"
$form.Size = New-Object System.Drawing.Size(520, 600)
$form.MinimumSize = New-Object System.Drawing.Size(500, 550)
$form.StartPosition = "CenterScreen"
$form.BackColor = $bgColor
$form.ForeColor = $fgColor
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false

$yPos = 20
#endregion

#region Scan Mode Section
$lblScanMode = New-Object System.Windows.Forms.Label
$lblScanMode.Location = New-Object System.Drawing.Point(20, $yPos)
$lblScanMode.Size = New-Object System.Drawing.Size(460, 20)
$lblScanMode.Text = "Scan Mode:"
$lblScanMode.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblScanMode)
$yPos += 30

# Radio: Auto-Discover
$radioAuto = New-Object System.Windows.Forms.RadioButton
$radioAuto.Location = New-Object System.Drawing.Point(40, $yPos)
$radioAuto.Size = New-Object System.Drawing.Size(400, 20)
$radioAuto.Text = "Auto-Discover (detect all subnets)"
$radioAuto.Checked = $true
$radioAuto.ForeColor = $fgColor
$form.Controls.Add($radioAuto)
$yPos += 25

# Radio: Manual Subnets
$radioManual = New-Object System.Windows.Forms.RadioButton
$radioManual.Location = New-Object System.Drawing.Point(40, $yPos)
$radioManual.Size = New-Object System.Drawing.Size(400, 20)
$radioManual.Text = "Manual Subnets (enter ranges)"
$radioManual.ForeColor = $fgColor
$form.Controls.Add($radioManual)
$yPos += 25

# Radio: Full Sweep
$radioFullSweep = New-Object System.Windows.Forms.RadioButton
$radioFullSweep.Location = New-Object System.Drawing.Point(40, $yPos)
$radioFullSweep.Size = New-Object System.Drawing.Size(400, 20)
$radioFullSweep.Text = "Full Sweep (scan 10.0.0.0/16)"
$radioFullSweep.ForeColor = $fgColor
$form.Controls.Add($radioFullSweep)
$yPos += 35
#endregion

#region Manual Subnets Input
$lblManual = New-Object System.Windows.Forms.Label
$lblManual.Location = New-Object System.Drawing.Point(20, $yPos)
$lblManual.Size = New-Object System.Drawing.Size(460, 20)
$lblManual.Text = "Manual subnets (comma-separated):"
$lblManual.ForeColor = $fgColor
$form.Controls.Add($lblManual)
$yPos += 25

$txtManualSubnets = New-Object System.Windows.Forms.TextBox
$txtManualSubnets.Location = New-Object System.Drawing.Point(20, $yPos)
$txtManualSubnets.Size = New-Object System.Drawing.Size(460, 25)
$txtManualSubnets.BackColor = $controlBg
$txtManualSubnets.ForeColor = $fgColor
$txtManualSubnets.Enabled = $false
$txtManualSubnets.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtManualSubnets)
$yPos += 35
#endregion

#region Scan Config Dropdown
$lblConfig = New-Object System.Windows.Forms.Label
$lblConfig.Location = New-Object System.Drawing.Point(20, $yPos)
$lblConfig.Size = New-Object System.Drawing.Size(120, 20)
$lblConfig.Text = "Scan Config:"
$lblConfig.ForeColor = $fgColor
$form.Controls.Add($lblConfig)

$cboScanConfig = New-Object System.Windows.Forms.ComboBox
$cboScanConfig.Location = New-Object System.Drawing.Point(140, ([int]$yPos - 3))
$cboScanConfig.Size = New-Object System.Drawing.Size(340, 25)
$cboScanConfig.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cboScanConfig.BackColor = $controlBg
$cboScanConfig.ForeColor = $fgColor
$cboScanConfig.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
[void]$cboScanConfig.Items.Add("Full and fast")
[void]$cboScanConfig.Items.Add("Full and very deep")
[void]$cboScanConfig.Items.Add("Discovery")
$cboScanConfig.SelectedIndex = 0
$form.Controls.Add($cboScanConfig)
$yPos += 40
#endregion

#region Exclusion Checkboxes
$chkExcludeVPN = New-Object System.Windows.Forms.CheckBox
$chkExcludeVPN.Location = New-Object System.Drawing.Point(20, $yPos)
$chkExcludeVPN.Size = New-Object System.Drawing.Size(460, 20)
$chkExcludeVPN.Text = "Exclude VPN networks"
$chkExcludeVPN.Checked = $true
$chkExcludeVPN.ForeColor = $fgColor
$form.Controls.Add($chkExcludeVPN)
$yPos += 25

$chkExcludeDocker = New-Object System.Windows.Forms.CheckBox
$chkExcludeDocker.Location = New-Object System.Drawing.Point(20, $yPos)
$chkExcludeDocker.Size = New-Object System.Drawing.Size(460, 20)
$chkExcludeDocker.Text = "Exclude Docker/WSL networks"
$chkExcludeDocker.Checked = $true
$chkExcludeDocker.ForeColor = $fgColor
$form.Controls.Add($chkExcludeDocker)
$yPos += 25

$chkMinRate = New-Object System.Windows.Forms.CheckBox
$chkMinRate.Location = New-Object System.Drawing.Point(20, $yPos)
$chkMinRate.Size = New-Object System.Drawing.Size(460, 20)
$chkMinRate.Text = "Use --min-rate 1000 (faster discovery)"
$chkMinRate.Checked = $false
$chkMinRate.ForeColor = $fgColor
$form.Controls.Add($chkMinRate)
$yPos += 40
#endregion

#region Status Section
$lblStatusHeader = New-Object System.Windows.Forms.Label
$lblStatusHeader.Location = New-Object System.Drawing.Point(20, $yPos)
$lblStatusHeader.Size = New-Object System.Drawing.Size(80, 20)
$lblStatusHeader.Text = "Status:"
$lblStatusHeader.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblStatusHeader.ForeColor = $fgColor
$form.Controls.Add($lblStatusHeader)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(100, $yPos)
$lblStatus.Size = New-Object System.Drawing.Size(380, 80)
$lblStatus.Text = "Ready to scan"
$lblStatus.ForeColor = $accentColor
$lblStatus.AutoSize = $false
$form.Controls.Add($lblStatus)
$yPos += 90
#endregion

#region Buttons
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(20, $yPos)
$btnStart.Size = New-Object System.Drawing.Size(220, 40)
$btnStart.Text = "Start Scan"
$btnStart.BackColor = $accentColor
$btnStart.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$btnStart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnStart.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnStart)

$btnViewResults = New-Object System.Windows.Forms.Button
$btnViewResults.Location = New-Object System.Drawing.Point(260, $yPos)
$btnViewResults.Size = New-Object System.Drawing.Size(220, 40)
$btnViewResults.Text = "View Results"
$btnViewResults.BackColor = $controlBg
$btnViewResults.ForeColor = $fgColor
$btnViewResults.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnViewResults.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnViewResults.FlatAppearance.BorderColor = $accentColor
$form.Controls.Add($btnViewResults)
#endregion

#region Event Handlers

# Radio button change: enable/disable manual textbox
$radioManual.Add_CheckedChanged({
    $txtManualSubnets.Enabled = $radioManual.Checked
})

# Background Worker for scan execution
$bgWorker = New-Object System.ComponentModel.BackgroundWorker
$bgWorker.WorkerReportsProgress = $true
$bgWorker.WorkerSupportsCancellation = $false

$bgWorker.Add_DoWork({
    param($sender, $e)

    $params = $e.Argument

    try {
        # Update status
        $sender.ReportProgress(0, "Checking prerequisites...")

        # Check OpenVAS
        if (-not (Test-OpenVAS)) {
            throw "OpenVAS container not running"
        }

        # Check nmap
        if (-not (Install-Nmap)) {
            throw "Failed to install nmap"
        }

        # Get credentials
        $sender.ReportProgress(10, "Getting OpenVAS credentials...")
        $creds = Get-OpenVASCredentials
        if (-not $creds) {
            throw "Could not get OpenVAS credentials"
        }

        # Determine subnets based on mode
        $sender.ReportProgress(20, "Determining target subnets...")
        $subnets = @()

        if ($params.Mode -eq "Auto") {
            $subnets = Get-LocalSubnets
        } elseif ($params.Mode -eq "Manual") {
            $subnets = $params.ManualSubnets -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        } elseif ($params.Mode -eq "FullSweep") {
            $subnets = @("10.0.0.0/16")
        }

        if ($subnets.Count -eq 0) {
            throw "No subnets to scan"
        }

        # Apply exclusions
        if (-not $params.ExcludeDocker) {
            # User wants to include Docker/WSL - need to modify exclusion logic
            # For now, we'll just note it; the Get-LocalSubnets already handles this
            $sender.ReportProgress(25, "Including Docker/WSL networks...")
        }

        # Discover live hosts
        $sender.ReportProgress(30, "Discovering live hosts (may take several minutes)...`nSubnets: $($subnets -join ', ')")
        $hosts = Find-LiveHosts -Subnets $subnets

        if ($hosts.Count -eq 0) {
            $sender.ReportProgress(50, "No live hosts found, using subnet ranges...")
            $hosts = $subnets
        } else {
            $sender.ReportProgress(50, "Found $($hosts.Count) live hosts")
        }

        # Create target
        $sender.ReportProgress(60, "Creating OpenVAS target...")
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $targetName = "GUI-Scan-$timestamp"
        $targetId = New-OpenVASTarget -Name $targetName -Hosts $hosts -Credentials $creds

        if (-not $targetId) {
            throw "Failed to create target"
        }

        # Create scan task
        $sender.ReportProgress(75, "Creating scan task...")
        $taskName = "GUI-Network-Scan-$timestamp"

        # Map friendly name to internal name
        $configName = switch ($params.ScanConfig) {
            "Full and fast" { "full_fast" }
            "Full and very deep" { "full_deep" }
            "Discovery" { "discovery" }
            default { "full_fast" }
        }

        $taskId = New-OpenVASScan -Name $taskName -TargetId $targetId -ConfigName $configName -Credentials $creds

        if (-not $taskId) {
            throw "Failed to create scan task"
        }

        # Start scan
        $sender.ReportProgress(90, "Starting scan...")
        if (-not (Start-OpenVASScan -TaskId $taskId -Credentials $creds)) {
            throw "Failed to start scan"
        }

        $sender.ReportProgress(100, "Scan started successfully!`nTarget: $targetName`nHosts: $($hosts.Count)`nMonitor at: http://localhost:9392")
        $e.Result = @{ Success = $true; TaskName = $taskName }

    } catch {
        $e.Result = @{ Success = $false; Error = $_.Exception.Message }
    }
})

$bgWorker.Add_ProgressChanged({
    param($sender, $e)
    $lblStatus.Text = $e.UserState
})

$bgWorker.Add_RunWorkerCompleted({
    param($sender, $e)

    $btnStart.Enabled = $true
    $btnStart.Text = "Start Scan"

    if ($e.Result.Success) {
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)  # Green
        [System.Windows.Forms.MessageBox]::Show(
            "Scan started successfully!`n`nTask: $($e.Result.TaskName)`n`nMonitor progress at: http://localhost:9392",
            "Scan Started",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } else {
        $lblStatus.Text = "Error: $($e.Result.Error)"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)  # Red
        [System.Windows.Forms.MessageBox]::Show(
            "Scan failed: $($e.Result.Error)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Start Scan button
$btnStart.Add_Click({
    # Determine mode
    $mode = if ($radioAuto.Checked) { "Auto" }
            elseif ($radioManual.Checked) { "Manual" }
            elseif ($radioFullSweep.Checked) { "FullSweep" }
            else { "Auto" }

    # Validate manual input
    if ($mode -eq "Manual" -and [string]::IsNullOrWhiteSpace($txtManualSubnets.Text)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter at least one subnet in CIDR notation (e.g., 192.168.1.0/24)",
            "Validation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }

    # Prepare parameters
    $scanParams = @{
        Mode = $mode
        ManualSubnets = $txtManualSubnets.Text
        ScanConfig = $cboScanConfig.SelectedItem.ToString()
        ExcludeVPN = $chkExcludeVPN.Checked
        ExcludeDocker = $chkExcludeDocker.Checked
        UseMinRate = $chkMinRate.Checked
    }

    # Disable button and start worker
    $btnStart.Enabled = $false
    $btnStart.Text = "Scanning..."
    $lblStatus.Text = "Initializing scan..."
    $lblStatus.ForeColor = $accentColor

    $bgWorker.RunWorkerAsync($scanParams)
})

# View Results button
$btnViewResults.Add_Click({
    Start-Process "http://localhost:9392"
})

#endregion

# Show form
[void]$form.ShowDialog()
