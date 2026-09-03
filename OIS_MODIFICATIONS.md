# OIS Wallet modifications

This fork keeps the original local/offline encryption foundation and changes the card experience for personal card inventory.

## Added

- `Photo` card appearance: the encrypted front image becomes the full card visual with no generated overlay.
- `Template` appearance: a custom image is used as the background while card details remain overlaid.
- `Simple` appearance: keeps the original generated gradient card style.
- Camera or gallery image selection.
- Manual move/zoom crop locked to the standard ID-1 card ratio (85.60 × 53.98 mm / 1.586).
- Front and back card images remain encrypted at rest.
- Custom category fields and category filters on payment and identity tabs.
- Card label/category captions below photographed cards in the home list.
- Photo cards open the encrypted image fullscreen from the detail screen.
- Existing cards with a stored front image automatically fall back to `Photo` mode when no display mode existed before the database migration.
- Android branding changed to `OIS Wallet` with application id `com.oisgrafika.wallet`.
- Personal release builds can fall back to Android debug signing when no private release keystore exists.
- GitHub Actions workflow `.github/workflows/build-personal-apk.yml` builds an installable APK without requiring a local Flutter setup.

## Database migration

- Wallet database: version 7 -> 8 (`displayMode`).
- Identity database: version 3 -> 4 (`category`, `displayMode`).

No INTERNET permission was added. The existing encrypted image storage and biometric/security foundation are retained.

## 1.2.0 - NFC bank-card quick add

- Added Android NFC permission with NFC hardware marked optional.
- Added read-only EMV NFC scanning to the bank-card form.
- NFC can fill the PAN/card number and expiry when the issuing card exposes them.
- After scanning, users can keep only the last four digits (default action) or intentionally use the full PAN.
- The scanner intentionally ignores PIN, CVV/CVC, cryptographic keys, transaction history, counters, and other EMV diagnostic fields.
- Card network is detected from the scanned PAN.
- NFC is used locally; no INTERNET permission was added.


## OIS Wallet 1.3.0 — Indonesia Wallet + Document Vault

- Custom per-card logos stored locally/encrypted; add GPN or any logo without rebuilding the APK.
- Added manual card networks: GPN, JCB, UnionPay, Other. Network filters are generated dynamically.
- Added E-Wallet section for GoPay, OVO, DANA, ShopeePay, LinkAja, Akulaku, Kredivo, and custom providers.
- E-Wallet fields: phone/account, manual balance, optional paylater/credit limit, account name, notes, custom logo.
- Added Identity PNG export to Android gallery (`Pictures/OIS Wallet`) and direct PNG share.
- Added encrypted Document Vault for PNG/JPG/WEBP, PDF and DOCX.
- A4 portrait/landscape document presentation.
- Offline PDF first-page preview using Android PdfRenderer.
- Offline DOCX text preview by reading `word/document.xml`; original DOCX remains intact.
- Documents can be exported back as their original file format.
- Backup format v5 now includes card logos, e-wallets, e-wallet logos and encrypted documents.


## v1.3.1 build fix
- Fixed invalid Flutter color constant `Colors.white45` in Document Vault.
- Replaced it with `Colors.white.withValues(alpha: 0.45)`.

## OIS Finance 2.0.0 — Finance Super App

- Added encrypted finance ledger with accounts for bank, e-wallet, cash, brankas, laci/kas, receh, debit, credit card, PayLater, loans and custom accounts.
- Added income, expense and account-to-account transfer flows. Transfers are excluded from income/expense totals.
- Added personal debt/receivable records with contacts, WhatsApp shortcut, proof images, partial payments and payment history.
- Added credit card / PayLater / loan center with limits, balances, statement dates, due dates and installment schedules.
- Added Indonesian cash denomination counter and balance reconciliation.
- Added monthly budgets, savings/sinking-fund goals and recurring transactions.
- Added finance calendar, global search, tags, monthly category analytics and net-worth snapshots.
- Added CSV/TXT/XLSX statement importer.
- Added offline screenshot OCR using Android ML Kit and Share-to-OIS Finance intake.
- Added optional Android notification-listener parser that creates reviewable transaction drafts instead of silently posting transactions.
- Added Android home-screen widgets for balance/net worth, quick expense/income/transfer entry and nearest due date, including privacy mode.
- Added Finance data and encrypted finance attachments to the encrypted backup/restore flow.
- Main navigation is now Home / Finance / Wallet / Vault / More.

### Final static sweep

- Fixed invalid Map iteration in Finance transaction/debt filter chips (`Map.entries`).
- Fixed nullable `ByteArray?` write in Android file export.
- Removed duplicate/obsolete Android plugin registration and unnecessary AndroidX notification-manager dependency.
- Aligned Android compile SDK with the Flutter SDK and set minSdk 23 for the bundled on-device OCR dependency.
- Removed fragile internal AGP APK-output mutation code.
- Added an explicit manifest merger rule to remove INTERNET permission even if a dependency requests it.
- Validated local Dart imports, XML resources/IDs, YAML files, asset paths, delimiter/string/bracket balance, and invalid Flutter color constants.
- Personal GitHub Action now runs `flutter analyze --no-fatal-warnings --no-fatal-infos` before the APK build.
