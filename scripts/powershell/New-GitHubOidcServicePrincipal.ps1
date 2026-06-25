<#
.SYNOPSIS
    Provisions an Azure AD application + service principal configured for GitHub
    Actions OIDC (workload identity federation) scoped to a specific repository
    environment.

.DESCRIPTION
    Creates (or reuses) an Azure AD application registration and its service
    principal, then adds a federated identity credential whose subject targets a
    GitHub repository environment:

        repo:<owner>/<repo>:environment:<environment>

    No role assignments / RBAC are performed here. Grant IAM privileges to the
    service principal separately after provisioning.

    The script is idempotent: re-running with the same inputs will reuse the
    existing application, service principal, and federated credential.

    On success it writes the application's (client) ID to the output stream so it
    can be captured, e.g.:

        $clientId = .\New-GitHubOidcServicePrincipal.ps1 -SpnName "my-spn" `
            -Repository "my-org/my-repo" -Environment "production"

.PARAMETER SpnName
    Display name for the Azure AD application / service principal.

.PARAMETER Repository
    GitHub repository in 'owner/repo' format (e.g. my-org/my-repo).

.PARAMETER Environment
    GitHub repository environment name (e.g. production).

.PARAMETER Audience
    OIDC token audience. Defaults to the GitHub-to-Azure standard 'api://AzureADMyOrg'.

.EXAMPLE
    .\New-GitHubOidcServicePrincipal.ps1 -SpnName "deploy-prod" -Repository "contoso/web-app" -Environment "production"

.NOTES
    Requires the Az.Accounts and Az.Resources modules and an authenticated
    context (Connect-AzAccount). The signed-in identity must have permission to
    create Azure AD application registrations.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SpnName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[^/\s]+/[^/\s]+$')]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Audience = 'api://AzureADMyOrg'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Issuer = 'https://token.actions.githubusercontent.com'
$Subject = "repo:${Repository}:environment:${Environment}"

function Test-RequiredModule {
    param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        throw "Required module '$Name' is not installed. Install it with: Install-Module $Name -Scope CurrentUser"
    }
}

Test-RequiredModule -Name 'Az.Accounts'
Test-RequiredModule -Name 'Az.Resources'

# Ensure we have an authenticated Azure context.
$context = Get-AzContext
if (-not $context) {
    throw "No Azure context found. Run Connect-AzAccount before executing this script."
}

Write-Host "Using tenant '$($context.Tenant.Id)' and account '$($context.Account.Id)'." -ForegroundColor Cyan
Write-Host "Federated credential subject will be: $Subject" -ForegroundColor Cyan

# --- Application registration (reuse if it already exists) ----------------------
$app = Get-AzADApplication -DisplayName $SpnName -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $app) {
    Write-Host "Creating Azure AD application '$SpnName'..." -ForegroundColor Green
    $app = New-AzADApplication -DisplayName $SpnName
}
else {
    Write-Host "Reusing existing Azure AD application '$SpnName' (AppId: $($app.AppId))." -ForegroundColor Yellow
}

# --- Service principal (reuse if it already exists) -----------------------------
$sp = Get-AzADServicePrincipal -ApplicationId $app.AppId -ErrorAction SilentlyContinue

if (-not $sp) {
    Write-Host "Creating service principal for AppId $($app.AppId)..." -ForegroundColor Green
    $sp = New-AzADServicePrincipal -ApplicationId $app.AppId
}
else {
    Write-Host "Reusing existing service principal (ObjectId: $($sp.Id))." -ForegroundColor Yellow
}

# --- Federated identity credential for the repo environment ---------------------
# Build a deterministic, valid credential name from the environment.
$sanitizedEnv = ($Environment -replace '[^A-Za-z0-9-_]', '-')
$credentialName = "gh-$sanitizedEnv"
if ($credentialName.Length -gt 120) {
    $credentialName = $credentialName.Substring(0, 120)
}

$existingCred = Get-AzADAppFederatedCredential -ApplicationObjectId $app.Id -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -eq $Subject } |
    Select-Object -First 1

if (-not $existingCred) {
    Write-Host "Creating federated credential '$credentialName'..." -ForegroundColor Green
    New-AzADAppFederatedCredential `
        -ApplicationObjectId $app.Id `
        -Name $credentialName `
        -Issuer $Issuer `
        -Subject $Subject `
        -Audience $Audience | Out-Null
}
else {
    Write-Host "Federated credential for subject '$Subject' already exists (Name: $($existingCred.Name))." -ForegroundColor Yellow
}

Write-Host "Done. Service principal is ready for GitHub OIDC." -ForegroundColor Cyan
Write-Host "Grant IAM/RBAC privileges to AppId $($app.AppId) separately as needed." -ForegroundColor Cyan

# Return the client (application) ID so callers / GitHub environment can capture it.
Write-Output $app.AppId
