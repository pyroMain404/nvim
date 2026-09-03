<#
.SYNOPSIS
Run one probe inside a real headless Neovim, with this configuration loaded.

.DESCRIPTION
The command every probe needs is always the same, and every part of it that is
easy to get wrong is handled here once:

- the terminal size, which headless Neovim otherwise leaves at 80x24 - too
  small to say anything true about a layout;
- the parameters, passed through the environment so that no quoting of JSON
  survives the shell;
- the grace period for everything loaded by `Config.later()`;
- stdout and stderr, captured and printed together, because a `setup()` that
  throws writes to stderr while still exiting 0;
- a watchdog, so that a probe that hangs is killed instead of being left behind
  as a process nobody remembers starting.

.PARAMETER Probe
Probe to run: a path, or the name of a file in this directory ('win_layout').

.PARAMETER File
File to open as the argument of Neovim. Filetype driven behaviour (ftplugin,
LSP, tree-sitter) only exists once a buffer of that filetype is loaded, so pass
one whenever the probe is about a filetype.

.PARAMETER Params
Parameters for the probe, as a hashtable. Every probe documents its own; `wait`
and `json` are read by all of them.

.PARAMETER Wait
Milliseconds to wait for the deferred part of the configuration before probing.

.PARAMETER Show
Print the exact command instead of anything else. Use it to hand the user
a reproducible line, which is worth more than a description of what to do.

.EXAMPLE
./run.ps1 win_layout -File README.md -Params @{
  before = "vim.cmd('Git diff HEAD~3')"
  keys   = @('<CR>', '<CR>')
}
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Probe,
  [string]$File = '',
  [hashtable]$Params = @{},
  [int]$Columns = 200,
  [int]$Lines = 60,
  [int]$Wait = 1500,
  [string]$Cwd = '',
  [string]$Appname = '',
  [int]$TimeoutSec = 60,
  [switch]$Json,
  [switch]$Clean,
  [switch]$Show
)

$ErrorActionPreference = 'Stop'

# `Start-Process` joins its argument list with spaces and quotes nothing, so an
# argument that holds one (`set columns=200 lines=60`, a path with a space)
# arrives at Neovim split in two. Quoting here is what keeps them one argument.
function Format-Argv([string[]] $items) {
  $quoted = $items | ForEach-Object { if ($_.Contains(' ')) { '"' + $_ + '"' } else { $_ } }
  return ($quoted -join ' ')
}

$path = $Probe
if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $PSScriptRoot $Probe }
if (-not (Test-Path -LiteralPath $path)) { $path = "$path.lua" }
if (-not (Test-Path -LiteralPath $path)) { throw "probe not found: $Probe" }
$path = (Resolve-Path -LiteralPath $path).Path.Replace([char]92, '/')

$Params = $Params.Clone()
if (-not $Params.ContainsKey('wait')) { $Params['wait'] = $Wait }
if ($Json) { $Params['json'] = $true }

$argv = @('--headless', '--cmd', "set columns=$Columns lines=$Lines")
if ($Clean) { $argv = @('--clean') + $argv }
if ($File -ne '') { $argv += $File }
$argv += @('-S', $path)

if ($Show) {
  $quoted = $argv | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }
  Write-Output "`$env:NVIM_PROBE = '$($Params | ConvertTo-Json -Compress -Depth 10)'"
  Write-Output "nvim $($quoted -join ' ')"
  return
}

$out = New-TemporaryFile
$err = New-TemporaryFile
$previous = @{ probe = $env:NVIM_PROBE; appname = $env:NVIM_APPNAME }
$env:NVIM_PROBE = $Params | ConvertTo-Json -Compress -Depth 10
if ($Appname -ne '') { $env:NVIM_APPNAME = $Appname }

try {
  $start = @{
    FilePath               = 'nvim'
    ArgumentList           = (Format-Argv $argv)
    NoNewWindow            = $true
    PassThru               = $true
    RedirectStandardOutput = $out
    RedirectStandardError  = $err
  }
  if ($Cwd -ne '') { $start['WorkingDirectory'] = $Cwd }
  $process = Start-Process @start
  if (-not $process.WaitForExit($TimeoutSec * 1000)) {
    $process.Kill($true)
    $process.WaitForExit()
    Write-Output "TIMEOUT after ${TimeoutSec}s - process killed"
  }
  $code = $process.ExitCode

  Get-Content -LiteralPath $out -ErrorAction SilentlyContinue | Write-Output
  $stderr = Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue
  if ($stderr) {
    Write-Output '--- stderr'
    Write-Output $stderr.TrimEnd()
    # A configuration error is written here while the exit code stays 0, so the
    # verdict has to come from the text as well as from the code.
    if ($stderr -match 'Failed to run|stack traceback|E5108|E5113') { $code = 1 }
  }
  Write-Output "--- exit $code"
  exit $code
}
finally {
  $env:NVIM_PROBE = $previous.probe
  $env:NVIM_APPNAME = $previous.appname
  Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
}
