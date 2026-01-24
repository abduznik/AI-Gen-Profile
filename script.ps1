# ==========================================
#  ABDUZNIK'S AI PROFILE GENERATOR
#  Current Version: v1.2 (Auto-Skeleton)
# ==========================================

function gen-profile {
    param (
        [switch]$ResetSkeleton
    )

    # --- CONFIGURATION ---
    $ToolVersion = "1.2"
    $InstallDir = "$HOME\AI-Gen-Profile"
    $SkeletonFile = "$InstallDir\skeleton.md"
    # ---------------------

    Write-Host "Abduznik AI Profile Gen [v$ToolVersion]" -ForegroundColor Magenta
    
    # 1. Get current username
    $currentUser = gh api user -q ".login"
    if (-not $currentUser) {
        Write-Host "!! Error: Not logged into GitHub CLI. Run 'gh auth login' first." -ForegroundColor Red
        return
    }
    Write-Host "Authenticated as: $currentUser" -ForegroundColor Gray

    # --- PHASE 1: SKELETON MANAGEMENT ---
    
    if ($ResetSkeleton) {
        if (Test-Path $SkeletonFile) { Remove-Item $SkeletonFile }
        Write-Host "  -> Skeleton reset requested." -ForegroundColor Yellow
    }

    if (-not (Test-Path $SkeletonFile)) {
        Write-Host "`n[SETUP] No skeleton found. Learning from your current profile..." -ForegroundColor Cyan
        
        # Fetch current profile
        try {
            $currentReadme = gh repo view "$currentUser/$currentUser" --json body -q .body 2>$null
        } catch {
            Write-Host "  !! Could not fetch current profile. Using default template." -ForegroundColor Red
            $currentReadme = ""
        }

        if ([string]::IsNullOrWhiteSpace($currentReadme)) {
            # Default Fallback
            $skeletonContent = "# Hi, I'm $currentUser`n`nMy Tech Stack...`n`n## Featured Projects`n{{PROJECTS}}`n"
        } else {
            # AI TEMPLATIZING
            Write-Host "  -> Asking Gemini to create a template..." -ForegroundColor Cyan
            
            $templatingPrompt = @"
Task: Convert this GitHub Profile README into a reusable template.
Input README:
$currentReadme

Instructions:
1. Keep the Bio, Header, Tech Stack images, and Section Headers exactly as they are.
2. REMOVE all specific project lists or bullet points under the headers "Embedded Systems", "Obsidian Plugins", "Game Development", or similar project sections.
3. REPLACE the removed project lists with these specific placeholders where appropriate:
   - {{SECTION_EMBEDDED}} (under Embedded/Hardware sections)
   - {{SECTION_OBSIDIAN}} (under Obsidian/Productivity sections)
   - {{SECTION_GAMEDEV}} (under Game Dev/Graphics sections)
   - {{SECTION_OTHER}} (if a generic project section exists)
4. Return ONLY the markdown content of the template.
"@
            $safePrompt = $templatingPrompt.Replace('"', '"')
            $aiOutput = cmd /c "gemini ""$safePrompt"" 2>&1"
            $skeletonContent = $aiOutput | Where-Object { $_ -notmatch "\[STARTUP\]" -and $_ -notmatch "Loaded cached" } | Out-String
            
            # Clean fences
            $skeletonContent = $skeletonContent -replace '```markdown', '' -replace '```', ''
        }
        
        # Save Skeleton
        if (-not (Test-Path $InstallDir)) { New-Item -Type Directory -Path $InstallDir -Force | Out-Null }
        $skeletonContent | Set-Content $SkeletonFile -Encoding UTF8
        Write-Host "  -> Skeleton saved to: $SkeletonFile" -ForegroundColor Green
    } else {
        Write-Host "  -> Loaded existing skeleton." -ForegroundColor Gray
        $skeletonContent = Get-Content $SkeletonFile -Raw -Encoding UTF8
    }

    # --- PHASE 2: GENERATION ---

    # 3. Fetch Repos
    Write-Host "`n[GENERATING] Fetching repository list..." -ForegroundColor Cyan
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

    Write-Host "  Gemini is categorizing your work..." -ForegroundColor Cyan

    # 4. Prompt for Structured Filling
    $fillPrompt = @"
Task: Categorize these GitHub repositories to fill the placeholders in the user's profile.
Input Repos:
$repoListString

Placeholders to fill:
- {{SECTION_EMBEDDED}}: Hardware, Drivers, C, Python automation, UART, SPI, ESP32.
- {{SECTION_OBSIDIAN}}: Obsidian plugins, productivity tools, markdown.
- {{SECTION_GAMEDEV}}: Godot, Games, Graphics, FFMPEG.
- {{SECTION_OTHER}}: Anything that doesn't fit the above (or if the placeholder exists).

Output: Return a JSON object with keys: "embedded", "obsidian", "gamedev", "other".
Format for values: A markdown list string. Example: "- **[RepoName](Link)** - Description"
Do not use markdown code blocks in the JSON values.
"@

    # Safe Execution
    $safePrompt = $fillPrompt.Replace('"', '"')
    $aiOutput = cmd /c "gemini ""$safePrompt"" 2>&1"
    
    # Clean Output
    $rawString = $aiOutput | Where-Object { $_ -notmatch "\[STARTUP\]" -and $_ -notmatch "Loaded cached" } | Out-String
    
    # Extract JSON
    if ($rawString -match "(?s)[\[.*\]]" -or $rawString -match "(?s)[\[.*\]]") {
        $cleanJson = $matches[0]
    } else {
        $cleanJson = $rawString
    }
    $cleanJson = $cleanJson -replace '```json', '' -replace '```', ''

    try {
        $data = $cleanJson | ConvertFrom-Json
        
        # 5. Fill the Skeleton
        $finalMd = $skeletonContent
        
        # We use strict replacement to avoid regex errors with special chars in bio
        if ($data.embedded) { $finalMd = $finalMd.Replace("{{SECTION_EMBEDDED}}", $data.embedded) }
        if ($data.obsidian) { $finalMd = $finalMd.Replace("{{SECTION_OBSIDIAN}}", $data.obsidian) }
        if ($data.gamedev) { $finalMd = $finalMd.Replace("{{SECTION_GAMEDEV}}", $data.gamedev) }
        if ($data.other) { $finalMd = $finalMd.Replace("{{SECTION_OTHER}}", $data.other) }
        
        # Cleanup any unused placeholders
        $finalMd = $finalMd -replace "\{\{SECTION_[A-Z]+\}"", ""
        
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
