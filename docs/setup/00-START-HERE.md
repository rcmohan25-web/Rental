# Start here (Phase 0)

Phase 0 is finished when the **repository, the contract and the first migration are merged**, CI is green and every folder exists.

## Order of work

| Step | Who | What | Instruction file |
| --- | --- | --- | --- |
| 1 | Mohan | Push this skeleton to the `rental` repo, run bootstrap, fix CODEOWNERS usernames, protect `main` | `docs/setup/github-setup-mohan.md` |
| 2 | Smaran, Srijan | Install tools, clone repo (in parallel with step 1) | `docs/setup/machine-setup.md` |
| 3 | Srijan | Two Supabase projects, `supabase init`, first migration | `docs/setup/supabase-setup-srijan.md` |
| 4 | Smaran + Srijan | Write `docs/api-contract.md` and shared models, then freeze | `docs/api-contract.md` |
| 5 | Smaran | `money.dart`, `money_cases.json` and unit tests | `packages/rental_core/README.md` |
| 6 | All | Agree the status machine and settings keys | `docs/state-machine.md` |

## Mohan's done-when
`main` runs on an emulator with placeholder screens and CI is green.

## Smaran's done-when
Money tests pass and the contract is merged.

## Srijan's done-when
The migration runs locally, sign-up creates a profile row and the contract is merged.

## Daily habits
10-minute check-in, rebase on `main` daily, PR reviews within 24 hours, evidence into `docs/evidence/`.
See `CONTRIBUTING.md`.
