# Cloud CLI Guard

**60-second safety cooldown for Azure and GitHub CLI destructive operations**

Protects against accidental deletion of resources, repositories, and production services by requiring Teams approval for dangerous commands.

## What It Does

- **Intercepts** `az` and `gh` commands before they execute
- **Blocks** dangerous operations (delete, purge, repo deletion, etc.)
- **Sends approval tokens** to Teams private channel (never shown in terminal)
- **60-second cooldown** gives you time to reconsider
- **Complete audit trail** logs all attempts

## Quick Install

```bash
# Run the installer
curl -fsSL https://your-domain.com/install-cloud-guard.sh | bash

# Or manually:
mkdir -p ~/.local/bin
cp cloud-cli-guard.sh ~/.local/bin/cloud-cli-guard
chmod +x ~/.local/bin/cloud-cli-guard

# Add to your shell config (Bash, Zsh, or Fish)
```

### Shell Setup

**Bash** (`~/.bashrc`):
```bash
az() { CLI_TYPE="az" ~/.local/bin/cloud-cli-guard "$@"; }
gh() { CLI_TYPE="gh" ~/.local/bin/cloud-cli-guard "$@"; }
```

**Zsh** (`~/.zshrc`):
```bash
az() { CLI_TYPE="az" ~/.local/bin/cloud-cli-guard "$@"; }
gh() { CLI_TYPE="gh" ~/.local/bin/cloud-cli-guard "$@"; }
```

**Fish** (`~/.config/fish/config.fish`):
```fish
function az
    env CLI_TYPE="az" ~/.local/bin/cloud-cli-guard $argv
end

function gh
    env CLI_TYPE="gh" ~/.local/bin/cloud-cli-guard $argv
end
```

Then reload: `source ~/.bashrc` (or `~/.zshrc`)

**PowerShell** (Windows):
```powershell
# Run the installer from the repo directory
.\Install-CloudGuard.ps1

# Reload profile
. $PROFILE
```

This installs a native PowerShell module that shadows `az` and `gh` commands. It shares the same config, audit log, and approval tokens with the bash version, so both shells see the same state.

## Protected Operations

### Azure CLI (🔴 Critical, 🟠 High, 🟡 Medium Risk)
```
🔴 az group delete              # Resource group deletion
🔴 az keyvault purge            # Permanent key vault deletion
🔴 az storage delete            # Storage account deletion
🟠 az vm stop/deallocate        # Production downtime
🟠 az containerapp stop         # Service interruption
🟡 az network nsg rule delete   # Could lock you out
```

### GitHub CLI (🔴 Critical, 🟠 High, 🟡 Medium Risk)
```
🔴 gh repo delete               # REPO GONE FOREVER
🔴 gh release delete            # Release + assets deleted
🔴 gh secret delete             # Credentials lost
🟠 gh pr merge --admin          # Force merge
🟠 gh pr/issue close            # State changes
🟡 gh repo edit                 # Settings changes
🟡 gh secret set                # Overwrites secrets
```

## How It Works

### Normal Commands (Instant)
```bash
az account list                 # ✅ Works immediately
az group list                   # ✅ Works immediately
gh repo list                    # ✅ Works immediately
gh pr view 123                  # ✅ Works immediately
```

### Blocked Commands (60s + Teams)
```bash
$ az group delete -n prod-rg

╔════════════════════════════════════════════════════════════════╗
║  💀 CRITICAL: Azure resource group deletion blocked            ║
╚════════════════════════════════════════════════════════════════╝

Command: az group delete -n prod-rg

This operation can cause IRREVERSIBLE data loss or service destruction.

To approve this operation:

  1. Wait 60s for the cooldown period
  2. Check your Teams private channel for the approval token
  3. Run: az --approve <token-from-teams>
```

### Approving a Command

1. Wait 60 seconds
2. Check Teams private channel for approval token
3. Run: `az --approve <token>` or `gh --approve <token>`

### Emergency Break Glass

Also requires Teams approval:

```bash
az --break-glass --enable       # Request (blocked, sends token)
az --approve <token>            # Approve
az --break-glass --enable       # Now enabled (1 hour)
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `az --guard-status` | Check Azure guard status |
| `gh --guard-status` | Check GitHub guard status |
| `az --guard-matrix` | Show all protected operations |
| `az --approve <token>` | Approve blocked Azure command |
| `gh --approve <token>` | Approve blocked GitHub command |
| `az --break-glass --enable` | Request emergency bypass |
| `az --break-glass --disable` | Disable emergency mode |

## Team Workflow

**Developers:**
1. Try command normally
2. If blocked, read the warning carefully
3. Wait 60s, verify target is correct
4. Check Teams for approval token
5. Run `az --approve <token>`

**Team Leads:**
- Monitor Teams channel for blocked operations
- Review audit log: `cat ~/.azure/az-guard-audit.log`
- Watch for patterns (frequent delete attempts?)

## Audit Trail

All operations logged to: `~/.azure/az-guard-audit.log`

```bash
# View recent blocks
tail ~/.azure/az-guard-audit.log

# View only Azure blocks
grep "az " ~/.azure/az-guard-audit.log | grep BLOCKED

# View only GitHub blocks
grep "gh " ~/.azure/az-guard-audit.log | grep BLOCKED
```

## Updating CLI Tools

Updates work normally - no reinstallation needed!

```bash
brew upgrade azure-cli gh      # macOS
apt upgrade azure-cli gh       # Ubuntu
```

The wrapper continues to work automatically.

## Uninstall

**Bash/Zsh/Fish:**
```bash
# Remove shell functions from ~/.bashrc or ~/.zshrc
rm ~/.local/bin/cloud-cli-guard
rm -rf ~/.azure/az-guard-*
```

**PowerShell:**
```powershell
# Remove Import-Module line from $PROFILE, then:
Remove-Item -Recurse "$HOME\Documents\PowerShell\Modules\CloudCliGuard"
```

## Security Notes

- **Tokens never shown in terminal** - Only sent to Teams
- **Break glass requires approval** - Can't bypass without visibility
- **Complete audit trail** - Every attempt logged
- **Survives CLI updates** - No binary modification
- **GitHub has no recovery** - Extra warnings for permanent deletions

## Support

- Full documentation: [CLOUD_CLI_GUARD_SETUP.md](CLOUD_CLI_GUARD_SETUP.md)
- Check status: `az --guard-status`
- View protection matrix: `az --guard-matrix`
