/**
 * Phase 4: Erweiterte Features - Countdown Integration
 */

// Globale Countdown-Konfiguration
let countdownConfig = {
    enabled: true,
    duration: 3
};

// Lade Countdown-Konfiguration vom Server
async function loadCountdownConfig() {
    try {
        const response = await fetch('/api/countdown');
        const data = await response.json();
        
        if (data.success) {
            countdownConfig = data.countdown;
            console.log('Countdown-Config geladen:', countdownConfig);
        }
    } catch (error) {
        console.error('Fehler beim Laden der Countdown-Config:', error);
    }
}

// Erweiterte Foto-Aufnahme mit konfigurierbarem Countdown
async function takePhotoWithCountdown() {
    // Lade aktuelle Konfiguration
    await loadCountdownConfig();
    
    if (countdownConfig.enabled && countdownConfig.duration > 0) {
        // Mit Countdown
        await startAdvancedCountdown(countdownConfig.duration);
    } else {
        // Direkt ohne Countdown
        console.log('Countdown deaktiviert - direkter Auslöser');
    }
    
    // Foto aufnehmen
    return takePhotoNow();
}

// Erweiterer Countdown mit Konfiguration
function startAdvancedCountdown(seconds = 3) {
    return new Promise((resolve) => {
        let count = seconds;
        
        // Erstelle Countdown-Overlay mit responsivem Design
        const overlay = document.createElement('div');
        overlay.id = 'advanced-countdown';
        overlay.className = 'countdown-overlay';
        
        // CSS für responsive Design
        const style = document.createElement('style');
        style.textContent = `
            .countdown-overlay {
                position: fixed;
                top: 0;
                left: 0;
                width: 100vw;
                height: 100vh;
                background: linear-gradient(135deg, rgba(0,0,0,0.95) 0%, rgba(0,0,0,0.8) 100%);
                z-index: 10000;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                color: white;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            }
            
            .countdown-number {
                font-size: min(20vw, 15rem);
                font-weight: 900;
                text-shadow: 0 0 30px rgba(255,255,255,0.5);
                margin: 2rem;
                transition: all 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55);
                line-height: 1;
            }
            
            .countdown-text {
                font-size: min(6vw, 3rem);
                text-align: center;
                opacity: 0.9;
                margin: 1rem 2rem;
                font-weight: 300;
                letter-spacing: 2px;
            }
            
            .countdown-progress {
                position: relative;
                width: min(80vw, 300px);
                height: min(80vw, 300px);
                margin: 2rem;
            }
            
            .progress-ring {
                transform: rotate(-90deg);
                width: 100%;
                height: 100%;
            }
            
            .progress-circle {
                transition: stroke-dashoffset 1s linear;
                filter: drop-shadow(0 0 15px currentColor);
            }
            
            @keyframes pulse {
                0%, 100% { transform: scale(1); }
                50% { transform: scale(1.05); }
            }
            
            @keyframes flash {
                0% { background: rgba(0,0,0,0.95); }
                50% { background: rgba(255,255,255,0.9); }
                100% { background: rgba(0,0,0,0.95); }
            }
            
            @media (max-width: 768px) {
                .countdown-number {
                    font-size: 25vw;
                }
                .countdown-text {
                    font-size: 8vw;
                }
            }
        `;
        
        document.head.appendChild(style);
        
        // HTML Structure
        overlay.innerHTML = `
            <div class="countdown-text" id="countdown-status">📸 Bereit für das perfekte Foto!</div>
            <div class="countdown-number" id="countdown-number">${count}</div>
            <div class="countdown-progress">
                <svg class="progress-ring" viewBox="0 0 200 200">
                    <circle cx="100" cy="100" r="90" 
                            fill="transparent" 
                            stroke="currentColor" 
                            stroke-width="8" 
                            stroke-dasharray="565.48" 
                            stroke-dashoffset="565.48"
                            class="progress-circle"
                            id="progress-circle"/>
                </svg>
            </div>
        `;
        
        document.body.appendChild(overlay);
        
        const numberEl = document.getElementById('countdown-number');
        const statusEl = document.getElementById('countdown-status');
        const progressEl = document.getElementById('progress-circle');
        
        // Countdown-Messages
        const messages = [
            { count: 5, text: '📸 Bereit für das perfekte Foto!', color: '#4CAF50' },
            { count: 4, text: '📷 Position einnehmen!', color: '#8BC34A' },
            { count: 3, text: '😊 Lächeln nicht vergessen!', color: '#FF9800' },
            { count: 2, text: '✨ Gleich geht\'s los!', color: '#FF5722' },
            { count: 1, text: '📸 Bereit... und...', color: '#F44336' },
            { count: 0, text: '🎉 KLICK! Perfekt!', color: '#FFFFFF' }
        ];
        
        // Countdown-Logic
        const interval = setInterval(() => {
            const currentMessage = messages.find(m => m.count === count) || messages[0];
            
            if (count > 0) {
                // Update UI
                numberEl.textContent = count;
                statusEl.textContent = currentMessage.text;
                numberEl.style.color = currentMessage.color;
                progressEl.style.color = currentMessage.color;
                
                // Progress Ring Animation
                const progress = (seconds - count + 1) / (seconds + 1);
                const offset = 565.48 * (1 - progress);
                progressEl.style.strokeDashoffset = offset;
                
                // Pulse Animation
                numberEl.style.animation = 'pulse 0.6s ease-in-out';
                setTimeout(() => {
                    numberEl.style.animation = '';
                }, 600);
                
                count--;
            } else {
                // Final Flash
                numberEl.textContent = '📸';
                statusEl.textContent = '🎉 KLICK! Perfekt!';
                numberEl.style.color = '#FFFFFF';
                numberEl.style.fontSize = 'min(25vw, 18rem)';
                
                overlay.style.animation = 'flash 0.5s ease-in-out';
                
                clearInterval(interval);
                setTimeout(() => {
                    overlay.remove();
                    style.remove();
                    resolve();
                }, 800);
            }
        }, 1000);
        
        // ESC zum Abbrechen
        const escHandler = (e) => {
            if (e.key === 'Escape') {
                clearInterval(interval);
                overlay.remove();
                style.remove();
                document.removeEventListener('keydown', escHandler);
                resolve();
            }
        };
        document.addEventListener('keydown', escHandler);
    });
}

// Event-Handler für erweiterte Foto-Aufnahme
function setupAdvancedPhotoCapture() {
    const photoButton = document.getElementById('takePhotoBtn');
    
    if (photoButton) {
        // Entferne alte Event-Listener
        photoButton.replaceWith(photoButton.cloneNode(true));
        const newPhotoButton = document.getElementById('takePhotoBtn');
        
        newPhotoButton.addEventListener('click', async function() {
            if (this.disabled) return;
            
            try {
                await takePhotoWithCountdown();
            } catch (error) {
                console.error('Fehler bei erweiterter Foto-Aufnahme:', error);
                showNotification('❌ Fehler bei der Foto-Aufnahme', 'error');
            }
        });
    }
}

// Countdown-Einstellungen speichern
async function saveCountdownSettings(enabled, duration) {
    try {
        const response = await fetch('/api/countdown', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                enabled: enabled,
                duration: duration
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            countdownConfig = data.countdown;
            showNotification('✅ Countdown-Einstellungen gespeichert', 'success');
            return true;
        } else {
            showNotification('❌ Fehler: ' + data.error, 'error');
            return false;
        }
    } catch (error) {
        console.error('Fehler beim Speichern der Countdown-Einstellungen:', error);
        showNotification('❌ Verbindungsfehler', 'error');
        return false;
    }
}

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', function() {
    loadCountdownConfig();
    
    // Setup enhanced photo capture if on main page
    if (document.getElementById('takePhotoBtn')) {
        setupAdvancedPhotoCapture();
    }
});