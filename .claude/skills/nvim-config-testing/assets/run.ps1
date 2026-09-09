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

A run can also reuse one instance instead of starting a new one (`-Session`).
That is worth doing whenever the thing being probed is expensive to reach:
a language server indexes its workspace once per process, so ten one-shot runs
pay for ten indexings, while ten probes in a session pay for one. In a session
the probe does not quit Neovim: it leaves its report in `g:probe_result`, which
is read back over the RPC socket (`:h --listen`, `:h --remote-expr`).

What the driver deliberately does not isolate, and that is sometimes the point:
the environment of the calling shell reaches the process untouched. Running the
same probe with and without a variable set ('$env:JDTLS_JVM_ARGS') compares two
configurations of a language server without editing a single file.

.PARAMETER Probe
Probe to run: a path, or the name of a file in this directory ('win_layout').

.PARAMETER File
File to open as the argument of Neovim. Filetype driven behaviour (ftplugin,
LSP, tree-sitter) only exists once a buffer of that filetype is loaded, so pass
one whenever the probe is about a filetype. In a session it is opened with
`:edit`, which means the state left by the previous probe is still there - the
point of a session, and its one caveat.

.PARAMETER Params
Parameters for the probe, as a hashtable. Every probe documents its own; `wait`
and `json` are read by all of them.

.PARAMETER Wait
Milliseconds to wait for the deferred part of the configuration before probing.
Ignored in a session, which finished loading long before the probe was sent.

.PARAMETER Session
Name of a reusable instance. It is started on first use and left running for
the next call; `-StopSession` ends it. One name is one Neovim, so use different
names for states that must not see each other.

.PARAMETER StopSession
Stop the named session and exit. Always do this when a series of probes is
done: the instance survives the shell otherwise.

.PARAMETER Reset
Wipe every buffer before running the probe in a session. State carries over
between probes of the same session - a buffer left modified by an `insert`, a
window a probe opened - which is useful right up to the moment it is not.

.PARAMETER Show
Print the exact command instead of anything else. Use it to hand the user
a reproducible line, which is worth more than a description of what to do.

.EXAMPLE
./run.ps1 win_layout -File README.md -Params @{
  before = "vim.cmd('Git diff HEAD~3')"
  keys   = @('<CR>', '<CR>')
}

.EXAMPLE
# Three LSP probes that index the workspace once instead of three times
./run.ps1 lsp -File init.lua -Session lua -Cwd $repo
./run.ps1 lsp_request -File init.lua -Session lua -Cwd $repo -Params @{ find = 'MiniPick' }
./run.ps1 -StopSession -Session lua
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Probe = '',
  [string]$File = '',
  [hashtable]$Params = @{},
  [int]$Columns = 200,
  [int]$Lines = 60,
  [int]$Wait = 1500,
  [string]$Cwd = '',
  [string]$Appname = '',
  [int]$TimeoutSec = 60,
  [string]$Session = '',
  [switch]$StopSession,
  [switch]$Reset,
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

# Run `nvim --server ... --remote-expr` and return its stdout. A dead socket
# and a live one that answers nothing look the same from the outside, so the
# caller gets `$null` for "no answer" and a string for everything else.
#
# `--headless` on the *client* is what makes the answer readable: without it
# the client starts a terminal UI first and the value arrives buried in escape
# sequences.
function Invoke-Remote([string] $Address, [string] $Expr, [int] $Seconds = 60) {
  $out = New-TemporaryFile
  $err = New-TemporaryFile
  try {
    $process = Start-Process -FilePath 'nvim' -NoNewWindow -PassThru `
      -ArgumentList (Format-Argv @('--headless', '--server', $Address, '--remote-expr', $Expr)) `
      -RedirectStandardOutput $out -RedirectStandardError $err
    if (-not $process.WaitForExit($Seconds * 1000)) {
      $process.Kill($true)
      $process.WaitForExit()
      return $null
    }
    if ($process.ExitCode -ne 0) { return $null }
    return (Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue)
  }
  finally {
    Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
  }
}

$address = ''
if ($Session -ne '') { $address = '\\.\pipe\nvim-probe-' + $Session }

if ($StopSession) {
  if ($Session -eq '') { throw '-StopSession needs -Session <name>' }
  # `:qa!` never answers, because the instance is gone before it could: the
  # null return is the success, not a failure.
  Invoke-Remote $address "execute('qa!')" 10 | Out-Null
  Write-Output "session '$Session' stopped"
  return
}

if ($Probe -eq '') { throw 'no probe given' }

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

# ---------------------------------------------------------------- session mode
if ($Session -ne '') {
  $Params['session'] = $true
  $previousAppname = $env:NVIM_APPNAME
  if ($Appname -ne '') { $env:NVIM_APPNAME = $Appname }

  try {
    if ($null -eq (Invoke-Remote $address '1' 10)) {
      $start = @{
        FilePath     = 'nvim'
        ArgumentList = (Format-Argv @(
            '--headless', '--listen', $address,
            '--cmd', "set columns=$Columns lines=$Lines"))
        NoNewWindow  = $true
        PassThru     = $true
      }
      if ($Cwd -ne '') { $start['WorkingDirectory'] = $Cwd }
      Start-Process @start | Out-Null

      $deadline = (Get-Date).AddSeconds(30)
      while ((Get-Date) -lt $deadline -and $null -eq (Invoke-Remote $address '1' 10)) {
        Start-Sleep -Milliseconds 300
      }
      if ($null -eq (Invoke-Remote $address '1' 10)) { throw "session '$Session' did not start" }
      Write-Output "--- session '$Session' started"
      # The deferred half of the configuration is on a timer, and in a session
      # it is only ever paid once.
      Invoke-Remote $address "luaeval('vim.wait($Wait)')" 60 | Out-Null
    }

    # Everything the instance has to do arrives as one Lua file: JSON in
    # `g:probe`, the buffer to look at, then the probe itself. Sending it as
    # a file is what keeps quoting out of the way - only its path travels.
    # Not `$json`: PowerShell variables are case insensitive, so that name
    # is the `-Json` switch of this script and assigning to it throws.
    $payload = $Params | ConvertTo-Json -Compress -Depth 10
    $driver = [System.IO.Path]::GetTempFileName() + '.lua'
    $body = @(
      "vim.g.probe = vim.json.decode([==[$payload]==])",
      "vim.g.probe_result = nil",
      "vim.g.probe_failed = 0"
    )
    if ($Reset) { $body += "vim.cmd('silent! %bwipeout!')" }
    if ($File -ne '') {
      # The path is made absolute here, and that is not a nicety: this config
      # sets `MiniMisc.setup_auto_root()`, so opening a file changes the working
      # directory of the instance. A relative path that worked for the first
      # probe of a session means something else by the second.
      $full = $File
      if (-not [System.IO.Path]::IsPathRooted($full)) {
        $base = if ($Cwd -ne '') { $Cwd } else { (Get-Location).Path }
        $full = Join-Path $base $File
      }
      $edit = $full.Replace([char]92, '/')
      $body += "vim.cmd('edit ' .. vim.fn.fnameescape([[$edit]]))"
    }
    $body += "dofile([[$path]])"
    # Wrapped, so that a failure of the setup - `:edit` refusing to leave a
    # modified buffer is the common one - comes back as a report instead of an
    # error on the socket that reads like a hung session.
    $body = @('local ok, err = pcall(function()') + $body + @(
      'end)',
      'if not ok then',
      "  vim.g.probe_result = 'FAIL the session could not run this probe' ..",
      "    string.char(10) .. '      ' .. tostring(err) ..",
      "    string.char(10) .. '      try -Reset, or -StopSession to start over'",
      '  vim.g.probe_failed = 1',
      'end'
    )
    Set-Content -LiteralPath $driver -Value ($body -join "`n") -Encoding UTF8

    try {
      $sent = Invoke-Remote $address "luaeval('dofile([[$($driver.Replace([char]92, '/'))]])')" $TimeoutSec
      if ($null -eq $sent) {
        throw "no answer from session '$Session' within ${TimeoutSec}s: it is busy or stuck. -StopSession to end it"
      }
      $result = Invoke-Remote $address "get(g:, 'probe_result', '')" 30
      $failed = Invoke-Remote $address "get(g:, 'probe_failed', 0)" 30
      if ($result) { Write-Output $result.TrimEnd() }
      $code = if ($failed -and $failed.Trim() -ne '0') { 1 } else { 0 }
      Write-Output "--- exit $code (session '$Session' still running)"
      exit $code
    }
    finally {
      Remove-Item -LiteralPath $driver -Force -ErrorAction SilentlyContinue
    }
  }
  finally {
    $env:NVIM_APPNAME = $previousAppname
  }
}

# -------------------------------------------------------------- one-shot mode
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
