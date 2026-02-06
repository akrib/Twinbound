@tool
extends RichTextEffect
## WaveEffect - Effet de vague pour RichTextLabel
## Usage: [wave amp=50 freq=2]Texte ondulant[/wave]

class_name RichTextWave

# BBCode tag
var bbcode = "wave"

# ============================================================================
# PROCESS
# ============================================================================

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# Paramètres
	var amp = char_fx.env.get("amp", 50.0)
	var freq = char_fx.env.get("freq", 2.0)
	
	# Calcul de l'offset vertical
	var time = char_fx.elapsed_time
	var offset_y = sin(time * freq + char_fx.glyph_index * 0.5) * amp
	
	char_fx.offset.y += offset_y
	
	return true
