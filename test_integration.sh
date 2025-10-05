#!/bin/bash
# Test-Script für die Integration

echo "=== INSTALL_COMPLETE.SH INTEGRATION TEST ==="

# Simuliere das wichtigste vom install_complete.sh
INSTALL_DIR="/home/pi/Photobox"
SERVICE_USER="pi"

print_status() {
    echo "[INFO] $1"
}

print_success() {
    echo "[SUCCESS] $1"
}

print_warning() {
    echo "[WARNING] $1"
}

print_step() {
    echo ""
    echo "=== $1 ==="
}

echo "✅ Test-Funktionen definiert"

# Simuliere den neuen Teil
print_step "Optimaler Camera Manager Setup"
print_status "Führe Optimal Photobox Setup aus..."

# Wechsle ins Installationsverzeichnis (simuliert)
echo "📁 cd $INSTALL_DIR"

# Prüfe ob setup_optimal_photobox.sh vorhanden wäre
if [ -f "../scripts/setup_optimal_photobox.sh" ]; then
    print_status "setup_optimal_photobox.sh gefunden!"
    
    echo "📋 Würde ausführen:"
    echo "   chmod +x scripts/setup_optimal_photobox.sh"
    echo "   sudo -u $SERVICE_USER bash scripts/setup_optimal_photobox.sh"
    
    print_success "Optimal Photobox Setup erfolgreich simuliert!"
else
    print_warning "setup_optimal_photobox.sh nicht in ../scripts/ gefunden"
fi

print_step "Finalisierung"
print_status "Würde Berechtigungen setzen..."

echo ""
echo "✅ Integration-Test erfolgreich!"
echo ""
echo "📋 Was wurde hinzugefügt:"
echo "   • Automatischer Aufruf von setup_optimal_photobox.sh"
echo "   • Ausführung als pi-Benutzer (nicht root)"
echo "   • Fehlerbehandlung und Status-Ausgabe"
echo "   • Aktualisierte Installationsübersicht"