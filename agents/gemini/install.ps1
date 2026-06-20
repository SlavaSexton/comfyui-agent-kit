<#
.SYNOPSIS
  Gemini CLI adapter. Ships a self-contained extension at ~/.gemini/extensions/comfyui that bundles the MCP
  server + the knowledge as GEMINI.md (Gemini has no skill auto-loader, so the knowledge is always-on context).
  Assumes shared/install_shared.ps1 already ran (comfyui-mcp global, templates cloned).
#>
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Here)
$Shared = Join-Path $RepoRoot "shared\comfyui"
$Ext = "$env:USERPROFILE\.gemini\extensions\comfyui"
function Ok($m){ Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Have($c){ return [bool](Get-Command $c -ErrorAction SilentlyContinue) }

Write-Host "`n[gemini] adapter" -ForegroundColor White
if (-not (Have "gemini")) { Warn "gemini CLI not on PATH; install Gemini CLI first"; throw "gemini missing" }

New-Item -ItemType Directory -Force -Path $Ext | Out-Null

# GEMINI.md = SKILL.md body with the YAML frontmatter stripped (Gemini context files have no frontmatter)
$skill = Get-Content "$Shared\SKILL.md" -Raw
$body = [regex]::Replace($skill, '(?s)^\s*---.*?---\s*', '')
$gemini = "# ComfyUI media generation (always-on context for Gemini CLI)`n`nUse this whenever a task involves generating or rendering images, video, or audio with ComfyUI, or building/`nrunning a ComfyUI workflow. The per-model prompting reference is MODELS.md next to this file.`n`n$body"
Set-Content "$Ext\GEMINI.md" $gemini -Encoding utf8
Copy-Item "$Shared\MODELS.md"       "$Ext\MODELS.md" -Force
Copy-Item "$Shared\comfy_client.py" "$Ext\comfy_client.py" -Force
Ok "GEMINI.md + MODELS.md + client -> $Ext"

# gemini-extension.json (MCP server + context file)
$manifest = @'
{
  "name": "comfyui",
  "version": "1.0.0",
  "description": "Drive a local ComfyUI for image, video, and audio generation. By AI VFX NEWS.",
  "contextFileName": "GEMINI.md",
  "mcpServers": {
    "comfyui": {
      "command": "comfyui-mcp",
      "args": [],
      "cwd": "${extensionPath}"
    }
  }
}
'@
Set-Content "$Ext\gemini-extension.json" $manifest -Encoding utf8
Ok "gemini-extension.json written"

Write-Host "[gemini] done. Restart gemini so the extension + MCP load (run /extensions list to confirm)." -ForegroundColor White
