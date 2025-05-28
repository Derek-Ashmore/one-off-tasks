#!/bin/bash

# Script to list VMs with a specific named extension across multiple Azure subscriptions
# Usage: ./list_vms_with_extension.sh -s <subscriptions_file> -e <extension_name> [-o <output_file>] [-f <format>]

set -e

# Default values
OUTPUT_FILE=""
FORMAT="table"
SUBSCRIPTIONS_FILE=""
EXTENSION_NAME=""

# Function to show usage
show_usage() {
    echo "Usage: $0 -s <subscriptions_file> -e <extension_name> [-o <output_file>] [-f <format>]"
    echo ""
    echo "Parameters:"
    echo "  -s, --subscriptions    Text file containing subscription IDs (one per line)"
    echo "  -e, --extension        Name of the VM extension to search for"
    echo "  -o, --output          Output file (optional, uses standard output if not provided)"
    echo "  -f, --format          Output format: 'csv' or 'table' (default: table)"
    echo ""
    echo "Example:"
    echo "  $0 -s subscriptions.txt -e Microsoft.Azure.Monitoring.DependencyAgent -f csv -o results.csv"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--subscriptions)
            SUBSCRIPTIONS_FILE="$2"
            shift 2
            ;;
        -e|--extension)
            EXTENSION_NAME="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo "Unknown parameter: $1"
            show_usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SUBSCRIPTIONS_FILE" ]]; then
    echo "Error: Subscriptions file is required (-s)"
    show_usage
fi

if [[ -z "$EXTENSION_NAME" ]]; then
    echo "Error: Extension name is required (-e)"
    show_usage
fi

# Validate subscriptions file exists
if [[ ! -f "$SUBSCRIPTIONS_FILE" ]]; then
    echo "Error: Subscriptions file '$SUBSCRIPTIONS_FILE' does not exist"
    exit 1
fi

# Validate format
if [[ "$FORMAT" != "csv" && "$FORMAT" != "table" ]]; then
    echo "Error: Format must be 'csv' or 'table'"
    exit 1
fi

# Setup output redirection
if [[ -n "$OUTPUT_FILE" ]]; then
    exec > "$OUTPUT_FILE"
fi

# Function to output header based on format
output_header() {
    if [[ "$FORMAT" == "csv" ]]; then
        echo "Subscription,ResourceGroup,VMName,Location,Extension,ExtensionVersion,ProvisioningState"
    else
        printf "%-36s %-30s %-30s %-15s %-40s %-15s %-20s\n" \
            "Subscription" "ResourceGroup" "VMName" "Location" "Extension" "Version" "ProvisioningState"
        printf "%-36s %-30s %-30s %-15s %-40s %-15s %-20s\n" \
            "------------------------------------" "------------------------------" "------------------------------" "---------------" "----------------------------------------" "---------------" "--------------------"
    fi
}

# Function to output VM data based on format
output_vm_data() {
    local subscription="$1"
    local resource_group="$2"
    local vm_name="$3"
    local location="$4"
    local extension="$5"
    local version="$6"
    local state="$7"
    
    if [[ "$FORMAT" == "csv" ]]; then
        echo "$subscription,$resource_group,$vm_name,$location,$extension,$version,$state"
    else
        printf "%-36s %-30s %-30s %-15s %-40s %-15s %-20s\n" \
            "$subscription" "$resource_group" "$vm_name" "$location" "$extension" "$version" "$state"
    fi
}

# Main processing
echo "Scanning VMs with extension: $EXTENSION_NAME" >&2
echo "Output format: $FORMAT" >&2
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "Output file: $OUTPUT_FILE" >&2
fi
echo "" >&2

# Output header
output_header

# Read subscriptions and process each one
while IFS= read -r subscription_id; do
    # Skip empty lines and comments
    [[ -z "$subscription_id" || "$subscription_id" =~ ^[[:space:]]*# ]] && continue
    
    echo "Processing subscription: $subscription_id" >&2
    
    # Set the current subscription
    if ! az account set --subscription "$subscription_id" 2>/dev/null; then
        echo "Warning: Could not set subscription $subscription_id, skipping..." >&2
        continue
    fi
    
    # Get all VMs in the subscription
    vms=$(az vm list --query "[].{name:name, resourceGroup:resourceGroup, location:location}" -o tsv 2>/dev/null || true)
    
    if [[ -z "$vms" ]]; then
        echo "No VMs found in subscription $subscription_id" >&2
        continue
    fi
    
    # Process each VM
    while IFS=$'\t' read -r vm_name resource_group location; do
        [[ -z "$vm_name" ]] && continue
        
        # Check if the VM has the specified extension
        extension_info=$(az vm extension show \
            --resource-group "$resource_group" \
            --vm-name "$vm_name" \
            --name "$EXTENSION_NAME" \
            --query "{name:name, typeHandlerVersion:typeHandlerVersion, provisioningState:provisioningState}" \
            -o tsv 2>/dev/null || echo "")
        
        if [[ -n "$extension_info" ]]; then
            # Parse extension information
            IFS=$'\t' read -r ext_name ext_version ext_state <<< "$extension_info"
            
            # Output the VM data
            output_vm_data "$subscription_id" "$resource_group" "$vm_name" "$location" "$ext_name" "$ext_version" "$ext_state"
        fi
    done <<< "$vms"
    
done < "$SUBSCRIPTIONS_FILE"

echo "" >&2
echo "Scan completed." >&2