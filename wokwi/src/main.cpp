/*
 * SaliSense - ESP32 Mock Firmware for Wokwi
 * 
 * Simulates an ESP32 salinity monitoring system that pushes
 * data to Firebase Realtime Database via REST API.
 * 
 * Wokwi Setup:
 *   1. Go to https://wokwi.com and create a new ESP32 project
 *   2. Paste this code into the sketch
 *   3. Add a diagram.json (provided below) or just use a bare ESP32
 *   4. Run the simulation — it will connect to Firebase over WiFi
 *
 * NOTE: Wokwi provides simulated WiFi with internet access automatically.
 */

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

// ============================================================
//  FIREBASE CONFIGURATION
// ============================================================
const char* FIREBASE_HOST = "https://salisense-default-rtdb.asia-southeast1.firebasedatabase.app";
const char* FIREBASE_API_KEY = "AIzaSyAR5DKFVEXa0v-T-IxTy9-O_Do3NyP0cXw";

// Firebase Auth credentials (same account the app uses)
const char* FIREBASE_EMAIL = "app@salisense.com";
const char* FIREBASE_PASSWORD = "password";

// ============================================================
//  WOKWI SIMULATED WIFI
// ============================================================
const char* WIFI_SSID = "Wokwi-GUEST";
const char* WIFI_PASS = "";

// ============================================================
//  DEVICE CONFIGURATION
// ============================================================
const char* DEVICE_CODE = "ESP32-A1B2C3";


// ============================================================
//  SIMULATION PARAMETERS
// ============================================================
// Tilapia optimal range: 0 - 15 ppt (per PRD)
const float PRESET_MIN_PPT = 5.0;
const float PRESET_MAX_PPT = 15.0;
const float SALINITY_BASE = 10.0;      // Center of normal range
const float SALINITY_DRIFT = 3.0;      // Random drift amplitude
const unsigned long SEND_INTERVAL_MS = 5000;  // Send data every 5 seconds

// ============================================================
//  GLOBAL STATE
// ============================================================
String firebaseIdToken = "";
unsigned long lastSendTime = 0;
int logCounter = 0;

// Simulated system state
bool freshwaterPumpActive = false;
bool saltwaterPumpActive = false;
bool sensorHealthy = true;
bool reservoirLow = false;
float currentPpt = SALINITY_BASE;

// ============================================================
//  FIREBASE AUTH - Sign in with Email/Password
// ============================================================
bool firebaseSignIn() {
  HTTPClient http;
  String url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + String(FIREBASE_API_KEY);
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // Build the auth request body
  JsonDocument doc;
  doc["email"] = FIREBASE_EMAIL;
  doc["password"] = FIREBASE_PASSWORD;
  doc["returnSecureToken"] = true;
  
  String body;
  serializeJson(doc, body);

  int httpCode = http.POST(body);
  
  if (httpCode == 200) {
    String response = http.getString();
    JsonDocument responseDoc;
    deserializeJson(responseDoc, response);
    firebaseIdToken = responseDoc["idToken"].as<String>();
    Serial.println("[AUTH] Signed in successfully!");
    Serial.println("[AUTH] Token length: " + String(firebaseIdToken.length()));
    http.end();
    return true;
  } else {
    Serial.println("[AUTH] Sign-in FAILED. HTTP Code: " + String(httpCode));
    Serial.println("[AUTH] Response: " + http.getString());
    http.end();
    return false;
  }
}

// ============================================================
//  FIREBASE REST API - PUT/PATCH data
// ============================================================
bool firebasePut(String path, String jsonData) {
  HTTPClient http;
  String fullPath = "devices/" + String(DEVICE_CODE) + "/" + path;
  String url = String(FIREBASE_HOST) + "/" + fullPath + ".json?auth=" + firebaseIdToken;
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  int httpCode = http.PUT(jsonData);
  bool success = (httpCode == 200);
  
  if (!success) {
    Serial.println("[FB] PUT failed at /" + fullPath + " HTTP: " + String(httpCode));
    Serial.println("[FB] Response: " + http.getString());
  }
  
  http.end();
  return success;
}

bool firebasePush(String path, String jsonData) {
  HTTPClient http;
  String fullPath = "devices/" + String(DEVICE_CODE) + "/" + path;
  String url = String(FIREBASE_HOST) + "/" + fullPath + ".json?auth=" + firebaseIdToken;

  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  int httpCode = http.POST(jsonData);  // POST = push (auto-generate key)
  bool success = (httpCode == 200);
  
  if (!success) {
    Serial.println("[FB] PUSH failed at /" + fullPath + " HTTP: " + String(httpCode));
  } else {
    Serial.println("[FB] PUSH OK at /" + fullPath);
  }

  http.end();
  return success;
}

bool firebaseDelete(String path) {
  HTTPClient http;
  String fullPath = "devices/" + String(DEVICE_CODE) + "/" + path;
  String url = String(FIREBASE_HOST) + "/" + fullPath + ".json?auth=" + firebaseIdToken;

  http.begin(url);
  int httpCode = http.sendRequest("DELETE");
  bool success = (httpCode == 200);

  if (!success) {
    Serial.println("[FB] DELETE failed at /" + fullPath + " HTTP: " + String(httpCode));
  }

  http.end();
  return success;
}

// ============================================================
//  SIMULATION LOGIC
// ============================================================
float simulateSalinity() {
  // Read potentiometer on pin 34 (ADC range 0-4095)
  int rawAdc = analogRead(34);
  // Map 0-4095 → 1.0 - 20.0 ppt
  currentPpt = 1.0 + (rawAdc / 4095.0) * 19.0;
  // Round to 2 decimal places
  currentPpt = round(currentPpt * 100.0) / 100.0;
  return currentPpt;
}

void simulatePumps(float ppt) {
  // Simple control logic simulation
  if (ppt > PRESET_MAX_PPT) {
    freshwaterPumpActive = true;   // Dilute with freshwater
    saltwaterPumpActive = false;
  } else if (ppt < PRESET_MIN_PPT) {
    freshwaterPumpActive = false;
    saltwaterPumpActive = true;    // Add saltwater
  } else {
    freshwaterPumpActive = false;
    saltwaterPumpActive = false;   // In range, pumps off
  }

  // Rare sensor fault simulation (2% chance, resets after)
  if (random(0, 100) < 2) {
    sensorHealthy = false;
    Serial.println("[SIM] >>> SENSOR FAULT triggered!");
  } else {
    sensorHealthy = true;
  }

  // Rare reservoir low simulation
  reservoirLow = (random(0, 100) < 3);
}

// ============================================================
//  SEND ALL DATA TO FIREBASE
// ============================================================
void sendDataToFirebase() {
  // Get current time as epoch milliseconds
  time_t now;
  time(&now);
  unsigned long epochMs = (unsigned long)now * 1000UL;
  
  float ppt = simulateSalinity();
  simulatePumps(ppt);

  Serial.println("─────────────────────────────────────");
  Serial.println("[DATA] ppt: " + String(ppt, 2) + 
                 " | FW:" + String(freshwaterPumpActive) +
                 " | SW:" + String(saltwaterPumpActive) + 
                 " | Sensor:" + String(sensorHealthy ? "OK" : "FAULT"));

  // 1. Update current salinity reading (sensor/current_ppt)
  {
    JsonDocument doc;
    doc["ppt"] = round(ppt * 100.0) / 100.0;  // 2 decimal places
    doc["timestamp"] = epochMs;
    String json;
    serializeJson(doc, json);
    firebasePut("sensor/current_ppt", json);
  }

  // 2. Push to salinity log history (logs/salinity)
  {
    JsonDocument doc;
    doc["ppt"] = round(ppt * 100.0) / 100.0;
    doc["timestamp"] = epochMs;
    String json;
    serializeJson(doc, json);
    firebasePush("logs/salinity", json);
    logCounter++;
  }

  // 3. Update system status (system/status)
  {
    JsonDocument doc;
    doc["freshwater_pump"] = freshwaterPumpActive;
    doc["saltwater_pump"] = saltwaterPumpActive;
    doc["sensor_status"] = sensorHealthy ? "ok" : "fault";
    doc["reservoir_low"] = reservoirLow;
    String json;
    serializeJson(doc, json);
    firebasePut("system/status", json);
  }

  // 4. Update active preset (system/active_preset) - only once
  if (logCounter == 1) {
    JsonDocument doc;
    doc["name"] = "Tilapia Grow-out";
    doc["min_ppt"] = PRESET_MIN_PPT;
    doc["max_ppt"] = PRESET_MAX_PPT;
    String json;
    serializeJson(doc, json);
    firebasePut("system/active_preset", json);
    Serial.println("[FB] Preset written: Tilapia Grow-out (" + 
                   String(PRESET_MIN_PPT) + " - " + String(PRESET_MAX_PPT) + " ppt)");
  }

  // 5. Clear stale active alerts, then push only currently-true conditions
  firebasePut("alerts/active", "null");

  if (ppt < PRESET_MIN_PPT || ppt > PRESET_MAX_PPT) {
    JsonDocument doc;
    doc["type"] = "overcorrection";
    doc["message"] = ppt < PRESET_MIN_PPT 
      ? "Salinity too LOW: " + String(ppt, 2) + " ppt (min: " + String(PRESET_MIN_PPT) + ")"
      : "Salinity too HIGH: " + String(ppt, 2) + " ppt (max: " + String(PRESET_MAX_PPT) + ")";
    doc["timestamp"] = epochMs;
    doc["is_active"] = true;
    String json;
    serializeJson(doc, json);
    firebasePush("alerts/active", json);
    firebasePush("logs/alerts", json);  // Push to alert history
    Serial.println("[ALERT] Out-of-range alert pushed!");
  }

  if (!sensorHealthy) {
    JsonDocument doc;
    doc["type"] = "sensor_fault";
    doc["message"] = "Salinity sensor returned invalid reading. Check wiring.";
    doc["timestamp"] = epochMs;
    doc["is_active"] = true;
    String json;
    serializeJson(doc, json);
    firebasePush("alerts/active", json);
    firebasePush("logs/alerts", json);  // Push to alert history
    Serial.println("[ALERT] Sensor fault alert pushed!");
  }

  if (reservoirLow) {
    JsonDocument doc;
    doc["type"] = "low_reservoir";
    doc["message"] = "Freshwater reservoir level is critically low.";
    doc["timestamp"] = epochMs;
    doc["is_active"] = true;
    String json;
    serializeJson(doc, json);
    firebasePush("alerts/active", json);
    firebasePush("logs/alerts", json);  // Push to alert history
    Serial.println("[ALERT] Low reservoir alert pushed!");
  }

  Serial.println("[OK] Data sent. Total logs: " + String(logCounter));
  Serial.println("─────────────────────────────────────");
}

// ============================================================
//  SETUP
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("=========================================");
  Serial.println("  SaliSense ESP32 Mock Firmware v1.0");
  Serial.println("  Wokwi Simulation Mode");
  Serial.println("=========================================");

  // Connect to WiFi (Wokwi provides simulated WiFi)
  Serial.print("[WIFI] Connecting to " + String(WIFI_SSID));
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Connected! IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\n[WIFI] FAILED to connect. Restarting...");
    ESP.restart();
  }

  // Sync time via NTP (needed for realistic timestamps)
  configTime(28800, 0, "pool.ntp.org");  // UTC+8 for Philippines
  Serial.print("[TIME] Syncing NTP...");
  struct tm timeinfo;
  while (!getLocalTime(&timeinfo)) {
    Serial.print(".");
    delay(500);
  }
  Serial.println(" OK! " + String(asctime(&timeinfo)));

  // Authenticate with Firebase
  if (!firebaseSignIn()) {
    Serial.println("[FATAL] Cannot authenticate. Restarting in 5s...");
    delay(5000);
    ESP.restart();
  }

  // Register device info on boot
  {
    JsonDocument doc;
    doc["status"] = "online";
    doc["last_boot"] = (unsigned long)time(NULL) * 1000UL;
    doc["firmware_version"] = "1.0";
    String json;
    serializeJson(doc, json);
    firebasePut("info", json);
    Serial.println("[FB] Device info registered");
  }

  // Seed random number generator
  randomSeed(analogRead(0) + millis());
  
  Serial.println("\n[READY] Sending data every " + String(SEND_INTERVAL_MS / 1000) + " seconds...\n");
}

// ============================================================
//  LOOP
// ============================================================
void loop() {
  if (millis() - lastSendTime >= SEND_INTERVAL_MS) {
    lastSendTime = millis();
    sendDataToFirebase();
  }
  
  delay(100);  // Small delay to prevent WDT reset
}
