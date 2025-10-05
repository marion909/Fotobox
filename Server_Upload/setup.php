<?php
/**
 * Photobox Server Upload - Installation & Setup Script
 * Automatisches Setup-Script für die Server-Upload-Funktionalität
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

// Setup-Status prüfen
$setup_complete = false;
$errors = [];
$warnings = [];
$success_messages = [];

// POST-Verarbeitung für Setup
if ($_POST) {
    $setup_complete = processSetup();
}

/**
 * Verarbeitet das Setup-Formular
 */
function processSetup() {
    global $errors, $warnings, $success_messages;
    
    try {
        // API-Key validieren
        $api_key = $_POST['api_key'] ?? '';
        if (empty($api_key) || strlen($api_key) < 32) {
            $errors[] = 'API-Key muss mindestens 32 Zeichen lang sein.';
            return false;
        }
        
        // Admin-Passwort validieren
        $admin_password = $_POST['admin_password'] ?? '';
        if (empty($admin_password) || strlen($admin_password) < 6) {
            $errors[] = 'Admin-Passwort muss mindestens 6 Zeichen lang sein.';
            return false;
        }
        
        // Base URL validieren
        $base_url = rtrim($_POST['base_url'] ?? '', '/');
        if (!filter_var($base_url, FILTER_VALIDATE_URL)) {
            $errors[] = 'Ungültige Base-URL.';
            return false;
        }
        
        // Konfigurationsdatei aktualisieren
        updateConfig([
            'API_KEY' => $api_key,
            'ADMIN_PASSWORD' => $admin_password,
            'BASE_URL' => $base_url,
            'MAX_FILE_SIZE' => intval($_POST['max_file_size'] ?? 10) * 1024 * 1024,
            'CREATE_THUMBNAILS' => isset($_POST['create_thumbnails']),
            'ENABLE_GALLERY' => isset($_POST['enable_gallery']),
            'AUTO_DELETE_DAYS' => intval($_POST['auto_delete_days'] ?? 0)
        ]);
        
        // Verzeichnisse erstellen
        createDirectories();
        
        // .htaccess erstellen
        createHtaccess();
        
        $success_messages[] = 'Setup erfolgreich abgeschlossen!';
        $success_messages[] = 'Konfiguration wurde gespeichert.';
        $success_messages[] = 'Upload-Verzeichnisse wurden erstellt.';
        
        return true;
        
    } catch (Exception $e) {
        $errors[] = 'Setup-Fehler: ' . $e->getMessage();
        return false;
    }
}

/**
 * Aktualisiert die Konfigurationsdatei
 */
function updateConfig($settings) {
    $config_file = 'config.php';
    $config_content = file_get_contents($config_file);
    
    foreach ($settings as $key => $value) {
        if (is_bool($value)) {
            $value = $value ? 'true' : 'false';
        } elseif (is_string($value)) {
            $value = "'" . addslashes($value) . "'";
        }
        
        $pattern = "/define\s*\(\s*['\"]" . $key . "['\"]\s*,\s*[^)]+\)/";
        $replacement = "define('{$key}', {$value})";
        $config_content = preg_replace($pattern, $replacement, $config_content);
    }
    
    file_put_contents($config_file, $config_content);
}

/**
 * Erstellt erforderliche Verzeichnisse
 */
function createDirectories() {
    $dirs = [
        'uploads',
        'uploads/thumbnails'
    ];
    
    foreach ($dirs as $dir) {
        if (!is_dir($dir)) {
            if (!mkdir($dir, 0755, true)) {
                throw new Exception("Kann Verzeichnis nicht erstellen: {$dir}");
            }
        }
        
        if (!is_writable($dir)) {
            throw new Exception("Verzeichnis nicht beschreibbar: {$dir}");
        }
    }
}

/**
 * Erstellt .htaccess für Sicherheit
 */
function createHtaccess() {
    $htaccess_content = '# Photobox Upload Security
# PHP-Ausführung im Upload-Verzeichnis verhindern
<FilesMatch "\.(php|php3|php4|php5|phtml)$">
    Order Allow,Deny
    Deny from all
</FilesMatch>

# Upload-Limits
php_value upload_max_filesize 10M
php_value post_max_size 10M
php_value max_execution_time 300
php_value memory_limit 128M

# MIME-Type Security
<FilesMatch "\.(jpg|jpeg|png|gif)$">
    ForceType image/jpeg
</FilesMatch>

# Hotlinking verhindern (optional)
# RewriteEngine On
# RewriteCond %{HTTP_REFERER} !^https?://(.+\.)?yourdomain\.com/ [NC]
# RewriteCond %{REQUEST_URI} !hotlink\.(jpg|jpeg|png|gif) [NC]
# RewriteRule .*\.(jpg|jpeg|png|gif)$ /hotlink.jpg [L]
';
    
    file_put_contents('uploads/.htaccess', $htaccess_content);
}

/**
 * Führt System-Checks durch
 */
function performSystemChecks() {
    global $errors, $warnings, $success_messages;
    
    // PHP-Version prüfen
    if (version_compare(PHP_VERSION, '7.4.0', '<')) {
        $errors[] = 'PHP 7.4 oder höher erforderlich. Aktuelle Version: ' . PHP_VERSION;
    } else {
        $success_messages[] = 'PHP-Version OK: ' . PHP_VERSION;
    }
    
    // Erforderliche Extensions prüfen
    $required_extensions = ['gd', 'json', 'fileinfo'];
    foreach ($required_extensions as $ext) {
        if (!extension_loaded($ext)) {
            $errors[] = "PHP-Extension '{$ext}' nicht verfügbar.";
        } else {
            $success_messages[] = "Extension '{$ext}' verfügbar.";
        }
    }
    
    // Verzeichnis-Berechtigungen prüfen
    if (!is_writable(__DIR__)) {
        $errors[] = 'Aktuelles Verzeichnis nicht beschreibbar.';
    } else {
        $success_messages[] = 'Verzeichnis-Berechtigungen OK.';
    }
    
    // Upload-Limits prüfen
    $upload_max = ini_get('upload_max_filesize');
    $post_max = ini_get('post_max_size');
    
    if (return_bytes($upload_max) < 10 * 1024 * 1024) {
        $warnings[] = "upload_max_filesize zu klein: {$upload_max} (empfohlen: 10M)";
    }
    
    if (return_bytes($post_max) < 10 * 1024 * 1024) {
        $warnings[] = "post_max_size zu klein: {$post_max} (empfohlen: 10M)";
    }
}

/**
 * Konvertiert PHP ini-Werte zu Bytes
 */
function return_bytes($val) {
    $val = trim($val);
    $last = strtolower($val[strlen($val)-1]);
    $val = intval($val);
    
    switch($last) {
        case 'g':
            $val *= 1024;
        case 'm':
            $val *= 1024;
        case 'k':
            $val *= 1024;
    }
    
    return $val;
}

// System-Checks durchführen
performSystemChecks();
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Photobox Server Setup</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .content {
            padding: 30px;
        }
        
        .section {
            margin-bottom: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        
        .section h2 {
            color: #333;
            margin-bottom: 15px;
            font-size: 1.3em;
        }
        
        .alert {
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 15px;
        }
        
        .alert-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .alert-warning {
            background: #fff3cd;
            color: #856404;
            border: 1px solid #ffeaa7;
        }
        
        .alert-danger {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            color: #333;
            font-weight: bold;
        }
        
        .form-group input,
        .form-group select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 16px;
        }
        
        .form-group input[type="checkbox"] {
            width: auto;
            margin-right: 10px;
        }
        
        .form-help {
            font-size: 0.9em;
            color: #666;
            margin-top: 5px;
        }
        
        .btn {
            padding: 12px 30px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
            text-decoration: none;
            display: inline-block;
            transition: all 0.3s;
        }
        
        .btn-primary {
            background: #4facfe;
            color: white;
        }
        
        .btn-primary:hover {
            background: #3a8bfd;
        }
        
        .btn-success {
            background: #28a745;
            color: white;
        }
        
        .btn-success:hover {
            background: #218838;
        }
        
        .system-check {
            display: grid;
            grid-template-columns: 1fr auto;
            gap: 15px;
            align-items: center;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 10px;
        }
        
        .check-ok {
            background: #d4edda;
            color: #155724;
        }
        
        .check-warning {
            background: #fff3cd;
            color: #856404;
        }
        
        .check-error {
            background: #f8d7da;
            color: #721c24;
        }
        
        .status-icon {
            font-size: 1.2em;
            font-weight: bold;
        }
        
        .progress {
            background: #e9ecef;
            border-radius: 10px;
            height: 20px;
            margin: 20px 0;
            overflow: hidden;
        }
        
        .progress-bar {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            height: 100%;
            transition: width 0.3s ease;
        }
        
        .complete-section {
            text-align: center;
            padding: 40px 20px;
        }
        
        .complete-section h2 {
            color: #28a745;
            margin-bottom: 20px;
            font-size: 2em;
        }
        
        .next-steps {
            background: #e8f5e8;
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
        }
        
        .next-steps ol {
            text-align: left;
            margin: 0 auto;
            display: inline-block;
        }
        
        .next-steps li {
            margin-bottom: 10px;
            color: #155724;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Photobox Server Setup</h1>
            <p>Installationsassistent für das Upload-System</p>
        </div>
        
        <div class="content">
            <?php if (!$setup_complete): ?>
                <!-- System-Checks -->
                <div class="section">
                    <h2>📋 System-Überprüfung</h2>
                    
                    <?php foreach ($success_messages as $message): ?>
                        <div class="system-check check-ok">
                            <span><?php echo htmlspecialchars($message); ?></span>
                            <span class="status-icon">✅</span>
                        </div>
                    <?php endforeach; ?>
                    
                    <?php foreach ($warnings as $warning): ?>
                        <div class="system-check check-warning">
                            <span><?php echo htmlspecialchars($warning); ?></span>
                            <span class="status-icon">⚠️</span>
                        </div>
                    <?php endforeach; ?>
                    
                    <?php foreach ($errors as $error): ?>
                        <div class="system-check check-error">
                            <span><?php echo htmlspecialchars($error); ?></span>
                            <span class="status-icon">❌</span>
                        </div>
                    <?php endforeach; ?>
                </div>
                
                <?php if (empty($errors)): ?>
                    <!-- Konfiguration -->
                    <form method="post">
                        <div class="section">
                            <h2>🔐 Sicherheits-Konfiguration</h2>
                            
                            <div class="form-group">
                                <label for="api_key">API-Key:</label>
                                <input type="text" id="api_key" name="api_key" 
                                       value="<?php echo bin2hex(random_bytes(16)); ?>" required>
                                <div class="form-help">Sicherer Schlüssel für die API-Authentifizierung (mindestens 32 Zeichen)</div>
                            </div>
                            
                            <div class="form-group">
                                <label for="admin_password">Admin-Passwort:</label>
                                <input type="password" id="admin_password" name="admin_password" required>
                                <div class="form-help">Passwort für den Admin-Bereich der Galerie (mindestens 6 Zeichen)</div>
                            </div>
                        </div>
                        
                        <div class="section">
                            <h2>🌐 Server-Konfiguration</h2>
                            
                            <div class="form-group">
                                <label for="base_url">Basis-URL:</label>
                                <input type="url" id="base_url" name="base_url" 
                                       value="<?php echo (isset($_SERVER['HTTPS']) ? 'https' : 'http') . '://' . $_SERVER['HTTP_HOST'] . dirname($_SERVER['REQUEST_URI']); ?>" required>
                                <div class="form-help">Vollständige URL zu diesem Verzeichnis (ohne abschließenden Slash)</div>
                            </div>
                            
                            <div class="form-group">
                                <label for="max_file_size">Maximale Dateigröße (MB):</label>
                                <input type="number" id="max_file_size" name="max_file_size" value="10" min="1" max="100" required>
                                <div class="form-help">Maximale Größe pro Upload-Datei</div>
                            </div>
                        </div>
                        
                        <div class="section">
                            <h2>⚙️ Funktions-Einstellungen</h2>
                            
                            <div class="form-group">
                                <label>
                                    <input type="checkbox" name="create_thumbnails" checked>
                                    Thumbnails erstellen
                                </label>
                                <div class="form-help">Automatische Erstellung von Vorschaubildern</div>
                            </div>
                            
                            <div class="form-group">
                                <label>
                                    <input type="checkbox" name="enable_gallery" checked>
                                    Web-Galerie aktivieren
                                </label>
                                <div class="form-help">Öffentliche Galerie für hochgeladene Bilder</div>
                            </div>
                            
                            <div class="form-group">
                                <label for="auto_delete_days">Automatische Löschung (Tage):</label>
                                <input type="number" id="auto_delete_days" name="auto_delete_days" value="30" min="0" max="365">
                                <div class="form-help">Automatisches Löschen alter Dateien (0 = deaktiviert)</div>
                            </div>
                        </div>
                        
                        <button type="submit" class="btn btn-primary">🚀 Installation starten</button>
                    </form>
                <?php else: ?>
                    <div class="alert alert-danger">
                        <strong>Setup nicht möglich!</strong><br>
                        Bitte beheben Sie die oben genannten Fehler, bevor Sie fortfahren können.
                    </div>
                <?php endif; ?>
                
            <?php else: ?>
                <!-- Setup erfolgreich -->
                <div class="complete-section">
                    <h2>✅ Setup erfolgreich abgeschlossen!</h2>
                    
                    <div class="next-steps">
                        <h3>🎯 Nächste Schritte:</h3>
                        <ol>
                            <li><strong>Löschen Sie diese Datei:</strong> setup.php (aus Sicherheitsgründen)</li>
                            <li><strong>Testen Sie den Upload:</strong> Verwenden Sie die Photobox-App</li>
                            <li><strong>Besuchen Sie die Galerie:</strong> <a href="gallery.php" target="_blank">gallery.php</a></li>
                            <li><strong>Konfigurieren Sie die App:</strong> Verwenden Sie die generierten Einstellungen</li>
                        </ol>
                    </div>
                    
                    <div style="margin: 30px 0; padding: 20px; background: #f8f9fa; border-radius: 10px; text-align: left;">
                        <h4>📱 Photobox-App Einstellungen:</h4>
                        <p><strong>Upload-URL:</strong> <code><?php echo $_POST['base_url']; ?>/upload.php</code></p>
                        <p><strong>API-Key:</strong> <code><?php echo htmlspecialchars($_POST['api_key']); ?></code></p>
                        <p><strong>Galerie-URL:</strong> <code><?php echo $_POST['base_url']; ?>/gallery.php</code></p>
                    </div>
                    
                    <a href="gallery.php" class="btn btn-success">🖼️ Galerie öffnen</a>
                </div>
            <?php endif; ?>
        </div>
    </div>
    
    <script>
        // API-Key Generator
        document.addEventListener('DOMContentLoaded', function() {
            const generateBtn = document.createElement('button');
            generateBtn.type = 'button';
            generateBtn.className = 'btn';
            generateBtn.style.marginLeft = '10px';
            generateBtn.textContent = '🔄 Neu generieren';
            generateBtn.onclick = function() {
                // Einfacher Client-seitiger Generator
                const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
                let key = '';
                for (let i = 0; i < 32; i++) {
                    key += chars.charAt(Math.floor(Math.random() * chars.length));
                }
                document.getElementById('api_key').value = key;
            };
            
            const apiKeyField = document.getElementById('api_key');
            if (apiKeyField) {
                apiKeyField.parentNode.appendChild(generateBtn);
            }
        });
    </script>
</body>
</html>