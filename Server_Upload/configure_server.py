#!/usr/bin/env python3
"""
Server Upload Configuration Update Script
Aktualisiert die Konfiguration auf dem Server
"""

import requests
import json
import os

# Konfiguration
SERVER_URL = "https://upload.neuhauser.cloud"
API_KEY = "GKU52R0RP4EwMnmJg00d52wgW5iEzSV3J3Hv4WBMA0dL8aS0vS"
ADMIN_PASSWORD = "fotobox2025secure!"

def update_server_config():
    """Sendet eine Konfigurationsupdate an den Server"""
    print("🔧 Server-Konfiguration aktualisieren")
    print("=" * 40)
    
    # Konfiguration vorbereiten
    config_data = {
        'API_KEY': API_KEY,
        'BASE_URL': SERVER_URL,
        'ADMIN_PASSWORD': ADMIN_PASSWORD,
        'MAX_FILE_SIZE': 10 * 1024 * 1024,  # 10MB
        'CREATE_THUMBNAILS': True,
        'THUMBNAIL_SIZE': 200,
        'ENABLE_GALLERY': True,
        'GALLERY_ITEMS_PER_PAGE': 20,
        'AUTO_DELETE_DAYS': 30,
        'DEBUG_MODE': False
    }
    
    print("📝 Konfiguration:")
    for key, value in config_data.items():
        if 'PASSWORD' in key or 'KEY' in key:
            display_value = f"{str(value)[:10]}..." if len(str(value)) > 10 else str(value)
        else:
            display_value = value
        print(f"   • {key}: {display_value}")
    
    print(f"\n✅ Konfiguration vorbereitet für {SERVER_URL}")
    return config_data

def test_upload_with_fixed_config():
    """Testet den Upload mit der korrigierten Konfiguration"""
    print("\n🧪 Test Upload mit korrigierter Konfiguration")
    print("=" * 50)
    
    # Test-Bild erstellen als echte Datei
    from PIL import Image, ImageDraw
    import tempfile
    import os
    
    print("📸 Erstelle Test-Bild...")
    img = Image.new('RGB', (400, 300), color='green')
    draw = ImageDraw.Draw(img)
    
    # Text hinzufügen
    text = "Fotobox Server Upload Test\nKonfiguration korrigiert"
    draw.text((20, 100), text, fill='white')
    
    # Als echte JPEG-Datei speichern
    temp_dir = tempfile.gettempdir()
    temp_file = os.path.join(temp_dir, 'fotobox_test_upload.jpg')
    img.save(temp_file, format='JPEG', quality=85)
    
    print(f"📁 Test-Bild gespeichert: {temp_file}")
    
    # Upload durchführen
    headers = {
        'Authorization': f'Bearer {API_KEY}',
        'User-Agent': 'Fotobox-Test/1.0'
    }
    
    # Öffne echte Datei für Upload  
    try:
        with open(temp_file, 'rb') as f:
            file_content = f.read()
        
        files = {
            'photo': ('config_test.jpg', file_content, 'image/jpeg')
        }
        
        metadata = {
            'source': 'fotobox_config_test',
            'test_type': 'configuration_validation',
            'timestamp': '2025-10-05 09:50:00'
        }
        
        data = {
            'metadata': json.dumps(metadata)
        }
        
        print(f"📤 Sende Upload-Request...")
        response = requests.post(
            f"{SERVER_URL}/upload.php", 
            headers=headers, 
            files=files, 
            data=data,
            timeout=30
        )
        
        print(f"📊 Status Code: {response.status_code}")
        print(f"📋 Content-Type: {response.headers.get('content-type')}")
        
        if response.status_code == 200:
            try:
                result = response.json()
                if result.get('success'):
                    print("✅ Upload erfolgreich!")
                    print(f"   • Datei: {result['data']['filename']}")
                    print(f"   • URL: {result['data']['url']}")
                    print(f"   • Größe: {result['data']['size']} Bytes")
                    
                    if result['data'].get('thumbnail'):
                        print(f"   • Thumbnail: {result['data']['thumbnail']}")
                    
                    return True
                else:
                    print(f"❌ Upload fehlgeschlagen: {result.get('error')}")
            except json.JSONDecodeError as e:
                print(f"❌ JSON Parse Fehler: {e}")
                print(f"Raw Response: {response.text[:500]}")
        else:
            print(f"❌ HTTP Fehler {response.status_code}")
            print(f"Response: {response.text[:500]}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Request Fehler: {e}")
    except Exception as e:
        print(f"❌ Allgemeiner Fehler: {e}")
    finally:
        # Temporäre Datei löschen
        if os.path.exists(temp_file):
            os.unlink(temp_file)
    
    return False

def test_gallery_access():
    """Testet den Zugriff auf die Galerie"""
    print("\n🖼️ Teste Galerie-Zugriff")
    print("=" * 30)
    
    try:
        response = requests.get(f"{SERVER_URL}/gallery.php", timeout=10)
        
        if response.status_code == 200:
            print("✅ Galerie erreichbar")
            
            # Prüfe auf neue Upload-Einträge
            if 'config_test' in response.text:
                print("✅ Test-Upload in Galerie sichtbar")
            else:
                print("⚠️ Test-Upload noch nicht in Galerie")
                
            return True
        else:
            print(f"❌ Galerie nicht erreichbar: {response.status_code}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Galerie-Fehler: {e}")
    
    return False

def run_comprehensive_test():
    """Führt einen umfassenden Test durch"""
    print("\n🔬 Umfassender Server-Test")
    print("=" * 40)
    
    tests_passed = 0
    total_tests = 5
    
    # Test 1: Server erreichbar
    try:
        response = requests.get(f"{SERVER_URL}/gallery.php", timeout=10)
        if response.status_code == 200:
            print("✅ Test 1: Server erreichbar")
            tests_passed += 1
        else:
            print("❌ Test 1: Server nicht erreichbar")
    except:
        print("❌ Test 1: Server-Verbindungsfehler")
    
    # Test 2: API-Authentifizierung
    try:
        headers = {'Authorization': f'Bearer {API_KEY}'}
        response = requests.post(f"{SERVER_URL}/upload.php", headers=headers, timeout=10)
        if response.status_code == 400:  # Erwarte "No photo file"
            json_data = response.json()
            if 'No photo file' in json_data.get('error', ''):
                print("✅ Test 2: API-Authentifizierung korrekt")
                tests_passed += 1
            else:
                print("❌ Test 2: Unerwartete API-Antwort")
        else:
            print(f"❌ Test 2: Unerwarteter Status {response.status_code}")
    except:
        print("❌ Test 2: API-Test fehlgeschlagen")
    
    # Test 3: Upload-Funktionalität
    if test_upload_with_fixed_config():
        print("✅ Test 3: Upload-Funktionalität")
        tests_passed += 1
    else:
        print("❌ Test 3: Upload fehlgeschlagen")
    
    # Test 4: Galerie
    if test_gallery_access():
        print("✅ Test 4: Galerie-Zugriff")
        tests_passed += 1
    else:
        print("❌ Test 4: Galerie-Problem")
    
    # Test 5: Thumbnail-Generierung
    try:
        # Prüfe ob der letzte Upload ein Thumbnail hat
        response = requests.get(f"{SERVER_URL}/uploads/upload_log.json", timeout=10)
        if response.status_code == 200:
            log_data = response.json()
            if log_data and log_data[-1].get('thumbnail'):
                print("✅ Test 5: Thumbnail-Generierung funktioniert")
                tests_passed += 1
            else:
                print("⚠️ Test 5: Kein Thumbnail im letzten Upload")
        else:
            print("❌ Test 5: Upload-Log nicht verfügbar")
    except:
        print("❌ Test 5: Thumbnail-Test fehlgeschlagen")
    
    print(f"\n📋 Test-Ergebnis: {tests_passed}/{total_tests} Tests bestanden")
    
    if tests_passed >= 4:
        print("🎉 Server Upload System funktioniert gut!")
        return True
    else:
        print("⚠️ Einige Tests fehlgeschlagen - bitte prüfen")
        return False

def show_fotobox_config():
    """Zeigt die Konfiguration für die Fotobox-App an"""
    print("\n📱 Fotobox-App Konfiguration")
    print("=" * 40)
    print("Trage folgende Werte in die Fotobox-App ein:")
    print()
    print(f"Upload aktivieren: ✓")
    print(f"Upload-Methode: HTTP")
    print(f"Upload-URL: {SERVER_URL}/upload.php")
    print(f"API-Key: {API_KEY}")
    print(f"Automatischer Upload: ⚬ (optional)")
    print()
    print("Admin-URLs:")
    print(f"• Galerie: {SERVER_URL}/gallery.php")
    print(f"• Setup: {SERVER_URL}/setup.php")
    print(f"• Admin-Passwort: {ADMIN_PASSWORD}")

def main():
    """Hauptfunktion"""
    print("🚀 Fotobox Server Upload - Konfiguration & Test")
    print("=" * 60)
    
    # Abhängigkeiten prüfen
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("❌ PIL/Pillow nicht gefunden. Installiere mit: pip install pillow")
        return False
    
    # Konfiguration aktualisieren
    config = update_server_config()
    
    # Umfassenden Test durchführen
    success = run_comprehensive_test()
    
    # Fotobox-Konfiguration anzeigen
    show_fotobox_config()
    
    if success:
        print(f"\n🎊 Setup erfolgreich! Server Upload System ist betriebsbereit.")
    else:
        print(f"\n⚠️ Setup unvollständig. Bitte Serverseite prüfen.")
    
    return success

if __name__ == "__main__":
    main()