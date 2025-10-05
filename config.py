#!/usr/bin/env python3
"""
Photobox Konfiguration - Phase 2
Erweiterte Einstellungen für Overlays, Drucken und Server-Upload
"""

import os
import json
from dataclasses import dataclass, asdict
from typing import Dict, Optional, List

@dataclass
class OverlayConfig:
    """Konfiguration für Foto-Overlays"""
    enabled: bool = False
    logo_path: str = "overlays/logo.png"
    logo_position: str = "bottom-right"  # bottom-right, bottom-left, top-right, top-left, center
    logo_size: int = 150  # Pixel
    logo_opacity: float = 0.8
    
    text_enabled: bool = False
    text_content: str = "Photobox 2025"
    text_position: str = "bottom-center"
    text_font_size: int = 48
    text_color: str = "#FFFFFF"
    text_shadow: bool = True
    
    frame_enabled: bool = False
    frame_path: str = "overlays/frame.png"
    frame_type: str = "border"  # border, full-overlay

@dataclass 
class PrintConfig:
    """Konfiguration für automatisches Drucken"""
    enabled: bool = False
    auto_print: bool = False
    printer_name: str = ""
    paper_size: str = "10x15cm"  # 10x15cm, 13x18cm, A4
    print_quality: str = "high"  # draft, normal, high, photo
    copies: int = 1
    
    # Druckbereich-Anpassungen
    margin_top: int = 0
    margin_bottom: int = 0
    margin_left: int = 0
    margin_right: int = 0

@dataclass
class UploadConfig:
    """Konfiguration für Server-Upload"""
    enabled: bool = False
    auto_upload: bool = False
    upload_method: str = "http"  # http, sftp, ftp
    
    # HTTP Upload
    http_endpoint: str = ""
    http_api_key: str = ""
    http_timeout: int = 30
    
    # SFTP Upload  
    sftp_host: str = ""
    sftp_port: int = 22
    sftp_username: str = ""
    sftp_password: str = ""
    sftp_remote_path: str = "/uploads/"
    
    # Allgemeine Upload-Einstellungen
    compress_images: bool = True
    compression_quality: int = 85
    max_file_size: int = 5  # MB
    generate_thumbnails: bool = True
    thumbnail_size: int = 300

@dataclass
class ThemeConfig:
    """Konfiguration für UI-Themes"""
    active_theme: str = "default"
    custom_css: str = ""
    
    # Farben
    primary_color: str = "#007bff"
    secondary_color: str = "#6c757d"
    success_color: str = "#28a745"
    danger_color: str = "#dc3545"
    
    # Schriftarten
    font_family: str = "system"
    font_size_base: str = "16px"
    
    # Layout
    border_radius: str = "12px"
    shadow_level: str = "normal"

@dataclass
class AppConfig:
    """Haupt-Konfiguration der Photobox"""
    # Basis-Einstellungen
    app_name: str = "Photobox"
    version: str = "2.0.0"
    debug_mode: bool = False
    
    # Verzeichnisse
    photo_dir: str = "photos"
    overlay_dir: str = "overlays" 
    temp_dir: str = "temp"
    backup_dir: str = "backups"
    
    # Kamera-Einstellungen
    camera_model: str = "Canon EOS 2000D"
    photo_format: str = "JPEG"
    photo_quality: str = "Fine"
    
    # Countdown
    countdown_enabled: bool = True
    countdown_duration: int = 3
    
    # Feature-Konfigurationen
    overlay: OverlayConfig = None
    printing: PrintConfig = None
    upload: UploadConfig = None
    theme: ThemeConfig = None
    
    # Phase 3: Kiosk & Deployment
    kiosk_mode: bool = False
    autostart_enabled: bool = False
    screen_timeout: int = 10  # Minuten, 0 = nie ausschalten
    backup_enabled: bool = True
    backup_retention_days: int = 7
    auto_update: bool = False
    maintenance_mode: bool = False
    
    def __post_init__(self):
        if self.overlay is None:
            self.overlay = OverlayConfig()
        if self.printing is None:
            self.printing = PrintConfig()
        if self.upload is None:
            self.upload = UploadConfig()
        if self.theme is None:
            self.theme = ThemeConfig()

class ConfigManager:
    """Verwaltung der Photobox-Konfiguration"""
    
    def __init__(self, config_file: str = "config.json"):
        self.config_file = config_file
        self.config = self.load_config()
    
    def load_config(self) -> AppConfig:
        """Lädt Konfiguration aus Datei oder erstellt Standard-Konfiguration"""
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                return self._dict_to_config(data)
            except Exception as e:
                print(f"⚠️ Fehler beim Laden der Konfiguration: {e}")
                print("📋 Verwende Standard-Konfiguration")
                
        return AppConfig()
    
    def save_config(self) -> bool:
        """Speichert aktuelle Konfiguration in Datei"""
        try:
            config_dict = self._config_to_dict(self.config)
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config_dict, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"❌ Fehler beim Speichern der Konfiguration: {e}")
            return False
    
    def _config_to_dict(self, config: AppConfig) -> Dict:
        """Konvertiert AppConfig zu Dictionary"""
        return {
            **asdict(config),
            'overlay': asdict(config.overlay),
            'printing': asdict(config.printing),
            'upload': asdict(config.upload),
            'theme': asdict(config.theme)
        }
    
    def _dict_to_config(self, data: Dict) -> AppConfig:
        """Konvertiert Dictionary zu AppConfig"""
        overlay_data = data.pop('overlay', {})
        printing_data = data.pop('printing', {})
        upload_data = data.pop('upload', {})
        theme_data = data.pop('theme', {})
        
        config = AppConfig(**data)
        config.overlay = OverlayConfig(**overlay_data)
        config.printing = PrintConfig(**printing_data)
        config.upload = UploadConfig(**upload_data)
        config.theme = ThemeConfig(**theme_data)
        
        return config
    
    def get(self, key: str, default=None):
        """Holt Konfigurationswert"""
        keys = key.split('.')
        value = self.config
        
        for k in keys:
            if hasattr(value, k):
                value = getattr(value, k)
            else:
                return default
                
        return value
    
    def set(self, key: str, value) -> bool:
        """Setzt Konfigurationswert"""
        keys = key.split('.')
        obj = self.config
        
        for k in keys[:-1]:
            if hasattr(obj, k):
                obj = getattr(obj, k)
            else:
                return False
        
        if hasattr(obj, keys[-1]):
            setattr(obj, keys[-1], value)
            return self.save_config()
        
        return False
    
    def reset_to_defaults(self):
        """Setzt Konfiguration auf Standard-Werte zurück"""
        self.config = AppConfig()
        self.save_config()
    
    def create_directories(self):
        """Erstellt alle benötigten Verzeichnisse"""
        directories = [
            self.config.photo_dir,
            self.config.overlay_dir,
            self.config.temp_dir,
            self.config.backup_dir
        ]
        
        for directory in directories:
            os.makedirs(directory, exist_ok=True)

# Globale Konfiguration
config_manager = ConfigManager()

# Convenience-Funktionen
def get_config() -> AppConfig:
    """Holt die aktuelle Konfiguration"""
    return config_manager.config

def save_config() -> bool:
    """Speichert die aktuelle Konfiguration"""
    return config_manager.save_config()

def get_setting(key: str, default=None):
    """Holt einen spezifischen Konfigurationswert"""
    return config_manager.get(key, default)

def set_setting(key: str, value) -> bool:
    """Setzt einen spezifischen Konfigurationswert"""
    return config_manager.set(key, value)

if __name__ == "__main__":
    # Test der Konfiguration
    print("📋 Photobox Konfiguration - Test")
    
    config = get_config()
    print(f"App Name: {config.app_name}")
    print(f"Version: {config.version}")
    print(f"Overlay aktiviert: {config.overlay.enabled}")
    print(f"Drucken aktiviert: {config.printing.enabled}")
    print(f"Upload aktiviert: {config.upload.enabled}")
    
    # Speichere Standard-Konfiguration
    if save_config():
        print("✅ Konfiguration gespeichert: config.json")
    else:
        print("❌ Fehler beim Speichern")