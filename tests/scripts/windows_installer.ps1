[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $Workspace,
  [Parameter(Mandatory)] [string] $Sandbox,
  [Parameter(Mandatory)] [string] $Nvim,
  [ValidateSet('standard', 'elevated')] [string] $Account = 'standard'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'run this harness from PowerShell 7 or newer' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if ($Account -eq 'standard' -and $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Windows installer runtime harness expected a non-admin user'
}
if ($Account -eq 'elevated' -and -not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Windows installer runtime harness expected an elevated administrator token'
}
if (-not (Get-Command powershell -ErrorAction SilentlyContinue)) { throw 'Windows PowerShell 5.1 was not found' }

function Get-Sid([object] $IdentityReference) {
  $IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
}

function Assert-PrivateParent([string] $Path) {
  $acl = Get-Acl -LiteralPath $Path
  if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne $identity.User.Value) { throw "owner mismatch: $Path" }
  if (-not $acl.AreAccessRulesProtected) { throw "DACL is not protected: $Path" }
  $rules = @($acl.Access)
  if ($rules.Count -ne 1) { throw "expected one explicit ACE: $Path" }
  $rule = $rules[0]
  if ($rule.AccessControlType -ne 'Allow' -or (Get-Sid $rule.IdentityReference) -ne $identity.User.Value) { throw "unexpected ACE identity/type: $Path" }
  if ($rule.FileSystemRights.ToString() -ne 'FullControl') { throw "unexpected ACE rights: $Path" }
  if ($rule.InheritanceFlags.ToString() -ne 'ContainerInherit, ObjectInherit' -or $rule.PropagationFlags.ToString() -ne 'None') { throw "unexpected ACE inheritance: $Path" }
  if ($rule.IsInherited) { throw "parent ACE is inherited: $Path" }
}

function Set-InsecureAcl([string] $Path) {
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
  $acl = [Security.AccessControl.DirectorySecurity]::new()
  $acl.SetOwner($identity.User)
  $acl.SetAccessRuleProtection($true, $false)
  [void] $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity.User, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
  [void] $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-1-0'), 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
  [IO.FileSystemAclExtensions]::SetAccessControl([IO.DirectoryInfo]::new($Path), $acl)
}

function Invoke-Harness([string] $Name, [string] $Separator, [bool] $Insecure, [string] $Cache = '') {
  if (-not $Cache) { $Cache = Join-Path $Sandbox "$Name-$Separator-cache" }
  $versionName = (Select-String -LiteralPath (Join-Path $Workspace 'lua/copilot/lsp/release.lua') -Pattern '^  version = "([^"]+)"').Matches[0].Groups[1].Value
  $target = Join-Path (Join-Path $Cache $versionName) 'win32-x64'
  if ($Insecure) {
    Set-InsecureAcl $Cache
    Set-InsecureAcl (Join-Path $Cache $versionName)
    Set-InsecureAcl $target
  }
  else { New-Item -ItemType Directory -Force -Path $Cache | Out-Null }
  $result = Join-Path $Sandbox "$Name-$Separator.json"
  Remove-Item -LiteralPath $result -Force -ErrorAction SilentlyContinue
  $env:COPILOT_WINDOWS_WORKSPACE = $Workspace
  $env:COPILOT_WINDOWS_CACHE_ROOT = $Cache
  $env:COPILOT_WINDOWS_RESULT = $result
  $env:COPILOT_WINDOWS_SEPARATOR = $Separator
  # This is deliberately inherited by Neovim. The production fix must clear it
  # only when it launches Windows PowerShell 5.1 children.
  $env:PSModulePath = (Join-Path $PSHOME 'Modules')
  & $Nvim --headless --clean -u NONE -c 'lua dofile(vim.fs.joinpath(vim.env.COPILOT_WINDOWS_WORKSPACE, "tests", "scripts", "windows_installer.lua"))' -c 'qa!'
  if ($LASTEXITCODE -ne 0) { throw "Neovim harness failed for $Name/$Separator with exit code $LASTEXITCODE" }
  $data = Get-Content -LiteralPath $result -Raw | ConvertFrom-Json
  if ($data.PSObject.Properties['failure']) { throw "Lua harness failed for $Name/${Separator}: $($data.failure)" }
  if (-not $data.staging_acl_verified -or -not $data.published_acl_verified -or -not $data.cache_verified -or $data.powershell_calls -lt 2) { throw "real PowerShell preparation/publication/cache validation was not observed for $Name/$Separator" }
  $version = Join-Path $Cache $versionName
  Assert-PrivateParent $Cache
  Assert-PrivateParent $version
  Assert-PrivateParent $target
  Write-Host "ACL persistence diagnostic ($Name/$Separator): $($data.diagnostic)"
  return $Cache
}

foreach ($separator in @('forward', 'backslash')) {
  $clean = Join-Path $Sandbox "clean-$separator-cache"
  $cache = Join-Path $Sandbox "insecure-$separator-cache"
  try {
    [void](Invoke-Harness -Name 'clean' -Separator $separator -Insecure $false -Cache $clean)
    [void](Invoke-Harness -Name 'clean-repeat' -Separator $separator -Insecure $false -Cache $clean)
    [void](Invoke-Harness -Name 'insecure' -Separator $separator -Insecure $true -Cache $cache)
    [void](Invoke-Harness -Name 'insecure-repeat' -Separator $separator -Insecure $false -Cache $cache)
  }
  finally {
    # Each account removes only cache roots it created. In particular, the
    # standard-user process performs this cleanup under its own token.
    foreach ($knownCache in @($clean, $cache)) {
      if ($knownCache -and (Test-Path -LiteralPath $knownCache)) {
        Remove-Item -LiteralPath $knownCache -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }
}

Write-Host "Windows installer ACL runtime harness ($Account) passed through $((Get-Command powershell).Source)"
