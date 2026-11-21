# env/

Copy `dev.example.json` to `dev.json` (and `demo.example.json` to `demo.json`) and fill in the values.
`env/*.json` is git-ignored, only the `*.example.json` files are committed.

Run an app with:

```bash
flutter run --dart-define-from-file=../../env/dev.json
```

Only the **anon** key is ever used in the apps. The service-role key lives in Edge Function secrets
and Mohan's password manager (never in this repo).
