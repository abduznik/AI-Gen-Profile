# ==========================================
#  ABDUZNIK'S AI PROFILE GENERATOR
#  Current Version: v3.0 (Smart Update)
# ==========================================

function gen-profile {
    param (
        [switch]$ResetSkeleton,
        [switch]$Force # Forces full regeneration even if a good profile exists
    )

    $ToolVersion = "3.1"
    # PORTABILITY FIX: Use the script's actual location, not $HOME
    $InstallDir = $PSScriptRoot
    $SkeletonFile = "$InstallDir\skeleton.md"

    Write-Host "Abduznik AI Profile Gen [v$ToolVersion]" -ForegroundColor Magenta
    
    $currentUser = gh api user -q ".login"
    $userEmail = gh api user -q ".email"
    # Fallback email if private
    if (-not $userEmail) { $userEmail = "$currentUser@users.noreply.github.com" }

    if (-not $currentUser) {
        Write-Host "!! Error: Not logged into GitHub CLI. Run 'gh auth login' first." -ForegroundColor Red
        return
    }
    Write-Host "Authenticated as: $currentUser" -ForegroundColor Gray
    
    # CRITICAL FIX: Tell Git to use the GitHub CLI token for authentication
    gh auth setup-git 2>$null

    # --- PHASE 0: DISCOVERY & STRATEGY ---
    $strategy = "FULL_GEN"
    $currentProfileContent = ""
    $existingRepoNames = @()

    if (-not $Force) {
        Write-Host "Checking for existing profile repository..." -ForegroundColor Cyan
        try {
            # Fetch raw markdown content
            $currentProfileContent = gh api "repos/$currentUser/$currentUser/readme" --headers "Accept: application/vnd.github.raw" 2>$null
            
            if ($currentProfileContent) {
                # Heuristic: Is it "Good Enough"?
                if ($currentProfileContent.Length -gt 200 -and $currentProfileContent -match "##") {
                    Write-Host "  -> Found existing robust profile." -ForegroundColor Green
                    $strategy = "SMART_UPDATE"
                    
                    # Extract existing repos to avoid duplicates
                    # Regex looks for: github.com/user/repo OR ](repo) links
                    # Simplified: We just look for the repo names in the text
                    $existingRepoNames = $currentProfileContent | Select-String -Pattern "github\.com/$currentUser/([a-zA-Z0-9-_.]+)" -AllMatches | ForEach-Object { $_.Matches.Groups[1].Value }
                } else {
                    Write-Host "  -> Profile exists but looks basic. Recommending full regeneration." -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "  -> No profile repository found ($currentUser/$currentUser)." -ForegroundColor Gray
        }
    }

    # --- PHASE 1: REPO FETCHING ---
    Write-Host "`n[ANALYSIS] Fetching repository list..." -ForegroundColor Cyan
    $rawRepos = gh repo list --visibility=public --limit 100 --json name,description,stargazerCount,primaryLanguage,url,isPrivate,isArchived --jq '.[]'
    
    if (-not $rawRepos) { Write-Host "No repos found." -ForegroundColor Red; return }

    $repos = $rawRepos | ConvertFrom-Json
    $repoLookup = @{}
    $candidates = @()

    foreach ($r in $repos) {
        # Global Filters
        if ($r.name -eq $currentUser) { continue }
        if ($r.isPrivate -eq $true) { continue }
        if ($r.isArchived -eq $true) { continue }
        
        # Explicit Junk Blocklist
        if ($r.name -eq "test") { continue }
        if ($r.name -eq "export") { continue }
        if ($r.name -match "^WPy64") { continue }
        if ($r.name -eq "PROFILE_DRAFT.md") { continue }
        if ($r.name -match "\.exe$") { continue }
        if ($r.name -match "^temp") { continue }

        $repoLookup[$r.name] = $r

        # Strategy Filter
        if ($strategy -eq "SMART_UPDATE") {
            if ($existingRepoNames -contains $r.name) { continue }
            # Also check simpler "Name matches" in markdown text to be safe
            if ($currentProfileContent -match "\b$($r.name)\b") { continue }
        }

        $candidates += $r
    }

    if ($strategy -eq "SMART_UPDATE" -and $candidates.Count -eq 0) {
        Write-Host "  -> Your profile is already up to date! No new repos found." -ForegroundColor Green
        return
    }

    # --- PHASE 2: AI EXECUTION ---
    
    # Model Setup
    $ModelList = @("gemini-3-flash-preview", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemma-3-27b-it")
    
    $prompt = ""
    $candidatesString = $candidates | ForEach-Object { "- Name: $($_.name)`n  Desc: $($_.description)`n  URL: $($_.url)" } | Out-String

    if ($strategy -eq "SMART_UPDATE") {
        Write-Host "  -> Smart Update Mode: merging $($candidates.Count) new repos..." -ForegroundColor Magenta
        
        $prompt = @"
Task: Update a GitHub Profile README.
Existing Markdown:
'''
$currentProfileContent
'''

New Projects to Add:
$candidatesString

Instructions:
1. Integrate the 'New Projects' into the 'Existing Markdown' naturally.
2. Place them under the most appropriate existing categories or headers.
3. If no suitable category exists, create a new one (e.g., '## Recent Projects').
4. MATCH THE STYLE: If the user uses badges, list format, or tables, mimic it exactly.
5. Use the provided URLs for the links.
6. STRICTLY NO EMOJIS in the output. Remove them if present in source.
7. Output the FULL updated Markdown content.
"@
    } else {
        # FULL GEN LOGIC
        Write-Host "  -> Full Generation Mode..." -ForegroundColor Cyan
        
        # We load skeleton if needed
        if ($ResetSkeleton -or -not (Test-Path $SkeletonFile)) {
            $skeletonContent = "# Hi, I am {{USERNAME}}`n`nI build tools and software.`n`n## Tech Stack`n![Python](https://img.shields.io/badge/-Python-3776AB?style=flat&logo=python&logoColor=white) ![C](https://img.shields.io/badge/-C-A8B9CC?style=flat&logo=c&logoColor=white) ![JavaScript](https://img.shields.io/badge/-JavaScript-F7DF1E?style=flat&logo=javascript&logoColor=black)`n`n---`n`n{{DYNAMIC_PROJECTS}}`n`n---`n*Generated by AI-Gen-Profile v$ToolVersion*"
            $skeletonContent | Set-Content $SkeletonFile -Encoding UTF8
        } else {
            $skeletonContent = Get-Content $SkeletonFile -Raw -Encoding UTF8
        }
        $skeletonContent = $skeletonContent.Replace("{{USERNAME}}", $currentUser)

        $prompt = @"
Task: Generate a Project Showcase for a GitHub Profile.
Target Skeleton:
'''
$skeletonContent
'''

Projects List:
$candidatesString

Instructions:
1. Group the projects into 3-6 meaningful categories (e.g., '## AI Tools', '## Embedded Systems').
2. List the projects using this format: '- **[Name](URL)** - Description'.
3. Replace the '{{DYNAMIC_PROJECTS}}' placeholder in the skeleton with your categorized list.
4. STRICTLY NO EMOJIS in the output.
5. Output the FULL final Markdown.
"@
    }

    # --- EXECUTION LOOP ---
    $aiOutput = $null
    $success = $false

    foreach ($model in $ModelList) {
        Write-Host "   -> Attempting with model: $model..." -ForegroundColor DarkGray
        
        try {
            if (Test-Path "/usr/local/bin/gemini") {
                $currentRun = & /usr/local/bin/gemini $prompt --model $model 2>&1 | Out-String
            } else {
                $currentRun = & gemini $prompt --model $model 2>&1 | Out-String
            }
        } catch {
            $currentRun = "Error: " + $_.Exception.Message
        }

        # Cleanup
        if ($currentRun -match "Both GOOGLE_API_KEY and GEMINI_API_KEY are set") {
             $currentRun = $currentRun -replace "Both GOOGLE_API_KEY and GEMINI_API_KEY are set\. Using GOOGLE_API_KEY\.", ""
        }
        $currentRun = $currentRun.Trim()

        # Validation
        if ($currentRun -match "##" -and $currentRun.Length -gt 100) {
             $aiOutput = $currentRun
             $success = $true
             break
        }
        
        if ($currentRun -match "429" -or $currentRun -match "exhausted") {
            Write-Host "      [!] Quota hit. Pausing..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }

    if (-not $success) {
        Write-Host "`n[CRITICAL] AI Generation failed." -ForegroundColor Red
        return
    }
    
    # Post-Processing: Strip Markdown blocks AND Emojis
    # Regex range includes common emoji blocks
    $finalMd = $aiOutput -replace '```markdown', '' -replace '```', ''
    $finalMd = $finalMd -replace "[\uD83C-\uDBFF\uDC00-\uDFFF]+", ""
    
    # Ensure footer is correct (if AI hallucinated or if smart update modified it)
    if ($finalMd -notmatch "Generated by AI-Gen-Profile v$ToolVersion") {
        # Remove old footers if present
        $finalMd = $finalMd -replace "\*Generated by AI-Gen-Profile.*", ""
        $finalMd += "`n`n---`n*Generated by AI-Gen-Profile v$ToolVersion*"
    }
    
    # Save Draft
    $outFile = "$PWD\PROFILE_DRAFT.md"
    $finalMd | Set-Content $outFile -Encoding UTF8
    
    Write-Host "`nSUCCESS! Draft saved to: $outFile" -ForegroundColor Magenta
    
    # --- PHASE 3: PR WORKFLOW ---
    Write-Host "`n[REVIEW]" -ForegroundColor Cyan
    $choice = Read-Host "Do you want to open a PR to update your profile? (y/n)"
    
    if ($choice -eq 'y') {
        Write-Host "  -> Setting up Pull Request..." -ForegroundColor Green
        
        $tempDir = [System.IO.Path]::GetTempPath() + "ai_profile_update_" + [Guid]::NewGuid().ToString()
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        
        try {
            Write-Host "  -> Cloning $currentUser/$currentUser..." -ForegroundColor DarkGray
            gh repo clone "$currentUser/$currentUser" "$tempDir"
            
            $branchName = "ai-profile-update-" + (Get-Date -Format "yyyyMMdd-HHmm")
            Set-Location $tempDir
            git checkout -b $branchName
            
            # GIT IDENTITY FIX: Ensure we can commit
            git config user.name "$currentUser"
            git config user.email "$userEmail"

            $finalMd | Set-Content "README.md" -Encoding UTF8
            
            git add README.md
            git commit -m "Update profile via AI-Gen-Profile"
            git push -u origin $branchName
            
            Write-Host "  -> Opening PR..." -ForegroundColor Green
            gh pr create --title "AI Profile Update" --body "Automated profile update generated by AI-Gen-Profile." --web
            
        } catch {
            Write-Host "  !! Error creating PR: $_" -ForegroundColor Red
            Write-Host "  !! Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        } finally {
            Set-Location $PWD
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "  -> Skipped." -ForegroundColor Gray
    }
}
