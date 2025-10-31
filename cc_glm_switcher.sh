#!/usr/bin/env bash

# Claude Code ↔ Z.AI GLM Model Switcher

ROOT_CC="$HOME/.claude"
CONFIG_DIR="./configs"
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="cc-glm-switcher"

# Parse command line arguments
case "${1:-}" in
    cc|glm)
        MODEL="$1"
        ;;
    list)
        ls -1 "$CONFIG_DIR"/backup_*.json 2>/dev/null || echo "No backup files found."
        exit 0
        ;;
    show)
        if [ -f "$ROOT_CC/settings.json" ]; then
            if command -v jq &> /dev/null; then
                jq '.' "$ROOT_CC/settings.json"
            else
                cat "$ROOT_CC/settings.json"
            fi
        else
            echo "Error: Settings file not found" >&2
            exit 1
        fi
        exit 0
        ;;
    restore)
        latest_backup=$(ls -1t "$CONFIG_DIR"/backup_*.json 2>/dev/null | head -1)
        if [ -z "$latest_backup" ]; then
            echo "Error: No backup files found." >&2
            exit 1
        fi
        echo "Restoring from latest backup"
        cp "$latest_backup" "$ROOT_CC/settings.json"
        exit $?
        ;;
    -V|--version)
        echo "$SCRIPT_NAME v$SCRIPT_VERSION"
        exit 0
        ;;
    -h|--help)
        echo "Usage: $0 {cc|glm|list|restore|show}"
        echo "Commands: cc=claude, glm=z.ai, list=backups, restore=latest, show=settings"
        exit 0
        ;;
    *)
        echo "Error: Command must be specified"
        echo "Usage: $0 {cc|glm|list|restore} [OPTIONS]"
        echo "Use -h or --help for usage information"
        exit 1
        ;;
esac

# Check dependencies
if ! command -v claude &> /dev/null; then
    echo "Error: claude command not found. See https://github.com/anthropics/claude-code for installation instructions." >&2
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq command not found. Please install jq." >&2
    exit 1
fi

# Ensure directories exist
mkdir -p "$CONFIG_DIR" "$ROOT_CC"

# Create backup and cleanup old ones
backup_file="$CONFIG_DIR/backup_$(date +%s).json"
cp "$ROOT_CC/settings.json" "$backup_file" 2>/dev/null || echo '{}' > "$backup_file"
ls -1t "$CONFIG_DIR"/backup_*.json 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true

# Load .env if exists
if [ -f ".env" ]; then
    set -a
    source ".env"
    set +a
fi

# Switch model
if [ "$MODEL" == "glm" ]; then
    if [ -z "$ZAI_AUTH_TOKEN" ]; then
        echo "Error: ZAI_AUTH_TOKEN not found in .env file" >&2
        exit 1
    fi

    cat > "$ROOT_CC/settings.json" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "$ZAI_AUTH_TOKEN",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "CLAUDE_MODEL_PROVIDER": "zhipu"
  }
}
EOF
    echo "Switched to Z.AI GLM model"
else
    echo '{}' > "$ROOT_CC/settings.json"
    echo "Switched to Claude Code model"
fi
