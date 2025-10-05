#!/usr/bin/env python3
"""
Fotobox Upload-Manager - Phase 2  
Verwaltet Upload von Fotos auf Server via HTTP/SFTP
"""

import os
import requests
import json
from typing import Dict, Optional
import paramiko
import ftplib
from PIL import Image
import tempfile
import hashlib
import datetime
from urllib.parse import urljoin

class UploadManager:
    """Manager für Foto-Upload"""
    
    def __init__(self, config):
        self.config = config
        self.upload_config = config.upload
        
    def upload_photo(self, photo_path: str, metadata: Optional[Dict] = None) -> Dict[str, any]:
        """
        Lädt ein Foto auf den konfigurierten Server hoch
        
        Args:
            photo_path: Pfad zum Foto
            metadata: Zusätzliche Metadaten (optional)
            
        Returns:
            Dictionary mit Upload-Ergebnis
        """
        if not os.path.exists(photo_path):
            return {
                'success': False,
                'message': f'Foto nicht gefunden: {photo_path}'
            }
        
        if not self.upload_config.enabled:
            return {
                'success': False,
                'message': 'Upload ist deaktiviert'
            }
        
        try:
            # Bereite Foto für Upload vor
            upload_ready_path = self._prepare_photo_for_upload(photo_path)
            upload_metadata = self._prepare_metadata(photo_path, metadata)
            
            # Wähle Upload-Methode
            if self.upload_config.upload_method == 'http':
                result = self._upload_http(upload_ready_path, upload_metadata)
            elif self.upload_config.upload_method == 'sftp':
                result = self._upload_sftp(upload_ready_path, upload_metadata)
            elif self.upload_config.upload_method == 'ftp':
                result = self._upload_ftp(upload_ready_path, upload_metadata)
            else:
                result = {
                    'success': False,
                    'message': f'Unbekannte Upload-Methode: {self.upload_config.upload_method}'
                }
            
            # Aufräumen
            if upload_ready_path != photo_path:
                os.remove(upload_ready_path)
            
            return result
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Upload-Fehler: {str(e)}'
            }
    
    def _prepare_photo_for_upload(self, photo_path: str) -> str:
        """Bereitet Foto für Upload vor (Komprimierung, Thumbnail)"""
        if not self.upload_config.compress_images:
            return photo_path
        
        try:
            with Image.open(photo_path) as img:
                # Konvertiere zu RGB falls nötig
                if img.mode in ('RGBA', 'P'):
                    img = img.convert('RGB')
                
                # Prüfe Dateigröße
                original_size = os.path.getsize(photo_path) / (1024 * 1024)  # MB
                
                if original_size <= self.upload_config.max_file_size:
                    return photo_path
                
                # Komprimiere Bild
                quality = self.upload_config.compression_quality
                
                # Berechne neue Dimensionen falls nötig
                max_dimension = 2048  # Maximale Breite/Höhe
                if max(img.size) > max_dimension:
                    ratio = max_dimension / max(img.size)
                    new_size = (int(img.width * ratio), int(img.height * ratio))
                    img = img.resize(new_size, Image.Resampling.LANCZOS)
                
                # Speichere komprimierte Version
                temp_fd, temp_path = tempfile.mkstemp(suffix='.jpg', prefix='fotobox_upload_')
                os.close(temp_fd)
                
                img.save(temp_path, 'JPEG', quality=quality, optimize=True)
                
                # Prüfe ob Komprimierung erfolgreich war
                compressed_size = os.path.getsize(temp_path) / (1024 * 1024)
                if compressed_size <= self.upload_config.max_file_size:
                    return temp_path
                else:
                    os.remove(temp_path)
                    return photo_path  # Verwende Original falls Komprimierung nicht ausreicht
                    
        except Exception as e:
            print(f"⚠️ Fehler bei Foto-Vorbereitung: {e}")
            return photo_path
    
    def _prepare_metadata(self, photo_path: str, additional_metadata: Optional[Dict] = None) -> Dict:
        """Erstellt Metadaten für Upload"""
        now = datetime.datetime.now()
        
        # Basis-Metadaten
        metadata = {
            'filename': os.path.basename(photo_path),
            'filesize': os.path.getsize(photo_path),
            'upload_timestamp': now.isoformat(),
            'upload_date': now.strftime('%Y-%m-%d'),
            'upload_time': now.strftime('%H:%M:%S'),
            'source': 'fotobox',
            'version': self.config.version,
            'checksum': self._calculate_checksum(photo_path)
        }
        
        # Foto-Metadaten extrahieren
        try:
            with Image.open(photo_path) as img:
                metadata.update({
                    'width': img.width,
                    'height': img.height,
                    'format': img.format,
                    'mode': img.mode
                })
                
                # EXIF-Daten falls vorhanden
                if hasattr(img, '_getexif') and img._getexif():
                    exif = img._getexif()
                    metadata['exif'] = {k: str(v) for k, v in exif.items() if isinstance(v, (str, int, float))}
                    
        except Exception:
            pass
        
        # Zusätzliche Metadaten hinzufügen
        if additional_metadata:
            metadata.update(additional_metadata)
        
        return metadata
    
    def _calculate_checksum(self, file_path: str) -> str:
        """Berechnet SHA256-Checksum einer Datei"""
        sha256_hash = hashlib.sha256()
        with open(file_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)
        return sha256_hash.hexdigest()
    
    def _upload_http(self, photo_path: str, metadata: Dict) -> Dict[str, any]:
        """Lädt Foto via HTTP POST hoch"""
        if not self.upload_config.http_endpoint:
            return {
                'success': False,
                'message': 'HTTP-Endpoint nicht konfiguriert'
            }
        
        try:
            # Bereite Upload-Daten vor
            files = {
                'photo': (metadata['filename'], open(photo_path, 'rb'), 'image/jpeg')
            }
            
            data = {
                'metadata': json.dumps(metadata)
            }
            
            # Authentifizierung
            headers = {}
            if self.upload_config.http_api_key:
                headers['Authorization'] = f'Bearer {self.upload_config.http_api_key}'
            
            # Upload durchführen
            response = requests.post(
                self.upload_config.http_endpoint,
                files=files,
                data=data,
                headers=headers,
                timeout=self.upload_config.http_timeout
            )
            
            # Schließe Datei
            files['photo'][1].close()
            
            # Prüfe Antwort
            if response.status_code == 200:
                try:
                    result_data = response.json()
                    return {
                        'success': True,
                        'message': 'Upload erfolgreich',
                        'response': result_data,
                        'url': result_data.get('url', ''),
                        'file_id': result_data.get('id', ''),
                        'upload_method': 'http'
                    }
                except json.JSONDecodeError:
                    return {
                        'success': True,
                        'message': 'Upload erfolgreich (keine JSON-Antwort)',
                        'response': response.text,
                        'upload_method': 'http'
                    }
            else:
                return {
                    'success': False,
                    'message': f'HTTP-Fehler {response.status_code}: {response.text}'
                }
                
        except requests.exceptions.Timeout:
            return {
                'success': False,
                'message': 'Upload-Timeout erreicht'
            }
        except requests.exceptions.ConnectionError:
            return {
                'success': False,
                'message': 'Verbindung zum Server fehlgeschlagen'
            }
        except Exception as e:
            return {
                'success': False,
                'message': f'HTTP-Upload fehlgeschlagen: {str(e)}'
            }
    
    def _upload_sftp(self, photo_path: str, metadata: Dict) -> Dict[str, any]:
        """Lädt Foto via SFTP hoch"""
        if not all([self.upload_config.sftp_host, self.upload_config.sftp_username]):
            return {
                'success': False,
                'message': 'SFTP-Verbindungsdaten unvollständig'
            }
        
        ssh_client = None
        sftp_client = None
        
        try:
            # SSH-Verbindung aufbauen
            ssh_client = paramiko.SSHClient()
            ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            ssh_client.connect(
                hostname=self.upload_config.sftp_host,
                port=self.upload_config.sftp_port,
                username=self.upload_config.sftp_username,
                password=self.upload_config.sftp_password,
                timeout=30
            )
            
            # SFTP-Client erstellen
            sftp_client = ssh_client.open_sftp()
            
            # Ziel-Pfad erstellen
            now = datetime.datetime.now()
            remote_dir = os.path.join(
                self.upload_config.sftp_remote_path,
                now.strftime('%Y'),
                now.strftime('%m'),
                now.strftime('%d')
            ).replace('\\', '/')
            
            # Verzeichnis erstellen (falls nicht vorhanden)
            self._ensure_sftp_directory(sftp_client, remote_dir)
            
            # Datei-Upload
            remote_filename = f"{now.strftime('%H%M%S')}_{metadata['filename']}"
            remote_path = f"{remote_dir}/{remote_filename}".replace('\\', '/')
            
            sftp_client.put(photo_path, remote_path)
            
            # Metadaten als JSON-Datei hochladen
            metadata_filename = f"{os.path.splitext(remote_filename)[0]}.json"
            metadata_path = f"{remote_dir}/{metadata_filename}".replace('\\', '/')
            
            temp_metadata_file = tempfile.mktemp(suffix='.json')
            with open(temp_metadata_file, 'w', encoding='utf-8') as f:
                json.dump(metadata, f, indent=2, ensure_ascii=False)
            
            sftp_client.put(temp_metadata_file, metadata_path)
            os.remove(temp_metadata_file)
            
            return {
                'success': True,
                'message': 'SFTP-Upload erfolgreich',
                'remote_path': remote_path,
                'metadata_path': metadata_path,
                'upload_method': 'sftp'
            }
            
        except paramiko.AuthenticationException:
            return {
                'success': False,
                'message': 'SFTP-Authentifizierung fehlgeschlagen'
            }
        except paramiko.SSHException as e:
            return {
                'success': False,
                'message': f'SSH-Fehler: {str(e)}'
            }
        except Exception as e:
            return {
                'success': False,
                'message': f'SFTP-Upload fehlgeschlagen: {str(e)}'
            }
        finally:
            if sftp_client:
                sftp_client.close()
            if ssh_client:
                ssh_client.close()
    
    def _ensure_sftp_directory(self, sftp_client, directory: str):
        """Stellt sicher, dass SFTP-Verzeichnis existiert"""
        try:
            sftp_client.stat(directory)
        except FileNotFoundError:
            # Verzeichnis existiert nicht, erstelle es rekursiv
            parent_dir = os.path.dirname(directory).replace('\\', '/')
            if parent_dir and parent_dir != '/':
                self._ensure_sftp_directory(sftp_client, parent_dir)
            
            sftp_client.mkdir(directory)
    
    def _upload_ftp(self, photo_path: str, metadata: Dict) -> Dict[str, any]:
        """Lädt Foto via FTP hoch (einfache Implementierung)"""
        return {
            'success': False,
            'message': 'FTP-Upload noch nicht implementiert'
        }
    
    def create_thumbnail(self, photo_path: str, output_dir: Optional[str] = None) -> Optional[str]:
        """Erstellt Thumbnail für Upload"""
        if not self.upload_config.generate_thumbnails:
            return None
        
        try:
            output_dir = output_dir or self.config.temp_dir
            os.makedirs(output_dir, exist_ok=True)
            
            with Image.open(photo_path) as img:
                # Erstelle Thumbnail
                thumbnail_size = (self.upload_config.thumbnail_size, self.upload_config.thumbnail_size)
                img.thumbnail(thumbnail_size, Image.Resampling.LANCZOS)
                
                # Speichere Thumbnail
                base_name = os.path.splitext(os.path.basename(photo_path))[0]
                thumbnail_path = os.path.join(output_dir, f"{base_name}_thumb.jpg")
                
                img.save(thumbnail_path, 'JPEG', quality=85, optimize=True)
                return thumbnail_path
                
        except Exception as e:
            print(f"⚠️ Fehler beim Erstellen des Thumbnails: {e}")
            return None
    
    def test_connection(self) -> Dict[str, any]:
        """Testet die Upload-Verbindung"""
        if not self.upload_config.enabled:
            return {
                'success': False,
                'message': 'Upload ist deaktiviert'
            }
        
        if self.upload_config.upload_method == 'http':
            return self._test_http_connection()
        elif self.upload_config.upload_method == 'sftp':
            return self._test_sftp_connection()
        else:
            return {
                'success': False,
                'message': f'Test für {self.upload_config.upload_method} nicht implementiert'
            }
    
    def _test_http_connection(self) -> Dict[str, any]:
        """Testet HTTP-Verbindung"""
        if not self.upload_config.http_endpoint:
            return {
                'success': False,
                'message': 'HTTP-Endpoint nicht konfiguriert'
            }
        
        try:
            # Einfacher GET-Request zum Testen
            headers = {}
            if self.upload_config.http_api_key:
                headers['Authorization'] = f'Bearer {self.upload_config.http_api_key}'
            
            response = requests.get(
                self.upload_config.http_endpoint,
                headers=headers,
                timeout=10
            )
            
            return {
                'success': True,
                'message': f'HTTP-Verbindung erfolgreich (Status: {response.status_code})',
                'status_code': response.status_code
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'HTTP-Verbindung fehlgeschlagen: {str(e)}'
            }
    
    def _test_sftp_connection(self) -> Dict[str, any]:
        """Testet SFTP-Verbindung"""
        if not all([self.upload_config.sftp_host, self.upload_config.sftp_username]):
            return {
                'success': False,
                'message': 'SFTP-Verbindungsdaten unvollständig'
            }
        
        ssh_client = None
        
        try:
            ssh_client = paramiko.SSHClient()
            ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            ssh_client.connect(
                hostname=self.upload_config.sftp_host,
                port=self.upload_config.sftp_port,
                username=self.upload_config.sftp_username,
                password=self.upload_config.sftp_password,
                timeout=10
            )
            
            return {
                'success': True,
                'message': 'SFTP-Verbindung erfolgreich'
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'SFTP-Verbindung fehlgeschlagen: {str(e)}'
            }
        finally:
            if ssh_client:
                ssh_client.close()

def test_upload_manager():
    """Test-Funktion für den Upload-Manager"""
    from config import get_config
    
    config = get_config()
    upload_manager = UploadManager(config)
    
    # Teste Verbindung
    result = upload_manager.test_connection()
    print(f"🌐 Upload-Verbindungstest: {result['message']}")
    
    print("🧪 Upload-Manager Test abgeschlossen")

if __name__ == "__main__":
    test_upload_manager()