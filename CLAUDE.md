# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Workflow Rules (CRITICAL)
- Always run /work command when making any changes, no matter how small
- Always create tasks using TaskCreate/TaskUpdate for tracking

## Project Overview

**openvas-installer** - One-stop PowerShell script to deploy OpenVAS (Greenbone Vulnerability Manager) on Windows machines.

## Purpose

Automate complete OpenVAS setup:
- Check/install prerequisites (Docker Desktop, WSL2, etc.)
- Deploy OpenVAS via Docker container
- Configure for first use
- Provide ready-to-scan environment

## Target Environment

- **OS:** Windows 10/11 only
- **Users:** IT department (1-5 machines)
- **Compliance:** PCI-DSS, SOC2

## Architecture

```
install-openvas.ps1          # OpenVAS Docker deployment
├── Prerequisites check (Docker, WSL2, Chocolatey)
├── Install missing components via Chocolatey
├── Pull OpenVAS Docker image
├── Configure container with default volumes
├── Start services
└── Display access credentials

scan-network.ps1             # Network auto-scanner (CLI + dot-sourceable)
├── Get-VPNAdapters          # Detects NordLynx, WireGuard, OpenVPN, etc.
├── Get-LocalSubnets         # Auto-discover subnets, exclude VPN/Docker/WSL
├── Find-LiveHosts           # nmap ping scan (--min-rate 1000 for large subnets)
├── Invoke-GMP               # GMP API via TLS on port 9390
├── New-OpenVASTarget        # Create scan target from discovered hosts
├── New-OpenVASScan          # Create scan task with config
└── Start-OpenVASScan        # Launch scan

scan-network-gui.ps1         # WinForms GUI (dot-sources scan-network.ps1)
├── Scan mode: Auto-Discover / Manual / Full Sweep
├── Config dropdown: Full and fast / Full and very deep / Discovery
├── Exclusion checkboxes: VPN, Docker/WSL, min-rate
├── BackgroundWorker for async scan execution
└── Dark theme (#1e1e2e background)
```

## Commands

```powershell
# Run installer (requires admin)
.\install-openvas.ps1

# Check status
.\install-openvas.ps1 -CheckOnly

# Uninstall
.\install-openvas.ps1 -Uninstall

# Network scanner (CLI)
.\scan-network.ps1
.\scan-network.ps1 -ExcludeSubnets "172.17.0.0/16" -ScanConfig full_deep

# Network scanner (GUI)
.\scan-network.ps1 -GUI
.\scan-network-gui.ps1
```

## Key Design Decisions

- **Chocolatey** for package management (not winget)
- **Default Docker volumes** for data persistence
- **Idempotent** - safe to run multiple times
- **Verbose logging** for IT troubleshooting

## Security Considerations

- Script requires admin elevation
- No hardcoded credentials
- Generated passwords stored securely
- Scan results may contain sensitive vulnerability data

## External Dependencies

- Docker Desktop
- WSL2 (Windows Subsystem for Linux)
- Chocolatey package manager
- Greenbone Community Container (Docker image: immauss/openvas)
- nmap (auto-installed via Chocolatey by scan-network.ps1)
