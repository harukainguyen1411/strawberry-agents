# Parallel QA as Duong-directed exception to serial overnight discipline

## Date

2026-04-22

## Context

The eighth-leg directive was explicit: serial dispatch only for overnight sessions (one subagent at a time, usage ceiling is the risk). In the ninth leg, after the main impl wave completed and Viktor hotfix was dispatched, Duong requested parallel QA across multiple aspects simultaneously, dispatching Akali-A for session lifecycle while Viktor hotfix was still in flight. This is a deliberate exception to serial discipline, issued by Duong directly.

## Lesson

Serial dispatch is the overnight default, not an absolute rule. The constraint is usage ceiling risk during unsupervised periods. When Duong is intermittently online and explicitly directs parallel dispatch (especially for read-heavy/QA operations that don't amplify usage the same way as impl waves), parallel is the right call. The distinction:

- **Impl waves:** serial by default — each wave can generate large outputs, nested agent spawns, and usage spikes. One at a time.
- **QA/review:** lighter usage profile; parallelizing multiple Akali or reviewer dispatches is acceptable when Duong directs it.
- **Hotfix + QA concurrently:** hotfix is critical-path; QA on other aspects can run in parallel without blocking the hotfix result.

Always record when the serial default is suspended and by whose direction. Re-apply serial discipline after the parallel window closes.
