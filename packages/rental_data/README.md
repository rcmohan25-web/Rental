# rental_data

Models and repositories.

```
lib/models/                 one hand-written file per entity (FROZEN after Phase 0)
lib/repositories/           abstract interfaces, one file per actor
lib/repositories/supabase/  real implementations      (Srijan)
lib/repositories/fake/      in-memory fakes for UI work (feature owner)
```

Rules
- Models and `docs/api-contract.md` are written by **Smaran and Srijan** in Phase 0, then frozen.
  Changing them needs a PR approved by all three.
- Frontends code against the abstract interfaces with the **fake** implementation until the RPCs land.
- No `freezed`, no `build_runner`, no generated files in git. Use `equatable` and hand-written `fromJson` / `toJson`.
- One file per actor in `repositories/` so two people never edit the same file.
