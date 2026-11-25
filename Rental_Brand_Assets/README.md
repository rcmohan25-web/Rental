# Rental by Sapati - Brand & Image Assets

Generated for the *Rental by Sapati Final Implementation Plan* (21 Nov 2026).
Brand tokens come from plan Section 7: navy `#0F1B3D`, hot pink `#FF3D8B`, background `#F7F8FC`, surface `#FFFFFF`.
Android package: `com.sapati.rental`. Every asset is provided as **SVG (editable) + PNG** unless noted. All text is converted to outlines (Poppins), so the SVGs need no fonts.

## Where each folder goes in the monorepo (plan Section 9)

| Folder in this zip | Copy to | Notes |
|---|---|---|
| `01_logo/` | `apps/mobile/assets/branding/logo/` (+ `docs/` for the report) | Mark, horizontal/stacked lockups, wordmark, Admin lockup, mono versions |
| `02_app_icons/android/res/` | `apps/mobile/android/app/src/main/res/` (merge) | Ready-made launcher icons (legacy, round, adaptive, **themed/monochrome**), `ic_stat_rental` notification icon, adaptive XML, background colour. Set `android:label="Rental"` and `android:icon="@mipmap/ic_launcher"`, `android:roundIcon="@mipmap/ic_launcher_round"` in AndroidManifest |
| `02_app_icons/play_store/` | Play Console upload | 512x512 icon |
| `02_app_icons/source/` | `apps/mobile/assets/branding/app_icon/` | 1024 px masters if you prefer `flutter_launcher_icons` |
| `02_app_icons/ios_future/` | later | iOS is future work in the plan; 1024 icon only |
| `03_splash/` | `apps/mobile/assets/branding/splash/` | Use with `flutter_native_splash_config.yaml`. `*_preview.png` files are full-screen previews only |
| `04_landing_onboarding/` | `apps/mobile/assets/branding/onboarding/` | 3 onboarding slides, landing hero art (transparent), full-screen landing background, auth header banner. `landing_screen_mockup_PREVIEW_ONLY` is a design reference: build the real text and buttons with widgets |
| `05_admin_web/web/` | `apps/admin_web/web/` | favicon, PWA icons (incl. maskable), apple-touch icon, `manifest.json`, `index_head_snippet.html`, og image |
| `05_admin_web/` (loose files) | `apps/admin_web/assets/` | Admin login hero, sidebar logos |
| `06_illustrations/empty_states/` | `.../illustrations/empty_states/` | Empty, offline, error, suspended and admin "all clear" states |
| `06_illustrations/flows/` | `.../illustrations/flows/` | ID upload / pending / verified / rejected, handover ID photo, handover code, payment proof, request sent, completed, deposit refund, damage report, awaiting owner |
| `07_category_icons/` | `.../categories/` | 10 suggested category icons (plain + tile). **Categories are a suggestion; the plan does not fix a category list** |
| `08_placeholders_and_demo/` | `.../placeholders/` | Item/avatar/error placeholders. `demo_*` files are fake and clearly labelled (plan Section 2: never use real IDs or faces) |
| `09_marketing/` | repo root / `docs/` / store listing | Play feature graphic 1024x500, GitHub social preview, README banner, OG image, round profile logo |

## Design notes
- **Mark:** a geometric "R" whose leg is a pink hand-over stroke. Navy badge for light surfaces; white R on navy for dark ones.
- **Contrast (plan Section 7):** white text on pink is about 3.3:1, so pink buttons need bold labels at 16 sp or larger.
- **Adaptive icon:** foreground sits inside the 66 dp safe zone; background colour is `#0F1B3D`; a monochrome layer is included for Android 13 themed icons.
- Semantic colours used in the status illustrations: green `#1FA971` verified, amber `#F5A524` pending, red `#E5484D` rejected.

## Placeholders to replace
- **Taglines** ("Borrow what you need. Lend what you don't.") are suggestions, not from the plan.
- **Sapati company wordmark** (`*_PLACEHOLDER`) is a simple stand-in. Replace it with Sapati's official logo if one exists; the "by Sapati / from Sapati" lines on the Rental lockups use plain Poppins text.
- Demo item images are illustrations, not photos; use consented photos for the final demo and report.
- Sample figures shown in artwork (NPR 42,500 total payable; code 482917) are examples only. The 42,500 matches the approved worked example (rental fee NPR 10,500 + 20% deposit NPR 32,000).

## Fonts
Poppins (Bold / Medium / Regular, SIL OFL) was used for lettering. If the app UI uses `google_fonts`, Poppins is a matching choice.
