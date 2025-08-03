#!/bin/bash

# Script to post GraphQL files to JFrog Catalog API
# This script associates all versions of each package listed to the allow label

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --directory DIR    Directory containing GraphQL files (default: ./output)"
    echo "  -f, --force           Force execution without confirmation"
    echo "  -v, --verbose         Enable verbose output"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  JF_URL               JFrog instance URL (required)"
    echo "  BEARER_TOKEN         Bearer token for authentication (required)"
    echo ""
    echo "Example:"
    echo "  JF_URL=https://your-instance.jfrog.io BEARER_TOKEN=your-token $0"
    echo "  JF_URL=https://your-instance.jfrog.io BEARER_TOKEN=your-token $0 -d ./output -v"
}

# Default values
GRAPHQL_DIR="./output"
FORCE=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            GRAPHQL_DIR="$2"
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
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to check environment variables
check_environment() {
    if [[ -z "$JF_URL" ]]; then
        print_error "JF_URL environment variable is required"
        echo "Please set JF_URL to your JFrog instance URL"
        echo "Example: export JF_URL=https://your-instance.jfrog.io"
        exit 1
    fi
    
    if [[ -z "$BEARER_TOKEN" ]]; then
        print_error "BEARER_TOKEN environment variable is required"
        echo "Please set BEARER_TOKEN to your authentication token"
        echo "Example: export BEARER_TOKEN=your-token"
        exit 1
    fi
    
    # Remove trailing slash from JF_URL if present
    JF_URL="${JF_URL%/}"
    
    print_success "Environment variables validated"
    print_status "JFrog URL: $JF_URL"
    print_status "Bearer token: ${BEARER_TOKEN:0:10}..."
}

# Function to check if directory exists and contains GraphQL files
check_graphql_files() {
    if [[ ! -d "$GRAPHQL_DIR" ]]; then
        print_error "Directory '$GRAPHQL_DIR' does not exist"
        exit 1
    fi
    
    # Find all .graphql files
    local all_graphql_files=($(find "$GRAPHQL_DIR" -name "*.graphql" -type f))
    
    if [[ ${#all_graphql_files[@]} -eq 0 ]]; then
        print_warning "No GraphQL files found in '$GRAPHQL_DIR'"
        exit 0
    fi
    
    # Sort files: package-labels files (containing versions) first, then others
    local package_labels_files=()
    local other_files=()
    
    for file in "${all_graphql_files[@]}"; do
        if [[ "$(basename "$file")" == *"package-labels.graphql" ]]; then
            package_labels_files+=("$file")
        else
            other_files+=("$file")
        fi
    done
    
    # Combine arrays: package-labels files first, then others
    GRAPHQL_FILES=("${package_labels_files[@]}" "${other_files[@]}")
    
    print_success "Found ${#GRAPHQL_FILES[@]} GraphQL file(s)"
    print_status "Package-labels files (with versions): ${#package_labels_files[@]}"
    print_status "Other GraphQL files: ${#other_files[@]}"
    
    if [[ "$VERBOSE" == true ]]; then
        if [[ ${#package_labels_files[@]} -gt 0 ]]; then
            print_status "Package-labels files (will be processed first):"
            for file in "${package_labels_files[@]}"; do
                print_status "  - $file"
            done
        fi
        
        if [[ ${#other_files[@]} -gt 0 ]]; then
            print_status "Other GraphQL files:"
            for file in "${other_files[@]}"; do
                print_status "  - $file"
            done
        fi
    fi
}

# Function to post GraphQL file to catalog API
post_graphql_file() {
    local file="$1"
    local filename=$(basename "$file")
    
    print_status "Posting $filename to catalog API..."
    
    # Construct the API endpoint
    local api_endpoint="${JF_URL}/catalog/api/v1/custom/graphql"
    
    # Show the actual curl command being executed (without showing the full token)
    print_status "Executing curl command:"
    echo "curl -X POST \\"
    echo "  -H \"Authorization: Bearer [TOKEN]\" \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d @\"$file\" \\"
    echo "  \"$api_endpoint\""
    echo ""
    
    if [[ "$VERBOSE" == true ]]; then
        print_status "API Endpoint: $api_endpoint"
        print_status "File: $file"
        print_status "Content preview:"
        head -c 200 "$file"
        echo "..."
    fi
    
    # Make the API call
    local response
    local http_code
    
    if [[ "$VERBOSE" == true ]]; then
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Authorization: Bearer $BEARER_TOKEN" \
            -H "Content-Type: application/json" \
            -d @"$file" \
            "$api_endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Authorization: Bearer $BEARER_TOKEN" \
            -H "Content-Type: application/json" \
            -d @"$file" \
            "$api_endpoint" 2>/dev/null)
    fi
    
    # Extract HTTP status code (last line) - macOS compatible
    http_code=$(echo "$response" | tail -1)
    # Extract response body (all lines except last) - macOS compatible
    response_body=$(echo "$response" | sed '$d')
    
    # Check HTTP status code
    if [[ "$http_code" -eq 200 ]]; then
        print_success "Successfully posted $filename"
        if [[ "$VERBOSE" == true ]]; then
            echo "Response: $response_body"
        fi
    else
        print_error "Failed to post $filename (HTTP $http_code)"
        if [[ "$VERBOSE" == true ]]; then
            echo "Response: $response_body"
        fi
        return 1
    fi
}

# Function to confirm execution
confirm_execution() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    echo ""
    print_warning "This will post ${#GRAPHQL_FILES[@]} GraphQL file(s) to:"
    print_warning "  $JF_URL/catalog/api/v1/custom/graphql"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled"
        exit 0
    fi
}

# Function to process all GraphQL files
process_graphql_files() {
    local success_count=0
    local failure_count=0
    
    print_status "Starting to post GraphQL files to catalog API..."
    echo ""
    
    for file in "${GRAPHQL_FILES[@]}"; do
        if post_graphql_file "$file"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
        echo ""
    done
    
    # Summary
    echo "========================================"
    print_success "Processing complete!"
    print_status "Successfully posted: $success_count file(s)"
    
    if [[ $failure_count -gt 0 ]]; then
        print_error "Failed to post: $failure_count file(s)"
        exit 1
    else
        print_success "All files posted successfully!"
    fi
}

# Main execution
main() {
    print_status "GraphQL Catalog API Posting Script"
    print_status "=================================="
    echo ""
    
    # Check environment variables
    check_environment
    echo ""
    
    # Check for GraphQL files
    check_graphql_files
    echo ""
    
    # Confirm execution
    confirm_execution
    
    # Process files
    process_graphql_files
}

# Run main function
main "$@" 