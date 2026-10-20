# Procurement Scanner

> Offline AI-powered handwritten procurement document scanner for **Sinhala**, **Tamil**, and **English**.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android-green?logo=android)
![Offline](https://img.shields.io/badge/Mode-100%25%20Offline-brightgreen)

---

## Features

| Feature | Details |
|---------|---------|
| 📷 Document scanning | Camera capture with document guide overlay |
| ✂️ Adjustable crop | Native crop UI with aspect-ratio presets |
| 🤖 On-device OCR | Google ML Kit Latin recognizer; no cloud API |
| 🌐 Languages | English/numbers ✓ · Tamil ⚠️ · Sinhala ⚠️ (manual review required) |
| 🔢 Verification | Deterministic decimal arithmetic — never AI arithmetic |
| 📄 PDF reports | Full report with images, tables, discrepancies, saved locally |
| 🔒 Privacy | No login, no cloud, no backend, no internet required |

---

## Screens

```
Home  →  Scan & Crop  →  Verify  →  Results
```

---

## OCR Language Support

| Language | Script | Support Level |
|----------|--------|--------------|
| English | Latin | Full support |
| Tamil | Tamil | Current build does not run a Tamil recognizer; fields are flagged for manual review |
| Sinhala | Sinhala | Current ML Kit integration does not support Sinhala; fields are flagged for manual review |

> The app **never claims successful verification** for fields that could not be reliably recognised.
> Low-confidence fields are always highlighted and require manual human review.

### Offline model evaluation

The current implementation uses Google ML Kit's on-device Latin text
recognizer. It performs inference locally and does not send document images to
a backend, but it is not a bundled multilingual handwriting model. Sinhala and
handwritten Tamil therefore remain explicit limitations rather than being
silently treated as supported. A future multilingual model must be evaluated
for Tamil/Sinhala handwriting accuracy, Android ABI/runtime compatibility,
package size and memory use, offline model licensing, and reproducible in-app
bundling before it replaces this conservative fallback.

---

## Project Structure

```
procurement_scanner/
├── lib/
│   ├── main.dart               # Entry point
│   ├── app.dart                # Root widget + routing
│   ├── theme.dart              # Design system (colours, typography)
│   ├── screens/
│   │   ├── home_screen.dart    # Screen 1: Home + CTA
│   │   ├── scan_screen.dart    # Screen 2: Camera + crop
│   │   ├── verify_screen.dart  # Screen 3: OCR trigger
│   │   └── results_screen.dart # Screen 4: Results + PDF
│   ├── widgets/
│   │   ├── status_badge.dart         # Verification status banner
│   │   └── extracted_field_tile.dart # Per-item result card
│   ├── services/
│   │   ├── ocr_service.dart          # ML Kit OCR wrapper
│   │   ├── calculator_service.dart   # Deterministic verification
│   │   └── pdf_service.dart          # PDF generation
│   └── models/
│       ├── document_scan.dart        # Session data model
│       ├── line_item.dart            # Extracted row model
│       └── verification_result.dart  # Verification output model
└── android/
    └── app/
        ├── build.gradle.kts         # minSdk=21, multiDex
        └── src/main/AndroidManifest.xml  # Permissions
```

---

## Setup and Running

### Prerequisites

- Flutter SDK 3.x or newer (https://docs.flutter.dev/get-started/install)
- Android Studio or VS Code with Flutter extension
- Android device or emulator (API 21+)

### 1. Install dependencies

```bash
cd procurement_scanner
flutter pub get
```

### 2. Run in debug mode

Connect an Android device (enable USB debugging) or start an emulator, then:

```bash
flutter run
```

### 3. Build a release APK

```bash
# Debug APK (no signing required, works on your own device):
flutter build apk --debug

# Release APK (recommended for phone installation):
flutter build apk --release --split-per-abi
```

APKs are output to:
```
build/app/outputs/flutter-apk/
```

### 4. Install on a phone

```bash
# Install via ADB (phone must be connected via USB)
adb install build/app/outputs/flutter-apk/app-release.apk

# Or copy the APK to your phone and open it (enable "Install unknown apps" in settings)
```

---

## Verification Logic

```
For each line item:
  expected_amount = qty x unit_price          (decimal arithmetic)
  difference      = |written_amount - expected_amount|
  matches         = difference <= 0.01

grand_total_computed = sum of expected_amounts

Overall status:
  Any field low-confidence?  -->  Manual Review Required
  Any amount mismatch?       -->  Discrepancy Detected
  All match, high-confidence -->  Calculations Match
```

---

## PDF Report Contents

1. Cover with scan timestamp and overall status
2. Original document image + cropped image (side-by-side)
3. Line item table: Description, Qty, Unit Price, Written Amount, Calculated Amount, Difference, Status
4. Totals section (computed vs. written)
5. Warnings (language limitations, low-confidence fields)
6. Raw OCR output text
7. Disclaimer footer

PDFs are saved to the device's external storage (or app documents directory as fallback).

---

## Known Limitations

- **Sinhala**: Google ML Kit does not natively support the Sinhala script. Sinhala text will not be reliably extracted. The app will flag all values as requiring manual review.
- **Tamil handwriting**: ML Kit has some Tamil support but handwritten Tamil recognition accuracy is limited. Results should always be verified manually.
- **Poor image quality**: Very blurry, low-contrast, or skewed images may yield no extracted text.
- **Table layout detection**: The heuristic parser works best with clearly-spaced tabular procurement forms.

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| camera | 0.10.5+ | Camera preview and capture |
| image_cropper | 8.1.0+ | Native crop UI |
| image_picker | 1.1.2+ | Gallery fallback |
| google_mlkit_text_recognition | 0.13.0+ | On-device OCR |
| decimal | 2.3.3+ | Precise decimal arithmetic |
| pdf | 3.11.1+ | PDF generation |
| printing | 5.13.1+ | PDF save and share |
| path_provider | 2.1.4+ | Device file paths |
| permission_handler | 11.3.1+ | Runtime permissions |
| flutter_animate | 4.5.0+ | Micro-animations |
| gap | 3.0.1+ | Spacing utility |

---

## License

MIT
