# fotobox Server Upload

PHP-basiertes Upload-System für die fotobox-Anwendung.

## 📋 Übersicht

Dieses System ermöglicht es der fotobox-Anwendung, Fotos auf einen Webserver hochzuladen und über eine Web-Galerie anzuzeigen.

## 🚀 Installation

### 1. Dateien hochladen
Laden Sie alle Dateien in ein Verzeichnis auf Ihrem Webserver hoch:
```
/fotobox/
├── upload.php
├── config.php
├── gallery.php
├── README.md
└── uploads/ (wird automatisch erstellt)
```

### 2. Berechtigungen setzen
```bash
chmod 755 /pfad/zum/fotobox/
chmod 644 *.php
mkdir uploads
chmod 755 uploads/
```

### 3. Konfiguration anpassen
Bearbeiten Sie `config.php`:

```php
// WICHTIG: API-Key ändern!
define('API_KEY', 'ihr-sicherer-api-key-hier');

// Basis-URL anpassen
define('BASE_URL', 'https://ihre-domain.com/fotobox');

// Admin-Passwort ändern
define('ADMIN_PASSWORD', 'ihr-sicheres-passwort');
```

### 4. fotobox-App konfigurieren
In der fotobox-App unter "Admin" → "Upload-Einstellungen":
- **Upload-URL**: `https://ihre-domain.com/fotobox/upload.php`
- **API-Key**: Der gleiche Key aus `config.php`

## 🔧 Konfiguration

### Sicherheitseinstellungen
```php
// API-Authentifizierung
define('API_KEY', 'generieren-sie-einen-sicheren-key');

// Maximale Dateigröße (10MB)
define('MAX_FILE_SIZE', 10 * 1024 * 1024);

// Admin-Passwort für Galerie
define('ADMIN_PASSWORD', 'sicheres-passwort');
```

### Upload-Einstellungen
```php
// Upload-Verzeichnis
define('UPLOAD_DIR', __DIR__ . '/uploads');

// Thumbnails erstellen
define('CREATE_THUMBNAILS', true);
define('THUMBNAIL_SIZE', 200);

// Erlaubte Dateiformate
define('ALLOWED_EXTENSIONS', ['jpg', 'jpeg', 'png']);
```

### Galerie-Einstellungen
```php
// Öffentliche Galerie
define('ENABLE_GALLERY', true);

// Bilder pro Seite
define('GALLERY_ITEMS_PER_PAGE', 20);

// Automatische Löschung (30 Tage)
define('AUTO_DELETE_DAYS', 30);
```

## 📱 Verwendung

### Upload via fotobox
1. Foto in der fotobox-App aufnehmen
2. "Hochladen" auswählen
3. Foto wird automatisch übertragen
4. Bestätigung in der App

### Web-Galerie
- **URL**: `https://ihre-domain.com/fotobox/gallery.php`
- **Admin-Bereich**: Login-Button oben rechts
- **Funktionen**: Fotos anzeigen, löschen (als Admin)

## 🛠️ API-Endpunkte

### Upload-Endpunkt
```
POST /upload.php
Content-Type: multipart/form-data
Authorization: Bearer YOUR_API_KEY

Parameter:
- photo: Bilddatei (JPG/PNG)
- metadata: JSON mit Metadaten (optional)
```

### Antwort-Format
```json
{
    "success": true,
    "message": "File uploaded successfully",
    "data": {
        "id": "abc123def",
        "filename": "fotobox_2024-01-01_12-34-56_abc123def.jpg",
        "url": "https://domain.com/fotobox/uploads/2024/01/01/fotobox_2024-01-01_12-34-56_abc123def.jpg",
        "thumbnail": "https://domain.com/fotobox/uploads/2024/01/01/thumbnails/thumb_fotobox_2024-01-01_12-34-56_abc123def.jpg",
        "size": 1234567,
        "upload_time": "2024-01-01 12:34:56"
    }
}
```

## 🔒 Sicherheit

### API-Authentifizierung
```php
// Sicheren API-Key generieren
openssl rand -hex 32
```

### Dateisicherheit
- Nur JPG/PNG Dateien erlaubt
- Maximale Dateigröße begrenzt
- EXIF-Daten werden entfernt
- Uploads in Datumsordnern organisiert

### Zugriffskontrolle
- Admin-Bereich passwortgeschützt
- Session-basierte Authentifizierung
- CORS-Header für Cross-Origin Requests

## 📊 Dateisystem

### Verzeichnisstruktur
```
uploads/
├── 2024/
│   ├── 01/
│   │   ├── 01/
│   │   │   ├── fotobox_2024-01-01_12-34-56_abc123def.jpg
│   │   │   └── thumbnails/
│   │   │       └── thumb_fotobox_2024-01-01_12-34-56_abc123def.jpg
│   │   └── 02/
│   └── 02/
└── upload_log.json
```

### Log-Format
```json
[
    {
        "id": "abc123def",
        "filename": "fotobox_2024-01-01_12-34-56_abc123def.jpg",
        "original_name": "IMG_001.jpg",
        "size": 1234567,
        "type": "image/jpeg",
        "path": "/var/www/fotobox/uploads/2024/01/01/fotobox_2024-01-01_12-34-56_abc123def.jpg",
        "url": "https://domain.com/fotobox/uploads/2024/01/01/fotobox_2024-01-01_12-34-56_abc123def.jpg",
        "thumbnail": "https://domain.com/fotobox/uploads/2024/01/01/thumbnails/thumb_fotobox_2024-01-01_12-34-56_abc123def.jpg",
        "upload_time": "2024-01-01 12:34:56",
        "metadata": {}
    }
]
```

## 🚨 Troubleshooting

### Upload-Fehler
```php
// Debug-Modus aktivieren
define('DEBUG_MODE', true);

// PHP Upload-Limits prüfen
echo 'upload_max_filesize: ' . ini_get('upload_max_filesize') . "\n";
echo 'post_max_size: ' . ini_get('post_max_size') . "\n";
echo 'max_execution_time: ' . ini_get('max_execution_time') . "\n";
```

### Berechtigungsfehler
```bash
# Upload-Verzeichnis prüfen
ls -la uploads/
# Berechtigung setzen
chmod 755 uploads/
chown www-data:www-data uploads/
```

### .htaccess für Apache
```apache
# Direkte PHP-Ausführung in uploads verhindern
<FilesMatch "\.(php|php3|php4|php5|phtml)$">
    Order Allow,Deny
    Deny from all
</FilesMatch>

# Maximale Upload-Größe
php_value upload_max_filesize 10M
php_value post_max_size 10M
php_value max_execution_time 300
```

## 🔄 Wartung

### Automatische Bereinigung
```php
// Alte Dateien automatisch löschen
define('AUTO_DELETE_DAYS', 30);
```

### Backup-Script
```bash
#!/bin/bash
# Backup der Upload-Dateien
tar -czf fotobox_backup_$(date +%Y%m%d).tar.gz uploads/
```

### Log-Rotation
```bash
# Großes Log-File aufteilen
split -l 1000 upload_log.json upload_log_part_
```

## ⚙️ Erweiterte Funktionen

### E-Mail-Benachrichtigungen
```php
define('ENABLE_EMAIL_NOTIFICATIONS', true);
define('SMTP_HOST', 'smtp.gmail.com');
define('NOTIFICATION_TO', 'admin@domain.com');
```

### Wasserzeichen
```php
define('ADD_WATERMARK', true);
define('WATERMARK_TEXT', 'fotobox © 2024');
```

### Datenbank-Integration
```php
define('USE_DATABASE', true);
define('DB_HOST', 'localhost');
define('DB_NAME', 'fotobox');
```

## 📞 Support

Bei Problemen:
1. Debug-Modus aktivieren
2. PHP Error-Log prüfen
3. Upload-Berechtigungen kontrollieren
4. API-Key und URL-Konfiguration validieren

## 📝 Changelog

### Version 1.0
- Basis Upload-Funktionalität
- Web-Galerie mit Admin-Bereich
- Thumbnail-Generierung
- API-Authentifizierung
- Automatische Verzeichnisorganisation
