# GMGN 选币评分 Product Audit

Date: 2026-06-30

## Product Position

This should be a quiet macOS menu bar radar, not a trading terminal.

The job is simple:

- Scan GMGN trending tokens in the background.
- Apply deterministic safety, momentum, buy-pressure, turnover, consensus, and chip-distribution rules.
- Notify only when a token clears the 70+ threshold.
- Explain why the token is worth attention in human language.
- Open GMGN when the user wants to inspect or act.

## Current Health

Overall: strong self-use foundation, not yet a fully polished product.

The core direction is correct because the app now has a narrow promise:

- no direct trading
- no positions
- no heavy dashboard
- no Python runtime
- no web panel
- menu bar first
- notification first

## What Works

1. The app has a clear loop.

   It scans every 30 seconds, filters, scores, and only interrupts on 70+ candidates.

2. The rule engine is understandable.

   The score still maps back to the original Web/backend logic: 5m momentum, 1h trend, buy pressure, turnover, smart/KOL consensus, and safety.

3. The notification now gives a usable first read.

   "Short-term volume, buyers over sellers, smart money present" is faster to parse than raw score arithmetic.

4. The settings page is no longer a control room.

   It exposes account, radar, and notification threshold. That matches a resident utility.

5. The app now has a real icon.

   This matters. A menu bar resident app without a Finder/system icon feels unfinished.

## Problems

1. There is still too much inherited trading language in the code model.

   `Position`, `RiskManager`, `sizeSol`, and risk terms remain in the domain layer even though the product no longer trades. This is product debt because future UI or logs can accidentally leak trading concepts back into the app.

2. The menu bar symbol is still weak.

   `◎` is a placeholder. It should become a proper status item image, ideally derived from the app icon or a monochrome radar glyph, with states for idle, scanning, and candidates found.

3. The product does not yet show a "why this, why now" hierarchy strongly enough.

   Notifications improved, but the menu bar list should visually separate:

   - main read
   - signal tags
   - raw numbers

   Right now these exist, but the visual hierarchy is still basic.

4. No local rule audit trail is surfaced.

   If a token is pushed, the app should remember the exact score breakdown for that push. Logs exist, but they are not productized as "recent alerts".

5. Settings lacks notification permission state.

   If macOS notification permission is denied, the app currently cannot explain that clearly inside settings.

6. The app has no first-run confidence moment.

   After saving the API key, the user should immediately understand:

   - scanning has started
   - current chain
   - next scan time
   - notification threshold

## Next Product Cuts

1. Remove unused trading/position/risk domain code from the native app.

2. Replace the text menu bar item with a proper template icon and numeric badge.

3. Add a "Recent Alerts" section in the menu bar:

   - token
   - human reason
   - score
   - alert time
   - click to GMGN

4. Add notification permission status to settings.

5. Add a small rule explanation view:

   - what makes score 70+
   - what blocks a token
   - why the app may stay silent for a long time

## Verdict

The product is now directionally right.

It should not grow a dashboard again. The next improvement is not more screens; it is sharper trust:

- better menu bar status
- clearer alert memory
- clean domain model
- permission health
- no trading residue
