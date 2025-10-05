/**
 * Photobox JavaScript - Touch-optimierte Funktionen
 * Phase 1: Grundfunktionen für Kamerasteuerung und UI
 */

// Globale Variablen
let isLoading = false;
let currentNotification = null;

// DOM Ready
document.addEventListener('DOMContentLoaded', function() {
    console.log('📱 Photobox App gestartet');
    
    // Touch-optimierte Event-Listener
    setupTouchEvents();
    
    // Auto-refresh für Kamerastatus (alle 30 Sekunden)
    setInterval(checkCameraStatus, 30000);
    
    // Keyboard shortcuts (für Entwicklung)
    setupKeyboardShortcuts();
});

// Touch Events Setup
function setupTouchEvents() {
    // Verhindere Zoom durch Doppeltipp
    let lastTouchEnd = 0;
    document.addEventListener('touchend', function(event) {
        const now = (new Date()).getTime();
        if (now - lastTouchEnd <= 300) {
            event.preventDefault();
        }
        lastTouchEnd = now;
    }, false);
    
    // Swipe-Gesten für Navigation
    let touchStartX = 0;
    let touchStartY = 0;
    
    document.addEventListener('touchstart', function(e) {
        touchStartX = e.changedTouches[0].screenX;
        touchStartY = e.changedTouches[0].screenY;
    }, false);
    
    document.addEventListener('touchend', function(e) {
        const touchEndX = e.changedTouches[0].screenX;
        const touchEndY = e.changedTouches[0].screenY;
        
        const deltaX = touchEndX - touchStartX;
        const deltaY = touchEndY - touchStartY;
        
        // Mindestdistanz für Swipe
        if (Math.abs(deltaX) > 50 && Math.abs(deltaX) > Math.abs(deltaY)) {
            if (deltaX > 0) {
                // Swipe rechts
                handleSwipeRight();
            } else {
                // Swipe links
                handleSwipeLeft();
            }
        }
    }, false);
}

// Swipe-Navigation
function handleSwipeLeft() {
    const currentPath = window.location.pathname;
    if (currentPath === '/') {
        window.location.href = '/gallery';
    } else if (currentPath === '/gallery') {
        window.location.href = '/admin';
    }
}

function handleSwipeRight() {
    const currentPath = window.location.pathname;
    if (currentPath === '/gallery') {
        window.location.href = '/';
    } else if (currentPath === '/admin') {
        window.location.href = '/gallery';
    }
}

// Keyboard Shortcuts (für Entwicklung)
function setupKeyboardShortcuts() {
    document.addEventListener('keydown', function(e) {
        // Leertaste = Foto aufnehmen
        if (e.code === 'Space' && !e.repeat) {
            e.preventDefault();
            const photoBtn = document.getElementById('takePhotoBtn');
            if (photoBtn && !photoBtn.disabled) {
                photoBtn.click();
            }
        }
        
        // G = Galerie
        if (e.key === 'g' || e.key === 'G') {
            window.location.href = '/gallery';
        }
        
        // A = Admin
        if (e.key === 'a' || e.key === 'A') {
            window.location.href = '/admin';
        }
        
        // H = Home
        if (e.key === 'h' || e.key === 'H') {
            window.location.href = '/';
        }
        
        // ESC = Modal schließen
        if (e.key === 'Escape') {
            closePhotoModal();
        }
    });
}

// Loading Overlay
function showLoading() {
    isLoading = true;
    const overlay = document.getElementById('loading');
    if (overlay) {
        overlay.style.display = 'flex';
    }
}

function hideLoading() {
    isLoading = false;
    const overlay = document.getElementById('loading');
    if (overlay) {
        overlay.style.display = 'none';
    }
}

// Notification System
function showNotification(message, type = 'info', duration = 4000) {
    // Entferne vorherige Notification
    if (currentNotification) {
        currentNotification.remove();
    }
    
    // Erstelle neue Notification
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    // Füge zum DOM hinzu
    document.body.appendChild(notification);
    currentNotification = notification;
    
    // Auto-remove nach Zeitablauf
    setTimeout(() => {
        if (notification.parentNode) {
            notification.style.animation = 'slideOut 0.3s ease-in forwards';
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.remove();
                }
                if (currentNotification === notification) {
                    currentNotification = null;
                }
            }, 300);
        }
    }, duration);
    
    // Click to dismiss
    notification.addEventListener('click', function() {
        if (notification.parentNode) {
            notification.remove();
        }
        if (currentNotification === notification) {
            currentNotification = null;
        }
    });
}

// Kamera Status prüfen
function checkCameraStatus() {
    fetch('/api/camera_status')
        .then(response => response.json())
        .then(data => {
            updateCameraStatusUI(data.connected);
        })
        .catch(error => {
            console.error('Fehler beim Kamera-Status Check:', error);
        });
}

// Kamera Status UI Update
function updateCameraStatusUI(connected) {
    const statusElements = document.querySelectorAll('.status-online, .status-offline');
    const photoButton = document.getElementById('takePhotoBtn');
    
    statusElements.forEach(element => {
        if (connected) {
            element.className = 'status-online';
            element.textContent = '🟢 Kamera bereit';
        } else {
            element.className = 'status-offline';
            element.textContent = '🔴 Kamera nicht verbunden';
        }
    });
    
    if (photoButton) {
        photoButton.disabled = !connected;
    }
}

// Countdown für Foto (Phase 2 Vorbereitung)
function startCountdown(seconds = 3) {
    return new Promise((resolve) => {
        let count = seconds;
        
        const countdownElement = document.createElement('div');
        countdownElement.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 8rem;
            font-weight: bold;
            color: white;
            z-index: 5000;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.7);
        `;
        document.body.appendChild(countdownElement);
        
        const interval = setInterval(() => {
            if (count > 0) {
                countdownElement.textContent = count;
                count--;
            } else {
                countdownElement.textContent = '📸';
                clearInterval(interval);
                setTimeout(() => {
                    countdownElement.remove();
                    resolve();
                }, 500);
            }
        }, 1000);
    });
}

// Foto-Upload (Phase 2 Vorbereitung)
function uploadPhoto(filename) {
    // Placeholder für Server-Upload
    console.log('Upload Foto:', filename);
    showNotification('📤 Upload-Funktion wird in Phase 2 implementiert', 'info');
}

// Drucken (Phase 2 Vorbereitung)
function printPhoto(filename) {
    // Placeholder für Drucken
    console.log('Drucke Foto:', filename);
    showNotification('🖨️ Druck-Funktion wird in Phase 2 implementiert', 'info');
}

// Local Storage Funktionen
function saveToLocalStorage(key, data) {
    try {
        localStorage.setItem(key, JSON.stringify(data));
    } catch (error) {
        console.error('Fehler beim Speichern in LocalStorage:', error);
    }
}

function loadFromLocalStorage(key, defaultValue = null) {
    try {
        const data = localStorage.getItem(key);
        return data ? JSON.parse(data) : defaultValue;
    } catch (error) {
        console.error('Fehler beim Laden aus LocalStorage:', error);
        return defaultValue;
    }
}

// App-Einstellungen
function saveAppSettings(settings) {
    saveToLocalStorage('photobox_settings', settings);
}

function loadAppSettings() {
    return loadFromLocalStorage('photobox_settings', {
        autoUpload: false,
        autoPrint: false,
        countdown: 3,
        theme: 'default'
    });
}

// Foto-Metadaten
function savePhotoMetadata(filename, metadata) {
    const allMetadata = loadFromLocalStorage('photo_metadata', {});
    allMetadata[filename] = {
        ...metadata,
        timestamp: new Date().toISOString()
    };
    saveToLocalStorage('photo_metadata', allMetadata);
}

function getPhotoMetadata(filename) {
    const allMetadata = loadFromLocalStorage('photo_metadata', {});
    return allMetadata[filename] || null;
}

// Vibration (falls auf Touch-Device verfügbar)
function vibrate(pattern = [100]) {
    if ('vibrate' in navigator) {
        navigator.vibrate(pattern);
    }
}

// Vollbild-Modus (für Kiosk-Mode Phase 3)
function enterFullscreen() {
    if (document.documentElement.requestFullscreen) {
        document.documentElement.requestFullscreen();
    } else if (document.documentElement.webkitRequestFullscreen) {
        document.documentElement.webkitRequestFullscreen();
    } else if (document.documentElement.msRequestFullscreen) {
        document.documentElement.msRequestFullscreen();
    }
}

function exitFullscreen() {
    if (document.exitFullscreen) {
        document.exitFullscreen();
    } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen();
    } else if (document.msExitFullscreen) {
        document.msExitFullscreen();
    }
}

// Service Worker Registration (für PWA-Features Phase 3)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', function() {
        navigator.serviceWorker.register('/static/js/sw.js')
            .then(function(registration) {
                console.log('🔧 Service Worker registriert:', registration.scope);
            })
            .catch(function(error) {
                console.log('❌ Service Worker Registrierung fehlgeschlagen:', error);
            });
    });
}

// Error Handler
window.addEventListener('error', function(e) {
    console.error('JavaScript Fehler:', e.error);
    showNotification('⚠️ Ein unerwarteter Fehler ist aufgetreten', 'error');
});

// Unhandled Promise Rejections
window.addEventListener('unhandledrejection', function(e) {
    console.error('Unhandled Promise Rejection:', e.reason);
    showNotification('⚠️ Netzwerk- oder Verbindungsfehler', 'error');
});

// CSS Animation für slideOut
const style = document.createElement('style');
style.textContent = `
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);

// Export für Modularität (falls benötigt)
window.PhotoboxApp = {
    showLoading,
    hideLoading,
    showNotification,
    checkCameraStatus,
    startCountdown,
    uploadPhoto,
    printPhoto,
    vibrate,
    enterFullscreen,
    exitFullscreen
};