import processing.serial.*;
import cc.arduino.*;

Arduino arduino;
final static int[] speedPins = {13, 11, 12, 5, 9, 7, 6, 10};
final static int pinX = 0;
final static int pinY = 1;
final static int pinButton = 3;
final static int pinSwitch = 4;

final static boolean t = true;
final static boolean f = false;
final static int windowW = 600;
final static int windowH = 400;
final static boolean[][] data = {
  {t, t, t, t, t, t, f, f}, // 0
  {f, t, t, f, f, f, f, f}, // 1
  {t, t, f, t, t, f, t, f}, // 2
  {t, t, t, t, f, f, t, f}, // 3
  {f, t, t, f, f, t, t, f}, // 4
  {t, f, t, t, f, t, t, f}, // 5
  {t, f, t, t, t, t, t, f}, // 6
  {t, t, t, f, f, f, f, f}, // 7
  {t, t, t, t, t, t, t, f}, // 8
  {t, t, t, t, f, t, t, f}, // 9
};

int playerX, playerY;
int playerRadius = 10;
int maxCannonNum = 99;
float minSpeed = 2;
float maxSpeed = 5;
ArrayList<Cannon> cannonList;
boolean isGameOver = true;
int score = 0;
int scoreMultiplexer;
boolean isFirstGame = true;

void setup() {
  arduino = new Arduino(this, Arduino.list()[0], 57600);
  
  for(int i = 0; i < 8; i++)
    arduino.pinMode(speedPins[i], Arduino.OUTPUT);    

  arduino.pinMode(pinSwitch, Arduino.INPUT);
  arduino.pinMode(pinButton, Arduino.INPUT);

  initScene();
}

void initScene() {
  size(windowW, windowH);
}

void initCannon() {
  cannonList = new ArrayList<Cannon>();
  for(int i=0; i<maxCannonNum; i++) 
    createCannon();
}

void createCannon() {
  int orientation = floor(random(1, 5));
  float x, y;
  switch(orientation) {
    case 1: 
      x = -10;
      y = random(-10, windowH + 10);
      break;
    case 2: 
      x = windowW + 10;
      y = random(-10, windowH + 10);
      break;
    case 3: 
      y = -10;
      x = random(-10, windowW + 10);
      break;
    default:
      y = windowH + 10;
      x = random(-10, windowW + 10);
      break;
  }
  float speed = random(minSpeed, maxSpeed);
  float speedX = speed * (playerX - x) / sqrt(sq(x - playerX) + sq(y - playerY));
  float speedY = speed * (playerY - y) / sqrt(sq(x - playerX) + sq(y - playerY));
  Cannon cannon = new Cannon(x, y, speedX, speedY);
  cannonList.add(cannon);
}

void initGame() {
  playerX = floor(windowW/2);
  playerY = floor(windowH/2);
  initCannon();
  score = 0;
  scoreMultiplexer = 1;
  isFirstGame = false;
  isGameOver = false;
}

void draw() {
  drawScene();
  if(isGameOver) {
    textSize(30);
    fill(250, 160, 0);
    if(!isFirstGame)
      text("Last score: " + score, floor(windowW/3), floor(windowH/2));
    text("<Press to start>", floor(windowW/3), floor(windowH/2 + 50));

    int btnValue = arduino.digitalRead(pinButton);
    println(btnValue);
    if(btnValue != Arduino.LOW) 
        initGame();
  } else {
    updatePlayer();
    updateCanon();
    drawPlayer();
    drawCannon();
    updateScore();
    updateMultiplexer();
    delay(100);  
  }
}

void drawScene() {
  background(0);
}

void drawPlayer() {
  noStroke();
  fill(250,250,0);
  ellipse(playerX, playerY, playerRadius, playerRadius);
}

void drawCannon() {
  noStroke();
  fill(250,20,0);
  for(int i=0; i<cannonList.size(); i++) {
    Cannon cannon = cannonList.get(i);
    ellipse(cannon.x, cannon.y, cannon.r, cannon.r);
  }
}

void updatePlayer() {
  int sensorValueX = arduino.analogRead(pinX);
  int sensorValueY = arduino.analogRead(pinY);

  if(sensorValueX > 800 || sensorValueX < 200) 
    playerX -= (sensorValueX - 500)/100;
  if(sensorValueY > 800 || sensorValueY < 200) 
    playerY += (sensorValueY - 500)/100;
  //println("Sensor: ", sensorValueX, ", ", sensorValueY);
}

void updateCanon() {
  for(int i=cannonList.size()-1; i>=0; i--) {
    if (hitTest(cannonList.get(i))) {
      cannonList.remove(i);
      isGameOver = true;
      break;
    } 
    if (boundaryTest(cannonList.get(i))) {
      cannonList.remove(i);
      continue;
    }
    Cannon cannon = cannonList.get(i);
    cannon.x += cannon.sx;
    cannon.y += cannon.sy;
    cannonList.set(i, cannon);
  }

  if(cannonList.size() < maxCannonNum) {
    for(int i=0; i<maxCannonNum-cannonList.size(); i++)
      createCannon();
  }
}

void updateScore() {
  score += scoreMultiplexer;
  if(score > 50 && scoreMultiplexer == 1) {
    scoreMultiplexer++;
    maxCannonNum += 5;
  }
  else if(score > 125 && scoreMultiplexer == 2) {
    scoreMultiplexer++;
    maxCannonNum += 10;
  }
  else if(score > 300 && scoreMultiplexer == 3) {
    scoreMultiplexer++;
    maxCannonNum += 10;
  }
  else if(score > 600 && scoreMultiplexer == 4) {
    scoreMultiplexer++;
    maxCannonNum += 20;
  }
  else if(score > 1200 && scoreMultiplexer == 5) {
    scoreMultiplexer++;
    maxCannonNum += 20;
  }

  textSize(10);
  fill(240, 220, 0);
  text("Your Score: "+score, 10, windowH-20);
}

void updateMultiplexer() {
  for(int i = 0; i < 8; i++){
    arduino.digitalWrite(speedPins[i], data[scoreMultiplexer][i] == t ? Arduino.HIGH : Arduino.LOW);
  }
}

boolean hitTest(Cannon cannon) {
  if ( sqrt((cannon.x - playerX) * (cannon.x - playerX) + (cannon.y - playerY) * (cannon.y - playerY)) < (playerRadius + cannon.r)/2)
    return true;
  return false;
}

boolean boundaryTest(Cannon cannon) {
  if (cannon.x < -10 || cannon.y < -10 || cannon.x > windowW + 10 || cannon.y > windowH + 10)
    return true;
  return false;
}

void keyPressed() {
  if(isGameOver) {
    initGame();
  }
}

class Cannon {
  float x;
  float y;
  float sx; // Speed on x-axis
  float sy; // Speed on y-axis
  int r;

  Cannon(float x, float y, float sx, float sy) {
    this.x = x;
    this.y = y;
    this.sx = sx;
    this.sy = sy;
    this.r = 6;

    //println("Cannon created: ", x, ", ", y, ", ", sx, ", ", sy);
  }
};