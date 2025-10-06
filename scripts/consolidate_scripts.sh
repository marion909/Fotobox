#!/bin/bash

# Script-Konsolidierung: Ersetzt 13 einzelne Scripts durch 1 Management-Tool
# Dieses Script führt die Migration durch

echo "🔄 Fotobox Script-Konsolidierung"
echo "================================="
echo "Ersetzt 13 einzelne Scripts durch 1 Management-Tool"
echo ""

# Zu entfernende Scripts (werden durch manage_fotobox.sh ersetzt)
SCRIPTS_TO_REMOVE=(
    "debug_camera_not_connected.sh"
    "debug_gphoto2_file_creation.sh" 
    "diagnose_camera.sh"
    "diagnose_installation.sh"
    "fix_camera_busy.sh"
    "fix_camera_usb.sh"
    "quick_fix.sh"
    # Behalten: install_complete.sh (Hauptinstaller)
    # Behalten: setup_optimal_photobox.sh (bereits integriert)
    # Behalten: install_autostart.sh (spezielle Funktionalität)
    # Behalten: setup_printer.sh (spezielle Funktionalität)
    # Behalten: cleanup_photobox.sh (wird zu manage_fotobox.sh --cleanup)
    # Behalten: update_photobox.sh (wird zu manage_fotobox.sh --update)
)

echo "📋 Scripts die entfernt werden:"
for script in "${SCRIPTS_TO_REMOVE[@]}"; do
    if [ -f "$script" ]; then
        echo "  ✅ $script (gefunden)"
    else
        echo "  ⚠️  $script (nicht gefunden)"
    fi
done

echo ""
echo "📋 Scripts die beibehalten werden:"
echo "  ✅ install_complete.sh (Hauptinstaller)"
echo "  ✅ setup_optimal_photobox.sh (bereits integriert)"  
echo "  ✅ install_autostart.sh (spezielle Funktionalität)"
echo "  ✅ setup_printer.sh (spezielle Funktionalität)"
echo "  ✅ manage_fotobox.sh (NEUES Management-Tool)"

echo ""
echo "🎯 Neue Struktur:"
echo "  • install_complete.sh      → Komplette Installation"
echo "  • manage_fotobox.sh        → Alle Management-Aufgaben"
echo "  • setup_printer.sh         → Drucker-spezifisch"
echo "  • install_autostart.sh     → Autostart-spezifisch"

echo ""
read -p "Scripts konsolidieren? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Entferne überflüssige Scripts..."
    
    for script in "${SCRIPTS_TO_REMOVE[@]}"; do
        if [ -f "$script" ]; then
            echo "  🗑️  Entferne $script"
            rm "$script"
        fi
    done
    
    # Mache das neue Management-Script ausführbar
    chmod +x manage_fotobox.sh
    
    echo ""
    echo "✅ Konsolidierung abgeschlossen!"
    echo ""
    echo "🎉 VON 13 SCRIPTS AUF 4 REDUZIERT:"
    echo ""
    echo "📁 Neue Script-Struktur:"
    echo "  1. install_complete.sh      - Komplette Installation"
    echo "  2. manage_fotobox.sh        - Alle Diagnose, Fix, Update, Cleanup"
    echo "  3. setup_printer.sh         - Drucker-Setup"  
    echo "  4. install_autostart.sh     - Autostart-Konfiguration"
    echo ""
    echo "🚀 Management-Tool verwenden:"
    echo "  ./manage_fotobox.sh                    # Interaktives Menü"
    echo "  sudo ./manage_fotobox.sh --install     # Installation"
    echo "  ./manage_fotobox.sh --diagnose         # Kamera-Diagnose"
    echo "  sudo ./manage_fotobox.sh --fix-usb     # USB-Fix"
    echo "  sudo ./manage_fotobox.sh --update      # Update"
    echo "  ./manage_fotobox.sh --status           # Status"
    echo "  ./manage_fotobox.sh --help             # Hilfe"
    
else
    echo "❌ Abgebrochen - Scripts bleiben unverändert"
fi