extends Control

@onready var label = self


func _ready():
	var text := "=== DEBUG VERSION INFO ===\n\n"
	text += load_build_info()
	text += "\n"
	text += load_doc_status()

	label.text = text


func load_build_info() -> String:
	var path = "res://documentation/build_info.json"
	if not FileAccess.file_exists(path):
		return "Build info: NOT AVAILABLE\n"

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Build info: FAILED TO OPEN\n"

	var content = file.get_as_text()
	var data = JSON.parse_string(content)

	if typeof(data) != TYPE_DICTIONARY:
		return "Build info: INVALID JSON\n"

	var text := "=== BUILD INFO ===\n"
	text += "Game Version : %s\n" % data.get("game_version", "unknown")
	text += "Git Commit   : %s\n" % data.get("git_commit", "unknown")
	text += "Git Branch   : %s\n" % data.get("git_branch", "unknown")
	text += "Build Date   : %s\n" % data.get("build_date", "unknown")

	if data.get("git_dirty", false):
		text += "Working Tree : DIRTY ⚠️\n"
	else:
		text += "Working Tree : CLEAN\n"

	return text


func load_doc_status() -> String:
	var path = "res://documentation/DOCUMENTATION_STATUS.md"
	if not FileAccess.file_exists(path):
		return "Documentation status: NOT AVAILABLE\n"

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Documentation status: FAILED TO OPEN\n"

	return "Documentation status: AVAILABLE\n"
