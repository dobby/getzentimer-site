# Website Notes

## Gotchas

- **Metal export: use `device.makeLibrary(source:)`, not `makeDefaultLibrary()`.** The latter returns nil in standalone script context. The exporter compiles the shader source directly.
- **Smart App Banner app-id is commented out.** Uncomment `<meta name="apple-itunes-app" content="app-id=...">` with real numeric ID before launch.
- **Pages deploy should stay Actions-based.** Keep `.github/workflows/deploy-site.yml` as the deployment path for this repo.
- **Support URL should expose real contact details.** App Store support pages should include a real contact method; keep spam risk lower by rendering an obfuscated visible address and generating `mailto:` via JS fragments.
- **Keep SVG displacement opt-in only.** `#zt-glass-distortion` may exist for CTA experimentation, but default CTA styling must remain the non-distorted layered glass unless `.zt-glass-btn--liquid` is explicitly added.
- **CTA buttons now use a required layer structure.** `.zt-glass-btn` expects `__fx`, `__effect`, `__tint`, `__shine`, and `__label` children for the glass rendering; changing CTA markup to plain text will break the new look.
- **`#zt-glass-distortion` is opt-in only.** Distortion filter defs are present in `index.html`, but the effect applies only with `.zt-glass-btn--liquid` and is intentionally unused by default.
- **`no-backdrop` fallback must be preserved.** Switches to opaque surfaces when `backdrop-filter` is unsupported. Don't remove this class.
- **`prefers-reduced-motion` disables background rotation.** Theme crossfade stops; keep this behavior.
- **Hero deck animation also stops for reduced motion.** The 10s front/back phone swap must not run when reduced motion is enabled.
- **Hero phone cards are interactive buttons.** The back phone can be tapped/clicked to bring it to front, and this should restart the 10s auto-swap timer.
- **Several placeholder URLs must be replaced before launch** — see Launch Checklist below.

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
- `.zt-glass-btn` (+ `--primary`, `--ghost`): same glass language, stable class API.
- CTA buttons now render with internal layered nodes (`.zt-glass-btn__effect`, `__tint`, `__shine`) and keep hover behavior to a slight tint shift plus subtle lift.
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
