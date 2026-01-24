# ==========================================
#  ABDUZNIK'S AI PROFILE GENERATOR
#  Current Version: v1.1 (Skeleton Mode)
# ==========================================

function gen-profile {
    # --- CONFIGURATION ---
    $ToolVersion = "1.1"
    # ---------------------

    Write-Host "Abduznik AI Profile Gen [v$ToolVersion]" -ForegroundColor Magenta
    
    # 1. Get current username
    $currentUser = gh api user -q ".login"
    if (-not $currentUser) {
        Write-Host "!! Error: Not logged into GitHub CLI. Run 'gh auth login' first." -ForegroundColor Red
        return
    }
    Write-Host "Authenticated as: $currentUser" -ForegroundColor Gray

    # 2. Define the Master Skeleton
    # This matches your preferred style perfectly.
    $skeleton = @"
# Hi, I'm $currentUser

### Computer Science Student | Embedded Systems | Toolsmith

I build tools that bridge the gap between hardware, software, and productivity. Currently focusing on **Embedded Systems** and **Obsidian Plugin Development**.

## Tech Stack
![Python](https://img.shields.io/badge/-Python-3776AB?style=flat&logo=python&logoColor=white)
![C](https://img.shields.io/badge/-C-A8B9CC?style=flat&logo=c&logoColor=white)
![JavaScript](https://img.shields.io/badge/-JavaScript-F7DF1E?style=flat&logo=javascript&logoColor=black)
![Raspberry Pi](https://img.shields.io/badge/-Raspberry_Pi-C51A4A?style=flat&logo=Raspberry-Pi&logoColor=white)
![Godot](https://img.shields.io/badge/-Godot-478CBF?style=flat&logo=godot-engine&logoColor=white)
![Obsidian](https://img.shields.io/badge/-Obsidian-483699?style=flat&logo=obsidian&logoColor=white)

---

## Embedded Systems & Hardware
*Low-level communication and hardware drivers.*

{{SECTION_EMBEDDED}}

## Featured Obsidian Plugins
*Enhancing the "second brain" with AI and automation.*

{{SECTION_OBSIDIAN}}

## Game Development & Graphics
{{SECTION_GAMEDEV}}

---
*Check out my repositories below for more tools and experiments.*
"@

    # 3. Fetch Repos
    Write-Host "Fetching repository list..." -ForegroundColor Cyan
    $rawRepos = gh repo list --visibility=public --limit 100 --json name,description,stargazerCount,language --jq '.[]'
    
    if (-not $rawRepos) { Write-Host "No repos found." -ForegroundColor Red; return }

    $repos = $rawRepos | ConvertFrom-Json
    
    # Format for AI
    $repoListString = ""
    foreach ($r in $repos) {
        if ($r.name -eq $currentUser) { continue } # Skip profile repo
        $desc = if ($r.description) { $r.description } else { "No description" }
        $lang = if ($r.language) { $r.language } else { "Generic" }
        $repoListString += "- [$($r.name)] ($lang): $desc (Stars: $($r.stargazerCount))`n"
    }

    Write-Host "  Gemini is sorting your projects into the skeleton..." -ForegroundColor Cyan

    # 4. Prompt for Structured Filling
    $promptTemplate = @"
Task: Categorize these GitHub repositories into 3 specific sections.
Input Repos:
$repoListString

Output: Return a JSON object with 3 keys: "embedded", "obsidian", "gamedev".
- "embedded": Lists projects related to hardware, drivers, C, Python automation, UART, SPI, ESP32.
- "obsidian": Lists projects related to Obsidian.md plugins, productivity tools, markdown.
- "gamedev": Lists projects related to Godot, Games, Graphics, FFMPEG, Image processing.
- If a project fits nowhere, ignore it.

Format for values: A markdown list string. Example: "- **[RepoName](Link)** - Description"
Do not use markdown code blocks in the JSON values.
"@

    # Safe Execution
    $safePrompt = $promptTemplate.Replace('"', '"')
    $aiOutput = cmd /c "gemini ""$safePrompt"" 2>&1"
    
    # Clean Output
    $rawString = $aiOutput | Where-Object { $_ -notmatch "[STARTUP]" -and $_ -notmatch "Loaded cached" } | Out-String
    # Extract JSON
    if ($rawString -match "(?s)[\[.*\]]" -or $rawString -match "(?s)[\{.*\}]") {
        $cleanJson = $matches[0]
    } else {
        $cleanJson = $rawString
    }
    $cleanJson = $cleanJson -replace '```json', '' -replace '```', ''

    try {
        $data = $cleanJson | ConvertFrom-Json
        
        # 5. Fill the Skeleton
        $finalMd = $skeleton.Replace("{{SECTION_EMBEDDED}}", $data.embedded)
        $finalMd = $finalMd.Replace("{{SECTION_OBSIDIAN}}", $data.obsidian)
        $finalMd = $finalMd.Replace("{{SECTION_GAMEDEV}}", $data.gamedev)
        
        # 6. Save
        $outFile = "PROFILE_DRAFT.md"
        $finalMd | Set-Content $outFile -Encoding UTF8
        
        Write-Host "`nSUCCESS! Draft saved to: $outFile" -ForegroundColor Magenta
        Write-Host "Review it, then copy content to your '$currentUser/$currentUser' repository." -ForegroundColor White
        
    } catch {
        Write-Host "Error parsing AI response. Check raw output." -ForegroundColor Red
        Write-Host $cleanJson
    }
}