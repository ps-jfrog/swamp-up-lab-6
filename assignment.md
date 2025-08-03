## Challenge: Package Security with JFrog Curation - Proactive Supply Chain Defense

This lab demonstrates how JFrog Curation provides proactive defense mechanisms to gatekeep your software supply chain and block malicious packages before they reach your development teams..

### Lab Setup Overview:

Your lab environment comes pre-configured with:
* Access to the JFrog Platform UI for deeper insights
* Python Poetry package manager installed
* `lab2-maven-remote` and `lab2-pypi-remote` repositories with uploaded Webgoat application
* Access to Command Line with `jf cli` configured to connect to test JFrog Platform
* Pre-configured legal and security policies
---

### Step 1: Accessing Your JFrog Platform UI

1. Log into your [button label="JFrog Platform UI"](tab-0) and login using the provided credentials:

```md
			- User: admin
			- Password: Admin1234!
```
---

### Step 2: Review Curation Policies

**Login to Jfrog Platform UI [button label="JFrog Platform UI"](tab-0) with credentials provided earlier**

Navigate to Curation | Policies, and study `lab2-legal-policy` and `lab2-security-policy`
Review `Curation Policy Details`.  Notice `Curation Repositories List` declared in Policy Effectiveness field.

**Register repository with Curation**

Repository must be registered with Curation in order for Curation Policy to be configured.
In top menu, navigate to Administration, select Curation Settings | Remote Repositories from left menu.  make sure that Connected toggle is on for `lab2-pypi-remote`.

### Step 3: Developers experience accessing curated repositories

**Setup repository client**

In the top menue, click on your credential, select `Set Me Up` and follow instructions to configure client PyPi package manager.  Select `lab2-pypi-remote` repository when propmpted to specify repository.  Capture all the steps that should look similar to this

```bash
poetry config repositories.artifactory-lab2-pypi-remote https://psazuse.jfrog.io/artifactory/api/pypi/lab2-pypi-remote

poetry config http-basic.artifactory-lab2-pypi-remote alexsh@jfrog.com cmVmdGtu...

poetry config http-basic.lab2-pypi-remote alexsh@jfrog.com cmVmdGtu...

poetry source add lab2-pypi-remote https://psazuse.jfrog.io/artifactory/api/pypi/lab2-pypi-remote/simple
```

**Attempting to pull curated package**

Policy `lab2-security-policy` is configured to prevent developers from using PyPi packages with vulnerabilites with severety level higher than 8.

Try to access curated package
```bash
poetry add tensorflow==2.12.0 --source lab2-pypi-remote
```

Revew Latest Audit Events under Curation | Audit Events

### Step 4: Use labels to add a waver

Developer may request an exception to the policy for sperified pacakge.
One way to do it is to use package labels.

**Creating label for specific version of the package**

Under Catalog | Explore, locate `tensorflow` package, and select version `2.12.1`.
Locate `+Add Label` button and enter `allowed_cves`.  Make sure that Select Versions section specified `2.12.1`

Under Catalog | Explore, locate `keras` package, and select version `2.12.0`.
Locate `+Add Label` button and enter `allowed_cves`.  Make sure that Select Versions section specified `2.12.0`


Try to access curated package
```bash
poetry add tensorflow==2.12.1 --source lab2-pypi-remote 
```

Revew Latest Audit Events under Curation | Audit Events
You should see multiple tensorflow dependencies under `Approved` tab of Latest Audit Events screen