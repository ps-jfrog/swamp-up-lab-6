#!/bin/bash

# Post Conditions and Policies to Xray API
# This script posts condition JSON files to the Xray curation conditions API
# and policy JSON files to the Xray curation policies API.
# It extracts condition IDs from the conditions API response and updates
# policy files with the real condition IDs before posting to the policies API.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DIRECTORY="./output"
FORCE=false
VERBOSE=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Post condition and policy JSON files to Xray API.

OPTIONS:
    -d, --directory DIR    Directory containing JSON files (default: ./output)
    -f, --force           Force execution without confirmation
    -v, --verbose         Enable verbose output with API responses
    -h, --help            Show this help message

ENVIRONMENT VARIABLES:
    JF_URL         JFrog instance URL (required)
    BEARER_TOKEN   Bearer token for authentication (required)

EXAMPLES:
    # Basic usage
    JF_URL=https://your-instance.jfrog.io BEARER_TOKEN=your-token $0

    # With custom directory and verbose output
    JF_URL=https://your-instance.jfrog.io BEARER_TOKEN=your-token $0 -d ./output -v

    # Force execution without confirmation
    JF_URL=https://your-instance.jfrog.io BEARER_TOKEN=your-token $0 -f

EOF
}

# Function to validate environment variables
validate_env() {
    if [[ -z "$JF_URL" ]]; then
        print_error "JF_URL environment variable is required"
        exit 1
    fi

    if [[ -z "$BEARER_TOKEN" ]]; then
        print_error "BEARER_TOKEN environment variable is required"
        exit 1
    fi

    # Remove trailing slash from JF_URL if present
    JF_URL="${JF_URL%/}"
}

# Function to validate directory
validate_directory() {
    if [[ ! -d "$DIRECTORY" ]]; then
        print_error "Directory '$DIRECTORY' does not exist"
        exit 1
    fi
}

# Function to extract condition ID from API response
extract_condition_id() {
    local response="$1"
    local condition_id
    
    # Try to extract condition ID from JSON response
    condition_id=$(echo "$response" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    
    if [[ -z "$condition_id" ]]; then
        print_error "Failed to extract condition ID from API response"
        if [[ "$VERBOSE" == true ]]; then
            echo "Response: $response"
        fi
        return 1
    fi
    
    echo "$condition_id"
}

# Function to update policy file with condition ID
update_policy_with_condition_id() {
    local policy_file="$1"
    local condition_id="$2"
    local temp_file
    
    temp_file=$(mktemp)
    
    # Update the condition_id field in the policy JSON
    if command -v jq >/dev/null 2>&1; then
        # Use jq if available for safer JSON manipulation
        jq --arg condition_id "$condition_id" '.condition_id = $condition_id' "$policy_file" > "$temp_file"
    else
        # Fallback to sed for basic replacement
        sed "s/\"condition_id\": \"[^\"]*\"/\"condition_id\": \"$condition_id\"/" "$policy_file" > "$temp_file"
    fi
    
    mv "$temp_file" "$policy_file"
    print_verbose "Updated policy file '$policy_file' with condition ID: $condition_id"
}

# Function to post condition file
post_condition() {
    set +e
    local condition_file="$1"
    local response
    local condition_id
    local http_code
    local masked_token="***"
    
    print_verbose "Posting condition file: $condition_file" >&2
    
    # Debug: Show the curl command being executed (mask token)
    if [[ "$VERBOSE" == true ]]; then
        print_verbose "Executing curl command:" >&2
        echo "curl -sS -w \"\\n%{http_code}\" \\" >&2
        echo "  -X POST \\" >&2
        echo "  -H \"Authorization: Bearer $masked_token\" \\" >&2
        echo "  -H \"Content-Type: application/json\" \\" >&2
        echo "  -d @\"$condition_file\" \\" >&2
        echo "  \"$JF_URL/xray/api/v1/curation/conditions\"" >&2
        echo >&2
        
        print_verbose "Condition file contents:" >&2
        cat "$condition_file" >&2
        echo >&2
    fi
    
    # Post condition to API (capture both stdout and stderr)
    response=$(curl -sS -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $BEARER_TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$condition_file" \
        "$JF_URL/xray/api/v1/curation/conditions" 2>&1)
    
    # Extract HTTP status code (last line) - compatible with both Linux and macOS
    http_code=$(echo "$response" | tail -n1)
    # Remove HTTP status code from response - compatible with both Linux and macOS
    response_body=$(echo "$response" | sed '$d')
    
    # Always show the response for debugging
    print_verbose "HTTP Status Code: $http_code" >&2
    print_verbose "API Response:" >&2
    if [[ "$VERBOSE" == true ]]; then
        echo "$response_body" >&2
        echo >&2
    fi
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        print_success "Condition posted successfully (HTTP $http_code)" >&2
        
        # Extract condition ID
        condition_id=$(extract_condition_id "$response_body")
        if [[ $? -eq 0 ]]; then
            echo "$condition_id"
        else
            print_error "Failed to extract condition ID from response" >&2
            set -e
            return 1
        fi
    else
        print_error "Failed to post condition (HTTP $http_code)" >&2
        print_error "Error details: $response_body" >&2
        set -e
        return 1
    fi
    set -e
}

# Function to post policy file
post_policy() {
    set +e
    local policy_file="$1"
    local http_code
    local response
    local masked_token="***"
    local policy_name=$(basename "$policy_file")
    
    print_verbose "Posting policy file: $policy_file" >&2
    
    # Debug: Show the curl command being executed (mask token)
    if [[ "$VERBOSE" == true ]]; then
        print_verbose "Executing curl command:" >&2
        echo "curl -sS -w \"\\n%{http_code}\" \\" >&2
        echo "  -X POST \\" >&2
        echo "  -H \"Authorization: Bearer $masked_token\" \\" >&2
        echo "  -H \"Content-Type: application/json\" \\" >&2
        echo "  -d @\"$policy_file\" \\" >&2
        echo "  \"$JF_URL/xray/api/v1/curation/policies\"" >&2
        echo >&2
        
        print_verbose "Policy file contents:" >&2
        cat "$policy_file" >&2
        echo >&2
    fi
    
    # Post policy to API (capture both stdout and stderr)
    response=$(curl -sS -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $BEARER_TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$policy_file" \
        "$JF_URL/xray/api/v1/curation/policies" 2>&1)
    
    # Extract HTTP status code (last line) - compatible with both Linux and macOS
    http_code=$(echo "$response" | tail -n1)
    # Remove HTTP status code from response - compatible with both Linux and macOS
    response_body=$(echo "$response" | sed '$d')
    
    # Always show the response for debugging
    print_verbose "HTTP Status Code: $http_code" >&2
    print_verbose "API Response:" >&2
    if [[ "$VERBOSE" == true ]]; then
        echo "$response_body" >&2
        echo >&2
    fi
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        print_success "Policy '$policy_name' posted successfully (HTTP $http_code)" >&2
        set -e
        return 0
    else
        print_error "Failed to post policy (HTTP $http_code)" >&2
        print_error "Error details: $response_body" >&2
        set -e
        return 1
    fi
    set -e
}

# Function to process files
process_files() {
    local condition_files
    local policy_files
    local condition_id_map=()
    local success_count=0
    local error_count=0
    
    # Find condition files
    condition_files=($(find "$DIRECTORY" -name "*condition*.json" -type f))
    
    # Find policy files
    policy_files=($(find "$DIRECTORY" -name "*policy*.json" -type f))
    
    if [[ ${#condition_files[@]} -eq 0 ]]; then
        print_warning "No condition files found in '$DIRECTORY'"
        return 0
    fi
    
    if [[ ${#policy_files[@]} -eq 0 ]]; then
        print_warning "No policy files found in '$DIRECTORY'"
        return 0
    fi
    
    print_status "Found ${#condition_files[@]} condition files and ${#policy_files[@]} policy files"
    
    # Phase 1: Post conditions and collect condition IDs
    print_status "Phase 1: Posting conditions..."
    for condition_file in "${condition_files[@]}"; do
        print_verbose "Processing condition file: $condition_file"
        if condition_id=$(post_condition "$condition_file"); then
            # Store condition ID mapping (filename -> condition_id)
            condition_id_map+=("$condition_file:$condition_id")
            print_verbose "Stored condition ID mapping: $condition_file -> $condition_id"
            ((success_count++))
        else
            print_error "Failed to post condition: $condition_file"
            ((error_count++))
        fi
    done
    
    if [[ $error_count -gt 0 ]]; then
        print_warning "Phase 1 completed with $error_count errors"
    else
        print_success "Phase 1 completed successfully"
    fi
    
    # Phase 2: Update and post policies
    print_status "Phase 2: Updating and posting policies..."
    error_count=0
    
    for policy_file in "${policy_files[@]}"; do
        # Find corresponding condition file and get condition ID
        local condition_id=""
        local condition_file=""
        
        # Extract base name from policy file (remove -policy.json suffix)
        local base_name=$(basename "$policy_file" | sed 's/-policy\.json$//')
        print_verbose "Looking for matching condition for policy: $policy_file (base name: $base_name)" >&2
        
        # Find matching condition file
        for mapping in "${condition_id_map[@]}"; do
            local cond_file="${mapping%:*}"
            local cond_id="${mapping#*:}"
            local cond_base_name=$(basename "$cond_file" | sed 's/-condition\.json$//')
            
            print_verbose "  Checking condition: $cond_file (base name: $cond_base_name)" >&2
            
            if [[ "$cond_base_name" == "$base_name" ]]; then
                condition_id="$cond_id"
                condition_file="$cond_file"
                print_verbose "  Found matching condition: $cond_file -> condition_id: $condition_id" >&2
                break
            fi
        done
        
        if [[ -z "$condition_id" ]]; then
            print_error "No matching condition found for policy: $policy_file" >&2
            print_error "Available condition mappings:" >&2
            for mapping in "${condition_id_map[@]}"; do
                local cond_file="${mapping%:*}"
                local cond_id="${mapping#*:}"
                local cond_base_name=$(basename "$cond_file" | sed 's/-condition\.json$//')
                print_error "  $cond_base_name -> $cond_id" >&2
            done
            ((error_count++))
            continue
        fi
        
        # Update policy file with condition ID
        if update_policy_with_condition_id "$policy_file" "$condition_id"; then
            # Post updated policy
            if post_policy "$policy_file"; then
                ((success_count++))
            else
                ((error_count++))
            fi
        else
            print_error "Failed to update policy file: $policy_file"
            ((error_count++))
        fi
    done
    
    # Summary
    echo
    if [[ $error_count -eq 0 ]]; then
        print_success "All files processed successfully! ($success_count total)"
    else
        print_warning "Processing completed with $error_count errors ($success_count successful)"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            DIRECTORY="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_status "Starting conditions and policies posting process..."
    print_status "Directory: $DIRECTORY"
    print_status "JFrog URL: $JF_URL"
    print_status "Verbose: $VERBOSE"
    print_status "Force: $FORCE"
    
    # Validate environment and directory
    validate_env
    validate_directory
    
    # Show files that will be processed
    local condition_files=($(find "$DIRECTORY" -name "*condition*.json" -type f))
    local policy_files=($(find "$DIRECTORY" -name "*policy*.json" -type f))
    
    if [[ ${#condition_files[@]} -eq 0 ]] && [[ ${#policy_files[@]} -eq 0 ]]; then
        print_error "No condition or policy files found in '$DIRECTORY'"
        exit 1
    fi
    
    echo
    print_status "Files to be processed:"
    if [[ ${#condition_files[@]} -gt 0 ]]; then
        echo "  Condition files (${#condition_files[@]}):"
        for file in "${condition_files[@]}"; do
            echo "    - $(basename "$file")"
        done
    fi
    
    if [[ ${#policy_files[@]} -gt 0 ]]; then
        echo "  Policy files (${#policy_files[@]}):"
        for file in "${policy_files[@]}"; do
            echo "    - $(basename "$file")"
        done
    fi
    echo
    
    # Confirm execution unless forced
    if [[ "$FORCE" != true ]]; then
        echo -n "Do you want to proceed? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_status "Operation cancelled"
            exit 0
        fi
    fi
    
    # Process files
    process_files
}

# Run main function
main "$@" 