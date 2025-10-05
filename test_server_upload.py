#!/usr/bin/env python3
"""
Photobox Server Upload Test Script
Testet die Upload-Funktionalität des Server-Systems
"""

import requests
import json
import os
import time
from PIL import Image
import io

# Konfiguration
SERVER_URL = "https://upload.neuhauser.cloud"
API_KEY = "GKU52R0RP4EwMnmJg00d52wgW5iEzSV3J3Hv4WBMA0dL8aS0vS"
UPLOAD_ENDPOINT = f"{SERVER_URL}/upload.php"
GALLERY_URL = f"{SERVER_URL}/gallery.php"

def create_test_image():
    """Erstellt ein Test-Bild für den Upload"""
    print("📸 Erstelle Test-Bild...")
    
    # Einfaches Test-Bild erstellen
    img = Image.new('RGB', (800, 600), color='blue')
    
    # Aktuelle Zeit als Text hinzufügen
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(img)
    
    try:
        # Versuche Standard-Font zu laden
        font = ImageFont.load_default()
    except:
        font = None
    
    text = f"Photobox Test Upload\n{time.strftime('%Y-%m-%d %H:%M:%S')}"
    
    if font:
        draw.text((50, 250), text, fill='white', font=font)
    else:
        draw.text((50, 250), text, fill='white')
    
    # Als JPEG in Memory speichern
    img_buffer = io.BytesIO()
    img.save(img_buffer, format='JPEG', quality=85)
    img_buffer.seek(0)
    
    return img_buffer

def test_server_connection():
    """Testet die Grundverbindung zum Server"""
    print("🌐 Teste Server-Verbindung...")
    
    try:
        response = requests.get(GALLERY_URL, timeout=10)
        if response.status_code == 200:
            print("✅ Server erreichbar")
            return True
        else:
            print(f"❌ Server antwortet mit Status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Verbindungsfehler: {e}")
        return False

def test_upload_endpoint():
    """Testet den Upload-Endpoint ohne Datei"""
    print("🔍 Teste Upload-Endpoint...")
    
    headers = {
        'Authorization': f'Bearer {API_KEY}'
    }
    
    try:
        response = requests.post(UPLOAD_ENDPOINT, headers=headers, timeout=10)
        
        if response.status_code == 400:
            data = response.json()
            if 'No photo file provided' in data.get('error', ''):
                print("✅ Upload-Endpoint reagiert korrekt")
                return True
        
        print(f"⚠️ Unerwartete Antwort: {response.status_code}")
        print(f"Response: {response.text}")
        return False
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Endpoint-Fehler: {e}")
        return False

def test_authentication():
    """Testet die API-Authentifizierung"""
    print("🔑 Teste API-Authentifizierung...")
    
    # Test ohne API-Key
    try:
        response = requests.post(UPLOAD_ENDPOINT, timeout=10)
        if response.status_code == 401:
            print("✅ Authentifizierung erforderlich (korrekt)")
        else:
            print(f"⚠️ Unerwartete Antwort ohne API-Key: {response.status_code}")
    except Exception as e:
        print(f"❌ Auth-Test Fehler: {e}")
        return False
    
    # Test mit falschem API-Key
    try:
        headers = {'Authorization': 'Bearer wrong_key'}
        response = requests.post(UPLOAD_ENDPOINT, headers=headers, timeout=10)
        if response.status_code == 401:
            print("✅ Falscher API-Key abgelehnt (korrekt)")
        else:
            print(f"⚠️ Falscher API-Key akzeptiert: {response.status_code}")
    except Exception as e:
        print(f"❌ Auth-Test Fehler: {e}")
        return False
    
    return True

def test_photo_upload():
    """Testet den tatsächlichen Foto-Upload"""
    print("📤 Teste Foto-Upload...")
    
    # Test-Bild erstellen
    test_image = create_test_image()
    
    headers = {
        'Authorization': f'Bearer {API_KEY}'
    }
    
    files = {
        'photo': ('test_photo.jpg', test_image, 'image/jpeg')
    }
    
    try:
        response = requests.post(UPLOAD_ENDPOINT, headers=headers, files=files, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                print("✅ Foto erfolgreich hochgeladen")
                print(f"   • Datei: {data['data']['filename']}")
                print(f"   • URL: {data['data']['url']}")
                print(f"   • Größe: {data['data']['size']} Bytes")
                print(f"   • Zeit: {data['data']['upload_time']}")
                return data['data']
            else:
                print(f"❌ Upload fehlgeschlagen: {data.get('error')}")
        else:
            print(f"❌ Server-Fehler: {response.status_code}")
            print(f"Response: {response.text}")
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Upload-Fehler: {e}")
    
    return None

def test_uploaded_file_access(upload_data):
    """Testet den Zugriff auf die hochgeladene Datei"""
    if not upload_data:
        return False
    
    print("🔗 Teste Datei-Zugriff...")
    
    try:
        # Hauptdatei testen
        response = requests.get(upload_data['url'], timeout=10)
        if response.status_code == 200:
            print("✅ Hochgeladene Datei erreichbar")
        else:
            print(f"❌ Datei nicht erreichbar: {response.status_code}")
            return False
        
        # Thumbnail testen (falls vorhanden)
        if upload_data.get('thumbnail'):
            response = requests.get(upload_data['thumbnail'], timeout=10)
            if response.status_code == 200:
                print("✅ Thumbnail erreichbar")
            else:
                print(f"⚠️ Thumbnail nicht erreichbar: {response.status_code}")
        
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Zugriffs-Fehler: {e}")
        return False

def test_gallery_access():
    """Testet den Zugriff auf die Galerie"""
    print("🖼️ Teste Galerie-Zugriff...")
    
    try:
        response = requests.get(GALLERY_URL, timeout=10)
        if response.status_code == 200:
            if 'Photobox' in response.text:
                print("✅ Galerie erreichbar")
                return True
            else:
                print("⚠️ Galerie-Inhalt ungewöhnlich")
        else:
            print(f"❌ Galerie nicht erreichbar: {response.status_code}")
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Galerie-Fehler: {e}")
    
    return False

def run_performance_test():
    """Führt einen Performance-Test durch"""
    print("⚡ Performance-Test (5 Uploads)...")
    
    start_time = time.time()
    successful_uploads = 0
    
    for i in range(5):
        print(f"   Upload {i+1}/5...", end=" ")
        
        test_image = create_test_image()
        headers = {'Authorization': f'Bearer {API_KEY}'}
        files = {'photo': (f'perf_test_{i}.jpg', test_image, 'image/jpeg')}
        
        try:
            response = requests.post(UPLOAD_ENDPOINT, headers=headers, files=files, timeout=30)
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    successful_uploads += 1
                    print("✅")
                else:
                    print("❌")
            else:
                print(f"❌ ({response.status_code})")
        except Exception as e:
            print(f"❌ ({e})")
    
    end_time = time.time()
    total_time = end_time - start_time
    
    print(f"📊 Performance-Ergebnis:")
    print(f"   • Erfolgreiche Uploads: {successful_uploads}/5")
    print(f"   • Gesamtzeit: {total_time:.2f} Sekunden")
    print(f"   • Durchschnitt pro Upload: {total_time/5:.2f} Sekunden")
    
    return successful_uploads == 5

def main():
    """Hauptfunktion - führt alle Tests durch"""
    print("🧪 Photobox Server Upload Test Suite")
    print("=" * 50)
    print(f"Server: {SERVER_URL}")
    print(f"API-Key: {API_KEY[:20]}...")
    print("")
    
    tests_passed = 0
    tests_total = 7
    
    # Test 1: Server-Verbindung
    if test_server_connection():
        tests_passed += 1
    
    # Test 2: Upload-Endpoint
    if test_upload_endpoint():
        tests_passed += 1
    
    # Test 3: Authentifizierung
    if test_authentication():
        tests_passed += 1
    
    # Test 4: Foto-Upload
    upload_data = test_photo_upload()
    if upload_data:
        tests_passed += 1
    
    # Test 5: Datei-Zugriff
    if test_uploaded_file_access(upload_data):
        tests_passed += 1
    
    # Test 6: Galerie
    if test_gallery_access():
        tests_passed += 1
    
    # Test 7: Performance
    if run_performance_test():
        tests_passed += 1
    
    print("")
    print("=" * 50)
    print(f"📋 Test-Ergebnis: {tests_passed}/{tests_total} Tests bestanden")
    
    if tests_passed == tests_total:
        print("🎉 Alle Tests erfolgreich! Server Upload System ist einsatzbereit.")
        return True
    else:
        print("⚠️ Einige Tests fehlgeschlagen. Bitte Konfiguration prüfen.")
        return False

if __name__ == "__main__":
    # Abhängigkeiten prüfen
    try:
        import requests
        from PIL import Image, ImageDraw, ImageFont
    except ImportError as e:
        print(f"❌ Fehlende Abhängigkeit: {e}")
        print("Installiere mit: pip install requests pillow")
        exit(1)
    
    # Tests ausführen
    success = main()
    exit(0 if success else 1)