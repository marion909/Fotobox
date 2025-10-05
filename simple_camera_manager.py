#!/usr/bin/env python3
"""
Einfacher Camera Manager für Fotobox
Nur gphoto2 CLI - bewährte, stabile Lösung
"""

import os
import subprocess
import datetime
import time
import threading
from config import config_manager

class SimpleCameraManager:
    """Einfacher, zuverlässiger Kamera-Manager mit nur gphoto2 CLI"""
    
    def __init__(self):
        self.config = config_manager.config
        self.camera_detected = False
        print("📷 Einfacher Camera Manager (gphoto2 CLI)")
        self.check_camera()
    
    def check_camera(self) -> bool:
        """Prüft, ob Kamera verbunden ist"""
        try:
            result = subprocess.run(['gphoto2', '--auto-detect'], 
                                  capture_output=True, text=True, check=True, timeout=10)
            self.camera_detected = "Canon" in result.stdout
            if self.camera_detected:
                print("✅ Canon EOS Kamera erkannt")
            else:
                print("⚠️ Keine Canon-Kamera gefunden")
            return self.camera_detected
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            self.camera_detected = False
            print("❌ gphoto2 nicht verfügbar oder Kamera-Problem")
            return False
    
    def get_camera_info(self):
        """Gibt einfache Kamera-Informationen zurück"""
        if not self.check_camera():
            return {'connected': False, 'model': None, 'api': 'gphoto2_cli'}
        
        try:
            result = subprocess.run(['gphoto2', '--auto-detect'], 
                                  capture_output=True, text=True, timeout=5)
            
            model = "Canon EOS"
            for line in result.stdout.split('\n'):
                if "Canon" in line and "usb:" in line:
                    parts = line.split()
                    if len(parts) >= 2:
                        model = " ".join(parts[:-1])
                    break
            
            return {
                'connected': True,
                'model': model,
                'api': 'gphoto2_cli',
                'status': 'ready'
            }
        except Exception as e:
            return {
                'connected': False,
                'model': None,
                'api': 'gphoto2_cli',
                'error': str(e)
            }
    
    def take_photo(self, filename=None, **kwargs):
        """Nimmt ein Foto auf mit bewährter 2-Schritt-Methode"""
        if not filename:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"photo_{timestamp}.jpg"
        
        filepath = os.path.join(self.config.photo_dir, filename)
        
        # Robuste 2-Schritt-Aufnahme mit mehreren Versuchen
        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                print(f"📸 Foto-Aufnahme Versuch {attempt}/{max_attempts}...")
                
                # Bei wiederholten Versuchen: Cleanup und Pause
                if attempt > 1:
                    print(f"⏳ Pause vor Versuch {attempt}...")
                    subprocess.run(['pkill', '-f', 'gphoto2'], capture_output=True)
                    time.sleep(3)
                
                # Schritt 1: Foto auf Kamera aufnehmen
                print("📷 Schritt 1: Foto aufnehmen...")
                capture_result = subprocess.run([
                    'gphoto2', '--capture-image'
                ], capture_output=True, text=True, check=True, timeout=20)
                
                print("✅ Foto auf Kamera gespeichert")
                
                # Schritt 2: Ins Zielverzeichnis wechseln und herunterladen
                print("💾 Schritt 2: Foto herunterladen...")
                original_dir = os.getcwd()
                
                try:
                    # Wechsle ins Photos-Verzeichnis
                    os.chdir(os.path.dirname(filepath))
                    
                    # Lade alle neuen Dateien herunter
                    download_result = subprocess.run([
                        'gphoto2', 
                        '--get-all-files',
                        '--delete-after'
                    ], capture_output=True, text=True, timeout=20)
                    
                    print("✅ Dateien heruntergeladen")
                    
                    # Finde die heruntergeladene Datei
                    photo_dir = os.path.dirname(filepath)
                    downloaded_files = []
                    
                    for file in os.listdir(photo_dir):
                        if (file.lower().startswith('capt') or file.lower().startswith('img_')) and \
                           file.lower().endswith('.jpg'):
                            downloaded_file = os.path.join(photo_dir, file)
                            if os.path.exists(downloaded_file) and os.path.getsize(downloaded_file) > 1000:
                                downloaded_files.append((downloaded_file, file))
                    
                    if downloaded_files:
                        # Verwende die neueste/größte Datei
                        downloaded_files.sort(key=lambda x: os.path.getmtime(x[0]), reverse=True)
                        source_file, original_name = downloaded_files[0]
                        
                        # Benenne um zum gewünschten Namen
                        os.rename(source_file, filepath)
                        print(f"✅ Datei umbenannt: {original_name} → {os.path.basename(filepath)}")
                        
                        # Prüfe finale Datei
                        if os.path.exists(filepath) and os.path.getsize(filepath) > 1000:
                            file_size = os.path.getsize(filepath)
                            print(f"✅ Foto erfolgreich: {filename} ({file_size} Bytes)")
                            
                            return {
                                'success': True,
                                'filename': filename,
                                'filepath': filepath,
                                'message': f'Foto erfolgreich aufgenommen! (Versuch {attempt})',
                                'attempts': attempt,
                                'api': 'gphoto2_cli',
                                'filesize': file_size
                            }
                        else:
                            raise Exception("Finale Datei ungültig")
                    else:
                        raise Exception("Keine gültige Fotodatei heruntergeladen")
                
                finally:
                    os.chdir(original_dir)
                    
            except subprocess.TimeoutExpired:
                print(f"⏰ Timeout bei Versuch {attempt}")
                subprocess.run(['pkill', '-9', '-f', 'gphoto2'], capture_output=True)
                if attempt == max_attempts:
                    return {
                        'success': False,
                        'message': f'Foto-Aufnahme nach {max_attempts} Versuchen fehlgeschlagen: Timeout'
                    }
                continue
                    
            except subprocess.CalledProcessError as e:
                error_msg = e.stderr.lower() if e.stderr else ""
                
                # PTP Device Busy Behandlung
                if "device busy" in error_msg or "0x2019" in error_msg:
                    print(f"⚠️ Device Busy bei Versuch {attempt}")
                    if attempt < max_attempts:
                        print("🔄 Führe Kamera-Reset durch...")
                        # Erweiterte Reset-Prozedur
                        subprocess.run(['pkill', '-f', 'gphoto2'], capture_output=True)
                        subprocess.run(['pkill', '-f', 'gvfs'], capture_output=True)
                        time.sleep(2)
                        continue
                    else:
                        return {
                            'success': False,
                            'message': f'Canon EOS Device Busy - Hardware-Reset erforderlich'
                        }
                else:
                    print(f"❌ gphoto2 Fehler bei Versuch {attempt}: {e.stderr}")
                    if attempt == max_attempts:
                        return {
                            'success': False,
                            'message': f'Kamera-Fehler: {e.stderr}'
                        }
                    continue
                        
            except FileNotFoundError:
                return {
                    'success': False,
                    'message': 'gphoto2 nicht installiert oder nicht im PATH'
                }
            except Exception as e:
                print(f"❌ Unerwarteter Fehler bei Versuch {attempt}: {e}")
                if attempt == max_attempts:
                    return {
                        'success': False,
                        'message': f'Unerwarteter Fehler: {str(e)}'
                    }
                continue
        
        # Falls alle Versuche fehlschlagen
        return {
            'success': False,
            'message': f'Foto-Aufnahme nach {max_attempts} Versuchen fehlgeschlagen'
        }

# Erstelle einfache Kamera-Instanz
simple_camera_manager = SimpleCameraManager()

# Backward-Kompatibilität für bestehenden Code
camera_manager = simple_camera_manager