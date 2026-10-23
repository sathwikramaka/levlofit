# Owner-run pre-migration backup of the levlo cloud database, for Windows PowerShell 5.1+.
# Wraps tools/backup_prod.sh (all dump and verification checks live there) and keeps the password off every command line:
#   - prompts with Read-Host -AsSecureString (nothing displayed, nothing written to history or disk);
#   - removes the password from the connection string and hands it to the child process only as PGPASSWORD in this
#     process's environment, which the Supabase CLI passes to pg_dump; the password-free string goes to bash on stdin;
#   - asks the same way for a Supabase personal access token for the Storage copy and passes it only as
#     SUPABASE_ACCESS_TOKEN in this process's environment;
#   - clears PGPASSWORD, SUPABASE_ACCESS_TOKEN and the plain-text copies when it finishes, also on failure.
# Usage (repo root, Docker Desktop running):  powershell -ExecutionPolicy Bypass -File tools\backup_prod.ps1
# Output: C:\Projects\levlo-secure-backups\levlo-pre-migration-<UTC timestamp>\ (outside the repo; personal data; the
#         folder is restricted to your Windows account and SYSTEM).
[CmdletBinding()]
param(
  [SecureString]$ConnectionString,                                  # for offline tests only; normally prompted
  [SecureString]$AccessToken,                                       # for offline tests only; normally prompted
  [string]$BashPath   = 'C:\Program Files\Git\bin\bash.exe',
  [string]$ScriptPath,                                              # default: backup_prod.sh next to this file
  [string]$BackupRoot = 'C:\Projects\levlo-secure-backups'
)
$ErrorActionPreference = 'Stop'
$ref = 'ndeozgxowggkljluaccz'
# This file's own folder (tools\), independent of the current directory. $PSScriptRoot is empty inside param()
# defaults under Windows PowerShell 5.1 -File, so the path is resolved here, in the script body.
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptPath) { $ScriptPath = Join-Path $toolsDir 'backup_prod.sh' }
function Stop-Backup([string]$msg) { throw [InvalidOperationException]::new("STOP: $msg") }

$code = 1
$bstr = [IntPtr]::Zero; $tbstr = [IntPtr]::Zero; $plain = $null; $pw = $null; $pwEnc = $null; $noPw = $null; $userinfo = $null; $rest = $null
try {
  if (-not (Test-Path -LiteralPath $BashPath))   { Stop-Backup "Git Bash not found at $BashPath" }
  if (-not (Test-Path -LiteralPath $ScriptPath)) { Stop-Backup "Backup script not found at $ScriptPath" }
  $repo = [IO.Path]::GetFullPath((Join-Path $toolsDir '..')).TrimEnd('\') + '\'
  $root = [IO.Path]::GetFullPath($BackupRoot).TrimEnd('\')
  if ($root -notmatch '^[A-Za-z]:\\') { Stop-Backup 'Backup folder must be a local drive path' }
  if (($root + '\').StartsWith($repo, [StringComparison]::OrdinalIgnoreCase)) { Stop-Backup 'Backup folder must be outside the repository' }

  # Private backup folder: only the current user and SYSTEM, no inherited access.
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value      # current account by SID, never by name
  & icacls $root /inheritance:r /grant:r "*${me}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
  if ($LASTEXITCODE -ne 0) { Stop-Backup "Could not restrict access to $root" }
  # /grant:r replaces only the two named entries: verify nothing else (e.g. an explicit Administrators entry) remains.
  $acl = Get-Acl -LiteralPath $root
  $others = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) |
    Where-Object { $_.IdentityReference.Value -ne $me -and $_.IdentityReference.Value -ne 'S-1-5-18' })
  if (-not $acl.AreAccessRulesProtected -or $others.Count -gt 0) {
    Stop-Backup "Other accounts can still open $root ($($others.Count) extra entries); remove them with icacls /remove:g, then rerun"
  }

  if (-not $ConnectionString) {
    $ConnectionString = Read-Host -AsSecureString 'Paste the Session pooler connection string (Dashboard > Connect), input hidden'
  }
  $bstr  = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ConnectionString)
  $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr).Trim()

  if ($plain -notmatch '^postgres(ql)?://' -or -not $plain.Contains($ref)) { Stop-Backup 'Not a levlo connection string' }
  $sep  = $plain.IndexOf('://') + 3
  $rest = $plain.Substring($sep)
  $at   = $rest.LastIndexOf('@')                                   # last '@': tolerates an unencoded '@' in the password
  if ($at -lt 1) { Stop-Backup 'Connection string has no user@host part' }
  $userinfo = $rest.Substring(0, $at)
  $colon = $userinfo.IndexOf(':')
  if ($colon -lt 1 -or $colon -eq $userinfo.Length - 1) { Stop-Backup 'Connection string has no password' }
  $pwEnc = $userinfo.Substring($colon + 1)
  if ($pwEnc.Contains('YOUR-PASSWORD')) { Stop-Backup 'Replace [YOUR-PASSWORD] in the connection string' }
  $pw   = [Uri]::UnescapeDataString($pwEnc)                         # %XX decoded once; '+' and stray '%' kept literally
  $noPw = $plain.Substring(0, $sep) + $userinfo.Substring(0, $colon) + '@' + $rest.Substring($at + 1)
  $plain = $null; $pwEnc = $null; $userinfo = $null; $rest = $null

  if (-not $AccessToken) {
    $AccessToken = Read-Host -AsSecureString 'Paste a Supabase personal access token for the Storage copy (Account > Access Tokens), input hidden'
  }
  $tbstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)
  $env:SUPABASE_ACCESS_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tbstr).Trim()
  if (-not $env:SUPABASE_ACCESS_TOKEN) { Stop-Backup 'No access token' }
  $env:PGPASSWORD  = $pw
  $env:BACKUP_ROOT = '/' + $root.Substring(0, 1).ToLower() + ($root.Substring(2) -replace '\\', '/')
  $pw = $null
  # Only the script path is a command-line argument; the password-free connection string goes in on stdin.
  $prevEnc = $OutputEncoding; $OutputEncoding = New-Object Text.UTF8Encoding $false   # no BOM on the stdin pipe
  try { $noPw | & $BashPath ($ScriptPath -replace '\\', '/'); $code = $LASTEXITCODE } finally { $OutputEncoding = $prevEnc }
} catch {
  # Only our own STOP messages are shown; any other error is reported generically (it could quote input).
  $m = $_.Exception.Message
  if ($m.StartsWith('STOP: ')) { Write-Host $m -ForegroundColor Red } else { Write-Host 'STOP: unexpected error before the backup ran.' -ForegroundColor Red }
  $code = 1
} finally {
  Remove-Item Env:PGPASSWORD  -ErrorAction SilentlyContinue
  Remove-Item Env:SUPABASE_ACCESS_TOKEN -ErrorAction SilentlyContinue
  Remove-Item Env:BACKUP_ROOT -ErrorAction SilentlyContinue
  if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  if ($tbstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tbstr) }
  $plain = $null; $pw = $null; $pwEnc = $null; $noPw = $null; $userinfo = $null; $rest = $null
  [GC]::Collect()
}
if ($code -ne 0) { Write-Host "Backup FAILED (exit $code). Nothing was changed in the database." -ForegroundColor Red; exit $code }
Write-Host "Backup finished and verified. Keep $root private; never commit or upload it." -ForegroundColor Green
exit 0
