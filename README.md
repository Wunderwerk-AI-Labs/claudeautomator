# ClaudeAutomator

Automatically run Claude Code iteratively on your codebase using only your **free quota** (no paid credits). When your quota is depleted, ClaudeAutomator waits for the embargo period to elapse and then resumes.

## Features

- **Free quota only**: Uses `--max-cost 0` by default to avoid spending credits
- **Iterative improvements**: Run Claude Code repeatedly to incrementally improve your codebase
- **Smart rate limit detection**: Automatically detects when quota is depleted
- **Auto-resume**: Parses wait times from Claude output and resumes after the embargo period
- **Configurable**: Supports config files, command-line args, and environment variables
- **Logging**: Full logging of all iterations and wait periods

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/claudeautomator.git
cd claudeautomator
chmod +x claudeautomator.sh
```

## Prerequisites

- [Claude Code CLI](https://claude.com/claude-code) installed and authenticated
- Bash shell

## Quick Start

1. Copy the example files:
   ```bash
   cp config.env.example config.env
   cp prompt.txt.example prompt.txt
   ```

2. Edit `config.env` with your target directory:
   ```bash
   TARGET_DIR="/path/to/your/webapp"
   ```

3. Customize `prompt.txt` with your improvement instructions

4. Run:
   ```bash
   ./claudeautomator.sh
   ```

## Usage

```bash
# Using config files
./claudeautomator.sh

# Using command line arguments
./claudeautomator.sh -d /path/to/project -p "Fix all TypeScript errors"

# Limit iterations
./claudeautomator.sh -d /path/to/project -n 10

# Custom wait time (minutes)
./claudeautomator.sh -d /path/to/project -w 120
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-p, --prompt TEXT` | Prompt to send to Claude Code |
| `-f, --prompt-file FILE` | File containing the prompt (default: ./prompt.txt) |
| `-d, --directory DIR` | Target directory for Claude Code |
| `-n, --max-iterations N` | Maximum iterations, 0=unlimited (default: 0) |
| `-w, --wait-minutes N` | Default wait time when rate limited (default: 60) |
| `-m, --model MODEL` | Claude model to use |
| `-l, --log FILE` | Log file path (default: ./claudeautomator.log) |
| `--use-credits` | Allow using paid credits (default: free quota only) |
| `-h, --help` | Show help message |

## Running as a Background Service

To run ClaudeAutomator continuously in the background:

```bash
# Using nohup
nohup ./claudeautomator.sh > /dev/null 2>&1 &

# Using screen
screen -S claudeautomator ./claudeautomator.sh

# Using tmux
tmux new-session -d -s claudeautomator './claudeautomator.sh'
```

### Using systemd (recommended for servers)

Create `/etc/systemd/system/claudeautomator.service`:

```ini
[Unit]
Description=ClaudeAutomator - Iterative Claude Code Runner
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/path/to/claudeautomator
ExecStart=/path/to/claudeautomator/claudeautomator.sh
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl enable claudeautomator
sudo systemctl start claudeautomator
sudo systemctl status claudeautomator

# View logs
journalctl -u claudeautomator -f
```

## Example Prompts

### General Improvement
```
Review this codebase and make one meaningful improvement.
Focus on bugs, performance, security, or code quality.
Make exactly ONE focused change per iteration.
Commit your changes with a descriptive message.
```

### Bug Hunting
```
Find and fix one bug in this codebase. Look for:
- Null/undefined errors
- Race conditions
- Logic errors
- Edge cases not handled
Fix only ONE bug and commit with a clear message.
```

### Security Hardening
```
Find and fix one security issue in this codebase. Check for:
- SQL injection
- XSS vulnerabilities
- Authentication/authorization flaws
- Sensitive data exposure
Fix ONE issue and commit with details.
```

### Test Coverage
```
Add tests for untested code in this project.
Focus on critical paths and edge cases.
Add tests for ONE function or component.
Ensure tests pass before committing.
```

## License

MIT
