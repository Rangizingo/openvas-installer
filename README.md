# OpenVAS Installer for Windows

One-click PowerShell script to deploy OpenVAS (Greenbone Vulnerability Manager) on Windows machines.

## Features

- **Automatic prerequisites**: Installs Chocolatey, WSL2, and Docker Desktop if missing
- **Container deployment**: Uses official Greenbone Community Container
- **Idempotent**: Safe to run multiple times
- **Status check**: View container health and resource usage
- **Clean uninstall**: Remove all components with optional data deletion

## Requirements

- Windows 10 (version 2004+) or Windows 11
- Administrator privileges
- 8GB+ RAM recommended
- 15GB+ free disk space

## Quick Start

```powershell
# Download and run (requires admin)
.\install-openvas.ps1
```

The script will:
1. Install Chocolatey (if missing)
2. Enable WSL2 (may require restart)
3. Install Docker Desktop (if missing)
4. Pull and configure OpenVAS container
5. Display login credentials

## Usage

### Full Installation
```powershell
.\install-openvas.ps1
```

### Check Status
```powershell
.\install-openvas.ps1 -CheckOnly
```

### Uninstall
```powershell
.\install-openvas.ps1 -Uninstall
```

### With Logging
```powershell
.\install-openvas.ps1 -LogPath "C:\logs\openvas-install.log"
```

## After Installation

1. Open http://localhost:9392 in your browser
2. Accept the self-signed certificate warning
3. Login with credentials displayed at end of install
4. **Change the admin password immediately**

### Initial Feed Sync

The vulnerability feeds (NVT, SCAP, CERT) sync automatically but take **30-60 minutes** to complete. Until sync finishes, scans will have limited detection capability.

Check feed status in the web UI: Administration → Feed Status

## Troubleshooting

### Docker won't start
- Ensure Hyper-V and WSL2 are enabled
- Try restarting after WSL2 installation
- Check Windows Features for "Virtual Machine Platform"

### Container unhealthy
```powershell
# View logs
docker logs openvas

# Restart container
docker restart openvas
```

### Port already in use
```powershell
# Find process using port 9392
netstat -ano | findstr 9392
```

### Not enough memory
The container requires ~4GB RAM minimum. Increase Docker Desktop memory limits:
Docker Desktop → Settings → Resources → Memory

## File Locations

| File | Location |
|------|----------|
| Docker Compose | `%USERPROFILE%\.openvas\docker-compose.yml` |
| Credentials | `%USERPROFILE%\.openvas\credentials.txt` |
| Container data | Docker volumes: `openvas_data`, `openvas_logs` |

## Compliance Notes

### PCI-DSS
- OpenVAS can be used for internal vulnerability scanning requirements (11.2.1)
- Ensure scans are performed quarterly at minimum
- Document remediation of critical/high findings

### SOC2
- Regular vulnerability scanning supports CC7.1 (Security Operations)
- Maintain scan logs and remediation evidence
- Configure alerts for new critical vulnerabilities

## Security Considerations

- Default credentials are randomly generated
- Credentials are stored locally in plaintext - secure the file
- Web UI uses self-signed HTTPS certificate
- Container runs with limited privileges
- Scan results may contain sensitive vulnerability data

## Updating

```powershell
# Pull latest container image
docker pull greenbone/community-container

# Restart to apply
docker restart openvas
```

## License

MIT License - See LICENSE file
