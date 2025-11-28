# Step 2: Inherit from Resource Group

**Policy Name**: `cost-center-inherit-rg-v3`  
**Effect**: Modify (non-blocking)  
**Deploy Order**: Second (after Step 1)  
**Author**: Anand Lakhera (anand.lakhera@ahead.com)

---

## Purpose

Automatically copies `Cost_Center` tag from parent Resource Group to resources that don't have any Cost_Center tag variation.

## How It Works

1. **Condition**: Resource has NO Cost_Center variations AND parent RG HAS Cost_Center tag
2. **Validation**: Resource Group's Cost_Center tag must be non-empty
3. **Action**: Copies Cost_Center value from RG to resource
4. **Safety**: Uses `addOrReplace` operation for idempotent behavior

## Prerequisites

- **Step 1** must achieve ≥95% compliance
- Wait 24 hours after Step 1 deployment
- Ensure Resource Groups have Cost_Center tags

## Key Change in v1.0.0

**Fixed Operation**: Changed from `add` to `addOrReplace`

**Why?**
- `add` fails if tag already exists (race conditions)
- `addOrReplace` is idempotent and safer for large-scale remediation
- Handles edge cases where tag appears between evaluation and remediation

## Deployment

```powershell
# Verify Step 1 compliance first
$step1State = Get-AzPolicyState -PolicyAssignmentName "cost-center-normalize"
$compliance = ($step1State | Where-Object {$_.ComplianceState -eq "Compliant"}).Count / $step1State.Count * 100

if ($compliance -lt 95) {
    Write-Host "Step 1 compliance is $compliance%. Wait for 95% before deploying Step 2" -ForegroundColor Red
    exit
}

# Deploy policy definition
New-AzPolicyDefinition `
    -Name "cost-center-inherit-rg-v3" `
    -Policy "./policy.json" `
    -SubscriptionId "YOUR-SUBSCRIPTION-ID"

# Assign policy
$policy = Get-AzPolicyDefinition -Name "cost-center-inherit-rg-v3"
$assignment = New-AzPolicyAssignment `
    -Name "cost-center-inherit" `
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
    -Name "remediate-inherit" `
    -PolicyAssignmentId $assignment.PolicyAssignmentId `
    -ResourceDiscoveryMode ReEvaluateCompliance
```

## Expected Results

**Target**: 98%+ compliance within 7 days

This policy fills the gap left by Step 1 by handling resources that had NO tag variations at all.

## Monitoring

Check compliance:
```powershell
Get-AzPolicyState -PolicyAssignmentName "cost-center-inherit" | 
    Group-Object ComplianceState | 
    Select-Object Name, Count
```

Check if inheritance is working:
```powershell
# Get a resource that should have inherited
$resource = Get-AzResource -ResourceGroupName "test-rg" -Name "test-vm"
$rg = Get-AzResourceGroup -Name "test-rg"

Write-Host "RG Cost_Center: $($rg.Tags['Cost_Center'])"
Write-Host "Resource Cost_Center: $($resource.Tags['Cost_Center'])"
```

## Troubleshooting

### Issue: Resources not inheriting
**Check**: Does the Resource Group have Cost_Center tag?
```powershell
Get-AzResourceGroup -Name "your-rg" | Select-Object ResourceGroupName, @{N='Cost_Center';E={$_.Tags['Cost_Center']}}
```

### Issue: Policy shows "Not applicable"
**Check**: Does the resource already have a Cost_Center variation?
```powershell
$resource.Tags.Keys | Where-Object {$_ -match 'cost.*center'}
```

## Next Steps

After achieving 90%+ compliance and waiting 24 hours, proceed to:
- **Step 3**: Cleanup duplicate variations

---

**Version**: 1.0.0  
**Last Updated**: November 26, 2025
