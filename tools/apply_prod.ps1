# Owner-run production migration apply (release steps A3-A19): one file, or an approved batch in the order given.
# Usage (repo root, Docker Desktop running):
#   powershell -ExecutionPolicy Bypass -File tools\apply_prod.ps1 supabase\migrations\<file>.sql [<file>.sql ...]
# Asks once for the Session pooler connection string with hidden input (same as backup_prod.ps1), keeps the password out
# of every command line (it reaches psql only as PGPASSWORD in this process's environment), prints each file's SHA-256,
# and applies each file unchanged with psql in the Supabase Postgres image: ON_ERROR_STOP and one transaction per file,
# so a failing file changes nothing and the run stops there (files before it stay applied).
# Forward-only (MIGRATION_RECONCILIATION.md Option B): migration history is not written.
param([Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$File)
$ErrorActionPreference = 'Stop'
$image = 'public.ecr.aws/supabase/postgres:17.6.1.171'

$paths = @(foreach ($f in $File) { (Resolve-Path -LiteralPath $f).Path })
foreach ($p in $paths) {
  Write-Host ('{0}  {1}' -f (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower().Substring(0, 16), (Split-Path -Leaf $p))
}

$secure = Read-Host -AsSecureString 'Paste the Session pooler connection string (Dashboard > Connect), input hidden'
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  if ($plain -notmatch '^(postgres(?:ql)?://)([^:/@]+):([^@]+)@(.+)$') { throw 'Not a postgresql://user:password@host connection string; nothing applied.' }
  if ($Matches[3] -like '*YOUR-PASSWORD*') { throw 'Replace [YOUR-PASSWORD] (brackets included) with the database password; nothing applied.' }
  $url = $Matches[1] + $Matches[2] + '@' + $Matches[4]
  $env:PGPASSWORD = [Uri]::UnescapeDataString($Matches[3])
  $plain = $null
  foreach ($path in $paths) {
    $dir = Split-Path -Parent $path
    $name = Split-Path -Leaf $path
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLower()
    # The file is mounted read-only (never piped, so no text re-encoding); PGPASSWORD passes from this environment.
    & docker run --rm -e PGPASSWORD -v "${dir}:/m:ro" $image psql $url -v ON_ERROR_STOP=1 --single-transaction -q -f "/m/$name"
    if ($LASTEXITCODE -ne 0) { throw "$name failed (psql exit ${LASTEXITCODE}): its transaction rolled back; later files were not run." }
    Write-Host "APPLIED $name ($hash)" -ForegroundColor Green
  }
  Write-Host "ALL APPLIED ($($paths.Count) files)" -ForegroundColor Green
} catch {
  Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
