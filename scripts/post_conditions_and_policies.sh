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
DEBUG=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

print_debug() {
    if [[ "$DEBUG" == true ]]; then
        echo -e "${YELLOW}[DEBUG]${NC} $1" >&2
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
    --debug               Enable debug output for troubleshooting
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

    # Debug mode for troubleshooting
    JF_URL=https://your-instance.jfrog.io BEARER_TOKEN=your-token $0 --debug

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
    
    print_debug "Extracting condition ID from response"
    print_debug "Response length: ${#response}"
    
    # Try to extract condition ID from JSON response - more portable approach
    if command -v jq >/dev/null 2>&1; then
        print_debug "Using jq to extract condition ID"
        condition_id=$(echo "$response" | jq -r '.id // empty')
    else
        print_debug "Using grep to extract condition ID"
        # More portable grep pattern
        condition_id=$(echo "$response" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    fi
    
    print_debug "Extracted condition ID: '$condition_id'"
    
    if [[ -z "$condition_id" ]]; then
        print_error "Failed to extract condition ID from API response"
        if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
            echo "Response: $response" >&2
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
    
    print_debug "Updating policy file: $policy_file with condition ID: $condition_id"
    
    # Create a temporary file in /tmp which should be writable
    temp_file=$(mktemp /tmp/policy_updated_XXXXXX.json)
    
    # First, let's try to read the file content to debug
    if [[ "$DEBUG" == true ]]; then
        print_debug "Original policy file content:"
        cat "$policy_file" >&2
        echo >&2
    fi
    
    # Update the condition_id field in the policy JSON
    if command -v jq >/dev/null 2>&1; then
        # Use jq if available for safer JSON manipulation
        print_debug "Using jq to update policy file"
        print_debug "Reading from: $policy_file"
        print_debug "Writing to: $temp_file"
        
        if ! cat "$policy_file" | jq --arg condition_id "$condition_id" '.condition_id = $condition_id' > "$temp_file"; then
            print_error "Failed to update policy file with jq: $policy_file"
            print_debug "jq error details: $?"
            rm -f "$temp_file"
            return 1
        fi
        
        # Verify the temp file was created and has content
        if [[ ! -s "$temp_file" ]]; then
            print_error "Temporary file is empty after jq processing"
            rm -f "$temp_file"
            return 1
        fi
        
        print_debug "Successfully created updated policy file with jq"
    else
        # Fallback to sed for basic replacement
        print_debug "Using sed to update policy file"
        if ! sed "s/\"condition_id\": \"[^\"]*\"/\"condition_id\": \"$condition_id\"/" "$policy_file" > "$temp_file"; then
            print_error "Failed to update policy file with sed: $policy_file"
            rm -f "$temp_file"
            return 1
        fi
        
        # Verify the temp file was created and has content
        if [[ ! -s "$temp_file" ]]; then
            print_error "Temporary file is empty after sed processing"
            rm -f "$temp_file"
            return 1
        fi
        
        print_debug "Successfully created updated policy file with sed"
    fi
    

    
    # Update the policy_file variable to point to the temporary file
    eval "$3=\"$temp_file\""  # Pass the new filename back to caller
    print_verbose "Created updated policy file '$temp_file' with condition ID: $condition_id"
    return 0
}

# Function to post condition file
post_condition() {
    set +e
    local condition_file="$1"
    local response
    local condition_id
    local http_code
    local masked_token="***"
    
    print_debug "Starting post_condition for file: $condition_file"
    print_verbose "Posting condition file: $condition_file" >&2
    
    # Debug: Show the curl command being executed (mask token)
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        print_verbose "Executing curl command:" >&2
        echo "curl -sS -w \"\\n%{http_code}\" \\" >&2
        echo "  -X POST \\" >&2
        echo "  -H \"Authorization: Bearer $masked_token\" \\" >&2
        echo "  -H \"Content-Type: application/json\" \\" >&2
        echo "  -d @\"$condition_file\" \\" >&2
        echo "  \"$JF_URL/xray/api/v1/curation/conditions\"" >&2
        echo >&2
        
        if [[ "$DEBUG" == true ]]; then
            print_debug "Condition file contents:" >&2
            cat "$condition_file" >&2
            echo >&2
        fi
    fi
    
    # Post condition to API (capture both stdout and stderr)
    print_debug "Executing curl command..."
    response=$(curl -sS -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $BEARER_TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$condition_file" \
        "$JF_URL/xray/api/v1/curation/conditions" 2>&1)
    
    local curl_exit_code=$?
    print_debug "Curl exit code: $curl_exit_code"
    
    if [[ $curl_exit_code -ne 0 ]]; then
        print_error "Curl command failed with exit code: $curl_exit_code" >&2
        print_error "Curl error: $response" >&2
        set -e
        return 1
    fi
    
    # Extract HTTP status code (last line) - more portable approach
    http_code=$(echo "$response" | tail -n1)
    # Remove HTTP status code from response - compatible with macOS
    response_body=$(echo "$response" | sed '$d')
    
    print_debug "HTTP Status Code: $http_code"
    print_debug "Response body length: ${#response_body}"
    
    # Always show the response for debugging
    print_verbose "HTTP Status Code: $http_code" >&2
    print_verbose "API Response:" >&2
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        echo "$response_body" >&2
        echo >&2
    fi
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        print_success "Condition posted successfully (HTTP $http_code)" >&2
        
        # Extract condition ID
        print_debug "Extracting condition ID from successful response"
        if [[ -z "$response_body" ]]; then
            print_debug "Empty response body, using condition ID from file"
            # If response body is empty, extract ID from the condition file
            if command -v jq >/dev/null 2>&1; then
                condition_id=$(jq -r '.id // empty' "$condition_file")
            else
                condition_id=$(grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' "$condition_file" | cut -d'"' -f4)
            fi
            if [[ -n "$condition_id" ]]; then
                print_debug "Using condition ID from file: $condition_id"
                echo "$condition_id"
                set -e
                return 0
            else
                print_error "Failed to extract condition ID from file" >&2
                set -e
                return 1
            fi
        elif condition_id=$(extract_condition_id "$response_body"); then
            print_debug "Successfully extracted condition ID: $condition_id"
            echo "$condition_id"
            set -e
            return 0
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
    
    print_debug "Starting post_policy for file: $policy_file"
    print_verbose "Posting policy file: $policy_file" >&2
    
    # Debug: Show the curl command being executed (mask token)
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        print_verbose "Executing curl command:" >&2
        echo "curl -sS -w \"\\n%{http_code}\" \\" >&2
        echo "  -X POST \\" >&2
        echo "  -H \"Authorization: Bearer $masked_token\" \\" >&2
        echo "  -H \"Content-Type: application/json\" \\" >&2
        echo "  -d @\"$policy_file\" \\" >&2
        echo "  \"$JF_URL/xray/api/v1/curation/policies\"" >&2
        echo >&2
        
        if [[ "$DEBUG" == true ]]; then
            print_debug "Policy file contents:" >&2
            cat "$policy_file" >&2
            echo >&2
        fi
    fi
    
    # Post policy to API (capture both stdout and stderr)
    print_debug "Executing curl command..."
    response=$(curl -sS -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $BEARER_TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$policy_file" \
        "$JF_URL/xray/api/v1/curation/policies" 2>&1)
    
    local curl_exit_code=$?
    print_debug "Curl exit code: $curl_exit_code"
    
    if [[ $curl_exit_code -ne 0 ]]; then
        print_error "Curl command failed with exit code: $curl_exit_code" >&2
        print_error "Curl error: $response" >&2
        set -e
        return 1
    fi
    
    # Extract HTTP status code (last line) - more portable approach
    http_code=$(echo "$response" | tail -n1)
    # Remove HTTP status code from response - compatible with macOS
    response_body=$(echo "$response" | sed '$d')
    
    print_debug "HTTP Status Code: $http_code"
    print_debug "Response body length: ${#response_body}"
    
    # Always show the response for debugging
    print_verbose "HTTP Status Code: $http_code" >&2
    print_verbose "API Response:" >&2
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
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
    # Use indexed array instead of associative array for better compatibility
    local condition_id_map=()
    local success_count=0
    local error_count=0
    
    print_debug "Starting process_files function"
    print_debug "Shell: $SHELL"
    print_debug "Bash version: $BASH_VERSION"
    print_debug "OS: $(uname -s)"
    print_debug "Directory: $DIRECTORY"
    
    # Find condition files - compatible with older bash versions
    print_debug "Finding condition files..."
    condition_files=($(find "$DIRECTORY" -name "*condition*.json" -type f))
    
    # Find policy files - compatible with older bash versions
    print_debug "Finding policy files..."
    policy_files=($(find "$DIRECTORY" -name "*policy*.json" -type f))
    
    print_debug "Found ${#condition_files[@]} condition files"
    print_debug "Found ${#policy_files[@]} policy files"
    
    # Debug: List all found files
    if [[ "$DEBUG" == true ]]; then
        echo "Condition files found:" >&2
        for file in "${condition_files[@]}"; do
            echo "  - $file" >&2
        done
        echo "Policy files found:" >&2
        for file in "${policy_files[@]}"; do
            echo "  - $file" >&2
        done
    fi
    
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
    set +e  # Temporarily disable exit on error for debugging
    for condition_file in "${condition_files[@]}"; do
        print_debug "Processing condition file: $condition_file"
        print_verbose "Processing condition file: $condition_file"
        
        local condition_id
        print_debug "About to call post_condition for: $condition_file"
        if condition_id=$(post_condition "$condition_file"); then
            # Store condition ID mapping using indexed array with delimiter
            condition_id_map+=("$condition_file:$condition_id")
            print_debug "Stored condition ID mapping: $condition_file -> $condition_id"
            print_verbose "Stored condition ID mapping: $condition_file -> $condition_id"
            ((success_count++))
            print_debug "Success count incremented to: $success_count"
        else
            print_error "Failed to post condition: $condition_file"
            ((error_count++))
            print_debug "Error count incremented to: $error_count"
        fi
        print_debug "Finished processing condition file: $condition_file"
    done
    set -e  # Re-enable exit on error
    
    print_debug "Phase 1 completed. Success: $success_count, Errors: $error_count"
    print_debug "Condition ID map size: ${#condition_id_map[@]}"
    print_debug "Condition ID map contents:"
    for mapping in "${condition_id_map[@]}"; do
        print_debug "  $mapping"
    done
    print_debug "About to start Phase 2"
    
    if [[ $error_count -gt 0 ]]; then
        print_warning "Phase 1 completed with $error_count errors"
    else
        print_success "Phase 1 completed successfully"
    fi
    
    # Phase 2: Update and post policies
    print_status "Phase 2: Updating and posting policies..."
    error_count=0
    
    for policy_file in "${policy_files[@]}"; do
        print_debug "Processing policy file: $policy_file"
        
        # Find corresponding condition file and get condition ID
        local condition_id=""
        local condition_file=""
        
        # Extract base name from policy file - more portable approach
        local base_name=$(basename "$policy_file")
        base_name="${base_name%-policy.json}"
        print_debug "Looking for matching condition for policy: $policy_file (base name: $base_name)"
        
        # Find matching condition file
        for mapping in "${condition_id_map[@]}"; do
            local cond_file="${mapping%:*}"
            local cond_id="${mapping#*:}"
            local cond_base_name=$(basename "$cond_file")
            cond_base_name="${cond_base_name%-condition.json}"
            
            print_debug "  Checking condition: $cond_file (base name: $cond_base_name)"
            
            if [[ "$cond_base_name" == "$base_name" ]]; then
                condition_id="$cond_id"
                condition_file="$cond_file"
                print_debug "  Found matching condition: $cond_file -> condition_id: $condition_id"
                break
            fi
        done
        
        if [[ -z "$condition_id" ]]; then
            print_error "No matching condition found for policy: $policy_file"
            print_error "Available condition mappings:"
            for mapping in "${condition_id_map[@]}"; do
                local cond_file="${mapping%:*}"
                local cond_id="${mapping#*:}"
                local cond_base_name=$(basename "$cond_file")
                cond_base_name="${cond_base_name%-condition.json}"
                print_error "  $cond_base_name -> $cond_id"
            done
            ((error_count++))
            continue
        fi
        
        # Update policy file with condition ID
        print_debug "About to update policy file: $policy_file"
        local updated_policy_file="$policy_file"
        if update_policy_with_condition_id "$policy_file" "$condition_id" updated_policy_file; then
            print_debug "Successfully updated policy file: $updated_policy_file"
            # Post updated policy
            print_debug "About to post policy: $updated_policy_file"
            if post_policy "$updated_policy_file"; then
                print_debug "Successfully posted policy: $updated_policy_file"
                ((success_count++))
                # Clean up temporary file if it was created
                if [[ "$updated_policy_file" != "$policy_file" ]]; then
                    rm -f "$updated_policy_file"
                    print_debug "Cleaned up temporary file: $updated_policy_file"
                fi
            else
                print_error "Failed to post policy: $updated_policy_file"
                ((error_count++))
                # Clean up temporary file on error
                if [[ "$updated_policy_file" != "$policy_file" ]]; then
                    rm -f "$updated_policy_file"
                    print_debug "Cleaned up temporary file on error: $updated_policy_file"
                fi
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
        --debug)
            DEBUG=true
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
    print_status "Debug: $DEBUG"
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