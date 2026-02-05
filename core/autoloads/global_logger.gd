extends Node
## GlobalLogger - Système de logging centralisé
## Gère les logs avec catégories, niveaux et formatage
##
## Accès via : GameRoot.global_logger

class_name GlobalLoggerClass

# ============================================================================
# CONFIGURATION
# ============================================================================

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3,
	NONE = 4
}

const LOG_COLORS = {
	LogLevel.DEBUG: "gray",
	LogLevel.INFO: "white",
	LogLevel.WARNING: "yellow",
	LogLevel.ERROR: "red"
}

const LOG_PREFIXES = {
	LogLevel.DEBUG: "🔍",
	LogLevel.INFO: "ℹ️",
	LogLevel.WARNING: "⚠️",
	LogLevel.ERROR: "❌"
}

# ============================================================================
# ÉTAT
# ============================================================================

var min_log_level: LogLevel = LogLevel.DEBUG
var enabled_categories: Dictionary = {}  # category -> bool
var log_to_file: bool = false
var log_file_path: String = "user://logs/game.log"
var log_file: FileAccess = null

# Historique des logs (pour debug overlay)
var log_history: Array[Dictionary] = []
var max_history: int = 100

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready() -> void:
	# En release, ne logger que les warnings et erreurs
	if not OS.is_debug_build():
		min_log_level = LogLevel.WARNING
	
	# Activer toutes les catégories par défaut
	_enable_default_categories()
	
	print("[GlobalLogger] ✅ Initialisé (niveau: %s)" % LogLevel.keys()[min_log_level])

func _enable_default_categories() -> void:
	"""Active les catégories de log par défaut"""
	
	var categories = [
		"GAME", "BATTLE", "UI", "SCENE", "SAVE",
		"AUDIO", "NETWORK", "AI", "DIALOGUE", "EVENT",
		"BATTLE_DATA", "TEAM"
	]
	
	for cat in categories:
		enabled_categories[cat] = true

# ============================================================================
# API PUBLIQUE
# ============================================================================

func debug(category: String, message: String) -> void:
	"""Log de niveau DEBUG"""
	_log(LogLevel.DEBUG, category, message)

func info(category: String, message: String) -> void:
	"""Log de niveau INFO"""
	_log(LogLevel.INFO, category, message)

func warning(category: String, message: String) -> void:
	"""Log de niveau WARNING"""
	_log(LogLevel.WARNING, category, message)

func error(category: String, message: String) -> void:
	"""Log de niveau ERROR"""
	_log(LogLevel.ERROR, category, message)

# ============================================================================
# LOGGING INTERNE
# ============================================================================

func _log(level: LogLevel, category: String, message: String) -> void:
	"""Fonction de logging principale"""
	
	# Vérifier le niveau minimum
	if level < min_log_level:
		return
	
	# Vérifier si la catégorie est activée (sauf pour ERROR)
	if level != LogLevel.ERROR:
		if enabled_categories.has(category) and not enabled_categories[category]:
			return
	
	# Formater le message
	var timestamp = Time.get_time_string_from_system()
	var prefix = LOG_PREFIXES.get(level, "")
	var formatted = "[%s] %s [%s] %s" % [timestamp, prefix, category, message]
	
	# Afficher dans la console
	match level:
		LogLevel.DEBUG:
			print(formatted)
		LogLevel.INFO:
			print(formatted)
		LogLevel.WARNING:
			push_warning(formatted)
		LogLevel.ERROR:
			push_error(formatted)
	
	# Ajouter à l'historique
	_add_to_history(level, category, message, timestamp)
	
	# Écrire dans le fichier si activé
	if log_to_file:
		_write_to_file(formatted)

func _add_to_history(level: LogLevel, category: String, message: String, timestamp: String) -> void:
	"""Ajoute un log à l'historique"""
	
	log_history.append({
		"level": level,
		"category": category,
		"message": message,
		"timestamp": timestamp
	})
	
	# Limiter la taille
	while log_history.size() > max_history:
		log_history.pop_front()

func _write_to_file(message: String) -> void:
	"""Écrit un message dans le fichier de log"""
	
	if not log_file:
		_open_log_file()
	
	if log_file:
		log_file.store_line(message)
		log_file.flush()

func _open_log_file() -> void:
	"""Ouvre le fichier de log"""
	
	# Créer le dossier si nécessaire
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("logs"):
		dir.make_dir("logs")
	
	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	
	if log_file:
		log_file.store_line("=== Game Log - %s ===" % Time.get_datetime_string_from_system())
		log_file.store_line("")

# ============================================================================
# CONFIGURATION
# ============================================================================

func set_log_level(level: LogLevel) -> void:
	"""Définit le niveau minimum de log"""
	min_log_level = level
	info("GAME", "Niveau de log changé : %s" % LogLevel.keys()[level])

func enable_category(category: String, enabled: bool = true) -> void:
	"""Active ou désactive une catégorie"""
	enabled_categories[category] = enabled

func enable_file_logging(enabled: bool = true, path: String = "") -> void:
	"""Active ou désactive le logging dans un fichier"""
	
	log_to_file = enabled
	
	if path != "":
		log_file_path = path
	
	if enabled:
		_open_log_file()
		info("GAME", "Logging fichier activé : %s" % log_file_path)
	elif log_file:
		log_file.close()
		log_file = null

# ============================================================================
# UTILITAIRES
# ============================================================================

func get_recent_logs(count: int = 20, level_filter: LogLevel = LogLevel.DEBUG) -> Array[Dictionary]:
	"""Retourne les logs récents filtrés par niveau"""
	
	var filtered: Array[Dictionary] = []
	
	for i in range(log_history.size() - 1, -1, -1):
		var entry = log_history[i]
		if entry.level >= level_filter:
			filtered.append(entry)
			if filtered.size() >= count:
				break
	
	filtered.reverse()
	return filtered

func get_logs_by_category(category: String, count: int = 20) -> Array[Dictionary]:
	"""Retourne les logs d'une catégorie spécifique"""
	
	var filtered: Array[Dictionary] = []
	
	for i in range(log_history.size() - 1, -1, -1):
		var entry = log_history[i]
		if entry.category == category:
			filtered.append(entry)
			if filtered.size() >= count:
				break
	
	filtered.reverse()
	return filtered

func clear_history() -> void:
	"""Vide l'historique des logs"""
	log_history.clear()

# ============================================================================
# NETTOYAGE
# ============================================================================

func _exit_tree() -> void:
	if log_file:
		log_file.store_line("")
		log_file.store_line("=== Session terminée ===")
		log_file.close()
