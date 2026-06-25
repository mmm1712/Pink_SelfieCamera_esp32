// ===============================
// StickerEngine.ino
// PocketCam / Creator Cam — soft color modes for ESP32
//
// Heart cycles:
// gray clean -> Cream Film -> Mint Milk -> Blue Milk -> gray clean
//
// These modes intentionally avoid stickers, frames, and backgrounds. The photo
// stays clean; only the color recipe changes.
// ===============================

// From main file
bool saveRGB565FrameAsJPG(camera_fb_t *fb, String path);
bool writeBufferToSD(const String& path, const uint8_t *data, size_t length, const char *label);
void pollTouchDuringDraw();

// From PhotoFilters.ino
uint16_t ccApplyPhotoFilter(uint16_t normalRGB565, int x, int y, int mode);
uint16_t ccApplyPhotoFilterFastPreview(uint16_t normalRGB565, int mode);

static const int ST_MODE_CREAM = 0;
static const int ST_MODE_MINT = 1;
static const int ST_MODE_BLUE = 2;
static const int ST_COLOR_MODE_COUNT = 3;
static const int ST_REGULAR_MODE = 3;

static const unsigned long ST_HEART_TAP_LOCKOUT_MS = 280;
static int stBackgroundMode = ST_REGULAR_MODE;
static unsigned long stLastHeartTapMs = 0;

// ===============================
// Public API used by main file
// ===============================
bool isStickerModeEnabled() {
  return stBackgroundMode != ST_REGULAR_MODE;
}

bool tryHandleStickerTouch(uint8_t x, uint8_t y) {
  int cx = 34;
  int cy = 58;
  int r = 26;

  int dx = (int)x - cx;
  int dy = (int)y - cy;

  if ((dx * dx + dy * dy) <= (r * r)) {
    unsigned long now = millis();
    if (now - stLastHeartTapMs < ST_HEART_TAP_LOCKOUT_MS) {
      return true;
    }

    stLastHeartTapMs = now;

    if (stBackgroundMode == ST_REGULAR_MODE) {
      stBackgroundMode = ST_MODE_CREAM;
    } else if (stBackgroundMode >= 0 && stBackgroundMode < ST_COLOR_MODE_COUNT - 1) {
      stBackgroundMode++;
    } else {
      stBackgroundMode = ST_REGULAR_MODE;
    }

    Serial.print("Soft color mode = ");
    Serial.println(stBackgroundMode);
    return true;
  }

  return false;
}

// ===============================
// Helpers
// ===============================
static int stClampInt(int v, int lo, int hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

static inline uint8_t stClamp8(int v) {
  if (v < 0) return 0;
  if (v > 255) return 255;
  return (uint8_t)v;
}

static uint16_t stRGB565(int r, int g, int b) {
  r = stClamp8(r);
  g = stClamp8(g);
  b = stClamp8(b);

  return ((r & 0xF8) << 8) |
         ((g & 0xFC) << 3) |
         (b >> 3);
}

static uint16_t stSwap565(uint16_t p) {
  return (p >> 8) | (p << 8);
}

static uint16_t stAccent() {
  if (stBackgroundMode == ST_MODE_CREAM) return stRGB565(245, 178, 86);
  if (stBackgroundMode == ST_MODE_MINT) return stRGB565(112, 190, 150);
  if (stBackgroundMode == ST_MODE_BLUE) return stRGB565(94, 160, 218);
  return C_SOFT_GRAY;
}

static int stPhotoFilterMode() {
  if (stBackgroundMode == ST_MODE_CREAM) return 5; // cream film
  if (stBackgroundMode == ST_MODE_MINT) return 2;  // mint milk
  if (stBackgroundMode == ST_MODE_BLUE) return 6;  // blue milk
  return 4;
}

static uint16_t stCameraPixelNormal(uint16_t *pixels, int frameWidth, int sx, int sy) {
  sx = stClampInt(sx, 0, 239);
  sy = stClampInt(sy, 0, 239);

  int cropX = frameWidth > 240 ? (frameWidth - 240) / 2 : 0;
  uint16_t raw = pixels[sy * frameWidth + cropX + sx];
  return stSwap565(raw);
}

static uint16_t stFilteredCameraPixel(uint16_t *pixels, int frameWidth, int sx, int sy, int outX, int outY) {
  uint16_t normal = stCameraPixelNormal(pixels, frameWidth, sx, sy);
  return ccApplyPhotoFilter(normal, outX, outY, stPhotoFilterMode());
}

static uint16_t stComposeLayoutPixel(uint16_t *pixels, int frameWidth, int x, int y) {
  if (stBackgroundMode == ST_MODE_CREAM ||
      stBackgroundMode == ST_MODE_MINT ||
      stBackgroundMode == ST_MODE_BLUE) {
    return stFilteredCameraPixel(pixels, frameWidth, x, y, x, y);
  }

  return stCameraPixelNormal(pixels, frameWidth, x, y);
}

// ===============================
// Decorative preview drawing
// ===============================
static void stDrawHeartIcon(int cx, int cy, uint16_t color) {
  canvas->fillCircle(cx - 5, cy - 4, 5, color);
  canvas->fillCircle(cx + 5, cy - 4, 5, color);
  canvas->fillTriangle(cx - 11, cy - 2, cx + 11, cy - 2, cx, cy + 13, color);
}

void drawStickerIconDirect() {
  int x = 34;
  int y = 58;

  canvas->fillCircle(x + 1, y + 1, 16, C_BLACK);
  canvas->fillCircle(x, y, 16, C_WHITE);

  uint16_t heartColor = C_SOFT_GRAY;
  if (stBackgroundMode != ST_REGULAR_MODE) {
    heartColor = stAccent();
  }

  stDrawHeartIcon(x, y, heartColor);
}

// ===============================
// Preview composition
// ===============================
void drawStickerPreviewToCanvas() {
  if (!cameraOK || isCapturing) return;

  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Sticker preview frame failed");
    return;
  }

  if (fb->format == PIXFORMAT_RGB565 && fb->width >= 240 && fb->height >= 240) {
    uint16_t *pixels = (uint16_t *)fb->buf;
    uint16_t *dst = canvas->getFramebuffer();
    int filterMode = stPhotoFilterMode();
    int cropX = fb->width > 240 ? (fb->width - 240) / 2 : 0;

    if (!dst) {
      Serial.println("Sticker preview framebuffer missing");
      esp_camera_fb_return(fb);
      return;
    }

    for (int y = 0; y < 240; y++) {
      uint16_t *srcLine = pixels + (y * fb->width) + cropX;
      uint16_t *dstLine = dst + (y * 240);

      for (int x = 0; x < 240; x++) {
        uint16_t normal = stSwap565(srcLine[x]);
        dstLine[x] = ccApplyPhotoFilterFastPreview(normal, filterMode);
      }

      if ((y & 0x0F) == 0) {
        pollTouchDuringDraw();
        yield();
      }
    }
  } else {
    Serial.printf("Bad sticker preview frame: %dx%d format=%d len=%u\n",
      fb->width, fb->height, fb->format, (unsigned)fb->len);
  }

  esp_camera_fb_return(fb);
}

static bool stEncodeRGB565JPG(
  uint8_t *rgbData,
  size_t rgbLen,
  int width,
  int height,
  int quality,
  uint8_t **jpgBuf,
  size_t *jpgLen
) {
  *jpgBuf = NULL;
  *jpgLen = 0;

  bool ok = fmt2jpg(
    rgbData,
    rgbLen,
    width,
    height,
    PIXFORMAT_RGB565,
    quality,
    jpgBuf,
    jpgLen
  );

  if (!ok || *jpgBuf == NULL || *jpgLen == 0) {
    if (*jpgBuf) {
      free(*jpgBuf);
      *jpgBuf = NULL;
    }
    *jpgLen = 0;
    return false;
  }

  return true;
}

static bool stEncodeLayoutJPG(camera_fb_t *fb, uint8_t **jpgBuf, size_t *jpgLen, int quality) {
  if (!fb || fb->format != PIXFORMAT_RGB565 || fb->width < 240 || fb->height < 240) {
    return false;
  }

  uint16_t *out = (uint16_t *)ps_malloc(240 * 240 * sizeof(uint16_t));
  if (!out) out = (uint16_t *)malloc(240 * 240 * sizeof(uint16_t));

  if (!out) {
    Serial.println("No memory for layout video frame");
    return false;
  }

  uint16_t *pixels = (uint16_t *)fb->buf;

  for (int y = 0; y < 240; y++) {
    for (int x = 0; x < 240; x++) {
      out[y * 240 + x] = stSwap565(stComposeLayoutPixel(pixels, fb->width, x, y));
    }
  }

  bool ok = stEncodeRGB565JPG(
    (uint8_t *)out,
    240 * 240 * sizeof(uint16_t),
    240,
    240,
    quality,
    jpgBuf,
    jpgLen
  );
  free(out);
  return ok;
}

bool encodeStickerFrameJPG(camera_fb_t *fb, uint8_t **jpgBuf, size_t *jpgLen, int quality) {
  *jpgBuf = NULL;
  *jpgLen = 0;

  if (!fb || fb->format != PIXFORMAT_RGB565) {
    Serial.println("Unsupported frame for video JPG");
    return false;
  }

  if (stBackgroundMode != ST_REGULAR_MODE) {
    return stEncodeLayoutJPG(fb, jpgBuf, jpgLen, quality);
  }

  return stEncodeRGB565JPG(fb->buf, fb->len, fb->width, fb->height, quality, jpgBuf, jpgLen);
}

static bool stWriteOutAsJPG(uint16_t *out, int width, int height, String path, int quality) {
  uint8_t *jpgBuf = NULL;
  size_t jpgLen = 0;

  bool ok = stEncodeRGB565JPG(
    (uint8_t *)out,
    width * height * sizeof(uint16_t),
    width,
    height,
    quality,
    &jpgBuf,
    &jpgLen
  );

  if (!ok) {
    Serial.println("Layout JPG conversion failed");
    return false;
  }

  bool saved = writeBufferToSD(path, jpgBuf, jpgLen, "Layout JPG");
  free(jpgBuf);

  if (saved) {
    Serial.printf("Layout JPG details: quality=%d, frame=%dx%d\n", quality, width, height);
  }

  return saved;
}

// ===============================
// Save final layout JPG
// ===============================
bool saveStickerJPG(camera_fb_t *fb, String path) {
  if (!fb || fb->format != PIXFORMAT_RGB565 || fb->width < 1 || fb->height < 1) {
    Serial.println("Unsupported frame for layout save");
    return false;
  }

  if (stBackgroundMode == ST_REGULAR_MODE) {
    return saveRGB565FrameAsJPG(fb, path);
  }

  int width = fb->width;
  int height = fb->height;
  size_t pixelCount = (size_t)width * (size_t)height;

  uint16_t *out = (uint16_t *)ps_malloc(pixelCount * sizeof(uint16_t));
  if (!out) out = (uint16_t *)malloc(pixelCount * sizeof(uint16_t));

  if (!out) {
    Serial.println("No memory for layout image");
    return false;
  }

  uint16_t *pixels = (uint16_t *)fb->buf;
  int filterMode = stPhotoFilterMode();

  for (int y = 0; y < height; y++) {
    uint16_t *srcLine = pixels + ((size_t)y * width);
    uint16_t *dstLine = out + ((size_t)y * width);

    for (int x = 0; x < width; x++) {
      uint16_t normal = stSwap565(srcLine[x]);
      dstLine[x] = stSwap565(ccApplyPhotoFilter(normal, x, y, filterMode));
    }
  }

  bool ok = stWriteOutAsJPG(out, width, height, path, 92);
  free(out);
  return ok;
}
