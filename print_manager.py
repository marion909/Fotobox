#!/usr/bin/env python3
"""
Photobox Druck-Manager - Phase 2
Verwaltet automatisches Drucken von Fotos via CUPS/lp
"""

import os
import subprocess
import json
from typing import Dict, List, Optional, Tuple
from PIL import Image
import tempfile

class PrintManager:
    """Manager für Foto-Druck"""
    
    def __init__(self, config):
        self.config = config
        self.print_config = config.printing
        
    def get_available_printers(self) -> List[Dict[str, str]]:
        """Gibt Liste aller verfügbaren Drucker zurück"""
        printers = []
        
        try:
            # Verwende lpstat um Drucker zu finden
            result = subprocess.run(['lpstat', '-p'], 
                                  capture_output=True, text=True, check=True)
            
            for line in result.stdout.strip().split('\n'):
                if line.startswith('printer '):
                    # Format: "printer PrinterName is idle..."
                    parts = line.split(' ')
                    if len(parts) >= 2:
                        name = parts[1]
                        status = ' '.join(parts[2:]) if len(parts) > 2 else 'unknown'
                        printers.append({
                            'name': name,
                            'status': status,
                            'description': self._get_printer_description(name)
                        })
                        
        except (subprocess.CalledProcessError, FileNotFoundError):
            # Fallback für Windows oder wenn CUPS nicht verfügbar
            printers = self._get_windows_printers()
        
        return printers
    
    def _get_printer_description(self, printer_name: str) -> str:
        """Holt detaillierte Drucker-Beschreibung"""
        try:
            result = subprocess.run(['lpoptions', '-p', printer_name], 
                                  capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except Exception:
            return "Drucker verfügbar"
    
    def _get_windows_printers(self) -> List[Dict[str, str]]:
        """Holt Windows-Drucker über PowerShell"""
        try:
            cmd = 'Get-Printer | Select-Object Name, PrinterStatus | ConvertTo-Json'
            result = subprocess.run(['powershell', '-Command', cmd], 
                                  capture_output=True, text=True, check=True)
            
            printers_data = json.loads(result.stdout)
            if not isinstance(printers_data, list):
                printers_data = [printers_data]
            
            return [
                {
                    'name': p['Name'],
                    'status': p['PrinterStatus'],
                    'description': f"Windows-Drucker ({p['PrinterStatus']})"
                }
                for p in printers_data
            ]
        except Exception:
            return []
    
    def print_photo(self, photo_path: str, copies: int = None) -> Dict[str, any]:
        """
        Druckt ein Foto
        
        Args:
            photo_path: Pfad zum Foto
            copies: Anzahl Kopien (optional, verwendet Konfiguration)
            
        Returns:
            Dictionary mit Ergebnis
        """
        if not os.path.exists(photo_path):
            return {
                'success': False,
                'message': f'Foto nicht gefunden: {photo_path}'
            }
        
        if not self.print_config.printer_name:
            return {
                'success': False,
                'message': 'Kein Drucker konfiguriert'
            }
        
        copies = copies or self.print_config.copies
        
        try:
            # Bereite Foto für Druck vor
            print_ready_path = self._prepare_photo_for_print(photo_path)
            
            # Drucke Foto
            if os.name == 'nt':  # Windows
                result = self._print_windows(print_ready_path, copies)
            else:  # Linux/macOS
                result = self._print_unix(print_ready_path, copies)
            
            # Aufräumen
            if print_ready_path != photo_path:
                os.remove(print_ready_path)
            
            return result
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Druck-Fehler: {str(e)}'
            }
    
    def _prepare_photo_for_print(self, photo_path: str) -> str:
        """Bereitet Foto für optimalen Druck vor"""
        try:
            with Image.open(photo_path) as img:
                # Konvertiere zu RGB falls nötig
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                # Skaliere auf Druckgröße
                target_size = self._get_print_dimensions()
                if target_size:
                    img = self._resize_for_print(img, target_size)
                
                # Anpassungen für Druckqualität
                if self.print_config.print_quality == 'photo':
                    # Verbessere für Foto-Druck
                    img = self._enhance_for_photo_print(img)
                
                # Speichere temporäre Datei
                temp_fd, temp_path = tempfile.mkstemp(suffix='.jpg', prefix='photobox_print_')
                os.close(temp_fd)
                
                img.save(temp_path, 'JPEG', quality=95, optimize=True)
                return temp_path
                
        except Exception as e:
            print(f"⚠️ Fehler bei Foto-Vorbereitung: {e}")
            return photo_path  # Verwende Original falls Vorbereitung fehlschlägt
    
    def _get_print_dimensions(self) -> Optional[Tuple[int, int]]:
        """Gibt Ziel-Dimensionen für Druckgröße zurück"""
        size_map = {
            '10x15cm': (1200, 1800),  # 4x6 inch bei 300 DPI
            '13x18cm': (1500, 2100),  # 5x7 inch bei 300 DPI  
            'A4': (2480, 3508),       # A4 bei 300 DPI
            'A6': (1240, 1748)        # A6 bei 300 DPI
        }
        
        return size_map.get(self.print_config.paper_size)
    
    def _resize_for_print(self, img: Image.Image, target_size: Tuple[int, int]) -> Image.Image:
        """Skaliert Bild für Druck unter Beibehaltung des Seitenverhältnisses"""
        # Berechne optimale Größe unter Beibehaltung des Verhältnisses
        img_ratio = img.width / img.height
        target_ratio = target_size[0] / target_size[1]
        
        if img_ratio > target_ratio:
            # Bild ist breiter, skaliere nach Höhe
            new_height = target_size[1]
            new_width = int(new_height * img_ratio)
        else:
            # Bild ist höher, skaliere nach Breite
            new_width = target_size[0]
            new_height = int(new_width / img_ratio)
        
        # Skaliere Bild
        resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Zentriere auf Zielgröße falls nötig
        if (new_width, new_height) != target_size:
            centered = Image.new('RGB', target_size, (255, 255, 255))
            offset = ((target_size[0] - new_width) // 2, 
                     (target_size[1] - new_height) // 2)
            centered.paste(resized, offset)
            return centered
        
        return resized
    
    def _enhance_for_photo_print(self, img: Image.Image) -> Image.Image:
        """Verbessert Bild für Foto-Druck"""
        from PIL import ImageEnhance
        
        # Leichte Kontrast-Verbesserung
        contrast = ImageEnhance.Contrast(img)
        img = contrast.enhance(1.1)
        
        # Leichte Schärfe-Verbesserung
        sharpness = ImageEnhance.Sharpness(img)
        img = sharpness.enhance(1.05)
        
        return img
    
    def _print_unix(self, file_path: str, copies: int) -> Dict[str, any]:
        """Druckt auf Unix-Systemen (Linux/macOS)"""
        cmd = ['lp']
        
        # Drucker-Name
        cmd.extend(['-d', self.print_config.printer_name])
        
        # Anzahl Kopien
        if copies > 1:
            cmd.extend(['-n', str(copies)])
        
        # Papierformat
        if self.print_config.paper_size:
            cmd.extend(['-o', f'media={self.print_config.paper_size}'])
        
        # Druckqualität
        quality_map = {
            'draft': 'draft',
            'normal': 'normal', 
            'high': 'high',
            'photo': 'photo'
        }
        quality = quality_map.get(self.print_config.print_quality, 'normal')
        cmd.extend(['-o', f'quality={quality}'])
        
        # Ränder
        if any([self.print_config.margin_top, self.print_config.margin_bottom,
                self.print_config.margin_left, self.print_config.margin_right]):
            margins = f"{self.print_config.margin_left},{self.print_config.margin_bottom}," \
                     f"{self.print_config.margin_right},{self.print_config.margin_top}"
            cmd.extend(['-o', f'page-margins={margins}'])
        
        # Datei
        cmd.append(file_path)
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            job_id = self._extract_job_id(result.stdout)
            
            return {
                'success': True,
                'message': f'Druckauftrag gesendet (ID: {job_id})',
                'job_id': job_id,
                'copies': copies
            }
            
        except subprocess.CalledProcessError as e:
            return {
                'success': False,
                'message': f'Druck fehlgeschlagen: {e.stderr}'
            }
    
    def _print_windows(self, file_path: str, copies: int) -> Dict[str, any]:
        """Druckt auf Windows-Systemen"""
        try:
            # PowerShell-Script für Windows-Druck
            script = f'''
            Add-Type -AssemblyName System.Drawing
            Add-Type -AssemblyName System.Windows.Forms
            
            $printer = "{self.print_config.printer_name}"
            $image = [System.Drawing.Image]::FromFile("{file_path}")
            
            $pd = New-Object System.Drawing.Printing.PrintDocument
            $pd.PrinterSettings.PrinterName = $printer
            $pd.PrinterSettings.Copies = {copies}
            
            $pd.Add_PrintPage({{
                param($sender, $e)
                $e.Graphics.DrawImage($image, $e.MarginBounds)
            }})
            
            $pd.Print()
            $image.Dispose()
            
            Write-Output "Druckauftrag gesendet"
            '''
            
            result = subprocess.run(['powershell', '-Command', script],
                                  capture_output=True, text=True, check=True)
            
            return {
                'success': True,
                'message': 'Druckauftrag gesendet (Windows)',
                'copies': copies
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Windows-Druck fehlgeschlagen: {str(e)}'
            }
    
    def _extract_job_id(self, lp_output: str) -> Optional[str]:
        """Extrahiert Job-ID aus lp-Ausgabe"""
        # Format: "request id is PrinterName-123 (1 file(s))"
        try:
            for line in lp_output.split('\n'):
                if 'request id is' in line:
                    parts = line.split(' ')
                    for i, part in enumerate(parts):
                        if part == 'is' and i + 1 < len(parts):
                            return parts[i + 1]
        except Exception:
            pass
        
        return None
    
    def get_print_queue(self) -> List[Dict[str, str]]:
        """Holt aktuelle Druckwarteschlange"""
        try:
            result = subprocess.run(['lpq', '-P', self.print_config.printer_name],
                                  capture_output=True, text=True, check=True)
            
            jobs = []
            for line in result.stdout.split('\n')[1:]:  # Überspringe Header
                if line.strip():
                    parts = line.split()
                    if len(parts) >= 4:
                        jobs.append({
                            'rank': parts[0],
                            'owner': parts[1],
                            'job_id': parts[2],
                            'files': ' '.join(parts[3:])
                        })
            
            return jobs
            
        except Exception:
            return []
    
    def cancel_print_job(self, job_id: str) -> bool:
        """Bricht Druckauftrag ab"""
        try:
            subprocess.run(['cancel', job_id], check=True)
            return True
        except Exception:
            return False
    
    def test_printer(self) -> Dict[str, any]:
        """Führt Drucker-Test durch"""
        if not self.print_config.printer_name:
            return {
                'success': False,
                'message': 'Kein Drucker konfiguriert'
            }
        
        try:
            # Erstelle Test-Seite
            test_image_path = self._create_test_page()
            
            # Drucke Test-Seite
            result = self.print_photo(test_image_path, copies=1)
            
            # Aufräumen
            os.remove(test_image_path)
            
            return result
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Test fehlgeschlagen: {str(e)}'
            }
    
    def _create_test_page(self) -> str:
        """Erstellt eine Test-Seite"""
        from PIL import ImageDraw, ImageFont
        import datetime
        
        # Erstelle Test-Bild
        size = (800, 600)
        img = Image.new('RGB', size, (255, 255, 255))
        draw = ImageDraw.Draw(img)
        
        # Titel
        try:
            font_large = ImageFont.truetype("arial.ttf", 48)
            font_small = ImageFont.truetype("arial.ttf", 24)
        except Exception:
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
        
        # Zeichne Test-Inhalt
        draw.text((50, 50), "📷 Photobox Drucker-Test", font=font_large, fill=(0, 0, 0))
        
        now = datetime.datetime.now()
        draw.text((50, 150), f"Datum: {now.strftime('%d.%m.%Y %H:%M:%S')}", 
                 font=font_small, fill=(0, 0, 0))
        draw.text((50, 200), f"Drucker: {self.print_config.printer_name}", 
                 font=font_small, fill=(0, 0, 0))
        draw.text((50, 250), f"Papierformat: {self.print_config.paper_size}", 
                 font=font_small, fill=(0, 0, 0))
        draw.text((50, 300), f"Qualität: {self.print_config.print_quality}", 
                 font=font_small, fill=(0, 0, 0))
        
        # Farb-Testbalken
        colors = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0), 
                 (255, 0, 255), (0, 255, 255)]
        
        bar_width = 100
        bar_height = 50
        start_y = 400
        
        for i, color in enumerate(colors):
            x = 50 + i * (bar_width + 10)
            draw.rectangle([x, start_y, x + bar_width, start_y + bar_height], 
                          fill=color)
        
        # Speichere temporäre Test-Datei
        temp_fd, temp_path = tempfile.mkstemp(suffix='.jpg', prefix='photobox_test_')
        os.close(temp_fd)
        
        img.save(temp_path, 'JPEG', quality=95)
        return temp_path

def test_print_manager():
    """Test-Funktion für den Print-Manager"""
    from config import get_config
    
    config = get_config()
    print_manager = PrintManager(config)
    
    # Zeige verfügbare Drucker
    printers = print_manager.get_available_printers()
    print("📄 Verfügbare Drucker:")
    for printer in printers:
        print(f"  - {printer['name']}: {printer['status']}")
    
    print("🧪 Print-Manager Test abgeschlossen")

if __name__ == "__main__":
    test_print_manager()