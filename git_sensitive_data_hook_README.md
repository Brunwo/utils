Installation & Usage

As a Git Hook:

# Copy to your repository
cp git_sensitive_data_hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit


As a Standalone Script:
./git_sensitive_data_hook.sh --action=warn

Environment Configuration:
export SENSITIVE_DATA_ACTION=warn
git commit -m "your message"


Configuration Examples
Customize behavior by editing the variables at the top:

Turn off email detection: CHECK_EMAILS=false
Add custom patterns: CUSTOM_PATTERNS+=("your-pattern-here")
Change default action: ACTION_MODE="warn"
Exclude additional files: EXCLUDE_PATTERNS+=("*.your-extension")
