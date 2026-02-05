# Architecture GameRoot - Guide de Configuration

## Vue d'ensemble

Cette architecture utilise une **scène persistante unique** (`GameRoot.tscn`) qui reste en mémoire pendant toute la durée de vie du jeu. Tous les systèmes globaux sont des enfants de cette scène, ce qui simplifie la gestion des références et évite les problèmes de timing avec les autoloads traditionnels.

## Structure des fichiers

```
project/
├── core/
│   ├── game_root.tscn          # 🎯 Scène principale persistante
│   ├── autoloads/              # Scripts des systèmes
│   │   ├── game_root.gd
│   │   ├── event_bus.gd
│   │   ├── global_logger.gd
│   │   ├── scene_loader.gd
│   │   ├── game_manager.gd
│   │   ├── ui_manager.gd
│   │   ├── debug_overlay.gd
│   │   ├── battle_data_manager.gd
│   │   ├── dialogue_manager.gd
│   │   ├── team_manager.gd
│   │   └── version_manager.gd
│   └── data/
│       ├── scene_registry.gd
│       ├── model_validator.gd
│       ├── validation_result.gd
│       ├── json_data_loader.gd
│       └── ability_data_loader.gd
├── features/                   # Scènes de jeu (chargées dynamiquement)
│   ├── menu/
│   ├── combat/
│   └── world_map/
├── data/                       # Données JSON
│   ├── models/
│   └── abilities/
└── project.godot
```

## Hiérarchie de la scène GameRoot

```
GameRoot (Node)
├── CoreSystems (Node)
│   ├── EventBus
│   ├── GlobalLogger
│   └── VersionManager
├── Managers (Node)
│   ├── SceneLoader
│   ├── GameManager
│   ├── BattleDataManager
│   ├── DialogueManager
│   └── TeamManager
├── SceneContainer (Node)      # 🎮 Les scènes de jeu sont chargées ici
└── UILayer (CanvasLayer)
    ├── UIManager
    └── DebugOverlay
```

## Configuration du projet

### 1. Définir la scène principale

Dans **Project Settings > Application > Run**:
- `Main Scene`: `res://core/game_root.tscn`

### 2. Configurer l'autoload

Dans **Project Settings > Autoload**:
| Nom | Chemin | Activé |
|-----|--------|--------|
| GameRoot | `*res://core/game_root.tscn` | ✅ |

> ⚠️ Le `*` devant le chemin est **crucial** - il indique que c'est une scène, pas un script.

### 3. Vérifier les Input Actions

Assurez-vous que ces actions existent dans **Project Settings > Input Map**:
- `debug_toggle` (F3) - Toggle du debug overlay
- `ui_cancel` (Escape) - Pause/Retour
- `ui_accept` (Enter/Space) - Confirmer
- `ui_end` (End) - Debug status

## Accès aux systèmes

Depuis n'importe quel script du jeu, accédez aux systèmes via l'autoload `GameRoot`:

```gdscript
# Changer de scène
GameRoot.change_scene(SceneRegistry.SceneID.BATTLE)

# Envoyer une notification
GameRoot.notify("Message important!", "success")

# Utiliser l'EventBus
GameRoot.event_bus.battle_started.emit(battle_data)

# Logger
GameRoot.log_info("GAME", "Partie démarrée")

# Accéder au game manager
if GameRoot.game_manager.is_paused:
    print("Jeu en pause")
```

## Flux de chargement de scènes

1. `GameRoot.tscn` est chargée au démarrage
2. Le script `game_root.gd` initialise tous les systèmes
3. `SceneLoader` charge les scènes de jeu dans `SceneContainer`
4. Les scènes de jeu peuvent être changées sans perdre les données globales

```gdscript
# Exemple: Charger une scène de combat
GameRoot.scene_loader.load_scene_by_id(SceneRegistry.SceneID.BATTLE)

# Ou via le raccourci
GameRoot.change_scene(SceneRegistry.SceneID.BATTLE)

# Avec ou sans transition
GameRoot.change_scene(SceneRegistry.SceneID.MAIN_MENU, false)  # Sans transition
```

## Ajouter un nouveau système

1. Créer le script dans `core/autoloads/`:

```gdscript
extends Node
class_name MonSystemeClass

func _ready() -> void:
    print("[MonSysteme] ✅ Initialisé")
```

2. Ajouter le nœud dans `game_root.tscn`
3. Ajouter la référence dans `game_root.gd`:

```gdscript
@onready var mon_systeme: MonSystemeClass = $Managers/MonSysteme
```

4. Ajouter la validation si nécessaire dans `_validate_systems()`

## Bonnes pratiques

### ✅ À faire

- Toujours accéder aux systèmes via `GameRoot.xxx`
- Utiliser `EventBus` pour la communication entre scènes
- Nettoyer les signaux dans `_exit_tree()`
- Utiliser `GameRoot.event_bus.safe_connect()` pour les connexions sécurisées

### ❌ À éviter

- N'utilisez **pas** `get_parent()` pour accéder à GameRoot
- Ne créez pas d'autoloads supplémentaires (tout passe par GameRoot)
- Ne stockez pas de références directes aux scènes de jeu (elles changent)

## Debug

### Afficher le debug overlay
Appuyez sur **F3** pour afficher/masquer le debug overlay.

### Afficher le status complet
```gdscript
GameRoot.print_status()
```

### Lister les connexions EventBus
```gdscript
GameRoot.event_bus.debug_list_connections()
```

## Dépannage

### "GameRoot is null"
- Vérifiez que l'autoload est correctement configuré avec le `*`
- Assurez-vous que le code n'est pas exécuté avant `_ready()`

### "Système non trouvé"
- Vérifiez que le nœud existe dans `game_root.tscn`
- Vérifiez le chemin dans les `@onready`

### Scène ne se charge pas
- Vérifiez que le chemin existe dans `SceneRegistry`
- Vérifiez que le fichier `.tscn` existe à ce chemin

## License

MIT License
