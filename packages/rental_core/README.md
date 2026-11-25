# rental_core

Shared UI and helpers used by **both** apps. Dependencies on Supabase are NOT allowed here.

| Folder | Owner | Contents |
| --- | --- | --- |
| `lib/theme/` | Mohan | Brand colours and the one Material 3 theme |
| `lib/widgets/` | Mohan | Buttons, fields, status chip, item card, empty/error/loading, admin table |
| `lib/widgets/terms_checkbox.dart` | Smaran | Reusable "I have read and accept" checkbox (stub) |
| `lib/money/money.dart` | Smaran | fee, deposit, commission, late fee, days (stub). Must mirror SQL |
| `lib/formatters/`, `lib/errors/` | Mohan | NPR and date formatting, AppException |
| `lib/constants/` | Mohan | `AppConstants`, `HonestyTexts`, `SettingKeys` (app_settings keys), `PaymentChannel` (eSewa, Khalti, bank, static QR asset paths) |

Import everything with `import 'package:rental_core/rental_core.dart';`.

## Brand rules (see `docs/branding.md`)
- Primary navy `#0F1B3D`, buttons hot pink `#FF3D8B` with **white bold labels, 16 sp or larger**.
- Never put small text on pink (white on pink is only about 3.3:1).
- Status chips are always colour **plus** text plus icon.

## Business rules that touch this package
See `docs/business-rules.md`. The deposit is `max(declared value x deposit_rate, min_deposit_amount)`, both set by an admin.
That formula lives in `money.dart` (Smaran) and in SQL (Srijan), never in screens.
