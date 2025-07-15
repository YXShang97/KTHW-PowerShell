# GitHub Copilot Instructions

## Project Overview
This repository contains PowerShell scripts for the "Kubernetes the Hard Way" tutorial, adapted for Azure infrastructure. The project demonstrates how to bootstrap a Kubernetes cluster manually to understand the underlying components and their interactions.

## Code Style and Conventions

### Command Verification and Safety
- **Verify Ambiguous Commands**: If you aren't sure about a command's impact or parameters, ask follow-up questions before executing
- **Confirm Destructive Operations**: Always confirm before running commands that delete, modify, or restart services
- **Validate Prerequisites**: Check that required resources exist before attempting operations
- **Test in Safe Mode**: When uncertain, provide commands for testing/validation before full execution

### Principle of Simplicity
- **Always provide the most straightforward and minimalist solution possible**
- **Solve problems with the least amount of code and complexity**
- **Avoid premature optimization or over-engineering**
- **Prioritize readability and maintainability over "clever" solutions**
- **Focus on the core request without adding unnecessary features**
- **Generate code that directly addresses the user's request**

### PowerShell Scripting Standards
- Use PowerShell 5.1+ features and syntax
- Follow verb-noun naming conventions for functions
- Use approved PowerShell verbs (Get-, Set-, New-, Remove-, etc.)
- Include comprehensive error handling with try-catch blocks
- Use Write-Host with appropriate colors for user feedback:
  - Cyan: Section headers and titles
  - Yellow: Progress messages and warnings
  - Green: Success messages (with ✅ emoji)
  - Red: Error messages (with ❌ emoji)
  - White: General information
  - Gray: Command output

### Function Design
- Include parameter validation and type constraints
- Use proper parameter attributes ([string], [switch], etc.)
- Include comprehensive help documentation with .SYNOPSIS, .DESCRIPTION, .PARAMETER, .EXAMPLE
- Return appropriate objects or boolean values for success/failure

### Azure Integration
- Always use Azure CLI commands for Azure resource management
- Include proper error handling for Azure CLI operations
- Use JSON output format with `-o json` or `-o tsv` for parsing
- Validate Azure CLI authentication before running scripts

### SSH and Remote Operations
- Use consistent SSH key management and connection patterns
- Include timeout handling for SSH operations
- Validate SSH connectivity before proceeding with remote operations
- Use proper escaping for remote commands

### Cross-Platform Considerations
- **Always use Unix line endings (LF) for files that will be transferred to Linux systems**
- **Use `[System.IO.File]::WriteAllText()` with explicit encoding for config files**
- **Test PowerShell here-strings (`@"..."@`) carefully when content goes to Linux**
- **Validate file encoding before SSH transfer operations**

#### Line Ending Fix Pattern:
```powershell
$content = $content -replace "`r`n", "`n"  # Convert CRLF to LF
[System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
```

## File Organization

### Script Structure
- Each step should be in its own numbered directory (01/, 02/, etc.)
- Include execution output files (*-execution-output.md) for documentation
- Store temporary files in appropriate system temp directories
- Clean up temporary files after use

### Repository Navigation Requirements
- **All execution output files must include standardized navigation sections**
- **Navigation should provide seamless browsing from README through all tutorial steps**
- **Use consistent navigation table format with Previous/Current/Next links**
- **Include tutorial progress section with links to main resources**

#### Required Navigation Template:
```markdown
---

## 🧭 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [⬅️ Step XX: Previous Title](../XX/XX-execution-output.md) | **Step YY: Current Title** | [➡️ Step ZZ: Next Title](../ZZ/ZZ-execution-output.md) |

### 📋 Tutorial Progress
- [🏠 Main README](../../README.md)
- [📖 All Tutorial Steps](../../README.md#-tutorial-steps)
- [🔧 Troubleshooting](../troubleshooting/Repair-Cluster.ps1)
- [✅ Cluster Validation](../validation/Validate-Cluster.ps1)
```

### Simplicity Guidelines
- **Keep functions simple and focused on single responsibilities**
- **Avoid over-engineering with excessive error handling layers**
- **Use clear, straightforward code over complex abstractions**
- **Focus on essential functionality rather than comprehensive coverage**
- **Prefer readable code over overly clever implementations**

### Documentation Requirements
- Every script must include a comprehensive header with .SYNOPSIS and .DESCRIPTION
- Include prerequisites section listing required previous steps
- Document all parameters and their expected values
- Provide troubleshooting guidance for common issues
- **All execution output files must include the standardized navigation section**
- **Navigation links must be tested and functional for GitHub repository browsing**
- **Update navigation when adding, removing, or reordering tutorial steps**

## Security Practices
- Never hardcode passwords or sensitive information
- Use Azure Key Vault or environment variables for secrets
- Implement proper certificate and key file handling
- Validate file permissions for certificate files (600/700)

## Error Handling and Validation
- Always check exit codes ($LASTEXITCODE) after external commands
- Provide meaningful error messages with suggested remediation steps
- Include validation steps to verify successful completion
- Implement retry logic for network operations where appropriate

## Testing and Validation
- Include verification commands to validate each step's success
- Provide rollback or cleanup procedures for failed operations
- Test scripts in clean environments to ensure reproducibility
- Document expected outputs and success criteria

## Kubernetes-Specific Guidelines
- Follow Kubernetes security best practices for certificate generation
- Use appropriate certificate types and extensions for different components
- Implement proper RBAC configurations
- Validate cluster connectivity and component health

## Code Comments
- Use inline comments to explain complex logic or Azure-specific configurations
- Document any deviations from the original tutorial
- Explain PowerShell-specific implementations of bash commands
- Include references to official Kubernetes documentation where relevant

## Debugging and Troubleshooting
- Include verbose output options for debugging
- Provide commands to check service status and logs
- Document common failure scenarios and their solutions
- Include cleanup procedures for partial failures

## Repository Management

### Git Workflow and Synchronization
- Commit and push changes to the repository after every major script modification
- Use descriptive commit messages that reference the tutorial step (e.g., "Fix etcd service configuration in step 07")
- Sync the repository before starting work to ensure you have the latest changes
- Create feature branches for experimental changes or major refactoring
- Tag successful tutorial completions for reference (e.g., "v1.0-complete")

### Recommended Git Commands
```powershell
# Sync repository before starting work
git pull origin main

# Stage and commit changes after script updates
git add .
git commit -m "Update step XX: [description of changes]"
git push origin main

# Tag completed tutorial runs
git tag -a "tutorial-complete-$(Get-Date -Format 'yyyy-MM-dd')" -m "Successful tutorial completion"
git push origin --tags
```

### Change Documentation
- Update execution output files (*-execution-output.md) after script modifications
- Document any infrastructure changes or new Azure resources in README.md
- Keep EXECUTION-SUMMARY.md current with latest test results
- Update troubleshooting sections based on encountered issues
- **Maintain navigation consistency across all execution output files**
- **Test navigation links when modifying or restructuring tutorial steps**
- **Ensure README tutorial steps table remains synchronized with actual files**
