# Cost_Center Tag Governance - Deployment Order

**Author**: Anand Lakhera (anand.lakhera@ahead.com)  
**Version**: 1.0.0  
**Last Updated**: November 26, 2025

---

## Quick Reference: Deployment Timeline

```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1: SILENT NORMALIZATION (4 weeks)                     │
├─────────────────────────────────────────────────────────────┤
│ Week 1 → Deploy Step 1 (Normalize)                          │
│ Week 2 → Deploy Step 2 (Inherit)                            │
│ Week 3 → Deploy Step 3 (Cleanup)                            │
│ Week 4 → Validate & Generate Reports                        │
├─────────────────────────────────────────────────────────────┤
│ PHASE 2: TEAM COMMUNICATION (2 weeks)                       │
├─────────────────────────────────────────────────────────────┤
│ Week 5 → Announce enforcement, share templates              │
│ Week 6 → Office hours, final preparation                    │
├─────────────────────────────────────────────────────────────┤
│ PHASE 3: ENFORCEMENT (1 week+)                              │
├─────────────────────────────────────────────────────────────┤
│ Week 7 → Deploy Step 4 (Deny) in audit mode                 │
│         → Enable enforcement after validation                │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Silent Normalization

### Week 1: Step 1 - Normalize Tag Variations

**Policy**: `cost-center-normalize-v3`  
**File**: `step1-normalize/policy.json`  
**Effect**: Modify (non-blocking)  
**Target**: 95%+ compliance

**Day 1: Deploy**
```powershell
# Set variables
$subscriptionId = "YOUR-SUBSCRIPTION-ID"
$location = "eastus"

# Deploy and assign
./scripts/deploy-step1.ps1 -SubscriptionId $subscriptionId -Location $location
```

**Days 2-7: Monitor**
- [ ] Check remediation task progress daily
- [ ] Monitor compliance rate (target: 95%)
- [ ] Review Activity Log for errors
- [ ] Identify any blocked resources

**End of Week Checklist**:
- [ ] Compliance ≥ 95%
- [ ] No active errors in remediation task
- [ ] Validation report generated
- [ ] Ready to proceed to Step 2

---

### Week 2: Step 2 - Inherit from Resource Group

**Policy**: `cost-center-inherit-rg-v3`  
**File**: `step2-inherit/policy.json`  
**Effect**: Modify (non-blocking)  
**Target**: 98%+ compliance

**Prerequisites**:
- [ ] Step 1 compliance ≥ 95%
- [ ] Wait 24 hours after Step 1 deployment

**Day 1: Deploy**
```powershell
# Verify Step 1 compliance first
./scripts/check-compliance.ps1 -PolicyName "cost-center-normalize"

# If >= 95%, proceed
./scripts/deploy-step2.ps1 -SubscriptionId $subscriptionId -Location $location
```

**Days 2-7: Monitor**
- [ ] Check remediation task progress
- [ ] Monitor compliance rate (target: 98%)
- [ ] Verify tag inheritance working
- [ ] Check RG tags are valid

**End of Week Checklist**:
- [ ] Compliance ≥ 98%
- [ ] Resources inheriting from RGs successfully
- [ ] No inheritance errors
- [ ] Ready to proceed to Step 3

---

### Week 3: Step 3 - Cleanup Duplicate Tags

**Policy**: `cost-center-cleanup-v3`  
**File**: `step3-cleanup/policy.json`  
**Effect**: Modify (non-blocking)  
**Target**: 99%+ compliance, 0 duplicate tags

**Prerequisites**:
- [ ] Step 2 compliance ≥ 90%
- [ ] Wait 24 hours after Step 2 deployment

**Day 1: Deploy**
```powershell
# Verify Step 2 compliance
./scripts/check-compliance.ps1 -PolicyName "cost-center-inherit"

# If >= 90%, proceed
./scripts/deploy-step3.ps1 -SubscriptionId $subscriptionId -Location $location
```

**Days 2-7: Monitor**
- [ ] Check cleanup progress
- [ ] Verify no data loss (canonical tag preserved)
- [ ] Monitor for any remaining variations
- [ ] Validate compliance rate

**End of Week Checklist**:
- [ ] Compliance ≥ 99%
- [ ] Duplicate tags removed
- [ ] Only Cost_Center tag remains
- [ ] No cleanup errors

---

### Week 4: Validation & Reporting

**No new deployments - validation only**

**Tasks**:
- [ ] Generate comprehensive compliance report
- [ ] Document any remaining non-compliant resources
- [ ] Identify patterns in non-compliance
- [ ] Prepare metrics for team communication
- [ ] Create exemption process if needed

**Compliance Report Script**:
```powershell
./scripts/generate-compliance-report.ps1 -SubscriptionId $subscriptionId -OutputPath "./reports"
```

**Expected Results**:
- Overall compliance: 99%+
- Resources with Cost_Center: 99%+
- Resources with variations: <1%
- Ready for enforcement

**Go/No-Go Decision**:
- [ ] All three policies ≥ 99% compliant
- [ ] No critical errors in Activity Log
- [ ] Remaining non-compliance documented
- [ ] ✅ **APPROVED** to proceed to Phase 2

---

## Phase 2: Team Communication

### Week 5: Announcement & Enablement

**Tasks**:
- [ ] Send initial email announcement (see template in README)
- [ ] Share compliance metrics with teams
- [ ] Distribute template examples (ARM/Terraform)
- [ ] Publish self-service validation script
- [ ] Update internal documentation
- [ ] Schedule office hours for Week 6

**Email Checklist**:
- [ ] Current compliance state (99%+)
- [ ] Enforcement date announced (Week 7)
- [ ] Action items for teams
- [ ] Links to resources and examples
- [ ] Contact information for support

**Resources to Distribute**:
- [ ] `scripts/validate-my-compliance.ps1`
- [ ] ARM template example with Cost_Center
- [ ] Terraform module example with Cost_Center
- [ ] Valid Cost_Center value taxonomy
- [ ] Link to this documentation

---

### Week 6: Final Preparation

**Tasks**:
- [ ] Conduct office hours (Q&A sessions)
- [ ] Monitor ticket/Slack for questions
- [ ] Help teams update templates
- [ ] Test deployments in dev/test
- [ ] Final reminder email (enforcement in 1 week)
- [ ] Prepare rollback plan

**Office Hours Agenda**:
1. Overview of policy framework
2. Demonstration of policy behavior
3. Template update walkthrough
4. Q&A session
5. Troubleshooting common issues

**Final Checklist Before Enforcement**:
- [ ] All teams notified (minimum 2 weeks ago)
- [ ] Templates and examples distributed
- [ ] Validation script provided
- [ ] Support channels established
- [ ] Rollback plan documented
- [ ] ✅ **APPROVED** to proceed to enforcement

---

## Phase 3: Enforcement

### Week 7: Deploy Deny Policy

**Policy**: `deny-rg-without-cost-center`  
**File**: `step4-enforce/policy.json`  
**Effect**: Deny (BLOCKING)  
**Impact**: Will block RG creation without Cost_Center tag

⚠️ **WARNING**: This policy BLOCKS resource creation. Only proceed if Phase 2 is complete.

---

**Days 1-5: Audit Mode (DoNotEnforce)**

Deploy in audit mode first to catch any issues:

```powershell
./scripts/deploy-step4-audit.ps1 -SubscriptionId $subscriptionId
```

**Monitor**:
- [ ] Check Azure Activity Log daily
- [ ] Identify attempts that would be blocked
- [ ] Contact teams proactively if issues found
- [ ] Validate no production impact

**Daily Check**:
```powershell
./scripts/check-would-be-blocked.ps1 -SubscriptionId $subscriptionId -Days 1
```

**If Issues Found**:
1. Contact affected team immediately
2. Provide guidance to fix templates
3. Offer exemption if legitimate edge case
4. Wait for resolution before enabling enforcement

---

**Days 6-7: Enable Enforcement**

**Prerequisites**:
- [ ] 5 days of audit mode completed
- [ ] No unresolved issues in audit logs
- [ ] Teams ready for enforcement
- [ ] Rollback plan ready

**Enable Enforcement**:
```powershell
# Final confirmation prompt
./scripts/enable-enforcement.ps1 -SubscriptionId $subscriptionId
```

**Post-Deployment**:
- [ ] Monitor first 24 hours closely
- [ ] Check for blocked deployments
- [ ] Respond to support requests quickly
- [ ] Document any issues and resolutions

---

### Week 8+: Steady State Operations

**Ongoing Tasks**:
- [ ] Monitor compliance weekly
- [ ] Review exemption requests
- [ ] Update documentation as needed
- [ ] Quarterly policy review
- [ ] Team feedback collection

**Weekly Monitoring**:
```powershell
./scripts/weekly-compliance-check.ps1 -SubscriptionId $subscriptionId
```

**Monthly Review**:
- Compliance trends
- Exemption analysis
- Team feedback
- Policy effectiveness

**Quarterly Review**:
- [ ] Policy performance assessment
- [ ] Exemption renewal/removal
- [ ] Cost savings analysis
- [ ] Framework improvements

---

## Rollback Procedures

### If Issues Occur During Phase 1-3 (Remediation)

**Step 1: Pause Remediation**
```powershell
# Stop active remediation tasks
$remediations = Get-AzPolicyRemediation | Where-Object {$_.ProvisioningState -eq "Running"}
$remediations | ForEach-Object { 
    Stop-AzPolicyRemediation -Name $_.Name -ResourceGroupName $_.ResourceGroupName 
}
```

**Step 2: Set Policy to DoNotEnforce**
```powershell
Set-AzPolicyAssignment -Name "POLICY-NAME" -EnforcementMode DoNotEnforce
```

**Step 3: Investigate**
- Review Activity Log for errors
- Check affected resources
- Identify root cause
- Develop fix

**Step 4: Resume**
- Fix issues
- Re-enable policy
- Create new remediation task
- Monitor closely

---

### If Issues Occur During Phase 3 (Enforcement)

**Emergency Rollback**:
```powershell
# Immediately disable enforcement
Set-AzPolicyAssignment -Name "deny-rg-cost-center" -EnforcementMode DoNotEnforce
```

**Communication**:
```
Subject: Azure Policy Enforcement Temporarily Disabled

Teams,

We've temporarily disabled Cost_Center tag enforcement while we address [ISSUE].

Impact: Resource Group creation is currently allowed without Cost_Center tag.
Expected Resolution: [TIMELINE]
Action Required: Continue adding Cost_Center tags as planned.

Updates will be shared in #azure-governance.

Thanks,
Cloud FinOps Team
```

**Root Cause Analysis**:
1. Document the issue
2. Identify affected resources
3. Determine if policy issue or edge case
4. Develop permanent fix
5. Re-enable after testing

---

## Deployment Scripts

All scripts referenced in this document are located in `./scripts/` directory:

- `deploy-step1.ps1` - Deploy Step 1 (Normalize)
- `deploy-step2.ps1` - Deploy Step 2 (Inherit)
- `deploy-step3.ps1` - Deploy Step 3 (Cleanup)
- `deploy-step4-audit.ps1` - Deploy Step 4 in audit mode
- `enable-enforcement.ps1` - Enable Step 4 enforcement
- `check-compliance.ps1` - Check policy compliance
- `generate-compliance-report.ps1` - Generate comprehensive report
- `validate-my-compliance.ps1` - Self-service validation for teams
- `check-would-be-blocked.ps1` - Check audit mode logs
- `weekly-compliance-check.ps1` - Weekly monitoring

---

## Success Metrics

### Phase 1 Success
- Step 1: ≥95% compliance
- Step 2: ≥98% compliance  
- Step 3: ≥99% compliance
- Duration: 4 weeks or less

### Phase 2 Success
- 100% of teams notified
- Templates distributed
- Zero unresolved questions
- Duration: 2 weeks minimum

### Phase 3 Success
- Zero blocked legitimate deployments
- 100% new RG compliance
- <5 exemptions in first month
- Smooth transition to enforcement

---

## Contact & Support

**Policy Owner**: Anand Lakhera  
**Email**: anand.lakhera@ahead.com  
**Team**: Cloud FinOps Engineering  
**Organization**: AHEAD

**For Deployment Support**:
- Primary: anand.lakhera@ahead.com
- Slack: #azure-governance
- Office Hours: [Schedule TBD]

---

**Last Updated**: November 26, 2025  
**Version**: 1.0.0
