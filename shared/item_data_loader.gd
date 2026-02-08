# addons/core/data/item_data_loader.gd
class_name ItemDataLoader
extends Node

## Charge les données d'items depuis JSON
## Format: data/items/*.json (organisé par catégories)

const ITEMS_DIR = "res://data/items/"


var items: Dictionary = {}
var items_by_category: Dictionary = {}


func load_all_items() -> void:
	# Charge récursivement (pour avoir les sous-dossiers par catégorie)
	items = GameRoot.json_data_loader.load_json_directory(ITEMS_DIR, true)
	_organize_by_category()
	
	for category in items_by_category:
		for item in items_by_category[category]:
			if item.has("stats"):
				for stat_key in item.stats:
					item.stats[stat_key] = GameRoot.data_normalizer.to_int(item.stats[stat_key], 0)
	
	if items.is_empty():
		push_warning("No items loaded")
	else:
		print("Loaded %d items" % _count_items(items))
		GameRoot.event_bus.emit_signal("data_loaded", "items", items)

func _organize_by_category() -> void:
	items_by_category.clear()
	_flatten_items(items, items_by_category)

func _flatten_items(source: Dictionary, target: Dictionary) -> void:
	for key in source:
		if source[key] is Dictionary:
			if source[key].has("id"):
				# C'est un item
				var item = source[key]
				target[item.id] = item
				
				var category = item.get("category", "misc")
				if not items_by_category.has(category):
					items_by_category[category] = []
				items_by_category[category].append(item)
			else:
				# C'est un dossier
				_flatten_items(source[key], target)

func _count_items(dict: Dictionary) -> int:
	var count = 0
	for key in dict:
		if dict[key] is Dictionary:
			if dict[key].has("id"):
				count += 1
			else:
				count += _count_items(dict[key])
	return count

func get_item(item_id: String) -> Dictionary:
	if items_by_category.is_empty():
		_organize_by_category()
	
	for category in items_by_category:
		for item in items_by_category[category]:
			if item.id == item_id:
				return item
	
	push_error("Item not found: " + item_id)
	return {}

func get_items_by_category(category: String) -> Array:
	if items_by_category.has(category):
		return items_by_category[category]
	return []
