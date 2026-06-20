<#
.SYNOPSIS
  Codex CLI adapter. Codex has the SAME skill format as Claude (SKILL.md frontmatter, progressive disclosure),
  but user skills live in ~/.agents/skills (NOT ~/.codex/skills). MCP goes in ~/.codex/config.toml.
  Assumes shared/install_shared.ps1 already ran (comfyui-mcp global, templates cloned).
#>
param([string]$ComfyUrl = "http://127.0.0.1:8188")
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Here)
$Shared = Join-Path $RepoRoot "shared\comfyui"
$SkillsDest = "$env:USERPROFILE\.agents\skills"   # Codex user skills (verified path)
$CodexHome = "$env:USERPROFILE\.codex"
$ConfigToml = "$CodexHome\config.toml"
$AgentsMd = "$CodexHome\AGENTS.md"
function Ok($m){ Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Have($c){ return [bool](Get-Command $c -ErrorAction SilentlyContinue) }

Write-Host "`n[codex] adapter" -ForegroundColor White
if (-not (Have "codex")) { Warn "codex CLI not on PATH; install OpenAI Codex CLI first"; throw "codex missing" }

# 1. skill (same SKILL.md) -> ~/.agents/skills/comfyui
New-Item -ItemType Directory -Force -Path "$SkillsDest\comfyui\workflows" | Out-Null
Copy-Item "$Shared\SKILL.md"        "$SkillsDest\comfyui\SKILL.md" -Force
Copy-Item "$Shared\MODELS.md"       "$SkillsDest\comfyui\MODELS.md" -Force
Copy-Item "$Shared\comfy_client.py" "$SkillsDest\comfyui\comfy_client.py" -Force
Ok "comfyui skill -> $SkillsDest\comfyui"

# 2. node-building skills
$tmp = Join-Path $env:TEMP ("cns_" + [guid]::NewGuid().ToString("N").Substring(0,8))
& git clone --depth 1 https://github.com/jtydhr88/comfyui-custom-node-skills.git $tmp 2>&1 | Out-Null
$src = Join-Path $tmp "plugins\comfyui-custom-nodes\skills"
if (Test-Path $src) { Get-ChildItem $src -Directory | ForEach-Object { $d="$SkillsDest\$($_.Name)"; if (Test-Path $d){Remove-Item $d -Recurse -Force -EA SilentlyContinue}; Copy-Item $_.FullName $d -Recurse -Force }; Ok "node-building skills installed" } else { Warn "node skills not found" }
Remove-Item $tmp -Recurse -Force -EA SilentlyContinue

# 3. MCP -> ~/.codex/config.toml  (prefer `codex mcp add`, fallback to TOML append)
New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
$toml = ""; if (Test-Path $ConfigToml) { $toml = Get-Content $ConfigToml -Raw }
if ($toml -match "\[mcp_servers\.comfyui\]") { Ok "MCP 'comfyui' already in config.toml" }
else {
  & codex mcp add comfyui -- comfyui-mcp 2>&1 | Out-Null
  $toml2 = ""; if (Test-Path $ConfigToml) { $toml2 = Get-Content $ConfigToml -Raw }
  if ($toml2 -match "\[mcp_servers\.comfyui\]") { Ok "MCP registered via 'codex mcp add'" }
  else {
    $block = "`n[mcp_servers.comfyui]`ncommand = `"comfyui-mcp`"`nargs = []`n[mcp_servers.comfyui.env]`nCOMFYUI_URL = `"$ComfyUrl`"`n"
    Add-Content $ConfigToml $block; Ok "MCP appended to config.toml"
  }
}

# 4. optional pointer in ~/.codex/AGENTS.md
$marker = "ComfyUI skill (comfyui)"
$am = ""; if (Test-Path $AgentsMd) { $am = Get-Content $AgentsMd -Raw }
if ($am -match [regex]::Escape($marker)) { Ok "AGENTS.md pointer present" }
else { Add-Content $AgentsMd "`n## $marker`nFor any ComfyUI / image / video / audio generation task, use the ``comfyui`` skill in ~/.agents/skills/comfyui (SKILL.md + MODELS.md).`n"; Ok "AGENTS.md pointer added" }

Write-Host "[codex] done. Restart codex so the skill + MCP load." -ForegroundColor White
