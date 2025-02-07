# Windows PATH Cleanup Tool 🧹

A smart PowerShell script that cleans up your Windows PATH environment variables while preserving critical system and development tools.

## Features
- 🔍 Intelligently scans for active development tools
- 🛡️ Preserves critical Windows paths
- 🧹 Removes duplicates and invalid paths
- 📊 Provides detailed logging of all actions
- ⚡ Shows real-time progress with fancy spinner

## Usage
1. Clone this repository
2. (Optional) Run `run-cleanup-check.bat` first to check current state without making any changes
3. Right-click `run-cleanup-path.bat` and select "Run as Administrator" > More-Info > Run-Anyways
4. Review the proposed changes and confirm 
5. You are done and the problems are all fixed!


## What it does
- Makes a backup of current env's
- Scans your PATH for valid executables
- Separates system and user paths
- Removes duplicates and invalid entries
- Keeps track of important development tools
- Shows you exactly what it's doing

## Safety Features
- Checks for Admin permissions or it wont run 
- Won't remove critical Windows paths
- Backs up paths before modifying them
- Detailed logging of all actions
- Confirmation before making changes

## Contributing
Feel free to open issues or submit PRs!

## License
MIT License - feel free to use and modify!

## Credits
Originally created by Claude & XroSilence