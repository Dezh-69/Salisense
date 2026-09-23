// Test EC Sensor on GPIO 34
// Use this to check raw ADC values and voltages.
void setup() {
  Serial.begin(115200);
  pinMode(34, INPUT);
  Serial.println("EC Sensor Test Started.");
}

void loop() {
  int raw = analogRead(34);
  float voltage = (raw / 4095.0) * 3300.0;
  
  Serial.print("Analog Raw (0-4095): "); 
  Serial.print(raw);
  Serial.print(" | Voltage: "); 
  Serial.print(voltage); 
  Serial.println(" mV");
  
  delay(1000);
}
