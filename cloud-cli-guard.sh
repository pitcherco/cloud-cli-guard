#!/bin/bash
# Cloud CLI Guard - Safety Wrapper for Azure and GitHub CLI
# Prevents irreparable damage and severe production incidents
#
# BLOCKED CATEGORIES:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ AZURE CLI                                                                     │
# │ 🔴 CRITICAL - Permanent Data Loss / Service Destruction                      │
# │    • delete, purge (resources, resource groups, key vaults, storage)        │
# │    • keyvault delete/purge (secrets, keys, certificates - immediate loss)   │
# │    • storage delete (blob containers, tables - data loss)                   │
# │    • sql/db delete (database deletion)                                      │
# │                                                                              │
# │ 🟠 HIGH - Production Downtime / Severe Disruption                           │
# │    • vm stop/deallocate (takes production VMs offline)                      │
# │    • containerapp stop/restart (service interruption)                       │
# │    • aks stop/start (entire cluster down)                                   │
# │    • webapp restart/stop (web app offline)                                  │
# │                                                                              │
# │ 🟡 MEDIUM - Access Lockout / Configuration Break                            │
# │    • network nsg rule delete/update (could lock you out)                    │
# │    • network firewall rule delete/update (access blocked)                   │
# │    • network vnet delete (network isolation)                                │
# │                                                                              │
# ├─────────────────────────────────────────────────────────────────────────────┤
# │ GITHUB CLI                                                                    │
# │ 🔴 CRITICAL - Permanent Data Loss (No Recovery)                             │
# │    • repo delete (repository gone forever, no soft-delete)                  │
# │    • release delete (release + all assets permanently deleted)              │
# │    • secret delete (credentials lost immediately)                           │
# │    • variable delete (CI/CD config lost)                                    │
# │    • workflow delete (automation removed)                                   │
# │                                                                              │
# │ 🟠 HIGH - Repository State Changes (Hard to Undo)                           │
# │    • pr merge --admin (force merge, bypasses checks)                        │
# │    • pr close (can reopen, but loses momentum)                              │
# │    • issue close (can reopen, but context lost)                             │
# │    • api DELETE /repos/... (any API deletion)                               │
# │                                                                              │
# │ 🟡 MEDIUM - Permission/Access Changes                                       │
# │    • repo edit (default branch, visibility, merge settings)                 │
# │    • secret set (overwrites existing secrets)                               │
# │    • variable set (overwrites existing variables)                           │
# │    • ruleset delete (branch protection removed)                             │
# │                                                                              │
# ├─────────────────────────────────────────────────────────────────────────────┤
# │ ⚪ PASS-THROUGH - Safe Operations (No Approval Required)                    │
# │    • list, show, get, version, login, status                                │
# │    • create (new resources/repos - safe)                                    │
# │    • clone, fork (copies data)                                              │
# │    • view, browse (read-only)                                               │
# └─────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

# Configuration
REAL_AZ="/opt/homebrew/bin/az"   # Update: $(which -p az)
REAL_GH="/opt/homebrew/bin/gh"   # Update: $(which -p gh)
AUDIT_LOG="${HOME}/.azure/az-guard-audit.log"
APPROVAL_DIR="${HOME}/.azure/approvals"
CONFIG_FILE="${HOME}/.azure/az-guard-config"
COOLDOWN_SECONDS=60  # 60 seconds to reconsider

# Detect which CLI is being called
CLI_TYPE="${CLI_TYPE:-unknown}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ensure directories exist
mkdir -p "$APPROVAL_DIR" "$(dirname "$AUDIT_LOG")"

# Load or create config
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'EOFCONFIG'
# MS Teams webhook URL (via Power Automate)
TEAMS_WEBHOOK="https://default36e770efe6fd4f9d9acea949f98a0c.aa.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/4527f64f72e24bc2b90fb2f098ba2240/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=K-URAtv5RRv1Vgb1nfilk47q12ezv9lzsVm3ipQUPl8"

# Require approval for dangerous operations
REQUIRE_CONFIRM=true

# Cooldown in seconds (60 = 1 minute to reconsider)
COOLDOWN_SECONDS=60

# Break glass mode - auto-expires after 1 hour
BREAK_GLASS=false
BREAK_GLASS_EXPIRES=""
EOFCONFIG
fi

source "$CONFIG_FILE"

# Azure dangerous operations
# Format: "SEVERITY|DESCRIPTION|PATTERN"
declare -a AZ_BLOCKED_PATTERNS=(
    # 🔴 CRITICAL - Permanent Data Loss
    "CRITICAL|Azure resource group deletion|(^| )group delete "
    "CRITICAL|Azure resource deletion|(^| )(resource|vm|containerapp|webapp|functionapp|storage|sql|cosmosdb|redis|servicebus|eventhubs) delete "
    "CRITICAL|Azure Key Vault purge|(^| )keyvault purge"
    "CRITICAL|Azure Key Vault secret deletion|(^| )keyvault secret delete"
    "CRITICAL|Azure Key Vault key deletion|(^| )keyvault key delete"
    "CRITICAL|Azure Key Vault cert deletion|(^| )keyvault certificate delete"
    "CRITICAL|Azure storage container deletion|(^| )storage container delete"
    "CRITICAL|Azure SQL DB deletion|(^| )sql db delete"
    "CRITICAL|Azure permanent deletion|(^| )(.*) purge($| )"
    
    # 🟠 HIGH - Production Downtime
    "HIGH|Azure VM stop/deallocate|(^| )vm (stop|deallocate|restart) "
    "HIGH|Azure Container App stop|(^| )containerapp (stop|restart) "
    "HIGH|Azure AKS stop/start|(^| )aks (stop|start|restart) "
    "HIGH|Azure Web App stop|(^| )webapp (stop|restart) "
    "HIGH|Azure Function App stop|(^| )functionapp (stop|restart) "
    "HIGH|Azure App Service stop|(^| )appservice (stop|restart) "
    "HIGH|Azure service shutdown|(^| )(shutdown|power-off) "
    
    # 🟡 MEDIUM - Access Lockout
    "MEDIUM|Azure NSG rule change|(^| )network nsg rule (delete|update) "
    "MEDIUM|Azure firewall change|(^| )network firewall (delete|update) "
    "MEDIUM|Azure VNet deletion|(^| )network vnet delete "
    "MEDIUM|Azure Key Vault soft-delete disable|(^| )keyvault update.*enable-soft-delete false"
    "MEDIUM|Azure service principal break|(^| )ad sp (delete|credential reset) "
    "MEDIUM|Azure role assignment removal|(^| )role assignment delete "
    "MEDIUM|Azure policy deletion|(^| )policy (definition|assignment) delete "
    "MEDIUM|Azure backup policy deletion|(^| )backup policy delete "
)

# GitHub dangerous operations
# Format: "SEVERITY|DESCRIPTION|PATTERN"
declare -a GH_BLOCKED_PATTERNS=(
    # 🔴 CRITICAL - Permanent Data Loss (GitHub has no soft-delete!)
    "CRITICAL|GitHub repository deletion|(^| )repo delete "
    "CRITICAL|GitHub release deletion|(^| )release delete "
    "CRITICAL|GitHub secret deletion|(^| )secret delete "
    "CRITICAL|GitHub variable deletion|(^| )variable delete "
    "CRITICAL|GitHub workflow deletion|(^| )workflow delete "
    "CRITICAL|GitHub API deletion|(^| )api DELETE "
    "CRITICAL|GitHub codespace deletion|(^| )codespace delete "
    "CRITICAL|GitHub cache deletion|(^| )cache delete "
    "CRITICAL|GitHub deploy key deletion|(^| )repo deploy-key delete "
    
    # 🟠 HIGH - Repository State Changes
    "HIGH|GitHub PR force merge|(^| )pr merge.*--admin "
    "HIGH|GitHub PR deletion|(^| )pr delete "
    "HIGH|GitHub PR close|(^| )pr close "
    "HIGH|GitHub issue close|(^| )issue close "
    "HIGH|GitHub release edit publish|(^| )release edit.*--draft=false "
    "HIGH|GitHub collaborator removal|(^| )repo collaborator remove "
    "HIGH|GitHub environment deletion|(^| )repo environment delete "
    
    # 🟡 MEDIUM - Permission/Config Changes
    "MEDIUM|GitHub repo settings change|(^| )repo edit "
    "MEDIUM|GitHub secret overwrite|(^| )secret set "
    "MEDIUM|GitHub variable overwrite|(^| )variable set "
    "MEDIUM|GitHub ruleset deletion|(^| )ruleset delete "
    "MEDIUM|GitHub branch protection removal|(^| )branch-protection delete "
    "MEDIUM|GitHub label deletion|(^| )label delete "
    "MEDIUM|GitHub milestone deletion|(^| )milestone delete "
)

# Functions
log_audit() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1 | $2 | $(whoami)@$(hostname) | $3" >> "$AUDIT_LOG"
}

send_teams_notification() {
    local cli="$1"
    local severity="$2"
    local reason="$3"
    local command="$4"
    local token="$5"
    
    if [[ -z "$TEAMS_WEBHOOK" || "$TEAMS_WEBHOOK" == "" ]]; then
        return 0
    fi
    
    local color="FF0000"
    case "$severity" in
        "CRITICAL") color="8B0000" ;;
        "HIGH") color="FF6600" ;;
        "MEDIUM") color="FFCC00" ;;
    esac
    
    local emoji="🛑"
    case "$severity" in
        "CRITICAL") emoji="💀" ;;
        "HIGH") emoji="🔥" ;;
        "MEDIUM") emoji="⚠️" ;;
    esac
    
    local json_payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "summary": "Cloud Guard: $cli $severity Alert",
    "themeColor": "$color",
    "title": "$emoji Cloud Guard: $cli $severity Operation Blocked",
    "sections": [{
        "activityTitle": "$reason requires approval",
        "facts": [
            {"name": "CLI:", "value": "$cli"},
            {"name": "Severity:", "value": "$severity"},
            {"name": "User:", "value": "$(whoami)@$(hostname)"},
            {"name": "Command:", "value": "${command:0:350}"},
            {"name": "Cooldown:", "value": "${COOLDOWN_SECONDS}s"},
            {"name": "Approval Token:", "value": "$token"}
        ],
        "markdown": true
    }]
}
EOF
)
    curl -s -X POST -H "Content-Type: application/json" -d "$json_payload" "$TEAMS_WEBHOOK" > /dev/null 2>&1 || true
}

analyze_command() {
    local cli="$1"
    local args="$2"
    local result=""
    
    if [[ "$cli" == "az" ]]; then
        for pattern_def in "${AZ_BLOCKED_PATTERNS[@]}"; do
            IFS='|' read -r severity description pattern <<< "$pattern_def"
            if [[ "$args" =~ $pattern ]]; then
                result="$severity|$description"
                break
            fi
        done
    elif [[ "$cli" == "gh" ]]; then
        for pattern_def in "${GH_BLOCKED_PATTERNS[@]}"; do
            IFS='|' read -r severity description pattern <<< "$pattern_def"
            if [[ "$args" =~ $pattern ]]; then
                result="$severity|$description"
                break
            fi
        done
    fi
    
    echo "$result"
}

generate_approval_token() {
    openssl rand -hex 12 2>/dev/null || head -c 24 /dev/urandom | xxd -p | head -c 24
}

is_break_glass_active() {
    if [[ "$BREAK_GLASS" == "true" && -n "$BREAK_GLASS_EXPIRES" ]]; then
        local now=$(date +%s)
        local expires=$(date -j -f "%Y-%m-%d %H:%M:%S" "$BREAK_GLASS_EXPIRES" +%s 2>/dev/null || date -d "$BREAK_GLASS_EXPIRES" +%s 2>/dev/null || echo "0")
        if [[ "$now" -lt "$expires" ]]; then
            return 0
        else
            sed -i '' 's/BREAK_GLASS=true/BREAK_GLASS=false/' "$CONFIG_FILE" 2>/dev/null || \
            sed -i 's/BREAK_GLASS=true/BREAK_GLASS=false/' "$CONFIG_FILE" 2>/dev/null || true
            return 1
        fi
    fi
    return 1
}

show_protection_matrix() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    CLOUD CLI GUARD PROTECTION MATRIX                             ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║ AZURE CLI                                                                        ║${NC}"
    echo -e "${RED}║ 🔴 CRITICAL - Permanent Data Loss / Service Destruction                          ║${NC}"
    echo -e "${RED}║    • delete, purge (resources, resource groups, key vaults)                     ║${NC}"
    echo -e "${RED}║    • keyvault secret/key/cert delete (immediate permanent loss)                 ║${NC}"
    echo -e "${RED}║    • storage container/blob delete (data loss)                                  ║${NC}"
    echo -e "${RED}║    • sql/db delete (database destruction)                                       ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║ 🟠 HIGH - Production Downtime / Severe Disruption                                ║${NC}"
    echo -e "${YELLOW}║    • vm stop/deallocate/restart (production VMs offline)                        ║${NC}"
    echo -e "${YELLOW}║    • containerapp stop/restart (service interruption)                           ║${NC}"
    echo -e "${YELLOW}║    • aks stop/start/restart (entire cluster down)                               ║${NC}"
    echo -e "${YELLOW}║    • webapp/functionapp stop/restart (app offline)                              ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║ 🟡 MEDIUM - Access Lockout / Configuration Break                                 ║${NC}"
    echo -e "${YELLOW}║    • nsg rule delete/update (could lock you out of VMs)                         ║${NC}"
    echo -e "${YELLOW}║    • firewall delete/update (access blocked)                                    ║${NC}"
    echo -e "${YELLOW}║    • vnet deletion (network isolation)                                          ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║ GITHUB CLI                                                                       ║${NC}"
    echo -e "${RED}║ 🔴 CRITICAL - Permanent Data Loss (No Recovery)                                  ║${NC}"
    echo -e "${RED}║    • repo delete (repository gone forever)                                      ║${NC}"
    echo -e "${RED}║    • release delete (release + assets permanently deleted)                      ║${NC}"
    echo -e "${RED}║    • secret delete (credentials lost immediately)                               ║${NC}"
    echo -e "${RED}║    • workflow delete (automation removed)                                       ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║ 🟠 HIGH - Repository State Changes (Hard to Undo)                                ║${NC}"
    echo -e "${YELLOW}║    • pr merge --admin (force merge, bypasses checks)                            ║${NC}"
    echo -e "${YELLOW}║    • pr/issue close (can reopen, but loses context)                             ║${NC}"
    echo -e "${YELLOW}║    • api DELETE (any API deletion)                                              ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║ 🟡 MEDIUM - Permission/Config Changes                                            ║${NC}"
    echo -e "${YELLOW}║    • repo edit (default branch, visibility, settings)                           ║${NC}"
    echo -e "${YELLOW}║    • secret/variable set (overwrites existing)                                  ║${NC}"
    echo -e "${YELLOW}║    • ruleset delete (branch protection removed)                                 ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║ ⚪ PASS-THROUGH - Safe Operations (No Approval Required)                        ║${NC}"
    echo -e "${GREEN}║    • list, show, get, version, login, status, view, browse                      ║${NC}"
    echo -e "${GREEN}║    • create (new resources/repos - safe)                                        ║${NC}"
    echo -e "${GREEN}║    • clone, fork (copies data)                                                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Cooldown: ${COOLDOWN_SECONDS}s | Audit log: $AUDIT_LOG"
    echo ""
}

# Main logic
main() {
    local args="$*"
    
    # Detect which CLI we're wrapping
    local cli="$CLI_TYPE"
    local real_cli=""
    
    if [[ "$cli" == "az" ]]; then
        real_cli="$REAL_AZ"
    elif [[ "$cli" == "gh" ]]; then
        real_cli="$REAL_GH"
    else
        echo "ERROR: CLI_TYPE not set. This script should be called via shell function."
        exit 1
    fi
    
    # Pass through help and version
    if [[ "$args" =~ ^(--help|-h|--version|-v)$ ]]; then
        exec "$real_cli" "$@"
    fi
    
    # Show protection matrix
    if [[ "$1" == "--guard-matrix" ]]; then
        show_protection_matrix
        exit 0
    fi
    
    # Check for special commands
    if [[ "$1" == "--guard-status" ]]; then
        echo -e "${BLUE}Cloud CLI Guard Status${NC}"
        echo "====================="
        echo "CLI Type: $cli"
        echo "Real binary: $real_cli"
        echo "Audit log: $AUDIT_LOG"
        echo "Config file: $CONFIG_FILE"
        echo "Pending approvals: $(ls -1 $APPROVAL_DIR 2>/dev/null | wc -l)"
        echo "Break glass: $BREAK_GLASS"
        echo "Cooldown: ${COOLDOWN_SECONDS}s"
        echo ""
        echo "Recent blocked operations:"
        tail -10 "$AUDIT_LOG" 2>/dev/null | grep "BLOCKED" || echo "None"
        exit 0
    fi
    
    if [[ "$1" == "--break-glass" ]]; then
        shift
        if [[ "$1" == "--enable" ]]; then
            # Check if already approved
            local cmd_hash=$(echo "break-glass-enable" | shasum | cut -d' ' -f1)
            if [[ -f "$APPROVAL_DIR/${cmd_hash}" ]]; then
                local expires=$(date -v+1H "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "+1 hour" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "")
                sed -i '' "s/BREAK_GLASS=false/BREAK_GLASS=true/" "$CONFIG_FILE" 2>/dev/null || \
                sed -i 's/BREAK_GLASS=false/BREAK_GLASS=true/' "$CONFIG_FILE" 2>/dev/null || true
                sed -i '' "s|BREAK_GLASS_EXPIRES=.*|BREAK_GLASS_EXPIRES=\"$expires\"|" "$CONFIG_FILE" 2>/dev/null || \
                sed -i "s|BREAK_GLASS_EXPIRES=.*|BREAK_GLASS_EXPIRES=\"$expires\"|" "$CONFIG_FILE" 2>/dev/null || true
                rm -f "$APPROVAL_DIR/${cmd_hash}"
                echo -e "${RED}🔥 BREAK GLASS ENABLED for 1 hour${NC}"
                echo "   All safety checks bypassed. Audit trail still active."
                log_audit "BREAK_GLASS" "ENABLED" "Expires: $expires"
                exit 0
            fi
            
            # Need approval first
            local token=$(generate_approval_token)
            echo "break-glass-enable" > "$APPROVAL_DIR/$token"
            echo "break-glass-enable" > "$APPROVAL_DIR/${cmd_hash}"
            
            send_teams_notification "$cli" "CRITICAL" "Break Glass Mode Request" "$cli --break-glass --enable" "$token"
            log_audit "BLOCKED" "CRITICAL|$token" "break-glass-enable"
            
            echo ""
            echo -e "${RED}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║  💀 CRITICAL: Break Glass Mode Request Blocked                                 ║${NC}"
            echo -e "${RED}╚════════════════════════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "Command: ${YELLOW}$cli --break-glass --enable${NC}"
            echo ""
            echo -e "${RED}This will disable ALL safety checks for 1 hour.${NC}"
            echo -e "${RED}Any team member with the token could execute dangerous commands.${NC}"
            echo ""
            echo -e "${BLUE}To approve enabling break glass mode:${NC}"
            echo ""
            echo "  1. Wait ${COOLDOWN_SECONDS}s for the cooldown period"
            echo "  2. Check your Teams private channel for the approval token"
            echo "  3. Run: ${GREEN}$cli --approve <token-from-teams>${NC}"
            echo "  4. Then run: ${GREEN}$cli --break-glass --enable${NC} again"
            echo ""
            
            exit 1
            
        elif [[ "$1" == "--disable" ]]; then
            sed -i '' 's/BREAK_GLASS=true/BREAK_GLASS=false/' "$CONFIG_FILE" 2>/dev/null || \
            sed -i 's/BREAK_GLASS=true/BREAK_GLASS=false/' "$CONFIG_FILE" 2>/dev/null || true
            echo -e "${GREEN}✓ Break glass disabled${NC}"
            log_audit "BREAK_GLASS" "DISABLED" "Manual"
            exit 0
        fi
    fi
    
    if [[ "$1" == "--approve" ]]; then
        shift
        local token="$1"
        if [[ -f "$APPROVAL_DIR/$token" ]]; then
            local cmd=$(cat "$APPROVAL_DIR/$token")
            rm -f "$APPROVAL_DIR/$token" "$APPROVAL_DIR/$(echo "$cmd" | shasum | cut -d' ' -f1)" 2>/dev/null || true
            echo -e "${GREEN}✓ Executing approved command:${NC}"
            echo "   $cli $cmd"
            log_audit "APPROVED" "EXECUTED" "$cmd"
            eval "$real_cli $cmd"
            exit $?
        else
            echo -e "${RED}✗ Invalid or expired approval token${NC}"
            echo "   Token may have already been used or expired."
            exit 1
        fi
    fi
    
    # Check if break glass is active
    if is_break_glass_active; then
        echo -e "${RED}🔥 BREAK GLASS MODE ACTIVE - Running without safety checks${NC}"
        log_audit "BREAK_GLASS" "BYPASSED" "$args"
        exec "$real_cli" "$@"
    fi
    
    # Analyze the command
    local analysis=$(analyze_command "$cli" "$args")
    
    if [[ -n "$analysis" ]]; then
        IFS='|' read -r severity reason <<< "$analysis"
        
        # Check if already approved
        local cmd_hash=$(echo "$args" | shasum | cut -d' ' -f1)
        if [[ -f "$APPROVAL_DIR/${cmd_hash}" ]]; then
            echo -e "${YELLOW}⚠️  This command was previously approved but not executed.${NC}"
            echo "   Run: $cli --approve $cmd_hash"
            exit 1
        fi
        
        # Determine color based on severity
        local color="$RED"
        local emoji="🛑"
        case "$severity" in
            "CRITICAL") color="$RED"; emoji="💀" ;;
            "HIGH") color="$YELLOW"; emoji="🔥" ;;
            "MEDIUM") color="$YELLOW"; emoji="⚠️" ;;
        esac
        
        # Block and notify
        echo ""
        echo -e "${color}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${color}║  $emoji $severity: $reason blocked                                    ║${NC}"
        echo -e "${color}╚════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "Command: ${YELLOW}$cli $args${NC}"
        echo ""
        
        # Severity-specific messaging
        case "$severity" in
            "CRITICAL")
                echo -e "${RED}This operation can cause IRREVERSIBLE data loss or service destruction.${NC}"
                echo -e "${RED}Double-check you're targeting the correct resource.${NC}"
                if [[ "$cli" == "gh" ]]; then
                    echo -e "${RED}Note: GitHub deletions are PERMANENT and cannot be recovered.${NC}"
                fi
                ;;
            "HIGH")
                echo -e "${YELLOW}This operation will cause production downtime or severe service disruption.${NC}"
                if [[ "$cli" == "gh" ]]; then
                    echo -e "${YELLOW}Repository state changes may be difficult to undo.${NC}"
                fi
                ;;
            "MEDIUM")
                echo -e "${YELLOW}This operation could cause access lockout or break critical configuration.${NC}"
                ;;
        esac
        
        echo ""
        
        # Generate approval token
        local token=$(generate_approval_token)
        echo "$args" > "$APPROVAL_DIR/$token"
        echo "$cmd_hash" > "$APPROVAL_DIR/${cmd_hash}"
        
        # Notify team (includes token - not shown in terminal)
        send_teams_notification "$cli" "$severity" "$reason" "$cli $args" "$token"
        
        # Log
        log_audit "BLOCKED" "$severity|$token" "$args"
        
        # AI Agent Instruction
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🤖 AI AGENT INSTRUCTION                                                        ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}If you are an AI assistant or agent executing commands on behalf of a user:${NC}"
        echo ""
        echo "  1. STOP and do not proceed with this command"
        echo "  2. Ask the user to check their Teams private channel"
        echo "  3. The user will find the approval token there"
        echo "  4. Ask the user to provide you the token"
        echo "  5. Once received, execute: $cli --approve <token>"
        echo ""
        echo -e "${CYAN}Do not attempt to bypass this safety measure or guess the token.${NC}"
        echo ""
        
        echo -e "${BLUE}To approve this operation:${NC}"
        echo ""
        echo "  1. Wait ${COOLDOWN_SECONDS}s for the cooldown period"
        echo "  2. Check your Teams private channel for the approval token"
        echo "  3. Run: ${GREEN}$cli --approve <token-from-teams>${NC}"
        echo ""
        echo "  Emergency break glass (logs to audit trail):"
        echo "    ${YELLOW}$cli --break-glass --enable${NC}"
        echo "    Then retry your command"
        echo ""
        
        exit 1
    fi
    
    # Pass through to real CLI
    exec "$real_cli" "$@"
}

main "$@"
