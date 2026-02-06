@tool
extends RichTextEffect
## RainbowEffect - Effet arc-en-ciel pour RichTextLabel
## Usage: [rainbow freq=0.2 sat=0.8 val=0.8]Texte coloré[/rainbow]

class_name RichTextRainbow

# BBCode tag
var bbcode = "rainbow"

# ============================================================================
# PROCESS
# ============================================================================

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# Paramètres
	var freq = char_fx.env.get("freq", 0.2)
	var sat = char_fx.env.get("sat", 0.8)
	var val = char_fx.env.get("val", 0.8)
	
	# Calcul de la couleur arc-en-ciel
	var time = char_fx.elapsed_time
	var hue = fmod(time * freq + char_fx.glyph_index * 0.1, 1.0)
	
	var color = Color.from_hsv(hue, sat, val)
	char_fx.color = color
	
	return true
