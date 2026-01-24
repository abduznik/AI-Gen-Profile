# Abduznik's AI Profile Generator

The ultimate GitHub Profile README generator.

## Features

- **Preserves Your Personality:** Keeps your existing Bio, Tech Stack, and header images.
- **AI-Powered Showcase:** Automatically scans *all* your repositories, categorizes them (e.g., "Embedded Systems," "Web Tools"), and writes a "Featured Projects" section.
- **Dynamic Updates:** Run it whenever you create a new project to keep your profile fresh.
- **Safe Mode:** Generates a `PROFILE_DRAFT.md` first so you can review before publishing.

## Prerequisites

1. **PowerShell**
2. **Gemini CLI**
   - Install via npm: `npm install -g @google/gemini-cli`
   - Run once to authenticate: `gemini chat`
3. **GitHub CLI**
   - Install via Winget: `winget install GitHub.cli`
   - Authenticate: `gh auth login`

## Installation

Run this command in PowerShell to install:

```powershell
irm https://raw.githubusercontent.com/abduznik/AI-Gen-Profile/main/setup.ps1 | iex
```

## Usage

Type `gen-profile` in PowerShell.

1. **First Run:** It fetches your *current* profile to learn your style and creates a local `skeleton.md`.
2. **Subsequent Runs:** It fetches your latest repositories, categorizes them using AI, and fills the skeleton with fresh data.
3. **Review:** It saves the result to `PROFILE_DRAFT.md`. Copy this to your `username/username` repository.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.