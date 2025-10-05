#!/usr/bin/env python3
"""
Photobox Flask Application
Phase 1: Grundfunktion - Kamerasteuerung und Touch-UI
"""

import os
import subprocess
import datetime
from flask import Flask, render_template, request, jsonify, send_file, redirect, url_for
from PIL import Image
import json

app = Flask(__name__)

# Konfiguration
class Config:
    PHOTO_DIR = "photos"
    OVERLAY_DIR = "overlays"
    TEMP_DIR = "temp"
    
    # Server Upload Settings (Phase 2)
    UPLOAD_SERVER = ""
    API_KEY = ""
    
    # Print Settings (Phase 2)
    PRINTER_NAME = ""
    PRINT_SIZE = (1200, 1800)  # 10x15 cm in pixels
    
    def __init__(self):
        # Erstelle notwendige Verzeichnisse
        for directory in [self.PHOTO_DIR, self.OVERLAY_DIR, self.TEMP_DIR]:
            os.makedirs(directory, exist_ok=True)

config = Config()

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
    
    def take_photo(self, filename=None):
        """Nimmt ein Foto auf"""
        if not filename:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"photo_{timestamp}.jpg"
        
        filepath = os.path.join(config.PHOTO_DIR, filename)
        
        try:
            # Foto aufnehmen und direkt speichern
            result = subprocess.run([
                'gphoto2', 
                '--capture-image-and-download',
                '--filename', filepath
            ], capture_output=True, text=True, check=True)
            
            if os.path.exists(filepath):
                return {
                    'success': True,
                    'filename': filename,
                    'filepath': filepath,
                    'message': 'Foto erfolgreich aufgenommen!'
                }
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

camera = CameraController()

class PhotoManager:
    """Verwaltung der aufgenommenen Fotos"""
    
    @staticmethod
    def get_all_photos():
        """Gibt Liste aller Fotos zurück"""
        photos = []
        if os.path.exists(config.PHOTO_DIR):
            for filename in os.listdir(config.PHOTO_DIR):
                if filename.lower().endswith(('.jpg', '.jpeg', '.png')):
                    filepath = os.path.join(config.PHOTO_DIR, filename)
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
    filepath = os.path.join(config.PHOTO_DIR, filename)
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
    print("🚀 Photobox startet...")
    print(f"📁 Fotos werden gespeichert in: {os.path.abspath(config.PHOTO_DIR)}")
    print(f"📷 Kamera verbunden: {'✓' if camera.camera_detected else '✗'}")
    print("🌐 Server läuft auf http://localhost:5000")
    print("👉 Für Touch-Interface im Vollbild öffnen")
    
    # Debug-Modus nur in der Entwicklung
    app.run(host='0.0.0.0', port=5000, debug=True)