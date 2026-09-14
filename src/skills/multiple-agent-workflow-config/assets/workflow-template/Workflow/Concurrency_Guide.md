# WorkingAgent Concurrency Guide

## Lease timing

Light read-only discovery may occur first. Acquire a lease before detailed analysis,
subagents, mutation, or state-changing tools.

## Native Codex coordination

Codex may expose native task-to-task communication. Use it as an optional adapter
around the lease protocol:

- The registry, actual files, and reproducible runtime results remain authoritative.
  Messages coordinate work; they do not grant scope or override a conflict.
- After `Status`, notify the owning task when an active or waiting lease overlaps
  the intended write range. State the overlap, access mode, and requested action.
- Do not send conflict notices for independent paths or `read + read` work.
- If the owner confirms completion, wait for `Release` and run `Status` again before
  editing. If it is still active, keep the scope or ask the user before overriding.
- A suspected-stale lease is never silently taken over. Report it or follow the
  explicit stale-removal rule.
- Release the lease before sending a completion notice to a task that was waiting.
  Include only verified facts, changed scope, and test/build status; mark diagnoses
  as hypotheses.
- If native communication is unavailable, use the same lease checks and report
  unresolved conflicts to the user.

## Conflict rules

- `read + read` may run concurrently.
- Overlapping paths conflict when either side writes; parent and child paths overlap.
- `exclusive` conflicts with every access to the same resource.
- Unscoped writes in the same category conflict.
- Expand scope with `UpdateScope` before modifying the new range.
- `pipeline:BuildPublishRun` is a global barrier against active writers.
- Ordinary override does not approve the build barrier.

## Heartbeat and stale markers

Refresh every five minutes, around long operations, and before scope expansion.
Fifteen minutes without heartbeat means suspected stale only. Never delete or take
over automatically.

## Completion

Release in a finally path on success, failure, or cancellation. Waiting leases become
active atomically after blockers disappear.
