# Week 4 – DLP / Secret Scanning Lab

## Objectives

- Add pre-commit hooks for secret scanning
- Run gitleaks locally and in CI/CD pipelines
- Simulate a leaked secret and fix it with history rewriting
- Build defenses for history rewrites, custom regex rules, and CI gate failures
- Multi-VM secret scanning deployment and testing
- Simulate realistic secret leakage scenarios across development workflow
- Build comprehensive DLP defense-in-depth strategies
- Practice incident response for leaked credentials

## Estimated Time

⏱️ **2.5-3 hours** (including VM setup and all exercises)

This lab is comprehensive and includes:
- Pre-commit hook setup and testing (~25-30 minutes)
- Basic secret scanning exercises (~30-40 minutes)
- Advanced history scanning and repair (~35-45 minutes)
- Custom rules and CI integration (~30-40 minutes)
- Multi-VM deployment and testing (~25-30 minutes)
- Incident response simulation (~20-25 minutes)

**Note:** While this lab focuses on CI/CD and Git operations, VM-based exercises simulate realistic development environments where secrets might leak. You can run most exercises locally or on VMs (e.g., `vagrant ssh defender` for development environment simulation).

## VM Setup for This Lab (Optional but Recommended)

For realistic development environment simulation, start these VMs:
```bash
cd /path/to/devops-tutorial
vagrant up defender webserver
```

**VM Roles in This Lab:**
- **defender** (192.168.220.11) - Simulates developer workstation with git repo and pre-commit hooks
- **webserver** (192.168.230.20) - Simulates staging/production server where secrets might be used

**Lab Flow:**
1. Set up secret scanning tools on **defender** (developer machine)
2. Simulate secret leaks in development workflow
3. Test CI/CD pipeline integration
4. Simulate secret exposure on **webserver**
5. Practice incident response and remediation

See [VM Setup Guide](../../VM-SETUP.md) for detailed instructions.

## Tasks

### 1. Setup and Basic Testing

**Option A: Local Machine (Quick Start)**

1. Install pre-commit and gitleaks:
   ```bash
   # Install pre-commit
   pip install pre-commit
   
   # Install gitleaks
   # On Linux:
   wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
   tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
   sudo mv gitleaks /usr/local/bin/
   
   # On macOS:
   brew install gitleaks
   ```

2. Navigate to this lab directory and set up hooks:
   ```bash
   cd labs/week08-dlp
   pre-commit install
   pre-commit run --all-files
   ```

   Expected output:
   - `Passed` for all hooks on clean repository
   - Hook names displayed: `gitleaks`

**Option B: VM-Based Development Environment (Realistic Simulation)**

1. Set up on defender VM (simulating developer workstation):
   
```bash
   vagrant ssh defender
   
   # Install development tools
   sudo apt-get update
   sudo apt-get install -y python3-pip git
   
   # Install pre-commit
   pip3 install pre-commit
   
   # Install gitleaks
   wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
   tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
   sudo mv gitleaks /usr/local/bin/
   sudo chmod +x /usr/local/bin/gitleaks
   
   # Verify installation
   gitleaks version
   pre-commit --version
   ```

2. Clone the repository and set up hooks:
   
```bash
   vagrant ssh defender
   
   # Create a test repository
   mkdir -p ~/dev-workspace/test-app
   cd ~/dev-workspace/test-app
   git init
   
   # Copy pre-commit config
   cat > .pre-commit-config.yaml <<'EOF'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
        args: ["detect", "--source", "."]
EOF
   
   # Install hooks
   pre-commit install
   
   # Test on empty repo
   echo "# Test App" > README.md
   git add README.md
   git commit -m "Initial commit"
   ```
   
   Expected: Commit succeeds with pre-commit running gitleaks.

### 2. Simulate Secret Leakage (Testing Detection)

**Scenario 1: Accidental API Key in Code**

1. Try committing a file with an AWS API key:
   
```bash
   # On defender VM or local machine
   cd ~/dev-workspace/test-app  # or labs/week08-dlp
   
   # Create a config file with secrets
   cat > config.py <<'EOF'
import os

# Database configuration
DB_HOST = "localhost"
DB_PORT = 5432

# API Keys - DO NOT COMMIT!
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Slack webhook
SLACK_WEBHOOK = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
EOF
   
   # Try to commit
   git add config.py
   git commit -m "Add configuration"
   ```
   
   Expected output:
   - Pre-commit hook blocks the commit
   - Gitleaks reports finding secrets with:
     - Line numbers
     - Secret type (e.g., "AWS Access Key")
     - Partial secret value (redacted)
     - Non-zero exit code
   
   Example failure message:
```
   gitleaks............................Failed
   - hook id: gitleaks
   - exit code: 1
   
   Finding:     AWS Access Key
   Secret:      AKIAIOSFODNN7EXAMPLE
   File:        config.py
   Line:        7
   ```

2. Fix the leak and commit properly:
   
```bash
   # Remove secrets from code
   cat > config.py <<'EOF'
import os

# Database configuration
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))

# API Keys - loaded from environment
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")

# Slack webhook - from environment
SLACK_WEBHOOK = os.getenv("SLACK_WEBHOOK")
EOF
   
   # Create example .env file (not committed)
   cat > .env.example <<'EOF'
AWS_ACCESS_KEY_ID=your_key_here
AWS_SECRET_ACCESS_KEY=your_secret_here
SLACK_WEBHOOK=your_webhook_url_here
DB_HOST=localhost
DB_PORT=5432
EOF
   
   # Add .env to gitignore
   echo ".env" >> .gitignore
   
   # Now commit should succeed
   git add config.py .env.example .gitignore
   git commit -m "Add configuration with environment variables"
   ```
   
   Expected: Commit succeeds, pre-commit passes.

**Scenario 2: Private Key Leakage**

1. Simulate SSH private key leak:
   
```bash
   cd ~/dev-workspace/test-app  # or labs/week08-dlp
   
   # Create a fake private key
   cat > deploy_key <<'EOF'
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1234567890abcdefghijklmnopqrstuvwxyz1234567890abc
defghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrstuvwxyz123456
... (truncated for brevity)
-----END RSA PRIVATE KEY-----
EOF
   
   # Try to commit
   git add deploy_key
   git commit -m "Add deployment key"
   ```
   
   Expected:
   - Gitleaks blocks with "RSA private key" detection
   - Shows file name and line numbers
   
2. Proper approach - use SSH agent and document:
   
```bash
   # Remove the private key file
   rm deploy_key
   
   # Create documentation instead
   cat > DEPLOYMENT.md <<'EOF'
# Deployment Guide

## SSH Key Setup

1. Generate SSH key pair:
   ```bash
   ssh-keygen -t rsa -b 4096 -C "deployment@example.com" -f ~/.ssh/deploy_key
   ```

2. Add public key to server:
```bash
   ssh-copy-id -i ~/.ssh/deploy_key.pub user@server
   ```

3. Use SSH agent for authentication:
```bash
   ssh-add ~/.ssh/deploy_key
   ```

**NEVER commit private keys to the repository!**
EOF
   
   git add DEPLOYMENT.md
   git commit -m "Add deployment documentation"
```

**Scenario 3: Database Credentials in Environment File**

1. Accidentally commit .env file:
   
   ```bash
   cd ~/dev-workspace/test-app
   
   # Create .env with real secrets
   cat > .env <<'EOF'
DATABASE_URL=postgresql://admin:SuperSecretPassword123@db.example.com:5432/production
REDIS_URL=redis://:AnotherSecret456@redis.example.com:6379/0
JWT_SECRET=my-super-secret-jwt-key-12345
ENCRYPTION_KEY=abcd1234efgh5678ijkl9012mnop3456
EOF
   
   # Try to commit (should fail if .gitignore is proper)
   git add .env
   git commit -m "Add environment config"
   ```
   
   Expected:
   - If .gitignore excludes .env: warning that file is ignored
   - If .gitignore missing: gitleaks blocks with multiple secret findings

2. Proper secrets management:
   
```bash
   # Ensure .env is ignored
   echo ".env" >> .gitignore
   
   # Create template without secrets
   cat > .env.template <<'EOF'
# Copy to .env and fill in your secrets
DATABASE_URL=postgresql://user:password@host:5432/database
REDIS_URL=redis://:password@host:6379/0
JWT_SECRET=generate-with-openssl-rand
ENCRYPTION_KEY=generate-with-openssl-rand

# To generate secure secrets:
# openssl rand -hex 32
EOF
   
   # Create documentation
   cat > SECRETS.md <<'EOF'
# Secrets Management

## Local Development

1. Copy template: `cp .env.template .env`
2. Fill in development credentials
3. Never commit `.env` file

## Production

Use your cloud provider's secret management:
- AWS: AWS Secrets Manager or Parameter Store
- Azure: Azure Key Vault
- GCP: Google Secret Manager
- Kubernetes: Kubernetes Secrets with encryption at rest

## Secret Rotation

Rotate secrets every 90 days:
1. Generate new secret
2. Update in secret manager
3. Deploy updated applications
4. Remove old secret after grace period
EOF
   
   git add .env.template SECRETS.md .gitignore
   git commit -m "Add secrets management documentation"
   ```

### 3. Advanced Monitoring and Real-Time Detection

**Real-Time Secret Scanning During Development**

Set up continuous monitoring that watches for secrets as you develop:

```bash
vagrant ssh defender

cd ~/dev-workspace/test-app

# Create a monitoring script
cat > /tmp/secret_monitor.sh <<'EOF'
#!/bin/bash
# Real-time secret monitoring for development

WATCH_DIR="${1:-.}"
LOG_FILE="/tmp/secret-scan-$(date +%Y%m%d).log"

echo "Starting real-time secret monitoring on $WATCH_DIR"
echo "Logs: $LOG_FILE"
echo "Press Ctrl+C to stop"

# Initial scan
echo "[$(date)] Initial scan" | tee -a "$LOG_FILE"
gitleaks detect --source "$WATCH_DIR" --report-path /tmp/secrets-report.json 2>&1 | tee -a "$LOG_FILE"

# Watch for changes
inotifywait -m -r -e modify,create,moved_to "$WATCH_DIR" --exclude '\.git' 2>/dev/null | \
while read path action file; do
    echo "[$(date)] Change detected: $path$file ($action)" | tee -a "$LOG_FILE"
    
    # Only scan text files
    if file "$path$file" 2>/dev/null | grep -q "text"; then
        echo "Scanning $path$file..." | tee -a "$LOG_FILE"
        gitleaks detect --source "$path$file" --verbose 2>&1 | \
            grep -E "Finding|Secret|File" | tee -a "$LOG_FILE"
    fi
done
EOF

chmod +x /tmp/secret_monitor.sh

# Install inotify-tools for file watching
sudo apt-get install -y inotify-tools

# Run in background (for demo)
/tmp/secret_monitor.sh ~/dev-workspace/test-app &
MONITOR_PID=$!

# Test it by creating a file with secrets
echo 'API_KEY="sk-1234567890abcdefghijklmnopqrstuvwxyz"' > ~/dev-workspace/test-app/test_secrets.txt

# Check the log
sleep 2
tail -20 /tmp/secret-scan-*.log

# Clean up
kill $MONITOR_PID 2>/dev/null
rm ~/dev-workspace/test-app/test_secrets.txt
```

**Automated Secret Scanning in CI/CD Pipeline**

1. Create a GitHub Actions workflow (already exists in `.github/workflows/`):
   
   ```bash
   # View the existing secret scanning workflow
   cat ../../.github/workflows/secret-scan.yml
   ```

2. Simulate CI/CD failure locally:
   
```bash
   cd ~/dev-workspace/test-app
   
   # Create a script that simulates CI
   cat > simulate_ci.sh <<'EOF'
#!/bin/bash
set -e

echo "=== Simulating CI/CD Pipeline ==="
echo ""

echo "Step 1: Checkout code"
echo "✓ Code checked out"
echo ""

echo "Step 2: Run secret scanner (gitleaks)"
if gitleaks detect --source . --verbose; then
    echo "✓ No secrets found"
else
    echo "✗ SECRETS DETECTED - BUILD FAILED"
    echo ""
    echo "Remediation steps:"
    echo "1. Remove secrets from code"
    echo "2. Use environment variables"
    echo "3. Rotate compromised credentials"
    exit 1
fi
echo ""

echo "Step 3: Run tests (skipped for demo)"
echo "✓ All tests passed"
echo ""

echo "=== CI/CD Pipeline Successful ==="
EOF
   
   chmod +x simulate_ci.sh
   
   # Test with clean code
   ./simulate_ci.sh
   
   # Now add a secret and test
   echo 'password="leaked_password_123"' > bad_config.txt
   git add bad_config.txt
   
   # This should fail
   ./simulate_ci.sh || echo "Build failed as expected"
   
   # Clean up
   rm bad_config.txt
   ```

Expected output hints:

- `pre-commit run --all-files` ends with `Passed` for clean files or prints hook failures with the hook name and line numbers.
- A blocked commit shows `gitleaks: forbidden pattern`, `ERROR: commit contains secret` with secret type, file, and line number, with non-zero exit code.
- Real-time monitor logs show `Change detected` and `Scanning` messages when files are modified.
- CI simulation shows clear pass/fail status with actionable remediation steps.

### Advanced: Break, detect, and repair

### 4. Custom Detection Rules

Gitleaks supports custom rules for organization-specific secrets:

1. **Create custom rules for your organization:**
   
```bash
   cd ~/dev-workspace/test-app
   
   # Create comprehensive custom rules
   cat > .gitleaks.toml <<'EOF'
title = "Custom Organization Rules"

[extend]
# Extend default rules
useDefault = true

[[rules]]
id = "internal-api-key"
description = "Internal API keys for our services"
regex = '''(?i)(internal[_-]?api[_-]?key|company[_-]?key)[\\s:=]+[\\'\"]?([a-z0-9]{32,})[\\'\"]?'''
tags = ["key", "internal"]

[[rules]]
id = "company-domain-password"
description = "Passwords with company domain reference"
regex = '''(?i)(password|passwd|pwd)[\\s:=]+[\\'\"]?([^\\s]+@(example\.com|company\.local))[\\'\"]?'''
tags = ["password", "company"]

[[rules]]
id = "database-connection-string"
description = "Database connection strings"
regex = '''(?i)(mongodb|mysql|postgresql|oracle|mssql)://([^:\\s]+):([^@\\s]+)@([^/\\s]+)'''
tags = ["database", "credentials"]

[[rules]]
id = "jwt-token"
description = "JWT tokens in configuration"
regex = '''eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}'''
tags = ["jwt", "token"]

[[rules]]
id = "private-key-pem"
description = "PEM formatted private keys"
regex = '''-----BEGIN\\s+[A-Z]+\\s+PRIVATE\\s+KEY-----'''
tags = ["key", "private"]

[[rules]]
id = "slack-webhook-url"
description = "Slack webhook URLs"
regex = '''https://hooks\.slack\.com/services/[A-Z0-9]+/[A-Z0-9]+/[A-Za-z0-9]+'''
tags = ["slack", "webhook"]

# Allowlist for test files and examples
[allowlist]
description = "Allowlist for test data"
paths = [
    '''.*test.*\.py''',
    '''.*example.*\.txt''',
    '''.*/fixtures/.*'''
]

# Specific strings that are safe
regexes = [
    '''password.*=.*example''',
    '''key.*=.*YOUR_KEY_HERE''',
]
EOF
   
   # Test custom rules
   cat > test_custom_rules.py <<'EOF'
# This file tests custom rule detection

# Should trigger: internal-api-key
INTERNAL_API_KEY = "abc123def456ghi789jkl012mno345pq"

# Should trigger: company-domain-password
DB_PASSWORD = "mypassword@example.com"

# Should trigger: database-connection-string  
MONGO_URL = "mongodb://admin:secretpass@db.example.com/mydb"

# Should trigger: jwt-token
AUTH_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
EOF
   
   # Run gitleaks with custom config
   gitleaks detect --source . --config .gitleaks.toml --verbose
   
   # Should find multiple violations
   echo ""
   echo "Custom rules detected: $(gitleaks detect --source . --config .gitleaks.toml 2>&1 | grep -c Finding || echo 0) secrets"
   
   # Clean up
   rm test_custom_rules.py
   ```
   
   Expected: Gitleaks finds 4+ secrets using custom rules, each with the rule ID and description.

2. **Test allowlist functionality:**
   
```bash
   cd ~/dev-workspace/test-app
   
   # Create a test file (should be ignored by allowlist)
   mkdir -p tests
   cat > tests/test_auth.py <<'EOF'
# Test file with fake secrets - should be allowed
def test_login():
    test_password = "example_password_123"
    test_api_key = "YOUR_KEY_HERE_abc123"
    assert login(test_password) == True
EOF
   
   # Run gitleaks - should NOT flag test file
   gitleaks detect --source tests/test_auth.py --config .gitleaks.toml
   
   echo "Test file secrets ignored: $?"  # Should be 0 (success)
   
   # Expected output:
   # - Exit code 0 (no secrets found due to allowlist)
   # - No "Finding" messages in output
   # - Gitleaks completes successfully
   ```

3. **Document custom rules:**
   
```bash
   cat > CUSTOM_RULES.md <<'EOF'
# Custom Gitleaks Rules

## Organization-Specific Detections

### Internal API Keys
- **Rule ID:** `internal-api-key`
- **Pattern:** Keys containing "internal_api_key" or "company_key"
- **Example:** `INTERNAL_API_KEY = "abc123..."`

### Company Domain Passwords
- **Rule ID:** `company-domain-password`
- **Pattern:** Passwords with @example.com or @company.local
- **Example:** `password = "user@example.com"`

### Database Connection Strings
- **Rule ID:** `database-connection-string`
- **Pattern:** Full connection strings with credentials
- **Example:** `mongodb://user:pass@host/db`

## Allowlist Policy

### Allowed Paths
- Test files: `*test*.py`
- Example files: `*example*.txt`
- Test fixtures: `fixtures/*`

### Allowed Patterns
- Example placeholders: `password=example`
- Template values: `key=YOUR_KEY_HERE`

## Adding New Rules

1. Edit `.gitleaks.toml`
2. Add rule with unique ID and clear description
3. Test with sample: `gitleaks detect --config .gitleaks.toml`
4. Update this documentation

## Testing Rules

```bash
# Test all rules
gitleaks detect --config .gitleaks.toml --source . --verbose

# Test specific file
gitleaks detect --config .gitleaks.toml --source path/to/file

# Generate report
gitleaks detect --config .gitleaks.toml --report-path report.json
```
EOF
   
   git add .gitleaks.toml CUSTOM_RULES.md
   git commit -m "Add custom gitleaks rules and documentation"
   ```

### 5. Full-History Scanning and Remediation

Secrets may exist in Git history even if removed from current files:

1. **Create a throwaway branch with leaked secrets:**
   
   ```bash
   cd ~/dev-workspace/test-app
   
   # Create a branch with secrets in history
   git checkout -b feature/bad-config
   
   # Commit a file with secrets
   cat > config_history.txt <<'EOF'
# Old configuration - contains secrets!
AWS_ACCESS_KEY = "AKIA1234567890ABCDEF"
AWS_SECRET_KEY = "abcd1234efgh5678ijkl9012mnop3456qrst7890"
DATABASE_PASSWORD = "SuperSecretDBPass123!"
EOF
   
   git add config_history.txt
   git commit -m "WIP: Add config (DO NOT MERGE)"
   
   # Later "fix" by removing file
   git rm config_history.txt
   git commit -m "Remove config file"
   
   # File is gone but exists in history!
   git log --oneline | head -5
   ```

2. **Scan entire Git history:**
   
   ```bash
   # Scan all commits, not just current files
   mkdir -p reports
   gitleaks detect \
     --source . \
     --log-opts="--all" \
     --report-path reports/gitleaks-history.json \
     --report-format json \
     --redact
   
   # View the report
   cat reports/gitleaks-history.json | jq '.' | head -50
   
   # Count secrets found in history
   echo "Secrets in history: $(cat reports/gitleaks-history.json | jq '. | length')"
   
   # Show which commits have secrets
   cat reports/gitleaks-history.json | jq -r '.[] | "\(.Commit): \(.RuleID) in \(.File)"'
   ```
   
   Expected: Report shows secrets with commit hashes, even though files are deleted.

3. **Remediate: Rewrite Git history to remove secrets**
   
   ⚠️ **WARNING:** History rewriting affects all team members. Coordinate before doing this!
   
   **Method A: Using BFG Repo-Cleaner (Recommended for large repos)**
   
```bash
   # Install BFG
   wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar -O /tmp/bfg.jar
   
   # Create passwords file
   cat > /tmp/passwords.txt <<'EOF'
AKIA1234567890ABCDEF
abcd1234efgh5678ijkl9012mnop3456qrst7890
SuperSecretDBPass123!
EOF
   
   # Clone repository mirror
   cd /tmp
   git clone --mirror ~/dev-workspace/test-app test-app.git
   
   # Remove passwords from history
   java -jar /tmp/bfg.jar --replace-text /tmp/passwords.txt test-app.git
   
   # Cleanup and push (in real scenario)
   cd test-app.git
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   
   # This would push to remote (DON'T RUN IN LAB):
   # git push --force
   ```
   
   **Method B: Using git filter-repo (More control)**
   
   ```bash
   cd ~/dev-workspace/test-app
   
   # Install git-filter-repo
   sudo apt-get install -y git-filter-repo || \
     (wget https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo && \
      chmod +x git-filter-repo && \
      sudo mv git-filter-repo /usr/local/bin/)
   
   # Backup first!
   cd ~/dev-workspace
   tar czf test-app-backup-$(date +%Y%m%d).tar.gz test-app/
   
   cd test-app
   
   # Remove specific file from all history
   git filter-repo --invert-paths --path config_history.txt --force
   
   # Verify file is gone from history
   git log --all --full-history --oneline -- config_history.txt
   # Should show nothing
   ```
   
   **Method C: Using git-rebase for recent commits**
   
   ```bash
   cd ~/dev-workspace/test-app
   git checkout feature/bad-config
   
   # Interactive rebase to remove bad commits
   # Find the commit before the secret was added
   git log --oneline | head -5
   
   # Start interactive rebase (replace N with commits to go back)
   git rebase -i HEAD~3
   
   # In the editor:
   # - Change 'pick' to 'drop' for the commit with secrets
   # - Or 'edit' to modify the commit
   # Save and exit
   
   # Force push (in team scenario, coordinate first!)
   # git push --force-with-lease origin feature/bad-config
   ```

4. **Verify remediation:**
   
   ```bash
   cd ~/dev-workspace/test-app
   
   # Re-scan history
   gitleaks detect \
     --source . \
     --log-opts="--all" \
     --report-path reports/gitleaks-history-after.json \
     --report-format json
   
   # Should find 0 secrets
   echo "Secrets remaining: $(cat reports/gitleaks-history-after.json 2>/dev/null | jq '. | length' || echo 0)"
   
   # Verify specific file is gone
   git log --all --full-history -- config_history.txt
   # Should show no commits
   ```

5. **Create incident postmortem:**
   
```bash
   # Generate postmortem with actual date
   INCIDENT_DATE=$(date +%Y-%m-%d)
   cat > INCIDENT_POSTMORTEM.md <<EOF
# Secret Leak Incident Postmortem

## Incident Summary
**Date:** $INCIDENT_DATE
**Severity:** HIGH
**Status:** RESOLVED

## Timeline

### Detection
- **T+0min:** Automated history scan detected secrets in commit abc123
- **T+5min:** Security team notified via alert
- **T+10min:** Incident response initiated

### Investigation
- **T+15min:** Identified 3 secrets in config_history.txt
  - AWS Access Key: AKIA1234567890ABCDEF
  - AWS Secret Key: abcd1234...
  - Database Password: SuperSecret...
- **T+20min:** Confirmed secrets were in commit abc123 from 2 days ago
- **T+25min:** Verified secrets were used in staging environment

### Containment
- **T+30min:** Rotated all affected credentials
  - Generated new AWS keys
  - Changed database password
  - Updated secret manager
- **T+45min:** Verified old credentials no longer work
- **T+50min:** Deployed applications with new secrets

### Remediation
- **T+60min:** Used git-filter-repo to remove secrets from history
- **T+75min:** Force-pushed cleaned history to all branches
- **T+90min:** All team members re-cloned repository
- **T+120min:** Verified no secrets remain in history

## Root Cause
Developer committed configuration file without using pre-commit hooks on a different machine where hooks were not installed.

## Impact
- Secrets exposed in Git history for 48 hours
- Potential unauthorized access window (no suspicious activity detected)
- Required credential rotation and application redeployment

## Remediation Actions Taken
1. ✅ Removed secrets from Git history using git-filter-repo
2. ✅ Rotated all compromised credentials
3. ✅ Updated all environments with new secrets
4. ✅ Verified old credentials are revoked
5. ✅ Confirmed no unauthorized access occurred

## Preventive Measures
1. **Pre-commit hooks mandatory:**
   - Enforced via CI/CD pipeline check
   - Added to developer onboarding checklist
   - Created verification script: `.github/scripts/verify-hooks.sh`

2. **Historical scanning in CI:**
   - Added full history scan to PR builds
   - Weekly scheduled scan of all repositories

3. **Secret rotation policy:**
   - Automated 90-day rotation for all credentials
   - Secrets stored only in secret manager
   - No exceptions for "temporary" credentials

4. **Developer training:**
   - Mandatory security training added to onboarding
   - Monthly security awareness sessions
   - Secret management best practices documentation

5. **Monitoring improvements:**
   - Real-time secret detection in commits
   - Alerts for secret exposure in public repos
   - Quarterly security audits

## Lessons Learned
- Pre-commit hooks are only effective if installed
- Historical scanning catches secrets that bypass prevention
- Quick credential rotation minimizes exposure window
- Clear incident response procedures reduce recovery time

## Follow-up Actions
- [ ] Enforce pre-commit hooks via CI/CD (Due: Week 1)
- [ ] Implement secret rotation automation (Due: Week 2)
- [ ] Conduct security training for all developers (Due: Week 3)
- [ ] Audit all repositories for historical secrets (Due: Week 4)

### Additional Resources (Coming Soon)
- Secret Leak Detection Runbook
- Git History Rewriting Guide
- Incident Response Procedures
EOF
   
   git add INCIDENT_POSTMORTEM.md
   git commit -m "docs: Add secret leak incident postmortem"
   ```

### 6. CI/CD Pipeline Integration

Build a comprehensive CI gate that fails on any secret detection:

1. **Create a CI simulation script:**
   
```bash
   cd ~/dev-workspace/test-app
   
   cat > .github/scripts/secret-scan.sh <<'EOF'
#!/bin/bash
# CI/CD Secret Scanning Gate
set -euo pipefail

REPORT_DIR="reports"
REPORT_FILE="$REPORT_DIR/gitleaks-ci-$(date +%Y%m%d-%H%M%S).json"

mkdir -p "$REPORT_DIR"

echo "=================================================="
echo "  Secret Scanning CI Gate"
echo "=================================================="
echo ""

echo "→ Scanning current files for secrets..."
if gitleaks detect \
    --source . \
    --report-path "$REPORT_FILE" \
    --report-format json \
    --verbose; then
    echo "✓ No secrets found in current files"
    FILES_CLEAN=true
else
    echo "✗ SECRETS FOUND IN CURRENT FILES"
    FILES_CLEAN=false
fi

echo ""
echo "→ Scanning Git history for secrets..."
if gitleaks detect \
    --source . \
    --log-opts="--all" \
    --report-path "${REPORT_FILE%.json}-history.json" \
    --report-format json; then
    echo "✓ No secrets found in Git history"
    HISTORY_CLEAN=true
else
    echo "✗ SECRETS FOUND IN GIT HISTORY"
    HISTORY_CLEAN=false
fi

echo ""
echo "=================================================="
echo "  Scan Results"
echo "=================================================="

if [ "$FILES_CLEAN" = true ] && [ "$HISTORY_CLEAN" = true ]; then
    echo "✓ All checks passed - No secrets detected"
    echo ""
    exit 0
else
    echo "✗ Security check FAILED - Secrets detected"
    echo ""
    
    if [ "$FILES_CLEAN" = false ]; then
        echo "Current files report: $REPORT_FILE"
        cat "$REPORT_FILE" | jq -r '.[] | "  - \(.File):\(.StartLine) [\(.RuleID)]"'
    fi
    
    if [ "$HISTORY_CLEAN" = false ]; then
        echo "History report: ${REPORT_FILE%.json}-history.json"
        cat "${REPORT_FILE%.json}-history.json" | jq -r '.[] | "  - \(.Commit[0:7]) \(.File) [\(.RuleID)]"' | head -20
    fi
    
    echo ""
    echo "Remediation required:"
    echo "1. Remove secrets from code"
    echo "2. Use environment variables or secret manager"
    echo "3. If in history: rewrite Git history (git-filter-repo)"
    echo "4. Rotate any exposed credentials immediately"
    echo ""
    exit 1
fi
EOF
   
   chmod +x .github/scripts/secret-scan.sh
   
   # Test the script
   ./.github/scripts/secret-scan.sh
   ```

2. **Add additional DLP checks:**
   
```bash
   cd ~/dev-workspace/test-app
   
   cat > .github/scripts/dlp-checks.sh <<'EOF'
#!/bin/bash
# Additional DLP checks beyond gitleaks
set -euo pipefail

echo ""
echo "→ Checking for private keys..."
if grep -r "BEGIN.*PRIVATE KEY" --include="*.pem" --include="*.key" --include="*.txt" --include="*.conf" --exclude-dir=.git --exclude-dir=node_modules .; then
    echo "✗ Private keys found in repository"
    exit 1
else
    echo "✓ No private keys found"
fi

echo ""
echo "→ Checking for .env files..."
if find . -name ".env" -not -path "*/\.*" -not -path "*/node_modules/*" | grep -q .; then
    echo "✗ .env files found (should be in .gitignore)"
    find . -name ".env" -not -path "*/\.*"
    exit 1
else
    echo "✓ No .env files found"
fi

echo ""
echo "→ Checking for common secret patterns..."
PATTERNS=(
    "password\s*=\s*['\"][^'\"]{8,}['\"]"
    "api[_-]?key\s*=\s*['\"][^'\"]{20,}['\"]"
    "secret\s*=\s*['\"][^'\"]{16,}['\"]"
)

FOUND=false
for pattern in "${PATTERNS[@]}"; do
    if grep -rE "$pattern" --exclude-dir=.git --exclude-dir=node_modules .; then
        echo "✗ Found pattern: $pattern"
        FOUND=true
    fi
done

if [ "$FOUND" = false ]; then
    echo "✓ No suspicious patterns found"
else
    exit 1
fi

echo ""
echo "✓ All DLP checks passed"
EOF
   
   chmod +x .github/scripts/dlp-checks.sh
   
   # Test it
   ./.github/scripts/dlp-checks.sh
   ```

3. **Create master CI pipeline script:**
   
```bash
   cat > .github/scripts/ci-security.sh <<'EOF'
#!/bin/bash
# Master CI Security Pipeline
set -euo pipefail

EXIT_CODE=0

echo "=========================================="
echo "  CI/CD Security Pipeline"
echo "=========================================="
echo ""

# Run secret scanning
echo "Stage 1: Secret Scanning"
if ./.github/scripts/secret-scan.sh; then
    echo "✓ Secret scanning passed"
else
    echo "✗ Secret scanning failed"
    EXIT_CODE=1
fi

echo ""

# Run DLP checks
echo "Stage 2: DLP Checks"
if ./.github/scripts/dlp-checks.sh; then
    echo "✓ DLP checks passed"
else
    echo "✗ DLP checks failed"
    EXIT_CODE=1
fi

echo ""
echo "=========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ All security checks passed"
    echo "=========================================="
else
    echo "✗ Security checks failed - Build blocked"
    echo "=========================================="
fi

exit $EXIT_CODE
EOF
   
   chmod +x ./.github/scripts/ci-security.sh
   
   mkdir -p .github/scripts
   git add .github/scripts/
   git commit -m "ci: Add comprehensive security scanning pipeline"
   ```

### Example solutions / what “good” looks like

- `.gitleaks.toml` contains a custom regex rule with a clear `description` and `regex` fields, and it triggers on a seeded sample string.
- Historical scan report (`reports/gitleaks-history.json`) shows the original commit hash containing the fake key, and a subsequent run shows `0` findings after rewrite.
- CI simulation exits non-zero with a message containing `Secret detected` and your postmortem lists detection + remediation steps.
- The pipeline DLP step fails with `grep` when a private-key header is present and passes after removal.
- `git status` is clean after removing the seeded secrets, proving the remediation steps were applied.

## Checklist

- [ ] pre-commit is installed and configured
- [ ] gitleaks blocks secrets locally
- [ ] Repository is clean after fixing leaks
- [ ] Custom detector added and verified against a sample secret
- [ ] Full-history scan run at least once with report captured
- [ ] CI/pipeline gate tested with a deliberate failure and documented fix

### Multi-VM Secret Exposure Tasks  
- [ ] Set up development environment on defender VM
- [ ] Simulated secret leak in deployment script
- [ ] Tested bypass detection in CI/CD
- [ ] Deployed secret scanning on webserver (production)
- [ ] Executed complete incident response workflow
- [ ] Rotated compromised credentials
- [ ] Removed secrets from production server
- [ ] Implemented automated server-side scanning
- [ ] Configured cron job for daily scans
- [ ] Created secret management strategy documentation

### Defense-in-Depth Understanding
- [ ] Can explain all four layers of secret detection
- [ ] Understand difference between prevention and detection
- [ ] Know how to use multiple tools for comprehensive coverage
- [ ] Can execute incident response from detection to resolution
- [ ] Understand secret rotation procedures
- [ ] Know when to use different secret storage methods
- [ ] Can configure alerts and monitoring for secret exposure

### Real-World Preparedness
- [ ] Practiced realistic secret leak scenario
- [ ] Executed time-sensitive incident response
- [ ] Coordinated secret rotation across environments
- [ ] Documented lessons learned
- [ ] Created runbooks for future incidents
- [ ] Implemented preventive measures

## Additional Resources

### Recommended Reading
- [Gitleaks Official Documentation](https://github.com/gitleaks/gitleaks)
- [git-filter-repo Manual](https://github.com/newren/git-filter-repo)
- [OWASP Secret Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)

### Tools Comparison
- **Gitleaks:** Fast, accurate, Git-focused
- **TruffleHog:** Deep entropy analysis, slower
- **detect-secrets:** Baseline tracking approach
- **git-secrets:** AWS-specific patterns

### Next Steps
- Week 5: Integrate secret detection alerts into SIEM
- Week 6: Monitor for secret usage in EDR logs
- Advanced: Implement automated secret rotation with HashiCorp Vault
