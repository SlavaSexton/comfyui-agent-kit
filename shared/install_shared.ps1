<#
.SYNOPSIS
  Shared, agent-independent machine setup: the MCP driver package, the workflow-template library, and (optionally)
  the in-graph Claude nodes. Run once; the per-agent adapters then just wire the skill + register the MCP.
.PARAMETER ComfyUIPath
  ComfyUI root (folder containing 'custom_nodes'). If given, the in-graph Claude nodes are cloned into it.
.PARAMETER TemplatesDir
  Where to sparse-clone the official templates. Default: $HOME\comfyui-agent-kit-data\workflow_templates
#>
param(
  [string]$ComfyUIPath = "",
  [string]$TemplatesDir = "$env:USERPROFILE\comfyui-agent-kit-data\workflow_templates",
  [switch]$SkipTemplates,
  [switch]$SkipNodes
)
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function Ok($m){ Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Have($c){ return [bool](Get-Command $c -ErrorAction SilentlyContinue) }
# Run a native command (npm / git / python) so its stderr - e.g. an npm deprecation WARNING - does not trip
# $ErrorActionPreference='Stop' into a NativeCommandError and abort the install. Output is muted; the REAL
# exit code is returned so callers still catch actual failures.
function Native([scriptblock]$cmd){
  $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & $cmd 2>&1 | Out-Null } finally { $ErrorActionPreference = $prev }
  return $LASTEXITCODE
}

Write-Host "`n[shared] machine-level setup" -ForegroundColor White
foreach ($c in @("node","npm","git","python")) { if (Have $c) { Ok "$c" } else { Warn "$c MISSING (install it first)"; throw "prereq $c missing" } }

# MCP driver (one global package, used by every agent)
if ((Native { npm install -g comfyui-mcp --loglevel=error }) -ne 0) { throw "npm install -g comfyui-mcp failed" }
Ok "comfyui-mcp installed globally"

# In-graph Claude nodes (machine-level, agent-agnostic)
if ($SkipNodes) { Warn "skipping in-graph Claude nodes (-SkipNodes)" }
elseif ($ComfyUIPath -and (Test-Path (Join-Path $ComfyUIPath "custom_nodes"))) {
  $cn = Join-Path $ComfyUIPath "custom_nodes"
  foreach ($nd in @(
      @{n="anthropic-claude"; u="https://github.com/alexmunteanu/comfyui-anthropic-claude.git"},
      @{n="comfyui_claude_prompt_generator"; u="https://github.com/PauldeLavallaz/comfyui_claude_prompt_generator.git"})) {
    $d = Join-Path $cn $nd.n
    if (Test-Path $d) { Ok "$($nd.n) present" } else { Native { git clone --depth 1 $nd.u $d } | Out-Null; if (Test-Path $d) { Ok "$($nd.n) cloned" } else { Warn "failed: $($nd.n)" } }
  }
  Warn "Restart ComfyUI to load the nodes (Desktop: reopen the app); they may need: pip install 'anthropic>=0.40.0'"
} else { Warn "no -ComfyUIPath: install the Claude nodes via ComfyUI Manager (search 'anthropic claude')" }

# Workflow templates (source of truth) + quick index
if ($SkipTemplates) { Warn "skipping templates (-SkipTemplates)" }
elseif (Test-Path (Join-Path $TemplatesDir ".git")) { Ok "templates already at $TemplatesDir (git pull to update)" }
else {
  New-Item -ItemType Directory -Force -Path (Split-Path $TemplatesDir) | Out-Null
  Native { git clone --filter=blob:none --no-checkout https://github.com/Comfy-Org/workflow_templates.git $TemplatesDir } | Out-Null
  Native { git -C $TemplatesDir sparse-checkout set templates blueprints } | Out-Null
  Native { git -C $TemplatesDir checkout } | Out-Null
  if (Test-Path (Join-Path $TemplatesDir "templates\index.json")) {
    Native { python "$RepoRoot\shared\tools\gen_quick_index.py" (Join-Path $TemplatesDir "templates") } | Out-Null
    Ok "templates cloned + index built -> $TemplatesDir"
  } else { Warn "template clone incomplete" }
}
Write-Host "[shared] done. Templates: $TemplatesDir" -ForegroundColor White
