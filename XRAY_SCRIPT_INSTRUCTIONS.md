# Xray Script Execution Instructions

This document provides detailed instructions for running the Xray curation scripts to post conditions, policies, and GraphQL files to JFrog Xray and Catalog APIs.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Script Overview](#script-overview)
4. [Running post_conditions_and_policies.sh](#running-post_conditions_and_policiessh)
5. [Running post_graphql_to_catalog.sh](#running-post_graphql_to_catalogsh)
6. [Troubleshooting](#troubleshooting)
7. [Examples](#examples)

## Prerequisites

### 1. JFrog Platform Access
- Valid JFrog Artifactory/Xray instance URL
- Bearer token with appropriate permissions for:
  - Xray API access (for conditions and policies)
  - Catalog API access (for GraphQL files)
  - Repository read/write permissions

### 2. Required Labels
Before running the scripts, you must create the following labels in your JFrog instance using the Catalog API:

#### Create Allowed CVEs and Legal Labels
Create both required labels using a single GraphQL mutation:

```bash
curl --location 'https://your-instance.jfrog.io/catalog/api/v1/custom/graphql' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer YOUR_BEARER_TOKEN' \
--data '{"query":"mutation {\n   customCatalogLabel{\n       createCustomCatalogLabels(labels: [{name: \"allowed_cves\", description: \"Security Policy Test\"}, {name: \"allowed_legal\", description: \"Legal Policy Test\"}]) {\n           name\n           description\n       }\n   }\n}\n","variables":{}}'
```

**Important Notes:**
- Replace `https://your-instance.jfrog.io` with your actual JFrog instance URL
- Replace `YOUR_BEARER_TOKEN` with your actual bearer token
- This command creates both `allowed_cves` and `allowed_legal` labels in a single API call
- The labels are created with descriptions "Security Policy Test" and "Legal Policy Test" respectively

#### Verify Labels Created
After running the command, you can verify the labels were created successfully by checking the API response. A successful response should include the label names and descriptions.


### 3. Repository Setup
Ensure the following repositories are created and accessible. These repositories are specifically required based on the policy configuration:

#### Required Remote Repositories
The following repositories must be created and configured:

- `remote-pypi`
- `remote-pypi-everything`
- `remote-go`
- `remote-go-index`
- `remote-sum-go`
- `remote-dockerhub`
- `ubuntu`
- `remote-nuget-uipath`
- `remote-epel7-march2024`
- `remote-epel9`
- `remote-node-dist`
- `vg-docker-3rdparty-eval-inst`

## Environment Setup

### 1. Set Environment Variables
Set the required environment variables before running any scripts:

```bash
# Required: JFrog instance URL
export JF_URL="https://your-instance.jfrog.io"

# Required: Bearer token for authentication
export BEARER_TOKEN="your-bearer-token-here"
```

## Script Overview

### post_conditions_and_policies.sh
This script performs a two-phase process:
1. **Phase 1**: Posts condition JSON files to Xray curation conditions API
2. **Phase 2**: Updates policy files with real condition IDs and posts them to Xray curation policies API

### post_graphql_to_catalog.sh
This script posts GraphQL files to the JFrog Catalog API to associate package versions with allow labels.

## Running post_conditions_and_policies.sh

### Basic Usage
```bash
# Basic execution
./scripts/post_conditions_and_policies.sh

# With custom directory
./scripts/post_conditions_and_policies.sh -d /path/to/your/files

# With verbose output
./scripts/post_conditions_and_policies.sh -v

# Force execution without confirmation
./scripts/post_conditions_and_policies.sh -f
```

### Command Line Options
- `-d, --directory DIR`: Directory containing JSON files (default: `./output`)
- `-f, --force`: Force execution without confirmation
- `-v, --verbose`: Enable verbose output with API responses
- `-h, --help`: Show help message

### File Requirements
The script expects the following file structure in the specified directory:
```
output/
├── condition1-condition.json
├── condition1-policy.json
├── condition2-condition.json
├── condition2-policy.json
└── ...
```

**File Naming Convention:**
- Condition files must end with `-condition.json`
- Policy files must end with `-policy.json`
- Base names must match between corresponding condition and policy files

## Running post_graphql_to_catalog.sh

### Basic Usage
```bash
# Basic execution
./scripts/post_graphql_to_catalog.sh

# With custom directory
./scripts/post_graphql_to_catalog.sh -d /path/to/graphql/files

# With verbose output
./scripts/post_graphql_to_catalog.sh -v

# Force execution without confirmation
./scripts/post_graphql_to_catalog.sh -f
```

### Command Line Options
- `-d, --directory DIR`: Directory containing GraphQL files (default: `./output`)
- `-f, --force`: Force execution without confirmation
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

### File Requirements
The script expects GraphQL files (`.graphql` extension) in the specified directory:
```
output/
├── package1.graphql
├── package2.graphql
└── ...
```

## Examples

### Example 1: Complete Workflow
```bash
# 1. Set environment variables
export JF_URL="https://your-instance.jfrog.io"
export BEARER_TOKEN="your-token-here"

# 2. Run conditions and policies script
./scripts/post_conditions_and_policies.sh -d ./output -v

# 3. Run GraphQL to catalog script
./scripts/post_graphql_to_catalog.sh -d ./output -v
```

### Example 2: Custom Directory
```bash
# Use custom directory for files
./scripts/post_conditions_and_policies.sh -d /custom/path/to/files
./scripts/post_graphql_to_catalog.sh -d /custom/path/to/graphql
```

## Troubleshooting

### Common Issues

#### 1. Authentication Errors
**Error**: `401 Unauthorized` or `403 Forbidden`
**Solution**: 
- Verify your bearer token is valid and not expired
- Ensure the token has appropriate permissions
- Check JFrog URL is correct

```bash
# Test authentication
curl -H "Authorization: Bearer $BEARER_TOKEN" "$JF_URL/xray/api/v1/version"
```

#### 2. File Not Found Errors
**Error**: `No condition/policy files found`
**Solution**:
- Verify file naming convention (`-condition.json`, `-policy.json`)
- Check file permissions
- Ensure files are in the correct directory

```bash
# List files in directory
ls -la ./output/*.json
```

#### 3. API Response Errors
**Error**: `Failed to extract condition ID`
**Solution**:
- Enable verbose mode to see full API responses
- Check JSON structure in condition files
- Verify API endpoint is accessible

```bash
# Run with verbose output
./scripts/post_conditions_and_policies.sh -v
```

#### 4. Network Connectivity Issues
**Error**: `Connection refused` or timeout
**Solution**:
- Verify network connectivity to JFrog instance
- Check firewall settings
- Ensure JFrog URL is accessible from your network

```bash
# Test connectivity
ping your-instance.jfrog.io
curl -I "$JF_URL"
```

#### 5. Repository Access Issues
**Error**: `Repository not found` or `Access denied`
**Solution**:
- Verify all required repositories are created
- Check repository permissions for the bearer token
- Ensure Xray scanning is enabled on repositories

```bash
# List repositories
curl -H "Authorization: Bearer $BEARER_TOKEN" "$JF_URL/artifactory/api/repositories"
```

## Change History

7/14/2025 - Fix the repository mapping for Nexus Firewall.  
Firewall wavers refer to two repositories only:  "remote-npm-registry", "remote-maven-central"

