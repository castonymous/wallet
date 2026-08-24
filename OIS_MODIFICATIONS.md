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
