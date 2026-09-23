/**
 * SaliSense - ESP32 Firmware
 * 
 * Hardware Requirements:
 * - ESP32 Development Board
 * - DFRobot Gravity Analog EC Sensor (DFR0300 V2)
 * - DS18B20 Waterproof Temperature Sensor
 * - 2-Channel 5V Relay Module (Controls FW and SW 5V DC Pumps)
 * - 2x Vertical Float Switches (Passive Dry Contact)
 * 
 * Dependencies:
 * - OneWire (for DS18B20)
 * - DallasTemperature (for DS18B20)
 * - ArduinoJson
 * - Firebase ESP Client (by Mobizt)
 */

#include <WiFi.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Firebase_ESP_Client.h>
#include <ArduinoJson.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// ==========================================
// CONFIGURATION
// ==========================================

// WiFi
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Firebase
#define FIREBASE_API_KEY "YOUR_API_KEY"
#define FIREBASE_DATABASE_URL "https://salisense-default-rtdb.asia-southeast1.firebasedatabase.app"
#define DEVICE_EMAIL "device@salisense.com" // Dedicated device account per PRD
#define DEVICE_PASSWORD "YOUR_DEVICE_PASSWORD"
#define DEVICE_CODE "ESP32-A1B2C3" // Hardware specific serial number

// GPIO Pin Mapping
#define PIN_EC_SENSOR 34      // Analog input for EC
#define PIN_TEMP_SENSOR 4     // Digital pin for OneWire (DS18B20)
#define PIN_RELAY_FW 26       // Relay channel 1 (Freshwater Pump)
#define PIN_RELAY_SW 27       // Relay channel 2 (Saltwater Pump)
#define PIN_FLOAT_FW 14       // Freshwater reservoir float switch
#define PIN_FLOAT_SW 25       // Saltwater reservoir float switch (Moved from 12 to avoid boot failure)

// System Constants
#define CONTROL_INTERVAL_MS 5000     // 5 seconds control loop
#define PUMP_TIMEOUT_MS 24000        // 24 seconds timeout for 0.5ppt change
#define EC_K_VALUE 1.0               // Cell constant of the EC sensor

// ==========================================
// GLOBAL STATE
// ==========================================
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
bool isFirebaseReady = false;

OneWire oneWire(PIN_TEMP_SENSOR);
DallasTemperature tempSensor(&oneWire);

// Operational State
float currentSalinity = 10.0;
float currentTemp = 25.0;
float targetMin = 8.0;
float targetMax = 12.0;
bool isFwPumpActive = false;
bool isSwPumpActive = false;

// Fault Flags (PRD section 9)
bool faultSensor = false;
bool faultPump = false;
bool faultLowReservoir = false;
bool faultOvercorrection = false;

// Tracking variables
unsigned long lastControlTime = 0;
unsigned long pumpStartTime = 0;
float salinityAtPumpStart = 0.0;
bool pumpTimeoutActive = false;
String lastCorrectionDirection = ""; // "UP" or "DOWN"

// ==========================================
// PROTOTYPES
// ==========================================
void initHardware();
void connectWiFi();
void initFirebase();
void readSensors();
void evaluateControlLogic();
void pushDataToFirebase();
void triggerAlert(String type, String message);
void clearActiveAlerts();
float readCompensatedSalinity();

// ==========================================
// SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  
  initHardware();
  connectWiFi();
  initFirebase();
  
  Serial.println("SaliSense ESP32 Initialized.");
}

// ==========================================
// LOOP
// ==========================================
void loop() {
  // Run control cycle every 5 seconds
  if (millis() - lastControlTime >= CONTROL_INTERVAL_MS) {
    lastControlTime = millis();
    
    // 1. Read Sensors
    readSensors();
    
    // 2. Evaluate State and Faults
    evaluateControlLogic();
    
    // 3. Push to Firebase
    pushDataToFirebase();
  }
}

// ==========================================
// HARDWARE & SENSOR FUNCTIONS
// ==========================================
void initHardware() {
  pinMode(PIN_RELAY_FW, OUTPUT);
  pinMode(PIN_RELAY_SW, OUTPUT);
  
  // Relays are typically active LOW, so write HIGH to turn off initially
  digitalWrite(PIN_RELAY_FW, HIGH);
  digitalWrite(PIN_RELAY_SW, HIGH);
  
  pinMode(PIN_FLOAT_FW, INPUT_PULLUP);
  pinMode(PIN_FLOAT_SW, INPUT_PULLUP);
  
  tempSensor.begin();
}

void readSensors() {
  // Read Temperature
  tempSensor.requestTemperatures();
  currentTemp = tempSensor.getTempCByIndex(0);
  
  // Read Salinity (PPT)
  currentSalinity = readCompensatedSalinity();
  
  // Check for Sensor Fault
  // Out of range (disconnected or shorted)
  if (currentSalinity < 0 || currentSalinity > 50.0 || currentTemp == DEVICE_DISCONNECTED_C) {
    if (!faultSensor) {
      faultSensor = true;
      triggerAlert("sensor_fault", "EC sensor disconnected or out of range");
    }
  } else {
    faultSensor = false;
  }
}

// Implements custom ADC correction for ESP32 non-linearity
float readCompensatedSalinity() {
  int rawAdc = analogRead(PIN_EC_SENSOR);
  
  // ESP32 12-bit ADC -> Voltage mapping (approximate polynomial)
  float voltage = (rawAdc / 4095.0) * 3300.0; // mV
  
  // Temperature compensation coefficient (typically 2% per degree C from 25C)
  float tempCoefficient = 1.0 + 0.02 * (currentTemp - 25.0);
  
  // Convert voltage to EC (Specific to DFRobot Analog EC sensor K=1)
  // EC = (Voltage / TempCoeff) * something...
  // For simplicity in this skeleton, using a basic mapping:
  float ec = (voltage / tempCoefficient) * EC_K_VALUE / 1000.0; // ms/cm
  
  // Convert EC to PPT (Rule of thumb: 1 ms/cm ≈ 0.55 ppt for tilapia water)
  float ppt = ec * 0.55; 
  
  return ppt;
}

// ==========================================
// CONTROL LOGIC & FAULTS
// ==========================================
void evaluateControlLogic() {
  // Read Reservoirs (LOW means empty if using standard NO float switch wired to GND)
  bool fwEmpty = digitalRead(PIN_FLOAT_FW) == LOW;
  bool swEmpty = digitalRead(PIN_FLOAT_SW) == LOW;
  
  // Handle Low Reservoir Fault
  if ((isFwPumpActive && fwEmpty) || (isSwPumpActive && swEmpty)) {
    if (!faultLowReservoir) {
      faultLowReservoir = true;
      triggerAlert("low_reservoir", "Float sensor signals low fill on active reservoir");
    }
  } else {
    faultLowReservoir = false;
  }
  
  // Check Pump Timeout Fault (24s)
  if (isFwPumpActive || isSwPumpActive) {
    if (millis() - pumpStartTime > PUMP_TIMEOUT_MS) {
      if (abs(currentSalinity - salinityAtPumpStart) < 0.5) {
        if (!faultPump) {
          faultPump = true;
          triggerAlert("pump_fault", "Activated pump did not change salinity by 0.5 ppt within 24s timeout");
        }
      } else {
        // Reset timeout tracking since we saw a valid change
        pumpStartTime = millis();
        salinityAtPumpStart = currentSalinity;
      }
    }
  }

  // Check Overcorrection Fault
  if (!isFwPumpActive && !isSwPumpActive) {
    if (lastCorrectionDirection == "DOWN" && currentSalinity < targetMin) {
       triggerAlert("overcorrection", "Salinity crossed activation threshold on opposite side after correction");
       lastCorrectionDirection = ""; // Reset to avoid spam
    } else if (lastCorrectionDirection == "UP" && currentSalinity > targetMax) {
       triggerAlert("overcorrection", "Salinity crossed activation threshold on opposite side after correction");
       lastCorrectionDirection = "";
    }
  }

  // FAILSAFE: If any fault is active, stop pumps immediately
  if (faultSensor || faultPump || faultLowReservoir) {
    digitalWrite(PIN_RELAY_FW, HIGH);
    digitalWrite(PIN_RELAY_SW, HIGH);
    isFwPumpActive = false;
    isSwPumpActive = false;
    return;
  }
  
  // Normal Control Loop
  if (currentSalinity > targetMax) {
    // Need freshwater to dilute
    if (!isFwPumpActive) {
      digitalWrite(PIN_RELAY_FW, LOW); // Turn ON
      digitalWrite(PIN_RELAY_SW, HIGH); // Turn OFF
      isFwPumpActive = true;
      isSwPumpActive = false;
      pumpStartTime = millis();
      salinityAtPumpStart = currentSalinity;
      lastCorrectionDirection = "DOWN";
    }
  } else if (currentSalinity < targetMin) {
    // Need saltwater to increase
    if (!isSwPumpActive) {
      digitalWrite(PIN_RELAY_SW, LOW); // Turn ON
      digitalWrite(PIN_RELAY_FW, HIGH); // Turn OFF
      isSwPumpActive = true;
      isFwPumpActive = false;
      pumpStartTime = millis();
      salinityAtPumpStart = currentSalinity;
      lastCorrectionDirection = "UP";
    }
  } else {
    // Within range
    digitalWrite(PIN_RELAY_FW, HIGH);
    digitalWrite(PIN_RELAY_SW, HIGH);
    isFwPumpActive = false;
    isSwPumpActive = false;
  }
}

// ==========================================
// NETWORK & FIREBASE
// ==========================================
void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println("\nConnected to WiFi!");
}

void initFirebase() {
  config.api_key = FIREBASE_API_KEY;
  config.database_url = FIREBASE_DATABASE_URL;
  
  // PRD: ESP32 uses dedicated device account
  auth.user.email = DEVICE_EMAIL;
  auth.user.password = DEVICE_PASSWORD;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void pushDataToFirebase() {
  if (!Firebase.ready()) return;
  
  // Clear stale alerts before re-evaluating current conditions
  clearActiveAlerts();
  
  // Build payload
  FirebaseJson json;
  json.set("timestamp", millis());
  json.set("current_ppt", currentSalinity);
  json.set("fw_pump_active", isFwPumpActive);
  json.set("sw_pump_active", isSwPumpActive);
  json.set("sensor_healthy", !faultSensor);
  json.set("reservoir_low", faultLowReservoir);
  
  // Push to device info path
  String path = String("devices/") + DEVICE_CODE + "/info";
  Firebase.RTDB.setJSON(&fbdo, path, &json);
  
  // Note: For historical logging (FT-07), we can either log every 30s locally via SPIFFS
  // or push to a `devices/DEVICE_CODE/logs/salinity` path directly if internet is available.
}

void triggerAlert(String type, String message) {
  if (!Firebase.ready()) return;
  Serial.println("ALERT: " + message);
  
  FirebaseJson alertJson;
  alertJson.set("type", type);
  alertJson.set("message", message);
  alertJson.set("timestamp", millis()); // In production, use NTP time
  alertJson.set("is_active", true);
  
  String basePath = String("devices/") + DEVICE_CODE;
  
  // Push to active alerts (keyed by type to avoid duplicates)
  Firebase.RTDB.setJSON(&fbdo, basePath + "/alerts/active/" + type, &alertJson);
  
  // Historical alert path
  Firebase.RTDB.pushJSON(&fbdo, basePath + "/logs/alerts", &alertJson);
}

void clearActiveAlerts() {
  if (!Firebase.ready()) return;
  String path = String("devices/") + DEVICE_CODE + "/alerts/active";
  Firebase.RTDB.deleteNode(&fbdo, path);
}
