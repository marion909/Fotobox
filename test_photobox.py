#!/usr/bin/env python3
"""
Photobox Test Script
Testet alle Grundfunktionen der Photobox-Anwendung
"""

import os
import sys
import subprocess
import requests
import json
import time
from datetime import datetime

class PhotoboxTester:
    def __init__(self):
        self.base_url = "http://localhost:5000"
        self.test_results = []
        self.passed = 0
        self.failed = 0
    
    def log_test(self, name, passed, message=""):
        """Protokolliert Testergebnis"""
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status} {name}: {message}")
        
        self.test_results.append({
            'name': name,
            'passed': passed,
            'message': message,
            'timestamp': datetime.now().isoformat()
        })
        
        if passed:
            self.passed += 1
        else:
            self.failed += 1
    
    def test_directories(self):
        """Testet ob alle benötigten Verzeichnisse existieren"""
        directories = ['photos', 'overlays', 'temp', 'templates', 'static']
        
        for directory in directories:
            exists = os.path.exists(directory)
            self.log_test(f"Directory {directory}", exists, f"{'exists' if exists else 'missing'}")
    
    def test_files(self):
        """Testet ob alle wichtigen Dateien vorhanden sind"""
        files = [
            'app.py',
            'requirements.txt',
            'templates/base.html',
            'templates/index.html',
            'templates/gallery.html',
            'templates/admin.html',
            'static/css/style.css',
            'static/js/app.js'
        ]
        
        for file_path in files:
            exists = os.path.exists(file_path)
            self.log_test(f"File {file_path}", exists, f"{'exists' if exists else 'missing'}")
    
    def test_python_imports(self):
        """Testet ob alle Python-Module importiert werden können"""
        modules = ['flask', 'PIL', 'requests']
        
        for module in modules:
            try:
                __import__(module)
                self.log_test(f"Python module {module}", True, "importable")
            except ImportError as e:
                self.log_test(f"Python module {module}", False, str(e))
    
    def test_gphoto2_installation(self):
        """Testet gphoto2 Installation"""
        try:
            result = subprocess.run(['gphoto2', '--version'], 
                                  capture_output=True, text=True, check=True)
            version = result.stdout.split('\n')[0]
            self.log_test("gphoto2 installation", True, version)
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.log_test("gphoto2 installation", False, "not found or not working")
    
    def test_camera_detection(self):
        """Testet Kamera-Erkennung"""
        try:
            result = subprocess.run(['gphoto2', '--auto-detect'], 
                                  capture_output=True, text=True, check=True)
            camera_found = "Canon" in result.stdout
            self.log_test("Camera detection", camera_found, 
                         "Canon camera found" if camera_found else "No Canon camera detected")
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.log_test("Camera detection", False, "gphoto2 command failed")
    
    def test_flask_app_startup(self):
        """Testet ob Flask-App gestartet werden kann"""
        try:
            # Importiere App-Module
            sys.path.insert(0, '.')
            from app import app, camera, config
            
            self.log_test("Flask app import", True, "app module imported successfully")
            
            # Teste Konfiguration
            has_photo_dir = hasattr(config, 'PHOTO_DIR')
            self.log_test("App config", has_photo_dir, "configuration loaded")
            
            # Teste Kamera-Controller
            has_camera = hasattr(camera, 'check_camera')
            self.log_test("Camera controller", has_camera, "camera controller initialized")
            
        except Exception as e:
            self.log_test("Flask app startup", False, str(e))
    
    def test_web_endpoints(self):
        """Testet Web-Endpoints (wenn Server läuft)"""
        endpoints = [
            ('/', 'Main page'),
            ('/gallery', 'Gallery page'),
            ('/admin', 'Admin page'),
            ('/api/camera_status', 'Camera status API')
        ]
        
        for endpoint, description in endpoints:
            try:
                response = requests.get(f"{self.base_url}{endpoint}", timeout=5)
                success = response.status_code == 200
                self.log_test(f"Endpoint {endpoint}", success, 
                             f"HTTP {response.status_code} - {description}")
            except requests.exceptions.RequestException as e:
                self.log_test(f"Endpoint {endpoint}", False, f"Connection failed: {str(e)}")
    
    def test_static_files(self):
        """Testet statische Dateien"""
        static_files = [
            '/static/css/style.css',
            '/static/js/app.js'
        ]
        
        for static_file in static_files:
            try:
                response = requests.get(f"{self.base_url}{static_file}", timeout=5)
                success = response.status_code == 200
                self.log_test(f"Static file {static_file}", success, 
                             f"HTTP {response.status_code}")
            except requests.exceptions.RequestException:
                self.log_test(f"Static file {static_file}", False, "Not accessible")
    
    def test_permissions(self):
        """Testet Dateiberechtigungen"""
        # Teste Schreibberechtigung in photos-Verzeichnis
        try:
            test_file = os.path.join('photos', 'test_write.tmp')
            with open(test_file, 'w') as f:
                f.write('test')
            os.remove(test_file)
            self.log_test("Photos directory writable", True, "write test successful")
        except Exception as e:
            self.log_test("Photos directory writable", False, str(e))
        
        # Teste app.py Ausführungsberechtigung
        executable = os.access('app.py', os.X_OK)
        self.log_test("app.py executable", executable, 
                     "executable" if executable else "not executable")
    
    def run_all_tests(self):
        """Führt alle Tests aus"""
        print("🧪 Photobox Test Suite")
        print("=" * 50)
        print()
        
        print("📂 Testing file structure...")
        self.test_directories()
        self.test_files()
        print()
        
        print("🐍 Testing Python environment...")
        self.test_python_imports()
        self.test_flask_app_startup()
        print()
        
        print("📷 Testing camera setup...")
        self.test_gphoto2_installation()
        self.test_camera_detection()
        print()
        
        print("🔒 Testing permissions...")
        self.test_permissions()
        print()
        
        print("🌐 Testing web interface...")
        self.test_web_endpoints()
        self.test_static_files()
        print()
        
        self.print_summary()
    
    def print_summary(self):
        """Gibt Testergebnis-Zusammenfassung aus"""
        total = self.passed + self.failed
        success_rate = (self.passed / total * 100) if total > 0 else 0
        
        print("=" * 50)
        print("📊 TEST SUMMARY")
        print("=" * 50)
        print(f"Total tests: {total}")
        print(f"Passed: {self.passed} ✅")
        print(f"Failed: {self.failed} ❌")
        print(f"Success rate: {success_rate:.1f}%")
        print()
        
        if self.failed == 0:
            print("🎉 ALL TESTS PASSED! Photobox is ready to use.")
        else:
            print("⚠️ Some tests failed. Please check the issues above.")
            print()
            print("🔧 Common fixes:")
            print("  - Install missing Python packages: pip install -r requirements.txt")
            print("  - Install gphoto2: sudo apt install gphoto2 libgphoto2-dev")
            print("  - Check camera USB connection")
            print("  - Start Flask server: python app.py")
        
        print()
        print("📋 Next steps:")
        print("  1. Connect Canon EOS 2000D via USB")
        print("  2. Start server: python app.py")
        print("  3. Open browser: http://localhost:5000")
        print("  4. Take test photo")
        
        # Speichere Testergebnisse
        self.save_test_results()
    
    def save_test_results(self):
        """Speichert Testergebnisse in JSON-Datei"""
        try:
            results = {
                'timestamp': datetime.now().isoformat(),
                'summary': {
                    'total': self.passed + self.failed,
                    'passed': self.passed,
                    'failed': self.failed,
                    'success_rate': (self.passed / (self.passed + self.failed) * 100) if (self.passed + self.failed) > 0 else 0
                },
                'tests': self.test_results
            }
            
            with open('test_results.json', 'w') as f:
                json.dump(results, f, indent=2)
            
            print(f"📝 Test results saved to: test_results.json")
        except Exception as e:
            print(f"⚠️ Could not save test results: {e}")

def main():
    """Hauptfunktion"""
    tester = PhotoboxTester()
    
    # Argument-Parsing für spezifische Tests
    if len(sys.argv) > 1:
        test_name = sys.argv[1]
        
        test_methods = {
            'files': tester.test_files,
            'dirs': tester.test_directories,
            'python': tester.test_python_imports,
            'camera': tester.test_camera_detection,
            'gphoto2': tester.test_gphoto2_installation,
            'web': tester.test_web_endpoints,
            'permissions': tester.test_permissions,
            'app': tester.test_flask_app_startup
        }
        
        if test_name in test_methods:
            print(f"🧪 Running specific test: {test_name}")
            test_methods[test_name]()
            tester.print_summary()
        else:
            print(f"❌ Unknown test: {test_name}")
            print(f"Available tests: {', '.join(test_methods.keys())}")
    else:
        # Alle Tests ausführen
        tester.run_all_tests()

if __name__ == '__main__':
    main()