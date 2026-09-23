// Test Relays on GPIO 26 and 27
// Note: Most 5V Relay modules are ACTIVE LOW. 
// Writing LOW turns them ON, writing HIGH turns them OFF.

#define RELAY_FW 26 // Freshwater Pump Relay
#define RELAY_SW 27 // Saltwater Pump Relay

void setup() {
  Serial.begin(115200);
  pinMode(RELAY_FW, OUTPUT);
  pinMode(RELAY_SW, OUTPUT);
  
  // Turn both OFF initially
  digitalWrite(RELAY_FW, HIGH);
  digitalWrite(RELAY_SW, HIGH);
  Serial.println("Relay Test Started.");
}

void loop() {
  Serial.println("Turning ON Freshwater Relay (Pin 26)...");
  digitalWrite(RELAY_FW, LOW); 
  delay(3000);
  
  Serial.println("Turning OFF Freshwater Relay (Pin 26)...");
  digitalWrite(RELAY_FW, HIGH); 
  delay(2000);
  
  Serial.println("Turning ON Saltwater Relay (Pin 27)...");
  digitalWrite(RELAY_SW, LOW); 
  delay(3000);
  
  Serial.println("Turning OFF Saltwater Relay (Pin 27)...");
  digitalWrite(RELAY_SW, HIGH); 
  delay(2000);
}
