## Lab 3: Package Security with JFrog Curation - Proactive Supply Chain Defense

### Lab Overview

**Lab Name:** "AI/ML Package Security with JFrog Curation - Proactive Supply Chain Defense"

**Description:** 
This lab demonstrates how JFrog Curation provides proactive defense mechanisms to gatekeep your software supply chain and block malicious packages before they reach your development teams.

Participants will learn to configure JFrog Curation on remote repositories, create security and legal policies, monitor audit logs, and experience real-time blocking of malicious packages through various client tools including JFrog CLI, NPM, and PyPI clients.

### Learning Objectives

By the end of this lab, participants will be able to:
- Configure JFrog Curation on remote repositories for AI/ML package sources
- Create and manage security and legal curation policies
- Monitor and analyze curation audit logs for compliance and security insights
- Experience real-time package blocking through multiple client tools
- Implement proactive supply chain security measures for AI/ML development

### Lab Setup Overview

Your lab environment comes pre-configured with:
* Access to the JFrog Platform UI for policy management and monitoring
* Pre-configured remote repositories for PyPI, NPM, and Hugging Face
* Sample malicious packages for testing curation policies
* JFrog CLI, NPM, and Python clients for demonstrating package consumption
* Access to Command Line with `jf cli` configured to connect to test JFrog Platform

---

### Step 1: Accessing Your JFrog Platform UI

1. Log into your [button label="JFrog Platform UI"](tab-0) and login using the provided credentials:

```md
			- User: admin
			- Password: Admin1234!
```

2. Navigate to **Administration** → **Repositories** to verify the following remote repositories are configured:
   - `remote-pypi` - PyPI packages
   - `remote-npm-registry` - NPM packages  
   - `remote-huggingface` - Hugging Face models

---

### Step 2: Understanding the AI/ML Security Challenge

**Scenario:** Your organization has seen a 300% increase in AI/ML development, with teams consuming thousands of packages from PyPI and Hugging Face. Recent security incidents have highlighted the need for proactive supply chain security.

**Current Threats:**
- Malicious packages with typosquatting names (e.g., `tens0rflow` instead of `tensorflow`)
- Packages with embedded malware or backdoors
- Packages violating license compliance requirements
- Packages with known vulnerabilities

**Your Mission:** Configure JFrog Curation to proactively block these threats before they reach your development teams.

---

### Step 3: Configuring JFrog Curation on Remote Repositories

1. **Enable Curation on PyPI Repository**

Navigate to **Administration** → **Repositories** → **remote-pypi** → **Advanced** → **Curation**

Enable the following settings:
- ✅ **Enable Curation**
- ✅ **Block on Policy Violation**
- ✅ **Log All Requests**

2. **Enable Curation on NPM Repository**

Navigate to **Administration** → **Repositories** → **remote-npm-registry** → **Advanced** → **Curation**

Enable the same settings as above.

3. **Verify Curation Status**

In [button label="IDE Terminal"](tab-2), verify curation is enabled:

```run,wrap
jf rt curl -X GET "/api/repositories/remote-pypi" | jq '.curation'
```

```run,wrap
jf rt curl -X GET "/api/repositories/remote-npm-registry" | jq '.curation'
```

---

### Step 4: Creating Security Curation Policies

1. **Navigate to Curation Policies**

Go to **Administration** → **Curation** → **Policies**

2. **Create Security Policy for Malicious Packages**

Click **Create Policy** and configure:

**Policy Name:** `ai-ml-security-policy`

**Policy Type:** Security

**Conditions:**
- Package name contains known malicious patterns
- Package has known CVE vulnerabilities
- Package is flagged by security scanners

**Actions:**
- Block package download
- Log violation details
- Send alert to security team

3. **Create Legal Policy for License Compliance**

**Policy Name:** `ai-ml-legal-policy`

**Policy Type:** Legal

**Conditions:**
- Package license is not in approved list
- Package has license conflicts
- Package violates organizational license requirements

**Actions:**
- Block package download
- Log violation details
- Require legal review

---

### Step 5: Testing Curation Policies with Malicious Packages

1. **Test Malicious PyPI Package**

In [button label="IDE Terminal"](tab-2), attempt to install a known malicious package:

```run,wrap
pip install --index-url http://localhost:8081/artifactory/api/pypi/remote-pypi/simple/ tens0rflow
```

**Expected Result:** Package should be blocked by curation policy with a clear error message.

2. **Test Malicious NPM Package**

```run,wrap
npm install --registry http://localhost:8081/artifactory/api/npm/remote-npm-registry/ malici0us-package
```

**Expected Result:** Package should be blocked by curation policy.

3. **Test JFrog CLI Package Download**

```run,wrap
jf rt dl --repo remote-pypi --pattern "tens0rflow*" --flat
```

**Expected Result:** Download should be blocked with curation violation message.

---

### Step 6: Monitoring Curation Audit Logs

1. **Access Curation Audit Logs**

Navigate to **Administration** → **Curation** → **Audit Logs**

2. **Review Blocked Requests**

Filter by **Status: Blocked** to see all blocked package requests.

3. **Analyze Policy Violations**

Click on individual entries to see:
- Package details
- Policy that triggered the block
- Timestamp and user information
- Detailed violation reason

4. **Export Audit Data**

In [button label="IDE Terminal"](tab-2), export curation audit logs:

```run,wrap
jf rt curl -X GET "/api/curation/audit-logs" -H "Content-Type: application/json" > curation-audit-logs.json
```

5. **Analyze Audit Data**

```run,wrap
cat curation-audit-logs.json | jq '.auditLogs[] | select(.status == "BLOCKED") | {package: .packageName, policy: .policyName, reason: .violationReason, timestamp: .timestamp}'
```

---

### Step 7: Real-World Client Integration Testing

1. **Configure NPM Client for Curation Testing**

Create `.npmrc` file in [button label="IDE"](tab-1):

```json
registry=http://localhost:8081/artifactory/api/npm/remote-npm-registry/
_auth=YOUR_AUTH_TOKEN
email=your-email@company.com
```

2. **Test NPM Package Installation**

```run,wrap
npm install express
```

**Expected Result:** Should succeed (legitimate package)

```run,wrap
npm install express-malware
```

**Expected Result:** Should be blocked by curation policy

3. **Configure Python Client for Curation Testing**

Create `pip.conf` file in [button label="IDE"](tab-1):

```ini
[global]
index-url = http://localhost:8081/artifactory/api/pypi/remote-pypi/simple/
trusted-host = localhost:8081
```

4. **Test PyPI Package Installation**

```run,wrap
pip install requests
```

**Expected Result:** Should succeed (legitimate package)

```run,wrap
pip install requests-malware
```

**Expected Result:** Should be blocked by curation policy

---

### Step 8: Advanced Curation Configuration

1. **Create Custom Curation Rules**

Navigate to **Administration** → **Curation** → **Rules**

Create a custom rule for AI/ML specific packages:

**Rule Name:** `ai-ml-custom-rule`

**Pattern:** `*tensorflow*, *pytorch*, *huggingface*`

**Action:** Enhanced scanning and validation

2. **Configure Package Allow Lists**

Navigate to **Administration** → **Curation** → **Allow Lists**

Add trusted packages:
- `tensorflow`
- `torch`
- `transformers`
- `numpy`

3. **Set Up Automated Notifications**

Configure email notifications for curation violations:
- **Recipients:** security-team@company.com
- **Trigger:** Any curation policy violation
- **Format:** Detailed violation report

---

### Step 9: Performance Monitoring and Optimization

1. **Monitor Curation Performance**

In [button label="IDE Terminal"](tab-2), check curation performance metrics:

```run,wrap
jf rt curl -X GET "/api/curation/metrics" | jq '.'
```

2. **Analyze Response Times**

```run,wrap
jf rt curl -X GET "/api/curation/audit-logs" | jq '.auditLogs[] | {package: .packageName, responseTime: .responseTime, status: .status}'
```

3. **Optimize Policy Rules**

Based on performance data, optimize policy rules for:
- Faster response times
- Reduced false positives
- Better coverage of threats

---

### Step 10: Compliance Reporting

1. **Generate Curation Compliance Report**

In [button label="IDE Terminal"](tab-2):

```run,wrap
jf rt curl -X POST "/api/curation/reports/compliance" -H "Content-Type: application/json" -d '{"startDate": "2024-01-01", "endDate": "2024-12-31", "format": "json"}' > curation-compliance-report.json
```

2. **Review Compliance Metrics**

```run,wrap
cat curation-compliance-report.json | jq '.summary'
```

3. **Export Detailed Violations**

```run,wrap
cat curation-compliance-report.json | jq '.violations[] | {package: .packageName, policy: .policyName, severity: .severity, timestamp: .timestamp}'
```

---

### Step 11: Integration with CI/CD Pipelines

1. **Configure JFrog CLI for CI/CD**

Create a CI/CD script that checks packages before deployment:

```bash
#!/bin/bash
# Check package against curation policies
jf rt dl --repo remote-pypi --pattern "$PACKAGE_NAME*" --flat
if [ $? -ne 0 ]; then
    echo "Package $PACKAGE_NAME blocked by curation policy"
    exit 1
fi
echo "Package $PACKAGE_NAME approved by curation"
```

2. **Test CI/CD Integration**

```run,wrap
PACKAGE_NAME="tensorflow" && jf rt dl --repo remote-pypi --pattern "$PACKAGE_NAME*" --flat
```

**Expected Result:** Should succeed for legitimate packages

```run,wrap
PACKAGE_NAME="tens0rflow" && jf rt dl --repo remote-pypi --pattern "$PACKAGE_NAME*" --flat
```

**Expected Result:** Should fail for malicious packages

---

### Step 12: Advanced Threat Detection

1. **Configure Behavioral Analysis**

Set up policies to detect:
- Packages with unusual download patterns
- Packages with suspicious metadata
- Packages from newly created accounts

2. **Implement Machine Learning-Based Detection**

Configure ML-based policies for:
- Anomaly detection in package behavior
- Pattern recognition for malicious packages
- Risk scoring based on multiple factors

---

### Lab Summary and Key Takeaways

**What You've Accomplished:**
- ✅ Configured JFrog Curation on remote repositories
- ✅ Created security and legal curation policies
- ✅ Tested real-time package blocking
- ✅ Monitored and analyzed audit logs
- ✅ Integrated curation with multiple client tools
- ✅ Set up compliance reporting and monitoring

**Key Benefits Demonstrated:**
- **Proactive Defense:** Block malicious packages before they reach developers
- **Compliance:** Ensure license and legal requirements are met
- **Visibility:** Complete audit trail of all package requests
- **Integration:** Seamless integration with existing development workflows
- **Performance:** Minimal impact on development velocity

**Next Steps for Your Organization:**
1. Deploy curation policies across all package repositories
2. Train development teams on curation workflows
3. Set up automated monitoring and alerting
4. Integrate curation into CI/CD pipelines
5. Regular review and optimization of policies

---

## Notes
- All curation audit logs are available in JFrog Platform UI under **Administration** → **Curation** → **Audit Logs**
- Policy violations are logged with detailed information for compliance and security analysis
- Curation policies can be customized based on your organization's specific security and compliance requirements
- Performance impact is typically minimal (< 100ms additional latency per request) 