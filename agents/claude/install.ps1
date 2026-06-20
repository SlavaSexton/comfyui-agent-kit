<#
.SYNOPSIS
  Claude Code adapter: install the comfyui skill, register the MCP, append the auto-activation block.
  Assumes shared/install_shared.ps1 already ran (comfyui-mcp global, templates cloned).
  Note: GLM (z.ai) run through Claude Code uses this same adapter, since it reads ~/.claude/skills.
.PARAMETER TemplatesDir
  Templates location to record in the activation pointer. Default matches the shared installer.
#>
param([string]$TemplatesDir = "$env:USERPROFILE\comfyui-agent-kit-data\workflow_templates")
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Here)
$Shared = Join-Path $RepoRoot "shared\comfyui"
$SkillsDest = "$env:USERPROFILE\.claude\skills"
$ClaudeMd = "$env:USERPROFILE\.claude\CLAUDE.md"
function Ok($m){ Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Have($c){ return [bool](Get-Command $c -ErrorAction SilentlyContinue) }

Write-Host "`n[claude] adapter" -ForegroundColor White
if (-not (Have "claude")) { Warn "claude CLI not on PATH; install Claude Code first"; throw "claude missing" }

# 1. skill (shared knowledge) -> ~/.claude/skills/comfyui
New-Item -ItemType Directory -Force -Path "$SkillsDest\comfyui\workflows" | Out-Null
Copy-Item "$Shared\SKILL.md"        "$SkillsDest\comfyui\SKILL.md" -Force
Copy-Item "$Shared\MODELS.md"       "$SkillsDest\comfyui\MODELS.md" -Force
Copy-Item "$Shared\comfy_client.py" "$SkillsDest\comfyui\comfy_client.py" -Force
Ok "comfyui skill -> $SkillsDest\comfyui"

# 2. node-building skills (Layer 4)
$tmp = Join-Path $env:TEMP ("cns_" + [guid]::NewGuid().ToString("N").Substring(0,8))
& git clone --depth 1 https://github.com/jtydhr88/comfyui-custom-node-skills.git $tmp 2>&1 | Out-Null
$src = Join-Path $tmp "plugins\comfyui-custom-nodes\skills"
if (Test-Path $src) { Get-ChildItem $src -Directory | ForEach-Object { $d="$SkillsDest\$($_.Name)"; if (Test-Path $d){Remove-Item $d -Recurse -Force -EA SilentlyContinue}; Copy-Item $_.FullName $d -Recurse -Force }; Ok "node-building skills installed" } else { Warn "node skills not found" }
Remove-Item $tmp -Recurse -Force -EA SilentlyContinue

# 3. register MCP
$already = $false; try { & claude mcp get comfyui *> $null; if ($LASTEXITCODE -eq 0) { $already = $true } } catch {}
if ($already) { Ok "MCP 'comfyui' already registered" }
else { & claude mcp add comfyui --scope user -- comfyui-mcp; if ($LASTEXITCODE -eq 0) { Ok "MCP registered" } else { Warn "register manually: claude mcp add comfyui --scope user -- comfyui-mcp" } }

# 4. auto-activation block in CLAUDE.md
$marker = "### ComfyUI media generation (auto-activation)"
$existing = ""; if (Test-Path $ClaudeMd) { $existing = Get-Content $ClaudeMd -Raw }
if ($existing -match [regex]::Escape($marker)) { Ok "activation block present" }
else { $s = (Get-Content "$Here\claude_md_activation.md" -Raw).Replace("__TEMPLATES_DIR__", $TemplatesDir); Add-Content $ClaudeMd "`n$s"; Ok "activation block appended" }

Write-Host "[claude] done. Start ComfyUI, then run the BOOTSTRAP once (docs/BOOTSTRAP.md)." -ForegroundColor White
