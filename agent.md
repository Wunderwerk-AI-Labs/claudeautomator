# ClaudeAutomator - Agent Reference

Bash automation tool that runs Claude Code CLI iteratively using free quota with automatic rate limit handling.

## Overview

ClaudeAutomator runs Claude Code in a loop, making incremental improvements to a codebase. It automatically detects rate limits, extracts wait times, pauses, and resumes when quota refreshes.

## Files

```
claudeautomator/
├── claudeautomator.sh        # Main executable script
├── README.md                 # Documentation
├── config.env.example        # Configuration template
├── prompt.txt.example        # Example prompt
└── claudeautomator.log       # Runtime log
```

## How It Works

1. Runs Claude Code with custom prompt against target directory
2. Uses `--max-cost 0` to stay within free quota
3. Monitors output for rate limit keywords
4. Extracts wait time from Claude's response
5. Sleeps for wait time + 2min buffer
6. Automatically resumes

## Usage

```bash
# Basic usage
./claudeautomator.sh -p "Review code and fix one bug" -d /path/to/project

# With iterations limit
./claudeautomator.sh -p "Add tests" -d /path/to/project -n 10

# Using config file
cp config.env.example config.env
# Edit config.env with your settings
./claudeautomator.sh
```

## Configuration

Three levels (in order of precedence):
1. Command-line arguments
2. Environment variables
3. `config.env` file

### Command-Line Arguments

| Flag | Description |
|------|-------------|
| `-p` | Prompt text |
| `-d` | Target directory |
| `-n` | Max iterations (0 = unlimited) |
| `-w` | Wait time between iterations (seconds) |
| `-m` | Max consecutive errors before stopping |
| `-l` | Log file path |
| `--use-credits` | Allow paid credits (removes --max-cost 0) |

### Environment Variables

```bash
PROMPT="Your improvement prompt"
TARGET_DIR=/path/to/project
MAX_ITERATIONS=0
WAIT_BETWEEN=5
MAX_ERRORS=5
LOG_FILE=claudeautomator.log
```

## Use Cases

**General improvement**:
```bash
./claudeautomator.sh -p "Review the codebase and make one meaningful improvement. Focus on code quality, readability, or small bug fixes." -d ./project
```

**Bug hunting**:
```bash
./claudeautomator.sh -p "Find and fix one bug in this codebase. Look for edge cases, null checks, or error handling issues." -d ./project
```

**Security hardening**:
```bash
./claudeautomator.sh -p "Find and fix one security vulnerability. Check for injection, XSS, or authentication issues." -d ./project
```

**Test coverage**:
```bash
./claudeautomator.sh -p "Add tests for one untested function. Focus on edge cases and error conditions." -d ./project
```

## Rate Limit Handling

Detects keywords: `quota`, `credits`, `rate limit`, `embargo`, `exceeded`, `try again`

Extracts wait times from patterns:
- "30 minutes"
- "1 hour"
- "01:30:00"
- "in X minutes/hours"

Default wait: 60 minutes if time not parseable.

## Logging

All output logged to `claudeautomator.log` with timestamps:
```
[2024-01-15 10:30:00] Starting iteration 1
[2024-01-15 10:31:00] Iteration 1 completed successfully
[2024-01-15 10:31:05] Starting iteration 2
[2024-01-15 10:32:00] Rate limit detected, waiting 32 minutes
[2024-01-15 11:04:00] Resuming after rate limit
```

## Deployment Options

**Direct execution**:
```bash
./claudeautomator.sh
```

**Background (nohup)**:
```bash
nohup ./claudeautomator.sh > /dev/null 2>&1 &
```

**Screen session**:
```bash
screen -S automator
./claudeautomator.sh
# Ctrl+A, D to detach
```

**systemd service**:
```ini
[Unit]
Description=Claude Automator
After=network.target

[Service]
Type=simple
User=robot
WorkingDirectory=/home/robot/claudeautomator
ExecStart=/home/robot/claudeautomator/claudeautomator.sh
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
```

## Key Behaviors

- **Free quota only** by default (`--max-cost 0`)
- **5 consecutive errors** stops execution
- **30 second retry** on transient errors
- **2 minute buffer** added to wait times
- **5 second pause** between successful iterations

## Dependencies

- Bash shell
- Claude Code CLI (`claude` command)
- Authenticated Claude session

## Common Tasks

### Change prompt
Edit `-p` argument or `PROMPT` in config.env.

### Target different project
Change `-d` argument or `TARGET_DIR`.

### Allow paid credits
Add `--use-credits` flag (removes --max-cost 0 limit).

### Stop execution
- Kill process: `pkill -f claudeautomator`
- Or: Ctrl+C if running in foreground
