"""
PHP-Konfigurationsverwaltung für Fotobox Server Upload
Ermöglicht das Lesen und Schreiben von PHP-Konfigurationsdateien
"""

import re
import os
import json
from typing import Dict, Any, Optional


class PHPConfigManager:
    """Verwaltet PHP-Konfigurationsdateien für Server-Upload"""
    
    def __init__(self, config_path: str):
        self.config_path = config_path
        
    def read_php_config(self) -> Dict[str, Any]:
        """Liest die aktuelle PHP-Konfiguration"""
        if not os.path.exists(self.config_path):
            return {}
            
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            config = {}
            
            # Definierte Konstanten extrahieren
            define_pattern = r"define\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*(.+?)\s*\);"
            matches = re.findall(define_pattern, content, re.MULTILINE)
            
            for name, value in matches:
                # Werte parsen
                value = value.strip()
                
                # String-Werte (in Anführungszeichen)
                if value.startswith(("'", '"')) and value.endswith(("'", '"')):
                    config[name] = value[1:-1]
                # Boolean-Werte
                elif value.lower() in ('true', 'false'):
                    config[name] = value.lower() == 'true'
                # Numerische Werte
                elif value.isdigit():
                    config[name] = int(value)
                # Berechnete Werte (z.B. 10 * 1024 * 1024)
                elif '*' in value and all(part.strip().isdigit() for part in value.split('*')):
                    try:
                        config[name] = eval(value)
                    except:
                        config[name] = value
                # Arrays
                elif value.startswith('[') and value.endswith(']'):
                    try:
                        # Einfache Array-Parsing für PHP-Arrays
                        array_content = value[1:-1].strip()
                        if array_content:
                            items = [item.strip().strip('\'"') for item in array_content.split(',')]
                            config[name] = [item for item in items if item]
                        else:
                            config[name] = []
                    except:
                        config[name] = value
                else:
                    config[name] = value
            
            return config
            
        except Exception as e:
            print(f"Fehler beim Lesen der PHP-Konfiguration: {e}")
            return {}
    
    def write_php_config(self, config: Dict[str, Any]) -> bool:
        """Schreibt die PHP-Konfiguration zurück"""
        if not os.path.exists(self.config_path):
            print(f"PHP-Konfigurationsdatei nicht gefunden: {self.config_path}")
            return False
            
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Jede define-Zeile einzeln ersetzen
            for key, value in config.items():
                pattern = rf"(define\s*\(\s*['\"]({re.escape(key)})['\"]\s*,\s*)(.+?)(\s*\);)"
                
                # Neuen Wert formatieren
                if isinstance(value, str):
                    new_value = f"'{value}'"
                elif isinstance(value, bool):
                    new_value = 'true' if value else 'false'
                elif isinstance(value, (int, float)):
                    new_value = str(value)
                elif isinstance(value, list):
                    # Array formatieren
                    items = [f"'{item}'" if isinstance(item, str) else str(item) for item in value]
                    new_value = '[' + ', '.join(items) + ']'
                else:
                    new_value = f"'{str(value)}'"
                
                replacement = rf"\g<1>{new_value}\g<4>"
                content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            
            # Backup der originalen Datei
            backup_path = f"{self.config_path}.backup"
            with open(backup_path, 'w', encoding='utf-8') as f:
                with open(self.config_path, 'r', encoding='utf-8') as original:
                    f.write(original.read())
            
            # Neue Konfiguration schreiben
            with open(self.config_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            return True
            
        except Exception as e:
            print(f"Fehler beim Schreiben der PHP-Konfiguration: {e}")
            return False
    
    def update_config_value(self, key: str, value: Any) -> bool:
        """Aktualisiert einen einzelnen Konfigurationswert"""
        config = self.read_php_config()
        config[key] = value
        return self.write_php_config(config)
    
    def get_server_config_for_admin(self) -> Dict[str, Any]:
        """Holt die Server-Konfiguration für die Admin-Oberfläche"""
        php_config = self.read_php_config()
        
        return {
            'server_upload_enabled': php_config.get('API_KEY', '') != '',
            'api_key': php_config.get('API_KEY', ''),
            'base_url': php_config.get('BASE_URL', ''),
            'max_file_size_mb': php_config.get('MAX_FILE_SIZE', 0) // (1024 * 1024),
            'create_thumbnails': php_config.get('CREATE_THUMBNAILS', False),
            'thumbnail_size': php_config.get('THUMBNAIL_SIZE', 200),
            'enable_gallery': php_config.get('ENABLE_GALLERY', False),
            'gallery_items_per_page': php_config.get('GALLERY_ITEMS_PER_PAGE', 20),
            'admin_password': php_config.get('ADMIN_PASSWORD', ''),
            'auto_delete_days': php_config.get('AUTO_DELETE_DAYS', 0),
            'enable_statistics': php_config.get('ENABLE_STATISTICS', False),
            'strip_exif': php_config.get('STRIP_EXIF', True),
            'add_watermark': php_config.get('ADD_WATERMARK', False),
            'watermark_text': php_config.get('WATERMARK_TEXT', ''),
            'email_notifications': php_config.get('ENABLE_EMAIL_NOTIFICATIONS', False),
            'smtp_host': php_config.get('SMTP_HOST', ''),
            'smtp_port': php_config.get('SMTP_PORT', 587),
            'smtp_username': php_config.get('SMTP_USERNAME', ''),
            'notification_from': php_config.get('NOTIFICATION_FROM', ''),
            'notification_to': php_config.get('NOTIFICATION_TO', '')
        }
    
    def update_server_config_from_admin(self, admin_data: Dict[str, Any]) -> bool:
        """Aktualisiert die Server-Konfiguration aus Admin-Daten"""
        try:
            updates = {}
            
            # Mapping von Admin-Feldern zu PHP-Konstanten
            if 'api_key' in admin_data:
                updates['API_KEY'] = admin_data['api_key']
            
            if 'base_url' in admin_data:
                updates['BASE_URL'] = admin_data['base_url']
            
            if 'max_file_size_mb' in admin_data:
                updates['MAX_FILE_SIZE'] = int(admin_data['max_file_size_mb']) * 1024 * 1024
            
            if 'create_thumbnails' in admin_data:
                updates['CREATE_THUMBNAILS'] = bool(admin_data['create_thumbnails'])
            
            if 'thumbnail_size' in admin_data:
                updates['THUMBNAIL_SIZE'] = int(admin_data['thumbnail_size'])
            
            if 'enable_gallery' in admin_data:
                updates['ENABLE_GALLERY'] = bool(admin_data['enable_gallery'])
            
            if 'gallery_items_per_page' in admin_data:
                updates['GALLERY_ITEMS_PER_PAGE'] = int(admin_data['gallery_items_per_page'])
            
            if 'admin_password' in admin_data:
                updates['ADMIN_PASSWORD'] = admin_data['admin_password']
            
            if 'auto_delete_days' in admin_data:
                updates['AUTO_DELETE_DAYS'] = int(admin_data['auto_delete_days'])
            
            if 'enable_statistics' in admin_data:
                updates['ENABLE_STATISTICS'] = bool(admin_data['enable_statistics'])
            
            if 'strip_exif' in admin_data:
                updates['STRIP_EXIF'] = bool(admin_data['strip_exif'])
            
            if 'add_watermark' in admin_data:
                updates['ADD_WATERMARK'] = bool(admin_data['add_watermark'])
            
            if 'watermark_text' in admin_data:
                updates['WATERMARK_TEXT'] = admin_data['watermark_text']
            
            if 'email_notifications' in admin_data:
                updates['ENABLE_EMAIL_NOTIFICATIONS'] = bool(admin_data['email_notifications'])
            
            if 'smtp_host' in admin_data:
                updates['SMTP_HOST'] = admin_data['smtp_host']
            
            if 'smtp_port' in admin_data:
                updates['SMTP_PORT'] = int(admin_data['smtp_port'])
            
            if 'smtp_username' in admin_data:
                updates['SMTP_USERNAME'] = admin_data['smtp_username']
            
            if 'notification_from' in admin_data:
                updates['NOTIFICATION_FROM'] = admin_data['notification_from']
            
            if 'notification_to' in admin_data:
                updates['NOTIFICATION_TO'] = admin_data['notification_to']
            
            return self.write_php_config(updates)
            
        except Exception as e:
            print(f"Fehler beim Aktualisieren der Server-Konfiguration: {e}")
            return False


# Globale Instanz für Server Upload Konfiguration
server_upload_config_path = os.path.join(os.path.dirname(__file__), 'Server_Upload', 'config.php')
php_config_manager = PHPConfigManager(server_upload_config_path)


if __name__ == "__main__":
    # Test der PHP-Konfigurationsverwaltung
    print("=== PHP Konfiguration Test ===")
    
    # Aktuelle Konfiguration lesen
    config = php_config_manager.read_php_config()
    print(f"Gelesene Konfiguration: {json.dumps(config, indent=2, default=str)}")
    
    # Server-Konfiguration für Admin-Panel
    admin_config = php_config_manager.get_server_config_for_admin()
    print(f"Admin-Konfiguration: {json.dumps(admin_config, indent=2)}")