# one-off-tasks
Collection of one-off tasks that are not usually related.

## Scripts and Utilities Cross Reference

| Script/Utility | Path | Description |
|---------------|------|-------------|
| list_vms_with_extension.sh | scripts/bash/azure/list_vms_with_extension.sh | Lists all virtual machines across multiple subscriptions that have a specified VM extension installed. Supports CSV and table output formats. |
| remove_extension.sh | scripts/bash/azure/remove_extension.sh | Removes a specified Azure VM extension (default: OmsAgentForLinux) from a VM using az CLI. |
| snapshot_files_share_with_sas.sh | scripts/bash/azure/snapshot_files_share_with_sas.sh | Generates a short-lived SAS token and uses it to create a snapshot of an Azure Files share. |
| git_branch_report.sh | scripts/bash/git/git_branch_report.sh | Recursively searches for Git repositories and generates a CSV report of unmerged remote branches with their status and last updater information. |
| git_pull_all.sh | scripts/bash/git/git_pull_all.sh | Recursively searches for Git repositories and executes 'git pull' on each one. Supports force pull, quiet mode, and verbose output options. |
| New-GitHubOidcServicePrincipal.ps1 | scripts/powershell/New-GitHubOidcServicePrincipal.ps1 | Provisions an Azure AD application + service principal configured for GitHub Actions OIDC (workload identity federation), adding a federated credential scoped to a repository environment (`repo:<owner>/<repo>:environment:<env>`). No RBAC is assigned; returns the SPN client ID. Idempotent. |
| keep-awake.ps1 | scripts/powershell/keep-awake.ps1 | Prevents the system (and optionally the display) from sleeping while running, using SetThreadExecutionState. Restores normal sleep behavior on exit. |
| simulate-keypress-every-minute.ps1 | scripts/powershell/simulate-keypress-every-minute.ps1 | Simulates a harmless keypress (default F15) on a fixed interval to keep a session active. Configurable interval and key (F15, Shift, ScrollLock). |

