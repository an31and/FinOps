# Step 4: Deny Resource Group Creation (ENFORCEMENT)

**Policy Name**: `deny-rg-without-cost-center`  
**Effect**: Deny (BLOCKING)  
**Deploy Order**: Fourth (LAST - after team communication)  
**Author**: Anand Lakhera (anand.lakhera@ahead.com)

---

## ⚠️ WARNING

**THIS POLICY BLOCKS RESOURCE CREATION**

Only deploy this policy after:
- [ ] Steps 1-3 achieve 99%+ compliance
- [ ] Teams receive minimum 2 weeks notice
- [ ] Templates and CI/CD updated
- [ ] Self-service validation provided
- [ ] Testing in DoNotEnforce mode for 3-5 days

---

## Purpose

Prevents creation of new Resource Groups without `Cost_Center` tag, ensuring all future resources will inherit the tag through policy-based inheritance.

## How It Works

1. **Condition**: Resource Group is being created WITHOUT `Cost_Center` tag
2. **Action**: **DENIES** the creation (deployment fails)
3. **User Impact**: ARM/Terraform deployments will fail with policy violation error
4. **Scope**: Only affects Resource Groups (mode: All)

## Why Resource Groups?

Blocking at the RG level (not individual resources) because:
- Resources inherit from RGs via Step 2 policy
- Single enforcement point = simpler governance
- Less disruptive to operations
- Easier for teams to comply

## Prerequisites

### Technical Prerequisites
- Steps 1-3 deployed and ≥99% compliant
- No active remediation tasks running
- Clean compliance validation report

### Communication Prerequisites
- [ ] Email announcement sent (minimum 2 weeks prior)
- [ ] Template examples distributed
- [ ] Self-service validation script provided
- [ ] Office hours conducted
- [ ] Support channels established
- [ ] Enforcement date confirmed

## Deployment: Phase 1 - Audit Mode

**Start with DoNotEnforce mode** to audit impact without blocking:

```powershell
# Deploy policy definition
New-AzPolicyDefinition `
    -Name "deny-rg-without-cost-center" `
    -Policy "./policy.json" `
    -SubscriptionId "YOUR-SUBSCRIPTION-ID"

# Assign in AUDIT mode (DoNotEnforce)
$policy = Get-AzPolicyDefinition -Name "deny-rg-without-cost-center"
$assignment = New-AzPolicyAssignment `
    -Name "deny-rg-cost-center" `
    -PolicyDefinition $policy `
    -Scope "/subscriptions/YOUR-SUBSCRIPTION-ID" `
    -EnforcementMode DoNotEnforce

Write-Host "✅ Policy deployed in AUDIT mode" -ForegroundColor Green
Write-Host "Monitor for 3-5 days before enabling enforcement" -ForegroundColor Yellow
```

### Monitor Audit Mode (Days 1-5)

Check what would have been blocked:

```powershell
# Check audit logs for denied actions (would-be blocks)
$startTime = (Get-Date).AddDays(-5)
$logs = Get-AzLog -StartTime $startTime -MaxRecord 1000 | 
    Where-Object {
        $_.Authorization.Action -eq "Microsoft.Resources/subscriptions/resourceGroups/write" -and
        $_.Properties.Content.responseBody -match "deny-rg-without-cost-center"
    }

Write-Host "Actions that WOULD have been blocked: $($logs.Count)" -ForegroundColor Yellow

if ($logs.Count -gt 0) {
    $logs | Select-Object @{N='Time';E={$_.EventTimestamp}}, Caller, ResourceGroupName | Format-Table
    
    Write-Host "`n⚠️ Found attempts without Cost_Center tag" -ForegroundColor Yellow
    Write-Host "Contact these teams before enabling enforcement" -ForegroundColor Yellow
}
else {
    Write-Host "✅ No violations found - safe to enable enforcement" -ForegroundColor Green
}
```

---

## Deployment: Phase 2 - Enable Enforcement

**Only proceed if**:
- Audit mode showed zero or minimal violations
- Any found violations have been resolved
- Final team reminder sent

```powershell
# FINAL WARNING
Write-Host "`n" -BackgroundColor Red
Write-Host "⚠️  ENABLING ENFORCEMENT - THIS WILL BLOCK RESOURCE CREATION  ⚠️" -ForegroundColor Red -BackgroundColor Yellow
Write-Host "`n" -BackgroundColor Red
Write-Host "Resource Groups without Cost_Center will be DENIED." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to cancel, or wait 10 seconds to proceed..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Enable enforcement
Set-AzPolicyAssignment `
    -Name "deny-rg-cost-center" `
    -EnforcementMode Default

Write-Host "`n✅ ENFORCEMENT ACTIVE" -ForegroundColor Green
Write-Host "All new Resource Groups must have Cost_Center tag" -ForegroundColor Green
```

---

## Policy Behavior

### Successful Deployment (Compliant)

ARM Template:
```json
{
  "type": "Microsoft.Resources/resourceGroups",
  "apiVersion": "2021-04-01",
  "name": "rg-example",
  "location": "eastus",
  "tags": {
    "Cost_Center": "CC-1001"  // ✅ Policy allows
  }
}
```

Result: ✅ **Deployment succeeds**

---

### Blocked Deployment (Non-Compliant)

ARM Template:
```json
{
  "type": "Microsoft.Resources/resourceGroups",
  "apiVersion": "2021-04-01",
  "name": "rg-example",
  "location": "eastus",
  "tags": {
    "Environment": "Production"  // ❌ Missing Cost_Center
  }
}
```

Result: ❌ **Deployment fails with error**:
```
Policy violation: Resource Group creation denied by policy 'deny-rg-without-cost-center'.
Required tag 'Cost_Center' is missing.
```

---

## Error Messages Users Will See

### Azure Portal
```
Deployment failed
The template deployment 'rgDeploy' is not valid according to the validation procedure.
Policy violation: deny-rg-without-cost-center
Required tag 'Cost_Center' is missing on Resource Group.
```

### Azure CLI
```
(PolicyViolation) The resource operation completed with terminal provisioning state 'Failed'.
Code: PolicyViolation
Message: Resource Group creation denied by policy 'deny-rg-without-cost-center'
```

### PowerShell
```
New-AzResourceGroup: The resource operation completed with terminal provisioning state 'Failed'.
ErrorCode: PolicyViolation
ErrorMessage: Policy deny-rg-without-cost-center prevents this action
```

---

## Team Guidance

Share this with teams after enforcement is enabled:

### How to Fix

**Before deploying a Resource Group**, ensure it has `Cost_Center` tag:

**ARM Template**:
```json
{
  "type": "Microsoft.Resources/resourceGroups",
  "location": "eastus",
  "tags": {
    "Cost_Center": "CC-1001",  // Required!
    "Environment": "Production"
  }
}
```

**Terraform**:
```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "East US"
  
  tags = {
    Cost_Center = "CC-1001"  # Required!
    Environment = "Production"
  }
}
```

**Azure CLI**:
```bash
az group create \
  --name rg-example \
  --location eastus \
  --tags Cost_Center=CC-1001 Environment=Production
```

**PowerShell**:
```powershell
New-AzResourceGroup `
  -Name "rg-example" `
  -Location "eastus" `
  -Tag @{Cost_Center="CC-1001"; Environment="Production"}
```

---

## Exemptions

For legitimate cases where Cost_Center cannot be applied:

```powershell
# Create exemption
New-AzPolicyExemption `
    -Name "exemption-legacy-rg" `
    -DisplayName "Legacy System - Manual Tag Management" `
    -PolicyAssignment $assignment `
    -Scope "/subscriptions/xxxxx/resourceGroups/legacy-rg" `
    -ExemptionCategory Waiver `
    -Description "Legacy system with external tag management. Reviewed quarterly." `
    -ExpiresOn (Get-Date).AddMonths(6)
```

**Exemption Best Practices**:
- Always set expiration date (review every 6 months)
- Document business justification
- Minimize exemptions to maintain governance
- Review and remove when no longer needed

---

## Monitoring Post-Enforcement

### Check for Blocked Deployments

```powershell
# Daily check
$today = Get-Date
$deniedActions = Get-AzLog -StartTime $today.AddDays(-1) -MaxRecord 1000 | 
    Where-Object {
        $_.Status.Value -eq "Failed" -and
        $_.Properties.Content.statusMessage -match "deny-rg-without-cost-center"
    }

Write-Host "Blocked deployments in last 24 hours: $($deniedActions.Count)"
$deniedActions | Select-Object EventTimestamp, Caller, ResourceId | Format-Table
```

### Compliance Rate

```powershell
# Check new RGs compliance
$recentRGs = Get-AzResourceGroup | Where-Object {
    $_.Tags.ContainsKey('Cost_Center')
}

$total = (Get-AzResourceGroup).Count
$compliant = $recentRGs.Count
$complianceRate = [math]::Round(($compliant / $total) * 100, 2)

Write-Host "Resource Group Compliance: $complianceRate%" -ForegroundColor $(if($complianceRate -eq 100){"Green"}else{"Yellow"})
```

---

## Rollback

If critical issues occur:

```powershell
# Emergency disable
Set-AzPolicyAssignment -Name "deny-rg-cost-center" -EnforcementMode DoNotEnforce

Write-Host "⚠️ Enforcement disabled - RG creation now allowed without Cost_Center" -ForegroundColor Yellow

# Communicate to teams
Send-MailMessage ... # Your notification logic
```

---

## Success Criteria

After 30 days of enforcement:
- [ ] 100% of new RGs have Cost_Center tag
- [ ] <5 policy exemptions
- [ ] <10 support tickets/month
- [ ] Zero rollbacks required
- [ ] Positive team feedback

---

## Support

**Common Issues**: See main README.md troubleshooting section

**Contact**:
- Policy Owner: anand.lakhera@ahead.com
- Slack: #azure-governance
- Support Hours: [Your schedule]

---

**Version**: 1.0.0  
**Last Updated**: November 26, 2025  

**⚠️ REMEMBER**: This is an enforcement policy. Deploy with care.
