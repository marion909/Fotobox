#!/usr/bin/env python3
"""
Debug-Script für Server Upload Response
"""

import requests
import json

SERVER_URL = "https://upload.neuhauser.cloud"
API_KEY = "GKU52R0RP4EwMnmJg00d52wgW5iEzSV3J3Hv4WBMA0dL8aS0vS"
UPLOAD_ENDPOINT = f"{SERVER_URL}/upload.php"

def debug_server_response():
    """Debuggt die Server-Antwort"""
    print("🔍 Debug Server Response")
    print("=" * 40)
    
    headers = {
        'Authorization': f'Bearer {API_KEY}',
        'User-Agent': 'Photobox-Debug/1.0'
    }
    
    try:
        print(f"📡 Sende Request an: {UPLOAD_ENDPOINT}")
        print(f"🔑 Headers: {headers}")
        
        response = requests.post(UPLOAD_ENDPOINT, headers=headers, timeout=10)
        
        print(f"📊 Status Code: {response.status_code}")
        print(f"📋 Response Headers: {dict(response.headers)}")
        print(f"📄 Content Type: {response.headers.get('content-type', 'unknown')}")
        print(f"📏 Content Length: {len(response.text)} Zeichen")
        print("")
        print("📝 Raw Response:")
        print("-" * 40)
        print(response.text[:1000])  # Erste 1000 Zeichen
        print("-" * 40)
        
        # Versuche JSON zu parsen
        try:
            json_data = response.json()
            print("✅ Valid JSON Response:")
            print(json.dumps(json_data, indent=2))
        except json.JSONDecodeError as e:
            print(f"❌ JSON Parse Fehler: {e}")
            
            # Versuche HTML zu erkennen
            if '<html' in response.text.lower() or '<!doctype' in response.text.lower():
                print("🌐 Response ist HTML (möglicherweise Fehlerseite)")
                
                # Extrahiere Title wenn vorhanden
                import re
                title_match = re.search(r'<title>(.*?)</title>', response.text, re.IGNORECASE)
                if title_match:
                    print(f"📄 HTML Title: {title_match.group(1)}")
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Request Fehler: {e}")

def test_simple_get():
    """Testet einen einfachen GET Request"""
    print("\n🌐 Teste einfachen GET Request")
    print("=" * 40)
    
    try:
        response = requests.get(f"{SERVER_URL}/upload.php", timeout=10)
        print(f"📊 GET Status: {response.status_code}")
        print(f"📄 GET Response (erste 200 Zeichen):")
        print(response.text[:200])
        
    except Exception as e:
        print(f"❌ GET Fehler: {e}")

def check_server_files():
    """Prüft verfügbare Dateien auf dem Server"""
    print("\n📁 Prüfe Server-Dateien")
    print("=" * 40)
    
    files_to_check = [
        "upload.php",
        "config.php", 
        "gallery.php",
        "setup.php"
    ]
    
    for filename in files_to_check:
        try:
            url = f"{SERVER_URL}/{filename}"
            response = requests.head(url, timeout=10)
            status = "✅" if response.status_code == 200 else "❌"
            print(f"{status} {filename}: HTTP {response.status_code}")
        except Exception as e:
            print(f"❌ {filename}: Fehler - {e}")

if __name__ == "__main__":
    debug_server_response()
    test_simple_get()
    check_server_files()