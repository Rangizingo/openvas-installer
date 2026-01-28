# PROJECT_SCOPE.md - openvas-installer

## Overview
One-stop PowerShell script to deploy OpenVAS (Greenbone Vulnerability Manager) on Windows machines for IT department use.

## Current Work
**Active Task:** Complete
**Status:** All tasks finished
**Started:** 2026-01-28
**Notes:** Full script implemented with all features

---

## Phase 1: Core Prerequisites

### 1.1 Admin Elevation Check
- [ ] Detect if running as administrator
- [ ] Auto-elevate or prompt user
- **Location:** `install-openvas.ps1:1-20`
- **Verify:** Run without admin, confirm elevation prompt
- **Acceptance:** Script re-launches elevated or exits with clear message

### 1.2 Chocolatey Detection/Install
- [ ] Check if choco command available
- [ ] Install Chocolatey if missing
- [ ] Verify installation success
- **Location:** `install-openvas.ps1:25-60`
- **Verify:** Run on machine without Chocolatey
- **Acceptance:** Chocolatey installed and functional

### 1.3 WSL2 Detection/Install
- [ ] Check WSL version (`wsl --version`)
- [ ] Enable WSL feature if needed
- [ ] Install WSL2 kernel update
- [ ] Set WSL2 as default
- **Location:** `install-openvas.ps1:65-120`
- **Blocked by:** 1.2
- **Verify:** `wsl --version` shows version 2
- **Acceptance:** WSL2 enabled and default

### 1.4 Docker Desktop Detection/Install
- [ ] Check if Docker daemon running
- [ ] Install Docker Desktop via Chocolatey if missing
- [ ] Wait for Docker service to start
- [ ] Verify docker commands work
- **Location:** `install-openvas.ps1:125-180`
- **Blocked by:** 1.2, 1.3
- **Verify:** `docker ps` succeeds
- **Acceptance:** Docker Desktop running and responsive

---

## Phase 2: OpenVAS Deployment

### 2.1 Pull Greenbone Container
- [ ] Pull greenbone/community-container image
- [ ] Show download progress
- [ ] Handle timeout/retry for large image
- **Location:** `install-openvas.ps1:185-220`
- **Blocked by:** 1.4
- **Verify:** `docker images` shows greenbone image
- **Acceptance:** Image pulled successfully

### 2.2 Create Docker Compose Config
- [ ] Generate docker-compose.yml for OpenVAS
- [ ] Configure default volumes for persistence
- [ ] Set appropriate resource limits
- **Location:** `install-openvas.ps1:225-280`
- **Blocked by:** 2.1
- **Verify:** docker-compose.yml exists and valid
- **Acceptance:** Compose file generated with correct structure

### 2.3 Start OpenVAS Container
- [ ] Run docker-compose up -d
- [ ] Wait for services to initialize
- [ ] Check container health status
- **Location:** `install-openvas.ps1:285-340`
- **Blocked by:** 2.2
- **Verify:** `docker ps` shows running container
- **Acceptance:** Container running and healthy

### 2.4 Initial Feed Sync
- [ ] Trigger NVT/SCAP/CERT feed updates
- [ ] Show sync progress
- [ ] Wait for initial sync completion (can take 30+ min)
- **Location:** `install-openvas.ps1:345-400`
- **Blocked by:** 2.3
- **Verify:** Feed sync completes without error
- **Acceptance:** Vulnerability feeds populated

---

## Phase 3: Configuration & Output

### 3.1 Generate Admin Credentials
- [ ] Create secure random password
- [ ] Set admin user password
- [ ] Display credentials to user
- **Location:** `install-openvas.ps1:405-440`
- **Blocked by:** 2.3
- **Verify:** Can login with generated credentials
- **Acceptance:** Admin password set and displayed

### 3.2 Display Access Information
- [ ] Show web UI URL (https://localhost:9392)
- [ ] Show default credentials
- [ ] Provide first-scan quick start
- **Location:** `install-openvas.ps1:445-480`
- **Blocked by:** 3.1
- **Verify:** URL accessible in browser
- **Acceptance:** User can access OpenVAS web interface

### 3.3 Create Status Check Function
- [ ] `-CheckOnly` parameter support
- [ ] Show container status
- [ ] Show feed update status
- [ ] Show disk usage
- **Location:** `install-openvas.ps1:485-540`
- **Verify:** `.\install-openvas.ps1 -CheckOnly` shows status
- **Acceptance:** Status output accurate and readable

### 3.4 Create Uninstall Function
- [ ] `-Uninstall` parameter support
- [ ] Stop and remove containers
- [ ] Optionally remove volumes
- [ ] Clean up compose file
- **Location:** `install-openvas.ps1:545-600`
- **Verify:** `.\install-openvas.ps1 -Uninstall` cleans up
- **Acceptance:** All OpenVAS components removed

---

## Phase 4: Polish & Documentation

### 4.1 Error Handling
- [ ] Try/catch blocks for all operations
- [ ] Clear error messages
- [ ] Rollback on failure where possible
- **Location:** Throughout script
- **Blocked by:** Phase 3 complete
- **Verify:** Deliberately break steps, confirm graceful handling
- **Acceptance:** No cryptic errors, actionable messages

### 4.2 Logging
- [ ] Timestamped log output
- [ ] Optional log file (`-LogPath` parameter)
- [ ] Verbose mode for troubleshooting
- **Location:** Throughout script
- **Blocked by:** 4.1
- **Verify:** Run with `-LogPath`, check log file
- **Acceptance:** Complete operation log available

### 4.3 README Documentation
- [ ] Installation instructions
- [ ] Usage examples
- [ ] Troubleshooting section
- [ ] Compliance notes (PCI-DSS, SOC2)
- **Location:** `README.md`
- **Blocked by:** Phase 3 complete
- **Verify:** Follow README on fresh machine
- **Acceptance:** New user can install using only README

---

## Completed
<!-- Move completed task blocks here -->

---

## Technical Notes

- **Image:** greenbone/community-container (official Greenbone image)
- **Ports:** 9392 (web UI), 9390 (GMP API)
- **First sync:** 30-60 minutes for initial feed download
- **Disk space:** ~10GB for feeds and container
