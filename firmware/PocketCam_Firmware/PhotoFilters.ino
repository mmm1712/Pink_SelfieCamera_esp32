// ===============================
// PhotoFilters.ino
// Creator Cam — separate subject/photo filters
//
// Input format:
// normalRGB565 = display/normal RGB565, NOT camera byte-swapped.
//
// Used from StickerEngine.ino like:
// uint16_t filtered = ccApplyPhotoFilter(camNormal, x, y, stBackgroundMode);
//
// Filter mapping:
// 0 = Purple Arcade Pop
// 1 = Sky Dream / Travel
// 2 = Mint Snackie / Matcha Pop
// 3 = Pink Diner
// 4 = Clean / no filter
// 5 = Cream Film
// 6 = Blue Milk
// ===============================

static inline uint8_t pfClamp8(int v) {
  if (v < 0) return 0;
  if (v > 255) return 255;
  return (uint8_t)v;
}

static uint16_t pfRGB565(int r, int g, int b) {
  r = pfClamp8(r);
  g = pfClamp8(g);
  b = pfClamp8(b);

  return ((r & 0xF8) << 8) |
         ((g & 0xFC) << 3) |
         (b >> 3);
}

static void pfRGB565To888(uint16_t normalRGB565, int &r, int &g, int &b) {
  r = ((normalRGB565 >> 11) & 0x1F) * 255 / 31;
  g = ((normalRGB565 >> 5) & 0x3F) * 255 / 63;
  b = (normalRGB565 & 0x1F) * 255 / 31;
}

static void pfContrast(int &r, int &g, int &b, int num, int den) {
  r = ((r - 128) * num) / den + 128;
  g = ((g - 128) * num) / den + 128;
  b = ((b - 128) * num) / den + 128;
}

static void pfSaturation(int &r, int &g, int &b, int num, int den) {
  int gray = (r * 30 + g * 59 + b * 11) / 100;

  r = gray + ((r - gray) * num) / den;
  g = gray + ((g - gray) * num) / den;
  b = gray + ((b - gray) * num) / den;
}

static void pfPosterize(int &r, int &g, int &b, int step) {
  r = (r / step) * step;
  g = (g / step) * step;
  b = (b / step) * step;
}

static void pfGrain(int &r, int &g, int &b, int x, int y, int amp) {
  // Deterministic fake grain, stable between preview/save.
  int n = ((x * 17 + y * 11 + x * y * 3 + 23) % (amp * 2 + 1)) - amp;
  r += n;
  g += n;
  b += n;
}

static void pfSoftGlow(int &r, int &g, int &b, int amount) {
  int lum = (r + g + b) / 3;

  if (lum > 145) {
    r += amount;
    g += amount;
    b += amount / 2;
  }

  if (lum < 55) {
    r += amount / 2;
    g += amount / 2;
    b += amount / 2;
  }
}

// ===============================
// 0 — Purple Arcade Pop
// Reference vibe: purple arcade / neon / playful
// ===============================
static uint16_t pfPurpleArcade(uint16_t normalRGB565, int x, int y) {
  int r, g, b;
  pfRGB565To888(normalRGB565, r, g, b);

  // Neon purple-pink tint
  r += 18;
  g += 2;
  b += 28;

  // More pop than the other filters
  pfContrast(r, g, b, 112, 100);
  pfSaturation(r, g, b, 112, 100);

  // Slight glow and soft grain
  pfSoftGlow(r, g, b, 10);
  pfGrain(r, g, b, x, y, 5);

  return pfRGB565(r, g, b);
}

// ===============================
// 1 — Sky Dream / Travel
// Reference vibe: blue sky, clouds, soft airy blur
// ===============================
static uint16_t pfSkyDream(uint16_t normalRGB565, int x, int y) {
  int r, g, b;
  pfRGB565To888(normalRGB565, r, g, b);

  // Light, airy, cooler highlights
  r += 8;
  g += 12;
  b += 20;

  // Lower contrast, dreamy
  pfContrast(r, g, b, 92, 100);
  pfSaturation(r, g, b, 88, 100);

  // Lift shadows so it feels cloudy/soft
  int lum = (r + g + b) / 3;
  if (lum < 90) {
    r += 12;
    g += 14;
    b += 18;
  }

  pfSoftGlow(r, g, b, 14);
  pfGrain(r, g, b, x, y, 3);

  return pfRGB565(r, g, b);
}

// ===============================
// 2 — Mint Snackie / Matcha Pop
// Reference vibe: green snack shop, creamy, painterly
// ===============================
static uint16_t pfMintSnackie(uint16_t normalRGB565, int x, int y) {
  int r, g, b;
  pfRGB565To888(normalRGB565, r, g, b);

  // Pastel mint + creamy warmth
  r += 16;
  g += 20;
  b += 8;

  // Soft low contrast
  pfContrast(r, g, b, 92, 100);
  pfSaturation(r, g, b, 82, 100);

  // Mint shadows, cream highlights
  int lum = (r + g + b) / 3;
  if (lum < 105) {
    g += 14;
    b += 4;
  } else {
    r += 10;
    g += 6;
  }

  // Painterly / low-color vibe
  pfPosterize(r, g, b, 18);
  pfSoftGlow(r, g, b, 8);
  pfGrain(r, g, b, x, y, 3);

  return pfRGB565(r, g, b);
}

// ===============================
// 3 — Pink Diner
// Reference vibe: pink diner, warm, soft, neon hearts
// ===============================
static uint16_t pfPinkDiner(uint16_t normalRGB565, int x, int y) {
  int r, g, b;
  pfRGB565To888(normalRGB565, r, g, b);

  // Pink/red warmth
  r += 30;
  g += 8;
  b += 12;

  // Soft but still cute
  pfContrast(r, g, b, 98, 100);
  pfSaturation(r, g, b, 108, 100);

  // Creamy highlights
  int lum = (r + g + b) / 3;
  if (lum > 120) {
    r += 10;
    g += 4;
  }

  pfSoftGlow(r, g, b, 12);
  pfGrain(r, g, b, x, y, 4);

  return pfRGB565(r, g, b);
}

// ===============================
// 4 — Clean / regular
// ===============================
static uint16_t pfClean(uint16_t normalRGB565, int x, int y) {
  return normalRGB565;
}

// ===============================
// 5 — Cream Film
// Similar soft/cute feeling to Pink Diner, without pink.
// ===============================
static uint16_t pfCreamFilm(uint16_t normalRGB565, int x, int y) {
  int r, g, b;
  pfRGB565To888(normalRGB565, r, g, b);

  // Creamy warm highlights, more butter/peach than pink.
  r += 18;
  g += 16;
  b += 4;

  pfContrast(r, g, b, 96, 100);
  pfSaturation(r, g, b, 94, 100);

  int lum = (r + g + b) / 3;
  if (lum > 118) {
    r += 8;
    g += 8;
    b += 2;
  }

  if (lum < 75) {
    r += 8;
    g += 10;
    b += 8;
  }

  pfSoftGlow(r, g, b, 11);
  pfGrain(r, g, b, x, y, 3);

  return pfRGB565(r, g, b);
}

// ===============================
// 6 — Blue Milk
// Soft airy color, not neon and not pink.
// ===============================
static uint16_t pfBlueMilk(uint16_t normalRGB565, int x, int y) {
  int r, g, b;
  pfRGB565To888(normalRGB565, r, g, b);

  r += 4;
  g += 13;
  b += 24;

  pfContrast(r, g, b, 91, 100);
  pfSaturation(r, g, b, 86, 100);

  int lum = (r + g + b) / 3;
  if (lum < 92) {
    r += 8;
    g += 12;
    b += 18;
  }

  if (lum > 145) {
    r += 4;
    g += 8;
    b += 10;
  }

  pfSoftGlow(r, g, b, 12);
  pfGrain(r, g, b, x, y, 2);

  return pfRGB565(r, g, b);
}

// ===============================
// Public function for StickerEngine.ino
// ===============================
uint16_t ccApplyPhotoFilter(uint16_t normalRGB565, int x, int y, int mode) {
  if (mode == 0) return pfPurpleArcade(normalRGB565, x, y);
  if (mode == 1) return pfSkyDream(normalRGB565, x, y);
  if (mode == 2) return pfMintSnackie(normalRGB565, x, y);
  if (mode == 3) return pfPinkDiner(normalRGB565, x, y);
  if (mode == 5) return pfCreamFilm(normalRGB565, x, y);
  if (mode == 6) return pfBlueMilk(normalRGB565, x, y);

  return pfClean(normalRGB565, x, y);
}

// ===============================
// Fast preview LUT
// ===============================
static uint16_t *pfPreviewLUT = NULL;
static int pfPreviewLUTMode = -1;

static bool pfEnsurePreviewLUT(int mode) {
  if (mode == 4) {
    return false;
  }

  if (pfPreviewLUT && pfPreviewLUTMode == mode) {
    return true;
  }

  if (!pfPreviewLUT) {
    pfPreviewLUT = (uint16_t *)ps_malloc(65536 * sizeof(uint16_t));
    if (!pfPreviewLUT) {
      pfPreviewLUT = (uint16_t *)malloc(65536 * sizeof(uint16_t));
    }
  }

  if (!pfPreviewLUT) {
    Serial.println("No memory for preview filter LUT");
    return false;
  }

  unsigned long startMs = millis();
  for (uint32_t color = 0; color <= 0xFFFF; color++) {
    // Preview LUT keeps the color recipe but skips per-pixel grain, which is too
    // expensive for high FPS. Final saved JPG still uses the full filter path.
    pfPreviewLUT[color] = ccApplyPhotoFilter((uint16_t)color, 0, 0, mode);
    if ((color & 0x0FFF) == 0) {
      yield();
    }
  }

  pfPreviewLUTMode = mode;
  Serial.printf("Preview filter LUT ready mode=%d in %lums\n", mode, millis() - startMs);
  return true;
}

uint16_t ccApplyPhotoFilterFastPreview(uint16_t normalRGB565, int mode) {
  if (mode == 4) {
    return normalRGB565;
  }

  if (pfEnsurePreviewLUT(mode)) {
    return pfPreviewLUT[normalRGB565];
  }

  return ccApplyPhotoFilter(normalRGB565, 0, 0, mode);
}
