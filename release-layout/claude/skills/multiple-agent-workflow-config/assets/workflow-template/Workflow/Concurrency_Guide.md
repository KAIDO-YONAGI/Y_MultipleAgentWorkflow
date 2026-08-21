# WorkingAgent Concurrency Guide

## Lease timing

Light read-only discovery may occur first. Acquire a lease before detailed analysis,
subagents, mutation, or state-changing tools.

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
