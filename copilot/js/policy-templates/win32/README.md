# GitHub Copilot Group Policy Templates for Windows

This directory contains Administrative Template (ADMX/ADML) files for managing GitHub Copilot settings through Windows Group Policy. These templates are bundled with the GitHub Copilot Language Server for enterprise deployment.

## Template Location

These templates are installed with the GitHub Copilot Language Server at:
```
[Language Server Installation Directory]/policy-templates/win32/
```

Common installation locations:
- **NPM Global Install**: `%APPDATA%\npm\node_modules\@github\copilot-language-server\dist\policy-templates\win32`
- **Local NPM Install**: `.\node_modules\@github\copilot-language-server\dist\policy-templates\win32`

## Files

- `IDEGitHubCopilot.admx` - Administrative template definition file
- `en-US/IDEGitHubCopilot.adml` - English language resource file
- `Install-PolicyTemplates.ps1` - PowerShell script for automated installation

## Installation Methods

### Option 1: PowerShell Script (Recommended)

1. **Open PowerShell as Administrator**
2. **Navigate to the policy templates directory:**
   ```powershell
   cd "[Language Server Installation Directory]\policy-templates\win32"
   ```
3. **Execute the installation script:**
   ```powershell
   .\Install-PolicyTemplates.ps1
   ```

### Option 2: Manual Installation

1. **Copy ADMX file:**
   ```
   Copy IDEGitHubCopilot.admx to C:\Windows\PolicyDefinitions\
   ```

2. **Copy ADML file:**
   ```
   Copy en-US\IDEGitHubCopilot.adml to C:\Windows\PolicyDefinitions\en-US\
   ```

### Option 3: Microsoft Intune Configuration

For cloud-based management with Microsoft Intune, create a Custom Configuration Profile with OMA-URI settings (see details below).

## Accessing Group Policy Settings

After installation:

1. **Open Group Policy Editor:**
   - Run `gpedit.msc` (Local Group Policy Editor)
   - Or use `gpmc.msc` (Group Policy Management Console) for domain environments

2. **Navigate to GitHub Copilot policies:**
   - Computer Configuration → Administrative Templates → GitHub Copilot
   - User Configuration → Administrative Templates → GitHub Copilot

## Available Policies

### Enable Extension-Contributed MCP Servers
**Category:** GitHub Copilot → Model Context Protocol (MCP)

Controls whether GitHub Copilot can use Model Context Protocol (MCP) servers contributed by IDE extensions.

**Registry Locations:**
- **Machine Policy:** `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\IDEGitHubCopilot\mcp.contributionPoint.enabled`
- **User Policy:** `HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\IDEGitHubCopilot\mcp.contributionPoint.enabled`

**Values:**
- `1` (REG_DWORD) = Enable extension-contributed MCP servers
- `0` (REG_DWORD) = Disable extension-contributed MCP servers

## Registry Testing

You can test the policies by setting registry values directly:

```cmd
REM Enable extension-contributed MCP servers (machine-wide)
reg add "HKLM\SOFTWARE\Policies\Microsoft\IDEGitHubCopilot" /v "mcp.contributionPoint.enabled" /t REG_DWORD /d 1 /f

REM Disable extension-contributed MCP servers (current user)
reg add "HKCU\SOFTWARE\Policies\Microsoft\IDEGitHubCopilot" /v "mcp.contributionPoint.enabled" /t REG_DWORD /d 0 /f
```

## Microsoft Intune Deployment

For cloud-based management with Microsoft Intune:

1. **Create a Custom Configuration Profile:**
   - Go to Microsoft Endpoint Manager admin center
   - Navigate to Devices → Configuration profiles
   - Create a new profile with platform "Windows 10 and later"
   - Profile type: "Custom"

2. **Add the registry setting:**
   ```
   Name: Enable Extension-Contributed MCP Servers
   OMA-URI: ./Device/Vendor/MSFT/Policy/Config/ADMX_IDEGitHubCopilot/McpContributionPointEnabled
   Data type: Integer
   Value: 1 (enabled) or 0 (disabled)
   ```

3. **Assign to device groups** as needed

## Policy Precedence

1. **Machine Policy** (highest precedence)
   - `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\IDEGitHubCopilot\`
2. **User Policy** 
   - `HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\IDEGitHubCopilot\`
3. **Default Behavior** (lowest precedence)
   - Determined by application defaults when no policy is set

## Troubleshooting

1. **Templates not appearing in Group Policy Editor:**
   - Verify ADMX/ADML files are copied to the correct directories
   - Run `gpupdate /force` to refresh Group Policy
   - Restart Group Policy Editor

2. **Policies not taking effect:**
   - Check registry values are being set correctly
   - Restart the IDE or GitHub Copilot service
   - Verify policy precedence (machine vs user)

3. **Permission errors during template copy:**
   - Ensure the application is running with administrator privileges
   - Manually copy templates using an elevated command prompt

## References

- [VS Code Group Policy Documentation](https://code.visualstudio.com/docs/setup/enterprise#_group-policy-on-windows)
- [@vscode/policy-watcher Documentation](https://github.com/microsoft/vscode-policy-watcher)
- [Microsoft Group Policy Documentation](https://docs.microsoft.com/en-us/previous-versions/windows/desktop/policy/group-policy-start-page)