# The Future: design direction

Not shipped (the build copies only `landing/` and the app). Read before changing the look.

## Brief

Self-authored from Nikita's message and the picture he gave.

- **What:** a free, private PWA that reads a Bitpanda portfolio and projects it forward. Plus a landing page.
- **Core action:** open, see what you hold, slide the monthly amount, see the number twenty years out.
- **Feel (the owner's words):** like the picture he sent: cream ground, a serif for the big numbers, deep navy for actions, a green growth curve with a glowing end, text that arrives out of a blur. Polished like a native iPhone app, with haptics and overscroll.

## The decision that was given

The look was chosen by the owner, not explored. Three rendered directions were skipped on purpose: he showed the one he wants.

That look is close to what the web-designer skill calls the **Paper Edition** (warm paper, editorial serif). The skill says to refuse it by default. Here it is kept, and what makes it ours instead of the template:

- **No tells of the template:** no "New" pill, no italic accent word in the headline, no mono eyebrows, no stats strip, no bento, no pricing, no FAQ, no black pill with a ghost pill beside it. The one headline is plain.
- **The richness is the product itself:** a growth curve you can change, a ruler, real numbers, on the first screen of the app and in a working calculator on the landing page. Not paper alone.
- **A grammar from the visitor's questions:** what is it, can I try it, how does it connect, is it safe, how do I install it.
- **A signature:** numbers and words arrive out of a blur (about 0.9 s, ease-out, 70 ms between words); the monthly amount is a ruler that flings and settles on a tick; the end of the curve glows. All of it stops under reduced motion.

## The category default refused

Trading and portfolio apps: black or dark navy with lime or green candles, a ticker, red and green everywhere, a row of KPI tiles, "Hello, Name". Here: light, calm, one green only for growth, a navy for actions, and the loss colour only where a number is below zero.

## Tokens

| Role | Value |
|---|---|
| ground | `#F8F5EC` |
| raised | `#FFFDF8` |
| ink | `#16170F` |
| ink-2 | `#5D5C4F` (landing), `#6A695C` (app) |
| navy (actions, selected) | `#263248` |
| green (growth) | `#4A8B5A`, as text `#2F6B40` |
| loss | `#A8432F` |
| sand (metals) | `#C7B58C` |

Light only. The app and the page both declare `color-scheme: light`; a dark theme is not built.

**Type.** Newsreader (variable, optical size) for headings and every large number, because it is the closest free face to the picture's serif and its figures stay tidy in tabular mode. Geist for text, because it is neutral next to it. Both are bundled (SIL OFL, the licences are in `assets/fonts`); the web page loads Latin subsets as woff2.

**Scale (app).** 72 and 64 for the number, 40 for large titles (down to 20 when collapsed), 16 for rows, 13 to 15 for notes.

**Radius family.** 22 for grouped lists, 27 for buttons (full pill), 32 for the dock, 12 to 14 for small marks.

## Native feel

- Bouncing scroll on every list, with mouse or finger; pull to refresh; large titles that collapse.
- Sheets are real iOS sheets (`CupertinoSheetRoute`): they push the page back and close by dragging.
- Haptics: Android uses the vibration API; iPhone has none, so `web/haptics.js` lies one invisible switch over the app (copied from Kalorat, where it was worked out on a real iPhone) so a tap ticks.
- The tab bar is the only glass: a blur and a tint, nothing else.
- Safe areas follow Kalorat's finding: no `viewport-fit=cover` (it broke touch targets on an iPhone home-screen app), and the home indicator inset is added for standalone iPhones.

## Voice

Plain, short, specific. "See what your money becomes." No exclamation marks, no "unlock", no "seamless".
