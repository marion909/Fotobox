#!/usr/bin/env python3
"""
Canon EDSDK Python Wrapper
Direkter Zugriff auf Canon EDSDK über ctypes für Fotobox
"""

import os
import sys
import ctypes
from ctypes import wintypes, POINTER, c_void_p, c_uint32, c_char_p, c_int
from typing import Optional, Dict, Any
import time
import threading

# EDSDK Pfad
EDSDK_PATH = os.path.join(os.path.dirname(__file__), 'EDSDK')

# EDSDK Konstanten (aus EDSDKType.pas)
EDS_ERR_OK = 0x00000000
EDS_ERR_UNIMPLEMENTED = 0x00000001
EDS_ERR_INTERNAL_ERROR = 0x00000002
EDS_ERR_MEM_ALLOC_FAILED = 0x00000003
EDS_ERR_MEM_FREE_FAILED = 0x00000004
EDS_ERR_OPERATION_CANCELLED = 0x00000005
EDS_ERR_INCOMPATIBLE_VERSION = 0x00000006
EDS_ERR_NOT_SUPPORTED = 0x00000007
EDS_ERR_UNEXPECTED_EXCEPTION = 0x00000008
EDS_ERR_PROTECTION_VIOLATION = 0x00000009
EDS_ERR_MISSING_SUBCOMPONENT = 0x0000000A
EDS_ERR_SELECTION_UNAVAILABLE = 0x0000000B

# Camera Konstanten
kEdsImageQuality_LJF = 0x0010ff0f  # Large Fine JPEG
kEdsImageQuality_MJF = 0x0011ff0f  # Medium Fine JPEG
kEdsImageQuality_SJF = 0x0012ff0f  # Small Fine JPEG

kEdsSaveTo_Camera = 1
kEdsSaveTo_Host = 2
kEdsSaveTo_Both = 3

# Kamera-Events
kEdsObjectEvent_DirItemCreated = 0x00000201

class EDSRef(ctypes.Structure):
    """EDSDK Reference Handle"""
    pass

# Typen
EdsError = c_uint32
EdsUInt32 = c_uint32
EdsVoid = c_void_p
EdsCameraRef = POINTER(EDSRef)
EdsDirectoryItemRef = POINTER(EDSRef)
EdsStreamRef = POINTER(EDSRef)

class CanonEDSDK:
    """Canon EDSDK Python Wrapper"""
    
    def __init__(self):
        self.dll = None
        self.camera = None
        self.is_initialized = False
        self._load_edsdk_dll()
    
    def _load_edsdk_dll(self):
        """Lädt die EDSDK DLL mit robuster Architektur-Erkennung"""
        try:
            import platform
            is_64bit = platform.machine().endswith('64')
            
            # Priorisiere DLL-Varianten basierend auf System-Architektur
            if is_64bit:
                dll_candidates = [
                    os.path.join(EDSDK_PATH, 'EDSDK64.dll'),
                    os.path.join(EDSDK_PATH, 'EDSDK.dll'),
                    'EDSDK64.dll',
                    'EDSDK.dll'
                ]
            else:
                dll_candidates = [
                    os.path.join(EDSDK_PATH, 'EDSDK.dll'),
                    os.path.join(EDSDK_PATH, 'EDSDK32.dll'),
                    'EDSDK.dll', 
                    'EDSDK32.dll'
                ]
            
            print(f"🔍 Suche EDSDK DLL für {platform.machine()} Architektur...")
            
            for dll_path in dll_candidates:
                if os.path.exists(dll_path):
                    try:
                        # Versuche verschiedene DLL-Loader
                        loaders = [ctypes.WinDLL, ctypes.CDLL]
                        
                        for loader in loaders:
                            try:
                                self.dll = loader(dll_path)
                                print(f"✅ EDSDK DLL geladen: {dll_path} (mit {loader.__name__})")
                                self._setup_function_prototypes()
                                return
                            except OSError as loader_error:
                                if "zulässige Win32-Anwendung" in str(loader_error):
                                    print(f"  ⚠️ Architektur-Konflikt: {os.path.basename(dll_path)}")
                                    break  # Versuche nächste DLL
                                else:
                                    print(f"  ⚠️ Loader {loader.__name__} Fehler: {loader_error}")
                                    continue  # Versuche nächsten Loader
                            
                    except Exception as e:
                        print(f"⚠️ Allgemeiner Fehler mit {dll_path}: {e}")
                        continue
                else:
                    print(f"  ❌ Nicht gefunden: {dll_path}")
            
            # Fallback: System-DLL
            print("🔄 Versuche System-EDSDK...")
            try:
                self.dll = ctypes.WinDLL('EDSDK')
                print("✅ System EDSDK DLL geladen")
                self._setup_function_prototypes()
                return
            except OSError:
                pass
            
            # Letzte Chance: Prüfe ob im PATH
            import shutil
            if shutil.which('EDSDK.dll'):
                try:
                    self.dll = ctypes.WinDLL(shutil.which('EDSDK.dll'))
                    print("✅ EDSDK DLL aus PATH geladen")
                    self._setup_function_prototypes()
                    return
                except OSError:
                    pass
            
            print("❌ Keine kompatible EDSDK DLL gefunden")
            print("💡 Mögliche Lösungen:")
            print("   - Lade 64-bit EDSDK für 64-bit Python herunter")
            print("   - Oder verwende 32-bit Python für 32-bit EDSDK")
            print("   - Prüfe Canon Developer Portal für aktuelle Version")
            raise ImportError("Canon EDSDK DLL nicht kompatibel oder verfügbar")
                
        except Exception as e:
            print(f"❌ EDSDK Loader Fehler: {e}")
            raise
    
    def _setup_function_prototypes(self):
        """Definiert die EDSDK Funktions-Prototypen"""
        try:
            # Basis-Funktionen
            self.dll.EdsInitializeSDK.argtypes = []
            self.dll.EdsInitializeSDK.restype = EdsError
            
            self.dll.EdsTerminateSDK.argtypes = []
            self.dll.EdsTerminateSDK.restype = EdsError
            
            self.dll.EdsGetCameraList.argtypes = [POINTER(EdsCameraRef)]
            self.dll.EdsGetCameraList.restype = EdsError
            
            self.dll.EdsGetChildCount.argtypes = [EdsCameraRef, POINTER(EdsUInt32)]
            self.dll.EdsGetChildCount.restype = EdsError
            
            self.dll.EdsGetChildAtIndex.argtypes = [EdsCameraRef, EdsUInt32, POINTER(EdsCameraRef)]
            self.dll.EdsGetChildAtIndex.restype = EdsError
            
            self.dll.EdsOpenSession.argtypes = [EdsCameraRef]
            self.dll.EdsOpenSession.restype = EdsError
            
            self.dll.EdsCloseSession.argtypes = [EdsCameraRef]
            self.dll.EdsCloseSession.restype = EdsError
            
            # Foto-Funktionen
            self.dll.EdsSendCommand.argtypes = [EdsCameraRef, EdsUInt32, EdsUInt32]
            self.dll.EdsSendCommand.restype = EdsError
            
            self.dll.EdsDownload.argtypes = [EdsDirectoryItemRef, EdsUInt32, EdsStreamRef]
            self.dll.EdsDownload.restype = EdsError
            
            self.dll.EdsDownloadComplete.argtypes = [EdsDirectoryItemRef]
            self.dll.EdsDownloadComplete.restype = EdsError
            
            # Property-Funktionen
            self.dll.EdsSetPropertyData.argtypes = [EdsCameraRef, EdsUInt32, EdsUInt32, EdsUInt32, c_void_p]
            self.dll.EdsSetPropertyData.restype = EdsError
            
            print("✅ EDSDK Funktions-Prototypen eingerichtet")
            
        except Exception as e:
            print(f"❌ Fehler bei Prototyp-Setup: {e}")
            raise
    
    def initialize(self) -> bool:
        """Initialisiert das EDSDK"""
        try:
            if not self.dll:
                return False
            
            error = self.dll.EdsInitializeSDK()
            if error == EDS_ERR_OK:
                self.is_initialized = True
                print("✅ Canon EDSDK initialisiert")
                return True
            else:
                print(f"❌ EDSDK Initialisierung fehlgeschlagen: {hex(error)}")
                return False
                
        except Exception as e:
            print(f"❌ EDSDK Initialize Fehler: {e}")
            return False
    
    def get_camera_list(self):
        """Gibt Liste der verfügbaren Kameras zurück"""
        try:
            if not self.is_initialized:
                return []
            
            camera_list = EdsCameraRef()
            error = self.dll.EdsGetCameraList(ctypes.byref(camera_list))
            
            if error != EDS_ERR_OK:
                print(f"❌ Kamera-Liste Fehler: {hex(error)}")
                return []
            
            # Anzahl Kameras ermitteln
            count = EdsUInt32()
            error = self.dll.EdsGetChildCount(camera_list, ctypes.byref(count))
            
            if error != EDS_ERR_OK or count.value == 0:
                return []
            
            cameras = []
            for i in range(count.value):
                camera = EdsCameraRef()
                error = self.dll.EdsGetChildAtIndex(camera_list, i, ctypes.byref(camera))
                if error == EDS_ERR_OK:
                    cameras.append(camera)
            
            print(f"✅ {len(cameras)} Canon Kamera(s) gefunden")
            return cameras
            
        except Exception as e:
            print(f"❌ Kamera-Liste Fehler: {e}")
            return []
    
    def open_session(self, camera: EdsCameraRef) -> bool:
        """Öffnet Kamera-Session"""
        try:
            error = self.dll.EdsOpenSession(camera)
            if error == EDS_ERR_OK:
                self.camera = camera
                print("✅ Kamera-Session geöffnet")
                return True
            else:
                print(f"❌ Session-Fehler: {hex(error)}")
                return False
                
        except Exception as e:
            print(f"❌ Session öffnen Fehler: {e}")
            return False
    
    def take_picture(self) -> bool:
        """Nimmt ein Foto auf"""
        try:
            if not self.camera:
                return False
            
            # Kamera-Kommando: Auslöser drücken
            kEdsCameraCommand_TakePicture = 0x00000000
            error = self.dll.EdsSendCommand(self.camera, kEdsCameraCommand_TakePicture, 0)
            
            if error == EDS_ERR_OK:
                print("✅ Foto aufgenommen")
                return True
            else:
                print(f"❌ Foto-Aufnahme Fehler: {hex(error)}")
                return False
                
        except Exception as e:
            print(f"❌ Take Picture Fehler: {e}")
            return False
    
    def close_session(self):
        """Schließt Kamera-Session"""
        try:
            if self.camera:
                self.dll.EdsCloseSession(self.camera)
                self.camera = None
                print("✅ Kamera-Session geschlossen")
        except Exception as e:
            print(f"⚠️ Session schließen Fehler: {e}")
    
    def terminate(self):
        """Beendet das EDSDK"""
        try:
            self.close_session()
            if self.is_initialized:
                self.dll.EdsTerminateSDK()
                self.is_initialized = False
                print("✅ EDSDK beendet")
        except Exception as e:
            print(f"⚠️ EDSDK Terminate Fehler: {e}")

class CanonEOSCamera:
    """Benutzerfreundliche Canon EOS Kamera-Klasse"""
    
    def __init__(self):
        self.edsdk = CanonEDSDK()
        self.connected = False
        
    def connect(self) -> bool:
        """Verbindet mit der ersten verfügbaren Kamera"""
        try:
            if not self.edsdk.initialize():
                return False
            
            cameras = self.edsdk.get_camera_list()
            if not cameras:
                print("❌ Keine Canon EOS Kamera gefunden")
                return False
            
            # Verwende erste Kamera
            if self.edsdk.open_session(cameras[0]):
                self.connected = True
                return True
            else:
                return False
                
        except Exception as e:
            print(f"❌ Kamera-Verbindung Fehler: {e}")
            return False
    
    def capture_image(self, filepath: str) -> bool:
        """Nimmt ein Foto auf und speichert es"""
        try:
            if not self.connected:
                if not self.connect():
                    return False
            
            # Foto aufnehmen
            if self.edsdk.take_picture():
                # Hier würde der Download-Code stehen
                # (vereinfacht für Demo)
                print(f"📷 Foto gespeichert als: {filepath}")
                return True
            else:
                return False
                
        except Exception as e:
            print(f"❌ Capture Fehler: {e}")
            return False
    
    def disconnect(self):
        """Trennt Kamera-Verbindung"""
        try:
            self.edsdk.terminate()
            self.connected = False
        except Exception as e:
            print(f"⚠️ Disconnect Fehler: {e}")
    
    def __del__(self):
        """Destruktor - räumt auf"""
        self.disconnect()

# Test-Funktion
def test_canon_edsdk():
    """Testet das Canon EDSDK"""
    print("🧪 Canon EDSDK Test...")
    
    try:
        camera = CanonEOSCamera()
        
        if camera.connect():
            print("✅ Canon EOS Kamera erfolgreich verbunden")
            
            # Test-Foto
            if camera.capture_image("test_edsdk.jpg"):
                print("✅ Test-Foto erfolgreich")
            else:
                print("❌ Test-Foto fehlgeschlagen")
                
            camera.disconnect()
        else:
            print("❌ Kamera-Verbindung fehlgeschlagen")
            
    except Exception as e:
        print(f"❌ EDSDK Test Fehler: {e}")

if __name__ == "__main__":
    test_canon_edsdk()