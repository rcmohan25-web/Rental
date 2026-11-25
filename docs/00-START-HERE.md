# Start here (Phase 0)

Phase 0 is finished when the **repository, the contract and the first migration are merged**, CI is green and every folder exists.
Rules decided with the supervisor are in `docs/business-rules.md`. Read it before you code.

## Status
| Item | State |
| --- | --- |
| Skeleton, CI, theme and shared widgets (Mohan) | Done (Builds 0.1 and 0.2) |
| Repository settings, protection, labels, issues (Mohan) | Follow `docs/setup/github-setup-mohan.md` |
| Money library and fixtures (Smaran) | Open |
| Models and API contract (Smaran + Srijan) | Open |
| Supabase projects and first migration (Srijan) | Open |

## Order of work
| Step | Who | What | Instruction file |
| --- | --- | --- | --- |
| 1 | Mohan | Protect `main`, run `scripts/setup_github.mjs`, invite the team | `docs/setup/github-setup-mohan.md` |
| 2 | Smaran, Srijan | Install tools, clone repo, run the apps | `docs/setup/machine-setup.md` |
| 3 | Srijan | Two Supabase projects, `supabase init`, first migration | `docs/setup/supabase-setup-srijan.md` |
| 4 | Smaran + Srijan | Write `docs/api-contract.md` and shared models, then freeze | `docs/api-contract.md` |
| 5 | Smaran | `money.dart`, `money_cases.json` and unit tests (with the minimum deposit rule) | `docs/business-rules.md` |
| 6 | All | Agree the status machine and settings keys | `docs/state-machine.md` |

## Daily habits
10-minute check-in, rebase on `main` daily, PR reviews within 24 hours, evidence into `docs/evidence/`.
See `CONTRIBUTING.md`. Your tasks are also GitHub issues (label `phase-0`).
