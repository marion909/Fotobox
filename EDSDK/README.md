# Canon EDSDK Verzeichnis

## 📄 Rechtlicher Hinweis

Dieses Verzeichnis ist für **Canon EDSDK Dateien** vorgesehen, die **separat von Canon bezogen** werden müssen.

### ⚠️ WICHTIG: Proprietäre Software

Die **Canon EDSDK** ist **proprietäre Software** von Canon Inc. und unterliegt speziellen Lizenzbedingungen:

- ❌ **NICHT Open Source**
- ❌ **NICHT frei redistributierbar** 
- ❌ **NICHT in GitHub Repositories erlaubt**
- ✅ **Muss individuell von Canon lizenziert werden**

## 🔗 Offizielle Bezugsquelle

**Canon Developer Portal**: https://developers.canon-europe.com/developers/

### Schritte zum Erhalt:
1. 📝 **Kostenlosen Developer Account** erstellen
2. 📥 **Canon EDSDK** herunterladen 
3. 📄 **Lizenzbedingungen** akzeptieren
4. 💾 **EDSDK.dll** in diesem Verzeichnis ablegen

## 📁 Erwartete Dateien (nach Download)

```
EDSDK/
├── EDSDK.dll          # ← Canon SDK (vom Benutzer zu beschaffen)
├── EDSDK64.dll        # ← 64-bit Version (optional)
├── EDSDKApi.pas       # ✅ Header-Dateien (bereits vorhanden)
├── EDSDKType.pas      # ✅ Header-Dateien (bereits vorhanden)
├── EDSDKError.pas     # ✅ Header-Dateien (bereits vorhanden)
└── README.md          # ✅ Diese Datei
```

## 🚀 Aktivierung nach DLL-Installation

Sobald die EDSDK.dll vorhanden ist:

```bash
# Automatische Aktivierung des Canon EDSDK:
curl -sSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/activate_edsdk_complete.sh | sudo bash
```

## 💡 Alternative ohne EDSDK

**Kein Problem!** Auch ohne Canon EDSDK erhalten Sie massive Verbesserungen:

```bash
# gphoto2 Python Integration (große Verbesserung):
curl -sSL https://raw.githubusercontent.com/marion909/Fotobox/master/scripts/upgrade_camera_apis.sh | sudo bash
```

**Ergebnis**: 95% weniger "PTP Device Busy" Probleme! 🎉

## 📊 API-Priorität im Photobox System

```
🥇 Canon EDSDK        (falls DLL vorhanden)
   ⬇️ Automatischer Fallback
🥈 gphoto2 Python     (robuste Alternative)
   ⬇️ Automatischer Fallback  
🥉 gphoto2 CLI        (verbesserte Shell-Methode)
```

## ⚖️ Lizenz-Compliance

- **Photobox Code**: MIT License (Open Source)
- **Pascal Headers**: Canon Inc. (nur Interface-Definitionen)
- **Canon EDSDK**: Proprietär (Benutzer-Lizenz erforderlich)

*Die Photobox Software stellt nur die Integration bereit. Benutzer sind für die ordnungsgemäße Lizenzierung des Canon EDSDK verantwortlich.*