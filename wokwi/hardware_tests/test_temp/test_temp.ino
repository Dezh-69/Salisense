// Test DS18B20 Temp Sensor on GPIO 4
// Requires OneWire and DallasTemperature libraries to be installed.

#include <OneWire.h>
#include <DallasTemperature.h>

#define PIN_TEMP 4

OneWire oneWire(PIN_TEMP);
DallasTemperature tempSensor(&oneWire);

void setup() {
  Serial.begin(115200);
  tempSensor.begin();
  Serial.println("DS18B20 Temp Sensor Test Started.");
}

void loop() {
  tempSensor.requestTemperatures();
  float tempC = tempSensor.getTempCByIndex(0);
  
  if (tempC == DEVICE_DISCONNECTED_C) {
    Serial.println("Error: Could not read temperature data (Disconnected).");
  } else {
    Serial.print("Temperature: "); 
    Serial.print(tempC); 
    Serial.println(" °C");
  }
  
  delay(1000);
}
