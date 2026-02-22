# Website Notes

## Gotchas

- **Metal export: use `device.makeLibrary(source:)`, not `makeDefaultLibrary()`.** The latter returns nil in standalone script context. The exporter compiles the shader source directly.
- **Smart App Banner app-id is commented out.** Uncomment `<meta name="apple-itunes-app" content="app-id=...">` with real numeric ID before launch.
- **Pages deploy should stay Actions-based.** Keep `.github/workflows/deploy-site.yml` as the deployment path for this repo.
- **Heading colors should be explicit in `assets/css/styles.css`.** Because index loads Bootstrap asynchronously, set title colors directly (for `h1/h2/h3` sections) instead of relying on defaults.
- **Reveal animation must fail open.** Keep `[data-reveal]` visible by default and only apply hidden pre-state under a JS guard class (e.g. `.js`) so the hero/header never disappears if JS fails.
- **Footer publish date needs a fallback.** If `data-build-date` is missing, render from `document.lastModified` (or current date fallback) so publish text is never blank.
- **Index non-button links should stay theme-reactive without relying on `color-mix()`.** Keep content/footer links in `.zt-shell` driven directly by `--theme-accent` (+ explicit `:visited`) so href text never falls back to default browser blue where `color-mix()` support is inconsistent.
- **Footer link groups may need explicit state overrides.** For `.zt-footer-links a`, define `:link/:visited/:hover/:active` with theme color (and `!important` if needed) to beat Bootstrap/UA link defaults.
- **Support URL should expose real contact details.** App Store support pages should include a real contact method; keep spam risk lower by rendering an obfuscated visible address and generating `mailto:` via JS fragments.
- **Button style is intentionally unified to simple ghost anchors.** Keep CTA/button markup as plain text inside `<a class="zt-glass-btn zt-glass-btn--ghost">…</a>` so all page buttons match.
- **iOS Safari status bar color depends on `<meta name="theme-color">`.** Keep a dark theme color meta tag in each page head (`index.html`, `privacy.html`, `support.html`) so the top browser/status bar does not render with a light default.
- **`no-backdrop` fallback must be preserved.** Switches to opaque surfaces when `backdrop-filter` is unsupported. Don't remove this class.
- **`prefers-reduced-motion` disables background rotation.** Theme crossfade stops; keep this behavior.
- **Hero deck animation also stops for reduced motion.** The 10s front/back phone swap must not run when reduced motion is enabled.
- **Hero phone cards are interactive buttons.** The back phone can be tapped/clicked to bring it to front, and this should restart the 10s auto-swap timer.
- **Several placeholder URLs must be replaced before launch** — see Launch Checklist below.
- **Feature-card screenshots can silently become duplicates.** Verify `feature-health-*` and `feature-themes-*` are not copies of timer captures when refreshing assets; check image hashes/dimensions after any screenshot export.

## How it works

### Site structure
Static site at repo root: `index.html`, `privacy.html`, `support.html`, `assets/css/styles.css`, `assets/js/main.js`, `assets/img/`, `robots.txt`, `sitemap.xml`.

### Background pipeline
- Export tool: `tools/export_metal_backgrounds.swift` (run via `xcrun swift` from repo root).
- Renders six themes (`forest`, `dawn`, `lagoon`, `glacier`, `gold`, `space`) at three sizes (3840x2160, 2560x1440, 1600x900).
- Outputs to `assets/img/backgrounds/`: JPG files + `manifest.json` + `preview-grid.jpg`.
- Runtime: site fetches `manifest.json`, selects resolution by viewport + DPR. Crossfade between two background layers (24s interval, 1.8s transition). Accent tint from `accentTintHex` → `--theme-accent`.

### Glass styling
- Tokens: `--glass-bg`, `--glass-bg-strong`, `--glass-border`, `--glass-blur`, `--glass-shadow`.
- `.zt-glass`: linear-gradient + border + blur + soft shadow. No inset highlight, no saturation.
- `.zt-glass-btn` (`--ghost`): shared button style used across index/privacy/support for visual consistency.
- Subtle hover lift (`translateY(-1px)`), reduced pulse intensity.

### Smart App Banner
Native-only strategy. Custom sticky banner was removed. Meta tag is a commented placeholder pending App Store launch.

### Theme showcase (hero)
Dual iPhone mockups (`device-iphone-14-pro` from [devices.css](https://cdn.jsdelivr.net/npm/devices.css@0.2.0/dist/devices.min.css), CDN, MIT) are shown as an overlapping deck: timer list (`#zt-showcase-screen-timer`) and stats (`#zt-showcase-screen-stats`). The deck swaps front/back every 10 seconds via `#zt-phone-deck.is-swapped`, with CSS transforms/tilt and depth layering for the card-stack effect. Each phone is keyboard/click interactive (`data-deck-phone`) so manually selecting the back card brings it forward.

Theme cards still show background thumbnails and drive `applyThemeByIndex`, but theme selection now updates **both** screenshot images (`timer-<theme>.png` + `stats-<theme>.png`) with a 350ms crossfade. Background auto-rotation remains 24s and still controls active theme when idle.

Responsive: desktop uses a two-column hero (copy left, phone deck + theme cards right); tablet/mobile stack the showcase below copy while keeping an overlap look with reduced tilt/offset.

## Launch Checklist

1. App Store URL → `window.ZenTimerSiteConfig.APP_STORE_URL`
2. Smart App Banner → uncomment `apple-itunes-app` meta with real app-id
3. Canonical/domain URLs → `index.html`, `privacy.html`, `support.html`, `robots.txt`, `sitemap.xml` (production domain: `https://getzentimer.com`)
