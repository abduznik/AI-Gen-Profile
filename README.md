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
3. **GitHub CLI**

## Installation

```powershell
irm https://raw.githubusercontent.com/abduznik/AI-Gen-Profile/main/setup.ps1 | iex
```

## Usage

Type `gen-profile` in PowerShell.

1. It fetches your current `username/username` README.
2. It fetches your public repositories.
3. Gemini groups your projects and writes a new "Featured Work" section.
4. It combines your old header with the new list and saves it to `PROFILE_DRAFT.md`.
5. You can then copy it to your actual profile.

## License

MIT
