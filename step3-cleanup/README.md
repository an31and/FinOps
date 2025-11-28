# Step 3: Remove Duplicate Variations

**Policy Name**: `cost-center-cleanup-v3`  
**Effect**: Modify (non-blocking)  
**Deploy Order**: Third (after Steps 1 & 2)  
**Author**: Anand Lakhera (anand.lakhera@ahead.com)

---

## Purpose

Removes all Cost_Center tag variations after the canonical `Cost_Center` tag has been established, ensuring a single source of truth.

## How It Works

1. **Condition**: Resource HAS canonical `Cost_Center` tag (non-empty) AND has at least one variation
2. **Action**: Removes ALL 8 tag variations in a single remediation
3. **Safety**: Only removes duplicates when canonical tag exists
4. **Result**: Resources have ONLY `Cost_Center` tag, no variations

## Variations Removed

This policy removes these tags if canonical `Cost_Center` exists:
- `Cost-Center`
- `CostCenter`
- `Cost Centre`
- `costcentre`
- `Cost-Centre`
- `Cost Center`
- `Cost_ Center`
- `cost-center`

## Prerequisites

- **Step 1** must achieve ≥95% compliance
- **Step 2** must achieve ≥90% compliance
- Wait 24 hours after Step 2 deployment

## Why This Order?

Deploying cleanup too early would delete variation tags before Step 1 can normalize them. The correct sequence ensures:

1. Step 1 copies variation → canonical
2. Step 2 fills any gaps from RGs
3. Step 3 removes variations (safe because canonical exists)

## Deployment

```powershell
# Verify Steps 1 & 2 compliance first
$step2State = Get-AzPolicyState -PolicyAssignmentName "cost-center-inherit"
$compliance = ($step2State | Where-Object {$_.ComplianceState -eq "Compliant"}).Count / $step2State.Count * 100

if ($compliance -lt 90) {
    Write-Host "Step 2 compliance is $compliance%. Wait for 90% before deploying Step 3" -ForegroundColor Red
    exit
}

# Deploy policy definition
New-AzPolicyDefinition `
    -Name "cost-center-cleanup-v3" `
    -Policy "./policy.json" `
    -SubscriptionId "YOUR-SUBSCRIPTION-ID"

# Assign policy
$policy = Get-AzPolicyDefinition -Name "cost-center-cleanup-v3"
$assignment = New-AzPolicyAssignment `
    -Name "cost-center-cleanup" `
    -PolicyDefinition $policy `
    -Scope "/subscriptions/YOUR-SUBSCRIPTION-ID" `
    -Location "eastus" `
    -AssignIdentity

# Assign Tag Contributor role
New-AzRoleAssignment `
    -ObjectId $assignment.Identity.PrincipalId `
    -RoleDefinitionName "Tag Contributor" `
    -Scope "/subscriptions/YOUR-SUBSCRIPTION-ID"

# Create remediation task
Start-AzPolicyRemediation `
    -Name "remediate-cleanup" `
    -PolicyAssignmentId $assignment.PolicyAssignmentId `
    -ResourceDiscoveryMode ReEvaluateCompliance
```

## Expected Results

**Target**: 99%+ compliance, 0 resources with duplicate tags

After completion:
- All resources have canonical `Cost_Center` tag
- No resources have variation tags
- Clean, consistent tagging across environment

## Monitoring

Check for remaining variations:
```kusto
Resources
| where isnotempty(tags)
| extend 
    HasCanonical = isnotempty(tags['Cost_Center']),
    HasVariations = 
        isnotempty(tags['Cost-Center']) or
        isnotempty(tags['CostCenter']) or
        isnotempty(tags['Cost Centre']) or
        isnotempty(tags['costcentre']) or
        isnotempty(tags['Cost-Centre']) or
        isnotempty(tags['Cost Center']) or
        isnotempty(tags['Cost_ Center']) or
        isnotempty(tags['cost-center'])
| where HasCanonical and HasVariations
| summarize Count = count()
```

Expected result: **Count = 0**

## Data Loss Prevention

This policy is designed to prevent data loss:

✅ **Safe**: Only removes variations when canonical tag exists  
✅ **Safe**: Validates canonical tag is non-empty  
✅ **Safe**: Deployed after normalization is complete  

❌ **Would be unsafe**: Deploying before Steps 1 & 2 complete  
❌ **Would be unsafe**: Running without canonical tag requirement  

## Next Steps

After achieving 99%+ compliance:
- Generate final compliance report
- Prepare for team communication (Phase 2)
- Plan enforcement deployment (Step 4)

Wait minimum 2 weeks for team enablement before deploying Step 4.

---

**Version**: 1.0.0  
**Last Updated**: November 26, 2025
