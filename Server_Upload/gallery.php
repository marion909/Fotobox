<?php
/**
 * Photobox Galerie - Einfache Web-Galerie für hochgeladene Fotos
 */

require_once 'config.php';

// Session starten für Admin-Funktionen
session_start();

// Admin-Login verarbeiten
if (isset($_POST['admin_login'])) {
    if ($_POST['password'] === ADMIN_PASSWORD) {
        $_SESSION['admin_logged_in'] = true;
    } else {
        $error_message = 'Falsches Passwort!';
    }
}

// Admin-Logout
if (isset($_GET['logout'])) {
    unset($_SESSION['admin_logged_in']);
    header('Location: gallery.php');
    exit;
}

// Admin-Aktionen verarbeiten
if (isset($_SESSION['admin_logged_in']) && isset($_POST['action'])) {
    switch ($_POST['action']) {
        case 'delete_photo':
            if (isset($_POST['photo_id'])) {
                deletePhoto($_POST['photo_id']);
                $success_message = 'Foto gelöscht!';
            }
            break;
        case 'clear_all':
            if (isset($_POST['confirm']) && $_POST['confirm'] === 'yes') {
                clearAllPhotos();
                $success_message = 'Alle Fotos gelöscht!';
            }
            break;
    }
}

// Fotos laden
$photos = loadPhotos();
$total_photos = count($photos);

// Paginierung
$page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
$per_page = GALLERY_ITEMS_PER_PAGE;
$total_pages = ceil($total_photos / $per_page);
$offset = ($page - 1) * $per_page;
$photos_page = array_slice($photos, $offset, $per_page);

/**
 * Lädt alle Fotos aus dem Log
 */
function loadPhotos() {
    if (!ENABLE_GALLERY) {
        return [];
    }
    
    $log_file = UPLOAD_DIR . '/upload_log.json';
    if (!file_exists($log_file)) {
        return [];
    }
    
    $content = file_get_contents($log_file);
    $photos = json_decode($content, true) ?: [];
    
    // Nach Upload-Zeit sortieren (neueste zuerst)
    usort($photos, function($a, $b) {
        return strtotime($b['upload_time']) - strtotime($a['upload_time']);
    });
    
    return $photos;
}

/**
 * Löscht ein einzelnes Foto
 */
function deletePhoto($photo_id) {
    $log_file = UPLOAD_DIR . '/upload_log.json';
    if (!file_exists($log_file)) {
        return false;
    }
    
    $content = file_get_contents($log_file);
    $photos = json_decode($content, true) ?: [];
    
    foreach ($photos as $key => $photo) {
        if ($photo['id'] === $photo_id) {
            // Datei löschen
            if (file_exists($photo['path'])) {
                unlink($photo['path']);
            }
            
            // Thumbnail löschen
            if (isset($photo['thumbnail']) && file_exists($photo['thumbnail'])) {
                $thumbnail_path = str_replace(BASE_URL, UPLOAD_DIR, $photo['thumbnail']);
                if (file_exists($thumbnail_path)) {
                    unlink($thumbnail_path);
                }
            }
            
            // Aus Array entfernen
            unset($photos[$key]);
            break;
        }
    }
    
    // Log aktualisieren
    file_put_contents($log_file, json_encode(array_values($photos), JSON_PRETTY_PRINT));
    return true;
}

/**
 * Löscht alle Fotos
 */
function clearAllPhotos() {
    // Upload-Verzeichnis leeren
    $files = glob(UPLOAD_DIR . '/*');
    foreach ($files as $file) {
        if (is_file($file)) {
            unlink($file);
        }
    }
    
    // Unterverzeichnisse rekursiv löschen
    $dirs = glob(UPLOAD_DIR . '/*', GLOB_ONLYDIR);
    foreach ($dirs as $dir) {
        deleteDirectory($dir);
    }
    
    // Log-Datei leeren
    $log_file = UPLOAD_DIR . '/upload_log.json';
    file_put_contents($log_file, '[]');
}

/**
 * Löscht ein Verzeichnis rekursiv
 */
function deleteDirectory($dir) {
    if (!is_dir($dir)) {
        return false;
    }
    
    $files = array_diff(scandir($dir), ['.', '..']);
    foreach ($files as $file) {
        $path = $dir . '/' . $file;
        if (is_dir($path)) {
            deleteDirectory($path);
        } else {
            unlink($path);
        }
    }
    
    return rmdir($dir);
}
?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Photobox Galerie</title>
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
            max-width: 1200px;
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
            position: relative;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .stats {
            display: flex;
            justify-content: center;
            gap: 30px;
            margin-top: 20px;
        }
        
        .stat-item {
            text-align: center;
        }
        
        .stat-number {
            font-size: 2em;
            font-weight: bold;
        }
        
        .admin-toggle {
            position: absolute;
            top: 20px;
            right: 20px;
            background: rgba(255,255,255,0.2);
            border: none;
            color: white;
            padding: 10px 15px;
            border-radius: 5px;
            cursor: pointer;
            transition: background 0.3s;
        }
        
        .admin-toggle:hover {
            background: rgba(255,255,255,0.3);
        }
        
        .content {
            padding: 30px;
        }
        
        .gallery {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .photo-card {
            background: white;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            overflow: hidden;
            transition: transform 0.3s, box-shadow 0.3s;
        }
        
        .photo-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        
        .photo-card img {
            width: 100%;
            height: 200px;
            object-fit: cover;
        }
        
        .photo-info {
            padding: 15px;
        }
        
        .photo-filename {
            font-weight: bold;
            color: #333;
            margin-bottom: 5px;
        }
        
        .photo-date {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 10px;
        }
        
        .photo-size {
            color: #888;
            font-size: 0.8em;
        }
        
        .pagination {
            display: flex;
            justify-content: center;
            gap: 10px;
            margin-top: 30px;
        }
        
        .pagination a {
            padding: 10px 15px;
            background: #f8f9fa;
            color: #333;
            text-decoration: none;
            border-radius: 5px;
            transition: all 0.3s;
        }
        
        .pagination a:hover,
        .pagination a.active {
            background: #4facfe;
            color: white;
        }
        
        .admin-panel {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        
        .admin-actions {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            transition: all 0.3s;
            font-size: 14px;
        }
        
        .btn-danger {
            background: #dc3545;
            color: white;
        }
        
        .btn-danger:hover {
            background: #c82333;
        }
        
        .btn-warning {
            background: #ffc107;
            color: #212529;
        }
        
        .btn-warning:hover {
            background: #e0a800;
        }
        
        .login-form {
            max-width: 400px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            color: #333;
        }
        
        .form-group input {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 16px;
        }
        
        .alert {
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        
        .alert-danger {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .alert-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .empty-gallery {
            text-align: center;
            color: #666;
            padding: 60px 20px;
        }
        
        .empty-gallery i {
            font-size: 4em;
            margin-bottom: 20px;
            color: #ddd;
        }
        
        @media (max-width: 768px) {
            .header {
                padding: 20px;
            }
            
            .header h1 {
                font-size: 2em;
            }
            
            .stats {
                flex-direction: column;
                gap: 15px;
            }
            
            .gallery {
                grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
                gap: 15px;
            }
            
            .admin-actions {
                justify-content: center;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📸 Photobox Galerie</h1>
            
            <?php if (isset($_SESSION['admin_logged_in'])): ?>
                <a href="?logout=1" class="admin-toggle">Admin Logout</a>
            <?php else: ?>
                <button class="admin-toggle" onclick="toggleLogin()">Admin Login</button>
            <?php endif; ?>
            
            <div class="stats">
                <div class="stat-item">
                    <div class="stat-number"><?php echo $total_photos; ?></div>
                    <div>Fotos gesamt</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number"><?php echo $total_pages; ?></div>
                    <div>Seiten</div>
                </div>
                <div class="stat-item">
                    <div class="stat-number"><?php echo count($photos_page); ?></div>
                    <div>Diese Seite</div>
                </div>
            </div>
        </div>
        
        <div class="content">
            <?php if (isset($error_message)): ?>
                <div class="alert alert-danger"><?php echo htmlspecialchars($error_message); ?></div>
            <?php endif; ?>
            
            <?php if (isset($success_message)): ?>
                <div class="alert alert-success"><?php echo htmlspecialchars($success_message); ?></div>
            <?php endif; ?>
            
            <!-- Admin Login Form -->
            <div id="loginForm" style="display: none;">
                <div class="login-form">
                    <h3>Admin Login</h3>
                    <form method="post">
                        <div class="form-group">
                            <label for="password">Passwort:</label>
                            <input type="password" id="password" name="password" required>
                        </div>
                        <button type="submit" name="admin_login" class="btn btn-warning">Login</button>
                        <button type="button" onclick="toggleLogin()" class="btn" style="background: #6c757d; color: white; margin-left: 10px;">Abbrechen</button>
                    </form>
                </div>
            </div>
            
            <!-- Admin Panel -->
            <?php if (isset($_SESSION['admin_logged_in'])): ?>
                <div class="admin-panel">
                    <h3>🛠️ Admin-Bereich</h3>
                    <div class="admin-actions">
                        <form method="post" onsubmit="return confirm('Wirklich ALLE Fotos löschen? Diese Aktion kann nicht rückgängig gemacht werden!');">
                            <input type="hidden" name="action" value="clear_all">
                            <input type="hidden" name="confirm" value="yes">
                            <button type="submit" class="btn btn-danger">🗑️ Alle Fotos löschen</button>
                        </form>
                    </div>
                </div>
            <?php endif; ?>
            
            <!-- Galerie -->
            <?php if (!ENABLE_GALLERY): ?>
                <div class="empty-gallery">
                    <div style="font-size: 4em; margin-bottom: 20px;">🔒</div>
                    <h3>Galerie deaktiviert</h3>
                    <p>Die Galerie-Funktion ist in der Konfiguration deaktiviert.</p>
                </div>
            <?php elseif (empty($photos_page)): ?>
                <div class="empty-gallery">
                    <div style="font-size: 4em; margin-bottom: 20px;">📷</div>
                    <h3>Noch keine Fotos</h3>
                    <p>Es wurden noch keine Fotos hochgeladen.</p>
                </div>
            <?php else: ?>
                <div class="gallery">
                    <?php foreach ($photos_page as $photo): ?>
                        <div class="photo-card">
                            <?php if (isset($photo['thumbnail'])): ?>
                                <img src="<?php echo htmlspecialchars($photo['thumbnail']); ?>" 
                                     alt="<?php echo htmlspecialchars($photo['filename']); ?>"
                                     onclick="openPhoto('<?php echo htmlspecialchars($photo['url']); ?>')">
                            <?php else: ?>
                                <img src="<?php echo htmlspecialchars($photo['url']); ?>" 
                                     alt="<?php echo htmlspecialchars($photo['filename']); ?>"
                                     onclick="openPhoto('<?php echo htmlspecialchars($photo['url']); ?>')">
                            <?php endif; ?>
                            
                            <div class="photo-info">
                                <div class="photo-filename"><?php echo htmlspecialchars($photo['filename']); ?></div>
                                <div class="photo-date"><?php echo date('d.m.Y H:i', strtotime($photo['upload_time'])); ?></div>
                                <div class="photo-size"><?php echo round($photo['size'] / 1024, 1); ?> KB</div>
                                
                                <?php if (isset($_SESSION['admin_logged_in'])): ?>
                                    <form method="post" style="margin-top: 10px;" onsubmit="return confirm('Foto wirklich löschen?');">
                                        <input type="hidden" name="action" value="delete_photo">
                                        <input type="hidden" name="photo_id" value="<?php echo htmlspecialchars($photo['id']); ?>">
                                        <button type="submit" class="btn btn-danger" style="font-size: 12px; padding: 5px 10px;">Löschen</button>
                                    </form>
                                <?php endif; ?>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
                
                <!-- Paginierung -->
                <?php if ($total_pages > 1): ?>
                    <div class="pagination">
                        <?php if ($page > 1): ?>
                            <a href="?page=<?php echo $page - 1; ?>">← Zurück</a>
                        <?php endif; ?>
                        
                        <?php for ($i = max(1, $page - 2); $i <= min($total_pages, $page + 2); $i++): ?>
                            <a href="?page=<?php echo $i; ?>" <?php echo $i === $page ? 'class="active"' : ''; ?>>
                                <?php echo $i; ?>
                            </a>
                        <?php endfor; ?>
                        
                        <?php if ($page < $total_pages): ?>
                            <a href="?page=<?php echo $page + 1; ?>">Weiter →</a>
                        <?php endif; ?>
                    </div>
                <?php endif; ?>
            <?php endif; ?>
        </div>
    </div>
    
    <script>
        function toggleLogin() {
            const form = document.getElementById('loginForm');
            form.style.display = form.style.display === 'none' ? 'block' : 'none';
        }
        
        function openPhoto(url) {
            window.open(url, '_blank');
        }
    </script>
</body>
</html>