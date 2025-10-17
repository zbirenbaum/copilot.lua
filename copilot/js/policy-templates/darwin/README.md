# GitHub Copilot macOS Policy Configuration

This directory contains policy templates for configuring GitHub Copilot behavior on macOS systems using Apple Configuration Profiles.

## Overview

The `IDEGitHubCopilot.mobileconfig` file is a macOS Configuration Profile that allows administrators to manage GitHub Copilot policies across their organization. This profile defines settings that control extension behavior, particularly for MCP (Model Context Protocol) servers.

## Available Policies

| Policy Name | Description | Type | Default |
|-------------|-------------|------|---------|
| mcp.contributionPoint.enabled | Controls whether extension-contributed MCP servers are enabled | Boolean | true |

## Installation Methods

### Method 1: Configuration Profile Installation (Recommended for Administrators)

The `IDEGitHubCopilot.mobileconfig` file provides the easiest way to deploy GitHub Copilot policies across multiple macOS systems.

#### Step 1: Locate the Configuration Profile
Find the `IDEGitHubCopilot.mobileconfig` file in this directory.

#### Step 2: Install the Configuration Profile
1. **Double-click** the `IDEGitHubCopilot.mobileconfig` file
2. macOS will open **System Settings** (or **System Preferences** on older versions)
3. You'll see a dialog asking if you want to install the profile
4. Click **Install** to proceed
5. Enter your administrator password when prompted
6. The profile will be installed **system-wide**

#### Step 3: Verify Installation
1. Open **System Settings** → **Privacy & Security** → **Profiles**
2. You should see "GitHub Copilot Policy" in the list of installed profiles
3. Click on it to view the configured settings

#### Step 4: Modify Policy Settings
To change the `mcp.contributionPoint.enabled` setting:

1. Open **System Settings** → **Privacy & Security** → **Profiles**
2. Select the "GitHub Copilot Policy" profile
3. Click **Edit** or **Configure**
4. Find the `mcp.contributionPoint.enabled` setting
5. Toggle it to:
   - **true** (checked) - Enable extension-contributed MCP servers
   - **false** (unchecked) - Disable extension-contributed MCP servers
6. Click **Save** or **Apply**

### Method 2: Command Line Installation (Alternative)

You can also install the configuration profile using the command line:

```bash
# Install the profile
sudo profiles -I -F IDEGitHubCopilot.mobileconfig

# Verify installation
profiles -P

# Remove the profile (if needed)
sudo profiles -R -p IDEGitHubCopilot
```

### Method 3: MDM Deployment (Enterprise)

For enterprise environments, the `IDEGitHubCopilot.mobileconfig` file can be deployed through Mobile Device Management (MDM) solutions like:

- Apple Business Manager
- Jamf Pro
- Microsoft Intune
- VMware Workspace ONE

Simply upload the `IDEGitHubCopilot.mobileconfig` file to your MDM solution and deploy it to your target devices.

## Verification

You can verify the current settings with:

```bash
# Check managed preferences
defaults read /Library/Managed\ Preferences/IDEGitHubCopilot 2>/dev/null || echo "No managed settings found"
```

## How It Works

The GitHub Copilot extension uses the `GroupPolicyWatcher` class to monitor policy changes. When policies are updated:

1. The policy watcher detects the change
2. Updates the internal policy state
3. Sends an LSP notification to the client
4. The client adjusts its behavior based on the new policy settings

The extension checks for policies in `/Library/Managed Preferences/IDEGitHubCopilot.plist` (MDM managed)

## Troubleshooting

### Policy changes aren't being detected
1. Verify the configuration profile is properly installed in System Settings
2. Make sure the policy file has the correct name and structure
3. Restart IDE to ensure the policy watcher is reinitialized
4. Check the extension logs for policy-related messages

### Configuration Profile won't install
1. Ensure you have administrator privileges
2. Check that the `.mobileconfig` file isn't corrupted
3. Try installing via command line: `sudo profiles -I -F IDEGitHubCopilot.mobileconfig`

### Settings don't take effect
1. Verify the policy is correctly configured in System Settings
2. Restart IDE completely
3. Check that no user-level settings are overriding system policies

## References

- [VS Code Enterprise Setup - Configuration Profiles on macOS](https://code.visualstudio.com/docs/setup/enterprise#_configuration-profiles-on-macos)
- [Apple Configuration Profile Reference](https://developer.apple.com/documentation/devicemanagement/configuring_multiple_devices_using_profiles)
- [macOS defaults command reference](https://ss64.com/osx/defaults.html)