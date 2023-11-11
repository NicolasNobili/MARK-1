#include <SoftwareSerial.h>
SoftwareSerial BT(10,11);

void setup() {
  // put your setup code here, to run once:
  Serial.begin(38400);
  BT.begin(38400);
  Serial.println("Listo");
}

void loop() {
  // put your main code here, to run repeatedly:
  if(BT.available())
  {
    Serial.write(BT.read());
  }
  if(Serial.available())
  {
    BT.write(Serial.read());
  }
}
