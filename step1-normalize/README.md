# Step 1: Normalize Tag Variations

**Policy Name**: `cost-center-normalize-v3`  
**Effect**: Modify (non-blocking)  
**Deploy Order**: First  
**Author**: Anand Lakhera (anand.lakhera@ahead.com)

---

## Purpose

Normalizes 8 common Cost_Center tag variations into the canonical `Cost_Center` format.

## Tag Variations Handled

This policy converts the following variations:

| Variation | Converted To |
|-----------|--------------|
| Cost-Center | Cost_Center |
| CostCenter | Cost_Center |
| Cost Centre | Cost_Center |
| costcentre | Cost_Center |
| Cost-Centre | Cost_Center |
| Cost Center | Cost_Center |
| Cost_ Center | Cost_Center |
| cost-center | Cost_Center |

## How It Works

1. **Condition**: Resource does NOT have `Cost_Center` tag but HAS at least one variation
2. **Validation**: The variation tag must be non-empty
3. **Action**: Copies value from variation to canonical `Cost_Center` tag
4. **Priority**: Uses first non-empty variation in the order listed above

## Deployment

```powershell
# Deploy policy definition
New-AzPolicyDefinition `
    -Name "cost-center-normalize-v3" `
    -Policy "./policy.json" `
    -SubscriptionId "YOUR-SUBSCRIPTION-ID"

# Assign policy
$policy = Get-AzPolicyDefinition -Name "cost-center-normalize-v3"
$assignment = New-AzPolicyAssignment `
    -Name "cost-center-normalize" `
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
    -Name "remediate-normalize" `
    -PolicyAssignmentId $assignment.PolicyAssignmentId `
    -ResourceDiscoveryMode ReEvaluateCompliance
```

## Expected Results

**Target**: 95%+ compliance within 7 days

For an environment with 400,000 resources:
- Estimated resources with variations: 20,000-40,000 (5-10%)
- Remediation rate: ~500 resources/hour
- Total remediation time: 40-80 hours

## Monitoring

Check compliance:
```powershell
Get-AzPolicyState -PolicyAssignmentName "cost-center-normalize" | 
    Group-Object ComplianceState | 
    Select-Object Name, Count
```

## Next Steps

After achieving 95%+ compliance and waiting 24 hours, proceed to:
- **Step 2**: Inherit from Resource Group

---

**Version**: 1.0.0  
**Last Updated**: November 26, 2025
