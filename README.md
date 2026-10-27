# The Future

**See what your money becomes.** The Future reads your Bitpanda portfolio, your ETFs and your crypto, and shows what they grow into if you keep investing the way you do now. Slide the monthly amount and watch the years move. Free, no account, installable as an app.

- **App:** https://nikity.is-a.dev/the-future/app/
- **Landing page:** https://nikity.is-a.dev/the-future/

## What it does

- **Portfolio.** Total value, what you put in and what it returned, and how the value moved over a day, week, month, six months, a year or all time (Bitpanda's own history; the change leaves out money you added). Split into funds and stocks, crypto and metals, with a filter that is remembered. Tap a holding for its price over a day up to five years (straight from Bitpanda's public charts), your average buy price and every transaction in it. An eye hides every amount.
- **Future.** A growth curve with a cautious, an expected and a hopeful case, a ruler for what you add each month, one-time additions ("€2,000 in March") and a yearly raise. The result shows what your account will say and what that is worth in today's money, and when you pass round amounts like €100k.
- **Goal.** Set an amount and a year: the app says whether your plan gets there, and what monthly amount it takes if not.
- **Export.** One Markdown file with every holding, every transaction and your plan, enough for a spreadsheet or an AI to analyse.
- **Starting point from your trades.** The monthly amount starts at your average net buying over the last six months. Change it and everything moves.
- **Lock.** A six digit PIN, or Face ID, Touch ID or a fingerprint. The app locks itself when you have been away for as long as you choose: always, 2 minutes, 15 minutes or an hour.
- Pull to refresh, bouncing scroll, sheets that push the page back, haptics on iPhone and Android, offline after the first visit.

## How it stays private

Bitpanda's API does not allow calls from a browser, and a key in a browser is a key at risk. So the app never sees the key.

```
Bitpanda  <-- read-only key, in a GitHub secret --  GitHub Actions (every 3 hours)
                                                         |
                                  seals the portfolio with your passphrase
                                  (AES-256-GCM, PBKDF2-SHA256, 600,000 rounds)
                                                         v
                                              app/data.enc on GitHub Pages
                                                         |
          your phone downloads the sealed file and opens it with your passphrase
```

- The key has the **Read** scope only: it cannot buy, sell or withdraw.
- `data.enc` is public, because GitHub Pages is. It is useless without the passphrase, so use a long one (four random words).
- On your phone the passphrase is sealed under your PIN, and optionally under a passkey that Face ID unlocks (WebAuthn with the PRF extension; iOS 18 or later).
- No server of its own, no account, no analytics. The only other address the app asks is Bitpanda's public price chart, for the holding you open; no key and nothing about you goes with it.

## Set it up

1. Fork this repository. In **Settings, Pages**, set the source to **GitHub Actions**, and allow workflows in the **Actions** tab. Your app lives at `yourname.github.io/the-future/app/`.
2. In Bitpanda, **Account, API keys**, create a key with the **Read** scope only.
3. In your fork, **Settings, Secrets and variables, Actions**, add:
   - `BITPANDA_API_KEY`: the key
   - `SYNC_PASSPHRASE`: a passphrase of at least 12 characters
4. Run **Actions, Test and deploy to GitHub Pages, Run workflow** once. After that it runs every three hours and on every push to `main`. Each run also keeps the value history from the last one, so it reaches back further than Bitpanda's one year.
5. Open your copy of the app, tap **Connect Bitpanda**, enter the passphrase, choose a PIN.

Without the two secrets the workflow still deploys; the app then offers the demo with made-up numbers.

## Structure

```
lib/        the Flutter app
  projection.dart   the maths (monthly steps, returns per asset kind, raises, one-offs, inflation)
  snapshot.dart     what Bitpanda returned, and the usual monthly amount derived from it
  vault.dart        PBKDF2 and AES-GCM, shared with tools/snapshot.mjs
  state.dart        the plan, the lock, the filter, saved in the browser
  ui/, screens/     the interface
web/        the page shell: haptics.js (iPhone ticks), biometrics.js (passkey), manifest, icons
landing/    the landing page and the 404
tools/      sync.mjs (reads Bitpanda, seals), snapshot.mjs (the parsing), serve.mjs (local preview)
tests/      Node tests for the parsing and the sealing
test/       Dart tests for the maths, the vault and the state
docs/       the design direction and critique
```

## Develop

```bash
npm test                 # Node tests
flutter test             # Dart tests
flutter analyze
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /the-future/app/ --no-web-resources-cdn
node tools/serve.mjs     # http://localhost:4173/the-future/  (landing) and /app/ (app)
```

## Good to know

- The projection is a calculation, not a forecast: the returns are assumptions you can change, taxes and fees are not included, and you can lose money. Not financial advice.
- The monthly amount is derived from your trades (`rate` times amount, per month). It assumes a EUR account and may differ from your real deposits; the ruler overrides it.
- Not affiliated with Bitpanda.

## Licence

MIT, see [LICENSE](LICENSE).
