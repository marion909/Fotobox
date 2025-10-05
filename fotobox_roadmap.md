
# 📸 Fotobox Projekt Roadmap

## 🧩 Ziel
Entwicklung einer anpassbaren Fotobox-Anwendung für Raspberry Pi mit Canon EOS 2000D, Touch-Display, Server-Upload und Fotodruck.

---

## 🔧 Hardware Setup
- [ ] Raspberry Pi 4 (oder 3B+) mit Touchdisplay
- [ ] Canon EOS 2000D per USB verbunden
- [ ] Kompatibler Fotodrucker (CUPS-Unterstützung)
- [ ] Netzteil, SD-Karte, stabile Stromversorgung

---

## 💻 Software & Tools
- [ ] Raspberry Pi OS / Raspbian installieren
- [ ] Pakete: `git`, `python3`, `pip`, `gphoto2`, `cups`, `chromium-browser`
- [ ] Kamera-Test mit `gphoto2 --auto-detect`
- [ ] CUPS Drucker konfigurieren (`http://localhost:631`)

---

## 🧠 Entwicklungsphasen

### Phase 1 – Grundfunktion ✅ ABGESCHLOSSEN
- [x] Einrichtung von `gphoto2` für Kameraauslösung ✅
- [x] Testbild aufnehmen und lokal speichern ✅
- [x] Flask-App zur Steuerung (Touch-UI) ✅
- [x] Anzeige der aufgenommenen Fotos im Browser ✅

### Phase 2 – Erweiterungen ✅ ABGESCHLOSSEN
- [x] Overlay/Branding (Logo, Text, Rahmen) ✅
- [x] Automatisches Drucken (via `lp`) ✅
- [x] Upload auf Server (HTTP/SFTP) ✅
- [x] Konfigurierbare Themes ✅

### Phase 3 – Kiosk & Deployment ✅ ABGESCHLOSSEN
- [x] Autostart-Service (systemd) ✅
- [x] Chromium im Vollbild-Kioskmodus starten ✅
- [x] Lokale Speicherung und Backup-Optionen ✅
- [x] Admin-Menü für Konfiguration (API-Key, Design, System) ✅
- [x] Komplettes System-Setup Script für Raspberry Pi ✅
- [x] Hardware-Test und Monitoring-Tools ✅
- [x] Server-Upload PHP-System mit Web-Galerie ✅

### Phase 4 – Erweiterte Features 🔄 IN ARBEIT
- [x] **4.1 Countdown mit Live-Preview** ✅ ABGESCHLOSSEN
  - [x] Konfigurierbarer Countdown (1-10 Sekunden)
  - [x] Animierte Full-Screen Countdown-Anzeige
  - [x] Responsive Design mit Farbwechsel
  - [x] Verschiedene Nachrichten je Countdown-Stufe
  - [x] ESC zum Abbrechen, Flash-Effekt beim Auslösen
  - [x] Admin-Interface für Countdown-Einstellungen
  - [x] API für Countdown-Konfiguration
- [ ] **4.2 QR-Code für Downloadlink** 🔄 NÄCHSTES FEATURE
- [ ] **4.3 Mehrfachaufnahme / Collage / GIF-Modus**
- [ ] **4.4 Nutzerwahl von Layouts & Filtern**

---

## ☁️ Server Upload
- [ ] HTTP POST Endpoint einrichten (`/upload`)
- [ ] Authentifizierung mit API-Key oder Token
- [ ] Datei speichern unter `/uploads/yyyy/mm/dd/`
- [ ] Rückgabe einer öffentlichen URL

---

## 🖨️ Drucken
- [ ] Drucker via `lpadmin` hinzufügen
- [ ] Testdruck `lp test.jpg`
- [ ] Skalierung auf 10x15 cm (1200x1800 px)
- [ ] Integration in Flask-App

---

## 🧰 Nächste Schritte
1. [ ] Hardware verbinden und testen
2. [ ] Basis-App starten und Kamera prüfen
3. [ ] Overlay-Design und Upload konfigurieren
4. [ ] Drucker anpassen und testen
5. [ ] Kiosk-Autostart einrichten
6. [ ] Design & Branding finalisieren


© 2025 – Fotobox Projekt by ChatGPT & User
