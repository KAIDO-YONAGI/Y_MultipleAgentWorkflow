# WorkingAgent Registry

This directory stores temporary JSON lease markers named `<AgentName>_<Hash>.txt`.
Only this README and `.gitignore` are versioned. Agents must use
`..\Workflow\Scripts\WorkingAgent.ps1` for registry operations.

Markers older than 15 minutes without a heartbeat are only suspected stale. They are
never deleted or taken over automatically.

In Codex, native task messages may point agents at an overlapping lease or announce
that a range is free. Messages do not replace this registry: verify the lease and
the actual workspace before editing, and release the lease before announcing
completion.
