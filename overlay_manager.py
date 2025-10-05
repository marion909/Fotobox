#!/usr/bin/env python3
"""
Fotobox Overlay-Manager - Phase 2
Verwaltet Logos, Text-Overlays und Rahmen für Fotos
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
from typing import Optional, Tuple
import datetime

class OverlayManager:
    """Manager für Foto-Overlays"""
    
    def __init__(self, config):
        self.config = config
        self.overlay_config = config.overlay
        
    def apply_overlays(self, image_path: str, output_path: Optional[str] = None) -> str:
        """
        Wendet alle aktivierten Overlays auf ein Foto an
        
        Args:
            image_path: Pfad zum Original-Foto
            output_path: Pfad für das Ausgabe-Foto (optional)
            
        Returns:
            Pfad zum bearbeiteten Foto
        """
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Foto nicht gefunden: {image_path}")
        
        # Lade Originalbild
        with Image.open(image_path) as img:
            # Konvertiere zu RGBA für Transparenz-Support
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Erstelle Arbeits-Kopie
            result = img.copy()
            
            # Wende Overlays an (Reihenfolge wichtig!)
            if self.overlay_config.frame_enabled:
                result = self._apply_frame(result)
            
            if self.overlay_config.logo_path and self.overlay_config.enabled:
                result = self._apply_logo(result)
                
            if self.overlay_config.text_enabled and self.overlay_config.text_content:
                result = self._apply_text(result)
            
            # Konvertiere zurück zu RGB für JPEG-Export
            if result.mode == 'RGBA':
                # Erstelle weißen Hintergrund
                background = Image.new('RGB', result.size, (255, 255, 255))
                background.paste(result, mask=result.split()[-1])  # Alpha-Kanal als Maske
                result = background
            
            # Speichere Ergebnis
            if output_path is None:
                base, ext = os.path.splitext(image_path)
                output_path = f"{base}_overlay{ext}"
            
            # Stelle sicher, dass Ausgabe-Verzeichnis existiert
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            result.save(output_path, 'JPEG', quality=95)
            return output_path
    
    def _apply_logo(self, image: Image.Image) -> Image.Image:
        """Fügt Logo-Overlay hinzu"""
        logo_path = self.overlay_config.logo_path
        
        if not os.path.exists(logo_path):
            print(f"⚠️ Logo nicht gefunden: {logo_path}")
            return image
        
        try:
            with Image.open(logo_path) as logo:
                # Konvertiere Logo zu RGBA
                if logo.mode != 'RGBA':
                    logo = logo.convert('RGBA')
                
                # Skaliere Logo auf gewünschte Größe
                logo_size = self.overlay_config.logo_size
                logo.thumbnail((logo_size, logo_size), Image.Resampling.LANCZOS)
                
                # Anpassung der Deckkraft
                if self.overlay_config.logo_opacity < 1.0:
                    alpha = logo.split()[-1]
                    enhancer = ImageEnhance.Brightness(alpha)
                    alpha = enhancer.enhance(self.overlay_config.logo_opacity)
                    logo.putalpha(alpha)
                
                # Berechne Position
                position = self._calculate_position(
                    image.size, 
                    logo.size, 
                    self.overlay_config.logo_position
                )
                
                # Füge Logo hinzu
                if logo.mode == 'RGBA':
                    image.paste(logo, position, logo)
                else:
                    image.paste(logo, position)
                
        except Exception as e:
            print(f"❌ Fehler beim Anwenden des Logos: {e}")
        
        return image
    
    def _apply_text(self, image: Image.Image) -> Image.Image:
        """Fügt Text-Overlay hinzu"""
        try:
            # Erstelle Drawing-Context
            draw = ImageDraw.Draw(image)
            
            # Lade Schriftart
            font = self._load_font(self.overlay_config.text_font_size)
            
            text = self.overlay_config.text_content
            
            # Ersetze Platzhalter
            text = self._replace_text_placeholders(text)
            
            # Berechne Text-Größe
            bbox = draw.textbbox((0, 0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
            
            # Berechne Position
            position = self._calculate_position(
                image.size,
                (text_width, text_height),
                self.overlay_config.text_position
            )
            
            # Zeichne Schatten (falls aktiviert)
            if self.overlay_config.text_shadow:
                shadow_offset = max(2, self.overlay_config.text_font_size // 20)
                shadow_pos = (position[0] + shadow_offset, position[1] + shadow_offset)
                draw.text(shadow_pos, text, font=font, fill=(0, 0, 0, 128))
            
            # Zeichne Text
            draw.text(position, text, font=font, fill=self.overlay_config.text_color)
            
        except Exception as e:
            print(f"❌ Fehler beim Anwenden des Textes: {e}")
        
        return image
    
    def _apply_frame(self, image: Image.Image) -> Image.Image:
        """Fügt Rahmen-Overlay hinzu"""
        frame_path = self.overlay_config.frame_path
        
        if not os.path.exists(frame_path):
            print(f"⚠️ Rahmen nicht gefunden: {frame_path}")
            return image
        
        try:
            with Image.open(frame_path) as frame:
                if self.overlay_config.frame_type == "full-overlay":
                    # Rahmen über das ganze Bild
                    frame = frame.resize(image.size, Image.Resampling.LANCZOS)
                    if frame.mode == 'RGBA':
                        image.paste(frame, (0, 0), frame)
                    else:
                        image.paste(frame, (0, 0))
                else:
                    # Border-Rahmen (um das Bild herum)
                    border_width = 20
                    new_size = (
                        image.size[0] + 2 * border_width,
                        image.size[1] + 2 * border_width
                    )
                    
                    # Erstelle neues Bild mit Rahmen
                    framed = Image.new('RGB', new_size, (255, 255, 255))
                    framed.paste(image, (border_width, border_width))
                    
                    # Skaliere Rahmen-Textur
                    frame = frame.resize(new_size, Image.Resampling.LANCZOS)
                    if frame.mode == 'RGBA':
                        framed.paste(frame, (0, 0), frame)
                    else:
                        framed.paste(frame, (0, 0))
                    
                    image = framed
                    
        except Exception as e:
            print(f"❌ Fehler beim Anwenden des Rahmens: {e}")
        
        return image
    
    def _calculate_position(self, image_size: Tuple[int, int], 
                          overlay_size: Tuple[int, int], 
                          position: str) -> Tuple[int, int]:
        """Berechnet Position für Overlay"""
        img_w, img_h = image_size
        overlay_w, overlay_h = overlay_size
        
        margin = 20  # Abstand zum Bildrand
        
        positions = {
            'top-left': (margin, margin),
            'top-center': ((img_w - overlay_w) // 2, margin),
            'top-right': (img_w - overlay_w - margin, margin),
            'center-left': (margin, (img_h - overlay_h) // 2),
            'center': ((img_w - overlay_w) // 2, (img_h - overlay_h) // 2),
            'center-right': (img_w - overlay_w - margin, (img_h - overlay_h) // 2),
            'bottom-left': (margin, img_h - overlay_h - margin),
            'bottom-center': ((img_w - overlay_w) // 2, img_h - overlay_h - margin),
            'bottom-right': (img_w - overlay_w - margin, img_h - overlay_h - margin)
        }
        
        return positions.get(position, positions['bottom-right'])
    
    def _load_font(self, size: int) -> ImageFont.FreeTypeFont:
        """Lädt Schriftart"""
        font_paths = [
            # Windows
            "C:/Windows/Fonts/arial.ttf",
            "C:/Windows/Fonts/calibri.ttf",
            # Linux
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
            # macOS  
            "/System/Library/Fonts/Arial.ttf",
        ]
        
        for font_path in font_paths:
            if os.path.exists(font_path):
                try:
                    return ImageFont.truetype(font_path, size)
                except Exception:
                    continue
        
        # Fallback auf Standard-Font
        try:
            return ImageFont.load_default()
        except Exception:
            return ImageFont.load_default()
    
    def _replace_text_placeholders(self, text: str) -> str:
        """Ersetzt Platzhalter im Text"""
        now = datetime.datetime.now()
        
        replacements = {
            '{date}': now.strftime('%d.%m.%Y'),
            '{time}': now.strftime('%H:%M'),
            '{datetime}': now.strftime('%d.%m.%Y %H:%M'),
            '{year}': str(now.year),
            '{month}': str(now.month),
            '{day}': str(now.day),
            '{app_name}': self.config.app_name
        }
        
        for placeholder, value in replacements.items():
            text = text.replace(placeholder, value)
        
        return text
    
    def create_sample_overlays(self):
        """Erstellt Beispiel-Overlays für Tests"""
        overlay_dir = self.config.overlay_dir
        os.makedirs(overlay_dir, exist_ok=True)
        
        # Erstelle Beispiel-Logo
        logo_path = os.path.join(overlay_dir, "logo.png")
        if not os.path.exists(logo_path):
            self._create_sample_logo(logo_path)
        
        # Erstelle Beispiel-Rahmen
        frame_path = os.path.join(overlay_dir, "frame.png")
        if not os.path.exists(frame_path):
            self._create_sample_frame(frame_path)
        
        print(f"✅ Beispiel-Overlays erstellt in: {overlay_dir}")
    
    def _create_sample_logo(self, logo_path: str):
        """Erstellt ein Beispiel-Logo"""
        size = 200
        img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Zeichne einen einfachen Kreis mit Text
        margin = 20
        draw.ellipse([margin, margin, size-margin, size-margin], 
                    fill=(0, 123, 255, 200), outline=(255, 255, 255, 255), width=3)
        
        # Füge Text hinzu
        font = self._load_font(24)
        text = "📷"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_w = bbox[2] - bbox[0]
        text_h = bbox[3] - bbox[1]
        
        text_pos = ((size - text_w) // 2, (size - text_h) // 2)
        draw.text(text_pos, text, font=font, fill=(255, 255, 255, 255))
        
        img.save(logo_path, 'PNG')
    
    def _create_sample_frame(self, frame_path: str):
        """Erstellt einen Beispiel-Rahmen"""
        # Erstelle einen einfachen Rahmen
        size = (800, 600)
        img = Image.new('RGBA', size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Zeichne Rahmen-Border
        border_width = 30
        
        # Äußerer Rahmen (schwarz)
        draw.rectangle([0, 0, size[0]-1, size[1]-1], 
                      outline=(0, 0, 0, 255), width=border_width)
        
        # Innerer Rahmen (weiß)  
        inner_margin = border_width - 5
        draw.rectangle([inner_margin, inner_margin, 
                       size[0]-inner_margin-1, size[1]-inner_margin-1], 
                      outline=(255, 255, 255, 255), width=5)
        
        img.save(frame_path, 'PNG')

def test_overlay_manager():
    """Test-Funktion für den Overlay-Manager"""
    from config import get_config
    
    config = get_config()
    overlay_manager = OverlayManager(config)
    
    # Erstelle Beispiel-Overlays
    overlay_manager.create_sample_overlays()
    
    # Aktiviere Overlays für Test
    config.overlay.enabled = True
    config.overlay.text_enabled = True
    config.overlay.text_content = "Fotobox {date} {time}"
    config.overlay.frame_enabled = True
    
    print("🧪 Overlay-Manager Test abgeschlossen")

if __name__ == "__main__":
    test_overlay_manager()