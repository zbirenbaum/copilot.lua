#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs GitHub Copilot Group Policy Administrative Templates
    
.DESCRIPTION
    This script copies the GitHub Copilot ADMX and ADML files to the Windows PolicyDefinitions
    directory to enable Group Policy management of GitHub Copilot settings.
    
    The script must be run from the win32 directory containing the template files.
    
.PARAMETER Uninstall
    Remove the GitHub Copilot policy templates instead of installing them
    
.EXAMPLE
    .\Install-PolicyTemplates.ps1
    Installs the GitHub Copilot policy templates
    
.EXAMPLE
    .\Install-PolicyTemplates.ps1 -Uninstall
    Removes the GitHub Copilot policy templates
#>

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# Paths
$PolicyDefinitionsPath = "$env:WINDIR\PolicyDefinitions"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceADMX = Join-Path $ScriptPath "IDEGitHubCopilot.admx"
$SourceADML = Join-Path $ScriptPath "en-US\IDEGitHubCopilot.adml"
$TargetADMX = Join-Path $PolicyDefinitionsPath "IDEGitHubCopilot.admx"
$TargetADMLDir = Join-Path $PolicyDefinitionsPath "en-US"
$TargetADML = Join-Path $TargetADMLDir "IDEGitHubCopilot.adml"

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Templates {
    Write-Host "Installing GitHub Copilot Group Policy Templates..." -ForegroundColor Green
    
    # Verify source files exist
    if (-not (Test-Path $SourceADMX)) {
        throw "ADMX file not found: $SourceADMX"
    }
    
    if (-not (Test-Path $SourceADML)) {
        throw "ADML file not found: $SourceADML"
    }
    
    # Verify PolicyDefinitions directory exists
    if (-not (Test-Path $PolicyDefinitionsPath)) {
        throw "PolicyDefinitions directory not found: $PolicyDefinitionsPath"
    }
    
    # Copy ADMX file
    Write-Host "Copying ADMX file to $TargetADMX"
    Copy-Item $SourceADMX $TargetADMX -Force
    
    # Ensure en-US directory exists
    if (-not (Test-Path $TargetADMLDir)) {
        Write-Host "Creating directory: $TargetADMLDir"
        New-Item -Path $TargetADMLDir -ItemType Directory -Force | Out-Null
    }
    
    # Copy ADML file
    Write-Host "Copying ADML file to $TargetADML"
    Copy-Item $SourceADML $TargetADML -Force
    
    Write-Host "GitHub Copilot Group Policy Templates installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To use the templates:"
    Write-Host "1. Run 'gpupdate /force' to refresh Group Policy"
    Write-Host "2. Open Group Policy Editor (gpedit.msc)"
    Write-Host "3. Navigate to Administrative Templates > GitHub Copilot"
}

function Uninstall-Templates {
    Write-Host "Removing GitHub Copilot Group Policy Templates..." -ForegroundColor Yellow
    
    # Remove ADMX file
    if (Test-Path $TargetADMX) {
        Write-Host "Removing ADMX file: $TargetADMX"
        Remove-Item $TargetADMX -Force
    } else {
        Write-Host "ADMX file not found: $TargetADMX"
    }
    
    # Remove ADML file
    if (Test-Path $TargetADML) {
        Write-Host "Removing ADML file: $TargetADML"
        Remove-Item $TargetADML -Force
    } else {
        Write-Host "ADML file not found: $TargetADML"
    }
    
    Write-Host "GitHub Copilot Group Policy Templates removed successfully!" -ForegroundColor Green
    Write-Host "Run 'gpupdate /force' to refresh Group Policy"
}

# Main execution
try {
    # Check for administrator rights
    if (-not (Test-AdminRights)) {
        throw "This script requires administrator privileges. Please run PowerShell as Administrator."
    }
    
    if ($Uninstall) {
        Uninstall-Templates
    } else {
        Install-Templates
    }
    
} catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}