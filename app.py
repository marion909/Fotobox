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
from optimal_camera_manager import optimal_camera_manager

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

# Verwende den optimalen camera manager (nur gphoto2 Python)
camera = optimal_camera_manager

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

@app.route('/capture', methods=['POST'])
def capture_photo():
    """Alias für /api/take_photo (Kompatibilität)"""
    result = camera.take_photo()
    return jsonify(result)

@app.route('/api/start_live_preview', methods=['POST'])
def api_start_live_preview():
    """API Endpoint zum Starten der Live-Vorschau"""
    result = camera.start_live_preview()
    return jsonify(result)

@app.route('/api/stop_live_preview', methods=['POST'])
def api_stop_live_preview():
    """API Endpoint zum Stoppen der Live-Vorschau"""
    camera.stop_live_preview()
    return jsonify({'success': True})

@app.route('/api/preview_image')
def api_preview_image():
    """API Endpoint für aktuelles Preview-Bild"""
    preview_path = camera.capture_preview_image()
    if preview_path and os.path.exists(preview_path):
        return send_file(preview_path, mimetype='image/jpeg')
    else:
        return "Preview nicht verfügbar", 404

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
                },
                'countdown': {
                    'enabled': config.countdown_enabled,
                    'duration': config.countdown_duration
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

# Phase 3: Kiosk & Deployment API-Endpunkte
@app.route('/api/kiosk/toggle', methods=['POST'])
def toggle_kiosk_mode():
    """Kiosk-Modus ein/ausschalten"""
    try:
        data = request.get_json()
        enabled = data.get('enabled', False)
        
        # Kiosk-Status in Konfiguration speichern
        config.kiosk_mode = enabled
        save_config()
        
        return jsonify({'success': True, 'kiosk_mode': enabled})
        
    except Exception as e:
        print(f"Kiosk-Toggle-Fehler: {e}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/autostart/toggle', methods=['POST'])
def toggle_autostart():
    """Autostart ein/ausschalten"""
    try:
        data = request.get_json()
        enabled = data.get('enabled', False)
        
        # Autostart-Status in Konfiguration speichern
        config.autostart_enabled = enabled
        save_config()
        
        return jsonify({'success': True, 'autostart_enabled': enabled})
        
    except Exception as e:
        print(f"Autostart-Toggle-Fehler: {e}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/system/restart', methods=['POST'])
def restart_system():
    """System neustarten"""
    try:
        import subprocess
        
        # Neustart-Befehl ausführen (funktioniert nur auf Linux/Raspberry Pi)
        subprocess.run(['sudo', 'reboot'], check=False)
        
        return jsonify({'success': True, 'message': 'System wird neugestartet...'})
        
    except Exception as e:
        print(f"Neustart-Fehler: {e}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/system/shutdown', methods=['POST'])
def shutdown_system():
    """System herunterfahren"""
    try:
        import subprocess
        
        # Shutdown-Befehl ausführen (funktioniert nur auf Linux/Raspberry Pi)
        subprocess.run(['sudo', 'shutdown', '-h', 'now'], check=False)
        
        return jsonify({'success': True, 'message': 'System wird heruntergefahren...'})
        
    except Exception as e:
        print(f"Shutdown-Fehler: {e}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/backup/create', methods=['POST'])
def create_backup():
    """Backup erstellen"""
    try:
        import subprocess
        import datetime
        
        # Backup-Script ausführen (nur auf Raspberry Pi verfügbar)
        result = subprocess.run(['/home/pi/backup_photobox.sh'], 
                              capture_output=True, text=True, check=False)
        
        if result.returncode == 0:
            timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            return jsonify({
                'success': True, 
                'message': f'Backup erfolgreich erstellt: {timestamp}'
            })
        else:
            return jsonify({
                'success': False, 
                'error': f'Backup-Fehler: {result.stderr}'
            })
        
    except Exception as e:
        print(f"Backup-Fehler: {e}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/config/export', methods=['GET'])
def export_config():
    """Konfiguration exportieren"""
    try:
        import datetime
        
        config_data = {
            'overlay_enabled': config.overlay.enabled,
            'overlay_text_enabled': config.overlay.text_enabled,
            'overlay_text_content': config.overlay.text_content,
            'printing_enabled': config.printing.enabled,
            'printing_auto_print': config.printing.auto_print,
            'upload_enabled': config.upload.enabled,
            'upload_auto_upload': config.upload.auto_upload,
            'upload_method': config.upload.upload_method,
            'kiosk_mode': getattr(config, 'kiosk_mode', False),
            'autostart_enabled': getattr(config, 'autostart_enabled', False),
            'backup_enabled': getattr(config, 'backup_enabled', True),
            'screen_timeout': getattr(config, 'screen_timeout', 10),
            'export_timestamp': datetime.datetime.now().isoformat()
        }
        
        return jsonify({
            'success': True,
            'config': config_data,
            'filename': f'photobox_config_{datetime.datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
        })
        
    except Exception as e:
        print(f"Config-Export-Fehler: {e}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/config/import', methods=['POST'])
def import_config():
    """Konfiguration importieren"""
    try:
        data = request.get_json()
        if not data or 'config' not in data:
            return jsonify({'success': False, 'error': 'Ungültige Konfigurationsdaten'})
        
        config_data = data['config']
        
        # Konfiguration aktualisieren (nur sichere Werte)
        safe_mapping = {
            'overlay_enabled': 'overlay.enabled',
            'overlay_text_enabled': 'overlay.text_enabled',
            'overlay_text_content': 'overlay.text_content',
            'printing_enabled': 'printing.enabled',
            'printing_auto_print': 'printing.auto_print',
            'upload_enabled': 'upload.enabled',
            'upload_auto_upload': 'upload.auto_upload',
            'upload_method': 'upload.upload_method',
            'kiosk_mode': 'kiosk_mode',
            'autostart_enabled': 'autostart_enabled',
            'backup_enabled': 'backup_enabled',
            'screen_timeout': 'screen_timeout'
        }
        
        for key, config_path in safe_mapping.items():
            if key in config_data:
                set_setting(config_path, config_data[key])
        
        save_config()
        
        return jsonify({'success': True, 'message': 'Konfiguration importiert'})
        
    except Exception as e:
        print(f"Config-Import-Fehler: {e}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/config/reset', methods=['POST'])
def reset_config():
    """Konfiguration auf Standardwerte zurücksetzen"""
    try:
        # Neue Standard-Konfiguration erstellen
        global config
        from config import create_default_config
        config = create_default_config()
        save_config()
        
        return jsonify({'success': True, 'message': 'Konfiguration zurückgesetzt'})
        
    except Exception as e:
        print(f"Config-Reset-Fehler: {e}")
        return jsonify({'success': False, 'error': str(e)})

# Phase 4 API: Countdown-Einstellungen
@app.route('/api/countdown', methods=['GET', 'POST'])
def api_countdown():
    """API für Countdown-Einstellungen"""
    if request.method == 'GET':
        return jsonify({
            'success': True,
            'countdown': {
                'enabled': config.countdown_enabled,
                'duration': config.countdown_duration
            }
        })
    
    elif request.method == 'POST':
        try:
            data = request.json
            
            if 'enabled' in data:
                config.countdown_enabled = bool(data['enabled'])
                set_setting('countdown_enabled', config.countdown_enabled)
                
            if 'duration' in data:
                duration = int(data['duration'])
                if 1 <= duration <= 10:  # Sinnvolle Grenzen
                    config.countdown_duration = duration
                    set_setting('countdown_duration', config.countdown_duration)
                else:
                    return jsonify({'success': False, 'error': 'Countdown muss zwischen 1 und 10 Sekunden sein'})
            
            save_config()
            
            return jsonify({
                'success': True,
                'message': 'Countdown-Einstellungen gespeichert',
                'countdown': {
                    'enabled': config.countdown_enabled,
                    'duration': config.countdown_duration
                }
            })
            
        except Exception as e:
            print(f"Countdown-Config-Fehler: {e}")
            return jsonify({'success': False, 'error': str(e)})

# Phase 4: Route für erweiterte Features
@app.route('/features')
def features():
    """Erweiterte Features - Phase 4"""
    return render_template('features.html',
                         countdown_enabled=config.countdown_enabled,
                         countdown_duration=config.countdown_duration)

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