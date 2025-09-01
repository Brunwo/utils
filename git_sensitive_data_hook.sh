#!/bin/bash

# Git Pre-commit Hook for Sensitive Data Detection
# Place this file in .git/hooks/pre-commit and make it executable: chmod +x .git/hooks/pre-commit
# Or use it as a standalone script to check staged changes

set -e

# =============================================================================
# CONFIGURATION - Modify these variables to customize behavior
# =============================================================================

# Action modes: "warn", "block", "unstage-files", "unstage-lines"
# - warn: Show warnings but allow commit
# - block: Block commit if sensitive data found
# - unstage-files: Remove entire files from staging if they contain sensitive data
# - unstage-lines: Remove specific lines from staging (requires git add -p workflow)
ACTION_MODE="${SENSITIVE_DATA_ACTION:-block}"

# Enable/disable specific checks (true/false)
CHECK_SECRETS=true
CHECK_PASSWORDS=true
CHECK_API_KEYS=true
CHECK_TOKENS=true
CHECK_CERTIFICATES=true
CHECK_EMAILS=true
CHECK_IPS=true
CHECK_URLS=true
CHECK_CUSTOM_PATTERNS=true

# File patterns to always exclude from checks
EXCLUDE_PATTERNS=(
    "*.min.js"
    "*.min.css"
    "package-lock.json"
    "yarn.lock"
    "*.log"
    "*.zip"
    "*.tar.gz"
    "*.binary"
    "*.jpg"
    "*.png"
    "*.gif"
    "*.pdf"
)

# Directories to exclude
EXCLUDE_DIRS=(
    "node_modules"
    ".git"
    "build"
    "dist"
    "target"
    ".vscode"
    ".idea"
    "vendor"
    "__pycache__"
)

# Custom patterns to detect (add your own regex patterns here)
CUSTOM_PATTERNS=(
    "AKIA[0-9A-Z]{16}"                    # AWS Access Key
    "sk-[a-zA-Z0-9]{32,}"                 # OpenAI API Key
    "ghp_[a-zA-Z0-9]{36}"                 # GitHub Personal Access Token
    "glpat-[a-zA-Z0-9_\-]{20,}"          # GitLab Personal Access Token
    "sk_live_[a-zA-Z0-9]{24,}"           # Stripe Live Key
    "sk_test_[a-zA-Z0-9]{24,}"           # Stripe Test Key
)

# Sensitive file patterns (will be flagged regardless of content)
SENSITIVE_FILE_PATTERNS=(
    ".env*"
    "*.pem"
    "*.key"
    "*.p12"
    "*.pfx"
    "*secret*"
    "*password*"
    "*credential*"
    "config.properties"
    "application-prod.*"
)

# =============================================================================
# FUNCTIONS
# =============================================================================

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}=== Git Pre-commit Sensitive Data Scanner ===${NC}"
    echo -e "${BLUE}Action Mode: ${ACTION_MODE}${NC}"
    echo ""
}

print_usage() {
    echo "Usage: $0 [--help] [--action=warn|block|unstage-files|unstage-lines]"
    echo ""
    echo "Environment variables:"
    echo "  SENSITIVE_DATA_ACTION    Action to take (warn|block|unstage-files|unstage-lines)"
    echo ""
    echo "Actions:"
    echo "  warn           - Show warnings but allow commit"
    echo "  block          - Block commit if sensitive data found"
    echo "  unstage-files  - Remove entire files from staging"
    echo "  unstage-lines  - Remove specific lines from staging"
}

should_exclude_file() {
    local file="$1"
    local basename=$(basename "$file")
    local dirname=$(dirname "$file")
    
    # Check exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$basename" == $pattern ]]; then
            return 0
        fi
    done
    
    # Check exclude directories
    for dir in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$dirname" == *"$dir"* ]]; then
            return 0
        fi
    done
    
    return 1
}

is_sensitive_file() {
    local file="$1"
    local basename=$(basename "$file")
    
    for pattern in "${SENSITIVE_FILE_PATTERNS[@]}"; do
        if [[ "$basename" == $pattern ]]; then
            return 0
        fi
    done
    
    return 1
}

detect_sensitive_patterns() {
    local file="$1"
    local content="$2"
    local issues=()
    
    # Check for common secret patterns
    if [[ "$CHECK_SECRETS" == "true" ]]; then
        # Environment variables with suspicious names
        while IFS= read -r line_info; do
            if [[ -n "$line_info" ]]; then
                local line_num=$(echo "$line_info" | cut -d: -f1)
                local line_content=$(echo "$line_info" | cut -d: -f2-)
                if [[ "$SHOW_LINE_CONTENT" == "true" ]]; then
                    issues+=("Line $line_num: Environment variable with suspicious name -> $line_content")
                else
                    issues+=("Line $line_num: Environment variable with suspicious name")
                fi
            fi
        done < <(echo "$content" | grep -n -E "(PASSWORD|SECRET|KEY|TOKEN|API_KEY|PRIVATE)")
    fi
    
    # Base64 encoded strings (improved detection, excluding URLs)
    if [[ "$CHECK_BASE64" == "true" ]]; then
        while IFS= read -r line_info; do
            if [[ -n "$line_info" ]]; then
                local line_num=$(echo "$line_info" | cut -d: -f1)
                local line_content=$(echo "$line_info" | cut -d: -f2-)
                # Skip if it looks like a URL or has common non-secret patterns
                if [[ ! "$line_content" =~ (https?://|data:|src=|href=|url\() ]]; then
                    if [[ "$SHOW_LINE_CONTENT" == "true" ]]; then
                        issues+=("Line $line_num: Possible base64 encoded secret -> $line_content")
                    else
                        issues+=("Line $line_num: Possible base64 encoded secret")
                    fi
                fi
            fi
        done < <(echo "$content" | grep -n -E "[A-Za-z0-9+/]{${BASE64_MIN_LENGTH},}={0,2}")
    fi
    
    # Check for password patterns
    if [[ "$CHECK_PASSWORDS" == "true" ]]; then
        while IFS= read -r line_info; do
            if [[ -n "$line_info" ]]; then
                local line_num=$(echo "$line_info" | cut -d: -f1)
                local line_content=$(echo "$line_info" | cut -d: -f2-)
                if [[ "$SHOW_LINE_CONTENT" == "true" ]]; then
                    issues+=("Line $line_num: Hardcoded password detected -> $line_content")
                else
                    issues+=("Line $line_num: Hardcoded password detected")
                fi
            fi
        done < <(echo "$content" | grep -n -iE "(password\s*[=:]\s*['\"][^'\"]{3,})")
    fi
    
    # Check custom patterns
    if [[ "$CHECK_CUSTOM_PATTERNS" == "true" ]]; then
        for pattern in "${CUSTOM_PATTERNS[@]}"; do
            while IFS= read -r line_info; do
                if [[ -n "$line_info" ]]; then
                    local line_num=$(echo "$line_info" | cut -d: -f1)
                    local line_content=$(echo "$line_info" | cut -d: -f2-)
                    if [[ "$SHOW_LINE_CONTENT" == "true" ]]; then
                        issues+=("Line $line_num: Custom pattern detected -> $line_content")
                    else
                        issues+=("Line $line_num: Custom pattern detected: $pattern")
                    fi
                fi
            done < <(echo "$content" | grep -n -E "$pattern")
        done
    fi
    
    # Check for API keys
    if [[ "$CHECK_API_KEYS" == "true" ]]; then
        while IFS= read -r line_info; do
            if [[ -n "$line_info" ]]; then
                local line_num=$(echo "$line_info" | cut -d: -f1)
                local line_content=$(echo "$line_info" | cut -d: -f2-)
                if [[ "$SHOW_LINE_CONTENT" == "true" ]]; then
                    issues+=("Line $line_num: Possible API key -> $line_content")
                else
                    issues+=("Line $line_num: Possible API key")
                fi
            fi
        done < <(echo "$content" | grep -n -iE "(api[_-]?key\s*[=:]\s*['\"][^'\"]{10,})")
    fi
    
    # Check for tokens
    if [[ "$CHECK_TOKENS" == "true" ]]; then
        while IFS= read -r line_info; do
            if [[ -n "$line_info" ]]; then
                local line_num=$(echo "$line_info" | cut -d: -f1)
                local line_content=$(echo "$line_info" | cut -d: -f2-)
                if [[ "$SHOW_LINE_CONTENT" == "true" ]]; then
                    issues+=("Line $line_num: Possible token -> $line_content")
                else
                    issues+=("Line $line_num: Possible token")
                fi
            fi
        done < <(echo "$content" | grep -n -iE "(token\s*[=:]\s*['\"][^'\"]{10,})")
    fi
    
    # Check for private keys
    if [[ "$CHECK_CERTIFICATES" == "true" ]]; then
        while IFS= read -r line_info; do
            if [[ -n "$line_info" ]]; then
                local line_num=$(echo "$line_info" | cut -d: -f1)
                local line_content=$(echo "$line_info" | cut -d: -f2-)
                if [[ "$SHOW_LINE_CONTENT" == "true" ]]; then
                    issues+=("Line $line_num: Private key detected -> $line_content")
                else
                    issues+=("Line $line_num: Private key detected")
                fi
            fi
        done < <(echo "$content" | grep -n "BEGIN.*PRIVATE KEY")
    fi
    
    # Check for email addresses (might be sensitive in some contexts)
    if [[ "$CHECK_EMAILS" == "true" ]]; then
        while IFS= read -r line_info; do
            if [[ -n "$line_info" ]]; then
                local line_num=$(echo "$line_info" | cut -d: -f1)
                local line_content=$(echo "$line_info" | cut -d: -f2-)
                if [[ "$SHOW_LINE_CONTENT" == "true" ]]; then
                    issues+=("Line $line_num: Email address detected -> $line_content")
                else
                    issues+=("Line $line_num: Email address detected")
                fi
            fi
        done < <(echo "$content" | grep -n -E "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")
    fi
    
    # Check for IP addresses
    if [[ "$CHECK_IPS" == "true" ]]; then
        while IFS= read -r line_info; do
            if [[ -n "$line_info" ]]; then
                local line_num=$(echo "$line_info" | cut -d: -f1)
                local line_content=$(echo "$line_info" | cut -d: -f2-)
                if [[ "$SHOW_LINE_CONTENT" == "true" ]]; then
                    issues+=("Line $line_num: IP address detected -> $line_content")
                else
                    issues+=("Line $line_num: IP address detected")
                fi
            fi
        done < <(echo "$content" | grep -n -E "([0-9]{1,3}\.){3}[0-9]{1,3}")
    fi
    
    # Print issues
    for issue in "${issues[@]}"; do
        echo "$issue"
    done
}

get_staged_content() {
    local file="$1"
    git show ":$file" 2>/dev/null || echo ""
}

unstage_file() {
    local file="$1"
    echo -e "${YELLOW}Unstaging file: $file${NC}"
    git reset HEAD "$file" >/dev/null 2>&1
}

unstage_lines() {
    local file="$1"
    shift
    local lines=("$@")
    
    echo -e "${YELLOW}Note: Automatic line unstaging is complex. Consider using 'git add -p' to selectively stage changes.${NC}"
    echo -e "${YELLOW}Problematic lines in $file:${NC}"
    for line in "${lines[@]}"; do
        echo -e "${RED}  $line${NC}"
    done
}

# =============================================================================
# MAIN LOGIC
# =============================================================================

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            print_usage
            exit 0
            ;;
        --action=*)
            ACTION_MODE="${1#*=}"
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
    shift
done

print_header

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [[ -z "$STAGED_FILES" ]]; then
    echo -e "${GREEN}No staged files to check.${NC}"
    exit 0
fi

echo "Checking staged files for sensitive data..."
echo ""

FOUND_ISSUES=false
FILES_WITH_ISSUES=()

# Check each staged file
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    
    # Skip excluded files
    if should_exclude_file "$file"; then
        continue
    fi
    
    echo -e "${BLUE}Checking: $file${NC}"
    
    # Check if it's a sensitive file by name
    if is_sensitive_file "$file"; then
        echo -e "${RED}  ⚠️  Sensitive file detected by filename pattern${NC}"
        FOUND_ISSUES=true
        FILES_WITH_ISSUES+=("$file")
        
        case "$ACTION_MODE" in
            "unstage-files")
                unstage_file "$file"
                continue
                ;;
        esac
    fi
    
    # Get staged content
    content=$(get_staged_content "$file")
    if [[ -z "$content" ]]; then
        continue
    fi
    
    # Detect sensitive patterns in content
    issues=$(detect_sensitive_patterns "$file" "$content")
    
    if [[ -n "$issues" ]]; then
        echo -e "${RED}  ⚠️  Sensitive data detected:${NC}"
        while IFS= read -r issue; do
            [[ -n "$issue" ]] && echo -e "${RED}    $issue${NC}"
        done <<< "$issues"
        
        FOUND_ISSUES=true
        FILES_WITH_ISSUES+=("$file")
        
        case "$ACTION_MODE" in
            "unstage-files")
                unstage_file "$file"
                ;;
            "unstage-lines")
                readarray -t line_issues <<< "$issues"
                unstage_lines "$file" "${line_issues[@]}"
                ;;
        esac
    else
        echo -e "${GREEN}  ✓ Clean${NC}"
    fi
    
done <<< "$STAGED_FILES"

echo ""

# Handle results based on action mode
if [[ "$FOUND_ISSUES" == "true" ]]; then
    case "$ACTION_MODE" in
        "warn")
            echo -e "${YELLOW}⚠️  WARNING: Sensitive data detected in staged files, but allowing commit.${NC}"
            echo -e "${YELLOW}Files with issues:${NC}"
            for file in "${FILES_WITH_ISSUES[@]}"; do
                echo -e "${YELLOW}  - $file${NC}"
            done
            exit 0
            ;;
        "block")
            echo -e "${RED}❌ COMMIT BLOCKED: Sensitive data detected in staged files.${NC}"
            echo -e "${RED}Files with issues:${NC}"
            for file in "${FILES_WITH_ISSUES[@]}"; do
                echo -e "${RED}  - $file${NC}"
            done
            echo ""
            echo "To proceed, you can:"
            echo "1. Remove the sensitive data from the files"
            echo "2. Use --action=warn to allow the commit with warnings"
            echo "3. Add files to .gitignore if they should never be committed"
            echo "4. Set SHOW_LINE_CONTENT=false to hide sensitive content in output"
            exit 1
            ;;
        "unstage-files")
            echo -e "${YELLOW}📝 Files with sensitive data have been unstaged:${NC}"
            for file in "${FILES_WITH_ISSUES[@]}"; do
                echo -e "${YELLOW}  - $file${NC}"
            done
            echo "Review the changes and commit again after removing sensitive data."
            exit 1
            ;;
        "unstage-lines")
            echo -e "${YELLOW}📝 Please review and selectively stage your changes using 'git add -p'.${NC}"
            echo -e "${YELLOW}Files with issues:${NC}"
            for file in "${FILES_WITH_ISSUES[@]}"; do
                echo -e "${YELLOW}  - $file${NC}"
            done
            exit 1
            ;;
    esac
else
    echo -e "${GREEN}✅ All staged files are clean of sensitive data.${NC}"
fi

exit 0