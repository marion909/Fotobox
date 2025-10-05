#!/usr/bin/env python3
"""
Modern Camera Manager für Photobox - Canon EDSDK Integration
Ersetzt gphoto2 für robustere Canon EOS Unterstützung
"""

import os
import sys
import time
import datetime
import threading
from typing import Dict, Optional, Any
from config import config_manager

# Prüfe verfügbare Kamera-APIs (Fallback-System)
CAMERA_APIS = {
    'edsdk': False,     # Canon EDSDK (beste Option)
    'gphoto2_py': False, # libgphoto2 Python bindings
    'gphoto2_cli': True  # gphoto2 Shell (Fallback)
}

# Teste verfügbare APIs
try:
    # Prüfe ob EDSDK-Verzeichnis existiert
    edsdk_path = os.path.join(os.path.dirname(__file__), 'EDSDK')
    if os.path.exists(edsdk_path):
        # Prüfe auf EDSDK DLL
        dll_files = [f for f in os.listdir(edsdk_path) if f.lower().endswith('.dll') and 'edsdk' in f.lower()]
        if dll_files:
            # Versuche unseren Wrapper zu importieren
            try:
                from canon_edsdk_wrapper import CanonEOSCamera
                CAMERA_APIS['edsdk'] = True
                print(f"✅ Canon EDSDK verfügbar (DLL: {dll_files[0]})")
            except ImportError as e:
                print(f"⚠️ Canon EDSDK Wrapper Fehler: {e}")
        else:
            print("⚠️ Canon EDSDK Verzeichnis gefunden, aber keine DLL")
    else:
        print("⚠️ Canon EDSDK Verzeichnis nicht gefunden")
except Exception as e:
    print(f"⚠️ Canon EDSDK Check Fehler: {e}")

try:
    import gphoto2 as gp
    CAMERA_APIS['gphoto2_py'] = True
    print("✅ gphoto2 Python API verfügbar")
except ImportError:
    print("⚠️ gphoto2 Python API nicht verfügbar")

class ModernCameraManager:
    """Moderne Kamera-Verwaltung mit mehreren API-Backends"""
    
    def __init__(self):
        self.config = config_manager.config
        self.camera_detected = False
        self.api_backend = self._select_best_api()
        self.camera_instance = None
        
        print(f"🎯 Verwende Kamera-API: {self.api_backend}")
        self._initialize_camera()
    
    def _select_best_api(self) -> str:
        """Wählt die beste verfügbare Kamera-API"""
        if CAMERA_APIS['edsdk']:
            return 'edsdk'
        elif CAMERA_APIS['gphoto2_py']:
            return 'gphoto2_py'
        else:
            return 'gphoto2_cli'
    
    def _initialize_camera(self):
        """Initialisiert die Kamera mit der gewählten API"""
        try:
            if self.api_backend == 'edsdk':
                self._init_canon_edsdk()
            elif self.api_backend == 'gphoto2_py':
                self._init_gphoto2_python()
            else:
                self._init_gphoto2_cli()
        except Exception as e:
            print(f"⚠️ Kamera-Initialisierung fehlgeschlagen: {e}")
            self.camera_detected = False
    
    def _init_canon_edsdk(self):
        """Initialisiert Canon EDSDK (beste Methode)"""
        try:
            import canon_edsdk
            
            # SDK initialisieren
            canon_edsdk.initialize_sdk()
            
            # Kamera finden
            cameras = canon_edsdk.get_camera_list()
            if cameras:
                self.camera_instance = cameras[0]
                self.camera_instance.open()
                self.camera_detected = True
                print("✅ Canon EDSDK: Kamera erfolgreich verbunden")
            else:
                print("❌ Canon EDSDK: Keine Kamera gefunden")
                
        except Exception as e:
            print(f"❌ Canon EDSDK Fehler: {e}")
            raise
    
    def _init_gphoto2_python(self):
        """Initialisiert gphoto2 Python API"""
        try:
            import gphoto2 as gp
            
            # Kamera suchen
            camera = gp.Camera()
            camera.init()
            
            # Test ob Kamera antwortet
            config = camera.get_config()
            self.camera_instance = camera
            self.camera_detected = True
            print("✅ gphoto2 Python: Kamera erfolgreich verbunden")
            
        except Exception as e:
            print(f"❌ gphoto2 Python Fehler: {e}")
            raise
    
    def _init_gphoto2_cli(self):
        """Fallback: gphoto2 Shell-Kommandos"""
        import subprocess
        try:
            result = subprocess.run(['gphoto2', '--auto-detect'], 
                                  capture_output=True, text=True, check=True)
            self.camera_detected = "Canon" in result.stdout
            if self.camera_detected:
                print("✅ gphoto2 CLI: Kamera erkannt")
            else:
                print("❌ gphoto2 CLI: Keine Canon-Kamera gefunden")
        except:
            print("❌ gphoto2 CLI: Nicht verfügbar")
            self.camera_detected = False
    
    def check_camera(self) -> bool:
        """Prüft Kamera-Status"""
        if not self.camera_detected:
            self._initialize_camera()
        return self.camera_detected
    
    def get_camera_info(self) -> Dict[str, Any]:
        """Gibt Kamera-Informationen zurück"""
        if not self.check_camera():
            return {'connected': False, 'model': None, 'api': self.api_backend}
        
        info = {
            'connected': True,
            'api': self.api_backend,
            'status': 'ready'
        }
        
        try:
            if self.api_backend == 'edsdk':
                info['model'] = self.camera_instance.get_device_info()['name']
            elif self.api_backend == 'gphoto2_py':
                import gphoto2 as gp
                config = self.camera_instance.get_config()
                info['model'] = 'Canon EOS (gphoto2)'
            else:
                import subprocess
                result = subprocess.run(['gphoto2', '--auto-detect'], 
                                      capture_output=True, text=True)
                for line in result.stdout.split('\n'):
                    if "Canon" in line:
                        info['model'] = line.split()[0] + " " + line.split()[1]
                        break
        except Exception as e:
            info['error'] = str(e)
        
        return info
    
    def take_photo(self, filename: Optional[str] = None, **kwargs) -> Dict[str, Any]:
        """Nimmt ein Foto auf mit der besten verfügbaren Methode"""
        if not self.check_camera():
            return {
                'success': False,
                'message': f'Keine Kamera verfügbar (API: {self.api_backend})'
            }
        
        if not filename:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"photo_{timestamp}.jpg"
        
        filepath = os.path.join(self.config.photo_dir, filename)
        
        try:
            if self.api_backend == 'edsdk':
                return self._take_photo_edsdk(filepath, **kwargs)
            elif self.api_backend == 'gphoto2_py':
                return self._take_photo_gphoto2_py(filepath, **kwargs)
            else:
                return self._take_photo_gphoto2_cli(filepath, **kwargs)
        except Exception as e:
            return {
                'success': False,
                'message': f'Foto-Aufnahme fehlgeschlagen ({self.api_backend}): {str(e)}'
            }
    
    def _take_photo_edsdk(self, filepath: str, **kwargs) -> Dict[str, Any]:
        """Foto-Aufnahme mit Canon EDSDK (robusteste Methode)"""
        try:
            # Foto aufnehmen
            image_data = self.camera_instance.take_photo()
            
            # Speichern
            with open(filepath, 'wb') as f:
                f.write(image_data)
            
            if os.path.exists(filepath) and os.path.getsize(filepath) > 1000:
                return {
                    'success': True,
                    'filename': os.path.basename(filepath),
                    'filepath': filepath,
                    'message': 'Foto erfolgreich aufgenommen (Canon EDSDK)',
                    'api': 'edsdk',
                    'filesize': os.path.getsize(filepath)
                }
            else:
                raise Exception("Foto-Datei nicht erstellt oder zu klein")
                
        except Exception as e:
            return {
                'success': False,
                'message': f'Canon EDSDK Fehler: {str(e)}'
            }
    
    def _take_photo_gphoto2_py(self, filepath: str, **kwargs) -> Dict[str, Any]:
        """Foto-Aufnahme mit gphoto2 Python API"""
        try:
            import gphoto2 as gp
            
            # Foto aufnehmen
            file_path = self.camera_instance.capture(gp.GP_CAPTURE_IMAGE)
            
            # Herunterladen
            camera_file = self.camera_instance.file_get(
                file_path.folder, file_path.name, gp.GP_FILE_TYPE_NORMAL)
            
            # Speichern
            camera_file.save(filepath)
            
            # Von Kamera löschen (optional)
            self.camera_instance.file_delete(file_path.folder, file_path.name)
            
            if os.path.exists(filepath) and os.path.getsize(filepath) > 1000:
                return {
                    'success': True,
                    'filename': os.path.basename(filepath),
                    'filepath': filepath,
                    'message': 'Foto erfolgreich aufgenommen (gphoto2 Python)',
                    'api': 'gphoto2_py',
                    'filesize': os.path.getsize(filepath)
                }
            else:
                raise Exception("Foto-Datei nicht erstellt oder zu klein")
                
        except Exception as e:
            return {
                'success': False,
                'message': f'gphoto2 Python Fehler: {str(e)}'
            }
    
    def _take_photo_gphoto2_cli(self, filepath: str, **kwargs) -> Dict[str, Any]:
        """Fallback: gphoto2 Shell-Kommandos mit verbesserter 2-Schritt-Methode"""
        import subprocess
        
        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                print(f"📸 Foto-Aufnahme Versuch {attempt}/{max_attempts} (gphoto2 CLI)...")
                
                if attempt > 1:
                    time.sleep(2)
                    subprocess.run(['pkill', '-f', 'gphoto2'], capture_output=True)
                    time.sleep(1)
                
                # 2-Schritt-Methode: Capture → Download
                capture_result = subprocess.run([
                    'gphoto2', '--capture-image'
                ], capture_output=True, text=True, check=True, timeout=15)
                
                # Verzeichniswechsel und Download
                original_dir = os.getcwd()
                try:
                    os.chdir(os.path.dirname(filepath))
                    filename_only = os.path.basename(filepath)
                    
                    download_result = subprocess.run([
                        'gphoto2', '--get-all-files', '--delete-after'
                    ], capture_output=True, text=True, timeout=15)
                    
                    # Finde heruntergeladene Datei
                    photo_dir = os.path.dirname(filepath)
                    for file in os.listdir(photo_dir):
                        if file.lower().startswith('capt') and file.lower().endswith('.jpg'):
                            downloaded_file = os.path.join(photo_dir, file)
                            if os.path.exists(downloaded_file) and os.path.getsize(downloaded_file) > 1000:
                                os.rename(downloaded_file, filepath)
                                break
                    
                finally:
                    os.chdir(original_dir)
                
                if os.path.exists(filepath) and os.path.getsize(filepath) > 1000:
                    return {
                        'success': True,
                        'filename': os.path.basename(filepath),
                        'filepath': filepath,
                        'message': f'Foto erfolgreich aufgenommen (gphoto2 CLI, Versuch {attempt})',
                        'api': 'gphoto2_cli',
                        'attempts': attempt,
                        'filesize': os.path.getsize(filepath)
                    }
                else:
                    raise Exception("Foto-Datei nicht erstellt oder zu klein")
                    
            except subprocess.CalledProcessError as e:
                if "device busy" in str(e.stderr).lower() or "0x2019" in str(e.stderr):
                    if attempt < max_attempts:
                        print(f"⚠️ Device Busy - Reset-Versuch {attempt}")
                        subprocess.run(['pkill', '-f', 'gphoto2'], capture_output=True)
                        subprocess.run(['pkill', '-f', 'gvfs'], capture_output=True)
                        time.sleep(3)
                        continue
                    else:
                        return {
                            'success': False,
                            'message': 'Canon EOS Device Busy - Hardware-Reset erforderlich'
                        }
                else:
                    if attempt < max_attempts:
                        continue
                    else:
                        return {
                            'success': False,
                            'message': f'gphoto2 CLI Fehler: {str(e)}'
                        }
            except Exception as e:
                if attempt < max_attempts:
                    continue
                else:
                    return {
                        'success': False,
                        'message': f'Unerwarteter Fehler: {str(e)}'
                    }
        
        return {
            'success': False,
            'message': f'Foto-Aufnahme nach {max_attempts} Versuchen fehlgeschlagen'
        }
    
    def cleanup(self):
        """Cleanup-Ressourcen"""
        try:
            if self.api_backend == 'edsdk' and self.camera_instance:
                self.camera_instance.close()
                import canon_edsdk
                canon_edsdk.terminate_sdk()
            elif self.api_backend == 'gphoto2_py' and self.camera_instance:
                self.camera_instance.exit()
        except Exception as e:
            print(f"⚠️ Cleanup-Fehler: {e}")

# Erstelle moderne Instanz
modern_camera_manager = ModernCameraManager()

# Backward-Kompatibilität
camera_manager = modern_camera_manager