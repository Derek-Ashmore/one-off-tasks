# one-off-tasks
Collection of one-off tasks that are not usually related.

## Scripts and Utilities Cross Reference

| Script/Utility | Path | Description |
|---------------|------|-------------|
| list_vms_with_extension.sh | scripts/bash/azure/list_vms_with_extension.sh | Lists all virtual machines across multiple subscriptions that have a specified VM extension installed. Supports CSV and table output formats. |
| remove_extension.sh | scripts/bash/azure/remove_extension.sh | Removes a specified Azure VM extension (default: OmsAgentForLinux) from a VM using az CLI. |
| git_branch_report.sh | scripts/bash/git/git_branch_report.sh | Recursively searches for Git repositories and generates a CSV report of unmerged remote branches with their status and last updater information. |
| git_pull_all.sh | scripts/bash/git/git_pull_all.sh | Recursively searches for Git repositories and executes 'git pull' on each one. Supports force pull, quiet mode, and verbose output options. |

