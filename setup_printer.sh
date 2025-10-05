#!/bin/bash

# Photobox Drucker-Setup Script
# Installiert und konfiguriert CUPS mit Canon-Unterstützung

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🖨️ Photobox Drucker-Setup"
echo "=========================="

# Prüfe Root-Rechte
if [ "$EUID" -ne 0 ]; then
    print_error "Dieses Script muss als root ausgeführt werden (sudo)"
    exit 1
fi

# 1. Basis CUPS Installation
print_status "Installiere CUPS..."
apt update
apt install -y \
    cups \
    cups-client \
    cups-bsd \
    cups-filters \
    cups-common \
    system-config-printer

print_success "CUPS Basis-Installation abgeschlossen"

# 2. Universelle Drucker-Treiber
print_status "Installiere universelle Drucker-Treiber..."
apt install -y \
    printer-driver-all \
    printer-driver-hpijs \
    printer-driver-gutenprint \
    printer-driver-postscript-hp \
    hplip \
    hplip-data

print_success "Universelle Treiber installiert"

# 3. Canon-spezifische Treiber (verschiedene Ansätze)
print_status "Installiere Canon-Drucker-Unterstützung..."

# Versuche offizielle Canon-Treiber
if apt-cache show printer-driver-canon >/dev/null 2>&1; then
    print_status "Installiere offiziellen Canon-Treiber..."
    apt install -y printer-driver-canon
    print_success "Canon-Treiber erfolgreich installiert"
else
    print_warning "Offizieller Canon-Treiber nicht verfügbar"
fi

# Alternative: CUPS-Filter und Gutenprint für Canon
print_status "Installiere erweiterte Canon-Unterstützung..."
apt install -y \
    cups-filters \
    cups-filters-core-drivers \
    ghostscript \
    foomatic-db \
    foomatic-db-engine \
    openprinting-ppds || true

# Canon PIXMA spezielle Unterstützung
if apt-cache show ijsgimpprint >/dev/null 2>&1; then
    apt install -y ijsgimpprint || true
fi

# 4. Benutzer-Konfiguration
SERVICE_USER=${SUDO_USER:-pi}
print_status "Konfiguriere CUPS für Benutzer '$SERVICE_USER'..."

# Benutzer zu lpadmin Gruppe hinzufügen
usermod -a -G lpadmin $SERVICE_USER
print_success "Benutzer '$SERVICE_USER' zu lpadmin Gruppe hinzugefügt"

# 5. CUPS-Konfiguration
print_status "Konfiguriere CUPS-Server..."

# CUPS für lokalen Zugriff konfigurieren
cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.backup

# Basis-Konfiguration für lokalen Zugriff
cat > /etc/cups/cupsd.conf << 'EOF'
# CUPS Konfiguration für Photobox
LogLevel warn
MaxLogSize 0
ServerName localhost
Port 631
Listen localhost:631
Listen /var/run/cups/cups.sock

# Sicherheit
Browsing On
BrowseLocalProtocols dnssd
DefaultAuthType Basic
WebInterface Yes

<Location />
  Order allow,deny
  Allow localhost
  Allow 127.0.0.1
  Allow 192.168.*.*
  Allow 10.*.*.*
</Location>

<Location /admin>
  Order allow,deny
  Allow localhost
  Allow 127.0.0.1
  Require user @lpadmin
</Location>

<Location /admin/conf>
  AuthType Default
  Require user @lpadmin
  Order allow,deny
  Allow localhost
  Allow 127.0.0.1
</Location>

<Policy default>
  JobPrivateAccess default
  JobPrivateValues default
  SubscriptionPrivateAccess default
  SubscriptionPrivateValues default
  
  <Limit Create-Job Print-Job Print-URI Validate-Job>
    Order deny,allow
    Allow localhost
    Allow 127.0.0.1
    Allow 192.168.*.*
  </Limit>
  
  <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job Cancel-My-Jobs Close-Job CUPS-Move-Job CUPS-Get-Document>
    Require user @lpadmin
    Order deny,allow
    Allow localhost
    Allow 127.0.0.1
  </Limit>
  
  <Limit CUPS-Add-Modify-Printer CUPS-Delete-Printer CUPS-Add-Modify-Class CUPS-Delete-Class CUPS-Set-Default CUPS-Get-Devices>
    AuthType Default
    Require user @lpadmin
    Order deny,allow
    Allow localhost
    Allow 127.0.0.1
  </Limit>
  
  <Limit Pause-Printer Resume-Printer Enable-Printer Disable-Printer Pause-Printer-After-Current-Job Hold-New-Jobs Release-Held-New-Jobs Deactivate-Printer Activate-Printer Restart-Printer Shutdown-Printer Startup-Printer Promote-Job Schedule-Job-After Cancel-Jobs CUPS-Accept-Jobs CUPS-Reject-Jobs>
    AuthType Default
    Require user @lpadmin
    Order deny,allow
    Allow localhost
    Allow 127.0.0.1
  </Limit>
  
  <Limit Cancel-Job CUPS-Authenticate-Job>
    Require user @lpadmin
    Order deny,allow
    Allow localhost
    Allow 127.0.0.1
  </Limit>
  
  <Limit All>
    Order deny,allow
    Allow localhost
    Allow 127.0.0.1
  </Limit>
</Policy>
EOF

# 6. CUPS-Service starten
print_status "Starte CUPS-Service..."
systemctl daemon-reload
systemctl enable cups
systemctl restart cups

# Warte bis Service läuft
sleep 3

if systemctl is-active --quiet cups; then
    print_success "CUPS-Service erfolgreich gestartet"
else
    print_error "CUPS-Service konnte nicht gestartet werden"
    exit 1
fi

# 7. Test der Installation
print_status "Teste CUPS-Installation..."

# Prüfe CUPS Web-Interface
if curl -s http://localhost:631 >/dev/null; then
    print_success "CUPS Web-Interface erreichbar unter http://localhost:631"
else
    print_warning "CUPS Web-Interface nicht erreichbar"
fi

# 8. Drucker-Erkennungstest
print_status "Suche nach verfügbaren Druckern..."
timeout 10s lpinfo -v 2>/dev/null | head -10 || print_warning "Keine Drucker gefunden"

# 9. Canon-spezifische Tests
print_status "Teste Canon-Drucker-Unterstützung..."

# Prüfe verfügbare PPD-Dateien für Canon
CANON_PPDS=$(find /usr/share/ppd /usr/share/cups/model -name "*canon*" -o -name "*Canon*" 2>/dev/null | wc -l)
if [ $CANON_PPDS -gt 0 ]; then
    print_success "Canon PPD-Dateien gefunden: $CANON_PPDS"
else
    print_warning "Keine Canon PPD-Dateien gefunden"
fi

# 10. Abschluss-Informationen
echo ""
print_success "Drucker-Setup abgeschlossen!"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Web-Interface öffnen: http://localhost:631"
echo "2. Drucker hinzufügen über 'Administration' > 'Add Printer'"
echo "3. Canon-Drucker anschließen und testen"
echo ""
echo "🔧 Kommandozeilen-Tools:"
echo "• Drucker anzeigen: lpstat -p"
echo "• Drucker hinzufügen: lpadmin -p DruckerName -E -v usb://..."
echo "• Test-Seite drucken: lp -d DruckerName /usr/share/cups/data/testprint"
echo ""
echo "📁 Wichtige Pfade:"
echo "• Konfiguration: /etc/cups/cupsd.conf"
echo "• Logs: /var/log/cups/"
echo "• PPD-Dateien: /usr/share/ppd/"
echo ""

if [ $CANON_PPDS -eq 0 ]; then
    print_warning "Falls Canon-Drucker nicht erkannt wird:"
    echo "1. Canon-Treiber von canon.de herunterladen"
    echo "2. Generic PostScript-Treiber verwenden"
    echo "3. Gutenprint-Treiber für Canon PIXMA-Serie probieren"
fi

print_success "Drucker-Setup erfolgreich abgeschlossen! 🖨️"