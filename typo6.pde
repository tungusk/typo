#define NUMPINS 26  // TOOK OUT 24(bad),50(stuck to 29),51(stuck to 43),52,53, 22(german kbd)
#define MAPOFFSET 10  // how many bytes are reserved in EEPROM before the map is stored
#define MAXFLASH 100000 // how many bytes of flash we can write to before its a problem
#define X 1
#define Y 2
#define NEITHER -1
#define MOST_PRESSED 2 // number of keys which can be pressed at once
#define SHIFTL 6 // byte code for SHIFTL is SHIFTR & 0xFE
#define SHIFTR 7
#define debounceTime 75 // number of milliseconds since last press or release when opposite is accepted

#include <EEPROM.h>

// pins of uno32 

byte pin[NUMPINS] = {
  23,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49};
byte group[NUMPINS];

#define NUMKEYS 53
char key[NUMKEYS] = {
  '`','1','2','3','4','5','6','7','8','9','0','-','=',char(8),char(9),'q','w','e','r','t','y','u','i','o','p','[',']','\\','a','s','d','f','g','h','j','k','l',';','\'',char(13),'z','x','c','v','b','n','m',',','.','/',char(32),char(SHIFTL),char(SHIFTR)};
char keyCaps[NUMKEYS] = {
  '~','!','@','#','$','%','^','&','*','(',')','_','+',char(8),char(9),'Q','W','E','R','T','Y','U','I','O','P','{','}','|','A','S','D','F','G','H','J','K','L',':','"',char(13),'Z','X','C','V','B','N','M','<','>','?',char(32),char(SHIFTL),char(SHIFTR)};

boolean keyState[NUMKEYS] = {
  false}; // state of keys being pressed or not
byte pins2keys[NUMPINS][NUMPINS];
boolean printReal=false;
boolean shift = false;  // whether shift is down or not
unsigned long pressed = 0;  // time last keypress down was detected    
int lastPressed = 0;  // last key pressed
unsigned long letGo = 0;  // time last a key was released    
unsigned long flashPointer = 0;// (1 + NUMPINS * NUMPINS + NUMPINS + MAPOFFSET);  // pointer to where we should store typing data
// STORED CONFIG DATA IS AFTER STORING char(69) AND pins2keys[] AND group[]
// flashPointer is initialized by readMap()

int i = 0;

void setup() {

  for (int i=0; i <  NUMPINS; ++i) {
    pinMode(pin[i],INPUT);
    digitalWrite(pin[i],LOW);
    group[i] = NEITHER;
    for (int j=0; j <  NUMPINS; ++j) {
      pins2keys[i][j] = NEITHER;
    }
  }

  Serial.begin(9600);  
  group[14]=X;
  Serial.print("set pin ");
  Serial.print(pin[14]);
  Serial.println(" to X group");

  Serial.println("Begin main loop");
}

void loop() {
  if (!readMap()) { // map was not found!  begin learning process
    Serial.println("Begin learning");  
    Serial.print("Press ");
    printKey(i);
    while (i<=NUMKEYS) { // stay in this loop until exited using i
      for (int j=0; j <  NUMPINS; j++) if (group[j]!=Y) {
        pinMode(pin[j],OUTPUT);
        digitalWrite(pin[j],LOW);
        for (int k=0; k <  NUMPINS; k++) if ((group[k]!=X) && (!digitalRead(pin[k])) && (j != k)) if ((pins2keys[j][k] == NEITHER) && (i < NUMKEYS)) {
          Serial.print(" Great!  pins ");
          Serial.print(pin[j]);
          Serial.print(" and ");
          Serial.print(pin[k]);
          printGroups();
          group[j]=X;
          group[k]=Y;
          pins2keys[j][k]=i;
          Serial.print("Press ");
          printKey(++i);
          if (i==NUMKEYS) {  // all keys have been programmed into map
            printReal=true;  // print a space instead of "spacebar" etc
            Serial.println("press 1 to save map to nonvolatile, 2 to restart programming, or 3 to typo without saving map.");  
          }
        }
        else {
          if (lastPressed != pins2keys[j][k]) {
            printKey(pins2keys[j][k]);
            lastPressed = pins2keys[j][k];
            if (lastPressed == '1') { // lets save the map to nonvolatile
              saveMap();
              Serial.print("flashPointer = ");    
              Serial.println(flashPointer);
              flashPointer = 0;
              i = NUMKEYS + 1;            
              Serial.println("saved map to nonvolatile, now exit to typo.");  
            }
            if (lastPressed == '2') { // start the whole learning process over
              i = 0;
              Serial.println("restart learning process.");                
            }
            if (lastPressed == '3') { // exit to typo without saving map
              i = NUMKEYS + 1;
              Serial.println("exit to typo without saving map.");  
            }
          }
        }
        pinMode(pin[j],INPUT);
      }
    } //  while (i<=NUMKEYS) 
    i = 0;
    printGroups();
  }  //  if (!readMap()) 
  while ((EEPROM.read(flashPointer) != 0) && (flashPointer < MAXFLASH)) flashPointer++;  // find the beginning of empty space
  Serial.print("flashPointer = ");    
  Serial.println(flashPointer);

  while(flashPointer < MAXFLASH) {
    for (int j=0; j <  NUMPINS; j++) if (group[j]==X) {
      pinMode(pin[j],OUTPUT);
      digitalWrite(pin[j],LOW);
      for (int k=0; k <  NUMPINS; k++) {
        p2k = pins2keys[j][k];
        if ((pins2keys[j][k] != NEITHER) && (group[k]==Y)) if (!digitalRead(pin[k])) { // key is down
        if ((!keyState[p2k]) && (millis() - letGo > debounceTime)) { // key has just been pressed
          pressed = millis();  // record the time this key was pressed down
          printKey(pins2keys[j][k]);
          keyState[pins2keys[j][k]] = true;            
        }
      } 
      else { // key is up
        if ((keyState[pins2keys[j][k]]) && (millis() - pressed > debounceTime)) { // key has just been released
          keyState[pins2keys[j][k]] = false;
          if (pins2keys[j][k] & 0xFE != SHIFTL) letGo = millis(); // don't set letGo if it's a shift key
        }
      }
      pinMode(pin[j],INPUT);
    }
  } // while(flashPointer < MAXFLASH)
  Serial.println("i never thought it would get to this point.");
  while (true);  // halt
} // void loop

void storeKey(char key) {
  EEPROM.write(flashPointer++,key);
}

void printGroups() {
  Serial.print("  X= ");
  for (int i = 0; i < NUMKEYS; i++) if (group[i]==X) {
    Serial.print(pin[i]);
    Serial.print(" ");
  }
  Serial.print("Y= ");
  for (int i = 0; i < NUMKEYS; i++) if (group[i]==Y) {
    Serial.print(pin[i]);
    Serial.print(" ");
  }
  Serial.println();  
}

char printKey(int whichKey) {
  if (!printReal) {
    switch (byte(key[whichKey])) {
    case 8:
      Serial.print("Backspace");
      break;
    case 9:
      Serial.print("Tab");
      break;
    case 13:
      Serial.print("Return");
      break;
    case 32:
      Serial.print("Spacebar");
      break;
    case SHIFTL:
      Serial.print("LEFT shift");
      break;
    case SHIFTR:
      Serial.print("RIGHT shift");
      break;      
    default:
      Serial.print(key[whichKey]);      
    }
  } 
  else { // printReal == true
    if (!shift) {
      Serial.print(key[whichKey]);      
      return key[whichKey];
    } 
    else {
      Serial.print(keyCaps[whichKey]);      
      return keyCaps[whichKey];
    }
  }
}

void saveMap() {
  if (flashPointer == 0) {
    EEPROM.write(flashPointer++,69); // signify that we have stored a map
    for (int ii = 0; ii <  NUMPINS; ii++) {
      EEPROM.write(flashPointer++,group[ii]);
      for (int jj = 0; jj <  NUMPINS; jj++) {
        EEPROM.write(flashPointer++, pins2keys[ii][jj]);
      }
    }
  }
}

boolean readMap() {
  if (EEPROM.read(0) == 69) { // if a map is stored
    flashPointer++;  // only if we found it
    for (int ii = 0; ii <  NUMPINS; ii++) {
      group[ii] = EEPROM.read(flashPointer++);
      for (int jj = 0; jj <  NUMPINS; jj++) {
        pins2keys[ii][jj] = EEPROM.read(flashPointer++);
      }
    }
    return true;  // the map was found and read
  } 
  else return false;  // no map was found
}
/*  if (!groups_done()) {
 while (scan_for_groups());  
 }
 else {
 for (int i=0; i <  NUMPINS; ++i) {
 Serial.print("Press: ");
 Serial.print(key[i]);
 while (!scan_for_letter(key[i]) && Serial.read() != 'n') ;
 }  
 for (int i=0; i <  NUMPINS; ++i) {
 for (int j=0; j <  NUMPINS; ++j) {
 Serial.print(pins2keys[i][j]);
 }
 }
 }
 }
 
 
 boolean groups_done() {
 for (int i=0; i < NUMPINS; ++i) {
 if (group[i] == -1)
 return false;
 }
 print_groups();
 return true;
 }
 
 void print_groups() {
 for (int i=0; i < NUMPINS; ++i) {
 Serial.print(group[i]);
 Serial.print(' ');
 }
 Serial.println();
 }
 
 boolean scan_for_groups() {
 
 boolean active = false;
 for (int i=0; i < NUMPINS; ++i) {
 if (group[i] == -1)
 continue;
 
 pinMode(cn[i],OUTPUT);
 digitalWrite(cn[i],LOW);
 for (int j=i+1; j < NUMPINS; ++j) {
 if (digitalRead(cn[j]) == 0) {
 if (group[j] == -1) {
 
 Serial.print("Output, low: pin ");
 Serial.println(cn[i]);
 
 Serial.print("Input low: pin ");
 Serial.println(cn[j]);
 
 active = true;
 group[j] = !group[i];    
 print_pin(j);
 print_groups();
 }
 }
 
 }
 pinMode(cn[i],INPUT);
 digitalWrite(cn[i],HIGH);
 }
 return active;
 }
 
 boolean scan_for_letter(int idx) {
 for (int i=0; i < NUMPINS; ++i) {
 if (group[i] == -1)
 continue;
 pinMode(cn[i],OUTPUT);
 digitalWrite(cn[i],LOW);
 for (int j=i+1; j < NUMPINS; ++j) {
 if (digitalRead(cn[j]) == 0) {
 if (pins2keys[i][j] == -1) {
 pins2keys[i][j] = idx; 
 print_pin(i);   
 print_pin(j);
 return true;
 
 }
 }
 }
 pinMode(cn[i],INPUT);
 digitalWrite(cn[i],HIGH);
 }
 
 return false;
 }
 void print_pin(int idx) {
 Serial.print(idx);
 Serial.print(' ');
 Serial.print(group[idx]);
 Serial.print(' ');
 
 if (cn[idx] >= A0 && cn[idx] <= A15) {
 Serial.print('A');
 Serial.println(cn[idx] - A0,DEC);
 }
 else {
 Serial.println(cn[idx]);
 }
 }
 
 */
















