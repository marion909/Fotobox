
# 📸 Photobox Projekt Roadmap

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

### Phase 1 – Grundfunktion
- [ ] Einrichtung von `gphoto2` für Kameraauslösung
- [ ] Testbild aufnehmen und lokal speichern
- [ ] Flask-App zur Steuerung (Touch-UI)
- [ ] Anzeige der aufgenommenen Fotos im Browser

### Phase 2 – Erweiterungen
- [ ] Overlay/Branding (Logo, Text, Rahmen)
- [ ] Automatisches Drucken (via `lp`)
- [ ] Upload auf Server (HTTP/SFTP)
- [ ] Konfigurierbare Themes

### Phase 3 – Kiosk & Deployment
- [ ] Autostart-Service (systemd)
- [ ] Chromium im Vollbild-Kioskmodus starten
- [ ] Lokale Speicherung und Backup-Optionen
- [ ] Admin-Menü für Konfiguration (z. B. API-Key, Design)

### Phase 4 – Erweiterte Features (optional)
- [ ] Countdown mit Live-Preview
- [ ] QR-Code für Downloadlink
- [ ] Mehrfachaufnahme / Collage / GIF-Modus
- [ ] Nutzerwahl von Layouts & Filtern

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


© 2025 – Photobox Projekt by ChatGPT & User
