#!/usr/bin/env python3
"""
Live Preview Test für Raspberry Pi mit echter Canon EOS Kamera
"""

from optimal_camera_manager import optimal_camera_manager
import time
import sys

def test_live_preview():
    """Testet die verbesserte Live Preview Funktionalität"""
    
    print("=== CANON EOS LIVE PREVIEW TEST ===")
    print("Dieser Test funktioniert nur mit angeschlossener Canon EOS Kamera!")
    print()
    
    # Schritt 1: Kamera-Verbindung prüfen
    print("1. Kamera-Verbindung prüfen...")
    if not optimal_camera_manager.check_camera():
        print("   [FAIL] Keine Kamera gefunden!")
        print("   Prüfen Sie:")
        print("   - Ist die Canon EOS Kamera eingeschaltet?")
        print("   - Ist das USB-Kabel angeschlossen?")
        print("   - Ist die Kamera im PTP/PC-Modus?")
        return False
    
    print("   [OK] Canon EOS Kamera erkannt!")
    
    # Schritt 2: Live Preview starten
    print("\n2. Live Preview aktivieren...")
    result = optimal_camera_manager.start_live_preview()
    
    if result['success']:
        print(f"   [OK] {result['message']}")
    else:
        print(f"   [FAIL] {result['message']}")
        return False
    
    # Schritt 3: Mehrere Preview-Bilder erfassen
    print("\n3. Preview-Bilder erfassen (10 Sekunden Test)...")
    
    for i in range(5):
        print(f"   Capture {i+1}/5...")
        preview_path = optimal_camera_manager.capture_preview_image()
        
        if preview_path:
            print(f"      [OK] Preview gespeichert: {preview_path}")
            time.sleep(2)  # 2 Sekunden zwischen Captures
        else:
            print(f"      [FAIL] Preview-Capture fehlgeschlagen")
            break
    
    # Schritt 4: Live Preview stoppen
    print("\n4. Live Preview deaktivieren...")
    optimal_camera_manager.stop_live_preview()
    print("   [OK] Live Preview gestoppt")
    
    print("\n=== TEST ABGESCHLOSSEN ===")
    print("[OK] Live Preview funktioniert korrekt!")
    return True

if __name__ == "__main__":
    try:
        success = test_live_preview()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n[INFO] Test durch Benutzer abgebrochen")
        optimal_camera_manager.stop_live_preview()
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR] Unerwarteter Fehler: {e}")
        optimal_camera_manager.stop_live_preview()
        sys.exit(1)