# Cost_Center Tag Governance - Quick Start Guide

**Author**: Anand Lakhera (anand.lakhera@ahead.com)  
**Version**: 1.0.0  
**Last Updated**: November 26, 2025

---

## TL;DR - 7-Week Deployment Plan

```
Week 1-4: Deploy policies 1-3 (normalize, inherit, cleanup)
Week 5-6: Communicate to teams, distribute templates
Week 7+:  Deploy policy 4 (deny), enable enforcement
```

---

## File Structure

```
cost-center-policies/
├── README.md                          # Complete documentation
├── DEPLOYMENT-ORDER.md                # Detailed timeline & checklist
├── QUICKSTART.md                      # This file
│
├── step1-normalize/
│   ├── policy.json                    # Deploy FIRST
│   └── README.md
│
├── step2-inherit/
│   ├── policy.json                    # Deploy SECOND (24h after Step 1)
│   └── README.md                      # ⚡ Fixed: operation = addOrReplace
│
├── step3-cleanup/
│   ├── policy.json                    # Deploy THIRD (24h after Step 2)
│   └── README.md
│
└── step4-enforce/
    ├── policy.json                    # Deploy LAST (after 2 weeks notice)
    └── README.md                      # ⚠️ WARNING: Blocks deployments
```

---

## Critical Points

### ✅ What's Fixed in v1.0.0

**Step 2 Policy** - Changed operation from `add` to `addOrReplace`:
```json
// OLD (had race condition issues)
"operation": "add"

// NEW (safer, idempotent)
"operation": "addOrReplace"
```

### ⚠️ Important Warnings

1. **DO NOT deploy Step 4 (deny) first** - You'll block all deployments
2. **DO NOT skip team communication** - Minimum 2 weeks notice required
3. **DO NOT rush Steps 1-3** - Wait for 90-95% compliance between steps
4. **DO deploy Step 4 in audit mode first** - Catch issues before enforcement

---

## Week-by-Week Deployment

### Week 1: Step 1 - Normalize

```powershell
# Set your subscription ID
$subscriptionId = "YOUR-SUBSCRIPTION-ID"
$location = "eastus"

# Deploy
New-AzPolicyDefinition -Name "cost-center-normalize-v3" -Policy "./step1-normalize/policy.json" -SubscriptionId $subscriptionId
$policy = Get-AzPolicyDefinition -Name "cost-center-normalize-v3"
$assignment = New-AzPolicyAssignment -Name "cost-center-normalize" -PolicyDefinition $policy -Scope "/subscriptions/$subscriptionId" -Location $location -AssignIdentity
New-AzRoleAssignment -ObjectId $assignment.Identity.PrincipalId -RoleDefinitionName "Tag Contributor" -Scope "/subscriptions/$subscriptionId"
Start-Sleep 300
Start-AzPolicyRemediation -Name "remediate-normalize" -PolicyAssignmentId $assignment.PolicyAssignmentId -ResourceDiscoveryMode ReEvaluateCompliance -AsJob
```

**Monitor**: Target 95%+ compliance

---

### Week 2: Step 2 - Inherit

```powershell
# Check Step 1 compliance first!
$compliance = (Get-AzPolicyState -PolicyAssignmentName "cost-center-normalize" | Where-Object {$_.ComplianceState -eq "Compliant"}).Count / (Get-AzPolicyState -PolicyAssignmentName "cost-center-normalize").Count * 100

if ($compliance -lt 95) {
    Write-Host "Wait! Step 1 is only $compliance% compliant. Need 95% before Step 2." -ForegroundColor Red
    exit
}

# Deploy
New-AzPolicyDefinition -Name "cost-center-inherit-rg-v3" -Policy "./step2-inherit/policy.json" -SubscriptionId $subscriptionId
$policy = Get-AzPolicyDefinition -Name "cost-center-inherit-rg-v3"
$assignment = New-AzPolicyAssignment -Name "cost-center-inherit" -PolicyDefinition $policy -Scope "/subscriptions/$subscriptionId" -Location $location -AssignIdentity
New-AzRoleAssignment -ObjectId $assignment.Identity.PrincipalId -RoleDefinitionName "Tag Contributor" -Scope "/subscriptions/$subscriptionId"
Start-Sleep 300
Start-AzPolicyRemediation -Name "remediate-inherit" -PolicyAssignmentId $assignment.PolicyAssignmentId -ResourceDiscoveryMode ReEvaluateCompliance -AsJob
```

**Monitor**: Target 98%+ compliance

---

### Week 3: Step 3 - Cleanup

```powershell
# Check Step 2 compliance first!
$compliance = (Get-AzPolicyState -PolicyAssignmentName "cost-center-inherit" | Where-Object {$_.ComplianceState -eq "Compliant"}).Count / (Get-AzPolicyState -PolicyAssignmentName "cost-center-inherit").Count * 100

if ($compliance -lt 90) {
    Write-Host "Wait! Step 2 is only $compliance% compliant. Need 90% before Step 3." -ForegroundColor Red
    exit
}

# Deploy
New-AzPolicyDefinition -Name "cost-center-cleanup-v3" -Policy "./step3-cleanup/policy.json" -SubscriptionId $subscriptionId
$policy = Get-AzPolicyDefinition -Name "cost-center-cleanup-v3"
$assignment = New-AzPolicyAssignment -Name "cost-center-cleanup" -PolicyDefinition $policy -Scope "/subscriptions/$subscriptionId" -Location $location -AssignIdentity
New-AzRoleAssignment -ObjectId $assignment.Identity.PrincipalId -RoleDefinitionName "Tag Contributor" -Scope "/subscriptions/$subscriptionId"
Start-Sleep 300
Start-AzPolicyRemediation -Name "remediate-cleanup" -PolicyAssignmentId $assignment.PolicyAssignmentId -ResourceDiscoveryMode ReEvaluateCompliance -AsJob
```

**Monitor**: Target 99%+ compliance, 0 duplicate tags

---

### Week 4: Validate

```powershell
# Generate compliance report
$policies = @("cost-center-normalize", "cost-center-inherit", "cost-center-cleanup")
foreach ($p in $policies) {
    $state = Get-AzPolicyState -PolicyAssignmentName $p
    $total = $state.Count
    $compliant = ($state | Where-Object {$_.ComplianceState -eq "Compliant"}).Count
    Write-Host "$p : $([math]::Round(($compliant/$total)*100,2))% compliant"
}
```

**Required**: All three policies ≥99% compliant before proceeding

---

### Weeks 5-6: Team Communication

**DO NOT SKIP THIS STEP**

1. Send email to all teams (see template in README.md)
2. Announce enforcement date (Week 7)
3. Provide template examples (ARM/Terraform)
4. Share self-service validation script
5. Hold office hours
6. Answer questions on Slack

**Minimum**: 2 weeks notice before enforcement

---

### Week 7: Step 4 - Enforce (Audit Mode)

```powershell
# Deploy in AUDIT mode first (DoNotEnforce)
New-AzPolicyDefinition -Name "deny-rg-without-cost-center" -Policy "./step4-enforce/policy.json" -SubscriptionId $subscriptionId
$policy = Get-AzPolicyDefinition -Name "deny-rg-without-cost-center"
New-AzPolicyAssignment -Name "deny-rg-cost-center" -PolicyDefinition $policy -Scope "/subscriptions/$subscriptionId" -EnforcementMode DoNotEnforce

Write-Host "✅ Deployed in AUDIT mode. Monitor for 3-5 days before enabling enforcement." -ForegroundColor Yellow
```

**Monitor for 3-5 days**: Check what would have been blocked

---

### Week 7 Day 5: Enable Enforcement

```powershell
# FINAL CHECK before enabling
$violations = Get-AzLog -StartTime (Get-Date).AddDays(-5) | Where-Object {$_.Status.Value -eq "Failed" -and $_.Properties.Content.statusMessage -match "deny-rg-without-cost-center"}

if ($violations.Count -gt 0) {
    Write-Host "⚠️ Found $($violations.Count) violations in audit mode. Review before enforcing!" -ForegroundColor Red
    exit
}

# Enable enforcement
Write-Host "⚠️ ENABLING ENFORCEMENT - This will BLOCK deployments without Cost_Center" -ForegroundColor Red
Start-Sleep 10
Set-AzPolicyAssignment -Name "deny-rg-cost-center" -EnforcementMode Default

Write-Host "✅ ENFORCEMENT ACTIVE" -ForegroundColor Green
```

---

## One-Line Compliance Check

```powershell
# Check overall compliance
Get-AzPolicyState | Where-Object {$_.PolicyDefinitionName -match "cost-center"} | Group-Object PolicyDefinitionName,ComplianceState | Select-Object @{N='Policy';E={$_.Group[0].PolicyDefinitionName}}, @{N='State';E={$_.Group[0].ComplianceState}}, Count | Format-Table
```

---

## Emergency Rollback

If something goes wrong:

```powershell
# Disable enforcement immediately
Set-AzPolicyAssignment -Name "deny-rg-cost-center" -EnforcementMode DoNotEnforce

# Stop remediation tasks
Get-AzPolicyRemediation | Where-Object {$_.ProvisioningState -eq "Running"} | Stop-AzPolicyRemediation
```

---

## Resources

- **Full Documentation**: `README.md`
- **Detailed Timeline**: `DEPLOYMENT-ORDER.md`
- **Step-by-Step Guides**: `stepX-*/README.md`

---

## Support

**Author**: Anand Lakhera  
**Email**: anand.lakhera@ahead.com  
**Organization**: AHEAD - Cloud FinOps Team

For deployment assistance, contact via email or Slack #azure-governance.

---

**Remember**: 
- Normalize first (Steps 1-3)
- Communicate (2 weeks minimum)
- Enforce last (Step 4)

Good luck with your deployment! 🚀
