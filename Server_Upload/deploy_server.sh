#!/bin/bash

# Photobox Server Upload - Deployment Script
# Automatisiert das Setup des Server-Upload-Systems auf einem Web-Server

set -e

# Konfiguration
DOMAIN="upload.neuhauser.cloud"
WEBROOT="/var/www/html"
INSTALL_DIR="$WEBROOT/photobox"
API_KEY="GKU52R0RP4EwMnmJg00d52wgW5iEzSV3J3Hv4WBMA0dL8aS0vS"
ADMIN_PASSWORD="photobox2025!"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              📤 PHOTOBOX SERVER UPLOAD SETUP                 ║"
    echo "║                  Deployment auf Web-Server                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo ""
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Root-Check
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Bitte als root ausführen: sudo $0"
        exit 1
    fi
}

# System-Check
check_system() {
    print_step "System-Überprüfung"
    
    # PHP prüfen
    if ! command -v php &> /dev/null; then
        print_error "PHP nicht installiert!"
        print_status "Installiere PHP..."
        apt update
        apt install -y php php-gd php-json php-mbstring php-curl
    else
        PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2)
        print_success "PHP verfügbar: $PHP_VERSION"
    fi
    
    # Apache/Nginx prüfen
    if systemctl is-active --quiet apache2; then
        print_success "Apache2 läuft"
        WEB_SERVER="apache2"
    elif systemctl is-active --quiet nginx; then
        print_success "Nginx läuft"
        WEB_SERVER="nginx"
    else
        print_warning "Kein Web-Server erkannt"
        print_status "Installiere Apache2..."
        apt install -y apache2
        systemctl enable apache2
        systemctl start apache2
        WEB_SERVER="apache2"
    fi
}

# Installation der PHP-Dateien
install_php_files() {
    print_step "Installation der Upload-Dateien"
    
    # Verzeichnis erstellen
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/uploads"
    
    # PHP-Dateien erstellen
    create_upload_php
    create_config_php
    create_gallery_php
    create_htaccess
    
    # Berechtigungen setzen
    chown -R www-data:www-data "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    chmod 777 "$INSTALL_DIR/uploads"
    
    print_success "PHP-Dateien installiert in $INSTALL_DIR"
}

create_upload_php() {
    cat > "$INSTALL_DIR/upload.php" << 'EOF'
<?php
/**
 * Photobox Server Upload Handler
 * Empfängt und verarbeitet Foto-Uploads von der Photobox-App
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Preflight OPTIONS Request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Nur POST-Requests erlauben
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed', 'code' => 405]);
    exit;
}

// Konfiguration laden
require_once 'config.php';

// Authentifizierung prüfen
$headers = getallheaders();
$auth_header = $headers['Authorization'] ?? '';

if (!empty(API_KEY)) {
    if (!preg_match('/Bearer\s+(.+)/i', $auth_header, $matches) || $matches[1] !== API_KEY) {
        http_response_code(401);
        echo json_encode(['error' => 'Unauthorized', 'code' => 401]);
        exit;
    }
}

// Upload-Verzeichnis prüfen
if (!is_dir(UPLOAD_DIR)) {
    if (!mkdir(UPLOAD_DIR, 0755, true)) {
        http_response_code(500);
        echo json_encode(['error' => 'Cannot create upload directory', 'code' => 500]);
        exit;
    }
}

try {
    // Datei-Upload verarbeiten
    if (!isset($_FILES['photo'])) {
        throw new Exception('No photo file provided');
    }
    
    $file = $_FILES['photo'];
    
    // Upload-Fehler prüfen
    if ($file['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('Upload error: ' . $file['error']);
    }
    
    // Dateigröße prüfen
    if ($file['size'] > MAX_FILE_SIZE) {
        throw new Exception('File too large. Max size: ' . (MAX_FILE_SIZE / 1024 / 1024) . 'MB');
    }
    
    // Dateiformat prüfen
    $allowed_types = ['image/jpeg', 'image/jpg', 'image/png'];
    $file_type = mime_content_type($file['tmp_name']);
    
    if (!in_array($file_type, $allowed_types)) {
        throw new Exception('Invalid file type. Allowed: JPEG, PNG');
    }
    
    // Eindeutigen Dateinamen generieren
    $timestamp = date('Y-m-d_H-i-s');
    $random = substr(md5(uniqid()), 0, 8);
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = "photobox_{$timestamp}_{$random}.{$extension}";
    
    // Zielverzeichnis erstellen (Jahr/Monat/Tag)
    $date_dir = date('Y/m/d');
    $target_dir = UPLOAD_DIR . '/' . $date_dir;
    
    if (!is_dir($target_dir)) {
        if (!mkdir($target_dir, 0755, true)) {
            throw new Exception('Cannot create target directory');
        }
    }
    
    // Datei verschieben
    $target_path = $target_dir . '/' . $filename;
    if (!move_uploaded_file($file['tmp_name'], $target_path)) {
        throw new Exception('Failed to move uploaded file');
    }
    
    // Thumbnail erstellen
    $thumbnail_path = null;
    if (CREATE_THUMBNAILS) {
        $thumbnail_path = createThumbnail($target_path, $target_dir);
    }
    
    // Upload-Informationen protokollieren
    $upload_data = [
        'id' => $random,
        'filename' => $filename,
        'original_name' => $file['name'],
        'size' => $file['size'],
        'type' => $file_type,
        'path' => $target_path,
        'url' => BASE_URL . '/uploads/' . $date_dir . '/' . $filename,
        'thumbnail' => $thumbnail_path ? BASE_URL . '/uploads/' . $date_dir . '/thumbnails/thumb_' . $filename : null,
        'upload_time' => date('Y-m-d H:i:s'),
        'client_ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown'
    ];
    
    // Log-Eintrag erstellen
    logUpload($upload_data);
    
    // Erfolgreiche Antwort
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'File uploaded successfully',
        'data' => [
            'id' => $upload_data['id'],
            'filename' => $upload_data['filename'],
            'url' => $upload_data['url'],
            'thumbnail' => $upload_data['thumbnail'],
            'size' => $upload_data['size'],
            'upload_time' => $upload_data['upload_time']
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'code' => 400
    ]);
}

function createThumbnail($source_path, $target_dir) {
    $thumbnail_dir = $target_dir . '/thumbnails';
    if (!is_dir($thumbnail_dir)) {
        mkdir($thumbnail_dir, 0755, true);
    }
    
    $filename = basename($source_path);
    $thumbnail_path = $thumbnail_dir . '/thumb_' . $filename;
    
    list($width, $height, $type) = getimagesize($source_path);
    
    $thumb_width = THUMBNAIL_SIZE;
    $thumb_height = THUMBNAIL_SIZE;
    
    $ratio = min($thumb_width / $width, $thumb_height / $height);
    $new_width = round($width * $ratio);
    $new_height = round($height * $ratio);
    
    $source = null;
    switch ($type) {
        case IMAGETYPE_JPEG:
            $source = imagecreatefromjpeg($source_path);
            break;
        case IMAGETYPE_PNG:
            $source = imagecreatefrompng($source_path);
            break;
        default:
            return null;
    }
    
    if (!$source) return null;
    
    $thumbnail = imagecreatetruecolor($new_width, $new_height);
    
    if ($type === IMAGETYPE_PNG) {
        imagealphablending($thumbnail, false);
        imagesavealpha($thumbnail, true);
        $transparent = imagecolorallocatealpha($thumbnail, 255, 255, 255, 127);
        imagefill($thumbnail, 0, 0, $transparent);
    }
    
    imagecopyresampled($thumbnail, $source, 0, 0, 0, 0, $new_width, $new_height, $width, $height);
    
    $success = false;
    switch ($type) {
        case IMAGETYPE_JPEG:
            $success = imagejpeg($thumbnail, $thumbnail_path, 85);
            break;
        case IMAGETYPE_PNG:
            $success = imagepng($thumbnail, $thumbnail_path, 8);
            break;
    }
    
    imagedestroy($source);
    imagedestroy($thumbnail);
    
    return $success ? $thumbnail_path : null;
}

function logUpload($data) {
    $log_file = UPLOAD_DIR . '/upload_log.json';
    
    $log_data = [];
    if (file_exists($log_file)) {
        $content = file_get_contents($log_file);
        $log_data = json_decode($content, true) ?: [];
    }
    
    $log_data[] = $data;
    
    // Behalte nur die letzten 1000 Einträge
    if (count($log_data) > 1000) {
        $log_data = array_slice($log_data, -1000);
    }
    
    file_put_contents($log_file, json_encode($log_data, JSON_PRETTY_PRINT));
}
?>
EOF
}

create_config_php() {
    cat > "$INSTALL_DIR/config.php" << EOF
<?php
/**
 * Photobox Server Upload - Konfiguration
 */

// API-Key für Authentifizierung
define('API_KEY', '$API_KEY');

// Upload-Verzeichnis
define('UPLOAD_DIR', __DIR__ . '/uploads');

// Maximale Dateigröße (10MB)
define('MAX_FILE_SIZE', 10 * 1024 * 1024);

// Basis-URL
define('BASE_URL', 'https://$DOMAIN');

// Thumbnails
define('CREATE_THUMBNAILS', true);
define('THUMBNAIL_SIZE', 200);

// Galerie
define('ENABLE_GALLERY', true);
define('GALLERY_ITEMS_PER_PAGE', 20);
define('ADMIN_PASSWORD', '$ADMIN_PASSWORD');

// Automatische Löschung (30 Tage)
define('AUTO_DELETE_DAYS', 30);

// Debug-Modus
define('DEBUG_MODE', false);

// Zeitzone
date_default_timezone_set('Europe/Berlin');
?>
EOF
}

create_gallery_php() {
    cp "$INSTALL_DIR/../Server_Upload/gallery.php" "$INSTALL_DIR/gallery.php" 2>/dev/null || {
        echo "<?php echo 'Galerie wird geladen...'; ?>" > "$INSTALL_DIR/gallery.php"
    }
}

create_htaccess() {
    cat > "$INSTALL_DIR/uploads/.htaccess" << 'EOF'
# Photobox Upload Security
<FilesMatch "\.(php|php3|php4|php5|phtml)$">
    Order Allow,Deny
    Deny from all
</FilesMatch>

# Upload-Limits
php_value upload_max_filesize 10M
php_value post_max_size 10M
php_value max_execution_time 300

# MIME-Type Security
<FilesMatch "\.(jpg|jpeg|png|gif)$">
    Header set Content-Type image/jpeg
</FilesMatch>
EOF
}

# Apache/Nginx Virtual Host konfigurieren
configure_webserver() {
    print_step "Web-Server Konfiguration"
    
    if [ "$WEB_SERVER" = "apache2" ]; then
        configure_apache
    elif [ "$WEB_SERVER" = "nginx" ]; then
        configure_nginx
    fi
}

configure_apache() {
    cat > "/etc/apache2/sites-available/photobox-upload.conf" << EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $INSTALL_DIR
    
    <Directory $INSTALL_DIR>
        AllowOverride All
        Require all granted
    </Directory>
    
    # Upload-Limits
    LimitRequestBody 10485760
    
    # Security Headers
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"
    
    ErrorLog \${APACHE_LOG_DIR}/photobox-upload_error.log
    CustomLog \${APACHE_LOG_DIR}/photobox-upload_access.log combined
</VirtualHost>
EOF

    # Site aktivieren
    a2ensite photobox-upload.conf
    a2enmod headers rewrite
    systemctl reload apache2
    
    print_success "Apache Virtual Host konfiguriert"
}

configure_nginx() {
    cat > "/etc/nginx/sites-available/photobox-upload" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $INSTALL_DIR;
    index index.php gallery.php;
    
    client_max_body_size 10M;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    location ~/uploads {
        location ~ \.php$ {
            deny all;
        }
    }
    
    # Security Headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
}
EOF

    # Site aktivieren
    ln -sf /etc/nginx/sites-available/photobox-upload /etc/nginx/sites-enabled/
    systemctl reload nginx
    
    print_success "Nginx Virtual Host konfiguriert"
}

# SSL-Zertifikat mit Let's Encrypt
install_ssl() {
    print_step "SSL-Zertifikat Installation"
    
    if command -v certbot &> /dev/null; then
        print_status "Certbot bereits installiert"
    else
        print_status "Installiere Certbot..."
        apt install -y certbot
        if [ "$WEB_SERVER" = "apache2" ]; then
            apt install -y python3-certbot-apache
        else
            apt install -y python3-certbot-nginx
        fi
    fi
    
    print_status "Erstelle SSL-Zertifikat für $DOMAIN..."
    if [ "$WEB_SERVER" = "apache2" ]; then
        certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN"
    else
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN"
    fi
    
    print_success "SSL-Zertifikat installiert"
}

# Status-Check und Test
test_installation() {
    print_step "Installation testen"
    
    # API-Endpoint testen
    print_status "Teste Upload-Endpoint..."
    if curl -s "https://$DOMAIN/upload.php" | grep -q "Method not allowed"; then
        print_success "Upload-Endpoint erreichbar"
    else
        print_warning "Upload-Endpoint möglicherweise nicht verfügbar"
    fi
    
    # Galerie testen
    print_status "Teste Galerie..."
    if curl -s "https://$DOMAIN/gallery.php" | grep -q "Photobox"; then
        print_success "Galerie erreichbar"
    else
        print_warning "Galerie möglicherweise nicht verfügbar"
    fi
    
    print_success "Installation abgeschlossen!"
}

# Hauptprogramm
main() {
    print_header
    
    print_status "Starte Server Upload Setup für $DOMAIN"
    print_status "API-Key: ${API_KEY:0:20}..."
    
    check_permissions
    check_system
    install_php_files
    configure_webserver
    
    read -p "SSL-Zertifikat installieren? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_ssl
    fi
    
    test_installation
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                  🎉 SETUP ABGESCHLOSSEN                       ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📋 Konfiguration:${NC}"
    echo "   • Domain: https://$DOMAIN"
    echo "   • Upload-Endpoint: https://$DOMAIN/upload.php"
    echo "   • Galerie: https://$DOMAIN/gallery.php"
    echo "   • API-Key: $API_KEY"
    echo ""
    echo -e "${BLUE}🎮 Photobox-App Einstellungen:${NC}"
    echo "   • Upload-URL: https://$DOMAIN/upload.php"
    echo "   • API-Key: $API_KEY"
    echo "   • Upload aktivieren: ✓"
    echo ""
    echo -e "${YELLOW}📁 Wichtige Verzeichnisse:${NC}"
    echo "   • Web-Root: $INSTALL_DIR"
    echo "   • Uploads: $INSTALL_DIR/uploads"
    echo "   • Logs: $INSTALL_DIR/uploads/upload_log.json"
    echo ""
    echo -e "${GREEN}🚀 Server Upload System ist einsatzbereit!${NC}"
}

# Script ausführen
main "$@"
EOF