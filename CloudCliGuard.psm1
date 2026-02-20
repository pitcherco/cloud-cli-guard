# Cloud CLI Guard - PowerShell Module
# Safety wrapper for Azure CLI (az) and GitHub CLI (gh)
# Shares config, audit log, and approvals with the bash implementation

$script:AzureDir = Join-Path $HOME '.azure'
$script:AuditLog = Join-Path $script:AzureDir 'az-guard-audit.log'
$script:ApprovalDir = Join-Path $script:AzureDir 'approvals'
$script:ConfigFile = Join-Path $script:AzureDir 'az-guard-config'
$script:DefaultCooldown = 60

$script:DefaultConfigContent = @'
# MS Teams webhook URL (via Power Automate)
TEAMS_WEBHOOK="https://default36e770efe6fd4f9d9acea949f98a0c.aa.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/4527f64f72e24bc2b90fb2f098ba2240/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=K-URAtv5RRv1Vgb1nfilk47q12ezv9lzsVm3ipQUPl8"

# Require approval for dangerous operations
REQUIRE_CONFIRM=true

# Cooldown in seconds (60 = 1 minute to reconsider)
COOLDOWN_SECONDS=60

# Break glass mode - auto-expires after 1 hour
BREAK_GLASS=false
BREAK_GLASS_EXPIRES=""
'@

# --- Pattern definitions (identical to cloud-cli-guard.sh) ---

$script:AzBlockedPatterns = @(
    # CRITICAL - Permanent Data Loss
    @{ Severity = 'CRITICAL'; Description = 'Azure resource group deletion';       Pattern = '(^| )group delete ' }
    @{ Severity = 'CRITICAL'; Description = 'Azure resource deletion';             Pattern = '(^| )(resource|vm|containerapp|webapp|functionapp|storage|sql|cosmosdb|redis|servicebus|eventhubs) delete ' }
    @{ Severity = 'CRITICAL'; Description = 'Azure Key Vault purge';               Pattern = '(^| )keyvault purge' }
    @{ Severity = 'CRITICAL'; Description = 'Azure Key Vault secret deletion';     Pattern = '(^| )keyvault secret delete' }
    @{ Severity = 'CRITICAL'; Description = 'Azure Key Vault key deletion';        Pattern = '(^| )keyvault key delete' }
    @{ Severity = 'CRITICAL'; Description = 'Azure Key Vault cert deletion';       Pattern = '(^| )keyvault certificate delete' }
    @{ Severity = 'CRITICAL'; Description = 'Azure storage container deletion';    Pattern = '(^| )storage container delete' }
    @{ Severity = 'CRITICAL'; Description = 'Azure SQL DB deletion';               Pattern = '(^| )sql db delete' }
    @{ Severity = 'CRITICAL'; Description = 'Azure permanent deletion';            Pattern = '(^| )(.*) purge($| )' }
    # HIGH - Production Downtime
    @{ Severity = 'HIGH'; Description = 'Azure VM stop/deallocate';       Pattern = '(^| )vm (stop|deallocate|restart) ' }
    @{ Severity = 'HIGH'; Description = 'Azure Container App stop';      Pattern = '(^| )containerapp (stop|restart) ' }
    @{ Severity = 'HIGH'; Description = 'Azure AKS stop/start';          Pattern = '(^| )aks (stop|start|restart) ' }
    @{ Severity = 'HIGH'; Description = 'Azure Web App stop';            Pattern = '(^| )webapp (stop|restart) ' }
    @{ Severity = 'HIGH'; Description = 'Azure Function App stop';       Pattern = '(^| )functionapp (stop|restart) ' }
    @{ Severity = 'HIGH'; Description = 'Azure App Service stop';        Pattern = '(^| )appservice (stop|restart) ' }
    @{ Severity = 'HIGH'; Description = 'Azure service shutdown';        Pattern = '(^| )(shutdown|power-off) ' }
    # MEDIUM - Access Lockout
    @{ Severity = 'MEDIUM'; Description = 'Azure NSG rule change';              Pattern = '(^| )network nsg rule (delete|update) ' }
    @{ Severity = 'MEDIUM'; Description = 'Azure firewall change';              Pattern = '(^| )network firewall (delete|update) ' }
    @{ Severity = 'MEDIUM'; Description = 'Azure VNet deletion';                Pattern = '(^| )network vnet delete ' }
    @{ Severity = 'MEDIUM'; Description = 'Azure Key Vault soft-delete disable'; Pattern = '(^| )keyvault update.*enable-soft-delete false' }
    @{ Severity = 'MEDIUM'; Description = 'Azure service principal break';      Pattern = '(^| )ad sp (delete|credential reset) ' }
    @{ Severity = 'MEDIUM'; Description = 'Azure role assignment removal';      Pattern = '(^| )role assignment delete ' }
    @{ Severity = 'MEDIUM'; Description = 'Azure policy deletion';              Pattern = '(^| )policy (definition|assignment) delete ' }
    @{ Severity = 'MEDIUM'; Description = 'Azure backup policy deletion';       Pattern = '(^| )backup policy delete ' }
)

$script:GhBlockedPatterns = @(
    # CRITICAL - Permanent Data Loss
    @{ Severity = 'CRITICAL'; Description = 'GitHub repository deletion';   Pattern = '(^| )repo delete ' }
    @{ Severity = 'CRITICAL'; Description = 'GitHub release deletion';      Pattern = '(^| )release delete ' }
    @{ Severity = 'CRITICAL'; Description = 'GitHub secret deletion';       Pattern = '(^| )secret delete ' }
    @{ Severity = 'CRITICAL'; Description = 'GitHub variable deletion';     Pattern = '(^| )variable delete ' }
    @{ Severity = 'CRITICAL'; Description = 'GitHub workflow deletion';     Pattern = '(^| )workflow delete ' }
    @{ Severity = 'CRITICAL'; Description = 'GitHub API deletion';          Pattern = '(^| )api DELETE ' }
    @{ Severity = 'CRITICAL'; Description = 'GitHub codespace deletion';    Pattern = '(^| )codespace delete ' }
    @{ Severity = 'CRITICAL'; Description = 'GitHub cache deletion';        Pattern = '(^| )cache delete ' }
    @{ Severity = 'CRITICAL'; Description = 'GitHub deploy key deletion';   Pattern = '(^| )repo deploy-key delete ' }
    # HIGH - Repository State Changes
    @{ Severity = 'HIGH'; Description = 'GitHub PR force merge';        Pattern = '(^| )pr merge.*--admin ' }
    @{ Severity = 'HIGH'; Description = 'GitHub PR deletion';           Pattern = '(^| )pr delete ' }
    @{ Severity = 'HIGH'; Description = 'GitHub PR close';              Pattern = '(^| )pr close ' }
    @{ Severity = 'HIGH'; Description = 'GitHub issue close';           Pattern = '(^| )issue close ' }
    @{ Severity = 'HIGH'; Description = 'GitHub release edit publish';  Pattern = '(^| )release edit.*--draft=false ' }
    @{ Severity = 'HIGH'; Description = 'GitHub collaborator removal';  Pattern = '(^| )repo collaborator remove ' }
    @{ Severity = 'HIGH'; Description = 'GitHub environment deletion';  Pattern = '(^| )repo environment delete ' }
    # MEDIUM - Permission/Config Changes
    @{ Severity = 'MEDIUM'; Description = 'GitHub repo settings change';       Pattern = '(^| )repo edit ' }
    @{ Severity = 'MEDIUM'; Description = 'GitHub secret overwrite';           Pattern = '(^| )secret set ' }
    @{ Severity = 'MEDIUM'; Description = 'GitHub variable overwrite';         Pattern = '(^| )variable set ' }
    @{ Severity = 'MEDIUM'; Description = 'GitHub ruleset deletion';           Pattern = '(^| )ruleset delete ' }
    @{ Severity = 'MEDIUM'; Description = 'GitHub branch protection removal'; Pattern = '(^| )branch-protection delete ' }
    @{ Severity = 'MEDIUM'; Description = 'GitHub label deletion';             Pattern = '(^| )label delete ' }
    @{ Severity = 'MEDIUM'; Description = 'GitHub milestone deletion';         Pattern = '(^| )milestone delete ' }
)

# --- Helpers ---

function Read-GuardConfig {
    $cfg = @{
        TEAMS_WEBHOOK      = ''
        REQUIRE_CONFIRM    = 'true'
        COOLDOWN_SECONDS   = "$script:DefaultCooldown"
        BREAK_GLASS        = 'false'
        BREAK_GLASS_EXPIRES = ''
    }

    if (-not (Test-Path $script:AzureDir)) { New-Item -ItemType Directory -Path $script:AzureDir -Force | Out-Null }
    if (-not (Test-Path $script:ApprovalDir)) { New-Item -ItemType Directory -Path $script:ApprovalDir -Force | Out-Null }

    if (-not (Test-Path $script:ConfigFile)) {
        Set-Content -Path $script:ConfigFile -Value $script:DefaultConfigContent -Encoding UTF8
    }

    foreach ($line in Get-Content $script:ConfigFile) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $eqIdx = $trimmed.IndexOf('=')
        if ($eqIdx -lt 1) { continue }
        $key = $trimmed.Substring(0, $eqIdx).Trim()
        $val = $trimmed.Substring($eqIdx + 1).Trim().Trim('"').Trim("'")
        $cfg[$key] = $val
    }
    return $cfg
}

function Write-AuditLog {
    param([string]$Status, [string]$Details, [string]$Command)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $user = "$env:USERNAME@$env:COMPUTERNAME"
    $entry = "$ts | $Status | $Details | $user | $Command"
    Add-Content -Path $script:AuditLog -Value $entry -Encoding UTF8
}

function Send-TeamsNotification {
    param([string]$Cli, [string]$Severity, [string]$Reason, [string]$Command, [string]$Token)
    $cfg = Read-GuardConfig
    $webhook = $cfg['TEAMS_WEBHOOK']
    if ([string]::IsNullOrWhiteSpace($webhook)) { return }

    $color = switch ($Severity) {
        'CRITICAL' { '8B0000' }
        'HIGH'     { 'FF6600' }
        'MEDIUM'   { 'FFCC00' }
        default    { 'FF0000' }
    }
    $emoji = switch ($Severity) {
        'CRITICAL' { [char]::ConvertFromUtf32(0x1F480) }  # skull
        'HIGH'     { [char]::ConvertFromUtf32(0x1F525) }  # fire
        'MEDIUM'   { [char]::ConvertFromUtf32(0x26A0) }   # warning
        default    { [char]::ConvertFromUtf32(0x1F6D1) }  # stop
    }

    $cooldown = $cfg['COOLDOWN_SECONDS']
    if ([string]::IsNullOrEmpty($cooldown)) { $cooldown = "$script:DefaultCooldown" }
    $truncCmd = if ($Command.Length -gt 350) { $Command.Substring(0, 350) } else { $Command }

    $body = @{
        '@type'      = 'MessageCard'
        '@context'   = 'https://schema.org/extensions'
        summary      = "Cloud Guard: $Cli $Severity Alert"
        themeColor   = $color
        title        = "$emoji Cloud Guard: $Cli $Severity Operation Blocked"
        sections     = @(@{
            activityTitle = "$Reason requires approval"
            facts = @(
                @{ name = 'CLI:';            value = $Cli }
                @{ name = 'Severity:';       value = $Severity }
                @{ name = 'User:';           value = "$env:USERNAME@$env:COMPUTERNAME" }
                @{ name = 'Command:';        value = $truncCmd }
                @{ name = 'Cooldown:';       value = "${cooldown}s" }
                @{ name = 'Approval Token:'; value = $Token }
            )
            markdown = $true
        })
    } | ConvertTo-Json -Depth 5 -Compress

    try { Invoke-RestMethod -Uri $webhook -Method Post -ContentType 'application/json' -Body $body -ErrorAction SilentlyContinue | Out-Null } catch {}
}

function Get-CommandHash {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
    $sha.Dispose()
    return ($hash | ForEach-Object { $_.ToString('x2') }) -join ''
}

function New-ApprovalToken {
    $bytes = [byte[]]::new(12)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    return ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Test-BreakGlassActive {
    $cfg = Read-GuardConfig
    if ($cfg['BREAK_GLASS'] -ne 'true') { return $false }
    $expiresStr = $cfg['BREAK_GLASS_EXPIRES']
    if ([string]::IsNullOrWhiteSpace($expiresStr)) { return $false }

    try {
        $expires = [DateTime]::ParseExact($expiresStr, 'yyyy-MM-dd HH:mm:ss', $null)
        if ([DateTime]::Now -lt $expires) { return $true }
    } catch {}

    # Expired -- auto-disable
    $content = Get-Content $script:ConfigFile -Raw
    $content = $content -replace 'BREAK_GLASS=true', 'BREAK_GLASS=false'
    Set-Content -Path $script:ConfigFile -Value $content -NoNewline -Encoding UTF8
    return $false
}

function Get-CommandAnalysis {
    param([string]$Cli, [string]$CommandArgs)
    $patterns = if ($Cli -eq 'az') { $script:AzBlockedPatterns } else { $script:GhBlockedPatterns }
    foreach ($p in $patterns) {
        if ($CommandArgs -match $p.Pattern) {
            return @{ Severity = $p.Severity; Description = $p.Description }
        }
    }
    return $null
}

function Get-SeverityColor {
    param([string]$Severity)
    switch ($Severity) {
        'CRITICAL' { 'Red' }
        'HIGH'     { 'Yellow' }
        'MEDIUM'   { 'Yellow' }
        default    { 'Red' }
    }
}

function Show-ProtectionMatrix {
    Write-Host ''
    Write-Host ('{0}{1}{2}' -f ([char]0x2554), ('=' * 78), ([char]0x2557)) -ForegroundColor Cyan
    Write-Host ('{0}                    CLOUD CLI GUARD PROTECTION MATRIX                        {1}' -f ([char]0x2551), ([char]0x2551)) -ForegroundColor Cyan
    Write-Host ('{0}{1}{2}' -f ([char]0x2560), ('=' * 78), ([char]0x2563)) -ForegroundColor Cyan

    Write-Host ('{0} AZURE CLI                                                                     {1}' -f ([char]0x2551), ([char]0x2551)) -ForegroundColor Blue
    foreach ($line in @(
        'CRITICAL - Permanent Data Loss / Service Destruction'
        '   * delete, purge (resources, resource groups, key vaults)'
        '   * keyvault secret/key/cert delete (immediate permanent loss)'
        '   * storage container/blob delete (data loss)'
        '   * sql/db delete (database destruction)'
    )) { Write-Host ('{0} {1}' -f ([char]0x2551), $line.PadRight(77)) -ForegroundColor Red }

    Write-Host ('{0}{1}{2}' -f ([char]0x2560), ('=' * 78), ([char]0x2563)) -ForegroundColor Yellow
    foreach ($line in @(
        'HIGH - Production Downtime / Severe Disruption'
        '   * vm stop/deallocate/restart (production VMs offline)'
        '   * containerapp stop/restart (service interruption)'
        '   * aks stop/start/restart (entire cluster down)'
        '   * webapp/functionapp stop/restart (app offline)'
    )) { Write-Host ('{0} {1}' -f ([char]0x2551), $line.PadRight(77)) -ForegroundColor Yellow }

    Write-Host ('{0}{1}{2}' -f ([char]0x2560), ('=' * 78), ([char]0x2563)) -ForegroundColor Yellow
    foreach ($line in @(
        'MEDIUM - Access Lockout / Configuration Break'
        '   * nsg rule delete/update (could lock you out of VMs)'
        '   * firewall delete/update (access blocked)'
        '   * vnet deletion (network isolation)'
    )) { Write-Host ('{0} {1}' -f ([char]0x2551), $line.PadRight(77)) -ForegroundColor Yellow }

    Write-Host ('{0}{1}{2}' -f ([char]0x2560), ('=' * 78), ([char]0x2563)) -ForegroundColor Cyan
    Write-Host ('{0} GITHUB CLI                                                                    {1}' -f ([char]0x2551), ([char]0x2551)) -ForegroundColor Blue
    foreach ($line in @(
        'CRITICAL - Permanent Data Loss (No Recovery)'
        '   * repo delete (repository gone forever)'
        '   * release delete (release + assets permanently deleted)'
        '   * secret delete (credentials lost immediately)'
        '   * workflow delete (automation removed)'
    )) { Write-Host ('{0} {1}' -f ([char]0x2551), $line.PadRight(77)) -ForegroundColor Red }

    Write-Host ('{0}{1}{2}' -f ([char]0x2560), ('=' * 78), ([char]0x2563)) -ForegroundColor Yellow
    foreach ($line in @(
        'HIGH - Repository State Changes (Hard to Undo)'
        '   * pr merge --admin (force merge, bypasses checks)'
        '   * pr/issue close (can reopen, but loses context)'
        '   * api DELETE (any API deletion)'
    )) { Write-Host ('{0} {1}' -f ([char]0x2551), $line.PadRight(77)) -ForegroundColor Yellow }

    Write-Host ('{0}{1}{2}' -f ([char]0x2560), ('=' * 78), ([char]0x2563)) -ForegroundColor Yellow
    foreach ($line in @(
        'MEDIUM - Permission/Config Changes'
        '   * repo edit (default branch, visibility, settings)'
        '   * secret/variable set (overwrites existing)'
        '   * ruleset delete (branch protection removed)'
    )) { Write-Host ('{0} {1}' -f ([char]0x2551), $line.PadRight(77)) -ForegroundColor Yellow }

    Write-Host ('{0}{1}{2}' -f ([char]0x2560), ('=' * 78), ([char]0x2563)) -ForegroundColor Green
    foreach ($line in @(
        'PASS-THROUGH - Safe Operations (No Approval Required)'
        '   * list, show, get, version, login, status, view, browse'
        '   * create (new resources/repos - safe)'
        '   * clone, fork (copies data)'
    )) { Write-Host ('{0} {1}' -f ([char]0x2551), $line.PadRight(77)) -ForegroundColor Green }

    Write-Host ('{0}{1}{2}' -f ([char]0x255A), ('=' * 78), ([char]0x255D)) -ForegroundColor Cyan
    Write-Host ''
    $cfg = Read-GuardConfig
    Write-Host "Cooldown: $($cfg['COOLDOWN_SECONDS'])s | Audit log: $script:AuditLog"
    Write-Host ''
}

# --- Main entry point ---

function Invoke-CloudGuard {
    param(
        [Parameter(Mandatory)][string]$CliType,
        [Parameter(ValueFromRemainingArguments)][string[]]$Arguments
    )

    $cfg = Read-GuardConfig
    $cooldown = $cfg['COOLDOWN_SECONDS']
    if ([string]::IsNullOrEmpty($cooldown)) { $cooldown = "$script:DefaultCooldown" }

    # Resolve real CLI path
    $realCli = $null
    if ($CliType -eq 'az') {
        $found = Get-Command 'az.cmd' -ErrorAction SilentlyContinue
        if (-not $found) { $found = Get-Command 'az' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if ($found) { $realCli = $found.Source }
    } elseif ($CliType -eq 'gh') {
        $found = Get-Command 'gh.exe' -ErrorAction SilentlyContinue
        if (-not $found) { $found = Get-Command 'gh' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if ($found) { $realCli = $found.Source }
    }

    if (-not $realCli) {
        Write-Host "ERROR: Could not find real $CliType binary." -ForegroundColor Red
        return
    }

    if ($null -eq $Arguments) { $Arguments = @() }
    $argsStr = $Arguments -join ' '

    # Pass through help and version
    if ($argsStr -match '^(--help|-h|--version|-v)$') {
        & $realCli @Arguments
        return
    }

    # --guard-matrix
    if ($Arguments.Count -ge 1 -and $Arguments[0] -eq '--guard-matrix') {
        Show-ProtectionMatrix
        return
    }

    # --guard-status
    if ($Arguments.Count -ge 1 -and $Arguments[0] -eq '--guard-status') {
        Write-Host 'Cloud CLI Guard Status' -ForegroundColor Blue
        Write-Host '====================='
        Write-Host "CLI Type: $CliType"
        Write-Host "Real binary: $realCli"
        Write-Host "Audit log: $script:AuditLog"
        Write-Host "Config file: $script:ConfigFile"
        $pending = if (Test-Path $script:ApprovalDir) { (Get-ChildItem $script:ApprovalDir -File -ErrorAction SilentlyContinue | Measure-Object).Count } else { 0 }
        Write-Host "Pending approvals: $pending"
        Write-Host "Break glass: $($cfg['BREAK_GLASS'])"
        Write-Host "Cooldown: ${cooldown}s"
        Write-Host ''
        Write-Host 'Recent blocked operations:'
        if (Test-Path $script:AuditLog) {
            $blocked = Get-Content $script:AuditLog -Tail 10 | Where-Object { $_ -match 'BLOCKED' }
            if ($blocked) { $blocked | ForEach-Object { Write-Host $_ } } else { Write-Host 'None' }
        } else {
            Write-Host 'None'
        }
        return
    }

    # --break-glass
    if ($Arguments.Count -ge 1 -and $Arguments[0] -eq '--break-glass') {
        if ($Arguments.Count -ge 2 -and $Arguments[1] -eq '--enable') {
            $cmdHash = Get-CommandHash 'break-glass-enable'
            $hashFile = Join-Path $script:ApprovalDir $cmdHash
            if (Test-Path $hashFile) {
                $expires = (Get-Date).AddHours(1).ToString('yyyy-MM-dd HH:mm:ss')
                $content = Get-Content $script:ConfigFile -Raw
                $content = $content -replace 'BREAK_GLASS=false', 'BREAK_GLASS=true'
                $content = $content -replace 'BREAK_GLASS_EXPIRES=.*', "BREAK_GLASS_EXPIRES=`"$expires`""
                Set-Content -Path $script:ConfigFile -Value $content -NoNewline -Encoding UTF8
                Remove-Item $hashFile -Force -ErrorAction SilentlyContinue
                Write-Host 'BREAK GLASS ENABLED for 1 hour' -ForegroundColor Red
                Write-Host '   All safety checks bypassed. Audit trail still active.'
                Write-AuditLog -Status 'BREAK_GLASS' -Details 'ENABLED' -Command "Expires: $expires"
                return
            }

            $token = New-ApprovalToken
            Set-Content -Path (Join-Path $script:ApprovalDir $token) -Value 'break-glass-enable' -Encoding UTF8
            Set-Content -Path $hashFile -Value 'break-glass-enable' -Encoding UTF8
            Send-TeamsNotification -Cli $CliType -Severity 'CRITICAL' -Reason 'Break Glass Mode Request' -Command "$CliType --break-glass --enable" -Token $token
            Write-AuditLog -Status 'BLOCKED' -Details "CRITICAL|$token" -Command 'break-glass-enable'

            Write-Host ''
            Write-Host 'CRITICAL: Break Glass Mode Request Blocked' -ForegroundColor Red
            Write-Host ''
            Write-Host "Command: $CliType --break-glass --enable" -ForegroundColor Yellow
            Write-Host ''
            Write-Host 'This will disable ALL safety checks for 1 hour.' -ForegroundColor Red
            Write-Host 'Any team member with the token could execute dangerous commands.' -ForegroundColor Red
            Write-Host ''
            Write-Host 'To approve enabling break glass mode:' -ForegroundColor Blue
            Write-Host ''
            Write-Host "  1. Wait ${cooldown}s for the cooldown period"
            Write-Host '  2. Check your Teams private channel for the approval token'
            Write-Host "  3. Run: $CliType --approve <token-from-teams>" -ForegroundColor Green
            Write-Host "  4. Then run: $CliType --break-glass --enable again" -ForegroundColor Green
            Write-Host ''
            return
        }
        elseif ($Arguments.Count -ge 2 -and $Arguments[1] -eq '--disable') {
            $content = Get-Content $script:ConfigFile -Raw
            $content = $content -replace 'BREAK_GLASS=true', 'BREAK_GLASS=false'
            Set-Content -Path $script:ConfigFile -Value $content -NoNewline -Encoding UTF8
            Write-Host 'Break glass disabled' -ForegroundColor Green
            Write-AuditLog -Status 'BREAK_GLASS' -Details 'DISABLED' -Command 'Manual'
            return
        }
    }

    # --approve
    if ($Arguments.Count -ge 2 -and $Arguments[0] -eq '--approve') {
        $token = $Arguments[1]
        $tokenFile = Join-Path $script:ApprovalDir $token
        if (Test-Path $tokenFile) {
            $cmd = Get-Content $tokenFile -Raw
            $cmd = $cmd.Trim()
            Remove-Item $tokenFile -Force -ErrorAction SilentlyContinue
            $cmdHashVal = Get-CommandHash $cmd
            Remove-Item (Join-Path $script:ApprovalDir $cmdHashVal) -Force -ErrorAction SilentlyContinue
            Write-Host 'Executing approved command:' -ForegroundColor Green
            Write-Host "   $CliType $cmd"
            Write-AuditLog -Status 'APPROVED' -Details 'EXECUTED' -Command $cmd
            $cmdParts = $cmd -split '\s+'
            & $realCli @cmdParts
            return
        } else {
            Write-Host 'Invalid or expired approval token' -ForegroundColor Red
            Write-Host '   Token may have already been used or expired.'
            return
        }
    }

    # Break glass active?
    if (Test-BreakGlassActive) {
        Write-Host 'BREAK GLASS MODE ACTIVE - Running without safety checks' -ForegroundColor Red
        Write-AuditLog -Status 'BREAK_GLASS' -Details 'BYPASSED' -Command $argsStr
        & $realCli @Arguments
        return
    }

    # Analyze the command
    $analysis = Get-CommandAnalysis -Cli $CliType -CommandArgs $argsStr

    if ($null -ne $analysis) {
        $severity = $analysis.Severity
        $reason = $analysis.Description
        $sevColor = Get-SeverityColor $severity

        $cmdHash = Get-CommandHash $argsStr
        $hashFile = Join-Path $script:ApprovalDir $cmdHash
        if (Test-Path $hashFile) {
            Write-Host "This command was previously approved but not executed." -ForegroundColor Yellow
            Write-Host "   Run: $CliType --approve $cmdHash"
            return
        }

        $emoji = switch ($severity) { 'CRITICAL' { 'CRITICAL' } 'HIGH' { 'HIGH' } 'MEDIUM' { 'MEDIUM' } default { 'BLOCKED' } }

        Write-Host ''
        Write-Host "$emoji`: $reason blocked" -ForegroundColor $sevColor
        Write-Host ''
        Write-Host "Command: $CliType $argsStr" -ForegroundColor Yellow
        Write-Host ''

        switch ($severity) {
            'CRITICAL' {
                Write-Host 'This operation can cause IRREVERSIBLE data loss or service destruction.' -ForegroundColor Red
                Write-Host "Double-check you're targeting the correct resource." -ForegroundColor Red
                if ($CliType -eq 'gh') {
                    Write-Host 'Note: GitHub deletions are PERMANENT and cannot be recovered.' -ForegroundColor Red
                }
            }
            'HIGH' {
                Write-Host 'This operation will cause production downtime or severe service disruption.' -ForegroundColor Yellow
                if ($CliType -eq 'gh') {
                    Write-Host 'Repository state changes may be difficult to undo.' -ForegroundColor Yellow
                }
            }
            'MEDIUM' {
                Write-Host 'This operation could cause access lockout or break critical configuration.' -ForegroundColor Yellow
            }
        }
        Write-Host ''

        $token = New-ApprovalToken
        Set-Content -Path (Join-Path $script:ApprovalDir $token) -Value $argsStr -Encoding UTF8
        Set-Content -Path $hashFile -Value $cmdHash -Encoding UTF8

        Send-TeamsNotification -Cli $CliType -Severity $severity -Reason $reason -Command "$CliType $argsStr" -Token $token
        Write-AuditLog -Status 'BLOCKED' -Details "$severity|$token" -Command $argsStr

        Write-Host 'AI AGENT INSTRUCTION' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'If you are an AI assistant or agent executing commands on behalf of a user:' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '  1. STOP and do not proceed with this command'
        Write-Host '  2. Ask the user to check their Teams private channel'
        Write-Host '  3. The user will find the approval token there'
        Write-Host '  4. Ask the user to provide you the token'
        Write-Host "  5. Once received, execute: $CliType --approve <token>"
        Write-Host ''
        Write-Host 'Do not attempt to bypass this safety measure or guess the token.' -ForegroundColor Cyan
        Write-Host ''

        Write-Host 'To approve this operation:' -ForegroundColor Blue
        Write-Host ''
        Write-Host "  1. Wait ${cooldown}s for the cooldown period"
        Write-Host '  2. Check your Teams private channel for the approval token'
        Write-Host "  3. Run: $CliType --approve <token-from-teams>" -ForegroundColor Green
        Write-Host ''
        Write-Host '  Emergency break glass (logs to audit trail):'
        Write-Host "    $CliType --break-glass --enable" -ForegroundColor Yellow
        Write-Host '    Then retry your command'
        Write-Host ''
        return
    }

    # Safe command -- pass through
    & $realCli @Arguments
}

# --- Public wrapper functions that shadow the real CLIs ---

function az {
    Invoke-CloudGuard -CliType 'az' @args
}

function gh {
    Invoke-CloudGuard -CliType 'gh' @args
}

Export-ModuleMember -Function az, gh, Invoke-CloudGuard
