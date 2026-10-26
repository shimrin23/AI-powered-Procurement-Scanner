# AI-Powered Procurement Scanner

> Intelligent Multimodal Procurement Document & Bill Scanner supporting **Sinhala**, **Tamil**, and **English** handwriting with deterministic financial verification.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android-green?logo=android)
![Gemini](https://img.shields.io/badge/AI-Google%20Gemini%20Vision-orange?logo=google)
![Languages](https://img.shields.io/badge/Languages-Sinhala%20%7C%20Tamil%20%7C%20English-purple)

---

## Key Features

| Feature | Details |
|---|---|
| 📄 **Multi-Page Scanning** | Upload and process multiple consecutive pages (Page 1, Page 2, etc.) for long invoices and bills |
| 🤖 **Multimodal Vision AI** | Powered by Google Gemini Flash (`gemini-3.5-flash-lite` / `gemini-3.8-flash`) for accurate transcription |
| 🌐 **Multilingual Handwriting** | Full OCR support for Sinhala (සිංහල), Tamil (தமிழ்), and English handwritten & printed text |
| ✂️ **Sequential Crop UI** | Interactive cropping tool with presets (Original, 4:3, 16:9) and page indicators |
| 🔢 **Deterministic Verification** | Math verification powered by high-precision decimal arithmetic (quantity × unit price = amount) |
| 📑 **Clean PDF Reports** | Professional verification reports with Noto Sans Unicode font support and clean `OK`/`Wrong` status |
| 🔒 **Secure Configuration** | Zero hardcoded secrets; API keys injected securely via compile-time `--dart-define` flags |

---

## Scanning Workflow

```
[Camera / Multi-Page Gallery] 
            ↓
[Sequential Crop & Review] 
            ↓
[Swipeable Multi-Page Verification Preview] 
            ↓
[Gemini Multimodal Transcription & Calculation Engine] 
            ↓
[Results Screen: Edit Items, Verification Status, Save/Share PDF]
```

---

## Project Structure

```
procurement_scanner/
├── lib/
│   ├── main.dart               # App entry point
│   ├── app.dart                # MaterialApp setup & routes
│   ├── theme.dart              # Dark theme design system & font fallbacks
│   ├── config/
│   │   └── api_config.dart     # Secure Gemini API configuration
│   ├── models/
│   │   ├── document_scan.dart  # Multi-page scan session model
│   │   ├── line_item.dart      # Extracted line-item data model
│   │   └── verification_result.dart # Math verification result model
│   ├── screens/
│   │   ├── home_screen.dart    # Home dashboard & batch gallery picker
│   │   ├── scan_screen.dart    # Camera scanning & gallery capture
│   │   ├── verify_screen.dart  # Multi-page carousel preview & AI trigger
│   │   └── results_screen.dart # Calculation audit, editor & PDF actions
│   ├── services/
│   │   ├── gemini_service.dart # Multi-image Gemini Vision AI service
│   │   ├── calculator_service.dart # High-precision decimal math engine
│   │   └── pdf_service.dart    # Unicode-ready PDF report generator
│   └── widgets/
│       ├── extracted_field_tile.dart # Interactive line-item editor card
│       └── status_badge.dart         # Overall verification status badge
└── android/
    └── app/
        ├── build.gradle.kts         # Android configuration
        └── src/main/AndroidManifest.xml # Permissions (Camera, Internet, Storage)
```

---

## Setup and Running

### Prerequisites

- [Flutter SDK 3.x](https://docs.flutter.dev/get-started/install)
- Android Studio or VS Code with Flutter extension
- An Android device or emulator (API 21+)
- A [Google Gemini API Key](https://aistudio.google.com/app/apikey)

### 1. Clone the repository

```bash
git clone https://github.com/shimrin23/AI-powered-Procurement-Scanner.git
cd AI-powered-Procurement-Scanner/procurement_scanner
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the App

Pass your Gemini API key securely at build/run time using `--dart-define`:

```bash
flutter run --dart-define=GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
```

### 4. Build a Release APK

To create an optimized release APK for your phone:

```bash
flutter build apk --release --split-per-abi --dart-define=GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
```

The generated APKs will be located at:
```
build/app/outputs/flutter-apk/
```

---

## Verification Logic

For every extracted row:
```
expected_amount = quantity × unit_price
difference      = |written_amount - expected_amount|
status          = difference <= 0.01 ? "OK" : "Wrong"
```

Document Totals:
```
computed_grand_total = sum(expected_amount)
total_difference     = |written_grand_total - computed_grand_total|
```

Overall Status:
- **Calculations Match:** All line items and grand totals match accurately.
- **Discrepancy Detected:** One or more written amounts differ from calculated amounts.
- **Manual Review Required:** Unclear handwriting or missing values flagged for human check.

---

## PDF Verification Report

The generated PDF includes:
1. **Header:** Document title, generation timestamp, and metadata.
2. **Status Banner:** Clear overall audit outcome (`Status: OK` or `Status: Wrong`).
3. **Line Items Table:** Complete extracted table with quantity, unit price, written amount, calculated amount, difference, and status. Full rendering support for Sinhala and Tamil characters via Google Noto Sans fonts.
4. **Totals Audit:** Computed total vs. written total with exact variance highlighted.
5. **Warnings Section:** Flagged unreadable words or ambiguous handwriting notes.

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `camera` | ^0.10.5 | Device camera capture & preview |
| `image_cropper` | ^12.2.1 | Native document cropping UI with aspect ratios |
| `image_picker` | ^1.1.2 | Multi-image gallery selection |
| `decimal` | ^2.3.3 | Exact decimal arithmetic (avoiding floating-point errors) |
| `pdf` | ^3.11.1 | Structured PDF document builder |
| `printing` | ^5.13.1 | Native Android PDF print, save & share dialogs |
| `path_provider` | ^2.1.4 | Access to local filesystem storage |
| `permission_handler` | ^11.3.1 | Runtime camera and storage permissions |
| `flutter_animate` | ^4.5.0 | Smooth micro-animations and loading transitions |
| `gap` | ^3.0.1 | Layout spacing utility |

---

## License

This project is licensed under the MIT License.
