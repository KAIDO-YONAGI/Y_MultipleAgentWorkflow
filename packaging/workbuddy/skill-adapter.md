## WorkBuddy execution environment

This Skill's executable workflows target Windows. The scripts are PowerShell, not
Bash. Windows PowerShell 5.1 is included with Windows; PowerShell 7 is optional.
From WorkBuddy's Bash tool, invoke a script through `powershell.exe` on the same
Windows host:

```bash
powershell.exe -NoLogo -NoProfile -File "<skill-root>/scripts/Initialize-Workflow.ps1" -ProjectRoot "<project-root>" -Categories Workflow,GUI -ProjectValidationMode None -WhatIf
```

Do not pass PowerShell code directly to Bash or translate a state-changing command
to another shell. If the Bash execution environment cannot access the Windows
workspace or launch `powershell.exe`, ask the user to run the command locally.

Load the method and maintenance references when needed:

@references/configuration-method.md
@references/doc-maintenance.md
@references/distribution.md
