import de.fhpotsdam.unfolding.*;
import de.fhpotsdam.unfolding.geo.*;
import de.fhpotsdam.unfolding.marker.*;
import de.fhpotsdam.unfolding.providers.*;
import de.fhpotsdam.unfolding.utils.*;
import processing.data.Table;
import processing.data.TableRow;
import java.util.List;
import java.util.ArrayList;
import ddf.minim.*;

UnfoldingMap map;
List<SimplePointMarker> markers = new ArrayList<SimplePointMarker>();

int phase = 0; // 0 - animacja, 1 - przejście, 2 - czarny ekran, 3 - ekran z przyciskami, 4 - mapa
int stage = 0; // Etapy animacji: 0 - śmiech, 1 - pistolet, 2 - strzelanie
int shootFrame = 0; // Licznik strzałów
boolean firstPersonShot = false; // Czy pierwsza osoba została postrzelona
boolean secondPersonShot = false; // Czy druga osoba została postrzelona
int fade = 0; // Do przejścia między fazami
boolean fadingOut = true; // Sterowanie przejściem
PImage bgImage;

// Zmienna do czarnego ekranu
int blackScreenFrame = 0; // Licznik klatek dla czarnego ekranu
int blackScreenDuration = 240; // Liczba klatek do wyświetlenia czarnego ekranu

// Przycisk
class Button {
  float x, y, w, h;
  String label;
  
  Button(float x, float y, float w, float h, String label) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
  }
  
  boolean isMouseInside() {
    return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
  }
  
  void display() {
    fill(200);
    rect(x, y, w, h, 10);
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(16);
    text(label, x + w/2, y + h/2);
  }
}

Button buttonMap;
Button buttonOther;
Button buttonBack;


// Dźwięki
Minim minim;
AudioPlayer backgroundMusic;
AudioPlayer gunshotSound;
AudioPlayer mapMusic;

void setup() {
  size(1000, 800);

  // Ładowanie obrazu tła
  bgImage = loadImage("10.jpg");
  if (bgImage == null) {
    println("Obraz nie został załadowany! Upewnij się, że znajduje się w folderze 'data' i ma poprawną nazwę.");
    exit();
  }

  // Inicjalizacja Minim i ładowanie dźwięków
  minim = new Minim(this);
  backgroundMusic = minim.loadFile("background_music.mp3");
  gunshotSound = minim.loadFile("gunshot.mp3");
  mapMusic = minim.loadFile("map_music.mp3");

  backgroundMusic.loop(); // Odtwarzanie muzyki w tle

  // Konfiguracja mapy
  map = new UnfoldingMap(this, new Microsoft.AerialProvider());
  map.zoomToLevel(4);
  map.panTo(new Location(37.0902, -95.7129)); // Centrum mapy USA
  MapUtils.createDefaultEventDispatcher(this, map);

  // Wczytaj dane z pliku CSV
  Table table = loadTable("school-shootings-data.csv", "header");
  
  if (table == null) {
    println("Tabela nie została załadowana! Upewnij się, że znajduje się w folderze 'data' i ma poprawną nazwę.");
    exit();
  } else {
    println("Tabela załadowana poprawnie. Liczba wierszy: " + table.getRowCount());
    for (int i = 0; i < min(5, table.getRowCount()); i++) {
      TableRow row = table.getRow(i);
      println("Wiersz " + i + ": lat=" + row.getFloat("lat") + ", long=" + row.getFloat("long"));
    }
  }

  for (TableRow row : table.rows()) {
    float latitude = row.getFloat("lat");
    float longitude = row.getFloat("long");
    String schoolName = row.getString("school_name");
    String date = row.getString("date");
    String time = row.getString("time");
    String killed = row.getString("killed");
    String injured = row.getString("injured");
    String casualties = row.getString("casualties");
    String ageShooter1 = row.getString("age_shooter1");
    String genderShooter1 = row.getString("gender_shooter1");
    String shooterRelationship1 = row.getString("shooter_relationship1");
    String deceasedNotes1 = row.getString("deceased_notes1");
    String weapon = row.getString("weapon");
    String weaponSource = row.getString("weapon_source");

    // Tworzenie lokalizacji markera
    Location location = new Location(latitude, longitude);
    SimplePointMarker marker = new SimplePointMarker(location);

    // Personalizacja markera
    marker.setColor(color(255, 0, 0, 150));
    marker.setRadius(map(row.getInt("casualties"), 1, 50, 5, 20));

    // Szczegóły do wyświetlenia po kliknięciu
    String details = "Nazwa szkoły: " + schoolName + "\n" +
                     "Data: " + date + "\n" +
                     "Godzina: " + time + "\n" +
                     "Zabici: " + killed + "\n" +
                     "Ranni: " + injured + "\n" +
                     "Ofiary łącznie: " + casualties + "\n" +
                     "Wiek strzelca: " + ageShooter1 + "\n" +
                     "Płeć strzelca: " + genderShooter1 + "\n" +
                     "Kim był strzelec: " + shooterRelationship1 + "\n" +
                     "Uwagi nt. śmierci strzelca: " + deceasedNotes1 + "\n" +
                     "Broń: " + weapon + "\n" +
                     "Źródło broni: " + weaponSource;

    marker.setId(details);

    markers.add(marker);
    map.addMarker(marker);
  }

  // Inicjalizacja przycisków
  buttonMap = new Button(width/2 - 160, height/2 + 50, 150, 50, "Pokaż mapę");
  buttonOther = new Button(width/2 + 10, height/2 + 50, 150, 50, "Gra");
  buttonBack = new Button(20, 20, 100, 40, "Powrót");

}

void draw() {
  if (phase == 0) {
    // Animacja
    playAnimation();
  } else if (phase == 1) {
    // Przejście
    transitionScreen();
  } else if (phase == 2) {
    // Czarny ekran z napisami
    showBlackScreen();
  } else if (phase == 3) {
    // Nowy ekran z przyciskami
    showNewScreen();
    if (backgroundMusic.isPlaying()) {
      backgroundMusic.pause();
    }
    if (!mapMusic.isPlaying()) {
      mapMusic.loop();
    }
  } else if (phase == 4) {
    // Zatrzymanie muzyki animacji i włączenie muzyki mapy
    if (backgroundMusic.isPlaying()) {
      backgroundMusic.pause();
    }
    if (!mapMusic.isPlaying()) {
      mapMusic.loop();
    }

    // Rysowanie mapy
    drawMap();
  }

}

void playAnimation() {
  background(200); 
  image(bgImage, 0, 0, width, height);

  if (stage == 0) {
    laughingScene();
  } else if (stage == 1) {
    takingGunScene();
  } else if (stage == 2) {
    shootingScene();
  }
}

void transitionScreen() {
  if (fadingOut) {
    fade += 5;
    if (fade >= 255) {
      fadingOut = false;
    }
  } else {
    fade -= 5;
    if (fade <= 0) {
      phase = 2; // Przejście do czarnego ekranu
      blackScreenFrame = 0; // Reset licznika klatek
      fadingOut = true; // Reset fadingOut
    }
  }

  fill(0, fade);
  rect(0, 0, width, height); // Czarna nakładka
}

Marker selectedMarker = null;

void drawMap() {
  background(240); // Czyszczenie tła
  map.draw(); // Rysowanie mapy

  Marker hoveredMarker = null;

  // Znajdź marker pod kursorem
  for (Marker marker : map.getMarkers()) {
    if (marker.isInside(map, mouseX, mouseY)) {
      hoveredMarker = marker;
      break;
    }
  }

  // Wyświetlanie tooltipa tylko gdy okno szczegółów nie jest otwarte
  if (hoveredMarker != null && selectedMarker == null) {
    String[] basicInfo = hoveredMarker.getId().split("\n");
    String summary = basicInfo[0] + "\n" + basicInfo[1]; // Pobieramy "Nazwa szkoły" i "Data"

    float padding = 10; // Odstęp wokół tekstu
    textSize(12);
    float textWidthValue = 0;
    for (String line : basicInfo) {
      textWidthValue = max(textWidthValue, textWidth(line));
    }
    float rectWidth = textWidthValue + 2 * padding; // Szerokość ramki
    float lineHeight = 18; // Wysokość jednej linii tekstu z odstępem
    float rectHeight = 2 * lineHeight + 2 * padding; // Dla dwóch linii tekstu z większym odstępem

    // Rysowanie ramki
    fill(255);
    stroke(0);
    rect(mouseX, mouseY - rectHeight, rectWidth, rectHeight);

    // Rysowanie tekstu w ramce
    fill(0);
    textAlign(LEFT, TOP);
    text(summary, mouseX + padding, mouseY - rectHeight + padding);
  }

  // Wyświetlanie szczegółów, jeśli wybrano marker
  if (selectedMarker != null) {
    showDetails(selectedMarker);
  }

  // Wyświetlenie przycisku powrotu
  buttonBack.display();
}


void mousePressed() {
  if (phase == 2) {
    // Czarny ekran z napisem
  } else if (phase == 3) {
    // Wybór opcji na nowym ekranie
    if (buttonMap.isMouseInside()) {
      phase = 4; // Przejście do mapy
    } else if (buttonOther.isMouseInside()) {
      // Przejście do gry
      Game();
    }
  }else if (phase == 4) {
    // Obsługa markerów na mapie
    boolean clickedOnMarker = false;

    for (Marker marker : map.getMarkers()) {
      if (marker.isInside(map, mouseX, mouseY)) {
        selectedMarker = marker;
        clickedOnMarker = true;
        break;
      }
    }

    if (!clickedOnMarker) {
      selectedMarker = null;
    }

    // Obsługa kliknięcia przycisku powrotu
    if (buttonBack.isMouseInside()) {
      phase = 3; // Przejście do ekranu wyboru
    }
}

}

void showDetails(Marker marker) {
  fill(255); // Tło okna
  rect(100, 100, 600, 400, 10); // Prostokąt z zaokrąglonymi rogami

  fill(0); // Tekst w oknie
  textSize(14);
  textAlign(LEFT, TOP);

  // Wyświetlenie informacji przechowywanych w polu id
  String info = marker.getId();
  text(info, 120, 120, 560, 380); // Tekst w oknie

  // Przycisk zamknięcia
  fill(200); // Tło przycisku
  rect(670, 110, 20, 20, 5);
  fill(0); // Tekst przycisku
  textSize(16);
  textAlign(CENTER, CENTER);
  text("X", 680, 120);

  // Obsługa zamknięcia okna
  if (mousePressed && mouseX >= 670 && mouseX <= 690 && mouseY >= 110 && mouseY <= 130) {
    selectedMarker = null;
  }
}

void showBlackScreen() {
  background(0); // Czarny ekran

  // Ustawienia tekstu
  fill(255); // Biały kolor tekstu
  textAlign(CENTER, CENTER); // Wyśrodkowanie tekstu w poziomie i pionie

  // Główny tekst
  textSize(24); // Rozmiar głównego tekstu
  String mainText = "W 2023 roku w Stanach Zjednoczonych doszło do 656 masowych strzelanin";
  text(mainText, width / 2, height / 2 - 20); // Wyświetlenie tekstu na środku ekranu

  // Mniejszy tekst pod głównym
  textSize(16); // Rozmiar mniejszego tekstu
  String subText = "~ według Gun Violence Archive";
  text(subText, width / 2, height / 2 + 40); // Wyświetlenie mniejszego tekstu pod głównym

  // Zwiększ licznik klatek
  blackScreenFrame++;

  // Po osiągnięciu określonej liczby klatek przejdź do ekranu z przyciskami
  if (blackScreenFrame >= blackScreenDuration) {
    phase = 3; // Przejście do ekranu z przyciskami
    blackScreenFrame = 0; // Reset licznika klatek
  }
}



void showNewScreen() {
  background(0); // Kolor tła nowego ekranu

  // Duży napis na środku
  stroke(255);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(48);
  text("Wybierz Opcję", width / 2, height / 2 - 100);

  // Wyświetlenie przycisków
  buttonMap.display();
  buttonOther.display();
}


void Game() {
  
  
}

void stop() {
  backgroundMusic.close();
  gunshotSound.close();
  mapMusic.close();
  minim.stop();
  super.stop();
}

// Sceny animacji
void laughingScene() {
  drawPerson(630, 440, true, false);
  drawPerson(730, 440, true, false);
  drawPerson(680, 540, false, false);

  fill(0);
  textSize(35);
  text("Hahaha!", 570, 350);
  text("Hahaha!", 720, 350);

  if (frameCount > 180) {
    stage = 1;
  }
}

void takingGunScene() {
  drawPerson(630, 440, true, false);
  drawPerson(730, 440, true, false);
  drawPerson(680, 540, false, false);

  fill(0);
  textSize(35);
  text("...", 670, 455);
  drawGun(695, 530, 1);

  if (frameCount > 300) {
    stage = 2;
  }
}

void shootingScene() {
  drawPerson(630, 440, false, firstPersonShot); // Pierwsza postać
  drawPerson(730, 440, false, secondPersonShot); // Druga postać
  drawPerson(680, 540, false, false); // Wyśmiewany
  drawGun(695, 530, 1);

  if (shootFrame < 20) {
    // Pierwszy strzał
    strokeWeight(2);
    stroke(255, 0, 0);
    line(715, 550, 630, 440); // Strzał do pierwszej postaci
    firstPersonShot = true; // Pierwsza postać staje się "zabita"

    if (!gunshotSound.isPlaying()) {
      gunshotSound.rewind();
      gunshotSound.play();
    }
  } else if (shootFrame < 40) {
    // Drugi strzał
    strokeWeight(2);
    stroke(255, 0, 0);
    line(715, 550, 730, 440); // Strzał do drugiej postaci
    secondPersonShot = true; // Druga postać staje się "zabita"

  
      gunshotSound.rewind();
      gunshotSound.play();

  }

  shootFrame++; // Inkrementacja liczby klatek animacji

  if (shootFrame >= 40) {
    phase = 1; // Przejdź do fazy przejścia
  }
}


void drawPerson(float x, float y, boolean laughing, boolean dead){
  strokeWeight(3);
  fill(255, 200, 200);
  ellipse(x, y - 40, 50, 50);
  line(x, y - 15, x, y + 60);
  line(x, y + 60, x - 20, y + 120);
  line(x, y + 60, x + 20, y + 120);
  line(x, y + 30, x - 20, y + 10);
  line(x, y + 30, x + 20, y + 10);
  drawFace(x, y - 40, laughing, dead);
}

void drawFace(float x, float y, boolean laughing, boolean dead) {
  fill(0);
  if (dead) {
    line(x - 10, y - 10, x, y);
    line(x, y - 10, x - 10, y);
    line(x + 10, y - 10, x, y);
    line(x, y - 10, x + 10, y);
    line(x - 10, y + 10, x + 10, y + 10);
  } else if (laughing) {
    ellipse(x - 10, y - 10, 5, 5);
    ellipse(x + 10, y - 10, 5, 5);
    arc(x, y + 10, 20, 10, 0, PI);
  } else {
    ellipse(x - 10, y - 10, 5, 5);
    ellipse(x + 10, y - 10, 5, 5);
    line(x - 10, y + 10, x + 10, y + 10);
  }
}

void drawGun(float x, float y, float scale) {
  fill(50);
  rect(x, y, 15 * scale, 30 * scale);
  fill(100);
  rect(x + 15 * scale, y - 10 * scale, 40 * scale, 20 * scale);
  fill(80);
  rect(x + 55 * scale, y - 5 * scale, 30 * scale, 10 * scale);
  fill(0);
  ellipse(x + 10 * scale, y + 10 * scale, 10 * scale, 15 * scale);
}
