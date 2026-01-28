# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

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
install-openvas.ps1
├── Prerequisites check (Docker, WSL2, Chocolatey)
├── Install missing components via Chocolatey
├── Pull OpenVAS Docker image
├── Configure container with default volumes
├── Start services
└── Display access credentials
```

## Commands

```powershell
# Run installer (requires admin)
.\install-openvas.ps1

# Check status
.\install-openvas.ps1 -CheckOnly

# Uninstall
.\install-openvas.ps1 -Uninstall
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
- Greenbone Community Container (Docker image)
