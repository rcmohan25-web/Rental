# rental_core

Shared UI and helpers used by **both** apps. Dependencies on Supabase are NOT allowed here.

| Folder | Owner | Contents |
| --- | --- | --- |
| `lib/theme/` | Mohan | Brand colours and the one Material 3 theme |
| `lib/widgets/` | Mohan | Buttons, fields, status chip, item card, empty/error/loading, admin table |
| `lib/widgets/terms_checkbox.dart` | Smaran | Reusable "I have read and accept" checkbox (stub) |
| `lib/money/money.dart` | Smaran | fee, deposit, commission, late fee, days (stub). Must mirror SQL |
| `lib/formatters/`, `lib/constants/`, `lib/errors/` | Mohan | NPR and date formatting, app constants, honesty-rule texts, AppException |

Import everything with `import 'package:rental_core/rental_core.dart';`.

## Brand rules (see `docs/branding.md`)
- Primary navy `#0F1B3D`, buttons hot pink `#FF3D8B` with **white bold labels, 16 sp or larger**.
- Never put small text on pink (white on pink is only about 3.3:1).
- Status chips are always colour **plus** text plus icon.
