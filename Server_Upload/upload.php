<?php
/**
 * Fotobox Server Upload Handler - Ultra Compatible Version
 * Funktioniert mit minimalsten PHP-Installationen
 */

// Error Reporting für Production
error_reporting(0);
ini_set('display_errors', '0');

header('Content-Type: application/json; charset=utf-8');
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

// Einfache Konfiguration
$config = [
    'API_KEY' => 'GKU52R0RP4EwMnmJg00d52wgW5iEzSV3J3Hv4WBMA0dL8aS0vS',
    'UPLOAD_DIR' => __DIR__ . '/uploads',
    'MAX_FILE_SIZE' => 10 * 1024 * 1024, // 10MB
    'BASE_URL' => 'https://upload.neuhauser.cloud',
    'CREATE_THUMBNAILS' => true,
    'THUMBNAIL_SIZE' => 200,
    'AUTO_DELETE_DAYS' => 30
];

// Authentifizierung prüfen
function checkAuth($config) {
    $headers = [];
    if (function_exists('getallheaders')) {
        $headers = getallheaders();
    } else {
        // Fallback für Server ohne getallheaders()
        foreach ($_SERVER as $key => $value) {
            if (strpos($key, 'HTTP_') === 0) {
                $header = str_replace('_', '-', substr($key, 5));
                $headers[$header] = $value;
            }
        }
    }
    
    $auth_header = $headers['Authorization'] ?? $headers['AUTHORIZATION'] ?? '';
    
    if (!empty($config['API_KEY'])) {
        if (!preg_match('/Bearer\s+(.+)/i', $auth_header, $matches) || $matches[1] !== $config['API_KEY']) {
            http_response_code(401);
            echo json_encode(['error' => 'Unauthorized', 'code' => 401]);
            exit;
        }
    }
}

// MIME-Type ermitteln (ultra-robust)
function getMimeTypeRobust($filepath, $original_name = '', $upload_type = '') {
    // 1. Priorität: Upload MIME-Type wenn vertrauenswürdig
    if (!empty($upload_type) && $upload_type !== 'application/octet-stream') {
        $allowed_upload_types = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
        if (in_array($upload_type, $allowed_upload_types)) {
            return $upload_type;
        }
    }
    
    // 2. Priorität: fileinfo extension
    if (function_exists('finfo_open') && extension_loaded('fileinfo')) {
        $finfo = @finfo_open(FILEINFO_MIME_TYPE);
        if ($finfo) {
            $mime = @finfo_file($finfo, $filepath);
            @finfo_close($finfo);
            if ($mime && $mime !== 'application/octet-stream') {
                return $mime;
            }
        }
    }
    
    // 3. Priorität: mime_content_type
    if (function_exists('mime_content_type')) {
        $mime = @mime_content_type($filepath);
        if ($mime && $mime !== 'application/octet-stream') {
            return $mime;
        }
    }
    
    // 4. Priorität: getimagesize (sehr zuverlässig für Bilder)
    if (function_exists('getimagesize')) {
        $image_info = @getimagesize($filepath);
        if ($image_info && isset($image_info['mime'])) {
            return $image_info['mime'];
        }
    }
    
    // 5. Fallback: Dateiendung (aus Upload oder Dateipfad)
    $extension = '';
    if (!empty($original_name)) {
        $extension = strtolower(pathinfo($original_name, PATHINFO_EXTENSION));
    }
    if (empty($extension)) {
        $extension = strtolower(pathinfo($filepath, PATHINFO_EXTENSION));
    }
    
    switch ($extension) {
        case 'jpg':
        case 'jpeg':
            return 'image/jpeg';
        case 'png':
            return 'image/png';
        case 'gif':
            return 'image/gif';
        default:
            return 'application/octet-stream';
    }
}

// Validiere Bilddatei
function validateImageFile($filepath, $detected_mime) {
    // Prüfe ob es wirklich ein Bild ist
    if (function_exists('getimagesize')) {
        $image_info = @getimagesize($filepath);
        if (!$image_info) {
            return false; // Nicht lesbar als Bild
        }
        
        // Prüfe MIME-Type match
        $valid_types = [
            'image/jpeg' => [IMAGETYPE_JPEG],
            'image/jpg' => [IMAGETYPE_JPEG], 
            'image/png' => [IMAGETYPE_PNG],
            'image/gif' => [IMAGETYPE_GIF]
        ];
        
        if (isset($valid_types[$detected_mime])) {
            return in_array($image_info[2], $valid_types[$detected_mime]);
        }
    }
    
    // Fallback: erlaubt wenn MIME-Type stimmt
    $allowed_types = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];
    return in_array($detected_mime, $allowed_types);
}

// Thumbnail erstellen
function createThumbnailSafe($source_path, $target_dir, $filename, $thumb_size) {
    if (!extension_loaded('gd')) {
        return null;
    }
    
    $thumbnail_dir = $target_dir . '/thumbnails';
    if (!is_dir($thumbnail_dir)) {
        if (!@mkdir($thumbnail_dir, 0755, true)) {
            return null;
        }
    }
    
    $thumbnail_path = $thumbnail_dir . '/thumb_' . $filename;
    
    $image_info = @getimagesize($source_path);
    if (!$image_info) return null;
    
    list($width, $height, $type) = $image_info;
    
    // Berechne neue Größe
    $ratio = min($thumb_size / $width, $thumb_size / $height);
    $new_width = round($width * $ratio);
    $new_height = round($height * $ratio);
    
    // Erstelle Quellbild
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
    
    if (!$source) return null;
    
    // Erstelle Thumbnail
    $thumbnail = @imagecreatetruecolor($new_width, $new_height);
    if (!$thumbnail) {
        imagedestroy($source);
        return null;
    }
    
    // Für PNG: Transparenz beibehalten
    if ($type === IMAGETYPE_PNG) {
        @imagealphablending($thumbnail, false);
        @imagesavealpha($thumbnail, true);
        $transparent = @imagecolorallocatealpha($thumbnail, 255, 255, 255, 127);
        if ($transparent !== false) {
            @imagefill($thumbnail, 0, 0, $transparent);
        }
    }
    
    // Resample
    $success = @imagecopyresampled($thumbnail, $source, 0, 0, 0, 0, 
                                   $new_width, $new_height, $width, $height);
    
    if ($success) {
        // Speichern
        switch ($type) {
            case IMAGETYPE_JPEG:
                $success = @imagejpeg($thumbnail, $thumbnail_path, 85);
                break;
            case IMAGETYPE_PNG:
                $success = @imagepng($thumbnail, $thumbnail_path, 8);
                break;
        }
    }
    
    @imagedestroy($source);
    @imagedestroy($thumbnail);
    
    return $success ? $thumbnail_path : null;
}

// Log-Funktion
function logUploadSafe($data, $upload_dir) {
    $log_file = $upload_dir . '/upload_log.json';
    
    $log_data = [];
    if (file_exists($log_file)) {
        $content = @file_get_contents($log_file);
        if ($content) {
            $log_data = @json_decode($content, true) ?: [];
        }
    }
    
    $log_data[] = $data;
    
    // Behalte nur die letzten 500 Einträge
    if (count($log_data) > 500) {
        $log_data = array_slice($log_data, -500);
    }
    
    $json_content = json_encode($log_data, JSON_PRETTY_PRINT);
    @file_put_contents($log_file, $json_content, LOCK_EX);
}

// Hauptlogik
try {
    // Auth prüfen
    checkAuth($config);
    
    // Upload-Verzeichnis prüfen
    if (!is_dir($config['UPLOAD_DIR'])) {
        if (!@mkdir($config['UPLOAD_DIR'], 0755, true)) {
            throw new Exception('Cannot create upload directory');
        }
    }
    
    // Datei-Upload prüfen
    if (!isset($_FILES['photo'])) {
        throw new Exception('No photo file provided');
    }
    
    $file = $_FILES['photo'];
    
    // Upload-Fehler prüfen
    if ($file['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('Upload error code: ' . $file['error']);
    }
    
    // Dateigröße prüfen
    if ($file['size'] > $config['MAX_FILE_SIZE']) {
        $max_mb = round($config['MAX_FILE_SIZE'] / 1024 / 1024, 1);
        throw new Exception("File too large. Max size: {$max_mb}MB");
    }
    
    // MIME-Type mit robuster Erkennung
    $file_type = getMimeTypeRobust($file['tmp_name'], $file['name'], $file['type']);
    
    // Validiere als Bilddatei
    if (!validateImageFile($file['tmp_name'], $file_type)) {
        throw new Exception('Invalid file type: ' . $file_type . '. Must be valid image (JPEG, PNG, GIF)');
    }
    
    // Eindeutigen Dateinamen generieren
    $timestamp = date('Y-m-d_H-i-s');
    $random = substr(md5(uniqid(mt_rand(), true)), 0, 8);
    $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    
    if (empty($extension) || !in_array($extension, ['jpg', 'jpeg', 'png', 'gif'])) {
        $extension = ($file_type === 'image/png') ? 'png' : 'jpg';
    }
    
    $filename = "fotobox_{$timestamp}_{$random}.{$extension}";
    
    // Zielverzeichnis (nach Datum organisiert)
    $date_dir = date('Y/m/d');
    $target_dir = $config['UPLOAD_DIR'] . '/' . $date_dir;
    
    if (!is_dir($target_dir)) {
        if (!@mkdir($target_dir, 0755, true)) {
            throw new Exception('Cannot create target directory');
        }
    }
    
    // Datei verschieben
    $target_path = $target_dir . '/' . $filename;
    if (!@move_uploaded_file($file['tmp_name'], $target_path)) {
        throw new Exception('Failed to move uploaded file');
    }
    
    // Thumbnail erstellen
    $thumbnail_path = null;
    $thumbnail_url = null;
    
    if ($config['CREATE_THUMBNAILS']) {
        $thumbnail_path = createThumbnailSafe($target_path, $target_dir, $filename, $config['THUMBNAIL_SIZE']);
        if ($thumbnail_path) {
            $thumbnail_url = $config['BASE_URL'] . '/uploads/' . $date_dir . '/thumbnails/thumb_' . $filename;
        }
    }
    
    // Upload-Daten zusammenstellen
    $upload_data = [
        'id' => $random,
        'filename' => $filename,
        'original_name' => $file['name'],
        'size' => $file['size'],
        'type' => $file_type,
        'path' => $target_path,
        'url' => $config['BASE_URL'] . '/uploads/' . $date_dir . '/' . $filename,
        'thumbnail' => $thumbnail_url,
        'upload_time' => date('Y-m-d H:i:s'),
        'client_ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
        'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown',
        'debug_info' => [
            'original_mime' => $file['type'],
            'detected_mime' => $file_type,
            'file_size' => $file['size'],
            'php_version' => PHP_VERSION
        ]
    ];
    
    // Metadaten verarbeiten (falls vorhanden)
    if (isset($_POST['metadata'])) {
        $metadata = @json_decode($_POST['metadata'], true);
        if ($metadata) {
            $upload_data['metadata'] = $metadata;
        }
    }
    
    // Log erstellen
    logUploadSafe($upload_data, $config['UPLOAD_DIR']);
    
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
            'upload_time' => $upload_data['upload_time'],
            'debug' => $upload_data['debug_info']
        ]
    ], JSON_UNESCAPED_SLASHES);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'code' => 400,
        'debug' => [
            'php_version' => PHP_VERSION,
            'extensions' => [
                'gd' => extension_loaded('gd'),
                'fileinfo' => extension_loaded('fileinfo')
            ],
            'functions' => [
                'getimagesize' => function_exists('getimagesize'),
                'finfo_open' => function_exists('finfo_open'),
                'mime_content_type' => function_exists('mime_content_type')
            ]
        ]
    ], JSON_UNESCAPED_SLASHES);
}

// Optional: Alte Dateien bereinigen
if ($config['AUTO_DELETE_DAYS'] > 0 && rand(1, 50) === 1) {
    $cutoff_time = time() - ($config['AUTO_DELETE_DAYS'] * 24 * 60 * 60);
    
    if (is_dir($config['UPLOAD_DIR'])) {
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($config['UPLOAD_DIR'], RecursiveDirectoryIterator::SKIP_DOTS),
            RecursiveIteratorIterator::CHILD_FIRST
        );
        
        foreach ($iterator as $file) {
            if ($file->isFile() && $file->getMTime() < $cutoff_time) {
                @unlink($file->getPathname());
            }
        }
    }
}
?>