# payment_qr

Static QR codes for the manual payment screen. **Owner: Mohan** (the company supplies the images).
All payments go to the Sapati company account (eSewa, Khalti or bank), so the QR codes are the same for every order.

Put the three images here with exactly these names (they are referenced by `PaymentChannel` in `rental_core`):

| File | Channel |
| --- | --- |
| `esewa.png` | eSewa |
| `khalti.png` | Khalti |
| `bank.png` | Bank transfer QR |

Rules
- Use `Image.asset(channel.qrAsset, errorBuilder: ...)` so the screen still works while an image is missing.
- Show `HonestyTexts.manualPayment` and `HonestyTexts.paymentQrInstruction` on the same screen.
- Keep real QR images out of public repositories and out of the report screenshots. If the repo is public, keep them local or blur them.
- Register the folder in `apps/mobile/pubspec.yaml` under `flutter: assets:` (Flutter does not include sub-folders automatically):
  ```yaml
  assets:
    - assets/
    - assets/payment_qr/
  ```
