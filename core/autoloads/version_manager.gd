extends Node
class_name VersionManagerClass
## Gestion des versions de données et migrations
##
## Accès via : GameRoot.version_manager

const CURRENT_VERSION = "1.0.0"
const VERSION_FILE = "user://version.json"

signal migration_started(from_version: String, to_version: String)
signal migration_completed(from_version: String, to_version: String)
signal migration_failed(from_version: String, to_version: String, error: String)

var migrations: Dictionary = {}  # "0.9.0" -> Callable

func _ready() -> void:
	_register_migrations()
	print("[VersionManager] ✅ Initialisé (version: %s)" % CURRENT_VERSION)

func _register_migrations() -> void:
	# Exemple de migration 0.9.0 -> 1.0.0
	register_migration("0.9.0", _migrate_0_9_to_1_0)

func register_migration(from_version: String, migration_func: Callable) -> void:
	migrations[from_version] = migration_func

func check_and_migrate() -> bool:
	var installed_version = _get_installed_version()
	
	if installed_version == CURRENT_VERSION:
		print("[VersionManager] ✅ Version à jour : ", CURRENT_VERSION)
		return true
	
	print("[VersionManager] 🔄 Migration nécessaire : ", installed_version, " -> ", CURRENT_VERSION)
	
	return migrate_from(installed_version)

func migrate_from(from_version: String) -> bool:
	if not migrations.has(from_version):
		# Pas de migration nécessaire, mettre à jour la version
		_set_installed_version(CURRENT_VERSION)
		return true
	
	migration_started.emit(from_version, CURRENT_VERSION)
	
	var migration_func = migrations[from_version]
	var success = migration_func.call()
	
	if success:
		_set_installed_version(CURRENT_VERSION)
		migration_completed.emit(from_version, CURRENT_VERSION)
		print("[VersionManager] ✅ Migration réussie")
		return true
	else:
		migration_failed.emit(from_version, CURRENT_VERSION, "Échec de la migration")
		return false

func _get_installed_version() -> String:
	if not FileAccess.file_exists(VERSION_FILE):
		return "0.0.0"
	
	var file = FileAccess.open(VERSION_FILE, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		return json.data.get("version", "0.0.0")
	
	return "0.0.0"

func _set_installed_version(version: String) -> void:
	var data = {"version": version, "timestamp": Time.get_unix_time_from_system()}
	
	var file = FileAccess.open(VERSION_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func get_current_version() -> String:
	return CURRENT_VERSION

func get_installed_version() -> String:
	return _get_installed_version()

# ============================================================================
# MIGRATIONS SPÉCIFIQUES
# ============================================================================

func _migrate_0_9_to_1_0() -> bool:
	print("[VersionManager] Migration 0.9.0 -> 1.0.0")
	
	var save_dir = "user://saves/"
	
	if not DirAccess.dir_exists_absolute(save_dir):
		return true  # Pas de sauvegardes
	
	var dir = DirAccess.open(save_dir)
	dir.list_dir_begin()
	
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".save"):
			var full_path = save_dir + file_name
			_migrate_save_file(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return true

func _migrate_save_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return
	
	var data = json.data
	data["version"] = "1.0.0"
	
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
