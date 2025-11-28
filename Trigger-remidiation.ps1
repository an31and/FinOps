<#
.SYNOPSIS
    Azure Policy Remediation Task Creator - PowerShell Runbook
    
.DESCRIPTION
    Creates remediation tasks for Cost_Center tag policies.
    Uses system-assigned managed identity for authentication.
    Compatible with Azure Automation (Az modules pre-installed).
    
.NOTES
    Requires: Az.PolicyInsights, Az.Accounts modules (pre-installed in Automation)
    RBAC Required: Policy Contributor, Tag Contributor
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "5635a156-fdb4-44db-9ef0-77d9a77483f4"
)

Write-Output "=============================================="
Write-Output "Policy Remediation Task Creator"
Write-Output "=============================================="
Write-Output "Subscription: $SubscriptionId"
Write-Output "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output ""

# Authenticate (Managed Identity in Automation, current context locally)
try {
    Write-Output "[1/4] Authenticating..."
    
    # Disable breaking changes warning
    Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
    
    # Check if running in Azure Automation
    if ($env:AUTOMATION_ASSET_ACCOUNTID) {
        Write-Output "  Running in Azure Automation - using Managed Identity"
        Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
        Write-Output "✅ Connected using Managed Identity"
    }
    else {
        Write-Output "  Running locally - using current Azure context"
        $context = Get-AzContext
        if (-not $context) {
            Write-Warning "Not logged in. Run: Connect-AzAccount"
            throw "No Azure context available"
        }
        Write-Output "✅ Using account: $($context.Account.Id)"
    }
    
    # Set subscription context
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    Write-Output "✅ Subscription context set"
}
catch {
    Write-Error "❌ Failed to authenticate: $_"
    Write-Error $_.Exception.Message
    throw
}

Write-Output ""
Write-Output "[2/4] Retrieving Policy Assignments..."

# Policy assignments to remediate (in order: Normalize → Inherit → Cleanup)
$policyAssignments = @(
    @{
        Name = 'assign-cost-center-normalize-v3'
        DisplayName = 'Cost_Center: Normalize Tags'
        Description = 'Remediate existing resources to normalize Cost_Center tag variations'
    },
    @{
        Name = 'assign-cost-center-inherit-v3'
        DisplayName = 'Cost_Center: Inherit from RG'
        Description = 'Remediate existing resources to inherit Cost_Center from resource group'
    },
    @{
        Name = 'assign-cost-center-cleanup-v3'
        DisplayName = 'Cost_Center: Remove Duplicates'
        Description = 'Remediate existing resources to remove duplicate Cost_Center tags'
    }
)

Write-Output "Found $($policyAssignments.Count) policy assignments to remediate"
Write-Output ""

Write-Output "[3/4] Creating Remediation Tasks..."

$successCount = 0
$failureCount = 0
$createdTasks = @()

foreach ($assignment in $policyAssignments) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $remediationName = "remediate-$($assignment.Name)-$timestamp"
    
    Write-Output ""
    Write-Output "Processing: $($assignment.DisplayName)"
    Write-Output "  Assignment: $($assignment.Name)"
    Write-Output "  Remediation: $remediationName"
    
    try {
        # Build the policy assignment ID
        $policyAssignmentId = "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/policyAssignments/$($assignment.Name)"
        
        Write-Output "  Assignment ID: $policyAssignmentId"
        
        # Verify assignment exists
        $policyAssignment = Get-AzPolicyAssignment -Id $policyAssignmentId -ErrorAction Stop
        
        if (-not $policyAssignment) {
            Write-Warning "  ⚠️  Assignment not found, skipping..."
            $failureCount++
            continue
        }
        
        # Create remediation task
        $remediation = Start-AzPolicyRemediation `
            -Name $remediationName `
            -PolicyAssignmentId $policyAssignmentId `
            -Scope "/subscriptions/$SubscriptionId" `
            -ResourceDiscoveryMode ExistingNonCompliant `
            -ErrorAction Stop
        
        Write-Output "  ✅ Created remediation task"
        Write-Output "     ID: $($remediation.Id)"
        Write-Output "     Status: $($remediation.ProvisioningState)"
        
        $createdTasks += [PSCustomObject]@{
            Name = $remediationName
            Assignment = $assignment.DisplayName
            Id = $remediation.Id
            Status = $remediation.ProvisioningState
        }
        
        $successCount++
        
        # Small delay to avoid throttling
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Warning "  ❌ Failed: $($_.Exception.Message)"
        $failureCount++
    }
}

Write-Output ""
Write-Output "=============================================="
Write-Output "SUMMARY"
Write-Output "=============================================="
Write-Output "✅ Successfully created: $successCount"
Write-Output "❌ Failed: $failureCount"
Write-Output ""

if ($createdTasks.Count -gt 0) {
    Write-Output "Created Remediation Tasks:"
    foreach ($task in $createdTasks) {
        Write-Output "  - $($task.Assignment)"
        Write-Output "    Name: $($task.Name)"
        Write-Output "    Status: $($task.Status)"
    }
}

Write-Output ""
Write-Output "=============================================="
Write-Output "NEXT STEPS"
Write-Output "=============================================="
Write-Output "1. Monitor remediation progress in Azure Portal:"
Write-Output "   Policy → Remediation → View remediation tasks"
Write-Output "2. Remediation runs asynchronously and may take time"
Write-Output "3. Check compliance state after completion"
Write-Output ""
Write-Output "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "=============================================="

# Return summary for automation job output
return [PSCustomObject]@{
    SubscriptionId = $SubscriptionId
    TotalTasks = $policyAssignments.Count
    SuccessCount = $successCount
    FailureCount = $failureCount
    CreatedTasks = $createdTasks
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
