# ZenTimer Website

Static one-page marketing site for ZenTimer.

## Run Locally

From repo root:

```bash
python3 -m http.server 8765
```
Then open: `http://127.0.0.1:8765/index.html`

## Structure

- `index.html` — landing page
- `privacy.html` — minimal privacy page
- `support.html` — App Store support page
- `assets/css/styles.css` — custom styling + glass effects
- `assets/js/main.js` — CTA, background rotation, motion, progressive enhancement
- `assets/img/backgrounds/` — generated Metal backgrounds + `manifest.json`
- `tools/export_metal_backgrounds.swift` — background export utility

## Update Launch Settings

Before publishing:

1. Set real App Store URL in `index.html`:
   - `window.ZenTimerSiteConfig.APP_STORE_URL`
2. Enable the native Smart App Banner in `index.html`:
   - Replace `<REAL_NUMERIC_ID>` in the `apple-itunes-app` meta tag with the published App Store numeric app ID.
   - Smart App Banner is supported in iOS/iPadOS Safari and requires a live App Store listing.
3. Set real production domain in:
   - `window.ZenTimerSiteConfig.CANONICAL_URL`
   - `robots.txt`
   - `sitemap.xml`
   - canonical links in `index.html`, `privacy.html`, and `support.html`

## Regenerate Metal Backgrounds

From repo root:

```bash
xcrun swift tools/export_metal_backgrounds.swift
```

This generates:

- 6 theme backgrounds (`forest`, `dawn`, `lagoon`, `glacier`, `gold`, `space`)
- 3 sizes each (`3840x2160`, `2560x1440`, `1600x900`)
- `assets/img/backgrounds/manifest.json`
- `assets/img/backgrounds/preview-grid.jpg`

## GitHub Pages

This repo deploys to Pages with GitHub Actions:

- Workflow: `.github/workflows/deploy-site.yml`
- Trigger: pushes to `main`

Custom domain setup for `getzentimer.com`:

1. In GitHub repo settings:
   - `Settings` → `Pages`
   - `Source` = `GitHub Actions`
   - `Custom domain` = `getzentimer.com`
   - Enable `Enforce HTTPS` after DNS resolves
2. In Squarespace DNS (`Domains` → your domain → `DNS settings`):
   - Add `A` records for host `@`:
     - `185.199.108.153`
     - `185.199.109.153`
     - `185.199.110.153`
     - `185.199.111.153`
   - Add `AAAA` records for host `@`:
     - `2606:50c0:8000::153`
     - `2606:50c0:8001::153`
     - `2606:50c0:8002::153`
     - `2606:50c0:8003::153`
   - Add `CNAME` for host `www` to `dobby.github.io`
3. Keep `CNAME` with:
   - `getzentimer.com`
