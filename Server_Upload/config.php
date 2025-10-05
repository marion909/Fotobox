<?php
/**
 * Photobox Server Upload - Konfiguration
 * Zentrale Konfigurationsdatei für den Upload-Server
 */

// =====================================
// SICHERHEIT & AUTHENTIFIZIERUNG
// =====================================

// API-Key für Authentifizierung (leer = keine Authentifizierung)
// Generiere einen sicheren Key: openssl rand -hex 32
define('API_KEY', 'GKU52R0RP4EwMnmJg00d52wgW5iEzSV3J3Hv4WBMA0dL8aS0vS');

// =====================================
// UPLOAD-EINSTELLUNGEN
// =====================================

// Upload-Verzeichnis (relativ zum Script oder absoluter Pfad)
define('UPLOAD_DIR', __DIR__ . '/uploads');

// Maximale Dateigröße in Bytes (default: 10MB)
define('MAX_FILE_SIZE', 10 * 1024 * 1024);

// Basis-URL für Datei-Links (ohne abschließenden Slash)
define('BASE_URL', 'https://upload.neuhauser.cloud');

// =====================================
// THUMBNAIL-EINSTELLUNGEN
// =====================================

// Thumbnails erstellen?
define('CREATE_THUMBNAILS', true);

// Thumbnail-Größe in Pixeln (quadratisch)
define('THUMBNAIL_SIZE', 200);

// =====================================
// GALERIE-EINSTELLUNGEN
// =====================================

// Öffentliche Galerie aktivieren?
define('ENABLE_GALLERY', true);

// Bilder pro Seite in der Galerie
define('GALLERY_ITEMS_PER_PAGE', 20);

// Admin-Passwort für Galerie-Verwaltung
define('ADMIN_PASSWORD', 'photobox2025secure!');

// =====================================
// E-MAIL-BENACHRICHTIGUNGEN
// =====================================

// E-Mail-Benachrichtigungen aktivieren?
define('ENABLE_EMAIL_NOTIFICATIONS', false);

// SMTP-Konfiguration
define('SMTP_HOST', 'smtp.gmail.com');
define('SMTP_PORT', 587);
define('SMTP_USERNAME', 'your-email@gmail.com');
define('SMTP_PASSWORD', 'your-app-password');
define('SMTP_ENCRYPTION', 'tls'); // 'tls' oder 'ssl'

// Benachrichtigungs-E-Mails
define('NOTIFICATION_FROM', 'photobox@your-domain.com');
define('NOTIFICATION_TO', 'admin@your-domain.com');

// =====================================
// ERWEITERTE EINSTELLUNGEN
// =====================================

// Automatische Löschung alter Dateien (Tage, 0 = deaktiviert)
define('AUTO_DELETE_DAYS', 30);

// Statistiken aktivieren?
define('ENABLE_STATISTICS', true);

// Debug-Modus (nur für Entwicklung!)
define('DEBUG_MODE', false);

// Erlaubte Dateierweiterungen
define('ALLOWED_EXTENSIONS', ['jpg', 'jpeg', 'png']);

// Erlaubte MIME-Types
define('ALLOWED_MIME_TYPES', [
    'image/jpeg',
    'image/jpg', 
    'image/png'
]);

// =====================================
// DATENBANK (optional)
// =====================================

// Datenbank verwenden? (false = JSON-Dateien)
define('USE_DATABASE', false);

// Datenbank-Konfiguration
define('DB_HOST', 'localhost');
define('DB_NAME', 'photobox');
define('DB_USER', 'photobox_user');
define('DB_PASS', 'secure_password');
define('DB_CHARSET', 'utf8mb4');

// =====================================
// WEITERE FUNKTIONEN
// =====================================

// Wasserzeichen hinzufügen?
define('ADD_WATERMARK', false);
define('WATERMARK_TEXT', 'Photobox © 2024');
define('WATERMARK_FONT_SIZE', 12);
define('WATERMARK_OPACITY', 50);

// EXIF-Daten aus Bildern entfernen? (Datenschutz)
define('STRIP_EXIF', true);

// Zeitzone
date_default_timezone_set('Europe/Berlin');

// =====================================
// HILFSFUNKTIONEN
// =====================================

/**
 * Prüft ob alle erforderlichen Verzeichnisse existieren
 */
function checkDirectories() {
    $dirs = [UPLOAD_DIR];
    
    if (CREATE_THUMBNAILS) {
        $dirs[] = UPLOAD_DIR . '/thumbnails';
    }
    
    foreach ($dirs as $dir) {
        if (!is_dir($dir)) {
            if (!mkdir($dir, 0755, true)) {
                throw new Exception("Cannot create directory: {$dir}");
            }
        }
        
        if (!is_writable($dir)) {
            throw new Exception("Directory not writable: {$dir}");
        }
    }
}

/**
 * Validiert die Konfiguration
 */
function validateConfig() {
    // Prüfe kritische Einstellungen
    if (API_KEY === 'your-secure-api-key-here-change-this-immediately') {
        trigger_error('WARNING: Standard API-Key wird verwendet! Bitte ändern Sie den API_KEY in config.php', E_USER_WARNING);
    }
    
    if (ADMIN_PASSWORD === 'admin123-change-this') {
        trigger_error('WARNING: Standard Admin-Passwort wird verwendet! Bitte ändern Sie ADMIN_PASSWORD in config.php', E_USER_WARNING);
    }
    
    if (MAX_FILE_SIZE <= 0) {
        throw new Exception('MAX_FILE_SIZE must be greater than 0');
    }
    
    if (THUMBNAIL_SIZE <= 0) {
        throw new Exception('THUMBNAIL_SIZE must be greater than 0');
    }
}

// Konfiguration beim Laden validieren
if (!defined('SKIP_CONFIG_VALIDATION')) {
    try {
        validateConfig();
        checkDirectories();
    } catch (Exception $e) {
        if (DEBUG_MODE) {
            die('Configuration Error: ' . $e->getMessage());
        }
    }
}
?>