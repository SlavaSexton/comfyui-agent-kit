<#
.SYNOPSIS
  Qwen Code adapter (a Gemini-CLI fork). Ships an extension at ~/.qwen/extensions/comfyui bundling the MCP server
  + the knowledge as QWEN.md. Manifest is qwen-extension.json. Assumes shared/install_shared.ps1 already ran.
#>
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Here)
$Shared = Join-Path $RepoRoot "shared\comfyui"
$Ext = "$env:USERPROFILE\.qwen\extensions\comfyui"
function Ok($m){ Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Have($c){ return [bool](Get-Command $c -ErrorAction SilentlyContinue) }

Write-Host "`n[qwen] adapter" -ForegroundColor White
if (-not (Have "qwen")) { Warn "qwen CLI not on PATH; install Qwen Code first"; throw "qwen missing" }

New-Item -ItemType Directory -Force -Path $Ext | Out-Null

$skill = Get-Content "$Shared\SKILL.md" -Raw
$body = [regex]::Replace($skill, '(?s)^\s*---.*?---\s*', '')
$qwen = "# ComfyUI media generation (always-on context for Qwen Code)`n`nUse this whenever a task involves generating or rendering images, video, or audio with ComfyUI, or building/`nrunning a ComfyUI workflow. The per-model prompting reference is MODELS.md next to this file.`n`n$body"
Set-Content "$Ext\QWEN.md" $qwen -Encoding utf8
Copy-Item "$Shared\MODELS.md"       "$Ext\MODELS.md" -Force
Copy-Item "$Shared\comfy_client.py" "$Ext\comfy_client.py" -Force
Ok "QWEN.md + MODELS.md + client -> $Ext"

$manifest = @'
{
  "name": "comfyui",
  "version": "1.0.0",
  "description": "Drive a local ComfyUI for image, video, and audio generation. By AI VFX NEWS.",
  "contextFileName": "QWEN.md",
  "mcpServers": {
    "comfyui": {
      "command": "comfyui-mcp",
      "args": [],
      "cwd": "${extensionPath}"
    }
  }
}
'@
Set-Content "$Ext\qwen-extension.json" $manifest -Encoding utf8
Ok "qwen-extension.json written"

Write-Host "[qwen] done. Restart qwen so the extension + MCP load." -ForegroundColor White
