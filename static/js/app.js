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

// Phase 4: Erweiteter Countdown für Foto mit Live-Preview
function startCountdown(seconds = 3) {
    return new Promise((resolve) => {
        let count = seconds;
        
        // Erstelle Full-Screen Countdown-Overlay
        const overlay = document.createElement('div');
        overlay.id = 'photo-countdown';
        overlay.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100vw;
            height: 100vh;
            background: linear-gradient(135deg, rgba(0,0,0,0.9) 0%, rgba(0,0,0,0.7) 100%);
            z-index: 9999;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            color: white;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        `;
        
        // Hauptzähler
        const countdownNumber = document.createElement('div');
        countdownNumber.style.cssText = `
            font-size: 12rem;
            font-weight: 900;
            text-shadow: 4px 4px 8px rgba(0,0,0,0.8);
            margin: 2rem;
            transition: all 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55);
        `;
        
        // Status-Text
        const statusText = document.createElement('div');
        statusText.style.cssText = `
            font-size: 3rem;
            text-align: center;
            opacity: 0.9;
            margin-bottom: 3rem;
            font-weight: 300;
        `;
        
        // Circular Progress Indicator
        const progressContainer = document.createElement('div');
        progressContainer.style.cssText = `
            position: relative;
            width: 300px;
            height: 300px;
            margin: 2rem;
        `;
        
        const progressSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        progressSvg.setAttribute('width', '300');
        progressSvg.setAttribute('height', '300');
        progressSvg.style.cssText = `
            transform: rotate(-90deg);
            position: absolute;
            top: 0;
            left: 0;
        `;
        
        const progressCircle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        progressCircle.setAttribute('cx', '150');
        progressCircle.setAttribute('cy', '150');
        progressCircle.setAttribute('r', '140');
        progressCircle.setAttribute('stroke', 'white');
        progressCircle.setAttribute('stroke-width', '8');
        progressCircle.setAttribute('fill', 'transparent');
        progressCircle.setAttribute('stroke-dasharray', '879.6'); // 2 * π * r
        progressCircle.setAttribute('stroke-dashoffset', '879.6');
        progressCircle.style.cssText = `
            transition: stroke-dashoffset 1s linear;
            filter: drop-shadow(0 0 10px rgba(255,255,255,0.5));
        `;
        
        progressSvg.appendChild(progressCircle);
        progressContainer.appendChild(progressSvg);
        
        overlay.appendChild(statusText);
        overlay.appendChild(countdownNumber);
        overlay.appendChild(progressContainer);
        document.body.appendChild(overlay);
        
        // Animationen und Countdown-Logic
        const interval = setInterval(() => {
            if (count > 0) {
                // Update Zahlen
                countdownNumber.textContent = count;
                
                // Update Progress Ring
                const progress = (seconds - count) / seconds;
                const offset = 879.6 * (1 - progress);
                progressCircle.style.strokeDashoffset = offset;
                
                // Farbschema je nach Countdown
                if (count === 3) {
                    countdownNumber.style.color = '#4CAF50';
                    progressCircle.setAttribute('stroke', '#4CAF50');
                    statusText.innerHTML = '📸 Bereit machen für das Foto!';
                    overlay.style.background = 'linear-gradient(135deg, rgba(76,175,80,0.3) 0%, rgba(0,0,0,0.8) 100%)';
                } else if (count === 2) {
                    countdownNumber.style.color = '#FF9800';
                    progressCircle.setAttribute('stroke', '#FF9800');
                    statusText.innerHTML = '😊 Lächeln nicht vergessen!';
                    overlay.style.background = 'linear-gradient(135deg, rgba(255,152,0,0.3) 0%, rgba(0,0,0,0.8) 100%)';
                } else if (count === 1) {
                    countdownNumber.style.color = '#F44336';
                    progressCircle.setAttribute('stroke', '#F44336');
                    statusText.innerHTML = '� Gleich geht\'s los!';
                    overlay.style.background = 'linear-gradient(135deg, rgba(244,67,54,0.3) 0%, rgba(0,0,0,0.8) 100%)';
                }
                
                // Scale-Animation
                countdownNumber.style.transform = 'scale(1.2)';
                setTimeout(() => {
                    countdownNumber.style.transform = 'scale(1)';
                }, 200);
                
                count--;
            } else {
                // Blitz-Effekt
                countdownNumber.textContent = '📸';
                countdownNumber.style.color = '#FFF';
                countdownNumber.style.fontSize = '15rem';
                countdownNumber.style.transform = 'scale(1.3)';
                statusText.innerHTML = '✨ KLICK! ✨';
                
                // Vollbild-Blitz
                overlay.style.background = 'white';
                
                clearInterval(interval);
                setTimeout(() => {
                    overlay.remove();
                    resolve();
                }, 800);
            }
        }, 1000);
        
        // Abbrechen mit ESC
        const escHandler = (e) => {
            if (e.key === 'Escape') {
                clearInterval(interval);
                overlay.remove();
                document.removeEventListener('keydown', escHandler);
                resolve();
            }
        };
        document.addEventListener('keydown', escHandler);
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