# Workflow Router

Document ID: `WF-ROUTER`  
Status: `Active`  
Maintenance count: `0/5`  
Last updated: `{{DATE}}`

## Maintenance rules

Update this Router when workflow authorities or task routes change. Count only
successful tasks that materially affect the business; follow the
[Workflow Guide](Workflow_Guide.md#maintenance-rules) for the maintenance cycle and exclusions.

## Task routing

| Task | Read |
|---|---|
| Workflow configuration method, category design, model entry integration | `..\Workflow_Configuration_Guide.md` |
| Routing, category proliferation, depth, maintenance | `Workflow_Guide.md` |
| Leases, conflicts, waiting, override, heartbeat | `Concurrency_Guide.md` |
| New business roots | `Templates\BusinessRouter.template.md` |
| Lease operations | `Scripts\WorkingAgent.ps1` |
| Lease regression | `Scripts\Test-WorkingAgent.ps1` |

Ask the user before changing root categories or workspace-wide rules.
