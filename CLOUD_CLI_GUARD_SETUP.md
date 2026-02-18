# Cloud CLI Guard - Setup Guide

## Overview

Safety wrapper for **Azure CLI** and **GitHub CLI** that prevents **irreparable damage** with a **60-second cooldown** and **Teams-only approval tokens**.

## How It Works

- **Single script** (`cloud-cli-guard.sh`) handles both Azure and GitHub
- **Shell functions** intercept `az` and `gh` commands
- **Security tokens** sent ONLY to Teams (never shown in terminal)
- **Break-glass mode** also requires Teams approval
- **Survives CLI updates** - real binaries never modified

## Protection Matrix

### Azure CLI

```
🔴 CRITICAL - Permanent Data Loss (60s + Teams approval)
   • delete, purge (resources, resource groups, key vaults)
   • keyvault secret/key/cert delete
   • storage container deletion
   • sql/db delete

🟠 HIGH - Production Downtime (60s + Teams approval)
   • vm stop/deallocate/restart
   • containerapp stop/restart
   • aks stop/start/restart
   • webapp/functionapp stop/restart

🟡 MEDIUM - Access Lockout (60s + Teams approval)
   • nsg rule delete/update
   • firewall delete/update
   • vnet deletion
```

### GitHub CLI

```
🔴 CRITICAL - Permanent Data Loss (60s + Teams approval)
   • repo delete (NO RECOVERY - gone forever)
   • release delete (release + all assets)
   • secret delete (credentials lost)
   • variable delete (CI/CD config lost)
   • workflow delete (automation removed)

🟠 HIGH - Repository State Changes (60s + Teams approval)
   • pr merge --admin (force merge, bypasses checks)
   • pr/issue close (can reopen, context lost)
   • api DELETE (any API deletion)

🟡 MEDIUM - Permission/Config Changes (60s + Teams approval)
   • repo edit (default branch, visibility, settings)
   • secret/variable set (overwrites existing)
   • ruleset delete (branch protection removed)
```

## Installation

### Prerequisites

- Azure CLI installed (`az`)
- GitHub CLI installed (`gh`)
- `~/.local/bin` directory
- Bash, Zsh, or Fish shell

### Step 1: Install the Guard Script

```bash
# Create user bin directory
mkdir -p ~/.local/bin

# Copy the guard script
cp /path/to/cloud-cli-guard.sh ~/.local/bin/cloud-cli-guard
chmod +x ~/.local/bin/cloud-cli-guard

# Verify it's in place
ls -la ~/.local/bin/cloud-cli-guard
```

### Step 2: Configure CLI Paths

Edit `~/.local/bin/cloud-cli-guard` and update lines 42-43:

```bash
# Find your CLI installations
which az    # e.g., /opt/homebrew/bin/az
which gh    # e.g., /opt/homebrew/bin/gh

# Update in the script:
REAL_AZ="/opt/homebrew/bin/az"   # Change to match your system
REAL_GH="/opt/homebrew/bin/gh"   # Change to match your system
```

### Step 3: Add Shell Functions

Choose your shell:

#### Bash (~/.bashrc)

```bash
cat >> ~/.bashrc << 'EOF'

# Cloud CLI Guard - Safety Wrappers
# Intercepts dangerous Azure and GitHub operations
az() {
    CLI_TYPE="az" ~/.local/bin/cloud-cli-guard "$@"
}

gh() {
    CLI_TYPE="gh" ~/.local/bin/cloud-cli-guard "$@"
}
EOF
```

#### Zsh (~/.zshrc)

```bash
cat >> ~/.zshrc << 'EOF'

# Cloud CLI Guard - Safety Wrappers
# Intercepts dangerous Azure and GitHub operations
az() {
    CLI_TYPE="az" ~/.local/bin/cloud-cli-guard "$@"
}

gh() {
    CLI_TYPE="gh" ~/.local/bin/cloud-cli-guard "$@"
}
EOF
```

#### Fish (~/.config/fish/config.fish)

```bash
cat >> ~/.config/fish/config.fish << 'EOF'

# Cloud CLI Guard - Safety Wrappers
function az
    env CLI_TYPE="az" ~/.local/bin/cloud-cli-guard $argv
end

function gh
    env CLI_TYPE="gh" ~/.local/bin/cloud-cli-guard $argv
end
EOF
```

### Step 4: Reload Shell Configuration

```bash
# Bash
source ~/.bashrc

# Zsh
source ~/.zshrc

# Fish
source ~/.config/fish/config.fish
```

### Step 5: Verify Installation

```bash
# Check which commands are using the wrapper
type az
type gh

# Check guard status for Azure
az --guard-status

# Check guard status for GitHub
gh --guard-status
```

Expected output:
```
Cloud CLI Guard Status
=====================
CLI Type: az
Real binary: /opt/homebrew/bin/az
...

Cloud CLI Guard Status
=====================
CLI Type: gh
Real binary: /opt/homebrew/bin/gh
...
```

## Updating CLI Tools

**Good news:** Updates work normally!

```bash
# Update Azure CLI
brew upgrade azure-cli

# Update GitHub CLI
brew upgrade gh

# Or your package manager
apt upgrade azure-cli gh    # Ubuntu/Debian
yum update azure-cli gh     # RHEL/CentOS

# The wrappers continue to work automatically!
```

**Note:** If CLIs move to new locations, update `REAL_AZ` and `REAL_GH` in `~/.local/bin/cloud-cli-guard`.

## Usage

### Normal Operations (no delay)

```bash
# Azure - instant
az account list
az group list
az vm create -n my-vm -g my-rg --image UbuntuLTS

# GitHub - instant
gh repo list
gh pr list
gh repo clone owner/repo
gh issue view 123
```

### Blocked Operations (60s cooldown + Teams approval)

**Azure example:**
```bash
az group delete -n production-rg

# Output:
# ╔════════════════════════════════════════════════════════════════╗
# ║  💀 CRITICAL: Azure resource group deletion blocked            ║
# ╚════════════════════════════════════════════════════════════════╝
#
# Command: az group delete -n production-rg
#
# This operation can cause IRREVERSIBLE data loss or service destruction.
#
# To approve:
#   1. Wait 60s
#   2. Check Teams private channel for token
#   3. Run: az --approve <token-from-teams>
```

**GitHub example:**
```bash
gh repo delete my-important-repo

# Output:
# ╔════════════════════════════════════════════════════════════════╗
# ║  💀 CRITICAL: GitHub repository deletion blocked               ║
# ╚════════════════════════════════════════════════════════════════╝
#
# Command: gh repo delete my-important-repo
#
# This operation can cause IRREVERSIBLE data loss or service destruction.
# Note: GitHub deletions are PERMANENT and cannot be recovered.
#
# To approve:
#   1. Wait 60s
#   2. Check Teams private channel for token
#   3. Run: gh --approve <token-from-teams>
```

### Approving Commands

1. Wait 60 seconds (cooldown period)
2. Check your Teams private channel for the approval token
3. Run approval with token:

```bash
# Azure
az --approve a1b2c3d4e5f6

# GitHub
gh --approve a1b2c3d4e5f6
```

### Emergency Break Glass

Break glass also requires Teams approval:

```bash
# Request break glass (blocked, sends token to Teams)
az --break-glass --enable

# Wait 60s, check Teams for token
az --approve <token>

# Now enable break glass
az --break-glass --enable
# 🔥 BREAK GLASS ENABLED for 1 hour

# Or for GitHub:
gh --break-glass --enable
# ...same process...

# Disable when done (no approval needed)
az --break-glass --disable
gh --break-glass --disable
```

### View Protection Matrix

```bash
# Shows both Azure and GitHub protection rules
az --guard-matrix
# or
gh --guard-matrix
```

### Check Status

```bash
az --guard-status
gh --guard-status
```

## Commands Reference

| Command | Works With | Description |
|---------|-----------|-------------|
| `az --guard-matrix` | Azure | Show protection matrix |
| `gh --guard-matrix` | GitHub | Show protection matrix |
| `az --guard-status` | Azure | Check status and recent blocks |
| `gh --guard-status` | GitHub | Check status and recent blocks |
| `az --approve <token>` | Azure | Approve blocked operation |
| `gh --approve <token>` | GitHub | Approve blocked operation |
| `az --break-glass --enable` | Azure | Request break glass (needs approval) |
| `gh --break-glass --enable` | GitHub | Request break glass (needs approval) |
| `az --break-glass --disable` | Azure | Disable break glass (instant) |
| `gh --break-glass --disable` | GitHub | Disable break glass (instant) |

## Team Workflow

### For Developers

1. Try your command normally
2. If blocked, review the output carefully
3. Wait 60 seconds (grab coffee, verify target)
4. Check Teams private channel for approval token
5. Run `az --approve <token>` or `gh --approve <token>`

### For Team Leads

1. Monitor Teams channel for blocked operations
2. Review audit logs:
   ```bash
   cat ~/.azure/az-guard-audit.log
   ```
3. Spot patterns - are people trying to delete things frequently?

### For Emergencies

```bash
# Request break glass mode
az --break-glass --enable

# Check Teams for token, approve
az --approve <token>

# Enable break glass
az --break-glass --enable

# Run emergency commands...

# Disable when done
az --break-glass --disable
```

## Audit Log

```bash
# View all activity
cat ~/.azure/az-guard-audit.log

# Azure only
grep "^20.*|.*|.*|.*|.*az " ~/.azure/az-guard-audit.log

# GitHub only
grep "^20.*|.*|.*|.*|.*gh " ~/.azure/az-guard-audit.log

# Blocked operations
grep "BLOCKED" ~/.azure/az-guard-audit.log

# Break glass usage
grep "BREAK_GLASS" ~/.azure/az-guard-audit.log
```

## Uninstall

```bash
# Remove shell functions from your config
# Edit ~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish
# Delete the az() and gh() functions

# Remove the wrapper script
rm ~/.local/bin/cloud-cli-guard

# Remove config and logs (optional)
rm -rf ~/.azure/az-guard-*

# Reload shell
source ~/.bashrc  # or ~/.zshrc
```

## Troubleshooting

### "command not found"

Ensure `~/.local/bin` is in PATH:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"
```

### "Real CLI not found"

Update paths in `~/.local/bin/cloud-cli-guard`:

```bash
# Find your installations
which az
which gh

# Update the script (lines 42-43)
REAL_AZ="/your/path/to/az"
REAL_GH="/your/path/to/gh"
```

### Teams notifications not working

1. Verify webhook URL in `~/.azure/az-guard-config`
2. Test webhook:
   ```bash
   curl -X POST -H "Content-Type: application/json" \
     -d '{"text":"Test"}' \
     "YOUR_WEBHOOK_URL"
   ```
3. Ensure `curl` is installed

### Approval tokens expire

Tokens are single-use and expire after 24 hours. If expired, run the original command again to generate a new token.

### Only one CLI working

Check that both functions are defined:

```bash
type az
type gh
```

Both should show they're using `cloud-cli-guard` with their respective `CLI_TYPE`.

## Security Features

1. **Tokens never shown in terminal** - Only sent to Teams
2. **Break glass requires approval** - Can't bypass without visibility
3. **Complete audit trail** - All operations logged
4. **Token expiration** - 24-hour expiry on approval tokens
5. **Break glass auto-expires** - 1 hour max even when enabled
6. **Survives CLI updates** - No binary modification
7. **GitHub has no recovery** - Extra warnings for permanent deletions

## Updating the Guard

To update the guard script:

```bash
# Copy new version
cp /path/to/new-cloud-cli-guard.sh ~/.local/bin/cloud-cli-guard
chmod +x ~/.local/bin/cloud-cli-guard

# Keep your REAL_AZ and REAL_GH settings
```

## Quick Setup Script

For team members, create this setup script:

```bash
#!/bin/bash
# save as setup-cloud-guard.sh

mkdir -p ~/.local/bin
mkdir -p ~/.azure/approvals

cp cloud-cli-guard.sh ~/.local/bin/cloud-cli-guard
chmod +x ~/.local/bin/cloud-cli-guard

# Find and update CLI paths
AZ_PATH=$(which az)
GH_PATH=$(which gh)
sed -i "s|REAL_AZ=.*|REAL_AZ=\"$AZ_PATH\"|" ~/.local/bin/cloud-cli-guard
sed -i "s|REAL_GH=.*|REAL_GH=\"$GH_PATH\"|" ~/.local/bin/cloud-cli-guard

# Add to shell config
echo '
# Cloud CLI Guard
az() { CLI_TYPE="az" ~/.local/bin/cloud-cli-guard "$@"; }
gh() { CLI_TYPE="gh" ~/.local/bin/cloud-cli-guard "$@"; }
' >> ~/.bashrc

echo "Setup complete! Run: source ~/.bashrc"
```

## Questions?

View protection matrix:
```bash
az --guard-matrix
```

Check recent activity:
```bash
az --guard-status
gh --guard-status
```

View audit log:
```bash
cat ~/.azure/az-guard-audit.log
```
