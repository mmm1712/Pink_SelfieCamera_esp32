#include <Arduino.h>
#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include "esp_camera.h"
#include "img_converters.h"
#include <WiFi.h>
#include <WebServer.h>
#include <Arduino_GFX_Library.h>

// ===============================
// Sticker Engine prototypes
// ===============================
bool isStickerModeEnabled();
bool tryHandleStickerTouch(uint8_t x, uint8_t y);
void drawStickerPreviewToCanvas();
void drawStickerIconDirect();
bool saveStickerJPG(camera_fb_t *fb, String path);
bool encodeStickerFrameJPG(camera_fb_t *fb, uint8_t **jpgBuf, size_t *jpgLen, int quality);
void pollTouchDuringDraw();

// ===============================
// Round Display pins
// ===============================
#define LCD_CS   D1
#define LCD_DC   D3
#define LCD_SCK  D8
#define LCD_MOSI D10
#define LCD_MISO D9
#define LCD_RST  GFX_NOT_DEFINED
#define LCD_BL   D6

#define ROUND_SD_CS D2

// Touch
#define TOUCH_INT D7
#define CHSC6X_I2C_ID 0x2E
#define CHSC6X_READ_POINT_LEN 5

#define SPI_SPEED 40000000
#define CAMERA_INIT_XCLK_HZ 20000000
#define CAMERA_FAST_XCLK_MHZ 24

// ===============================
// Camera pins — XIAO ESP32S3 Sense
// ===============================
#define PWDN_GPIO_NUM   -1
#define RESET_GPIO_NUM  -1
#define XCLK_GPIO_NUM   10
#define SIOD_GPIO_NUM   40
#define SIOC_GPIO_NUM   39

#define Y9_GPIO_NUM     48
#define Y8_GPIO_NUM     11
#define Y7_GPIO_NUM     12
#define Y6_GPIO_NUM     14
#define Y5_GPIO_NUM     16
#define Y4_GPIO_NUM     18
#define Y3_GPIO_NUM     17
#define Y2_GPIO_NUM     15

#define VSYNC_GPIO_NUM  38
#define HREF_GPIO_NUM   47
#define PCLK_GPIO_NUM   13

// Stable live preview.
// Keep capture in the same RGB565/QVGA mode as preview for stability.
// The XIAO ESP32S3 Sense can restart when switching to JPEG high-res at shutter time.
#define PREVIEW_FRAME_SIZE FRAMESIZE_QVGA
#define PHOTO_CAPTURE_FRAME_SIZE FRAMESIZE_QVGA
#define ENABLE_EXPERIMENTAL_HQ_PHOTO 0
#define HQ_PHOTO_FRAME_SIZE FRAMESIZE_VGA
#define HQ_PHOTO_FALLBACK_FRAME_SIZE FRAMESIZE_QVGA
#define HQ_PHOTO_JPEG_QUALITY 10

// ===============================
// Wi-Fi
// ===============================
const char* AP_SSID = "your_camera_ssid";
const char* AP_PASSWORD = "your_camera_password";

IPAddress AP_IP(192, 168, 10, 1);
IPAddress AP_GATEWAY(192, 168, 10, 1);
IPAddress AP_SUBNET(255, 255, 255, 0);

WebServer server(80);

// ===============================
// Display
// ===============================
Arduino_DataBus *bus = new Arduino_ESP32SPI(
  LCD_DC, LCD_CS, LCD_SCK, LCD_MOSI, LCD_MISO
);

Arduino_GFX *gfx = new Arduino_GC9A01(
  bus, LCD_RST, 0, true
);

Arduino_Canvas *canvas = new Arduino_Canvas(240, 240, gfx);

// ===============================
// Colors
// ===============================
#define C_BLACK      BLACK
#define C_WHITE      WHITE
#define C_GRAY       0x8410
#define C_SOFT_GRAY  0xBDF7
#define C_IOS_BLUE   0x03DF
#define C_RED        0xF800
#define C_GREEN      0x07E0

// ===============================
// State
// ===============================
int currentMode = 1; // 0 = VIDEO, 1 = PHOTO
bool isRecording = false;
bool isCapturing = false;

bool sdOK = false;
bool cameraOK = false;

int latestPhotoId = 0;
int nextPhotoId = 1;

int latestVideoId = 0;
int nextVideoId = 1;

File videoFile;
int currentVideoId = 0;
int videoFrameCount = 0;
int videoFrameFailCount = 0;
unsigned long videoStartMs = 0;
unsigned long lastVideoFrameMs = 0;

const unsigned long VIDEO_FRAME_INTERVAL_MS = 200; // about 5 FPS
const unsigned long MAX_VIDEO_MS = 30000;

const int API_DEFAULT_LIMIT = 40;
const int API_MAX_LIMIT = 40;

bool wasTouching = false;
unsigned long lastTouchMs = 0;
unsigned long lastTouchPollMs = 0;
bool pendingTouchTap = false;
uint8_t pendingTouchX = 0;
uint8_t pendingTouchY = 0;

const unsigned long TOUCH_TAP_DEBOUNCE_MS = 70;
const unsigned long TOUCH_POLL_DURING_DRAW_MS = 12;
const unsigned long SHUTTER_ACTION_COOLDOWN_MS = 320;
const int TOUCH_READ_RETRIES = 3;
const int SHUTTER_TOUCH_RADIUS = 48;
unsigned long lastShutterActionMs = 0;

unsigned long lastPreviewMs = 0;
const unsigned long PREVIEW_INTERVAL_MS = 66; // target about 15 FPS

bool showSplash = true;
unsigned long splashStartMs = 0;
const unsigned long SPLASH_DURATION_MS = 1200;

String statusText = "Starting";

unsigned long photoFlashUntilMs = 0;
unsigned long photoSavedUntilMs = 0;
int lastSavedPhotoId = 0;

const unsigned long PHOTO_FLASH_MS = 140;
const unsigned long PHOTO_SAVED_MS = 900;

unsigned long previewStatsStartMs = 0;
unsigned long previewStatsDrawMs = 0;
unsigned long previewStatsFlushMs = 0;
unsigned int previewStatsFrames = 0;

// ===============================
// Helpers
// ===============================
void setBacklight(uint8_t brightness) {
  pinMode(LCD_BL, OUTPUT);
  digitalWrite(LCD_BL, HIGH);
}

String photoPathFromId(int id) {
  char path[48];
  sprintf(path, "/photos/IMG_%06d.jpg", id);
  return String(path);
}

String videoPathFromId(int id) {
  char path[48];
  sprintf(path, "/videos/VID_%06d.mjpg", id);
  return String(path);
}

String photoFilenameFromId(int id) {
  char name[28];
  sprintf(name, "IMG_%06d.jpg", id);
  return String(name);
}

String videoFilenameFromId(int id) {
  char name[30];
  sprintf(name, "VID_%06d.mjpg", id);
  return String(name);
}

int parseIdFromName(String name, const char *prefix, const char *ext) {
  int start = name.indexOf(prefix);
  int end = name.indexOf(ext);
  if (start < 0 || end < 0 || end <= start + 4) return -1;
  String idString = name.substring(start + 4, end);
  return idString.toInt();
}

bool isInsideCircle(int x, int y, int cx, int cy, int r) {
  int dx = x - cx;
  int dy = y - cy;
  return (dx * dx + dy * dy) <= (r * r);
}

bool isShutterTouch(int x, int y) {
  if (isInsideCircle(x, y, 120, 204, SHUTTER_TOUCH_RADIUS)) {
    return true;
  }

  return x >= 72 && x <= 168 && y >= 172 && y <= 239;
}

// ===============================
// Touch
// ===============================
bool touchIsPressed() {
  return digitalRead(TOUCH_INT) == LOW;
}

bool readTouchOnce(uint8_t *x, uint8_t *y) {
  if (!touchIsPressed()) return false;

  uint8_t data[CHSC6X_READ_POINT_LEN] = {0};

  uint8_t readLen = Wire.requestFrom(
    (uint8_t)CHSC6X_I2C_ID,
    (uint8_t)CHSC6X_READ_POINT_LEN
  );

  if (readLen == CHSC6X_READ_POINT_LEN) {
    Wire.readBytes(data, readLen);

    if (data[0] == 0x01) {
      *x = data[2];
      *y = data[4];
      return true;
    }
  }

  return false;
}

bool readTouch(uint8_t *x, uint8_t *y) {
  for (int attempt = 0; attempt < TOUCH_READ_RETRIES; attempt++) {
    if (!touchIsPressed()) return false;

    if (readTouchOnce(x, y)) {
      return true;
    }

    delay(2);
  }

  return false;
}

// ===============================
// SD
// ===============================
void scanPhotoLibrary() {
  latestPhotoId = 0;

  if (!SD.exists("/photos")) SD.mkdir("/photos");

  File root = SD.open("/photos");
  if (!root || !root.isDirectory()) {
    nextPhotoId = 1;
    return;
  }

  File file = root.openNextFile();
  while (file) {
    if (!file.isDirectory()) {
      int id = parseIdFromName(String(file.name()), "IMG_", ".jpg");
      if (id > latestPhotoId) latestPhotoId = id;
    }
    file.close();
    file = root.openNextFile();
  }

  root.close();
  nextPhotoId = latestPhotoId + 1;
}

void scanVideoLibrary() {
  latestVideoId = 0;

  if (!SD.exists("/videos")) SD.mkdir("/videos");

  File root = SD.open("/videos");
  if (!root || !root.isDirectory()) {
    nextVideoId = 1;
    return;
  }

  File file = root.openNextFile();
  while (file) {
    if (!file.isDirectory()) {
      int id = parseIdFromName(String(file.name()), "VID_", ".mjpg");
      if (id > latestVideoId) latestVideoId = id;
    }
    file.close();
    file = root.openNextFile();
  }

  root.close();
  nextVideoId = latestVideoId + 1;
}

bool setupRoundDisplaySD() {
  Serial.println("Initializing Round Display SD...");

  if (!SD.begin(ROUND_SD_CS)) {
    Serial.println("SD mount failed");
    statusText = "SD failed";
    return false;
  }

  if (SD.cardType() == CARD_NONE) {
    Serial.println("No SD card");
    statusText = "No SD";
    return false;
  }

  Serial.println("SD OK");
  Serial.printf("Card size: %llu MB\n", SD.cardSize() / (1024 * 1024));

  SD.mkdir("/photos");
  SD.mkdir("/videos");

  scanPhotoLibrary();
  scanVideoLibrary();

  statusText = "SD OK";
  return true;
}

// ===============================
// Camera
// ===============================
void flushCameraFrames(int count, int delayMs) {
  for (int i = 0; i < count; i++) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (fb) {
      esp_camera_fb_return(fb);
    }
    delay(delayMs);
  }
}

void applySensorTuning() {
  sensor_t *s = esp_camera_sensor_get();
  if (!s) return;

  s->set_brightness(s, 1);
  s->set_contrast(s, 1);
  s->set_saturation(s, 1);

  s->set_whitebal(s, 1);
  s->set_awb_gain(s, 1);
  s->set_exposure_ctrl(s, 1);
  s->set_gain_ctrl(s, 1);

  s->set_hmirror(s, 0);
  s->set_vflip(s, 0);

  // These are supported in the ESP32 camera sensor API for OV2640.
  s->set_wpc(s, 1);
  s->set_lenc(s, 1);
  s->set_raw_gma(s, 1);
}

void tryFastPreviewClock() {
  sensor_t *s = esp_camera_sensor_get();
  if (!s) return;

  if (s->set_xclk && s->set_xclk(s, LEDC_TIMER_0, CAMERA_FAST_XCLK_MHZ) == 0) {
    Serial.printf("Camera XCLK set to %d MHz\n", CAMERA_FAST_XCLK_MHZ);
  } else {
    Serial.println("Camera fast XCLK not accepted; staying at default clock");
  }
}

bool setupCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;

  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;

  config.pin_xclk  = XCLK_GPIO_NUM;
  config.pin_pclk  = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href  = HREF_GPIO_NUM;

  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;

  config.pin_pwdn  = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;

  config.xclk_freq_hz = CAMERA_INIT_XCLK_HZ;
  config.pixel_format = PIXFORMAT_RGB565;
  config.frame_size   = PREVIEW_FRAME_SIZE;
  config.jpeg_quality = 12;
  config.fb_count     = 2;
  config.fb_location  = CAMERA_FB_IN_PSRAM;
  config.grab_mode    = CAMERA_GRAB_LATEST;

  Serial.println("Initializing camera RGB565 QVGA preview...");
  esp_err_t err = esp_camera_init(&config);

  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    statusText = "Camera fail";
    return false;
  }

  applySensorTuning();
  tryFastPreviewClock();
  flushCameraFrames(2, 50);

  Serial.println("Camera OK");
  statusText = "Camera OK";
  return true;
}

void recordPreviewStats(unsigned long frameStartMs, unsigned long flushStartMs, unsigned long frameEndMs) {
  if (previewStatsStartMs == 0) {
    previewStatsStartMs = frameStartMs;
  }

  previewStatsFrames++;
  previewStatsDrawMs += flushStartMs - frameStartMs;
  previewStatsFlushMs += frameEndMs - flushStartMs;

  unsigned long elapsed = frameEndMs - previewStatsStartMs;
  if (elapsed >= 1000 && previewStatsFrames > 0) {
    float fps = (previewStatsFrames * 1000.0f) / elapsed;
    Serial.printf(
      "Preview FPS: %.1f draw=%lums flush=%lums\n",
      fps,
      previewStatsDrawMs / previewStatsFrames,
      previewStatsFlushMs / previewStatsFrames
    );

    previewStatsStartMs = frameEndMs;
    previewStatsDrawMs = 0;
    previewStatsFlushMs = 0;
    previewStatsFrames = 0;
  }
}

void resetPreviewStats() {
  previewStatsStartMs = 0;
  previewStatsDrawMs = 0;
  previewStatsFlushMs = 0;
  previewStatsFrames = 0;
}

// Draw live preview from camera
void drawLivePreviewToCanvas() {
  if (!cameraOK || isCapturing) return;

  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Preview frame failed");
    return;
  }

  if (fb->format == PIXFORMAT_RGB565 && fb->width >= 240 && fb->height >= 240) {
    uint16_t *pixels = (uint16_t *)fb->buf;
    uint16_t *dst = canvas->getFramebuffer();
    int cropX = (fb->width - 240) / 2;

    if (!dst) {
      Serial.println("Preview framebuffer missing");
      esp_camera_fb_return(fb);
      return;
    }

    for (int y = 0; y < 240; y++) {
      uint16_t *srcLine = pixels + (y * fb->width) + cropX;
      uint16_t *dstLine = dst + (y * 240);

      for (int x = 0; x < 240; x++) {
        uint16_t p = srcLine[x];
        dstLine[x] = (p >> 8) | (p << 8);
      }

      if ((y & 0x0F) == 0) {
        pollTouchDuringDraw();
        yield();
      }
    }
  } else {
    Serial.printf(
      "Bad preview frame: %dx%d format=%d len=%u\n",
      fb->width,
      fb->height,
      fb->format,
      (unsigned)fb->len
    );
  }

  esp_camera_fb_return(fb);
}

// ===============================
// Overlay UI
// ===============================
void drawTextWithShadowDirect(const char *text, int x, int y, uint16_t color) {
  canvas->setTextSize(1);
  canvas->setTextColor(C_BLACK);
  canvas->setCursor(x + 1, y + 1);
  canvas->print(text);

  canvas->setTextColor(color);
  canvas->setCursor(x, y);
  canvas->print(text);
}

void drawModeSwitcherDirect() {
  int y = 166;

  drawTextWithShadowDirect("VIDEO", 39, y, currentMode == 0 ? C_IOS_BLUE : C_WHITE);
  drawTextWithShadowDirect("PHOTO", 166, y, currentMode == 1 ? C_IOS_BLUE : C_WHITE);

  if (currentMode == 0) {
    canvas->fillRoundRect(46, y + 13, 19, 3, 1, C_IOS_BLUE);
  } else {
    canvas->fillRoundRect(174, y + 13, 20, 3, 1, C_IOS_BLUE);
  }
}

void drawShutterDirect() {
  int cx = 120;
  int cy = 204;

  canvas->fillCircle(cx + 1, cy + 2, 31, C_BLACK);

  if (currentMode == 0) {
    canvas->fillCircle(cx, cy, 29, C_WHITE);
    canvas->fillCircle(cx, cy, 23, C_BLACK);

    if (isRecording) {
      canvas->fillRoundRect(cx - 10, cy - 10, 20, 20, 4, C_RED);
    } else {
      canvas->fillCircle(cx, cy, 15, C_RED);
    }
  } else {
    canvas->fillCircle(cx, cy, 30, C_WHITE);
    canvas->fillCircle(cx, cy, 24, C_BLACK);
    canvas->fillCircle(cx, cy, 18, C_WHITE);
  }
}

void drawRecordingDirect() {
  if (isRecording) {
    canvas->fillCircle(120, 38, 5, C_RED);
    canvas->setTextSize(1);
    canvas->setTextColor(C_RED);
    canvas->setCursor(132, 34);
    canvas->print("REC");
  }
}

void drawThickLine(int x0, int y0, int x1, int y1, uint16_t color) {
  canvas->drawLine(x0, y0, x1, y1, color);
  canvas->drawLine(x0 + 1, y0, x1 + 1, y1, color);
  canvas->drawLine(x0 - 1, y0, x1 - 1, y1, color);
  canvas->drawLine(x0, y0 + 1, x1, y1 + 1, color);
  canvas->drawLine(x0, y0 - 1, x1, y1 - 1, color);
}

void drawPhotoFeedback() {
  unsigned long now = millis();

  if (now < photoFlashUntilMs) {
    canvas->fillScreen(C_WHITE);
  }

  if (now < photoSavedUntilMs) {
    int cx = 120;
    int cy = 104;

    canvas->fillCircle(cx + 2, cy + 3, 32, C_BLACK);
    canvas->fillCircle(cx, cy, 30, C_WHITE);

    drawThickLine(cx - 13, cy, cx - 4, cy + 10, C_GREEN);
    drawThickLine(cx - 4, cy + 10, cx + 15, cy - 12, C_GREEN);

    canvas->setTextSize(1);
    canvas->setTextColor(C_WHITE);
    canvas->setCursor(103, 142);
    canvas->print("SAVED");
  }
}

void drawOverlay() {
  drawRecordingDirect();
  drawStickerIconDirect();
  drawModeSwitcherDirect();
  drawShutterDirect();
}

// ===============================
// Save RGB565 frame as JPG
// ===============================
bool writeBufferToSD(const String& path, const uint8_t *data, size_t length, const char *label) {
  if (!data || length == 0) {
    Serial.printf("%s save skipped: empty buffer\n", label);
    if (SD.exists(path)) {
      SD.remove(path);
    }
    return false;
  }

  if (SD.exists(path)) {
    SD.remove(path);
  }

  File file = SD.open(path, FILE_WRITE);
  if (!file) {
    Serial.printf("%s file open failed\n", label);
    return false;
  }

  size_t written = file.write(data, length);
  file.close();

  if (written != length) {
    Serial.printf("%s partial write: %u/%u bytes\n",
                  label, (unsigned)written, (unsigned)length);
    SD.remove(path);
    return false;
  }

  Serial.printf("%s saved: %u bytes\n", label, (unsigned)written);
  return true;
}

bool saveRGB565FrameAsJPGWithQuality(camera_fb_t *fb, String path, int quality) {
  if (!fb || fb->format != PIXFORMAT_RGB565) {
    Serial.println("Unsupported RGB565 frame for JPG save");
    return false;
  }

  uint8_t *jpgBuf = NULL;
  size_t jpgLen = 0;

  bool ok = fmt2jpg(
    fb->buf,
    fb->len,
    fb->width,
    fb->height,
    PIXFORMAT_RGB565,
    quality,
    &jpgBuf,
    &jpgLen
  );

  if (!ok || jpgBuf == NULL || jpgLen == 0) {
    Serial.println("JPG conversion failed");
    if (jpgBuf) free(jpgBuf);
    return false;
  }

  bool saved = writeBufferToSD(path, jpgBuf, jpgLen, "JPG");
  free(jpgBuf);

  if (saved) {
    Serial.printf("JPG details: quality=%d, frame=%dx%d\n", quality, fb->width, fb->height);
  }

  return saved;
}

bool saveRGB565FrameAsJPG(camera_fb_t *fb, String path) {
  return saveRGB565FrameAsJPGWithQuality(fb, path, 92);
}

bool saveNativeJPGFrame(camera_fb_t *fb, String path) {
  if (!fb || fb->format != PIXFORMAT_JPEG || fb->len == 0) {
    Serial.println("Unsupported native JPG frame");
    return false;
  }

  bool saved = writeBufferToSD(path, fb->buf, fb->len, "Native JPG");
  if (saved) {
    Serial.printf("Native JPG details: frame=%dx%d\n", fb->width, fb->height);
  }

  return saved;
}

bool configureCameraSensor(pixformat_t pixelFormat, framesize_t frameSize, int jpegQuality) {
  sensor_t *s = esp_camera_sensor_get();
  if (!s) {
    Serial.println("Camera sensor not available");
    return false;
  }

  bool ok = true;

  if (s->set_pixformat(s, pixelFormat) != 0) {
    Serial.println("set_pixformat failed");
    ok = false;
  }
  delay(80);

  if (s->set_framesize(s, frameSize) != 0) {
    Serial.println("set_framesize failed");
    ok = false;
  }
  delay(80);

  if (pixelFormat == PIXFORMAT_JPEG && s->set_quality(s, jpegQuality) != 0) {
    Serial.println("set_quality failed");
    ok = false;
  }
  delay(120);

  return ok;
}

void restorePreviewCameraMode() {
  Serial.println("Restoring fast RGB565 preview...");

  configureCameraSensor(PIXFORMAT_RGB565, PREVIEW_FRAME_SIZE, 12);
  applySensorTuning();
  flushCameraFrames(2, 50);
}

bool enterPhotoCaptureFrameSize(bool *didSwitch) {
  *didSwitch = false;

  if ((int)PHOTO_CAPTURE_FRAME_SIZE == (int)PREVIEW_FRAME_SIZE) {
    flushCameraFrames(1, 35);
    return true;
  }

  Serial.println("Switching to regular photo size...");

  if (!configureCameraSensor(PIXFORMAT_RGB565, PHOTO_CAPTURE_FRAME_SIZE, 12)) {
    Serial.println("Photo size switch failed; staying in preview size");
    restorePreviewCameraMode();
    return false;
  }

  applySensorTuning();
  flushCameraFrames(2, 40);
  *didSwitch = true;
  return true;
}

bool captureNativeJPGPhoto(String path, framesize_t frameSize, const char *label) {
  Serial.print("Trying native JPG photo ");
  Serial.println(label);

  if (!configureCameraSensor(PIXFORMAT_JPEG, frameSize, HQ_PHOTO_JPEG_QUALITY)) {
    return false;
  }

  flushCameraFrames(2, 90);

  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Native JPG capture failed");
    return false;
  }

  bool ok = saveNativeJPGFrame(fb, path);
  esp_camera_fb_return(fb);

  return ok;
}

// ===============================
// Safe regular photo capture
// ===============================
// This is intentionally NOT high-res reinit.
// The high-res reinit was causing board restart in gray-heart mode.
// This version saves the current stable RGB565 preview frame without camera reinit.
bool captureRegularFullFramePhoto(String path) {
  Serial.println("Safe regular photo capture...");

  bool didSwitch = false;
  bool photoSizeReady = enterPhotoCaptureFrameSize(&didSwitch);

  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Regular capture failed");
    if (didSwitch || !photoSizeReady) {
      restorePreviewCameraMode();
    }
    return false;
  }

  bool ok = saveRGB565FrameAsJPGWithQuality(fb, path, 95);
  esp_camera_fb_return(fb);

  if (didSwitch) {
    restorePreviewCameraMode();
  }

  return ok;
}

bool captureRegularHighQualityPhoto(String path) {
  statusText = "HQ photo";

  bool ok = captureNativeJPGPhoto(path, HQ_PHOTO_FRAME_SIZE, "primary");

  if (!ok) {
    Serial.println("Primary HQ failed; trying fallback");
    ok = captureNativeJPGPhoto(path, HQ_PHOTO_FALLBACK_FRAME_SIZE, "fallback");
  }

  restorePreviewCameraMode();

  if (ok) {
    return true;
  }

  Serial.println("Native JPG photo failed; falling back to safe QVGA");
  statusText = "Safe photo";
  return captureRegularFullFramePhoto(path);
}

bool captureRegularBestPhoto(String path) {
#if ENABLE_EXPERIMENTAL_HQ_PHOTO
  return captureRegularHighQualityPhoto(path);
#else
  statusText = "Safe photo";
  return captureRegularFullFramePhoto(path);
#endif
}

// ===============================
// Photo capture
// ===============================
bool captureAndSavePhoto() {
  if (!sdOK || !cameraOK || isCapturing || isRecording) {
    statusText = "Not ready";
    return false;
  }

  isCapturing = true;
  statusText = "Capturing";

  int id = nextPhotoId;
  String path = photoPathFromId(id);

  Serial.print("Photo -> ");
  Serial.println(path);

  bool ok = false;

  if (isStickerModeEnabled()) {
    // Cute color modes: keep preview fast, but capture/save a regular photo size.
    bool didSwitch = false;
    bool photoSizeReady = enterPhotoCaptureFrameSize(&didSwitch);
    camera_fb_t *fb = esp_camera_fb_get();

    if (!fb) {
      Serial.println("Layout capture failed");
      statusText = "Capture fail";
      isCapturing = false;
      if (didSwitch || !photoSizeReady) {
        restorePreviewCameraMode();
      }
      return false;
    }

    ok = saveStickerJPG(fb, path);
    esp_camera_fb_return(fb);

    if (didSwitch) {
      restorePreviewCameraMode();
    }

  } else {
    // Gray-heart regular mode:
    // stable full-frame photo without switching camera modes at shutter time.
    ok = captureRegularBestPhoto(path);
  }

  if (!ok) {
    statusText = "Save fail";
    isCapturing = false;
    return false;
  }

  latestPhotoId = id;
  nextPhotoId = id + 1;

  statusText = "Photo saved";
  isCapturing = false;
  resetPreviewStats();

  lastSavedPhotoId = id;
  photoFlashUntilMs = millis() + PHOTO_FLASH_MS;
  photoSavedUntilMs = millis() + PHOTO_SAVED_MS;

  Serial.println("Photo saved");
  return true;
}

// ===============================
// Video MJPEG
// ===============================
bool startVideoRecording() {
  if (!sdOK || !cameraOK || isCapturing || isRecording) {
    statusText = "Not ready";
    return false;
  }

  int id = nextVideoId;
  String path = videoPathFromId(id);

  if (SD.exists(path)) {
    SD.remove(path);
  }

  videoFile = SD.open(path, FILE_WRITE);
  if (!videoFile) {
    statusText = "Video fail";
    return false;
  }

  currentVideoId = id;
  videoFrameCount = 0;
  videoFrameFailCount = 0;
  videoStartMs = millis();
  lastVideoFrameMs = videoStartMs;
  isRecording = true;
  statusText = "REC";

  Serial.print("Video started -> ");
  Serial.println(path);

  return true;
}

bool recordOneVideoFrame() {
  if (!isRecording || !videoFile) return false;

  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) return false;

  uint8_t *jpgBuf = NULL;
  size_t jpgLen = 0;

  bool ok = encodeStickerFrameJPG(fb, &jpgBuf, &jpgLen, isStickerModeEnabled() ? 86 : 88);

  esp_camera_fb_return(fb);

  if (!ok || jpgBuf == NULL || jpgLen == 0) {
    if (jpgBuf) free(jpgBuf);
    return false;
  }

  size_t written = videoFile.write(jpgBuf, jpgLen);
  free(jpgBuf);

  if (written != jpgLen) {
    Serial.printf("Video frame write failed: %u/%u bytes\n", (unsigned)written, (unsigned)jpgLen);
    return false;
  }

  videoFrameCount++;

  if (videoFrameCount % 5 == 0) {
    videoFile.flush();
  }

  return true;
}

bool stopVideoRecording() {
  if (!isRecording) return false;

  int savedVideoId = currentVideoId;
  int savedFrameCount = videoFrameCount;
  String path = savedVideoId > 0 ? videoPathFromId(savedVideoId) : "";

  if (videoFile) {
    videoFile.flush();
    videoFile.close();
  }

  isRecording = false;
  currentVideoId = 0;
  videoFrameCount = 0;
  videoFrameFailCount = 0;
  videoStartMs = 0;
  lastVideoFrameMs = 0;

  size_t savedSize = 0;
  if (savedVideoId > 0 && path.length() > 0 && SD.exists(path)) {
    File saved = SD.open(path, FILE_READ);
    if (saved) {
      savedSize = saved.size();
      saved.close();
    }
  }

  if (savedVideoId > 0 && savedFrameCount > 0 && savedSize > 0) {
    latestVideoId = savedVideoId;
    nextVideoId = savedVideoId + 1;
    statusText = "Video saved";

    Serial.printf("Video saved id=%d frames=%d bytes=%u\n",
                  savedVideoId, savedFrameCount, (unsigned)savedSize);
    return true;
  }

  if (savedVideoId > 0 && path.length() > 0 && SD.exists(path)) {
    SD.remove(path);
  }

  statusText = savedFrameCount > 0 ? "Video fail" : "Video empty";
  Serial.printf("Video discarded id=%d frames=%d bytes=%u\n",
                savedVideoId, savedFrameCount, (unsigned)savedSize);

  return false;
}

void updateVideoRecording() {
  if (!isRecording) return;

  unsigned long now = millis();

  if (now - videoStartMs > MAX_VIDEO_MS) {
    stopVideoRecording();
    return;
  }

  if (now - lastVideoFrameMs >= VIDEO_FRAME_INTERVAL_MS) {
    lastVideoFrameMs = now;
    if (recordOneVideoFrame()) {
      videoFrameFailCount = 0;
    } else {
      videoFrameFailCount++;
      if (videoFrameFailCount >= 5) {
        Serial.println("Too many video frame failures; stopping");
        stopVideoRecording();
      }
    }
  }
}

// ===============================
// Wi-Fi API
// ===============================
void addCorsHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
  server.sendHeader("Cache-Control", "no-store");
}

void sendPlain(int code, const String& text) {
  addCorsHeaders();
  server.send(code, "text/plain", text);
}

void sendJSON(int code, const String& json) {
  addCorsHeaders();
  server.send(code, "application/json", json);
}

void sendFileFromSD(String path, const char *mime) {
  if (!SD.exists(path)) {
    sendPlain(404, "Not found");
    return;
  }

  File file = SD.open(path, FILE_READ);
  if (!file) {
    sendPlain(500, "Open failed");
    return;
  }

  addCorsHeaders();
  server.streamFile(file, mime);
  file.close();
}

void handleRoot() {
  String html = "<html><body><h1>PocketCam</h1>"
                "<a href='/status.json'>Status</a><br>"
                "<a href='/capture'>Capture</a><br>"
                "<a href='/photos.json'>Photos</a><br>"
                "<a href='/videos.json'>Videos</a><br>"
                "<a href='/latest'>Latest</a><br>"
                "<a href='/video/start'>Start video</a><br>"
                "<a href='/video/stop'>Stop video</a><br>"
                "</body></html>";
  addCorsHeaders();
  server.send(200, "text/html", html);
}

void handleStatus() {
  String json = "{";
  json += "\"ready\":" + String(sdOK && cameraOK ? "true" : "false") + ",";
  json += "\"sd_ok\":" + String(sdOK ? "true" : "false") + ",";
  json += "\"camera_ok\":" + String(cameraOK ? "true" : "false") + ",";
  json += "\"recording\":" + String(isRecording ? "true" : "false") + ",";
  json += "\"latest_id\":" + String(latestPhotoId) + ",";
  json += "\"next_id\":" + String(nextPhotoId) + ",";
  json += "\"latest_video_id\":" + String(latestVideoId) + ",";
  json += "\"next_video_id\":" + String(nextVideoId);
  json += "}";
  sendJSON(200, json);
}

void handleCaptureAPI() {
  bool ok = captureAndSavePhoto();
  if (!ok) {
    sendJSON(500, "{\"ok\":false}");
    return;
  }

  String json = "{";
  json += "\"ok\":true,";
  json += "\"id\":" + String(latestPhotoId) + ",";
  json += "\"filename\":\"" + photoFilenameFromId(latestPhotoId) + "\",";
  json += "\"url\":\"/photo?id=" + String(latestPhotoId) + "\"";
  json += "}";
  sendJSON(200, json);
}

int apiLimitArg(int fallback) {
  if (!server.hasArg("limit")) return fallback;

  int limit = server.arg("limit").toInt();
  if (limit < 1) return fallback;
  if (limit > API_MAX_LIMIT) return API_MAX_LIMIT;
  return limit;
}

void handlePhotosJson() {
  int since = 0;
  if (server.hasArg("since")) {
    since = server.arg("since").toInt();
  }

  int limit = apiLimitArg(API_DEFAULT_LIMIT);
  bool latestOnly = server.hasArg("latest") && server.arg("latest") == "1";
  bool reverseScan = latestOnly && since == 0;
  int emitted = 0;

  String json = "[";
  if (limit > 0) {
    json.reserve(limit * 92 + 2);
  }

  bool first = true;

  int startId = reverseScan ? latestPhotoId : since + 1;
  int endId = reverseScan ? 1 : latestPhotoId;
  int step = reverseScan ? -1 : 1;

  for (int id = startId; reverseScan ? id >= endId : id <= endId; id += step) {
    String path = photoPathFromId(id);
    if (!SD.exists(path)) continue;

    File file = SD.open(path, FILE_READ);
    size_t size = file ? file.size() : 0;
    if (file) file.close();

    if (size == 0) continue;

    if (!first) json += ",";
    first = false;

    json += "{";
    json += "\"id\":" + String(id) + ",";
    json += "\"filename\":\"" + photoFilenameFromId(id) + "\",";
    json += "\"size\":" + String(size) + ",";
    json += "\"url\":\"/photo?id=" + String(id) + "\"";
    json += "}";

    emitted++;
    if (limit > 0 && emitted >= limit) break;
  }

  json += "]";
  sendJSON(200, json);
}

void handlePhotoById() {
  if (!server.hasArg("id")) {
    sendPlain(400, "Missing id");
    return;
  }

  int id = server.arg("id").toInt();
  sendFileFromSD(photoPathFromId(id), "image/jpeg");
}

void handleLatest() {
  if (latestPhotoId <= 0) {
    sendPlain(404, "No photo");
    return;
  }

  sendFileFromSD(photoPathFromId(latestPhotoId), "image/jpeg");
}

void handleVideosJson() {
  int since = 0;
  if (server.hasArg("since")) {
    since = server.arg("since").toInt();
  }

  int limit = apiLimitArg(API_DEFAULT_LIMIT);
  int emitted = 0;

  String json = "[";
  if (limit > 0) {
    json.reserve(limit * 96 + 2);
  }

  bool first = true;

  for (int id = since + 1; id <= latestVideoId; id++) {
    String path = videoPathFromId(id);
    if (!SD.exists(path)) continue;

    File file = SD.open(path, FILE_READ);
    size_t size = file ? file.size() : 0;
    if (file) file.close();

    if (size == 0) continue;

    if (!first) json += ",";
    first = false;

    json += "{";
    json += "\"id\":" + String(id) + ",";
    json += "\"filename\":\"" + videoFilenameFromId(id) + "\",";
    json += "\"size\":" + String(size) + ",";
    json += "\"url\":\"/video?id=" + String(id) + "\"";
    json += "}";

    emitted++;
    if (limit > 0 && emitted >= limit) break;
  }

  json += "]";
  sendJSON(200, json);
}

void handleVideoById() {
  if (!server.hasArg("id")) {
    sendPlain(400, "Missing id");
    return;
  }

  int id = server.arg("id").toInt();
  sendFileFromSD(videoPathFromId(id), "video/x-motion-jpeg");
}

void handleVideoStart() {
  if (startVideoRecording()) sendPlain(200, "Video started");
  else sendPlain(500, "Video start failed");
}

void handleVideoStop() {
  bool wasRecording = isRecording;
  if (stopVideoRecording()) sendPlain(200, "Video saved");
  else {
    String message = wasRecording ? statusText : String("No recording");
    sendPlain(500, message);
  }
}

bool setupCreatorCamAP() {
  WiFi.disconnect(true, true);
  delay(200);

  WiFi.mode(WIFI_AP);
  WiFi.setSleep(false);

  if (!WiFi.softAPConfig(AP_IP, AP_GATEWAY, AP_SUBNET)) return false;
  if (!WiFi.softAP(AP_SSID, AP_PASSWORD, 6, false, 4)) return false;

  Serial.println("Wi-Fi started");
  Serial.println(WiFi.softAPIP());
  return true;
}

void setupRoutes() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/status.json", HTTP_GET, handleStatus);
  server.on("/capture", HTTP_GET, handleCaptureAPI);
  server.on("/photos.json", HTTP_GET, handlePhotosJson);
  server.on("/photo", HTTP_GET, handlePhotoById);
  server.on("/latest", HTTP_GET, handleLatest);

  server.on("/videos.json", HTTP_GET, handleVideosJson);
  server.on("/video", HTTP_GET, handleVideoById);
  server.on("/video/start", HTTP_GET, handleVideoStart);
  server.on("/video/stop", HTTP_GET, handleVideoStop);

  server.begin();
}

// ===============================
// Touch actions
// ===============================
void setMode(int mode) {
  if (currentMode == mode) return;
  if (isRecording) stopVideoRecording();

  currentMode = mode;
  statusText = currentMode == 0 ? "Video" : "Photo";
}

void handleShutter() {
  unsigned long now = millis();
  if (now - lastShutterActionMs < SHUTTER_ACTION_COOLDOWN_MS) {
    return;
  }

  lastShutterActionMs = now;

  if (currentMode == 1) {
    captureAndSavePhoto();
  } else {
    if (isRecording) stopVideoRecording();
    else startVideoRecording();
  }

  lastPreviewMs = 0;
}

void handleTouchTap(uint8_t x, uint8_t y) {
  if (tryHandleStickerTouch(x, y)) {
    return;
  }

  if (x >= 20 && x <= 105 && y >= 145 && y <= 190) {
    setMode(0);
    return;
  }

  if (x >= 140 && x <= 230 && y >= 145 && y <= 190) {
    setMode(1);
    return;
  }

  if (isShutterTouch(x, y)) {
    handleShutter();
    return;
  }
}

void updateTouch() {
  if (pendingTouchTap) {
    uint8_t x = pendingTouchX;
    uint8_t y = pendingTouchY;

    pendingTouchTap = false;
    handleTouchTap(x, y);
    return;
  }

  uint8_t x = 0;
  uint8_t y = 0;

  bool touching = readTouch(&x, &y);

  if (touching && !wasTouching && millis() - lastTouchMs > TOUCH_TAP_DEBOUNCE_MS) {
    handleTouchTap(x, y);
    lastTouchMs = millis();
  }

  wasTouching = touching;
}

void pollTouchDuringDraw() {
  unsigned long now = millis();

  if (now - lastTouchPollMs < TOUCH_POLL_DURING_DRAW_MS) {
    return;
  }

  lastTouchPollMs = now;

  uint8_t x = 0;
  uint8_t y = 0;

  bool touching = readTouch(&x, &y);

  if (touching && !wasTouching && !pendingTouchTap && now - lastTouchMs > TOUCH_TAP_DEBOUNCE_MS) {
    pendingTouchX = x;
    pendingTouchY = y;
    pendingTouchTap = true;
    lastTouchMs = now;
  }

  wasTouching = touching;
}

// ===============================
// Splash
// ===============================
void drawSplash() {
  canvas->fillScreen(C_BLACK);
  canvas->drawCircle(120, 86, 31, C_WHITE);
  canvas->drawCircle(120, 86, 19, C_GRAY);
  canvas->fillCircle(120, 86, 7, C_IOS_BLUE);

  canvas->setTextSize(2);
  canvas->setTextColor(C_WHITE);
  canvas->setCursor(34, 136);
  canvas->print("PocketCam");

  canvas->flush();
}

// ===============================
// Setup / loop
// ===============================
void setup() {
  Serial.begin(115200);
  delay(2000);

  Serial.println("Creator Cam Safe Quality v1");

  pinMode(TOUCH_INT, INPUT_PULLUP);
  Wire.begin();

  setBacklight(150);

  if (!gfx->begin(SPI_SPEED)) {
    Serial.println("Display failed");
    return;
  }

  canvas->begin();
  drawSplash();

  sdOK = setupRoundDisplaySD();
  cameraOK = setupCamera();

  setupCreatorCamAP();
  setupRoutes();

  statusText = (sdOK && cameraOK) ? "Ready" : "Check";
  splashStartMs = millis();

  Serial.println("Setup done");
}

void loop() {
  unsigned long now = millis();

  server.handleClient();
  updateTouch();
  updateVideoRecording();
  if (isRecording || pendingTouchTap) {
    updateTouch();
  }

  if (showSplash && now - splashStartMs > SPLASH_DURATION_MS) {
    showSplash = false;
  }

  if (!showSplash && !isCapturing && now - lastPreviewMs >= PREVIEW_INTERVAL_MS) {
    lastPreviewMs = now;
    unsigned long frameStartMs = millis();

    if (isStickerModeEnabled()) {
      drawStickerPreviewToCanvas();
    } else {
      drawLivePreviewToCanvas();
    }

    updateTouch();

    drawOverlay();
    drawPhotoFeedback();

    unsigned long flushStartMs = millis();
    canvas->flush();
    unsigned long frameEndMs = millis();
    recordPreviewStats(frameStartMs, flushStartMs, frameEndMs);
  }

  delay(1);
}
