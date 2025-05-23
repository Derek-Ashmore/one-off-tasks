#!/bin/bash

# Usage: ./remove_omsagent.sh <vm_resource_id> [extension_name]

if [ -z "$1" ]; then
  echo "Usage: $0 <vm_resource_id> [extension_name]"
  exit 1
fi

VM_ID="$1"
EXT_NAME="${2:-OmsAgentForLinux}"

# Remove the extension
az vm extension delete \
  --ids "$VM_ID" \
  --name "$EXT_NAME"

if [ $? -eq 0 ]; then
  echo "Successfully removed $EXT_NAME from $VM_ID"
else
  echo "Failed to remove $EXT_NAME from $VM_ID"
fi
