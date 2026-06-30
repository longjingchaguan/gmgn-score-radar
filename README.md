# GMGN Score Radar

GMGN Score Radar is a native macOS menu bar app for watching GMGN trending tokens.

It is a read-only screening radar:

- scans GMGN OpenAPI directly
- scores tokens with deterministic rules
- sends macOS notifications only for 70+ candidates
- explains alerts in short human language
- opens the token page on GMGN for manual inspection

It does not trade, sign transactions, manage wallets, or place orders.

> This is an unofficial companion tool for GMGN users. It is not affiliated with, endorsed by, or maintained by GMGN.

## Install

Download the latest `.dmg` from [GitHub Releases](https://github.com/longjingchaguan/gmgn-score-radar/releases/latest).

Open the DMG and drag `GMGN 选币评分.app` into `Applications`.

The current build is ad-hoc signed and not Apple-notarized. On first launch, macOS may require right-clicking the app and choosing **Open**.

## Use

1. Launch the app.
2. Open the menu bar icon.
3. Save your GMGN OpenAPI key in macOS Keychain.
4. Choose a chain.
5. Leave the app running in the menu bar.

By default, the app scans every 30 seconds and only notifies when a token reaches the 70+ score threshold.

When an alert appears, click it to open the token on GMGN.

## Scoring

The score is based on the original AI Trader screening logic:

- safety gates: honeypot, mint authority, taxes, rug ratio, bundler, dev holding, top 10 concentration
- consensus gate: smart money + renowned KOL count
- weighted score: 5m momentum, 1h trend, buy pressure, turnover, consensus, and safety
- verdict gate: rejects fading trends and seller-dominated moves

The macOS app adds one stricter product rule: only 70+ candidates are shown and notified.

## Privacy

- API keys are stored in macOS Keychain.
- The app calls `https://openapi.gmgn.ai` directly.
- The app does not run Python, FastAPI, a browser server, or `gmgn-cli`.
- Local settings and logs are stored under the user's Application Support directory.

## Build From Source

Requires macOS 14+ and Swift Package Manager.

```bash
swift run
```

## Build App

```bash
./scripts/build-app.sh
open "dist/GMGN 选币评分.app"
```

## Build DMG

```bash
./scripts/build-dmg.sh
```

Output:

```text
dist/GMGN 选币评分.dmg
```

## Disclaimer

This software is for information and research only. It is not financial advice. Memecoin trading is highly risky. Always do your own research before taking any action.
