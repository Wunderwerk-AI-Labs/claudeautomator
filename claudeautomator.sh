#!/bin/bash

# ClaudeAutomator - Run Claude Code iteratively until credits depleted, then wait and resume
# Usage: ./claudeautomator.sh [options]

set -e

# Default configuration
CONFIG_FILE="${CONFIG_FILE:-./config.env}"
PROMPT_FILE="${PROMPT_FILE:-./prompt.txt}"
TARGET_DIR="${TARGET_DIR:-.}"
MAX_ITERATIONS="${MAX_ITERATIONS:-0}"  # 0 = unlimited
LOG_FILE="${LOG_FILE:-./claudeautomator.log}"
DEFAULT_WAIT_MINUTES="${DEFAULT_WAIT_MINUTES:-60}"
CLAUDE_MODEL="${CLAUDE_MODEL:-}"  # Empty = use default

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load config file if exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--prompt)
            PROMPT="$2"
            shift 2
            ;;
        -f|--prompt-file)
            PROMPT_FILE="$2"
            shift 2
            ;;
        -d|--directory)
            TARGET_DIR="$2"
            shift 2
            ;;
        -n|--max-iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        -w|--wait-minutes)
            DEFAULT_WAIT_MINUTES="$2"
            shift 2
            ;;
        -m|--model)
            CLAUDE_MODEL="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "ClaudeAutomator - Run Claude Code iteratively with rate limit handling"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -p, --prompt TEXT       Prompt to send to Claude Code"
            echo "  -f, --prompt-file FILE  File containing the prompt (default: ./prompt.txt)"
            echo "  -d, --directory DIR     Target directory for Claude Code (default: current)"
            echo "  -n, --max-iterations N  Maximum iterations, 0=unlimited (default: 0)"
            echo "  -w, --wait-minutes N    Default wait time when rate limited (default: 60)"
            echo "  -m, --model MODEL       Claude model to use (optional)"
            echo "  -l, --log FILE          Log file path (default: ./claudeautomator.log)"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Environment variables / config.env:"
            echo "  PROMPT, PROMPT_FILE, TARGET_DIR, MAX_ITERATIONS,"
            echo "  DEFAULT_WAIT_MINUTES, CLAUDE_MODEL, LOG_FILE"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to log messages
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to extract wait time from Claude output
extract_wait_time() {
    local output="$1"

    # Look for common rate limit patterns
    # Pattern: "try again in X minutes" or "wait X minutes" or "X minutes remaining"
    local minutes=$(echo "$output" | grep -oiE '(try again in |wait |in )([0-9]+) ?(minutes?|mins?)' | grep -oE '[0-9]+' | head -1)

    if [[ -n "$minutes" ]]; then
        echo "$minutes"
        return
    fi

    # Pattern: "X hours"
    local hours=$(echo "$output" | grep -oiE '(try again in |wait |in )([0-9]+) ?(hours?)' | grep -oE '[0-9]+' | head -1)
    if [[ -n "$hours" ]]; then
        echo $((hours * 60))
        return
    fi

    # Pattern: HH:MM:SS or similar timestamp
    local time_match=$(echo "$output" | grep -oE '[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?' | head -1)
    if [[ -n "$time_match" ]]; then
        # Parse as duration
        IFS=':' read -ra parts <<< "$time_match"
        if [[ ${#parts[@]} -eq 3 ]]; then
            echo $(( ${parts[0]} * 60 + ${parts[1]} + 1 ))
        elif [[ ${#parts[@]} -eq 2 ]]; then
            echo $(( ${parts[0]} * 60 + ${parts[1]} + 1 ))
        fi
        return
    fi

    # No time found, return empty
    echo ""
}

# Function to check if output indicates rate limiting
is_rate_limited() {
    local output="$1"
    local exit_code="$2"

    # Check for common rate limit indicators
    if echo "$output" | grep -qiE '(rate.?limit|quota|credits?.?(exhaust|deplet|run.?out)|too many requests|429|try again|embargo|cooldown|usage.?limit)'; then
        return 0
    fi

    # Non-zero exit with certain patterns
    if [[ "$exit_code" -ne 0 ]] && echo "$output" | grep -qiE '(limit|quota|wait|retry)'; then
        return 0
    fi

    return 1
}

# Function to run Claude Code
run_claude() {
    local prompt="$1"
    local output_file=$(mktemp)
    local exit_code=0

    # Build claude command
    local cmd="claude --dangerously-skip-permissions"

    if [[ -n "$CLAUDE_MODEL" ]]; then
        cmd="$cmd --model $CLAUDE_MODEL"
    fi

    # Run claude and capture output
    log "${BLUE}Running Claude Code...${NC}"

    cd "$TARGET_DIR"

    # Use print mode to get structured output, pipe prompt via stdin
    set +e
    output=$(echo "$prompt" | $cmd --print 2>&1)
    exit_code=$?
    set -e

    echo "$output" > "$output_file"

    # Return results
    echo "$output_file:$exit_code"
}

# Main function
main() {
    log "${GREEN}=== ClaudeAutomator Started ===${NC}"
    log "Target directory: $TARGET_DIR"
    log "Max iterations: ${MAX_ITERATIONS:-unlimited}"

    # Get prompt
    if [[ -z "$PROMPT" ]]; then
        if [[ -f "$PROMPT_FILE" ]]; then
            PROMPT=$(cat "$PROMPT_FILE")
            log "Loaded prompt from: $PROMPT_FILE"
        else
            log "${RED}Error: No prompt provided. Use -p or create $PROMPT_FILE${NC}"
            exit 1
        fi
    fi

    log "Prompt: ${PROMPT:0:100}..."

    # Ensure target directory exists
    if [[ ! -d "$TARGET_DIR" ]]; then
        log "${RED}Error: Target directory does not exist: $TARGET_DIR${NC}"
        exit 1
    fi

    local iteration=0
    local consecutive_errors=0
    local max_consecutive_errors=5

    while true; do
        iteration=$((iteration + 1))

        # Check max iterations
        if [[ "$MAX_ITERATIONS" -gt 0 ]] && [[ "$iteration" -gt "$MAX_ITERATIONS" ]]; then
            log "${GREEN}Reached maximum iterations ($MAX_ITERATIONS). Stopping.${NC}"
            break
        fi

        log "${YELLOW}--- Iteration $iteration ---${NC}"

        # Run Claude
        result=$(run_claude "$PROMPT")
        output_file=$(echo "$result" | cut -d: -f1)
        exit_code=$(echo "$result" | cut -d: -f2)
        output=$(cat "$output_file")
        rm -f "$output_file"

        # Check for rate limiting
        if is_rate_limited "$output" "$exit_code"; then
            log "${YELLOW}Rate limit detected!${NC}"

            # Extract wait time
            wait_minutes=$(extract_wait_time "$output")

            if [[ -z "$wait_minutes" ]]; then
                wait_minutes=$DEFAULT_WAIT_MINUTES
                log "Could not determine wait time, using default: ${wait_minutes} minutes"
            else
                log "Detected wait time: ${wait_minutes} minutes"
            fi

            # Add buffer time
            wait_minutes=$((wait_minutes + 2))

            local resume_time=$(date -d "+${wait_minutes} minutes" '+%Y-%m-%d %H:%M:%S')
            log "${BLUE}Waiting ${wait_minutes} minutes until: $resume_time${NC}"

            sleep $((wait_minutes * 60))

            log "${GREEN}Resuming after wait period...${NC}"
            consecutive_errors=0
            continue
        fi

        # Check for other errors
        if [[ "$exit_code" -ne 0 ]]; then
            consecutive_errors=$((consecutive_errors + 1))
            log "${RED}Error (exit code: $exit_code). Consecutive errors: $consecutive_errors${NC}"

            if [[ "$consecutive_errors" -ge "$max_consecutive_errors" ]]; then
                log "${RED}Too many consecutive errors. Stopping.${NC}"
                echo "Last output:"
                echo "$output" | tail -50
                exit 1
            fi

            # Short wait before retry on error
            log "Waiting 30 seconds before retry..."
            sleep 30
            continue
        fi

        # Success
        consecutive_errors=0
        log "${GREEN}Iteration $iteration completed successfully${NC}"

        # Log output summary
        local output_lines=$(echo "$output" | wc -l)
        log "Output: $output_lines lines"

        # Brief pause between successful iterations
        log "Pausing 5 seconds before next iteration..."
        sleep 5
    done

    log "${GREEN}=== ClaudeAutomator Finished ===${NC}"
}

# Run main
main
