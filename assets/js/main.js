(() => {
  const config = {
    APP_STORE_URL: "https://apps.apple.com/app/id0000000000",
    CANONICAL_URL: "https://getzentimer.com/",
    BACKGROUND_ROTATION_INTERVAL_MS: 24000,
    BACKGROUND_CROSSFADE_MS: 1800,
    HERO_DECK_SWAP_INTERVAL_MS: 10000,
    ...(window.ZenTimerSiteConfig || {})
  };

  const state = {
    themes: [],
    activeLayerIndex: 0,
    activeThemeIndex: 0,
    intervalId: null,
    deckIntervalId: null,
    deckSwapped: false,
    manifestLoaded: false,
    backgroundInitialized: false
  };

  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // One-time WebP support check
  const supportsWebP = (() => {
    const canvas = document.createElement("canvas");
    canvas.width = 1;
    canvas.height = 1;
    return canvas.toDataURL("image/webp").indexOf("data:image/webp") === 0;
  })();

  function toWebP(path) {
    return supportsWebP ? path.replace(/\.(png|jpe?g)$/, ".webp") : path;
  }

  function screenshotURL(path) {
    return toWebP(path);
  }

  function updatePictureSource(img, newSrc) {
    const picture = img.closest("picture");
    if (!picture) return;
    const source = picture.querySelector("source[type='image/webp']");
    if (source) {
      source.setAttribute("srcset", newSrc.replace(/\.png$/, ".webp"));
    }
  }

  const dom = {
    bgLayers: Array.from(document.querySelectorAll(".zt-bg-layer")),
    showcaseTimerScreen: document.getElementById("zt-showcase-screen-timer"),
    showcaseStatsScreen: document.getElementById("zt-showcase-screen-stats"),
    phoneDeck: document.getElementById("zt-phone-deck"),
    phoneCards: Array.from(document.querySelectorAll("[data-deck-phone]")),
    themeButtons: Array.from(document.querySelectorAll("[data-theme-option]")),
    featureScreens: Array.from(document.querySelectorAll("[data-feature-screen]")),
    lightbox: document.getElementById("zt-lightbox"),
    lightboxImg: document.getElementById("zt-lightbox-img"),
    year: document.querySelector("[data-year]")
  };

  init();

  function init() {
    document.documentElement.style.setProperty("--bg-crossfade-ms", `${config.BACKGROUND_CROSSFADE_MS}ms`);
    setCanonicalURL();
    hydrateAppStoreLinks();
    setupMotionSupport();
    setupRevealAnimations();
    setupParallax();
    setupFooterYear();
    setupFocusPulse();
    setupThemeCards();
    setupDeckRotation();
    setupDeckInteraction();
    setupLightbox();
    document.addEventListener("visibilitychange", handleVisibilityChange);
    void initBackgroundRotation();
  }

  function setCanonicalURL() {
    const canonicalTag = document.querySelector("link[rel='canonical']");
    if (canonicalTag && config.CANONICAL_URL) {
      canonicalTag.setAttribute("href", config.CANONICAL_URL);
    }
  }

  function hydrateAppStoreLinks() {
    const links = document.querySelectorAll("[data-app-store-link]");
    links.forEach((link) => {
      const slot = link.getAttribute("data-cta-slot") || "default";
      link.setAttribute("href", withTracking(config.APP_STORE_URL, slot));
      link.setAttribute("rel", "noopener noreferrer");
      link.setAttribute("target", "_blank");
    });
  }

  function withTracking(baseURL, slot) {
    try {
      const url = new URL(baseURL);
      url.searchParams.set("ct", `zt-site-${slot}`);
      if (!url.searchParams.has("itscg")) {
        url.searchParams.set("itscg", "30200");
      }
      return url.toString();
    } catch {
      return baseURL;
    }
  }

  function setupMotionSupport() {
    const supportsBackdrop = CSS.supports("backdrop-filter: blur(8px)") || CSS.supports("-webkit-backdrop-filter: blur(8px)");
    if (!supportsBackdrop) {
      document.body.classList.add("no-backdrop");
    }
  }

  function setupRevealAnimations() {
    const nodes = document.querySelectorAll("[data-reveal]");
    if (!nodes.length || prefersReducedMotion) {
      nodes.forEach((node) => node.classList.add("is-visible"));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { rootMargin: "0px 0px -12% 0px", threshold: 0.08 }
    );

    nodes.forEach((node) => observer.observe(node));
  }

  function setupParallax() {
    if (prefersReducedMotion) {
      return;
    }

    const nodes = Array.from(document.querySelectorAll("[data-parallax]"));
    if (!nodes.length) {
      return;
    }

    let scheduled = false;

    const apply = () => {
      const scrollY = window.scrollY;
      nodes.forEach((node) => {
        const speed = Number(node.getAttribute("data-parallax-speed") || "0.04");
        node.style.setProperty("--parallax-shift", `${Math.round(scrollY * speed * -1)}`);
      });
      scheduled = false;
    };

    const onScroll = () => {
      if (!scheduled) {
        scheduled = true;
        window.requestAnimationFrame(apply);
      }
    };

    window.addEventListener("scroll", onScroll, { passive: true });
    apply();
  }

  function setupFooterYear() {
    if (dom.year) {
      dom.year.textContent = String(new Date().getFullYear());
    }
    const publishEl = document.querySelector("[data-publish-date]");
    if (publishEl) {
      const stamp = document.documentElement.getAttribute("data-build-date");
      if (stamp) {
        publishEl.textContent = `Published ${stamp}`;
      }
    }
  }

  function setupFocusPulse() {
    if (prefersReducedMotion) {
      return;
    }
    const primaryCTA = document.querySelector("[data-primary-cta]");
    if (primaryCTA) {
      primaryCTA.classList.add("zt-pulse");
    }
  }

  function setupThemeCards() {
    dom.themeButtons.forEach((button) => {
      button.addEventListener("click", () => {
        const themeId = button.getAttribute("data-theme-option");
        const index = state.themes.findIndex((theme) => theme.id === themeId);
        if (index >= 0) {
          button.classList.add("is-loading");
          applyThemeByIndex(index, { animateBackground: true, fromUser: true })
            .finally(() => button.classList.remove("is-loading"));
        }
      });
    });
  }

  async function initBackgroundRotation() {
    if (dom.bgLayers.length < 2) {
      return;
    }

    try {
      const response = await fetch("assets/img/backgrounds/manifest.json", { cache: "no-store" });
      if (!response.ok) {
        throw new Error("Background manifest not found");
      }

      const manifest = await response.json();
      const resolutionLabel = pickResolutionLabel();
      state.themes = (manifest.themes || [])
        .map((theme) => {
          const image =
            theme.images?.find((entry) => entry.resolution === resolutionLabel) ||
            theme.images?.[0] ||
            null;
          if (!image?.file) {
            return null;
          }
          return {
            id: theme.id,
            displayName: theme.displayName,
            accentTintHex: theme.accentTintHex,
            imageURL: toWebP(image.file),
            timerScreenshotURL: screenshotURL(`assets/img/appstore-captures/timer-${theme.id}.png`),
            statsScreenshotURL: screenshotURL(`assets/img/appstore-captures/stats-${theme.id}.png`),
            featureScreenshots: {
              timer: screenshotURL(`assets/img/appstore-captures/feature-timer-${theme.id}.png`),
              health: screenshotURL(`assets/img/appstore-captures/feature-health-${theme.id}.png`),
              stats: screenshotURL(`assets/img/appstore-captures/feature-stats-${theme.id}.png`),
              themes: screenshotURL(`assets/img/appstore-captures/feature-themes-${theme.id}.png`)
            }
          };
        })
        .filter(Boolean);

      if (!state.themes.length) {
        return;
      }

      state.manifestLoaded = true;
      await applyThemeByIndex(0, { animateBackground: false });

      if (!prefersReducedMotion) {
        startRotation();
      }
    } catch (error) {
      console.warn("ZenTimer background rotation disabled:", error);
    }
  }

  function pickResolutionLabel() {
    const requiredWidth = window.innerWidth * Math.max(window.devicePixelRatio || 1, 1);
    if (requiredWidth >= 2900) {
      return "3840x2160";
    }
    if (requiredWidth >= 1900) {
      return "2560x1440";
    }
    return "1600x900";
  }

  function startRotation() {
    stopRotation();
    if (config.BACKGROUND_ROTATION_INTERVAL_MS <= 0) {
      return;
    }
    state.intervalId = window.setInterval(() => {
      void rotateTheme(1, false);
    }, config.BACKGROUND_ROTATION_INTERVAL_MS);
  }

  function stopRotation() {
    if (state.intervalId) {
      window.clearInterval(state.intervalId);
      state.intervalId = null;
    }
  }

  async function rotateTheme(step, fromUser) {
    if (!state.themes.length) {
      return;
    }
    const nextThemeIndex = (state.activeThemeIndex + step + state.themes.length) % state.themes.length;
    await applyThemeByIndex(nextThemeIndex, { animateBackground: true, fromUser });
  }

  async function applyThemeByIndex(index, options = {}) {
    const { animateBackground = true, fromUser = false } = options;
    if (!state.themes.length) {
      return;
    }

    const normalizedIndex = ((index % state.themes.length) + state.themes.length) % state.themes.length;
    const theme = state.themes[normalizedIndex];
    // Preload only above-fold images before applying; feature screens load in background
    await Promise.all([
      preloadImage(theme.imageURL),
      preloadImage(theme.timerScreenshotURL),
      preloadImage(theme.statsScreenshotURL)
    ]);
    Object.values(theme.featureScreenshots).forEach(preloadImage);

    if (!state.backgroundInitialized || !animateBackground || dom.bgLayers.length < 2) {
      dom.bgLayers.forEach((layer) => {
        layer.style.backgroundImage = `url('${theme.imageURL}')`;
        layer.classList.remove("is-active");
      });
      if (dom.bgLayers[0]) {
        dom.bgLayers[0].classList.add("is-active");
      }
      state.activeLayerIndex = 0;
      state.backgroundInitialized = true;
    } else {
      const inactiveLayerIndex = state.activeLayerIndex === 0 ? 1 : 0;
      const activeLayer = dom.bgLayers[state.activeLayerIndex];
      const inactiveLayer = dom.bgLayers[inactiveLayerIndex];

      inactiveLayer.style.backgroundImage = `url('${theme.imageURL}')`;
      inactiveLayer.classList.add("is-active");
      activeLayer.classList.remove("is-active");
      state.activeLayerIndex = inactiveLayerIndex;
    }

    state.activeThemeIndex = normalizedIndex;
    applyThemeAccent(theme.accentTintHex);
    updateThemeUI(theme);

    if (fromUser && !prefersReducedMotion) {
      startRotation();
    }
  }

  function applyThemeAccent(accentHex) {
    if (!accentHex) {
      return;
    }
    document.documentElement.style.setProperty("--theme-accent", accentHex);
  }

  function updateThemeUI(theme) {
    updateShowcaseScreens(theme);
    updateFeatureScreens(theme);

    dom.themeButtons.forEach((button) => {
      const isActive = button.getAttribute("data-theme-option") === theme.id;
      button.setAttribute("aria-pressed", String(isActive));
    });
  }

  function updateShowcaseScreens(theme) {
    updateShowcaseScreen(
      dom.showcaseTimerScreen,
      theme.timerScreenshotURL,
      `ZenTimer timer list in ${theme.displayName} theme`
    );
    updateShowcaseScreen(
      dom.showcaseStatsScreen,
      theme.statsScreenshotURL,
      `ZenTimer stats in ${theme.displayName} theme`
    );
  }

  function updateShowcaseScreen(screen, newSrc, altText) {
    if (!screen || !newSrc) return;

    if (screen.src.endsWith(newSrc.replace(/^.*\//, ""))) return;

    const applySource = () => {
      updatePictureSource(screen, newSrc);
      screen.src = newSrc;
      screen.alt = altText;
    };

    if (prefersReducedMotion) {
      applySource();
      return;
    }

    screen.classList.add("is-fading");
    setTimeout(() => {
      applySource();
      screen.classList.remove("is-fading");
    }, 500);
  }

  function updateFeatureScreens(theme) {
    dom.featureScreens.forEach((screen) => {
      const key = screen.getAttribute("data-feature-screen");
      const newSrc = theme.featureScreenshots[key];
      if (!newSrc) return;
      if (screen.src.endsWith(newSrc.replace(/^.*\//, ""))) return;

      const applySource = () => {
        updatePictureSource(screen, newSrc);
        screen.src = newSrc;
        screen.alt = `ZenTimer ${key} in ${theme.displayName} theme`;
      };

      if (prefersReducedMotion) {
        applySource();
        return;
      }

      screen.classList.add("is-fading");
      setTimeout(() => {
        applySource();
        screen.classList.remove("is-fading");
      }, 500);
    });
  }

  function setupLightbox() {
    if (!dom.lightbox || !dom.lightboxImg) return;

    dom.featureScreens.forEach((screen) => {
      screen.parentElement.addEventListener("click", () => {
        dom.lightboxImg.src = screen.src;
        dom.lightboxImg.alt = screen.alt;
        dom.lightbox.classList.add("is-open");
        dom.lightbox.setAttribute("aria-hidden", "false");
      });
    });

    dom.lightbox.addEventListener("click", (e) => {
      if (e.target === dom.lightbox || e.target.classList.contains("zt-lightbox-close")) {
        closeLightbox();
      }
    });

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && dom.lightbox.classList.contains("is-open")) {
        closeLightbox();
      }
    });
  }

  function closeLightbox() {
    dom.lightbox.classList.remove("is-open");
    dom.lightbox.setAttribute("aria-hidden", "true");
  }

  function setupDeckRotation() {
    if (!dom.phoneDeck) {
      return;
    }
    if (!prefersReducedMotion) {
      startDeckRotation();
    }
  }

  function setupDeckInteraction() {
    if (!dom.phoneCards.length) {
      return;
    }

    const handleSelect = (phoneType) => {
      if (phoneType === "timer") {
        setDeckSwapped(false, true);
      } else if (phoneType === "stats") {
        setDeckSwapped(true, true);
      }
    };

    dom.phoneCards.forEach((card) => {
      card.addEventListener("click", () => {
        handleSelect(card.getAttribute("data-deck-phone"));
      });

      card.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          handleSelect(card.getAttribute("data-deck-phone"));
        }
      });
    });
  }

  function startDeckRotation() {
    stopDeckRotation();
    if (config.HERO_DECK_SWAP_INTERVAL_MS <= 0) {
      return;
    }

    state.deckIntervalId = window.setInterval(() => {
      setDeckSwapped(!state.deckSwapped, false);
    }, config.HERO_DECK_SWAP_INTERVAL_MS);
  }

  function stopDeckRotation() {
    if (state.deckIntervalId) {
      window.clearInterval(state.deckIntervalId);
      state.deckIntervalId = null;
    }
  }

  function setDeckSwapped(swapped, restartTimer) {
    if (!dom.phoneDeck) {
      return;
    }
    state.deckSwapped = Boolean(swapped);
    dom.phoneDeck.classList.toggle("is-swapped", state.deckSwapped);

    if (restartTimer && !prefersReducedMotion) {
      startDeckRotation();
    }
  }

  function preloadImage(url) {
    return new Promise((resolve) => {
      const image = new Image();
      image.src = url;
      image.onload = () => resolve();
      image.onerror = () => resolve();
    });
  }

  function handleVisibilityChange() {
    if (document.hidden) {
      stopRotation();
      stopDeckRotation();
    } else {
      if (state.manifestLoaded && !prefersReducedMotion) {
        startRotation();
      }
      if (!prefersReducedMotion) {
        startDeckRotation();
      }
    }
  }
})();
