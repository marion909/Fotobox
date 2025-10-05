#!/usr/bin/env python3
"""
Camera Manager für Fotobox
Kamera-Controller für gphoto2 mit robuster Canon EOS Unterstützung
"""

import os
import subprocess
import datetime
import time
import threading
from config import config_manager

class CameraManager:
    """Kamera-Controller für gphoto2"""
    
    def __init__(self):
        self.config = config_manager.config
        self.camera_detected = False
        self.check_camera()
    
    def check_camera(self):
        """Prüft, ob Kamera verbunden ist"""
        try:
            result = subprocess.run(['gphoto2', '--auto-detect'], 
                                  capture_output=True, text=True, check=True)
            self.camera_detected = "Canon" in result.stdout
            return self.camera_detected
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.camera_detected = False
            return False
    
    def get_camera_info(self):
        """Gibt detaillierte Kamera-Informationen zurück"""
        if not self.check_camera():
            return {'connected': False, 'model': None}
            
        try:
            # Kamera-Modell ermitteln
            result = subprocess.run(['gphoto2', '--auto-detect'], 
                                  capture_output=True, text=True, check=True)
            
            model = "Unbekannt"
            for line in result.stdout.split('\n'):
                if "Canon" in line and "usb:" in line:
                    parts = line.split()
                    if len(parts) >= 2:
                        model = " ".join(parts[:-1])  # Alle Teile außer USB-Port
                    break
            
            return {
                'connected': True,
                'model': model,
                'status': 'ready'
            }
        except Exception as e:
            return {
                'connected': False,
                'model': None,
                'error': str(e)
            }
    
    def take_photo(self, filename=None, apply_overlays=True, auto_print=None, auto_upload=None):
        """Nimmt ein Foto auf mit robuster Canon EOS Device-Busy-Behandlung"""
        if not filename:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"photo_{timestamp}.jpg"
        
        filepath = os.path.join(self.config.photo_dir, filename)
        
        # Robuste Foto-Aufnahme mit mehreren Versuchen
        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                print(f"📸 Foto-Aufnahme Versuch {attempt}/{max_attempts}...")
                
                # Bei wiederholten Versuchen: Kurze Pause und gphoto2-Prozesse beenden
                if attempt > 1:
                    print(f"⏳ Warte 2 Sekunden vor Versuch {attempt}...")
                    time.sleep(2)
                    # Alte gphoto2-Prozesse beenden die eventuell hängen
                    subprocess.run(['pkill', '-f', 'gphoto2'], capture_output=True)
                    time.sleep(1)
                
                # ROBUST: 2-Schritt-Methode (Canon EOS funktioniert besser so)
                print(f"🔧 Verwende 2-Schritt-Capture-Methode...")
                
                # Schritt 1: Foto auf Kamera aufnehmen
                capture_result = subprocess.run([
                    'gphoto2', '--capture-image'
                ], capture_output=True, text=True, check=True, timeout=15)
                
                print(f"📸 Capture-Ergebnis: {capture_result.stdout}")
                
                # Schritt 2: Ins Zielverzeichnis wechseln und herunterladen
                original_dir = os.getcwd()
                try:
                    os.chdir(os.path.dirname(filepath))
                    filename_only = os.path.basename(filepath)
                    
                    # Alle neuen Dateien herunterladen
                    download_result = subprocess.run([
                        'gphoto2', 
                        '--get-all-files',
                        '--delete-after'
                    ], capture_output=True, text=True, timeout=15)
                    
                    print(f"💾 Download-Ergebnis: {download_result.stdout}")
                    
                    # Finde die heruntergeladene Datei (meist capt0000.jpg o.ä.)
                    photo_dir = os.path.dirname(filepath)
                    for file in os.listdir(photo_dir):
                        if file.lower().startswith('capt') and file.lower().endswith('.jpg'):
                            downloaded_file = os.path.join(photo_dir, file)
                            if os.path.exists(downloaded_file) and os.path.getsize(downloaded_file) > 1000:
                                # Benenne um zum gewünschten Dateinamen
                                os.rename(downloaded_file, filepath)
                                print(f"✅ Datei umbenannt: {file} → {filename_only}")
                                break
                    
                finally:
                    os.chdir(original_dir)
                
                # Prüfe ob Datei wirklich erstellt wurde und gültige Größe hat
                if os.path.exists(filepath) and os.path.getsize(filepath) > 1000:  # Min. 1KB
                    print(f"✅ Foto erfolgreich aufgenommen: {filename}")
                    
                    response = {
                        'success': True,
                        'filename': filename,
                        'filepath': filepath,
                        'message': f'Foto erfolgreich aufgenommen! (Versuch {attempt})',
                        'attempts': attempt,
                        'overlay_applied': False,
                        'print_queued': False,
                        'upload_queued': False
                    }
                    
                    # Phase 2: Overlays anwenden (falls verfügbar)
                    if apply_overlays and hasattr(self.config, 'overlay') and self.config.overlay.enabled:
                        try:
                            # Importiere overlay_manager nur wenn benötigt
                            from overlay_manager import OverlayManager
                            overlay_manager = OverlayManager(self.config)
                            overlay_path = overlay_manager.apply_overlays(filepath)
                            response['overlay_applied'] = True
                            response['overlay_path'] = overlay_path
                            response['message'] += ' Overlay angewendet.'
                        except Exception as e:
                            print(f"⚠️ Overlay-Fehler: {e}")
                    
                    # Phase 2: Automatisches Drucken (falls verfügbar)
                    if (auto_print or (hasattr(self.config, 'printing') and self.config.printing.auto_print)) and \
                       hasattr(self.config, 'printing') and self.config.printing.enabled:
                        threading.Thread(target=self._async_print, args=(filepath,)).start()
                        response['print_queued'] = True
                        response['message'] += ' Druck eingeplant.'
                    
                    # Phase 2: Automatischer Upload (falls verfügbar)
                    if (auto_upload or (hasattr(self.config, 'upload') and self.config.upload.auto_upload)) and \
                       hasattr(self.config, 'upload') and self.config.upload.enabled:
                        threading.Thread(target=self._async_upload, args=(filepath,)).start()
                        response['upload_queued'] = True  
                        response['message'] += ' Upload eingeplant.'
                    
                    return response
                else:
                    raise Exception("Foto-Datei nicht erstellt oder zu klein")
                    
            except subprocess.TimeoutExpired:
                print(f"⏰ Timeout bei Versuch {attempt} - gphoto2 hängt")
                # Hängende Prozesse beenden
                subprocess.run(['pkill', '-9', '-f', 'gphoto2'], capture_output=True)
                if attempt < max_attempts:
                    continue
                else:
                    return {
                        'success': False,
                        'message': f'Foto-Aufnahme nach {max_attempts} Versuchen fehlgeschlagen: Timeout'
                    }
                    
            except subprocess.CalledProcessError as e:
                error_msg = e.stderr.lower() if e.stderr else ""
                
                # Spezielle Behandlung für "Device Busy" Fehler
                if "device busy" in error_msg or "0x2019" in error_msg:
                    print(f"⚠️ Device Busy Fehler bei Versuch {attempt}")
                    if attempt < max_attempts:
                        print("🔄 Führe Camera-Reset durch...")
                        # Erweiterte Reset-Prozedur
                        subprocess.run(['pkill', '-f', 'gphoto2'], capture_output=True)
                        time.sleep(1)
                        # Versuche USB-Reset (falls Root-Rechte vorhanden)
                        try:
                            subprocess.run(['bash', 'scripts/fix_camera_busy.sh', '--reset'], 
                                         capture_output=True, timeout=10)
                        except:
                            pass  # Falls Script nicht verfügbar
                        continue
                    else:
                        return {
                            'success': False,
                            'message': f'Canon EOS Device Busy Fehler - Versuche: bash scripts/fix_camera_busy.sh --reset'
                        }
                else:
                    print(f"❌ gphoto2 Fehler bei Versuch {attempt}: {e.stderr}")
                    if attempt < max_attempts:
                        continue
                    else:
                        return {
                            'success': False,
                            'message': f'Kamera-Fehler nach {max_attempts} Versuchen: {e.stderr}'
                        }
                        
            except FileNotFoundError:
                return {
                    'success': False,
                    'message': 'gphoto2 nicht installiert oder nicht im PATH'
                }
            except Exception as e:
                print(f"❌ Unerwarteter Fehler bei Versuch {attempt}: {e}")
                if attempt < max_attempts:
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
    
    def _async_print(self, filepath):
        """Asynchrones Drucken"""
        try:
            time.sleep(1)  # Kurze Verzögerung
            from print_manager import PrintManager
            print_manager = PrintManager(self.config)
            result = print_manager.print_photo(filepath)
            print(f"🖨️ Druck-Ergebnis: {result['message']}")
        except Exception as e:
            print(f"❌ Druck-Fehler: {e}")
    
    def _async_upload(self, filepath):
        """Asynchroner Upload"""
        try:
            time.sleep(2)  # Kurze Verzögerung
            from upload_manager import UploadManager
            upload_manager = UploadManager(self.config)
            result = upload_manager.upload_photo(filepath)
            print(f"☁️ Upload-Ergebnis: {result['message']}")
        except Exception as e:
            print(f"❌ Upload-Fehler: {e}")

# Standardinstanz für Import
camera_manager = CameraManager()