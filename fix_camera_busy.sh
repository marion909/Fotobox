#!/bin/bash

# 📸 Canon EOS Device Busy Fix Script
# Behebt "Canon EOS Full-Press failed (0x2019: PTP Device Busy)" Fehler
# Optimiert für wiederholte Foto-Aufnahmen

echo "🔧 Canon EOS Device Busy Fix Script"
echo "=================================="
echo "Behebt 'Device Busy' Fehler bei wiederholten Aufnahmen"
echo ""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging-Funktionen
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Funktionen für robuste Foto-Aufnahme
canon_reset_connection() {
    log_info "Setze Canon-Verbindung zurück..."
    
    # 1. Alle gphoto2 Prozesse beenden
    sudo pkill -f gphoto2 2>/dev/null || true
    
    # 2. USB-Reset für Canon-Geräte
    for device in $(lsusb | grep -i canon | awk '{print $6}'); do
        vendor_id=$(echo $device | cut -d: -f1)
        product_id=$(echo $device | cut -d: -f2)
        
        # USB-Device reset
        for usb_dev in /sys/bus/usb/devices/*/idVendor; do
            if [ -f "$usb_dev" ] && [ "$(cat $usb_dev)" = "$vendor_id" ]; then
                usb_path=$(dirname $usb_dev)
                if [ -f "$usb_path/idProduct" ] && [ "$(cat $usb_path/idProduct)" = "$product_id" ]; then
                    device_path=$(basename $usb_path)
                    log_info "Resette USB-Device $device_path..."
                    echo 0 | sudo tee "$usb_path/authorized" > /dev/null 2>&1 || true
                    sleep 1
                    echo 1 | sudo tee "$usb_path/authorized" > /dev/null 2>&1 || true
                fi
            fi
        done
    done
    
    # 3. Kurz warten für Stabilisierung
    sleep 2
    
    log_success "Verbindung zurückgesetzt"
}

canon_wait_ready() {
    log_info "Warte bis Kamera bereit ist..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if timeout 5 gphoto2 --auto-detect | grep -q Canon; then
            log_success "Kamera bereit (Versuch $attempt/$max_attempts)"
            return 0
        fi
        
        log_warning "Kamera noch nicht bereit (Versuch $attempt/$max_attempts)..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "Kamera nach $max_attempts Versuchen nicht bereit"
    return 1
}

canon_capture_robust() {
    local filename=${1:-"test_%Y%m%d_%H%M%S.jpg"}
    local max_attempts=3
    local attempt=1
    
    log_info "Robuste Foto-Aufnahme: $filename"
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Aufnahme-Versuch $attempt/$max_attempts..."
        
        # Vor jeder Aufnahme: Kurz warten und Status prüfen
        sleep 1
        
        if timeout 30 gphoto2 --capture-image-and-download --filename "$filename" 2>/dev/null; then
            log_success "Foto erfolgreich aufgenommen: $filename"
            return 0
        else
            log_warning "Aufnahme fehlgeschlagen (Versuch $attempt/$max_attempts)"
            
            if [ $attempt -lt $max_attempts ]; then
                log_info "Setze Kamera zurück und versuche erneut..."
                canon_reset_connection
                canon_wait_ready
                sleep 2
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Foto-Aufnahme nach $max_attempts Versuchen fehlgeschlagen"
    return 1
}

# Hauptfunktionen
test_multiple_captures() {
    local count=${1:-5}
    
    log_step "Teste $count aufeinanderfolgende Aufnahmen"
    
    local success_count=0
    local failed_count=0
    
    for i in $(seq 1 $count); do
        echo ""
        log_info "=== Foto $i/$count ==="
        
        if canon_capture_robust "test_multi_${i}_%Y%m%d_%H%M%S.jpg"; then
            success_count=$((success_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
        
        # Pause zwischen Fotos
        if [ $i -lt $count ]; then
            log_info "Pause 3 Sekunden..."
            sleep 3
        fi
    done
    
    echo ""
    log_step "Ergebnis"
    log_success "Erfolgreiche Aufnahmen: $success_count/$count"
    if [ $failed_count -gt 0 ]; then
        log_warning "Fehlgeschlagene Aufnahmen: $failed_count/$count"
    fi
}

install_permanent_fix() {
    log_step "Installiere permanente Device-Busy-Fixes"
    
    # 1. Optimierte gphoto2-Konfiguration
    if [ ! -f ~/.gphoto/settings ]; then
        mkdir -p ~/.gphoto
        cat > ~/.gphoto/settings << 'EOF'
# Canon EOS Optimierungen
gphoto2=model=Canon EOS
gphoto2=port=usb:
gphoto2=speed=1

# Device Busy Fixes
capture-timeout=30
download-timeout=30
wait-for-event=2000
EOF
        log_success "gphoto2-Konfiguration erstellt"
    fi
    
    # 2. Systemd-Service für automatisches Reset bei Device-Busy
    cat > /tmp/canon-reset.service << 'EOF'
[Unit]
Description=Canon Camera Auto-Reset on Device Busy
After=multi-user.target

[Service]
Type=oneshot
User=pi
ExecStart=/home/pi/Fotobox/fix_camera_busy.sh --auto-reset
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF
    
    sudo mv /tmp/canon-reset.service /etc/systemd/system/
    sudo systemctl daemon-reload
    log_success "Auto-Reset-Service installiert"
    
    # 3. Udev-Regel für Canon-Kamera-Optimierung
    cat > /tmp/99-canon-eos-optimization.rules << 'EOF'
# Canon EOS Optimierung - Device Busy Prevention
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ATTR{bConfigurationValue}!="1", ATTR{bConfigurationValue}="1"
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ACTION=="add", RUN+="/bin/sh -c 'echo 1 > /sys/$devpath/authorized'"

# Canon EOS Power Management
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ATTR{power/control}="on"
EOF
    
    sudo mv /tmp/99-canon-eos-optimization.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    log_success "USB-Optimierungs-Regeln installiert"
}

show_usage() {
    echo "Verwendung:"
    echo "  $0                    - Interaktiver Modus mit Tests"
    echo "  $0 --test N          - Teste N aufeinanderfolgende Aufnahmen"
    echo "  $0 --capture FILE    - Einzelne robuste Aufnahme"
    echo "  $0 --reset           - Nur Verbindung zurücksetzen"
    echo "  $0 --install-fix     - Permanente Fixes installieren"
    echo "  $0 --auto-reset      - Automatisches Reset bei Busy-Fehler"
}

# Parameter-Verarbeitung
case "${1:-interactive}" in
    --test)
        test_multiple_captures ${2:-5}
        ;;
    --capture)
        canon_capture_robust ${2:-"test_%Y%m%d_%H%M%S.jpg"}
        ;;
    --reset)
        canon_reset_connection
        canon_wait_ready
        ;;
    --install-fix)
        install_permanent_fix
        ;;
    --auto-reset)
        # Für systemd-Service
        while true; do
            if ! timeout 5 gphoto2 --auto-detect >/dev/null 2>&1; then
                canon_reset_connection
            fi
            sleep 10
        done
        ;;
    --help|-h)
        show_usage
        exit 0
        ;;
    interactive|*)
        # Interaktiver Modus
        log_step "Canon EOS Device-Busy-Diagnose"
        
        # 1. Aktuelle Situation prüfen
        log_info "1. Prüfe Kamera-Verbindung..."
        if lsusb | grep -i canon; then
            log_success "Canon-Kamera per USB erkannt"
        else
            log_error "Keine Canon-Kamera erkannt!"
            exit 1
        fi
        
        if timeout 10 gphoto2 --auto-detect | grep -q Canon; then
            log_success "Kamera von gphoto2 erkannt"
        else
            log_warning "Kamera nicht von gphoto2 erkannt - führe Reset durch"
            canon_reset_connection
            canon_wait_ready
        fi
        
        # 2. Einzelnes Test-Foto
        echo ""
        log_info "2. Teste einzelne Aufnahme..."
        canon_capture_robust "single_test_%Y%m%d_%H%M%S.jpg"
        
        # 3. Multiple Aufnahmen testen
        echo ""
        echo "Möchten Sie mehrere Aufnahmen testen? (empfohlen)"
        read -p "Anzahl Test-Fotos (Enter für 3): " test_count
        test_count=${test_count:-3}
        
        if [ "$test_count" -gt 0 ]; then
            test_multiple_captures $test_count
        fi
        
        # 4. Permanente Fixes anbieten
        echo ""
        echo "Möchten Sie permanente Fixes für Device-Busy-Probleme installieren?"
        read -p "Installieren? (j/N): " install_fix
        
        if [[ "$install_fix" =~ ^[Jj] ]]; then
            install_permanent_fix
            log_success "Permanente Fixes installiert!"
            echo ""
            echo "Empfohlene nächste Schritte:"
            echo "1. Raspberry Pi neustarten: sudo reboot"
            echo "2. Kamera neu verbinden"
            echo "3. Test wiederholen: ./fix_camera_busy.sh --test 5"
        fi
        ;;
esac

echo ""
log_info "Script beendet."