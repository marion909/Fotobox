#!/usr/bin/env python3
"""
Photobox Flask Application
Phase 2: Erweiterte Funktionen - Overlays, Drucken, Upload
"""

import os
import subprocess
import datetime
from flask import Flask, render_template, request, jsonify, send_file, redirect, url_for, flash
from PIL import Image
import json
import threading
import time

# Phase 2 Imports
from config import get_config, save_config, set_setting
from overlay_manager import OverlayManager
from print_manager import PrintManager
from upload_manager import UploadManager

app = Flask(__name__)
app.secret_key = 'photobox_phase2_secret_key_change_in_production'

# Phase 2 Konfiguration
from config import config_manager
config = config_manager.config
config_manager.create_directories()

# Phase 2 Manager initialisieren
overlay_manager = OverlayManager(config)
print_manager = PrintManager(config)  
upload_manager = UploadManager(config)

class CameraController:
    """Kamera-Controller für gphoto2"""
    
    def __init__(self):
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
    
    def take_photo(self, filename=None, apply_overlays=True, auto_print=None, auto_upload=None):
        """Nimmt ein Foto auf mit Phase 2 Features"""
        if not filename:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"photo_{timestamp}.jpg"
        
        filepath = os.path.join(config.photo_dir, filename)
        
        try:
            # Foto aufnehmen und direkt speichern
            result = subprocess.run([
                'gphoto2', 
                '--capture-image-and-download',
                '--filename', filepath
            ], capture_output=True, text=True, check=True)
            
            if os.path.exists(filepath):
                response = {
                    'success': True,
                    'filename': filename,
                    'filepath': filepath,
                    'message': 'Foto erfolgreich aufgenommen!',
                    'overlay_applied': False,
                    'print_queued': False,
                    'upload_queued': False
                }
                
                # Phase 2: Overlays anwenden
                if apply_overlays and config.overlay.enabled:
                    try:
                        overlay_path = overlay_manager.apply_overlays(filepath)
                        response['overlay_applied'] = True
                        response['overlay_path'] = overlay_path
                        response['message'] += ' Overlay angewendet.'
                    except Exception as e:
                        print(f"⚠️ Overlay-Fehler: {e}")
                
                # Phase 2: Automatisches Drucken
                if (auto_print or config.printing.auto_print) and config.printing.enabled:
                    threading.Thread(target=self._async_print, args=(filepath,)).start()
                    response['print_queued'] = True
                    response['message'] += ' Druck eingeplant.'
                
                # Phase 2: Automatischer Upload
                if (auto_upload or config.upload.auto_upload) and config.upload.enabled:
                    threading.Thread(target=self._async_upload, args=(filepath,)).start()
                    response['upload_queued'] = True  
                    response['message'] += ' Upload eingeplant.'
                
                return response
            else:
                return {
                    'success': False,
                    'message': 'Fehler beim Speichern des Fotos'
                }
                
        except subprocess.CalledProcessError as e:
            return {
                'success': False,
                'message': f'Kamera-Fehler: {e.stderr}'
            }
        except FileNotFoundError:
            return {
                'success': False,
                'message': 'gphoto2 nicht installiert oder nicht im PATH'
            }
    
    def _async_print(self, filepath):
        """Asynchrones Drucken"""
        try:
            time.sleep(1)  # Kurze Verzögerung
            result = print_manager.print_photo(filepath)
            print(f"🖨️ Druck-Ergebnis: {result['message']}")
        except Exception as e:
            print(f"❌ Druck-Fehler: {e}")
    
    def _async_upload(self, filepath):
        """Asynchroner Upload"""
        try:
            time.sleep(2)  # Kurze Verzögerung
            result = upload_manager.upload_photo(filepath)
            print(f"☁️ Upload-Ergebnis: {result['message']}")
        except Exception as e:
            print(f"❌ Upload-Fehler: {e}")

camera = CameraController()

class PhotoManager:
    """Verwaltung der aufgenommenen Fotos"""
    
    @staticmethod
    def get_all_photos():
        """Gibt Liste aller Fotos zurück"""
        photos = []
        if os.path.exists(config.photo_dir):
            for filename in os.listdir(config.photo_dir):
                if filename.lower().endswith(('.jpg', '.jpeg', '.png')):
                    filepath = os.path.join(config.photo_dir, filename)
                    stat = os.stat(filepath)
                    photos.append({
                        'filename': filename,
                        'size': stat.st_size,
                        'created': datetime.datetime.fromtimestamp(stat.st_ctime),
                        'url': f'/photo/{filename}'
                    })
        
        # Sortiere nach Erstellungszeit (neueste zuerst)
        photos.sort(key=lambda x: x['created'], reverse=True)
        return photos
    
    @staticmethod
    def get_photo_count():
        """Gibt Anzahl der Fotos zurück"""
        return len(PhotoManager.get_all_photos())

# Flask Routes

@app.route('/')
def index():
    """Hauptseite - Touch-UI"""
    photos = PhotoManager.get_all_photos()
    camera_status = camera.check_camera()
    
    return render_template('index.html', 
                         photos=photos[:6],  # Zeige nur die letzten 6 Fotos
                         photo_count=len(photos),
                         camera_connected=camera_status)

@app.route('/api/take_photo', methods=['POST'])
def api_take_photo():
    """API Endpoint zum Fotografieren"""
    result = camera.take_photo()
    return jsonify(result)

@app.route('/api/camera_status')
def api_camera_status():
    """API Endpoint für Kamera-Status"""
    status = camera.check_camera()
    return jsonify({
        'connected': status,
        'message': 'Kamera verbunden' if status else 'Kamera nicht gefunden'
    })

@app.route('/photo/<filename>')
def serve_photo(filename):
    """Einzelnes Foto ausliefern"""
    filepath = os.path.join(config.photo_dir, filename)
    if os.path.exists(filepath):
        return send_file(filepath)
    else:
        return "Foto nicht gefunden", 404

@app.route('/gallery')
def gallery():
    """Foto-Galerie"""
    photos = PhotoManager.get_all_photos()
    return render_template('gallery.html', photos=photos)

@app.route('/admin')
def admin():
    """Admin-Panel (Phase 3)"""
    return render_template('admin.html', 
                         camera_connected=camera.camera_detected,
                         photo_count=PhotoManager.get_photo_count())

@app.route('/api/test_camera')
def api_test_camera():
    """Testet die Kamera-Verbindung"""
    try:
        result = subprocess.run(['gphoto2', '--summary'], 
                              capture_output=True, text=True, check=True)
        return jsonify({
            'success': True,
            'summary': result.stdout
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

# Phase 2 API Endpoints

@app.route('/api/apply_overlay/<filename>', methods=['POST'])
def api_apply_overlay(filename):
    """Wendet Overlay auf ein vorhandenes Foto an"""
    filepath = os.path.join(config.photo_dir, filename)
    
    if not os.path.exists(filepath):
        return jsonify({
            'success': False,
            'message': 'Foto nicht gefunden'
        })
    
    try:
        overlay_path = overlay_manager.apply_overlays(filepath)
        return jsonify({
            'success': True,
            'message': 'Overlay erfolgreich angewendet',
            'original_path': filepath,
            'overlay_path': overlay_path
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Overlay-Fehler: {str(e)}'
        })

@app.route('/api/print_photo/<filename>', methods=['POST'])
def api_print_photo(filename):
    """Druckt ein Foto"""
    filepath = os.path.join(config.photo_dir, filename)
    
    if not os.path.exists(filepath):
        return jsonify({
            'success': False,
            'message': 'Foto nicht gefunden'
        })
    
    copies = request.json.get('copies', 1) if request.is_json else 1
    result = print_manager.print_photo(filepath, copies)
    
    return jsonify(result)

@app.route('/api/upload_photo/<filename>', methods=['POST'])
def api_upload_photo(filename):
    """Lädt ein Foto auf Server hoch"""
    filepath = os.path.join(config.photo_dir, filename)
    
    if not os.path.exists(filepath):
        return jsonify({
            'success': False,
            'message': 'Foto nicht gefunden'
        })
    
    metadata = request.json if request.is_json else None
    result = upload_manager.upload_photo(filepath, metadata)
    
    return jsonify(result)

@app.route('/api/printers')
def api_get_printers():
    """Gibt verfügbare Drucker zurück"""
    printers = print_manager.get_available_printers()
    return jsonify({
        'success': True,
        'printers': printers
    })

@app.route('/api/test_printer', methods=['POST'])
def api_test_printer():
    """Führt Drucker-Test durch"""
    result = print_manager.test_printer()
    return jsonify(result)

@app.route('/api/test_upload', methods=['POST'])
def api_test_upload():
    """Testet Upload-Verbindung"""
    result = upload_manager.test_connection()
    return jsonify(result)

@app.route('/api/config', methods=['GET', 'POST'])
def api_config():
    """Konfiguration abrufen oder setzen"""
    if request.method == 'GET':
        return jsonify({
            'success': True,
            'config': {
                'overlay': {
                    'enabled': config.overlay.enabled,
                    'text_enabled': config.overlay.text_enabled,
                    'text_content': config.overlay.text_content,
                    'logo_enabled': bool(config.overlay.logo_path and os.path.exists(config.overlay.logo_path))
                },
                'printing': {
                    'enabled': config.printing.enabled,
                    'auto_print': config.printing.auto_print,
                    'printer_name': config.printing.printer_name
                },
                'upload': {
                    'enabled': config.upload.enabled,
                    'auto_upload': config.upload.auto_upload,
                    'upload_method': config.upload.upload_method
                }
            }
        })
    
    elif request.method == 'POST':
        try:
            updates = request.json
            
            # Update Konfiguration
            for key, value in updates.items():
                if set_setting(key, value):
                    print(f"✅ Konfiguration aktualisiert: {key} = {value}")
                else:
                    print(f"⚠️ Konfiguration nicht gefunden: {key}")
            
            return jsonify({
                'success': True,
                'message': 'Konfiguration aktualisiert'
            })
        except Exception as e:
            return jsonify({
                'success': False,
                'message': f'Konfigurationsfehler: {str(e)}'
            })

# Hilfsfunktionen für Templates
@app.template_filter('datetime')
def datetime_filter(dt):
    """Template Filter für Datum/Zeit"""
    return dt.strftime('%d.%m.%Y %H:%M')

@app.template_filter('filesize')
def filesize_filter(size):
    """Template Filter für Dateigröße"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TB"

if __name__ == '__main__':
    print("🚀 Photobox Phase 2 startet...")
    print(f"📁 Fotos werden gespeichert in: {os.path.abspath(config.photo_dir)}")
    print(f"📷 Kamera verbunden: {'✓' if camera.camera_detected else '✗'}")
    print(f"� Overlays aktiviert: {'✓' if config.overlay.enabled else '✗'}")
    print(f"🖨️ Drucken aktiviert: {'✓' if config.printing.enabled else '✗'}")
    print(f"☁️ Upload aktiviert: {'✓' if config.upload.enabled else '✗'}")
    print("�🌐 Server läuft auf http://localhost:5000")
    print("👉 Für Touch-Interface im Vollbild öffnen")
    
    # Erstelle Beispiel-Overlays falls noch nicht vorhanden
    overlay_manager.create_sample_overlays()
    
    # Debug-Modus nur in der Entwicklung
    app.run(host='0.0.0.0', port=5000, debug=config.debug_mode)