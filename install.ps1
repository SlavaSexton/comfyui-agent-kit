<#
.SYNOPSIS
  comfyui-agent-kit installer. Runs the shared machine setup once, then installs the comfyui skill + MCP for each
  selected agent (Claude Code, Codex, Gemini CLI, Qwen Code). Idempotent.
.PARAMETER Agents
  Comma list: claude,codex,gemini,qwen. Default "auto" = install for whichever CLIs are found on PATH.
.PARAMETER ComfyUIPath
  ComfyUI root (folder with 'custom_nodes'), for the in-graph Claude nodes. Optional.
.EXAMPLE
  ./install.ps1 -ComfyUIPath "E:\ComfyUI\ComfyUI\ComfyUI"
  ./install.ps1 -Agents claude,gemini
#>
param(
  [string]$Agents = "auto",
  [string]$ComfyUIPath = "",
  [string]$TemplatesDir = "$env:USERPROFILE\comfyui-agent-kit-data\workflow_templates",
  [switch]$SkipTemplates,
  [switch]$SkipNodes
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
function Have($c){ return [bool](Get-Command $c -ErrorAction SilentlyContinue) }

Write-Host "`n=== comfyui-agent-kit installer ===" -ForegroundColor White

# 1. shared machine setup (MCP package, templates, ComfyUI nodes)
& "$Root\shared\install_shared.ps1" -ComfyUIPath $ComfyUIPath -TemplatesDir $TemplatesDir `
    -SkipTemplates:$SkipTemplates -SkipNodes:$SkipNodes

# 2. pick agents
$known = @("claude","codex","gemini","qwen")
if ($Agents -eq "auto") { $sel = $known | Where-Object { Have $_ } }
else { $sel = $Agents.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $known -contains $_ } }
if (-not $sel) { Write-Host "`nNo target agent CLIs found on PATH. Install one of: $($known -join ', '), then re-run (or pass -Agents)." -ForegroundColor Yellow; return }
Write-Host "`nInstalling for: $($sel -join ', ')" -ForegroundColor White

# 3. run each adapter
foreach ($a in $sel) {
  try {
    if ($a -eq "claude") { & "$Root\agents\claude\install.ps1" -TemplatesDir $TemplatesDir }
    else { & "$Root\agents\$a\install.ps1" }
  } catch { Write-Host "  [!] $a adapter failed: $($_.Exception.Message)" -ForegroundColor Yellow }
}

Write-Host "`n=== Done. Next steps ===" -ForegroundColor White
Write-Host "  1. Start ComfyUI (Desktop: open the app). Confirm http://127.0.0.1:8188 answers." -ForegroundColor Cyan
Write-Host "  2. Restart the agent CLI(s) you installed for, so the skill/extension + MCP load." -ForegroundColor Cyan
Write-Host "  3. In a session, run the BOOTSTRAP once (docs/BOOTSTRAP.md): detect GPUs/VRAM/RAM/disk + paths." -ForegroundColor Cyan
Write-Host "  Note: GLM (z.ai) is run through Claude Code, so the 'claude' adapter already covers it." -ForegroundColor Cyan
