# Project Validation Guide

Document ID: `WF-PROJECT-VALIDATION`  
Status: `PendingConfiguration`  
Last updated: `{{DATE}}`

## Scope

This optional document records only validation commands and state-changing checks
confirmed for this project. It is not a generic workflow requirement.

Before activating this guide, inspect the project and obtain user confirmation for:

- which changes trigger validation;
- build, test, publish, run, or deployment commands and their order;
- processes or services that may be stopped or restarted;
- required concurrency resources and barrier names;
- success criteria, timeouts, and project-specific environment handling.

Do not infer commands from another project or from the workflow template.
