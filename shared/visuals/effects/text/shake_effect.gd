@tool
extends RichTextEffect
## ShakeEffect - Effet de tremblement pour RichTextLabel
## Usage: [shake rate=20 level=5]Texte tremblant[/shake]

class_name RichTextShake

# BBCode tag
var bbcode = "shake"

# ============================================================================
# PROCESS
# ============================================================================

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# Paramètres
	var rate = char_fx.env.get("rate", 20.0)
	var level = char_fx.env.get("level", 5.0)
	
	# Calcul du décalage
	var time = char_fx.elapsed_time
	var offset = Vector2(
		sin(time * rate + char_fx.glyph_index) * level,
		cos(time * rate * 1.3 + char_fx.glyph_index) * level
	)
	
	char_fx.offset += offset
	
	return true
