// Test Float Switches on GPIO 14 and 25
// Uses internal pull-up resistors.
// Wire the float switch between the GPIO pin and GND.

#define PIN_FLOAT_FW 14
#define PIN_FLOAT_SW 25

void setup() {
  Serial.begin(115200);
  pinMode(PIN_FLOAT_FW, INPUT_PULLUP);
  pinMode(PIN_FLOAT_SW, INPUT_PULLUP);
  Serial.println("Float Switch Test Started.");
}

void loop() {
  int fwState = digitalRead(PIN_FLOAT_FW);
  int swState = digitalRead(PIN_FLOAT_SW);
  
  Serial.print("FW Float (Pin 14): ");
  // HIGH means open circuit (Switch is UP / floating)
  // LOW means closed to ground (Switch is DOWN / empty)
  if (fwState == HIGH) Serial.print("HIGH (Tank Full)  |  ");
  else Serial.print("LOW (Tank Empty)  |  ");
  
  Serial.print("SW Float (Pin 25): ");
  if (swState == HIGH) Serial.println("HIGH (Tank Full)");
  else Serial.println("LOW (Tank Empty)");
  
  delay(500);
}
