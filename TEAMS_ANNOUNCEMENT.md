# 🛡️ Cloud CLI Guard - Now Live for All Teams

Hey team! 

We've deployed a new safety system to protect against accidental deletions and production incidents when using Azure and GitHub CLI.

## What is it?

**Cloud CLI Guard** adds a 60-second safety cooldown to destructive operations. Before any delete, purge, or dangerous command runs, it:

1. ✅ **Blocks** the command
2. ✅ **Sends approval token** to this Teams channel
3. ✅ **Waits 60 seconds** for you to reconsider
4. ✅ **Requires token** from Teams to proceed (never shown in terminal)

## Why?

- Prevent accidental resource deletions
- Stop agents/LLMs from deleting things without approval
- Protect against typos (e.g., deleting `prod-rg` instead of `dev-rg`)
- Maintain audit trail of all dangerous operations

## What gets blocked?

### Azure CLI (🔴 CRITICAL)
- `az group delete` - Entire resource groups
- `az keyvault purge` - Permanent key vault deletion  
- `az vm stop/deallocate` - Production downtime
- `az storage delete` - Data loss
- All purge operations

### GitHub CLI (🔴 CRITICAL - No recovery!)
- `gh repo delete` - **REPO GONE FOREVER**
- `gh release delete` - Release + assets deleted
- `gh secret delete` - Credentials lost
- `gh pr merge --admin` - Force merge

Full list: Run `az --guard-matrix` or check the repo

## Installation

**One command:**
```bash
curl -fsSL https://raw.githubusercontent.com/pitcherco/cloud-cli-guard/main/install-cloud-guard.sh | bash
```

Then reload your shell:
```bash
source ~/.bashrc  # or ~/.zshrc
```

That's it! No manual config needed.

## How to use

### Normal commands (instant)
```bash
az account list           ✅ Works immediately
az group list             ✅ Works immediately
gh repo list              ✅ Works immediately
gh pr view 123            ✅ Works immediately
```

### Dangerous commands (blocked)
```bash
az group delete -n my-rg

╔════════════════════════════════════════════════════════════════╗
║  💀 CRITICAL: Azure resource group deletion blocked            ║
╚════════════════════════════════════════════════════════════════╝

To approve this operation:

  1. Wait 60s for the cooldown period
  2. Check your Teams private channel for the approval token
  3. Run: az --approve <token-from-teams>
```

**Check this channel** - you'll see a message with the approval token!

### Approving commands

1. Try your command (it gets blocked)
2. Wait 60 seconds
3. Look in this Teams channel for the token
4. Run: `az --approve <token>` or `gh --approve <token>`

### For AI/Agents

If an AI assistant hits a safety gate, it will see instructions to ask you for the token. Just check this channel, give them the token, they'll execute: `az --approve <token>`

## Emergency Break Glass

If you need to run multiple dangerous commands (e.g., cleanup, incident response):

```bash
az --break-glass --enable       # Request (blocked, sends token)
az --approve <token>            # Approve via Teams
az --break-glass --enable       # Now enabled for 1 hour

# Run your emergency commands...

az --break-glass --disable      # Disable when done
```

Break glass also requires Teams approval and auto-expires after 1 hour.

## Quick Reference

| Command | Purpose |
|---------|---------|
| `az --guard-matrix` | Show all protected operations |
| `az --guard-status` | Check status and recent blocks |
| `az --approve <token>` | Approve blocked Azure command |
| `gh --approve <token>` | Approve blocked GitHub command |
| `az --break-glass --enable` | Request emergency bypass |

## Repo & Docs

- **Repository:** https://github.com/pitcherco/cloud-cli-guard
- **Full docs:** See `CLOUD_CLI_GUARD_SETUP.md` in the repo
- **Install script:** `install-cloud-guard.sh`

## FAQ

**Q: Does this slow down my normal workflow?**
A: No! Only dangerous commands (delete, purge, etc.) are blocked. All read operations work instantly.

**Q: What if I need to delete something quickly?**
A: Break glass mode allows bypassing after Teams approval, or just wait 60s + grab the token from this channel.

**Q: Will this break my existing scripts?**
A: Only scripts that delete resources will be blocked. Non-destructive scripts work normally.

**Q: Can I see what's been blocked?**
A: Yes! Check the audit: `cat ~/.azure/az-guard-audit.log` or ask in this channel.

**Q: What about GitHub CLI updates?**
A: The guard survives `brew upgrade gh` - no reinstallation needed!

## Action Required

Please install this **this week**:

```bash
curl -fsSL https://raw.githubusercontent.com/pitcherco/cloud-cli-guard/main/install-cloud-guard.sh | bash
source ~/.bashrc  # or ~/.zshrc
```

Questions? Check the repo or ask in this channel!

Thanks,
Dustin

---
*Cloud CLI Guard - Protecting production, one 60-second cooldown at a time* ⏱️🛡️
