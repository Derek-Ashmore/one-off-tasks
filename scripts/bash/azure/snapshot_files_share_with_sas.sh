#!/bin/bash

# Generate a short-lived, read-only SAS token for an Azure storage account
# and use it to create a snapshot of an Azure Files share.
#
# Usage:
#   ./snapshot_files_share_with_sas.sh \
#       -g <resource_group> \
#       -a <storage_account_name> \
#       -n <file_share_name> \
#       [-d <duration_minutes>] \
#       [--metadata key=value ...]
#
# Examples:
#   ./snapshot_files_share_with_sas.sh -g rg-prod -a mystorageacct -n backups
#   ./snapshot_files_share_with_sas.sh -g rg-prod -a mystorageacct -n backups -d 10 --metadata source=automated
#
# Requirements:
#   - Azure CLI (az)
#   - Logged-in Azure CLI session with permission to read the storage account

set -euo pipefail

DURATION_MINUTES=15
RESOURCE_GROUP="file-snapshot-test-rg"
STORAGE_ACCOUNT="aspfilessnaptest"
SHARE_NAME="testshare"
METADATA_ARGS=()

usage() {
    sed -n '4,28p' "$0"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_positive_integer() {
    local value="$1"
    if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -le 0 ]]; then
        echo "Error: Duration must be a positive integer (minutes)." >&2
        exit 1
    fi
}

calculate_timestamp() {
    local offset="$1"

    if command_exists python3; then
        python3 - <<PY
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) + timedelta(minutes=$offset)).strftime("%Y-%m-%dT%H:%MZ"))
PY
    elif command_exists python; then
        python - <<PY
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) + timedelta(minutes=$offset)).strftime("%Y-%m-%dT%H:%MZ"))
PY
    else
        # Fall back to GNU date; if unavailable, the command will fail
        date -u -d "$offset minutes" +"%Y-%m-%dT%H:%MZ"
    fi
}

ensure_az_cli() {
    if ! command_exists az; then
        echo "Error: Azure CLI (az) is required but not found in PATH." >&2
        exit 1
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--resource-group)
                RESOURCE_GROUP="$2"
                shift 2
                ;;
            -a|--account)
                STORAGE_ACCOUNT="$2"
                shift 2
                ;;
            -n|--share-name)
                SHARE_NAME="$2"
                shift 2
                ;;
            -d|--duration-minutes)
                DURATION_MINUTES="$2"
                ensure_positive_integer "$DURATION_MINUTES"
                shift 2
                ;;
            --metadata)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --metadata requires key=value argument(s)." >&2
                    exit 1
                fi
                while [[ $# -gt 1 && "$2" != -* ]]; do
                    METADATA_ARGS+=("--metadata" "$2")
                    shift
                done
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown argument: $1" >&2
                usage
                ;;
        esac
    done
}

validate_args() {
    [[ -n "$RESOURCE_GROUP" ]] || { echo "Error: Resource group is required (-g)." >&2; exit 1; }
    [[ -n "$STORAGE_ACCOUNT" ]] || { echo "Error: Storage account name is required (-a)." >&2; exit 1; }
    [[ -n "$SHARE_NAME" ]] || { echo "Error: File share name is required (-n)." >&2; exit 1; }
}

verify_share_exists() {
    if ! az storage share-rm show \
        --resource-group "$RESOURCE_GROUP" \
        --storage-account "$STORAGE_ACCOUNT" \
        --name "$SHARE_NAME" \
        --query "name" \
        --output tsv >/dev/null 2>&1; then
        echo "Error: File share '$SHARE_NAME' was not found in storage account '$STORAGE_ACCOUNT' (resource group '$RESOURCE_GROUP')." >&2
        exit 1
    fi
}

generate_sas_token() {
    local start_time expiry_time raw_sas
    # Start time 5 minutes in the past to mitigate clock skew.
    start_time=$(calculate_timestamp -5)
    expiry_time=$(calculate_timestamp "$DURATION_MINUTES")

    raw_sas=$(az storage account generate-sas \
        --account-name "$STORAGE_ACCOUNT" \
        --services f \
        --resource-types sco \
        --permissions rl \
        --https-only \
        --start "$start_time" \
        --expiry "$expiry_time" \
        --output tsv)

    if [[ -z "$raw_sas" ]]; then
        echo "Error: Failed to generate SAS token." >&2
        exit 1
    fi

    if [[ "${raw_sas:0:1}" != "?" ]]; then
        raw_sas="?$raw_sas"
    fi

    echo "$raw_sas"
}

create_share_snapshot() {
    local sas_token="$1"

    az storage share snapshot \
        --name "$SHARE_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --sas-token "$sas_token" \
        "${METADATA_ARGS[@]}" \
        --query "snapshot" \
        --output tsv
}

main() {
    parse_args "$@"
    validate_args
    ensure_az_cli
    verify_share_exists

    echo "Generating read-only SAS token for storage account '$STORAGE_ACCOUNT'..." >&2
    sas_token=$(generate_sas_token)

    echo "Creating snapshot for Azure Files share '$SHARE_NAME'..." >&2
    snapshot_id=$(create_share_snapshot "$sas_token")

    echo "Snapshot created successfully."
    echo "Share: $SHARE_NAME"
    echo "Snapshot ID: $snapshot_id"
}

main "$@"

