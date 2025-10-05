#!/usr/bin/env python3
"""
Optimaler Camera Manager für Photobox
Nur gphoto2 Python - beste Balance aus Einfachheit und Zuverlässigkeit
"""

import os
import datetime
import time
from config import config_manager

try:
    import gphoto2 as gp
    GPHOTO2_AVAILABLE = True
    print("✅ gphoto2 Python verfügbar")
except ImportError:
    GPHOTO2_AVAILABLE = False
    print("❌ gphoto2 Python nicht verfügbar - Installation erforderlich")

class OptimalCameraManager:
    """Optimaler Kamera-Manager mit nur gphoto2 Python"""
    
    def __init__(self):
        self.config = config_manager.config
        self.camera = None
        self.camera_detected = False
        
        if not GPHOTO2_AVAILABLE:
            print("⚠️ gphoto2 Python fehlt. Installation: pip install gphoto2")
            return
            
        print("📷 Optimaler Camera Manager (gphoto2 Python)")
        self.check_camera()
    
    def check_camera(self) -> bool:
        """Prüft und initialisiert Kamera-Verbindung"""
        if not GPHOTO2_AVAILABLE:
            self.camera_detected = False
            return False
            
        try:
            # Alte Verbindung schließen falls vorhanden
            if self.camera:
                try:
                    self.camera.exit()
                except:
                    pass
                self.camera = None
            
            # Neue Kamera-Instanz
            self.camera = gp.Camera()
            self.camera.init()
            
            # Test ob Kamera antwortet
            config = self.camera.get_config()
            self.camera_detected = True
            print("✅ Canon EOS Kamera verbunden (gphoto2 Python)")
            return True
            
        except gp.GPhoto2Error as e:
            self.camera_detected = False
            if "not found" in str(e).lower():
                print("⚠️ Keine Kamera gefunden")
            elif "busy" in str(e).lower():
                print("⚠️ Kamera busy - versuche Reset...")
                self._reset_camera_connection()
                return self.check_camera()  # Rekursiver Retry
            else:
                print(f"❌ Kamera-Fehler: {e}")
            return False
        except Exception as e:
            self.camera_detected = False
            print(f"❌ Unerwarteter Kamera-Fehler: {e}")
            return False
    
    def _reset_camera_connection(self):
        """Reset bei Kamera-Problemen"""
        try:
            if self.camera:
                self.camera.exit()
        except:
            pass
        self.camera = None
        time.sleep(2)
    
    def get_camera_info(self):
        """Gibt Kamera-Informationen zurück"""
        if not self.check_camera():
            return {
                'connected': False, 
                'model': None, 
                'api': 'gphoto2_python',
                'available': GPHOTO2_AVAILABLE
            }
        
        try:
            # Kamera-Modell ermitteln
            summary = self.camera.get_summary()
            model_line = str(summary).split('\n')[0] if summary else "Canon EOS"
            
            return {
                'connected': True,
                'model': model_line.strip(),
                'api': 'gphoto2_python',
                'status': 'ready',
                'available': True
            }
        except Exception as e:
            return {
                'connected': self.camera_detected,
                'model': 'Canon EOS (gphoto2)',
                'api': 'gphoto2_python', 
                'error': str(e)
            }
    
    def start_live_preview(self):
        """Startet Live-Vorschau der Kamera"""
        if not GPHOTO2_AVAILABLE:
            # Fallback für Demo/Test ohne gphoto2
            print("🎬 Demo-Modus: Live-Vorschau simuliert (gphoto2 nicht verfügbar)")
            return {
                'success': True,
                'message': 'Demo Live-Vorschau aktiviert',
                'demo_mode': True
            }
        
        if not self.camera_detected:
            return {
                'success': False,
                'message': 'Kamera nicht verbunden'
            }
        
        try:
            # Live View aktivieren
            config = self.camera.get_config()
            viewfinder = config.get_child_by_name('viewfinder')
            viewfinder.set_value(1)
            self.camera.set_config(config)
            
            return {
                'success': True,
                'message': 'Live-Vorschau aktiviert'
            }
        except Exception as e:
            print(f"❌ Live-Vorschau Fehler: {e}")
            return {
                'success': False, 
                'message': f'Live-Vorschau nicht möglich: {e}'
            }
    
    def stop_live_preview(self):
        """Stoppt Live-Vorschau der Kamera"""
        if not GPHOTO2_AVAILABLE or not self.camera_detected:
            return
        
        try:
            # Live View deaktivieren
            config = self.camera.get_config()
            viewfinder = config.get_child_by_name('viewfinder')
            viewfinder.set_value(0)
            self.camera.set_config(config)
        except Exception as e:
            print(f"⚠️ Fehler beim Stoppen der Live-Vorschau: {e}")
    
    def capture_preview_image(self):
        """Erfasst ein Preview-Bild für Live-Ansicht"""
        if not GPHOTO2_AVAILABLE:
            # Demo-Modus: Erstelle ein Platzhalter-Preview-Bild
            return self._create_demo_preview_image()
        
        if not self.camera_detected:
            return None
        
        try:
            # Preview-Bild aufnehmen
            camera_file = self.camera.capture_preview()
            file_data = camera_file.get_data_and_size()
            
            # Als temporäre Datei speichern
            preview_path = os.path.join(self.config.photo_dir, 'live_preview.jpg')
            with open(preview_path, 'wb') as f:
                f.write(file_data)
            
            return preview_path
        except Exception as e:
            print(f"❌ Preview-Aufnahme Fehler: {e}")
            return self._create_demo_preview_image()
    
    def _create_demo_preview_image(self):
        """Erstellt ein Demo-Preview-Bild für Test/Demo-Zwecke"""
        try:
            from PIL import Image, ImageDraw, ImageFont
            import io
            
            # Erstelle Demo-Bild (640x480)
            img = Image.new('RGB', (640, 480), color='#2C3E50')
            draw = ImageDraw.Draw(img)
            
            # Aktuelle Zeit für animierte Demo
            current_time = datetime.datetime.now()
            time_str = current_time.strftime("%H:%M:%S")
            
            # Zeichne Demo-Interface
            draw.rectangle([50, 50, 590, 430], fill='#34495E', outline='#ECF0F1', width=3)
            
            # Titel
            try:
                # Versuche systemspezifische Schrift zu laden
                font_large = ImageFont.truetype("arial.ttf", 36)
                font_medium = ImageFont.truetype("arial.ttf", 24)
                font_small = ImageFont.truetype("arial.ttf", 16)
            except:
                # Fallback zu Default-Font
                font_large = ImageFont.load_default()
                font_medium = ImageFont.load_default()
                font_small = ImageFont.load_default()
            
            # Demo-Text
            draw.text((320, 120), "📷 LIVE PREVIEW", font=font_large, anchor="mm", fill='#ECF0F1')
            draw.text((320, 180), "Canon EOS Demo", font=font_medium, anchor="mm", fill='#BDC3C7')
            draw.text((320, 220), f"Zeit: {time_str}", font=font_small, anchor="mm", fill='#95A5A6')
            
            # Animierte Elemente
            seconds = current_time.second
            for i in range(0, 360, 30):
                if (i // 30) <= (seconds // 5):
                    x = 320 + 80 * (i / 360) * 3.14159 
                    y = 280 + 20 * ((i + seconds * 6) % 360 / 360)
                    draw.circle([x, y], 3, fill='#3498DB')
            
            draw.text((320, 350), "Demo-Modus aktiv", font=font_medium, anchor="mm", fill='#E74C3C')
            draw.text((320, 380), "Installieren Sie gphoto2 für echte Kamera", font=font_small, anchor="mm", fill='#95A5A6')
            
            # Speichere als Preview-Datei
            preview_path = os.path.join(self.config.photo_dir, 'live_preview.jpg')
            img.save(preview_path, 'JPEG', quality=85)
            
            return preview_path
            
        except Exception as e:
            print(f"❌ Demo-Preview Fehler: {e}")
            return None

    def take_photo(self, filename=None, **kwargs):
        """Nimmt ein Foto auf mit gphoto2 Python"""
        if not GPHOTO2_AVAILABLE:
            return {
                'success': False,
                'message': 'gphoto2 Python nicht installiert. Führe aus: pip install gphoto2'
            }
        
        if not filename:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"photo_{timestamp}.jpg"
        
        filepath = os.path.join(self.config.photo_dir, filename)
        
        # Mehrere Versuche mit intelligenter Fehlerbehandlung
        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                print(f"📸 Foto-Aufnahme Versuch {attempt}/{max_attempts} (gphoto2 Python)...")
                
                # Stelle sicher dass Kamera verbunden ist
                if not self.camera_detected:
                    if not self.check_camera():
                        if attempt == max_attempts:
                            return {
                                'success': False,
                                'message': 'Keine Kamera gefunden'
                            }
                        continue
                
                # Foto aufnehmen
                print("📷 Löse Kamera aus...")
                file_path = self.camera.capture(gp.GP_CAPTURE_IMAGE)
                print(f"✅ Foto aufgenommen: {file_path.folder}/{file_path.name}")
                
                # Datei von Kamera herunterladen
                print("💾 Lade Foto herunter...")
                camera_file = self.camera.file_get(
                    file_path.folder, 
                    file_path.name, 
                    gp.GP_FILE_TYPE_NORMAL
                )
                
                # Speichere Datei lokal
                camera_file.save(filepath)
                print(f"💾 Foto gespeichert: {filepath}")
                
                # Optional: Datei von Kamera löschen
                try:
                    self.camera.file_delete(file_path.folder, file_path.name)
                    print("🗑️ Foto von Kamera entfernt")
                except:
                    pass  # Nicht kritisch wenn Löschen fehlschlägt
                
                # Prüfe ob Datei korrekt gespeichert wurde
                if os.path.exists(filepath) and os.path.getsize(filepath) > 1000:
                    file_size = os.path.getsize(filepath)
                    print(f"✅ Foto erfolgreich: {filename} ({file_size} Bytes)")
                    
                    return {
                        'success': True,
                        'filename': filename,
                        'filepath': filepath,
                        'message': f'Foto erfolgreich aufgenommen! (gphoto2 Python, Versuch {attempt})',
                        'attempts': attempt,
                        'api': 'gphoto2_python',
                        'filesize': file_size
                    }
                else:
                    raise Exception("Foto-Datei nicht korrekt gespeichert")
                    
            except gp.GPhoto2Error as e:
                error_code = getattr(e, 'code', 0)
                error_msg = str(e).lower()
                
                print(f"❌ gphoto2 Fehler bei Versuch {attempt}: {e}")
                
                # Spezielle Fehlerbehandlung
                if "busy" in error_msg or error_code == -110:
                    print("⚠️ Kamera busy - Reset Verbindung...")
                    self._reset_camera_connection()
                    time.sleep(2)
                elif "not found" in error_msg:
                    print("⚠️ Kamera getrennt - versuche Reconnect...")
                    self._reset_camera_connection()
                elif "timeout" in error_msg:
                    print("⚠️ Timeout - versuche erneut...")
                    time.sleep(1)
                
                if attempt == max_attempts:
                    return {
                        'success': False,
                        'message': f'gphoto2 Fehler: {str(e)}'
                    }
                continue
                
            except Exception as e:
                print(f"❌ Unerwarteter Fehler bei Versuch {attempt}: {e}")
                
                if attempt < max_attempts:
                    # Reset bei unbekannten Fehlern
                    self._reset_camera_connection()
                    time.sleep(2)
                    continue
                else:
                    return {
                        'success': False,
                        'message': f'Unerwarteter Fehler: {str(e)}'
                    }
        
        # Falls alle Versuche fehlschlagen
        return {
            'success': False,
            'message': f'Foto-Aufnahme nach {max_attempts} Versuchen fehlgeschlagen'
        }
    
    def cleanup(self):
        """Ressourcen aufräumen"""
        try:
            if self.camera:
                self.camera.exit()
                self.camera = None
                print("✅ Kamera-Verbindung geschlossen")
        except Exception as e:
            print(f"⚠️ Cleanup-Fehler: {e}")
    
    def __del__(self):
        """Destruktor - automatisches Cleanup"""
        self.cleanup()

# Erstelle optimale Kamera-Instanz
optimal_camera_manager = OptimalCameraManager()

# Backward-Kompatibilität
camera_manager = optimal_camera_manager