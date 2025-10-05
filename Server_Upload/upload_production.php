<?php
/**
 * Photobox Server Upload Handler - Production Version
 * Empfängt und verarbeitet Foto-Uploads von der Photobox-App
 */

// Error Reporting für Production konfigurieren
error_reporting(E_ERROR | E_PARSE);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

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

// Konfiguration laden (ohne Warnings)
define('SKIP_CONFIG_VALIDATION', true);
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
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $file_type = finfo_file($finfo, $file['tmp_name']);
    finfo_close($finfo);
    
    if (!in_array($file_type, $allowed_types)) {
        throw new Exception('Invalid file type. Allowed: JPEG, PNG');
    }
    
    // Metadaten verarbeiten
    $metadata = [];
    if (isset($_POST['metadata'])) {
        $metadata = json_decode($_POST['metadata'], true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $metadata = [];
        }
    }
    
    // Eindeutigen Dateinamen generieren
    $timestamp = date('Y-m-d_H-i-s');
    $random = substr(md5(uniqid(mt_rand(), true)), 0, 8);
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    if (empty($extension)) {
        $extension = ($file_type === 'image/png') ? 'png' : 'jpg';
    }
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
    $thumbnail_url = null;
    if (CREATE_THUMBNAILS && extension_loaded('gd')) {
        $thumbnail_path = createThumbnail($target_path, $target_dir, $filename);
        if ($thumbnail_path) {
            $thumbnail_url = BASE_URL . '/uploads/' . $date_dir . '/thumbnails/thumb_' . $filename;
        }
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
        'thumbnail' => $thumbnail_url,
        'upload_time' => date('Y-m-d H:i:s'),
        'client_ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
        'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
        'metadata' => $metadata
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

/**
 * Erstellt ein Thumbnail für das hochgeladene Bild
 */
function createThumbnail($source_path, $target_dir, $filename) {
    if (!extension_loaded('gd')) {
        return null;
    }
    
    $thumbnail_dir = $target_dir . '/thumbnails';
    if (!is_dir($thumbnail_dir)) {
        if (!mkdir($thumbnail_dir, 0755, true)) {
            return null;
        }
    }
    
    $thumbnail_path = $thumbnail_dir . '/thumb_' . $filename;
    
    // Bildgröße ermitteln
    $image_info = getimagesize($source_path);
    if (!$image_info) {
        return null;
    }
    
    list($width, $height, $type) = $image_info;
    
    // Thumbnail-Größe berechnen
    $thumb_size = THUMBNAIL_SIZE;
    $ratio = min($thumb_size / $width, $thumb_size / $height);
    $new_width = round($width * $ratio);
    $new_height = round($height * $ratio);
    
    // Bild-Resource erstellen
    $source = null;
    switch ($type) {
        case IMAGETYPE_JPEG:
            $source = @imagecreatefromjpeg($source_path);
            break;
        case IMAGETYPE_PNG:
            $source = @imagecreatefrompng($source_path);
            break;
        default:
            return null;
    }
    
    if (!$source) {
        return null;
    }
    
    // Thumbnail erstellen
    $thumbnail = imagecreatetruecolor($new_width, $new_height);
    if (!$thumbnail) {
        imagedestroy($source);
        return null;
    }
    
    // Transparenz für PNG beibehalten
    if ($type === IMAGETYPE_PNG) {
        imagealphablending($thumbnail, false);
        imagesavealpha($thumbnail, true);
        $transparent = imagecolorallocatealpha($thumbnail, 255, 255, 255, 127);
        if ($transparent !== false) {
            imagefill($thumbnail, 0, 0, $transparent);
        }
    }
    
    // Resampling
    $success = imagecopyresampled($thumbnail, $source, 0, 0, 0, 0, 
                                  $new_width, $new_height, $width, $height);
    
    if (!$success) {
        imagedestroy($source);
        imagedestroy($thumbnail);
        return null;
    }
    
    // Thumbnail speichern
    $saved = false;
    switch ($type) {
        case IMAGETYPE_JPEG:
            $saved = @imagejpeg($thumbnail, $thumbnail_path, 85);
            break;
        case IMAGETYPE_PNG:
            $saved = @imagepng($thumbnail, $thumbnail_path, 8);
            break;
    }
    
    // Ressourcen freigeben
    imagedestroy($source);
    imagedestroy($thumbnail);
    
    return $saved ? $thumbnail_path : null;
}

/**
 * Protokolliert den Upload
 */
function logUpload($data) {
    $log_file = UPLOAD_DIR . '/upload_log.json';
    
    // Existierendes Log laden
    $log_data = [];
    if (file_exists($log_file)) {
        $content = @file_get_contents($log_file);
        if ($content) {
            $log_data = json_decode($content, true) ?: [];
        }
    }
    
    // Neuen Eintrag hinzufügen
    $log_data[] = $data;
    
    // Behalte nur die letzten 1000 Einträge für Performance
    if (count($log_data) > 1000) {
        $log_data = array_slice($log_data, -1000);
    }
    
    // Log speichern
    $json_content = json_encode($log_data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    @file_put_contents($log_file, $json_content, LOCK_EX);
}

/**
 * Cleanup-Funktion für alte Dateien (optional via Cron aufrufen)
 */
function cleanupOldFiles() {
    if (AUTO_DELETE_DAYS <= 0) {
        return;
    }
    
    $cutoff_time = time() - (AUTO_DELETE_DAYS * 24 * 60 * 60);
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator(UPLOAD_DIR, RecursiveDirectoryIterator::SKIP_DOTS)
    );
    
    foreach ($iterator as $file) {
        if ($file->isFile() && $file->getMTime() < $cutoff_time) {
            @unlink($file->getPathname());
        }
    }
}

// Optional: Cleanup bei jedem 100. Upload (rudimentäre Wartung)
if (AUTO_DELETE_DAYS > 0 && rand(1, 100) === 1) {
    cleanupOldFiles();
}
?>