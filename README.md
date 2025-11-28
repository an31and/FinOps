# Cost_Center Tag Governance Framework

**Author**: Anand Lakhera (anand.lakhera@ahead.com)  
**Version**: 1.0.0  
**Last Updated**: November 26, 2025  
**Organization**: AHEAD

---

## Overview

Complete enterprise-grade Azure Policy framework for Cost_Center tag governance across 400,000+ resources. This framework implements a **normalize-first, enforce-later** approach to achieve 99%+ tag compliance without disrupting team operations.

### Design Philosophy

This framework follows a team-friendly approach:

1. ✅ **Normalize First**: Fix existing issues silently via remediation
2. ✅ **Communicate**: Give teams time to update templates and CI/CD
3. ✅ **Enforce Last**: Block non-compliant resources only after preparation

**Why This Order?**
- Prevents blocking teams during normalization
- Achieves high compliance before enforcement
- Provides measurable success metrics
- Allows proper team enablement and communication

---

## Policy Architecture

### 4-Step Sequential Framework

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Silent Normalization (Weeks 1-4)                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Step 1: Normalize Tag Variations                           │
│  ├─ Converts: Cost-Center, CostCenter, etc. → Cost_Center   │
│  ├─ Effect: Modify (non-blocking)                           │
│  └─ Target: 95%+ compliance                                 │
│         ↓ Wait 24 hours                                      │
│                                                              │
│  Step 2: Inherit from Resource Group                        │
│  ├─ Copies Cost_Center from RG to resources                 │
│  ├─ Effect: Modify (non-blocking)                           │
│  └─ Target: 98%+ compliance                                 │
│         ↓ Wait 24 hours                                      │
│                                                              │
│  Step 3: Remove Duplicate Variations                        │
│  ├─ Cleans up after Steps 1 & 2 complete                    │
│  ├─ Effect: Modify (non-blocking)                           │
│  └─ Target: 99%+ compliance, 0 duplicate tags               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Team Communication (Weeks 5-6)                     │
├─────────────────────────────────────────────────────────────┤
│  • Share compliance metrics with teams                       │
│  • Provide updated ARM/Terraform templates                   │
│  • Announce enforcement date (minimum 2 weeks notice)        │
│  • Conduct office hours and Q&A sessions                     │
│  • Enable self-service validation tools                      │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: Enforcement (Week 7+)                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Step 4: Deny RG without Cost_Center                        │
│  ├─ Day 1-5: Deploy in DoNotEnforce (audit mode)            │
│  ├─ Day 6-7: Enable Default mode (enforcement)              │
│  ├─ Effect: Deny (BLOCKING)                                 │
│  └─ Result: 100% compliance on all NEW resources            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Policies

### Step 1: Normalize Tag Variations
**File**: `step1-normalize/policy.json`  
**Policy Name**: `cost-center-normalize-v3`  
**Effect**: Modify  
**Deploy**: Week 1 (FIRST)

**Purpose**: Converts 8 common Cost_Center tag variations into the canonical `Cost_Center` format.

**Handled Variations**:
- `Cost-Center` → `Cost_Center`
- `CostCenter` → `Cost_Center`
- `Cost Centre` → `Cost_Center`
- `costcentre` → `Cost_Center`
- `Cost-Centre` → `Cost_Center`
- `Cost Center` → `Cost_Center`
- `Cost_ Center` → `Cost_Center`
- `cost-center` → `Cost_Center`

**Key Features**:
- Priority chain handles multiple variations (uses first non-empty value)
- Excludes Resource Groups to prevent conflicts
- Only operates when canonical tag is missing
- Validates source tags are non-empty

---

### Step 2: Inherit from Resource Group
**File**: `step2-inherit/policy.json`  
**Policy Name**: `cost-center-inherit-rg-v3`  
**Effect**: Modify  
**Deploy**: Week 2 (SECOND - after Step 1 reaches 95% compliance)

**Purpose**: Automatically copies `Cost_Center` tag from parent Resource Group to resources that don't have any Cost_Center variation.

**Key Features**:
- Only acts when resource has NO Cost_Center variations
- Validates RG tag is non-empty before copying
- Uses `addOrReplace` for idempotent operation
- Prevents overwriting existing tags

**Fixed in v1.0.0**: Changed operation from `add` to `addOrReplace` for safer remediation in race condition scenarios.

---

### Step 3: Remove Duplicate Variations
**File**: `step3-cleanup/policy.json`  
**Policy Name**: `cost-center-cleanup-v3`  
**Effect**: Modify  
**Deploy**: Week 3 (THIRD - after Step 2 reaches 90% compliance)

**Purpose**: Removes all tag variations after canonical `Cost_Center` tag is established, ensuring single source of truth.

**Key Features**:
- Only removes duplicates when canonical tag exists and is non-empty
- Removes all 8 variations in a single remediation
- Safe sequencing prevents data loss
- Final cleanup step in normalization

---

### Step 4: Deny Resource Group Creation
**File**: `step4-enforce/policy.json`  
**Policy Name**: `deny-rg-without-cost-center`  
**Effect**: Deny  
**Deploy**: Week 7+ (LAST - ONLY after team communication)

**Purpose**: Prevents creation of new Resource Groups without `Cost_Center` tag, ensuring all future resources inherit the tag.

**Key Features**:
- Uses `mode: All` (required for RG-level policies)
- Parameterized tag name for reusability
- Simple, effective denial logic
- Blocks problem at source

**⚠️ WARNING**: This policy BLOCKS resource creation. Deploy ONLY after:
1. Steps 1-3 achieve 99%+ compliance
2. Teams receive minimum 2 weeks notice
3. Templates and CI/CD pipelines are updated
4. Testing in DoNotEnforce mode for 3-5 days

---

## Deployment Guide

### Prerequisites

- Azure PowerShell Az module installed
- Appropriate RBAC permissions:
  - `Policy Contributor` role at target scope
  - `User Access Administrator` for role assignments
- Target subscription or Management Group identified

### Phase 1: Silent Normalization (Weeks 1-4)

#### Week 1: Step 1 - Normalize

```powershell
# Variables
$subscriptionId = "5635a156-fdb4-44db-9ef0-77d9a77483f4"
$location = "eastus"

# Set context
Set-AzContext -SubscriptionId $subscriptionId

# 1. Deploy Policy Definition
New-AzPolicyDefinition `
    -Name "cost-center-normalize-v3" `
    -Policy "./step1-normalize/policy.json" `
    -SubscriptionId $subscriptionId `
    -Verbose

# 2. Assign Policy
$policy = Get-AzPolicyDefinition -Name "cost-center-normalize-v3"
$assignment = New-AzPolicyAssignment `
    -Name "cost-center-normalize" `
    -DisplayName "Cost_Center: Normalize Tag Variations" `
    -PolicyDefinition $policy `
    -Scope "/subscriptions/$subscriptionId" `
    -Location $location `
    -AssignIdentity `
    -Verbose

# 3. Assign Tag Contributor Role to Managed Identity
New-AzRoleAssignment `
    -ObjectId $assignment.Identity.PrincipalId `
    -RoleDefinitionName "Tag Contributor" `
    -Scope "/subscriptions/$subscriptionId"

# 4. Wait 5 minutes for RBAC propagation
Write-Host "Waiting 5 minutes for RBAC propagation..." -ForegroundColor Yellow
Start-Sleep -Seconds 300

# 5. Create Remediation Task
Start-AzPolicyRemediation `
    -Name "remediate-normalize-$(Get-Date -Format 'yyyyMMdd-HHmm')" `
    -PolicyAssignmentId $assignment.PolicyAssignmentId `
    -ResourceDiscoveryMode ReEvaluateCompliance `
    -AsJob

Write-Host "✅ Step 1 deployed. Monitor compliance for next 7 days." -ForegroundColor Green
Write-Host "Target: 95%+ compliance before proceeding to Step 2" -ForegroundColor Yellow
```

**Monitor Compliance**:
```powershell
# Check compliance rate
$state = Get-AzPolicyState -PolicyAssignmentName "cost-center-normalize"
$compliance = $state | Group-Object ComplianceState | 
    Select-Object Name, Count, @{N='Percentage';E={[math]::Round(($_.Count/$state.Count)*100,2)}}
$compliance | Format-Table -AutoSize
```

---

#### Week 2: Step 2 - Inherit

**Prerequisites**: Step 1 compliance ≥ 95%

```powershell
# 1. Verify Step 1 Compliance
$step1State = Get-AzPolicyState -PolicyAssignmentName "cost-center-normalize"
$step1Compliance = ($step1State | Where-Object {$_.ComplianceState -eq "Compliant"}).Count / $step1State.Count * 100
Write-Host "Step 1 Compliance: $([math]::Round($step1Compliance,2))%" -ForegroundColor Cyan

if ($step1Compliance -lt 95) {
    Write-Host "⚠️ Wait for Step 1 to reach 95% compliance before deploying Step 2" -ForegroundColor Red
    exit
}

# 2. Deploy Policy Definition
New-AzPolicyDefinition `
    -Name "cost-center-inherit-rg-v3" `
    -Policy "./step2-inherit/policy.json" `
    -SubscriptionId $subscriptionId `
    -Verbose

# 3. Assign Policy
$policy = Get-AzPolicyDefinition -Name "cost-center-inherit-rg-v3"
$assignment = New-AzPolicyAssignment `
    -Name "cost-center-inherit" `
    -DisplayName "Cost_Center: Inherit from Resource Group" `
    -PolicyDefinition $policy `
    -Scope "/subscriptions/$subscriptionId" `
    -Location $location `
    -AssignIdentity `
    -Verbose

# 4. Assign Tag Contributor Role
New-AzRoleAssignment `
    -ObjectId $assignment.Identity.PrincipalId `
    -RoleDefinitionName "Tag Contributor" `
    -Scope "/subscriptions/$subscriptionId"

# 5. Wait and Create Remediation
Start-Sleep -Seconds 300
Start-AzPolicyRemediation `
    -Name "remediate-inherit-$(Get-Date -Format 'yyyyMMdd-HHmm')" `
    -PolicyAssignmentId $assignment.PolicyAssignmentId `
    -ResourceDiscoveryMode ReEvaluateCompliance `
    -AsJob

Write-Host "✅ Step 2 deployed. Monitor for next 7 days." -ForegroundColor Green
Write-Host "Target: 98%+ compliance before proceeding to Step 3" -ForegroundColor Yellow
```

---

#### Week 3: Step 3 - Cleanup

**Prerequisites**: Step 2 compliance ≥ 90%

```powershell
# 1. Verify Step 2 Compliance
$step2State = Get-AzPolicyState -PolicyAssignmentName "cost-center-inherit"
$step2Compliance = ($step2State | Where-Object {$_.ComplianceState -eq "Compliant"}).Count / $step2State.Count * 100
Write-Host "Step 2 Compliance: $([math]::Round($step2Compliance,2))%" -ForegroundColor Cyan

if ($step2Compliance -lt 90) {
    Write-Host "⚠️ Wait for Step 2 to reach 90% compliance before deploying Step 3" -ForegroundColor Red
    exit
}

# 2. Deploy Policy Definition
New-AzPolicyDefinition `
    -Name "cost-center-cleanup-v3" `
    -Policy "./step3-cleanup/policy.json" `
    -SubscriptionId $subscriptionId `
    -Verbose

# 3. Assign Policy
$policy = Get-AzPolicyDefinition -Name "cost-center-cleanup-v3"
$assignment = New-AzPolicyAssignment `
    -Name "cost-center-cleanup" `
    -DisplayName "Cost_Center: Remove Duplicate Variations" `
    -PolicyDefinition $policy `
    -Scope "/subscriptions/$subscriptionId" `
    -Location $location `
    -AssignIdentity `
    -Verbose

# 4. Assign Tag Contributor Role
New-AzRoleAssignment `
    -ObjectId $assignment.Identity.PrincipalId `
    -RoleDefinitionName "Tag Contributor" `
    -Scope "/subscriptions/$subscriptionId"

# 5. Wait and Create Remediation
Start-Sleep -Seconds 300
Start-AzPolicyRemediation `
    -Name "remediate-cleanup-$(Get-Date -Format 'yyyyMMdd-HHmm')" `
    -PolicyAssignmentId $assignment.PolicyAssignmentId `
    -ResourceDiscoveryMode ReEvaluateCompliance `
    -AsJob

Write-Host "✅ Step 3 deployed. Monitor for next 7 days." -ForegroundColor Green
Write-Host "Target: 99%+ compliance and 0 duplicate tags" -ForegroundColor Yellow
```

---

#### Week 4: Validation

```powershell
# Generate Comprehensive Compliance Report
$allPolicies = @("cost-center-normalize", "cost-center-inherit", "cost-center-cleanup")
$report = @()

foreach ($policyName in $allPolicies) {
    $state = Get-AzPolicyState -PolicyAssignmentName $policyName
    $total = $state.Count
    $compliant = ($state | Where-Object {$_.ComplianceState -eq "Compliant"}).Count
    $nonCompliant = ($state | Where-Object {$_.ComplianceState -eq "NonCompliant"}).Count
    
    $report += [PSCustomObject]@{
        Policy = $policyName
        Total = $total
        Compliant = $compliant
        NonCompliant = $nonCompliant
        ComplianceRate = [math]::Round(($compliant/$total)*100, 2)
    }
}

$report | Format-Table -AutoSize

# Check for any remaining tag variations
$resources = Get-AzResource
$withVariations = $resources | Where-Object {
    $_.Tags.Keys -match 'Cost-Center|CostCenter|Cost Centre|costcentre|Cost-Centre|Cost Center|Cost_ Center|cost-center'
}

Write-Host "`nResources with tag variations remaining: $($withVariations.Count)" -ForegroundColor $(if($withVariations.Count -eq 0){"Green"}else{"Yellow"})
```

---

### Phase 2: Team Communication (Weeks 5-6)

#### Week 5: Announcement

**Email Template**:

```
Subject: Action Required: Cost_Center Tag Standardization - Enforcement Date [SPECIFIC DATE]

Hi Team,

We've successfully normalized Cost_Center tags across our Azure environment and achieved 99%+ compliance through automated remediation.

WHAT'S CHANGING:
Starting [ENFORCEMENT DATE], all new Resource Groups MUST include a Cost_Center tag.
Deployments without this tag will be BLOCKED.

CURRENT STATE:
✅ 99% of existing resources now have the Cost_Center tag
✅ All tag variations normalized to Cost_Center
✅ Automated inheritance from Resource Groups is active

ACTION REQUIRED BY [DATE - 2 WEEKS FROM NOW]:
1. Update ARM/Bicep templates to include Cost_Center tag on Resource Groups
2. Update Terraform modules to include Cost_Center tag
3. Update CI/CD pipelines to validate tags before deployment
4. Test in dev/test subscriptions

RESOURCES PROVIDED:
• Self-Service Validation Script: [link to script below]
• ARM Template Example: [link]
• Terraform Module Example: [link]
• Valid Cost_Center Values: [link to your taxonomy]
• Policy Documentation: [link to this README]

NEED HELP?
• Office Hours: [dates/times]
• Slack Channel: #azure-governance
• Contact: Anand Lakhera (anand.lakhera@ahead.com)

Thank you for maintaining our Azure governance standards.

Best regards,
Cloud FinOps Team
```

---

#### Self-Service Validation Script

Create `scripts/validate-my-compliance.ps1`:

```powershell
<#
.SYNOPSIS
    Self-service Cost_Center tag compliance validation
.DESCRIPTION
    Teams can run this script to check their resources before enforcement
.PARAMETER SubscriptionId
    Target subscription ID
.PARAMETER ResourceGroupName
    Optional: specific Resource Group to check (wildcards supported)
.EXAMPLE
    .\validate-my-compliance.ps1 -SubscriptionId "xxxxx"
.AUTHOR
    Anand Lakhera (anand.lakhera@ahead.com)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "*"
)

# Set context
Write-Host "`nConnecting to subscription..." -ForegroundColor Cyan
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Cost_Center Tag Compliance Check                       ║" -ForegroundColor Cyan
Write-Host "║     Subscription: $SubscriptionId                          " -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Check Resource Groups
Write-Host "Checking Resource Groups..." -ForegroundColor Yellow
$rgs = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like $ResourceGroupName }
$rgsMissingTag = $rgs | Where-Object { -not $_.Tags.ContainsKey('Cost_Center') }

$rgCompliance = if ($rgs.Count -gt 0) { 
    [math]::Round((($rgs.Count - $rgsMissingTag.Count) / $rgs.Count) * 100, 2) 
} else { 
    0 
}

Write-Host "  Total Resource Groups: $($rgs.Count)"
Write-Host "  Missing Cost_Center: $($rgsMissingTag.Count)" -ForegroundColor $(if($rgsMissingTag.Count -eq 0){"Green"}else{"Red"})
Write-Host "  Compliance Rate: $rgCompliance%" -ForegroundColor $(if($rgCompliance -ge 95){"Green"}else{"Red"})

if ($rgsMissingTag.Count -gt 0) {
    Write-Host "`n  ⚠️  Resource Groups missing Cost_Center tag:" -ForegroundColor Red
    $rgsMissingTag | Select-Object ResourceGroupName, Location | Format-Table -AutoSize
}

# Check Resources
Write-Host "`nChecking Resources..." -ForegroundColor Yellow
$resources = Get-AzResource -ResourceGroupName $ResourceGroupName
$resourcesMissingTag = $resources | Where-Object { -not $_.Tags.ContainsKey('Cost_Center') }

$resCompliance = if ($resources.Count -gt 0) { 
    [math]::Round((($resources.Count - $resourcesMissingTag.Count) / $resources.Count) * 100, 2) 
} else { 
    0 
}

Write-Host "  Total Resources: $($resources.Count)"
Write-Host "  Missing Cost_Center: $($resourcesMissingTag.Count)" -ForegroundColor $(if($resourcesMissingTag.Count -eq 0){"Green"}else{"Yellow"})
Write-Host "  Compliance Rate: $resCompliance%" -ForegroundColor $(if($resCompliance -ge 95){"Green"}else{"Yellow"})

if ($resourcesMissingTag.Count -gt 0 -and $resourcesMissingTag.Count -le 20) {
    Write-Host "`n  ℹ️  Sample resources missing Cost_Center:" -ForegroundColor Yellow
    $resourcesMissingTag | Select-Object -First 20 Name, ResourceType, ResourceGroupName | Format-Table -AutoSize
}

# Check for tag variations
Write-Host "`nChecking for tag variations..." -ForegroundColor Yellow
$variations = @('Cost-Center', 'CostCenter', 'Cost Centre', 'costcentre', 'Cost-Centre', 'Cost Center', 'Cost_ Center', 'cost-center')
$withVariations = $resources | Where-Object {
    $tags = $_.Tags.Keys
    $variations | Where-Object { $tags -contains $_ }
}

Write-Host "  Resources with old variations: $($withVariations.Count)" -ForegroundColor $(if($withVariations.Count -eq 0){"Green"}else{"Yellow"})

# Summary
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    COMPLIANCE SUMMARY                       ║" -ForegroundColor Cyan
Write-Host "╠════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  Resource Groups: $rgCompliance%                                     " -ForegroundColor $(if($rgCompliance -ge 95){"Green"}else{"Red"})
Write-Host "║  Resources:       $resCompliance%                                     " -ForegroundColor $(if($resCompliance -ge 95){"Green"}else{"Yellow"})
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

if ($rgCompliance -lt 100) {
    Write-Host "⚠️  ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "   1. Add Cost_Center tag to all Resource Groups listed above"
    Write-Host "   2. Resources will automatically inherit from Resource Groups within 24 hours"
    Write-Host "   3. Re-run this script after 24 hours to verify compliance"
    Write-Host "`n📚 Documentation: [your-documentation-link]"
    Write-Host "💬 Support: Slack #azure-governance or anand.lakhera@ahead.com`n"
}
else {
    Write-Host "✅ READY FOR ENFORCEMENT" -ForegroundColor Green
    Write-Host "   Your resources are 100% compliant. No action needed.`n" -ForegroundColor Green
}
```

---

### Phase 3: Enforcement (Week 7+)

#### Week 7: Deploy Deny Policy

**⚠️ CRITICAL**: Only proceed if:
- [ ] Steps 1-3 show 99%+ compliance
- [ ] Teams received 2+ weeks notice
- [ ] Templates and CI/CD pipelines updated
- [ ] Validation script distributed to teams

```powershell
# 1. Deploy Policy Definition
New-AzPolicyDefinition `
    -Name "deny-rg-without-cost-center" `
    -Policy "./step4-enforce/policy.json" `
    -SubscriptionId $subscriptionId `
    -Verbose

# 2. Assign in AUDIT mode first (DoNotEnforce)
$policy = Get-AzPolicyDefinition -Name "deny-rg-without-cost-center"
$assignment = New-AzPolicyAssignment `
    -Name "deny-rg-cost-center" `
    -DisplayName "Deny Resource Group without Cost_Center Tag" `
    -PolicyDefinition $policy `
    -Scope "/subscriptions/$subscriptionId" `
    -EnforcementMode DoNotEnforce `
    -Verbose

Write-Host "✅ Step 4 deployed in AUDIT mode (DoNotEnforce)" -ForegroundColor Green
Write-Host "Monitor for 3-5 days to identify any issues before enabling enforcement" -ForegroundColor Yellow
```

**Monitor Audit Logs** (Days 1-5):
```powershell
# Check what WOULD have been blocked
$auditLogs = Get-AzLog -StartTime (Get-Date).AddDays(-5) -MaxRecord 1000 | 
    Where-Object { 
        $_.Authorization.Action -eq "Microsoft.Resources/subscriptions/resourceGroups/write" -and
        $_.Properties.Content.responseBody -match "deny-rg-without-cost-center"
    }

Write-Host "RG creations that WOULD have been blocked: $($auditLogs.Count)" -ForegroundColor Yellow
$auditLogs | Select-Object @{N='Time';E={$_.EventTimestamp}}, Caller, ResourceGroupName | Format-Table
```

**Enable Enforcement** (Day 6-7):
```powershell
# After validation period, enable enforcement
Write-Host "`n⚠️  ENABLING ENFORCEMENT - Resource Groups without Cost_Center will be BLOCKED" -ForegroundColor Red
Write-Host "Press Ctrl+C to cancel, or wait 10 seconds to proceed..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Set-AzPolicyAssignment `
    -Name "deny-rg-cost-center" `
    -EnforcementMode Default

Write-Host "`n✅ ENFORCEMENT ACTIVE" -ForegroundColor Green
Write-Host "All new Resource Groups must have Cost_Center tag" -ForegroundColor Green
```

---

## Monitoring & Reporting

### Compliance Dashboard (Azure Resource Graph)

```kusto
// Overall Compliance Rate
PolicyResources
| where type == "microsoft.policyinsights/policystates"
| where properties.policyDefinitionName in (
    "cost-center-normalize-v3",
    "cost-center-inherit-rg-v3", 
    "cost-center-cleanup-v3"
)
| extend 
    PolicyName = tostring(properties.policyDefinitionName),
    ComplianceState = tostring(properties.complianceState),
    ResourceId = tolower(tostring(properties.resourceId))
| summarize 
    Total = dcount(ResourceId),
    Compliant = dcountif(ResourceId, ComplianceState == "Compliant"),
    NonCompliant = dcountif(ResourceId, ComplianceState == "NonCompliant")
    by PolicyName
| extend ComplianceRate = round((Compliant * 100.0) / Total, 2)
| project PolicyName, Total, Compliant, NonCompliant, ComplianceRate
| order by PolicyName asc
```

### Resources Missing Cost_Center

```kusto
// Find resources still missing Cost_Center tag
Resources
| where type !~ "microsoft.resources/subscriptions/resourcegroups"
| where isempty(tags['Cost_Center']) or isnull(tags['Cost_Center'])
| project 
    ResourceName = name,
    ResourceType = type,
    ResourceGroup = resourceGroup,
    Location = location,
    SubscriptionId = subscriptionId,
    Tags = tags
| order by ResourceGroup asc, ResourceType asc
| take 100
```

### Tag Variations Still Present

```kusto
// Identify resources with duplicate tag variations
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
| project 
    name,
    type,
    resourceGroup,
    Cost_Center = tags['Cost_Center'],
    VariationTags = pack_all()
| take 100
```

### Compliance Trend Over Time

```kusto
// Track compliance improvement over time
PolicyResources
| where type == "microsoft.policyinsights/policystates"
| where properties.policyDefinitionName == "cost-center-normalize-v3"
| extend 
    ComplianceState = tostring(properties.complianceState),
    ResourceId = tolower(tostring(properties.resourceId)),
    Timestamp = todatetime(properties.timestamp)
| summarize 
    Total = dcount(ResourceId),
    Compliant = dcountif(ResourceId, ComplianceState == "Compliant")
    by bin(Timestamp, 1d)
| extend ComplianceRate = (Compliant * 100.0) / Total
| project Timestamp, ComplianceRate
| order by Timestamp asc
| render timechart
```

---

## Troubleshooting

### Common Issues

#### Issue: Remediation Task Fails with "Forbidden"
**Cause**: Managed Identity doesn't have Tag Contributor role  
**Solution**:
```powershell
$assignment = Get-AzPolicyAssignment -Name "cost-center-normalize"
New-AzRoleAssignment `
    -ObjectId $assignment.Identity.PrincipalId `
    -RoleDefinitionName "Tag Contributor" `
    -Scope "/subscriptions/$subscriptionId"
```

#### Issue: Policy Shows "Not Started" Compliance State
**Cause**: Policy needs time to evaluate  
**Solution**: Wait 15-30 minutes for initial evaluation, then check compliance

#### Issue: Resources Not Inheriting from RG
**Cause**: Step 2 policy hasn't evaluated yet OR RG missing Cost_Center  
**Solution**:
```powershell
# Check if RG has the tag
$rg = Get-AzResourceGroup -Name "YourRG"
$rg.Tags['Cost_Center']

# Trigger policy re-evaluation
Start-AzPolicyComplianceScan -ResourceGroupName "YourRG"
```

#### Issue: Duplicate Tags Not Being Removed
**Cause**: Step 3 waiting for canonical Cost_Center to exist  
**Solution**: Ensure Steps 1 & 2 are complete and compliant first

---

## Policy Exemptions

For resources that cannot comply (rare cases):

```powershell
# Create exemption for specific resource
New-AzPolicyExemption `
    -Name "exemption-legacy-system" `
    -DisplayName "Legacy System - Manual Tag Management" `
    -PolicyAssignment $assignment `
    -Scope "/subscriptions/$subscriptionId/resourceGroups/legacy-rg/providers/Microsoft.Compute/virtualMachines/legacy-vm" `
    -ExemptionCategory Waiver `
    -Description "Legacy system with custom tag management. Reviewed quarterly." `
    -ExpiresOn (Get-Date).AddMonths(6)
```

**Best Practices**:
- Always set expiration date (review quarterly/semi-annually)
- Document reason in Description
- Use `Waiver` category (business decision) or `Mitigated` (compensating control exists)
- Minimize exemptions to maintain governance

---

## Success Criteria

### Phase 1 Completion (Week 4)
- [ ] Step 1: ≥95% compliance (normalized tags)
- [ ] Step 2: ≥98% compliance (inherited tags)
- [ ] Step 3: ≥99% compliance, <1% with duplicate tags
- [ ] No policy errors in Activity Log
- [ ] Comprehensive compliance report generated

### Phase 2 Completion (Week 6)
- [ ] Teams notified with 2+ weeks notice
- [ ] Template examples distributed
- [ ] Self-service validation script provided
- [ ] Office hours conducted
- [ ] Enforcement date confirmed and communicated

### Phase 3 Completion (Week 8)
- [ ] Step 4 deployed and enforcing
- [ ] 0 RGs created without Cost_Center tag
- [ ] 100% compliance on new resources
- [ ] Exception process documented and operational
- [ ] Quarterly review scheduled

---

## Maintenance

### Quarterly Review
- Review exemptions and renew/remove as appropriate
- Analyze compliance trends
- Update valid Cost_Center values if taxonomy changes
- Review and optimize remediation tasks
- Update team documentation

### Policy Updates
When updating policies:
1. Test changes in non-production subscription
2. Version policies (increment to 1.1.0, 2.0.0, etc.)
3. Update metadata with change log
4. Communicate changes to teams
5. Deploy with phased rollout

---

## ARM/Terraform Examples

### ARM Template Example

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "resourceGroupName": {
      "type": "string"
    },
    "costCenter": {
      "type": "string",
      "metadata": {
        "description": "Cost Center for financial tracking (e.g., CC-1001)"
      }
    }
  },
  "resources": [
    {
      "type": "Microsoft.Resources/resourceGroups",
      "apiVersion": "2021-04-01",
      "name": "[parameters('resourceGroupName')]",
      "location": "eastus",
      "tags": {
        "Cost_Center": "[parameters('costCenter')]",
        "ManagedBy": "Terraform",
        "Environment": "Production"
      }
    }
  ]
}
```

### Terraform Example

```hcl
# Resource Group with mandatory Cost_Center tag
resource "azurerm_resource_group" "example" {
  name     = "rg-example-prod"
  location = "East US"

  tags = {
    Cost_Center = var.cost_center  # Required by policy
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# Variable definition
variable "cost_center" {
  description = "Cost Center for financial tracking (e.g., CC-1001)"
  type        = string
  
  validation {
    condition     = can(regex("^CC-[0-9]{4}$", var.cost_center))
    error_message = "Cost_Center must be in format CC-#### (e.g., CC-1001)"
  }
}
```

---

## Support & Contact

**Author**: Anand Lakhera  
**Email**: anand.lakhera@ahead.com  
**Organization**: AHEAD  
**Team**: Cloud FinOps Engineering

**For Support**:
- Slack: #azure-governance
- Email: anand.lakhera@ahead.com
- Office Hours: [Schedule TBD]

---

## Version History

### v1.0.0 (November 26, 2025)
- Initial release
- 4-policy framework with sequential deployment
- Fixed Step 2 operation from `add` to `addOrReplace`
- Comprehensive deployment guide
- Self-service validation tools
- Team communication templates

---

## License & Usage

This policy framework is internal to AHEAD. For questions about external use or adaptation, contact anand.lakhera@ahead.com.

---

**End of Documentation**
