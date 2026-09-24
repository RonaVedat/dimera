# Dimera

A native SwiftUI personal finance tracker for iOS. Local-only, no backend — your data never leaves your device.

## Features

- **Home dashboard** — net worth trend, cash/savings/investments/debt breakdown, upcoming bills and income
- **Activity** — a searchable log of every transaction, with on-device receipt capture and OCR
- **Insights** — spending analysis, a tax radar that flags likely-deductible purchases, and **Commitments** (Subscriptions vs. Contracts, tracked separately)
- **Reports** — Monthly Summary, Spending Analysis, Commitment Report, and Goal Progress, each generated as a shareable PDF
- **Tax Export** — a consolidated PDF for your own records, or raw CSV/OFX for an accountant, with a fiscal-year-aware date range
- **Goals** — savings targets with 30-day balance forecasting
- **Premium** — a real subscription via StoreKit 2 (Apple handles payment and identity; this app never sees a name, email, or card number)
- Fully localized: English, German, French, Russian, Chinese (Simplified), Italian, Portuguese (Brazil), Spanish (Spain), Spanish (Latin America), Turkish, Indonesian

## Requirements

- macOS with **Xcode 15 or later** (developed on Xcode 26.6 / iOS 26.5 SDK)
- **iOS 17.0+** deployment target (simulator or device)
- [**XcodeGen**](https://github.com/yonaskolb/XcodeGen) — only needed if you change `project.yml` and want to regenerate the `.xcodeproj`:
  ```bash
  brew install xcodegen
  ```

## Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/RonaVedat/dimera.git
   cd dimera
   ```
2. Open `Dimera.xcodeproj` in Xcode (it's already checked in and ready to build — you don't need XcodeGen just to open the project).
3. Select the **Dimera** scheme and an iOS 17+ simulator (or a signed device), then **Run** (⌘R).

If you edit `project.yml` (targets, settings, dependencies), regenerate the project before building:
```bash
xcodegen generate
```

## Testing Premium purchases

Premium is backed by real StoreKit 2, with a local **StoreKit Configuration** file (`Dimera/Products.storekit`) already wired into the `Dimera` scheme — no App Store Connect account or network access needed to test it.

- Running the app via Xcode's **Run** button (⌘R) automatically uses the local StoreKit test environment: tapping "Start Premium" shows the native purchase sheet, and completing it unlocks Premium instantly.
- This **only works when launched through Xcode's scheme** (⌘R, or `xcodebuild test`) — launching a built app directly (e.g. `xcrun simctl launch`) bypasses the StoreKit Testing configuration, and purchases will fail with "Purchase failed" since no real product is reachable.
- To simulate transactions, refunds, or renewal states without buying anything, use Xcode's **Debug → StoreKit → Manage Transactions** while the app is running.
- For local UI testing without going through StoreKit at all, `Settings → Debug → Simulate Premium` (DEBUG builds only) flips the same flag directly.

## Project structure

```
Dimera/
├── App/            Entry point, root tab view
├── Design/         Colors, typography, currency/locale formatting, haptics
├── Models/         FinanceStore (the app's single state container) and its data types
│   └── Reports/    Fiscal-year logic, PDF rendering, tax data export
├── Views/          One folder per feature area (Home, Activity, Insights, Goals,
│                   Onboarding, Premium, Settings, Entry forms, shared Components)
└── Resources/      Assets and Localizable.xcstrings (the localization catalog)
```

The app has **no backend and no third-party dependencies** — everything is UserDefaults-backed local storage, Apple's own frameworks (StoreKit, Vision for receipt OCR, PDFKit-style rendering via `ImageRenderer`), and plain SwiftUI.

## Configuration notes

- Bundle identifier: `com.dimera.app`
- To run on a physical device, set your own Development Team in Xcode's Signing & Capabilities for the `Dimera` target (not required for the simulator)
- `#if DEBUG` gates a few developer-only conveniences in Settings (Simulate Premium, Restart Onboarding) — none of these appear in a Release build
