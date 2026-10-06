/**
 * ============================================================================
 *  SaliSense — ESP32 Production Firmware  v2.0
 * ============================================================================
 *
 *  Automated Salinity Monitoring and Controlled Balancing System
 *  for Enclosed Fishponds (Capstone 2)
 *
 *  Hardware (per Hardwares.txt):
 *    • ESP32 DevKit C V4 (38-pin)
 *    • DFRobot Gravity Analog EC Sensor K=1 (DFR0300 V2)
 *    • DS18B20 Waterproof Temperature Probe
 *    • 2-Channel 5V Relay Module (active-LOW, SRD-05VDC-SL-C style)
 *    • 2× Vertical Float Switches (passive dry-contact, NO)
 *    • 2× 5V DC Submersible Pumps (freshwater + saltwater)
 *    • 5V 3A Regulated DC Adapter
 *
 *  Firebase RTDB paths (must match Flutter app constants.dart):
 *    devices/{DEVICE_CODE}/sensor/current_ppt   ← live reading
 *    devices/{DEVICE_CODE}/logs/salinity         ← history (push)
 *    devices/{DEVICE_CODE}/system/active_preset  ← preset info
 *    devices/{DEVICE_CODE}/system/status         ← pump/sensor state
 *    devices/{DEVICE_CODE}/alerts/active         ← current alerts
 *    devices/{DEVICE_CODE}/logs/alerts           ← alert history
 *    devices/{DEVICE_CODE}/info                  ← device metadata
 *
 *  Dependencies (Arduino Library Manager):
 *    1. DFRobot_EC        — EC sensor calibration & reading
 *    2. OneWire            — 1-Wire protocol
 *    3. DallasTemperature  — DS18B20 driver
 *    4. Firebase ESP Client (by Mobizt)
 *    5. ArduinoJson (v7+)
 *
 *  Serial commands (for calibration):
 *    Type "enterec" in Serial Monitor → enter EC calibration mode
 *    Submerge probe in 1413μS/cm solution → type "calec"
 *    Or in 12.88mS/cm solution → type "calec"
 *    Type "exitec" to save & exit calibration
 *
 *  Authors: SaliSense Group 2, BSIT 3C
 * ============================================================================
 */

#include <Arduino.h>
#include <WiFi.h>
#include <EEPROM.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Firebase_ESP_Client.h>
#include <ArduinoJson.h>
#include <time.h>

// Firebase helper addons (bundled with Firebase_ESP_Client)
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// DFRobot EC sensor library
#include "DFRobot_EC.h"

// ============================================================================
//  USER CONFIGURATION — CHANGE THESE BEFORE UPLOADING
// ============================================================================

// WiFi credentials (hardcoded per capstone demo)
#define WIFI_SSID          "YOUR_WIFI_SSID"
#define WIFI_PASSWORD      "YOUR_WIFI_PASSWORD"

// Firebase project
#define FIREBASE_API_KEY       "AIzaSyAR5DKFVEXa0v-T-IxTy9-O_Do3NyP0cXw"
#define FIREBASE_DATABASE_URL  "https://salisense-default-rtdb.asia-southeast1.firebasedatabase.app"

// Dedicated device account (separate from the app account per PRD §6)
#define DEVICE_EMAIL       "device@salisense.com"
#define DEVICE_PASSWORD    "YOUR_DEVICE_PASSWORD"

// Unique device identifier — matches what the Flutter app registers
#define DEVICE_CODE        "ESP32-A1B2C3"

// ============================================================================
//  GPIO PIN MAPPING — ESP32 DevKit C V4 (38-pin)
// ============================================================================

// Analog input — EC sensor analog output
#define PIN_EC_SENSOR      34   // ADC1_CH6 (input-only pin, safe for analog)

// Digital — DS18B20 data line (needs 4.7kΩ pull-up to 3.3V)
#define PIN_TEMP_SENSOR    4    // GPIO4

// Digital outputs — Relay module IN1 / IN2 (active-LOW)
#define PIN_RELAY_FW       26   // Freshwater pump relay
#define PIN_RELAY_SW       27   // Saltwater pump relay

// Digital inputs — Float switches (NO, wired between GPIO and GND)
// Uses internal pull-up: HIGH = reservoir OK, LOW = reservoir empty
#define PIN_FLOAT_FW       14   // Freshwater reservoir float
#define PIN_FLOAT_SW       25   // Saltwater reservoir float
// NOTE: GPIO25 used instead of GPIO12 to avoid ESP32 boot failure
// (GPIO12 is a strapping pin — pulling it HIGH at boot forces flash
//  voltage to 1.8V, causing boot loop)

// ============================================================================
//  SYSTEM CONSTANTS (from PRD)
// ============================================================================

// Control loop timing
#define CONTROL_INTERVAL_MS     5000    // 5-second control cycle
#define LOG_INTERVAL_MS         30000   // 30-second Firebase log push (FT-07)
#define DEFAULT_PUMP_TIMEOUT_MS 24000   // Default pump fault timeout (overridden by Firebase)
#define SENSOR_FAULT_DELAY_MS   10000   // 10s max sensor-fault-to-app latency (FT-06)

// EC sensor calibration constant
#define EC_K_VALUE              1.0     // DFRobot probe K=1

// Salinity conversion factor
// Rule of thumb: 1 mS/cm ≈ 0.55 ppt at ~25°C for brackish water
#define EC_TO_PPT_FACTOR        0.55

// Tilapia grow-out preset (hardcoded per PRD §5.2 — no remote config)
#define PRESET_NAME             "Tilapia Grow-out"
#define PRESET_MIN_PPT          0.0
#define PRESET_MAX_PPT          7.0

// ADC filtering
#define ADC_SAMPLES             30      // Number of ADC samples to average
#define ADC_SAMPLE_DELAY_MS     10      // Delay between samples

// ============================================================================
//  GLOBAL OBJECTS
// ============================================================================

// Firebase
FirebaseData fbdo;
FirebaseData streamFbdo;              // Dedicated stream for settings updates
FirebaseAuth firebaseAuth;
FirebaseConfig firebaseConfig;
bool firebaseReady = false;

// Dynamic pump timeout — fetched from Firebase, defaults to 24s
unsigned long pumpTimeoutMs = DEFAULT_PUMP_TIMEOUT_MS;

// Temperature sensor
OneWire oneWire(PIN_TEMP_SENSOR);
DallasTemperature tempSensor(&oneWire);

// EC sensor (DFRobot library — handles calibration via EEPROM)
DFRobot_EC ecSensor;

// ============================================================================
//  OPERATIONAL STATE
// ============================================================================

// Sensor readings
float currentPpt       = 0.0;
float currentTempC     = 25.0;
float currentVoltage   = 0.0;   // EC sensor voltage in mV

// Pump state
bool isFwPumpActive    = false;
bool isSwPumpActive    = false;

// Fault flags (PRD §9)
bool faultSensor           = false;
bool faultPump             = false;
bool faultLowReservoirFW   = false;
bool faultLowReservoirSW   = false;
bool faultOvercorrection   = false;

// Tracking
unsigned long lastControlTime   = 0;
unsigned long lastLogTime       = 0;
unsigned long pumpStartTime     = 0;
float salinityAtPumpStart       = 0.0;
String lastCorrectionDirection  = "";   // "UP" or "DOWN"
bool presetWritten              = false;
bool deviceInfoWritten          = false;

// Serial calibration buffer
char serialBuffer[32];
int serialIndex = 0;

// ============================================================================
//  FORWARD DECLARATIONS
// ============================================================================

void initHardware();
void connectWiFi();
void initFirebase();
void syncNTP();
float readTemperature();
float readSalinityPPT();
void evaluateControlLogic();
void executePumpControl();
void pushLiveData();
void pushLogEntry();
void pushPresetOnce();
void pushDeviceInfoOnce();
void triggerAlert(const char* type, const char* message);
void clearActiveAlerts();
unsigned long getEpochMs();
void handleSerialCalibration();
void fetchAndStreamSettings();

// ============================================================================
//  SETUP
// ============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println(F(""));
  Serial.println(F("========================================="));
  Serial.println(F("  SaliSense ESP32 Firmware v2.0"));
  Serial.println(F("  Production Build"));
  Serial.println(F("========================================="));

  initHardware();
  connectWiFi();
  syncNTP();
  initFirebase();
  fetchAndStreamSettings();

  Serial.println(F("[READY] System operational."));
  Serial.printf("[READY] Control cycle: 5s | Log push: 30s | Pump timeout: %lus\n", pumpTimeoutMs / 1000);
  Serial.println(F("[CAL]   Type 'enterec' in Serial Monitor to calibrate EC sensor."));
  Serial.println(F(""));
}

// ============================================================================
//  LOOP
// ============================================================================

void loop() {
  unsigned long now = millis();

  // ---- Handle serial input for EC calibration ----
  handleSerialCalibration();

  // ---- 5-second control cycle ----
  if (now - lastControlTime >= CONTROL_INTERVAL_MS) {
    lastControlTime = now;

    // 1. Read sensors
    currentTempC = readTemperature();
    currentPpt   = readSalinityPPT();

    // 2. Evaluate faults and control logic
    evaluateControlLogic();

    // 3. Execute pump outputs
    executePumpControl();

    // 4. Push live data to Firebase (every control cycle)
    pushLiveData();

    // 5. One-time writes
    pushPresetOnce();
    pushDeviceInfoOnce();

    // Debug output
    Serial.println(F("─────────────────────────────────────"));
    Serial.printf("[DATA] PPT: %.2f | Temp: %.1f°C | V: %.1fmV\n",
                  currentPpt, currentTempC, currentVoltage);
    Serial.printf("[PUMP] FW: %s | SW: %s\n",
                  isFwPumpActive ? "ON" : "off",
                  isSwPumpActive ? "ON" : "off");
    Serial.printf("[FAULT] Sensor:%d Pump:%d ResFW:%d ResSW:%d Over:%d\n",
                  faultSensor, faultPump, faultLowReservoirFW,
                  faultLowReservoirSW, faultOvercorrection);
    Serial.println(F("─────────────────────────────────────"));
  }

  // ---- 30-second log push (FT-07) ----
  if (now - lastLogTime >= LOG_INTERVAL_MS) {
    lastLogTime = now;
    pushLogEntry();
  }

  // Keep Firebase token alive
  if (Firebase.ready()) {
    // Firebase ESP Client handles token refresh internally
  }

  // ---- Check for settings updates from Firebase stream ----
  if (Firebase.RTDB.readStream(&streamFbdo)) {
    if (streamFbdo.streamAvailable()) {
      int timeoutSec = streamFbdo.intData();
      if (timeoutSec > 0) {
        pumpTimeoutMs = (unsigned long)timeoutSec * 1000UL;
        Serial.printf("[SETTINGS] Pump timeout updated: %d seconds (%.1f min)\n",
                      timeoutSec, timeoutSec / 60.0);
      }
    }
  }

  delay(10);  // Yield to RTOS / prevent WDT
}

// ============================================================================
//  HARDWARE INIT
// ============================================================================

void initHardware() {
  // Relay outputs — start with pumps OFF (HIGH = off for active-LOW relay)
  pinMode(PIN_RELAY_FW, OUTPUT);
  pinMode(PIN_RELAY_SW, OUTPUT);
  digitalWrite(PIN_RELAY_FW, HIGH);
  digitalWrite(PIN_RELAY_SW, HIGH);

  // Float switch inputs — internal pull-up (HIGH = OK, LOW = empty)
  pinMode(PIN_FLOAT_FW, INPUT_PULLUP);
  pinMode(PIN_FLOAT_SW, INPUT_PULLUP);

  // DS18B20
  tempSensor.begin();
  tempSensor.setResolution(12);          // 12-bit = 0.0625°C resolution
  tempSensor.setWaitForConversion(true); // Blocking read (~750ms at 12-bit)

  // DFRobot EC sensor — reads calibration data from EEPROM
  ecSensor.begin();

  Serial.println(F("[HW] Hardware initialized."));
  Serial.printf("[HW] DS18B20 devices found: %d\n", tempSensor.getDeviceCount());
}

// ============================================================================
//  WIFI
// ============================================================================

void connectWiFi() {
  Serial.printf("[WIFI] Connecting to %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WIFI] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println(F("\n[WIFI] FAILED! Restarting in 5s..."));
    delay(5000);
    ESP.restart();
  }
}

// ============================================================================
//  NTP TIME SYNC
// ============================================================================

void syncNTP() {
  // UTC+8 for Philippines (no DST)
  configTime(28800, 0, "pool.ntp.org", "time.nist.gov");
  Serial.print(F("[TIME] Syncing NTP..."));

  struct tm timeinfo;
  int retries = 0;
  while (!getLocalTime(&timeinfo) && retries < 20) {
    Serial.print(".");
    delay(500);
    retries++;
  }

  if (retries < 20) {
    Serial.printf(" OK! %s", asctime(&timeinfo));
  } else {
    Serial.println(F(" WARN: NTP sync failed — timestamps may be epoch 0."));
  }
}

// ============================================================================
//  FIREBASE INIT
// ============================================================================

void initFirebase() {
  firebaseConfig.api_key = FIREBASE_API_KEY;
  firebaseConfig.database_url = FIREBASE_DATABASE_URL;

  // Device account (separate from app account per PRD §6)
  firebaseAuth.user.email = DEVICE_EMAIL;
  firebaseAuth.user.password = DEVICE_PASSWORD;

  // Token status callback for debug
  firebaseConfig.token_status_callback = tokenStatusCallback;

  Firebase.begin(&firebaseConfig, &firebaseAuth);
  Firebase.reconnectWiFi(true);

  // Wait for initial auth
  Serial.print(F("[FB] Authenticating..."));
  unsigned long authStart = millis();
  while (!Firebase.ready() && millis() - authStart < 15000) {
    delay(100);
  }

  if (Firebase.ready()) {
    firebaseReady = true;
    Serial.println(F(" OK!"));
  } else {
    Serial.println(F(" WARN: Firebase not ready yet — will retry in loop."));
  }
}

// ============================================================================
//  FIREBASE — FETCH & STREAM SETTINGS
// ============================================================================

void fetchAndStreamSettings() {
  if (!Firebase.ready()) return;

  String path = String("devices/") + DEVICE_CODE + "/settings/pump_timeout";

  // 1. Initial fetch of current value
  if (Firebase.RTDB.getInt(&fbdo, path)) {
    int timeoutSec = fbdo.intData();
    if (timeoutSec > 0) {
      pumpTimeoutMs = (unsigned long)timeoutSec * 1000UL;
      Serial.printf("[SETTINGS] Pump timeout loaded: %d seconds (%.1f min)\n",
                    timeoutSec, timeoutSec / 60.0);
    } else {
      Serial.printf("[SETTINGS] No valid pump timeout — using default: %lus\n",
                    pumpTimeoutMs / 1000);
    }
  } else {
    Serial.printf("[SETTINGS] Could not fetch pump timeout — using default: %lus\n",
                  pumpTimeoutMs / 1000);
  }

  // 2. Start real-time stream listener for live updates from the app
  if (Firebase.RTDB.beginStream(&streamFbdo, path)) {
    Serial.println(F("[SETTINGS] Stream listener active for pump_timeout."));
  } else {
    Serial.printf("[SETTINGS] Stream setup failed: %s\n",
                  streamFbdo.errorReason().c_str());
  }
}

// ============================================================================
//  SENSOR READING — TEMPERATURE
// ============================================================================

float readTemperature() {
  tempSensor.requestTemperatures();
  float t = tempSensor.getTempCByIndex(0);

  // DS18B20 returns DEVICE_DISCONNECTED_C (-127.0) if not found
  if (t == DEVICE_DISCONNECTED_C || t < -10.0 || t > 60.0) {
    Serial.println(F("[SENSOR] DS18B20 read error — using last known temp."));
    return currentTempC;  // Keep previous value
  }

  return t;
}

// ============================================================================
//  SENSOR READING — SALINITY (EC → PPT)
// ============================================================================

float readSalinityPPT() {
  // Multi-sample ADC averaging for noise reduction
  long adcSum = 0;
  for (int i = 0; i < ADC_SAMPLES; i++) {
    adcSum += analogRead(PIN_EC_SENSOR);
    delay(ADC_SAMPLE_DELAY_MS);
  }
  float avgAdc = (float)adcSum / ADC_SAMPLES;

  // Convert ADC to voltage (ESP32: 12-bit, 0–3.3V)
  currentVoltage = avgAdc / 4095.0 * 3300.0;  // millivolts

  // Use DFRobot library for temperature-compensated EC (mS/cm)
  float ecValue = ecSensor.readEC(currentVoltage, currentTempC);

  // Convert EC (mS/cm) to salinity (ppt)
  float ppt = ecValue * EC_TO_PPT_FACTOR;

  // Clamp to reasonable range
  if (ppt < 0.0) ppt = 0.0;
  if (ppt > 50.0) ppt = 50.0;

  // Round to 2 decimal places
  ppt = round(ppt * 100.0) / 100.0;

  // Sensor fault detection (FT-06): disconnected or out-of-range
  bool wasHealthy = !faultSensor;
  if (currentVoltage < 5.0 || currentVoltage > 3200.0 || ppt > 45.0) {
    if (!faultSensor) {
      faultSensor = true;
      Serial.println(F("[FAULT] EC sensor disconnected or out of range!"));
      triggerAlert("sensor_fault",
                   "EC sensor returned disconnected or out of range reading. Check wiring.");
    }
  } else {
    if (faultSensor) {
      Serial.println(F("[FAULT] EC sensor recovered."));
    }
    faultSensor = false;
  }

  return ppt;
}

// ============================================================================
//  CONTROL LOGIC & FAULT EVALUATION
// ============================================================================

void evaluateControlLogic() {
  // ---- Reservoir float switch check (FT-09) ----
  // Float switch: NO (normally open) wired between GPIO and GND.
  // Pin mode: INPUT_PULLUP (internal ~45kΩ pull-up to 3.3V).
  //
  // Float UP   (water present) → switch CLOSED → GPIO pulled to GND → LOW  → OK
  // Float DOWN (water gone)    → switch OPEN   → pull-up to 3.3V   → HIGH → EMPTY
  bool fwReservoirEmpty = (digitalRead(PIN_FLOAT_FW) == HIGH);
  bool swReservoirEmpty = (digitalRead(PIN_FLOAT_SW) == HIGH);

  // Freshwater reservoir fault
  if (fwReservoirEmpty && !faultLowReservoirFW) {
    faultLowReservoirFW = true;
    triggerAlert("low_reservoir",
                 "Freshwater reservoir level is critically low.");
    Serial.println(F("[FAULT] Freshwater reservoir LOW!"));
  } else if (!fwReservoirEmpty) {
    faultLowReservoirFW = false;
  }

  // Saltwater reservoir fault
  if (swReservoirEmpty && !faultLowReservoirSW) {
    faultLowReservoirSW = true;
    triggerAlert("low_reservoir",
                 "Saltwater reservoir level is critically low.");
    Serial.println(F("[FAULT] Saltwater reservoir LOW!"));
  } else if (!swReservoirEmpty) {
    faultLowReservoirSW = false;
  }

  // ---- Pump timeout fault (FT-08) ----
  // If a pump has been running beyond the dynamic timeout without ≥ 0.5 ppt change → fault
  if (isFwPumpActive || isSwPumpActive) {
    if (millis() - pumpStartTime > pumpTimeoutMs) {
      float delta = abs(currentPpt - salinityAtPumpStart);
      if (delta < 0.5) {
        if (!faultPump) {
          faultPump = true;
          String pumpName = isFwPumpActive ? "Freshwater" : "Saltwater";
          String msg = pumpName + " pump did not change salinity by 0.5 ppt within timeout (" + String(pumpTimeoutMs / 1000) + "s).";
          triggerAlert("pump_fault", msg.c_str());
          Serial.println(F("[FAULT] Pump timeout — no measurable change!"));
        }
      } else {
        // Progress detected — reset the timeout window
        pumpStartTime = millis();
        salinityAtPumpStart = currentPpt;
        faultPump = false;
      }
    }
  } else {
    // No pump running — reset pump fault tracking
    faultPump = false;
  }

  // ---- Overcorrection detection ----
  // After pumps stop, check if salinity crossed the opposite threshold
  if (!isFwPumpActive && !isSwPumpActive && lastCorrectionDirection.length() > 0) {
    if (lastCorrectionDirection == "DOWN" && currentPpt < PRESET_MIN_PPT) {
      faultOvercorrection = true;
      triggerAlert("overcorrection",
                   "Salinity overcorrected below minimum after freshwater dilution.");
      Serial.println(F("[FAULT] Overcorrection detected (too low)!"));
      lastCorrectionDirection = "";  // Prevent repeated alerts
    } else if (lastCorrectionDirection == "UP" && currentPpt > PRESET_MAX_PPT) {
      faultOvercorrection = true;
      triggerAlert("overcorrection",
                   "Salinity overcorrected above maximum after saltwater dosing.");
      Serial.println(F("[FAULT] Overcorrection detected (too high)!"));
      lastCorrectionDirection = "";
    } else {
      faultOvercorrection = false;
    }
  }
}

// ============================================================================
//  PUMP CONTROL EXECUTION
// ============================================================================

void executePumpControl() {
  // FAILSAFE: Any critical fault → shut down ALL pumps immediately
  if (faultSensor || faultPump) {
    digitalWrite(PIN_RELAY_FW, HIGH);  // OFF
    digitalWrite(PIN_RELAY_SW, HIGH);  // OFF
    isFwPumpActive = false;
    isSwPumpActive = false;
    return;
  }

  // ---- Normal control logic ----
  if (currentPpt > PRESET_MAX_PPT) {
    // Salinity too HIGH → activate freshwater pump to dilute
    if (!faultLowReservoirFW) {
      if (!isFwPumpActive) {
        digitalWrite(PIN_RELAY_FW, LOW);   // ON (active-LOW)
        digitalWrite(PIN_RELAY_SW, HIGH);  // OFF
        isFwPumpActive = true;
        isSwPumpActive = false;
        pumpStartTime = millis();
        salinityAtPumpStart = currentPpt;
        lastCorrectionDirection = "DOWN";
        Serial.println(F("[PUMP] Freshwater pump ACTIVATED (diluting)."));
      }
    } else {
      // Reservoir empty — can't pump
      digitalWrite(PIN_RELAY_FW, HIGH);
      isFwPumpActive = false;
    }

  } else if (currentPpt < PRESET_MIN_PPT) {
    // Salinity too LOW → activate saltwater pump to dose
    if (!faultLowReservoirSW) {
      if (!isSwPumpActive) {
        digitalWrite(PIN_RELAY_SW, LOW);   // ON (active-LOW)
        digitalWrite(PIN_RELAY_FW, HIGH);  // OFF
        isSwPumpActive = true;
        isFwPumpActive = false;
        pumpStartTime = millis();
        salinityAtPumpStart = currentPpt;
        lastCorrectionDirection = "UP";
        Serial.println(F("[PUMP] Saltwater pump ACTIVATED (dosing)."));
      }
    } else {
      digitalWrite(PIN_RELAY_SW, HIGH);
      isSwPumpActive = false;
    }

  } else {
    // Within target range → all pumps OFF
    if (isFwPumpActive || isSwPumpActive) {
      Serial.println(F("[PUMP] In range — pumps OFF."));
    }
    digitalWrite(PIN_RELAY_FW, HIGH);
    digitalWrite(PIN_RELAY_SW, HIGH);
    isFwPumpActive = false;
    isSwPumpActive = false;
  }
}

// ============================================================================
//  FIREBASE — PUSH LIVE DATA (every 5s)
// ============================================================================

void pushLiveData() {
  if (!Firebase.ready()) return;

  String basePath = String("devices/") + DEVICE_CODE;
  unsigned long epochMs = getEpochMs();

  // ---- sensor/current_ppt ----
  // Matches: AppConstants.pathCurrentSalinity(deviceCode)
  // Flutter model: SalinityReading { ppt, timestamp }
  {
    FirebaseJson json;
    json.set("ppt", round(currentPpt * 100.0) / 100.0);
    json.set("timestamp", (double)epochMs);
    Firebase.RTDB.setJSON(&fbdo, basePath + "/sensor/current_ppt", &json);
  }

  // ---- system/status ----
  // Matches: AppConstants.pathSystemStatus(deviceCode)
  // Flutter model: SystemStatus { freshwater_pump, saltwater_pump, sensor_status, reservoir_low }
  {
    FirebaseJson json;
    json.set("freshwater_pump", isFwPumpActive);
    json.set("saltwater_pump", isSwPumpActive);
    json.set("sensor_status", faultSensor ? "fault" : "ok");
    json.set("reservoir_low", faultLowReservoirFW || faultLowReservoirSW);
    Firebase.RTDB.setJSON(&fbdo, basePath + "/system/status", &json);
  }

  // ---- Clear stale active alerts, then re-push current ones ----
  clearActiveAlerts();

  // Re-push any currently active faults
  if (faultSensor) {
    triggerAlert("sensor_fault",
                 "EC sensor returned disconnected or out of range reading. Check wiring.");
  }
  if (faultPump) {
    String msg = isFwPumpActive
      ? "Freshwater pump did not produce expected salinity change within timeout."
      : "Saltwater pump did not produce expected salinity change within timeout.";
    triggerAlert("pump_fault", msg.c_str());
  }
  if (faultLowReservoirFW) {
    triggerAlert("low_reservoir", "Freshwater reservoir level is critically low.");
  }
  if (faultLowReservoirSW) {
    triggerAlert("low_reservoir", "Saltwater reservoir level is critically low.");
  }
  if (currentPpt < PRESET_MIN_PPT || currentPpt > PRESET_MAX_PPT) {
    String msg = currentPpt < PRESET_MIN_PPT
      ? "Salinity too LOW: " + String(currentPpt, 2) + " ppt (min: " + String(PRESET_MIN_PPT, 2) + ")"
      : "Salinity too HIGH: " + String(currentPpt, 2) + " ppt (max: " + String(PRESET_MAX_PPT, 2) + ")";
    triggerAlert("overcorrection", msg.c_str());
  }
}

// ============================================================================
//  FIREBASE — PUSH LOG ENTRY (every 30s, FT-07)
// ============================================================================

void pushLogEntry() {
  if (!Firebase.ready()) return;

  unsigned long epochMs = getEpochMs();
  String path = String("devices/") + DEVICE_CODE + "/logs/salinity";

  // Push (POST) generates auto-key — matches Flutter's orderByChild('timestamp')
  FirebaseJson json;
  json.set("ppt", round(currentPpt * 100.0) / 100.0);
  json.set("timestamp", (double)epochMs);

  if (Firebase.RTDB.pushJSON(&fbdo, path, &json)) {
    Serial.println(F("[LOG] Salinity log pushed."));
  } else {
    Serial.printf("[LOG] Push failed: %s\n", fbdo.errorReason().c_str());
  }
}

// ============================================================================
//  FIREBASE — WRITE PRESET ONCE (FR-02, FR-04)
// ============================================================================

void pushPresetOnce() {
  if (presetWritten || !Firebase.ready()) return;

  String path = String("devices/") + DEVICE_CODE + "/system/active_preset";

  // Matches Flutter model: Preset { name, min_ppt, max_ppt }
  FirebaseJson json;
  json.set("name", PRESET_NAME);
  json.set("min_ppt", PRESET_MIN_PPT);
  json.set("max_ppt", PRESET_MAX_PPT);

  if (Firebase.RTDB.setJSON(&fbdo, path, &json)) {
    presetWritten = true;
    Serial.printf("[FB] Preset written: %s (%.1f – %.1f ppt)\n",
                  PRESET_NAME, PRESET_MIN_PPT, PRESET_MAX_PPT);
  }
}

// ============================================================================
//  FIREBASE — WRITE DEVICE INFO ONCE
// ============================================================================

void pushDeviceInfoOnce() {
  if (deviceInfoWritten || !Firebase.ready()) return;

  String path = String("devices/") + DEVICE_CODE + "/info";

  FirebaseJson json;
  json.set("status", "online");
  json.set("last_boot", (double)getEpochMs());
  json.set("firmware_version", "2.0");
  json.set("device_code", DEVICE_CODE);

  if (Firebase.RTDB.setJSON(&fbdo, path, &json)) {
    deviceInfoWritten = true;
    Serial.println(F("[FB] Device info registered."));
  }
}

// ============================================================================
//  FIREBASE — ALERT HELPERS
// ============================================================================

void triggerAlert(const char* type, const char* message) {
  if (!Firebase.ready()) return;

  String basePath = String("devices/") + DEVICE_CODE;
  unsigned long epochMs = getEpochMs();

  FirebaseJson json;
  json.set("type", type);
  json.set("message", message);
  json.set("timestamp", (double)epochMs);
  json.set("is_active", true);

  // Write to active alerts (keyed by type to prevent duplicates)
  Firebase.RTDB.setJSON(&fbdo, basePath + "/alerts/active/" + String(type), &json);

  // Push to historical alert log
  Firebase.RTDB.pushJSON(&fbdo, basePath + "/logs/alerts", &json);
}

void clearActiveAlerts() {
  if (!Firebase.ready()) return;
  String path = String("devices/") + DEVICE_CODE + "/alerts/active";
  Firebase.RTDB.deleteNode(&fbdo, path);
}

// ============================================================================
//  UTILITY — EPOCH MILLISECONDS
// ============================================================================

unsigned long getEpochMs() {
  time_t now;
  time(&now);
  // Multiply by 1000 for milliseconds (matches Flutter's fromMillisecondsSinceEpoch)
  return (unsigned long)now * 1000UL;
}

// ============================================================================
//  SERIAL CALIBRATION HANDLER
// ============================================================================

void handleSerialCalibration() {
  // Read serial input character by character
  while (Serial.available() > 0) {
    char c = Serial.read();

    if (c == '\n' || c == '\r') {
      if (serialIndex > 0) {
        serialBuffer[serialIndex] = '\0';

        // Pass command to DFRobot EC library for calibration
        ecSensor.calibration(currentVoltage, currentTempC, serialBuffer);

        // Clear buffer
        serialIndex = 0;
        memset(serialBuffer, 0, sizeof(serialBuffer));
      }
    } else {
      if (serialIndex < (int)sizeof(serialBuffer) - 1) {
        serialBuffer[serialIndex++] = c;
      }
    }
  }
}
