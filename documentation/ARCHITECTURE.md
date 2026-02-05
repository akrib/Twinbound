# ARCHITECTURE DU PROJET - PARTIE 1 : UI, DIALOGUES & WORLD MAP

## 📋 Vue d'ensemble

**Type de projet** : Tactical RPG 3D (Godot 4.x)  
**Langage principal** : GDScript  
**Architecture** : Event-driven avec systèmes découplés

---

## 🎯 Systèmes analysés dans cette partie

1. **Menu Principal** (`scenes/menu/`)
2. **Système de Dialogue** (`scenes/dialogue/`, `scenes/ui/dialogue_box`)
3. **World Map** (`scenes/world/`)
4. **Interface de Combat** (`scenes/battle/battle_3d.tscn`)
5. **Narrative/Intro** (`scenes/narrative/`)

---

## 🏗️ STRUCTURE DES DOSSIERS

```
scenes/
├── battle/              # Scènes de combat 3D
│   ├── battle_3d.tscn          # Scène principale du combat
│   └── damage_number.tscn       # Affichage des dégâts
├── dialogue/            # Système de dialogue
│   ├── bark_label.gd/tscn      # Messages courts flottants
│   ├── bark_system.gd          # Gestionnaire de barks
│   ├── dialogue_data.gd        # Format de données dialogues
│   └── effects/                # Effets BBCode (shake, wave, rainbow)
├── menu/                # Menu principal
│   ├── main_menu.gd/tscn
├── narrative/           # Scènes narratives
│   └── intro_dialogue.gd/tscn
├── team/               # Gestion d'équipe
│   └── team_roster_ui.tscn
├── ui/                 # Composants UI réutilisables
│   └── dialogue_box.gd/tscn    # Boîte de dialogue principale
└── world/              # World map
    ├── world_map.gd/tscn
    ├── world_map_location.gd
    ├── world_map_connection.gd
    └── world_map_player.gd
```

---

## 🔧 SYSTÈMES PRINCIPAUX

### 1. EVENT BUS (EventBus)

**Architecture centrale** : Communication événementielle découplée

#### Signaux utilisés
```gdscript
# Gestion de scènes
GameRoot.event_bus.change_scene(scene_id)

# Notifications
GameRoot.event_bus.notify(message, type)  # type: "info", "warning", "error"
GameRoot.event_bus.notification_posted.emit(message, type)

# Jeu
GameRoot.event_bus.game_started.emit()
GameRoot.event_bus.game_loaded.emit(save_name)
GameRoot.event_bus.game_paused.emit(paused)
GameRoot.event_bus.quit_game_requested.emit()

# World Map
GameRoot.event_bus.location_discovered.emit(location_id)

# Custom events
GameRoot.event_bus.emit_event(event_type, [event_data])
```

#### Pattern de connexion sécurisée
```gdscript
GameRoot.event_bus.safe_connect("signal_name", callback)
GameRoot.event_bus.disconnect_all(self)  # Dans _exit_tree()
```

---

### 2. SCENE LOADER (SceneLoader)

**Gestion des transitions** entre scènes avec système de registre

#### SceneRegistry (SceneRegistry.SceneID)
```gdscript
enum SceneID {
    MAIN_MENU,
    WORLD_MAP,
    BATTLE,
    OPTIONS_MENU,
    CREDITS,
    # ... autres scènes
}
```

#### Utilisation
```gdscript
GameRoot.event_bus.change_scene(SceneRegistry.SceneID.WORLD_MAP)
```

#### Auto-connexion des signaux
Les scènes peuvent implémenter :
```gdscript
func _get_signal_connections() -> Array:
    return [
        {
            "source": button,
            "signal_name": "pressed",
            "target": self,
            "method": "_on_button_pressed"
        }
    ]
```

---

### 3. SYSTÈME DE DIALOGUE

#### DialogueData (Resource)
Format de données pour les dialogues

**Structure d'une ligne** :
```gdscript
{
    "speaker": "Nom du personnage",
    "speaker_key": "clé_i18n",  # Pour i18n
    "text": "Texte affiché",
    "text_key": "dialogue.key.01",
    "portrait": "res://portraits/knight.png",
    "emotion": "happy",  # happy, sad, angry, neutral
    "voice_sfx": "res://sfx/voice_male.ogg",
    "speed": 50.0,  # Override vitesse
    "auto_advance": false,  # ⚠️ false par défaut
    "auto_delay": 2.0,
    "effects": ["shake", "rainbow"],  # Effets BBCode
    "choices": [],  # Pour choix multiples
    "event": {},  # Événement à déclencher
}
```

#### Effets BBCode disponibles
- `[shake rate=20 level=5]` - Tremblement
- `[wave amp=50 freq=2]` - Ondulation
- `[rainbow freq=0.2]` - Arc-en-ciel

#### DialogueBox (Control)
**Composant UI réutilisable**

**Signaux** :
```gdscript
text_reveal_started
text_reveal_completed
choice_selected(index)
```

**Méthodes publiques** :
```gdscript
show_dialogue_box()
hide_dialogue_box()
display_line(line: Dictionary)
display_choices(choices: Array)
complete_text()  # Skip typewriter
```

**Input** :
- Clic gauche / Espace / Entrée : Avancer
- Si texte en révélation : complète le texte
- Sinon : passe à la ligne suivante
- Navigation choix : Haut/Bas

#### Dialogue_Manager (Singleton)
**Gestionnaire global des dialogues**

```gdscript
Dialogue_Manager.start_dialogue(dialogue_data, dialogue_box)
Dialogue_Manager.advance_dialogue()
Dialogue_Manager.select_choice(index)

# Signaux
Dialogue_Manager.dialogue_ended
```

#### BarkSystem (Node2D)
**Messages courts flottants** (non-bloquants)

```gdscript
bark_system.show_bark(speaker, text, world_position, duration)
bark_system.show_bark_3d(speaker, text, world_pos_3d, camera, duration)
```

#### Chargement des données
```gdscript
# JSON
var dialogue = DialogueData.from_json("res://data/dialogues/intro.json")

# CSV
var dialogue = DialogueData.from_csv("res://data/dialogues/lines.csv", "dialogue_id")

# Quick creation
var dialogue = DialogueData.quick_dialogue("test_id", [
    ["Knight", "Hello!"],
    ["Wizard", "Welcome!"]
])
```

---

### 4. WORLD MAP

#### Architecture
- **WorldMap** : Nœud principal (Node2D)
- **WorldMapLocation** : Points d'intérêt
- **WorldMapConnection** : Lignes de connexion entre locations
- **WorldMapPlayer** : Sprite du joueur

#### WorldMapLocation (Node2D)
**Représente une location interactive**

**Propriétés** :
```gdscript
location_id: String
location_name: String
is_unlocked: bool
```

**Signaux** :
```gdscript
clicked(location)
hovered(location)
unhovered(location)
```

**Données attendues** :
```gdscript
{
    "id": "village_north",
    "name": "Village du Nord",
    "position": {"x": 400, "y": 300},  # ou Vector2i
    "icon": "res://icons/town.png",  # Optionnel, rond jaune par défaut
    "scale": 1.5,
    "connections": ["castle_central"],
    "unlocked_at_step": 0
}
```

#### WorldMapConnection (Node2D)
**Lignes pointillées entre locations avec état**

**États** :
```gdscript
enum ConnectionState {
    UNLOCKED,   # Accessible
    LOCKED,     # Visible mais bloqué (+ croix rouge)
    HIDDEN      # Invisible
}
```

**Configuration globale** (variables de classe statiques) :
```gdscript
WorldMapConnection.default_line_width = 4.0
WorldMapConnection.default_dash_length = 15.0
WorldMapConnection.default_color_unlocked = Color(0.7, 0.7, 0.7, 0.8)
WorldMapConnection.default_color_locked = Color(0.3, 0.3, 0.3, 0.4)
```

**API publique** :
```gdscript
world_map.unlock_connection(from_id, to_id)
world_map.lock_connection(from_id, to_id)
world_map.hide_connection(from_id, to_id)
world_map.reveal_connection(from_id, to_id, locked=true)
```

#### WorldMapPlayer (Node2D)
**Sprite du joueur avec animation bounce**

**Configuration** :
```gdscript
bounce_speed: 1.5
bounce_amount: 10.0
bounce_offset: 75.0  # Offset vertical permanent
move_speed: 300.0
```

**Méthodes** :
```gdscript
move_to_location(target_location)  # Avec animation
set_location(location)  # Sans animation

# Signaux
movement_started
movement_completed
```

#### Actions sur les locations
Les locations peuvent avoir des **actions** définies dans les données :

**Types d'actions** :
- `"battle"` : Lance un combat
- `"dialogue"` : Démarre un dialogue
- `"exploration"` : Exploration
- `"building"` : Entrée dans un bâtiment
- `"shop"` : Magasin
- `"quest_board"` : Panneau de quêtes
- `"team_management"` : Gestion d'équipe
- `"custom"` : Événement personnalisé

**Format d'action** :
```json
{
    "id": "action_battle_01",
    "type": "battle",
    "label": "⚔️ Combat d'entraînement",
    "icon": "res://icons/battle.png",
    "unlocked_at_step": 0,
    "battle_id": "training_battle_01"
}
```

#### Chargement des données
```gdscript
# WorldMapDataLoader (singleton supposé)
var world_data = WorldMapDataLoader.load_world_map_data("world_map_data", true)
var location_data = WorldMapDataLoader.load_location_data(location_id)
```

**Structure world_map_data** :
```gdscript
{
    "name": "Monde Principal",
    "locations": [...],  # Array de location data
    "connections_visual": {
        "width": 4.0,
        "dash_length": 15.0,
        "color": {"r": 0.7, "g": 0.7, "b": 0.7, "a": 0.8},
        "color_locked": {"r": 0.3, "g": 0.3, "b": 0.3, "a": 0.4}
    },
    "connection_states": {
        "village_to_castle": "unlocked",
        "castle_to_port": "locked"
    },
    "player": {
        "start_location": "village_north",
        "icon": "res://sprites/player_icon.png",
        "scale": 1.0,
        "bounce_speed": 1.5
    }
}
```

---

### 5. MENU PRINCIPAL

#### MainMenu (Control)
**Point d'entrée du jeu**

**Boutons** :
- Nouvelle Partie → `GameRoot.event_bus.change_scene(WORLD_MAP)`
- Continuer → Charge dernière sauvegarde
- Options → (à implémenter)
- Crédits → (à implémenter)
- Quitter → `GameRoot.event_bus.quit_game_requested.emit()`

**Pattern** : Auto-connexion via `_get_signal_connections()`

---

### 6. INTRO DIALOGUE / NARRATIVE

#### IntroDialogue (Control)
**Séquence narrative pilotée par données JSON**

#### campaign_start.json
**Structure de démarrage de campagne** :

```json
{
    "start_sequence": [
        {
            "type": "dialogue",
            "dialogue_id": "intro_001",
            "blocking": true
        },
        {
            "type": "notification",
            "message": "Bienvenue !",
            "duration": 2.0
        },
        {
            "type": "unlock_location",
            "location": "village_north"
        },
        {
            "type": "transition",
            "target": "world_map",
            "fade_duration": 1.0
        }
    ]
}
```

**Types d'étapes** :
- `dialogue` : Affiche un dialogue
- `notification` : Notification temporaire
- `unlock_location` : Déverrouille une location
- `transition` : Change de scène

---

### 7. BATTLE DATA

#### BattleDataManager (Singleton supposé)
**Stockage des données de combat**

```gdscript
BattleDataManager.set_battle_data(battle_data)
```

**Format battle_data.json** :
```json
{
    "id": "training_battle_01",
    "name": "Combat d'entraînement",
    "grid_size": {"width": 10, "height": 8},
    "player_units": [
        {
            "unit_id": "knight_01",
            "position": [1, 4],
            "hp": 100,
            "stats": {"atk": 15, "def": 10}
        }
    ],
    "enemy_units": [...],
    "terrain_obstacles": [
        {
            "type": "rock",
            "position": [5, 5]
        }
    ]
}
```

**⚠️ Conversion de types nécessaire** :
- JSON `position: [x, y]` → `Vector2i(x, y)`
- JSON `grid_size: {width, height}` → `Vector2i(width, height)`
- JSON floats → int pour HP/stats

**Fonction helper** dans WorldMap :
```gdscript
_convert_battle_json_to_godot_types(battle_data: Dictionary)
```

---

## 🎨 CONVENTIONS DE CODE

### Nommage
- **Scènes** : snake_case (`world_map.tscn`)
- **Classes** : PascalCase (`WorldMapLocation`)
- **Variables** : snake_case (`location_id`)
- **Constantes** : UPPER_SNAKE_CASE (`MAX_LOCATIONS`)
- **Signaux** : snake_case (`location_discovered`)

### Organisation des fichiers
- **1 classe = 1 fichier**
- Script et scène portent le même nom
- Scripts dans `scenes/` à côté de leur .tscn

### Structure d'un script
```gdscript
extends Node2D
## Documentation de la classe
class_name ClassName

# ============================================================================
# SIGNAUX
# ============================================================================
signal signal_name()

# ============================================================================
# PROPRIÉTÉS / CONFIGURATION
# ============================================================================
@export var property: int = 0
var internal_var: String = ""

# ============================================================================
# RÉFÉRENCES
# ============================================================================
@onready var node_ref: Node = $NodePath

# ============================================================================
# INITIALISATION
# ============================================================================
func _ready() -> void:
    pass

# ============================================================================
# MÉTHODES PUBLIQUES
# ============================================================================
func public_method() -> void:
    pass

# ============================================================================
# MÉTHODES PRIVÉES
# ============================================================================
func _private_method() -> void:
    pass

# ============================================================================
# NETTOYAGE
# ============================================================================
func _exit_tree() -> void:
    GameRoot.event_bus.disconnect_all(self)
```

---

## 🔗 DÉPENDANCES ENTRE MODULES

### Hiérarchie de dépendances
```
EventBus (core)
    ↓
SceneLoader, SceneRegistry
    ↓
GameManager, Dialogue_Manager
    ↓
WorldMap, DialogueBox, MainMenu
    ↓
WorldMapLocation, DialogueData
```

### Singletons/Autoloads supposés
- `EventBus` : Bus d'événements global
- `SceneLoader` : Chargement de scènes
- `SceneRegistry` : Registre des scènes
- `GameManager` : Gestion état du jeu
- `Dialogue_Manager` : Gestionnaire de dialogues
- `BattleDataManager` : Données de combat
- `WorldMapDataLoader` : Chargeur de données world map
- `DialogueDataLoader` : Chargeur de dialogues
- `JSONDataLoader` : Chargeur JSON générique

---

## 📦 FORMATS DE DONNÉES

### Localisation (i18n)
**Système prévu** :
- Clés `speaker_key` et `text_key` dans DialogueData
- Fonction `tr(key)` pour traduction
- Fallback sur texte direct si clé absente

### JSON vs CSV
- **JSON** : Dialogues complexes, données de combat, world map
- **CSV** : Dialogues simples (lignes séquentielles)

---

## 🐛 POINTS D'ATTENTION POUR LE DEBUG

### DialogueBox
- **Auto-advance désactivé par défaut** : `"auto_advance": false`
- Indicateur de continuation visible seulement quand texte complètement révélé
- Input géré dans `_input()`, pas dans les boutons

### WorldMap
- Les locations créent un **rond jaune par défaut** si pas d'icône
- Player sprite placé avec **bounce_offset** de 75px au-dessus
- Connexions créées une seule fois par paire (évite doublons)
- Area2D avec `collision_layer = 2` pour clics

### Conversions de types
- JSON arrays → Vector2i nécessite conversion manuelle
- Floats JSON → int pour stats

### EventBus
- **Toujours déconnecter** dans `_exit_tree()`
- Utiliser `safe_connect()` pour éviter doublons

---

## ✅ CHECKLIST : Ce dont j'ai besoin pour débugger/créer

### Pour débugger un dialogue
- [ ] DialogueData (format JSON ou code)
- [ ] ID du dialogue
- [ ] Scène avec DialogueBox
- [ ] Connexion à Dialogue_Manager

### Pour débugger la World Map
- [ ] world_map_data.json
- [ ] location_data JSON pour chaque location
- [ ] Liste des connexions attendues
- [ ] Step de progression actuel

### Pour débugger un combat
- [ ] battle_data JSON
- [ ] Liste des unités (player + enemy)
- [ ] Grid size
- [ ] Obstacles terrain

### Informations générales toujours utiles
- [ ] Version de Godot
- [ ] Liste des autoloads/singletons actifs
- [ ] Structure complète des dossiers `data/`
- [ ] Stacktrace d'erreur complète
- [ ] État du GameManager (si existant)

---

## 📝 NOTES POUR LA SUITE

**Systèmes non couverts dans cette partie** :
- Système de combat tactique complet
- Gestion de l'équipe (team roster)
- Système d'inventaire
- Gestion des stats/classes des unités
- Système de sauvegarde
- Audio/Musique
- Effets visuels (VFX)

**Attente des parties suivantes** pour compléter l'architecture globale.

---

## 🔍 QUESTIONS POUR CLARIFICATIONS FUTURES

1. **GameManager** : Structure complète ? État global ?
2. **Sauvegarde** : Format ? Quoi sauvegarder ?
3. **Combat** : Flow complet ? Turn-based ? Actions disponibles ?
4. **Stats** : Système de classes ? Progression ?
5. **Inventaire** : Items équipables ? Consommables ?

---

*Document généré pour la Partie 1 - À compléter avec les parties suivantes*

# ARCHITECTURE_PART2.md - Système de Combat & Modules Avancés

**Tactical RPG Duos - Godot 4.5**  
**Date:** 2026-01-29  
**Partie:** 2/X (Combat, Modules Battle, Systèmes Avancés)

---

## TABLE DES MATIÈRES

1. [Vue d'ensemble](#vue-densemble)
2. [Système de Combat 3D](#système-de-combat-3d)
3. [Modules de Combat](#modules-de-combat)
4. [Systèmes Avancés](#systèmes-avancés)
5. [Managers Critiques](#managers-critiques)
6. [Data Loaders & Validation](#data-loaders--validation)
7. [Patterns & Utilitaires](#patterns--utilitaires)
8. [Configuration Projet](#configuration-projet)
9. [Points d'Attention](#points-dattention)
10. [Dépendances Inter-Systèmes](#dépendances-inter-systèmes)

---

## VUE D'ENSEMBLE

### Systèmes documentés dans cette partie

**Combat 3D :**
- BattleMapManager3D (orchestrateur principal)
- BattleUnit3D (entité de combat)
- DamageNumber (feedback visuel)

**Modules de Combat :**
- TerrainModule3D (grille 3D)
- UnitManager3D (gestion des unités)
- MovementModule3D (déplacement avec pathfinding)
- ActionModule3D (actions de combat)
- AIModule3D (intelligence artificielle)
- ObjectiveModule (objectifs de mission)

**Systèmes Avancés :**
- DuoSystem (formation de duos)
- RingSystem (anneaux matérialisation/canalisation)
- Command Pattern (undo/redo)
- State Machine (états de combat)

**Managers :**
- BattleDataManager (stockage données combat)
- CampaignManager (progression campagne)
- TeamManager (gestion équipe joueur)

**Infrastructure :**
- JSONDataLoader (chargement JSON)
- Validation (validators & rules)
- Logging (GlobalLogger)
- DebugOverlay (debug en jeu)

---

## SYSTÈME DE COMBAT 3D

### 1. BattleMapManager3D

**Fichier :** `scripts/battle/battle_map_manager_3d.gd`  
**Type :** Node3D  
**Rôle :** Orchestrateur principal du combat tactique 3D

#### Structure

```
BattleMapManager3D (Node3D)
├── GridContainer (Node3D)
│   └── TerrainModule3D
├── UnitsContainer (Node3D)
│   └── BattleUnit3D (instances)
├── CameraRig (Node3D)
│   └── Camera3D
└── UILayer (CanvasLayer)
    └── BattleUI (Control)
        ├── ActionPopup (menu actions)
        ├── DuoSelectionPopup (sélection duo)
        ├── UnitInfoPanel (infos unité)
        ├── TopBar (tour/phase)
        └── BottomBar (contrôles)
```

#### Configuration

```gdscript
const TILE_SIZE: float = 1.0
const GRID_WIDTH: int = 20
const GRID_HEIGHT: int = 15

# Caméra
const CAMERA_ROTATION_SPEED: float = 90.0
const CAMERA_DISTANCE: float = 15.0
const CAMERA_HEIGHT: float = 12.0
const CAMERA_ANGLE: float = 45.0

# Couleurs highlight
const MOVEMENT_COLOR: Color = Color(0.3, 0.6, 1.0, 0.5)
const ATTACK_COLOR: Color = Color(1.0, 0.3, 0.3, 0.5)
```

#### Enums

```gdscript
enum TurnPhase {
    PLAYER_TURN,
    ENEMY_TURN,
    CUTSCENE,
    VICTORY,
    DEFEAT
}

enum ActionState {
    IDLE,              # Aucune action
    UNIT_SELECTED,     # Unité sélectionnée
    CHOOSING_DUO,      # Choix partenaire duo
    SHOWING_MOVE,      # Affichage mouvement
    SHOWING_ATTACK,    # Affichage attaque
    EXECUTING_ACTION   # Exécution action
}
```

#### Signaux

```gdscript
signal battle_map_ready()
signal turn_phase_changed(phase: TurnPhase)
signal unit_selected(unit: BattleUnit3D)
signal unit_deselected()
signal action_completed()
```

#### Initialisation

**Séquence de démarrage :**

```gdscript
_ready() 
└── await _initialize_modules()
    ├── Création TerrainModule3D
    ├── Création UnitManager3D
    ├── Création MovementModule3D
    ├── Création ActionModule3D
    ├── Création ObjectiveModule
    ├── Création JSONScenarioModule
    ├── Création BattleStatsTracker
    ├── Création AIModule3D
    ├── Création DuoSystem
    ├── Création RingSystem
    ├── Création DataValidationModule
    └── _connect_modules()

└── initialize_battle(data: Dictionary)
    ├── _load_terrain(terrain_data)
    ├── _load_objectives(objectives_data)
    ├── _load_scenario(scenario_data)
    ├── _spawn_units(player_units, enemy_units)
    └── _start_battle()
        ├── play_intro() (si présent)
        ├── GameRoot.event_bus.battle_started.emit()
        └── _start_player_turn()
```

#### Gestion des Tours

**Tour joueur :**
```gdscript
_start_player_turn()
├── unit_manager.reset_player_units()
├── _update_all_torus_states(true)
├── json_scenario_module.trigger_turn_event(turn, false)
└── set_process_input(true)

# Fin tour
_end_player_turn()
├── set_process_input(false)
├── _deselect_unit()
├── change_phase(ENEMY_TURN)
└── _start_enemy_turn()
```

**Tour ennemi :**
```gdscript
_start_enemy_turn()
├── unit_manager.reset_enemy_units()
├── _update_all_torus_states(false)
├── json_scenario_module.trigger_turn_event(turn, false)
├── ai_module.execute_enemy_turn()
└── _end_enemy_turn()
    ├── current_turn += 1
    ├── objective_module.check_objectives()
    └── _start_player_turn()
```

#### Système de Sélection 3D

**Raycasting :**

```gdscript
_input(event: InputEventMouseButton)
└── _handle_mouse_click(mouse_pos)
    └── PhysicsRayQueryParameters3D
        ├── collide_with_areas = true
        ├── collision_mask = 3
        └── intersect_ray()
            ├── Clic sur unité → _handle_unit_click()
            └── Clic sur terrain → _handle_terrain_click()
```

**Sélection unité :**

```gdscript
_select_unit(unit: BattleUnit3D)
├── _deselect_unit() (si déjà sélectionnée)
├── unit.set_selected(true)
├── unit_selected.emit(unit)
├── _open_action_menu()
└── current_action_state = UNIT_SELECTED
```

#### Menu d'Actions

**Boutons disponibles :**

- **Move** : Affiche cases accessibles (MOVEMENT_COLOR)
- **Attack** : Ouvre menu sélection duo ou affiche portée
- **Defend** : +50% défense, consomme action
- **Abilities** : Liste capacités (désactivé si vide)
- **Items** : Inventaire (à implémenter)
- **Wait** : Termine le tour de l'unité
- **Cancel** : Ferme le menu

#### Système de Duo

**Flow de formation :**

```gdscript
_on_attack_pressed()
├── Vérifie si unité déjà en duo
│   ├── OUI → Utilise duo existant
│   └── NON → _open_duo_selection_menu()
│       ├── Recherche alliés à distance <= 3
│       ├── Crée boutons pour candidats
│       └── Bouton "Attaquer Seul" (toujours disponible)
│
└── _select_duo_partner(partner)
    ├── duo_system.try_form_duo(leader, support)
    ├── duo_partner = partner
    └── _show_attack_range()
```

**Validation duo :**

- Même équipe (player_unit == player_unit)
- Distance <= 3 cases
- Aucune unité déjà en duo
- Unités vivantes

#### Caméra Rotative

**Rotation par paliers de 90° :**

```gdscript
# Inputs
ui_home → rotate_camera(-90)  # Gauche
ui_end  → rotate_camera(90)   # Droite

# Animation smooth
_process_camera_rotation(delta)
├── Interpolation angle_current → angle_target
├── CAMERA_ROTATION_SPEED = 90°/s
└── _update_camera_position()
    ├── camera_rig.rotation.y = angle_rad
    └── camera.position = Vector3(0, HEIGHT, DISTANCE)
```

#### Panel d'Information (bas droite)

**Priorités d'affichage :**

1. **Unité survolée** (hovered_unit ≠ selected_unit)
2. **Unité sélectionnée** (selected_unit)
3. **Info terrain** (tuile sous souris)

**Affichage unité :**

```gdscript
info_unit_name_label.text = unit.unit_name
info_class_label.text = "Classe: " + unit_class
info_hp_value.text = "HP/MAX"  # Couleur selon %
info_atk_value.text = str(attack)
info_def_value.text = str(defense)
info_mov_value.text = str(movement)
```

#### Fin de Combat

**Conditions victoire :**
- Tous les ennemis morts
- Tous les objectifs complétés

**Conditions défaite :**
- Toutes les unités joueur mortes

**Séquence de fin :**

```gdscript
_end_battle(victory: bool)
├── is_battle_active = false
├── duo_system.clear_all_duos()
├── _award_xp_to_survivors() (si victoire)
├── json_scenario_module.play_outro(victory)
├── stats_tracker.get_final_stats()
├── _calculate_rewards(victory, stats)
├── GameRoot.event_bus.battle_ended.emit(results)
└── GameRoot.event_bus.change_scene(BATTLE_RESULTS)
```

---

### 2. BattleUnit3D

**Fichier :** `scripts/battle/entities/battle_unit_3d.gd`  
**Type :** Node3D  
**Rôle :** Entité de combat avec visuels 3D billboard

#### Composition Visuelle

```
BattleUnit3D (Node3D)
├── shadow_sprite (Sprite3D horizontal)
├── sprite_3d (Sprite3D billboard)
├── selection_indicator (TorusMesh horizontal)
├── hp_bar_container (Node3D billboard)
│   ├── hp_bar_bg (MeshInstance3D - fond gris)
│   ├── hp_bar_3d (MeshInstance3D - vert)
│   └── team_indicator (MeshInstance3D - vert/rouge)
└── collision (Area3D + CylinderShape3D)
```

#### Stats de Base

```gdscript
var max_hp: int = 100
var current_hp: int = 100
var attack_power: int = 20
var defense_power: int = 10
var movement_range: int = 5
var attack_range: int = 1
```

#### États d'Action

```gdscript
var movement_used: bool = false
var action_used: bool = false
var has_acted_this_turn: bool = false
```

#### Système de Torus (anneau de sélection)

**États visuels :**

```gdscript
enum TorusState {
    CAN_ACT_AND_MOVE,   # Vert
    CAN_ACT_ONLY,       # Jaune
    CAN_MOVE_ONLY,      # Bleu
    CANNOT_ACT,         # Gris
    SELECTED,           # Rouge
    ENEMY_TURN          # Gris
}
```

**Mise à jour :**

```gdscript
update_torus_state(is_current_turn: bool)
├── Détermine l'état selon capacités
└── _apply_torus_color()
    └── material.albedo_color = color
```

**Configuration torus :**

```gdscript
TorusMesh.new()
├── inner_radius = tile_size * 0.35
├── outer_radius = tile_size * 0.45
├── position.y = -0.4  # Au sol
└── emission_enabled = true
```

#### Barre de HP Billboard

**Correction importante :** La barre HP utilise un billboard pur qui copie la rotation de la caméra

```gdscript
_process(delta)
└── if hp_bar_container:
        var cam_basis = camera.global_transform.basis
        hp_bar_container.global_transform.basis = cam_basis
```

**Composition :**

```gdscript
hp_bar_container (Node3D)
├── hp_bar_bg (BoxMesh 0.8x0.08x0.02 - gris foncé)
├── hp_bar_3d (BoxMesh dynamique - vert/jaune/rouge)
│   ├── scale.x = hp_percent
│   └── position.x = -offset  # Ancré à gauche
└── team_indicator (BoxMesh 0.12x0.12x0.04)
    └── position.x = bar_width/2 + 0.08  # À droite
```

**⚠️ Détails Critiques :**

- Utiliser `TRANSPARENCY_DISABLED` sur tous les materials
- Définir `sorting_offset = 0.1` sur hp_bar_3d
- Position.z = 0.03 pour passer devant le fond
- Material `cull_mode = CULL_DISABLED`

#### Initialisation depuis Données

```gdscript
initialize_unit(data: Dictionary)
├── Identité (name, id, is_player)
├── Position (grid_position)
├── Stats (depuis data.stats ou direct)
│   ⚠️ IMPORTANT: Ordre d'initialisation
│   ├── temp_max_hp = data.stats.hp
│   ├── temp_current_hp = data.hp (si défini)
│   ├── max_hp = temp_max_hp
│   └── current_hp = temp_current_hp ou max_hp
├── Capacités (abilities array)
├── Effets de statut (status_effects dict)
├── Apparence (color selon équipe)
└── Level & XP
```

**⚠️ Bug HP :** Toujours initialiser `max_hp` AVANT `current_hp` pour éviter division par zéro.

#### Système de Dégâts

```gdscript
take_damage(damage: int) -> int
├── actual_damage = max(1, damage - defense_power)
├── current_hp -= actual_damage
├── _update_hp_bar()
├── _animate_damage()  # Flash rouge
└── if current_hp <= 0: die()

heal(amount: int) -> int
├── current_hp = min(max_hp, current_hp + amount)
├── _update_hp_bar()
└── _animate_heal()  # Flash vert
```

#### Collision pour Raycasting

```gdscript
Area3D
├── collision_layer = 2  # Layer unités
├── collision_mask = 0
└── CylinderShape3D
    ├── radius = tile_size * 0.4
    └── height = sprite_height * 2

# Métadonnées
area.set_meta("unit", self)
```

#### Reset Tour

```gdscript
reset_for_new_turn()
├── movement_used = false
├── action_used = false
├── has_acted_this_turn = false
├── _process_status_effects()  # Décrémente durée
└── update_torus_state(true)
```

---

### 3. DamageNumber

**Fichier :** `scripts/battle/entities/damage_number.gd`  
**Type :** Node3D  
**Rôle :** Affichage animé des dégâts avec parabole

#### Configuration

```gdscript
var lifetime: float = 1.5
var peak_height: float = 2.0
var label_3d: Label3D (billboard)
```

#### Animation Parabolique

```gdscript
_process(delta)
├── elapsed += delta
├── t = elapsed / lifetime  # 0.0 → 1.0
├── parabola = -4 * peak_height * t * (t - 1)
├── final_pos = start + offset * t
├── final_pos.y += parabola
└── if t > 0.5: fade_out
```

**Formule parabole :** `y = -4h·t·(t-1)` où h = hauteur pic

#### Utilisation

```gdscript
var dn = DamageNumber.new()
dn.setup(damage, spawn_pos, random_offset)
target.get_parent().add_child(dn)  # Auto-destroy après lifetime
```

---

## MODULES DE COMBAT

### 4. TerrainModule3D

**Fichier :** `scripts/battle/modules/terrain_module_3d.gd`  
**Type :** Node3D  
**Rôle :** Grille de terrain 3D avec tuiles physiques

#### Configuration

```gdscript
var tile_size: float = 1.0
var tile_height: float = 0.2
var grid_width: int = 20
var grid_height: int = 15
```

#### Types de Tuiles

```gdscript
enum TileType {
    GRASS,      # Plaine (coût 1.0, def +0)
    FOREST,     # Forêt (coût 2.0, def +10)
    MOUNTAIN,   # Montagne (coût 3.0, def +20)
    WATER,      # Eau (coût INF, def +0)
    ROAD,       # Route (coût 0.5, def +0)
    WALL,       # Mur (coût INF, def +0)
    BRIDGE,     # Pont (coût 1.0, def +0)
    CASTLE,     # Château (coût 1.0, def +30)
}
```

#### Propriétés des Tuiles

```gdscript
const MOVEMENT_COSTS: Dictionary = {
    GRASS: 1.0,
    FOREST: 2.0,
    MOUNTAIN: 3.0,
    WATER: INF,  # Non marchable
    # ...
}

const DEFENSE_BONUS: Dictionary = {
    GRASS: 0,
    FOREST: 10,
    MOUNTAIN: 20,
    CASTLE: 30,
    # ...
}

const TILE_HEIGHTS: Dictionary = {
    GRASS: 0.0,
    MOUNTAIN: 0.5,
    WATER: -0.1,
    # ...
}
```

#### Structure de Données

```gdscript
var grid: Array[Array] = []  # [y][x] = TileType
var tile_meshes: Array[Array] = []  # [y][x] = MeshInstance3D
var tile_materials: Array[Array] = []  # [y][x] = StandardMaterial3D
```

#### Génération de Terrain

**Depuis preset :**

```gdscript
load_preset("plains")
└── _generate_from_preset(preset_dict)
    ├── Fill base_type
    └── _add_feature(feature) pour chaque feature
        ├── Si positions → placer aux coords
        └── Si density → distribution aléatoire
```

**Presets disponibles :**

- `"plains"` : base GRASS + forêts éparses
- `"forest"` : base FOREST + clairières
- `"castle"` : base GRASS + château + murs
- `"mountain"` : base MOUNTAIN + plaines/forêts

#### Création de Mesh 3D

```gdscript
_create_tile_mesh(grid_pos: Vector2i) -> MeshInstance3D
├── mesh_instance = MeshInstance3D.new()
├── mesh = BoxMesh (size 0.98x0.2x0.98)
├── position = grid_to_world(grid_pos)
├── position.y += TILE_HEIGHTS[type]
├── material = StandardMaterial3D
│   ├── albedo_color = TILE_COLORS[type]
│   ├── transparency (si WATER)
│   └── roughness selon type
├── StaticBody3D + CollisionShape3D (BoxShape3D)
└── set_meta("grid_position", grid_pos)
```

#### Highlighting (coloration cases)

```gdscript
highlight_tile(grid_pos: Vector2i, color: Color)
├── material.albedo_color = original.lerp(color, 0.5)
└── material.emission = color * 0.3

clear_highlight(grid_pos: Vector2i)
├── material.albedo_color = TILE_COLORS[type]
└── material.emission_enabled = false
```

#### Conversions 3D

```gdscript
grid_to_world(grid_pos: Vector2i) -> Vector2
├── offset_x = (grid_width - 1) * tile_size / 2
├── offset_z = (grid_height - 1) * tile_size / 2
└── return Vector2(
        x * tile_size - offset_x,
        y * tile_size - offset_z
    )

world_to_grid(world_pos: Vector3) -> Vector2i
└── Inverse transformation
```

#### Pathfinding Helpers

```gdscript
get_neighbors(pos: Vector2i) -> Array[Vector2i]
└── Retourne [haut, bas, gauche, droite] si in_bounds

get_distance(from: Vector2i, to: Vector2i) -> int
└── Manhattan: abs(to.x - from.x) + abs(to.y - from.y)
```

---

### 5. UnitManager3D

**Fichier :** `scripts/battle/modules/unit_manager_3d.gd`  
**Type :** Node3D  
**Rôle :** Gestion centralisée de toutes les unités

#### Structure

```gdscript
var all_units: Array[BattleUnit3D] = []
var player_units: Array[BattleUnit3D] = []
var enemy_units: Array[BattleUnit3D] = []
var unit_grid: Dictionary = {}  # Vector2i -> BattleUnit3D
```

#### Spawning d'Unité

```gdscript
spawn_unit(unit_data: Dictionary, is_player: bool) -> BattleUnit3D
├── unit = BattleUnit3D.new()
├── unit.is_player_unit = is_player
├── unit.initialize_unit(unit_data)
├── unit.position = _grid_to_world_3d(spawn_pos)
├── add_child(unit)
├── all_units.append(unit)
├── player_units ou enemy_units.append(unit)
├── unit_grid[spawn_pos] = unit
└── unit.died.connect(_on_unit_died.bind(unit))
```

**⚠️ Position 3D avec hauteur terrain :**

```gdscript
_grid_to_world_3d(grid_pos: Vector2i) -> Vector3
├── world_2d = terrain.grid_to_world(grid_pos)
├── tile_type = terrain.get_tile_type(grid_pos)
├── tile_height = terrain.TILE_HEIGHTS[tile_type]
└── return Vector3(world_2d.x, tile_height + 0.5, world_2d.y)
```

#### Mouvement

```gdscript
move_unit(unit: BattleUnit3D, new_pos: Vector2i)
├── unit_grid.erase(old_pos)
├── unit.grid_position = new_pos
├── unit.position = _grid_to_world_3d(new_pos)
├── unit_grid[new_pos] = unit
└── unit_moved.emit(unit, old_pos, new_pos)
```

#### Getters

```gdscript
get_unit_at(grid_pos: Vector2i) -> BattleUnit3D
get_all_units() -> Array[BattleUnit3D]
get_alive_player_units() -> Array[BattleUnit3D]
get_alive_enemy_units() -> Array[BattleUnit3D]
is_position_occupied(grid_pos: Vector2i) -> bool
```

#### Reset Tours

```gdscript
reset_player_units()
└── for unit in player_units:
        unit.reset_for_new_turn()

reset_enemy_units()
└── for unit in enemy_units:
        unit.reset_for_new_turn()
```

---

### 6. MovementModule3D

**Fichier :** `scripts/battle/modules/movement_module_3d.gd`  
**Type :** Node  
**Rôle :** Gestion du déplacement avec pathfinding A*

#### Configuration

```gdscript
const MOVEMENT_SPEED: float = 3.0  # unités/sec
const MOVEMENT_COLOR: Color = Color(0.3, 0.6, 1.0, 0.5)
```

#### Calcul de Portée

```gdscript
calculate_reachable_positions(unit: BattleUnit3D) -> Array[Vector2i]
├── Flood-fill depuis position unité
├── max_movement = unit.movement_range
├── Pour chaque voisin:
│   ├── move_cost = terrain.get_movement_cost(neighbor)
│   ├── new_cost = current_cost + move_cost
│   ├── if new_cost > max_movement: skip
│   └── if occupied and ≠ start: skip
└── return positions accessibles
```

#### Pathfinding A*

```gdscript
calculate_path(from: Vector2i, to: Vector2i, max_movement: float) -> Array
├── open_set = [from]
├── g_score = {from: 0}
├── f_score = {from: heuristic(from, to)}
├── Pour chaque itération:
│   ├── current = node avec f_score minimal
│   ├── if current == to: return _reconstruct_path()
│   ├── Pour chaque voisin:
│   │   ├── tentative_g = g_score[current] + move_cost
│   │   ├── if tentative_g > max_movement: skip
│   │   └── if meilleur chemin: update scores
└── return []  # Pas de chemin
```

**Heuristique :** Distance Manhattan

#### Animation de Mouvement

```gdscript
move_unit(unit: BattleUnit3D, target: Vector2i)
├── path = calculate_path(from, to, movement_range)
├── movement_started.emit(unit)
├── await _animate_movement_3d(unit, path)
├── unit_manager.move_unit(unit, target)
└── movement_completed.emit(unit, path)

_animate_movement_3d(unit, path)
└── Pour chaque étape:
    ├── world_3d = terrain.grid_to_world(next_pos)
    ├── distance / MOVEMENT_SPEED = duration
    ├── tween.tween_property(position, world_3d, duration)
    └── await tween.finished
```

---

### 7. ActionModule3D

**Fichier :** `scripts/battle/modules/action_module_3d.gd`  
**Type :** Node  
**Rôle :** Gestion des actions de combat (attaque, capacités)

#### Validation Attaque

```gdscript
can_attack(attacker: BattleUnit3D, target: BattleUnit3D) -> bool
├── attacker.can_act() ?
├── target.is_alive() ?
├── Équipes différentes ?
├── distance = terrain.get_distance(pos_a, pos_b)
└── distance <= attacker.attack_range ?
```

#### Portée d'Attaque

```gdscript
get_attack_positions(unit: BattleUnit3D) -> Array[Vector2i]
├── range = unit.attack_range
├── Pour dy in [-range, range]:
│   └── Pour dx in [-range, range]:
│       ├── manhattan = abs(dx) + abs(dy)
│       ├── if manhattan <= range and ≠ (0,0):
│       └── positions.append(pos)
└── return positions
```

#### Exécution Attaque

```gdscript
execute_attack(attacker, target, duo_partner = null)
├── Vérifier can_attack()
├── is_duo_attack = (duo_partner != null)
├── await _animate_attack_3d(attacker, target)
├── damage = calculate_damage(attacker, target)
├── if is_duo_attack: damage *= 1.5
├── target.take_damage(damage)
├── _spawn_damage_number(target, damage)
├── damage_dealt.emit(target, damage)
└── GameRoot.event_bus.attack(attacker, target, damage)
```

#### Calcul Dégâts

```gdscript
calculate_damage(attacker, target) -> int
├── base_damage = attacker.attack_power
├── terrain_defense = terrain.get_defense_bonus(target_pos)
├── total_defense = target.defense + (terrain_def * 0.1)
├── damage = max(1, base_damage - total_defense)
└── damage *= randf_range(0.9, 1.1)  # Variance 10%
```

#### DamageNumber Spawning

```gdscript
_spawn_damage_number(target, damage)
├── damage_number = DamageNumber.new()
├── spawn_pos = target.global_position + Vector3(0, 2, 0)
├── random_offset = Vector3(randf(-0.5,0.5), 0, randf(-0.5,0.5))
├── damage_number.setup(damage, spawn_pos, offset)
└── target.get_parent().add_child(damage_number)
```

---

### 8. AIModule3D

**Fichier :** `scripts/battle/modules/ai_module_3d.gd`  
**Type :** Node  
**Rôle :** Intelligence artificielle pour les ennemis

#### Comportements

```gdscript
enum AIBehavior {
    AGGRESSIVE,  # Attaque prioritaire
    DEFENSIVE,   # Défend positions
    BALANCED,    # Équilibré
    SUPPORT      # Soutien alliés
}
```

#### Exécution Tour IA

```gdscript
execute_enemy_turn()
├── ai_turn_started.emit()
├── enemies = unit_manager.get_alive_enemy_units()
├── enemies.sort_custom(_sort_by_priority)  # Plus proche en premier
├── Pour chaque enemy:
│   ├── await _execute_unit_turn(enemy)
│   └── await timer(0.5s)
└── ai_turn_completed.emit()
```

#### Décision par Unité

```gdscript
_execute_unit_turn(unit)
├── decision = evaluate_unit_action(unit)
│   ├── target = find_best_attack_target(unit)
│   ├── if can_attack(unit, target):
│   │   └── return {action: "attack", target}
│   └── else:
│       └── return {action: "wait", move_to: best_pos}
│
├── if decision.move_to and can_move:
│   └── await movement_module.move_unit(unit, target_pos)
│
└── if decision.action and can_act:
    └── await _execute_ai_action(unit, decision)
```

#### Évaluation de Cible

```gdscript
find_best_attack_target(unit) -> BattleUnit3D
├── Pour chaque player_unit:
│   └── score = _evaluate_target(unit, target)
│       ├── score += (20 - distance) * 10
│       ├── score += (1 - hp_percent) * 100  # Priorité HP bas
│       └── score += (50 - defense) * 2
└── return target avec meilleur score
```

#### Positionnement Tactique

```gdscript
find_position_to_attack(attacker, target) -> Vector2i
├── reachable = movement_module.calculate_reachable_positions()
├── Pour chaque pos:
│   ├── distance = terrain.get_distance(pos, target_pos)
│   ├── if distance <= attack_range: return pos  # Immédiat
│   └── else: track best_pos (distance minimale)
└── return best_pos
```

---

### 9. ObjectiveModule

**Fichier :** `scripts/battle/modules/objective_module.gd`  
**Type :** Node  
**Rôle :** Gestion des objectifs de mission

#### Structure Objectif

```gdscript
var objectives: Dictionary = {}
# objective_id -> {
#     type: "defeat_all_enemies" | "survive_turns" | "reach_position" | "protect_unit",
#     status: "pending" | "completed" | "failed",
#     data: {...},  # Données spécifiques
#     description: String,
#     is_primary: bool
# }
```

#### Types d'Objectifs

**defeat_all_enemies :**
```gdscript
_check_defeat_all() -> bool
└── Vérifie unit_manager.get_alive_enemy_units().is_empty()
```

**survive_turns :**
```gdscript
# Vérifié par BattleMapManager
if current_turn >= required_turns:
    objective_module.complete_objective(obj_id)
```

**reach_position :**
```gdscript
check_position_objectives(unit, pos)
└── if pos == target and unit.is_player_unit:
        _complete_objective(obj_id)
```

**protect_unit :**
```gdscript
_check_unit_alive(unit_id) -> bool
└── if not alive: _fail_objective(obj_id)
```

#### Setup depuis JSON

```gdscript
setup_objectives(data: Dictionary)
├── Pour chaque obj in data.primary:
│   └── objectives[obj_id] = {
│           type, status, data, description,
│           is_primary: true
│       }
└── Pour chaque obj in data.secondary:
    └── objectives[obj_id] = {..., is_primary: false}
```

#### Complétion

```gdscript
_complete_objective(obj_id)
├── objectives[obj_id].status = "completed"
├── objective_completed.emit(obj_id)
└── if are_all_primary_completed():
        all_objectives_completed.emit()
```

---

## SYSTÈMES AVANCÉS

### 10. DuoSystem

**Fichier :** `scripts/systems/duo/duo_system.gd`  
**Type :** Node  
**Rôle :** ⭐ Système critique de formation de duos

#### Configuration

```gdscript
const MAX_DUO_DISTANCE: int = 1  # Adjacence
const DUO_FORMATION_COST: int = 0  # Gratuit
```

#### Structure Duo

```gdscript
class DuoData:
    var duo_id: String  # "unitA_id_unitB_id" (triés)
    var leader: BattleUnit3D
    var support: BattleUnit3D
    var formation_time: float
    var is_active: bool = true
```

#### Formation de Duo

```gdscript
try_form_duo(unit_a, unit_b) -> bool
├── validation = validate_duo_formation(a, b)
│   ├── Unités non nulles ?
│   ├── Unités différentes ?
│   ├── validate_same_team() ?
│   ├── validate_availability() ?  # Pas déjà en duo
│   └── validate_adjacency() ?  # Distance <= 1
│
├── if not valid:
│   └── duo_validation_failed.emit(reason)
│
├── duo = DuoData.new(unit_a, unit_b)
├── active_duos[duo.duo_id] = duo
├── duo_formed.emit(duo_dict)
└── return true
```

#### Validation Adjacence

```gdscript
validate_adjacency(unit_a, unit_b) -> bool
├── if not terrain_module:
│   └── ERROR: TerrainModule non injecté!
├── distance = terrain_module.get_distance(pos_a, pos_b)
└── return distance <= MAX_DUO_DISTANCE
```

**⚠️ Injection de dépendance requise :**

```gdscript
# Dans BattleMapManager3D._initialize_modules()
duo_system.terrain_module = terrain_module
```

#### Rupture de Duo

```gdscript
break_duo(duo_id: String)
├── duo.is_active = false
├── active_duos.erase(duo_id)
└── duo_broken.emit(duo_id)
```

#### Getters

```gdscript
get_duo_for_unit(unit: BattleUnit3D) -> Dictionary
└── Parcourt active_duos, retourne {} si absent

is_unit_in_duo(unit: BattleUnit3D) -> bool
└── return not get_duo_for_unit(unit).is_empty()

get_all_active_duos() -> Array[Dictionary]
└── Retourne tous les duos actifs
```

#### Nettoyage

```gdscript
clear_all_duos()
└── Pour chaque duo_id:
        break_duo(duo_id)
```

---

### 11. RingSystem

**Fichier :** `scripts/systems/ring/ring_system.gd`  
**Type :** Node  
**Rôle :** ⭐ Système critique des anneaux magiques

#### Types d'Anneaux

**Anneau de Matérialisation :**

```gdscript
class MaterializationRing:
    var ring_id: String
    var ring_name: String
    var attack_shape: String  # "line", "cone", "circle", "cross"
    var base_range: int
    var area_size: int
    var description: String
```

**Anneau de Canalisation :**

```gdscript
class ChannelingRing:
    var ring_id: String
    var ring_name: String
    var mana_effect_id: String  # Référence vers mana_effects.json
    var mana_potency: float
    var effect_duration: float
    var description: String
```

#### Profil d'Attaque Combiné

```gdscript
class AttackProfile:
    var shape: String        # De MaterializationRing
    var range: int
    var area: int
    var mana_effect: String  # De ChannelingRing
    var potency: float
    var duration: float
```

#### Chargement depuis JSON

```gdscript
load_rings_from_json("res://data/ring/rings.json") -> bool
├── data = json_loader.load_json_file(path)
├── Pour ring_data in data.materialization_rings:
│   └── materialization_rings[ring_id] = MaterializationRing.new()
├── Pour ring_data in data.channeling_rings:
│   └── channeling_rings[ring_id] = ChannelingRing.new()
└── rings_loaded.emit(total_count)
```

**Format JSON attendu :**

```json
{
  "materialization_rings": [
    {
      "ring_id": "mat_basic_line",
      "ring_name": "Lame Basique",
      "attack_shape": "line",
      "base_range": 2,
      "area_size": 1,
      "description": "..."
    }
  ],
  "channeling_rings": [
    {
      "ring_id": "chan_fire",
      "ring_name": "Flamme Élémentaire",
      "mana_effect_id": "fire_burn",
      "mana_potency": 1.5,
      "effect_duration": 3.0,
      "description": "..."
    }
  ]
}
```

#### Génération de Profil

```gdscript
generate_attack_profile(mat_ring_id, chan_ring_id) -> AttackProfile
├── mat_ring = get_materialization_ring(mat_ring_id)
├── chan_ring = get_channeling_ring(chan_ring_id)
├── profile = AttackProfile.new()
│   ├── profile.shape = mat_ring.attack_shape
│   ├── profile.range = mat_ring.base_range
│   ├── profile.area = mat_ring.area_size
│   ├── profile.mana_effect = chan_ring.mana_effect_id
│   ├── profile.potency = chan_ring.mana_potency
│   └── profile.duration = chan_ring.effect_duration
└── attack_profile_generated.emit(profile)
```

#### Équipement (temporaire)

```gdscript
var unit_equipment: Dictionary = {}  # unit_id -> {"mat": ring_id, "chan": ring_id}

equip_materialization_ring(unit_id, ring_id) -> bool
equip_channeling_ring(unit_id, ring_id) -> bool
get_unit_rings(unit_id) -> Dictionary
```

---

### 12. Command Pattern

**Fichiers :**
- `scripts/systems/command/command.gd`
- `scripts/systems/command/command_history.gd`
- `scripts/battle/commands/battle_commands.gd`

#### Pattern Command

**Interface :**

```gdscript
class_name Command extends RefCounted

var is_executed: bool = false
var timestamp: float
var description: String

func execute() -> bool
func undo() -> bool
func _do_execute() -> bool  # À surcharger
func _do_undo() -> bool     # À surcharger
```

#### Exemple : MoveUnitCommand

```gdscript
class_name MoveUnitCommand extends Command

var unit: BattleUnit3D
var from_pos: Vector2i
var to_pos: Vector2i
var unit_manager: UnitManager3D

func _do_execute() -> bool
└── unit_manager.move_unit(unit, to_pos)

func _do_undo() -> bool
└── unit_manager.move_unit(unit, from_pos)
```

#### CommandHistory

```gdscript
class_name CommandHistory extends Node

var history: Array[Command] = []
var current_index: int = -1
var max_history_size: int = 50

execute_command(command: Command) -> bool
├── command.execute()
├── if current_index < history.size() - 1:
│   └── history = history.slice(0, current_index + 1)  # Supprime redo
├── history.append(command)
├── current_index += 1
└── command_executed.emit(command)

undo() -> bool
├── if can_undo():
│   ├── command = history[current_index]
│   ├── command.undo()
│   ├── current_index -= 1
│   └── command_undone.emit(command)

redo() -> bool
└── if can_redo():
    ├── current_index += 1
    ├── command = history[current_index]
    └── command.execute()
```

#### Utilisation dans BattleMapManager

```gdscript
# Initialisation
command_history = CommandHistory.new()
add_child(command_history)

# Mouvement avec undo
if movement_valid:
    var cmd = MoveUnitCommand.new(unit, target_pos, unit_manager)
    command_history.execute_command(cmd)

# Bouton Undo
undo_button.pressed.connect(_on_undo_pressed)

func _on_undo_pressed():
    if command_history.can_undo():
        command_history.undo()
```

---

### 13. State Machine

**Fichiers :**
- `scripts/systems/state_machine/state_machine.gd`
- `scripts/systems/state_machine/battle_state_machine.gd`

#### StateMachine (générique)

```gdscript
class_name StateMachine extends Node

var current_state: String = ""
var previous_state: String = ""
var states: Dictionary = {}  # name -> {enter, exit, process}
var transitions: Dictionary = {}  # from -> [allowed_to_states]

add_state(name, enter: Callable, exit: Callable, process: Callable)
add_transition(from: String, to: String)
can_transition(from, to) -> bool
change_state(new_state, force=false) -> bool
```

#### BattleStateMachine

**États :**

```gdscript
enum State {
    INTRO,
    PLAYER_TURN,
    ENEMY_TURN,
    ANIMATION,
    VICTORY,
    DEFEAT
}
```

**Définition :**

```gdscript
func _define_states():
    add_state("INTRO", _on_intro_enter, _on_intro_exit)
    add_state("PLAYER_TURN", _on_player_turn_enter, _on_player_turn_exit, _on_player_turn_process)
    add_state("ENEMY_TURN", _on_enemy_turn_enter, _on_enemy_turn_exit)
    add_state("ANIMATION", _on_animation_enter, _on_animation_exit)
    add_state("VICTORY", _on_victory_enter)
    add_state("DEFEAT", _on_defeat_enter)

func _define_transitions():
    add_transition("INTRO", "PLAYER_TURN")
    add_transition("PLAYER_TURN", "ANIMATION")
    add_transition("PLAYER_TURN", "ENEMY_TURN")
    add_transition("ENEMY_TURN", "ANIMATION")
    # ...
```

**Utilisation :**

```gdscript
# Initialisation
battle_state_machine = BattleStateMachine.new()
add_child(battle_state_machine)

# Changement de phase
change_phase(new_phase: TurnPhase)
└── var state_name = TurnPhase.keys()[new_phase]
    battle_state_machine.change_state(state_name)

# Connexion signal
battle_state_machine.state_changed.connect(_on_battle_state_changed)
```

---

## MANAGERS CRITIQUES

### 14. BattleDataManager

**Fichier :** `scripts/managers/battle_data_manager.gd`  
**Type :** Autoload  
**Rôle :** ⭐ Stockage thread-safe des données de combat

#### Responsabilités

1. **Stockage** : Conserver données combat actuel
2. **Validation** : Vérifier structure avec BattleDataValidator
3. **Thread-safe** : Accès sécurisé entre scènes
4. **Nettoyage** : Auto-cleanup après combat

#### Structure de Données

```gdscript
var _current_battle_data: Dictionary = {}
var _is_data_valid: bool = false
var _battle_id: String = ""
```

#### Stockage

```gdscript
set_battle_data(data: Dictionary) -> bool
├── validator = BattleDataValidator.new()
├── result = validator.validate_battle_data(data)
├── if not result.is_valid:
│   ├── GameRoot.global_logger.error("BATTLE_DATA", errors)
│   └── battle_data_invalid.emit(errors)
├── _current_battle_data = data.duplicate(true)
├── _is_data_valid = true
├── _battle_id = data.get("battle_id", "unknown_XXX")
├── battle_data_stored.emit(_battle_id)
└── return true
```

#### Récupération

```gdscript
get_battle_data() -> Dictionary
├── if not _is_data_valid:
│   └── push_warning("Aucune donnée valide")
└── return _current_battle_data.duplicate(true)

has_battle_data() -> bool
└── return _is_data_valid and not _current_battle_data.is_empty()
```

#### Nettoyage Automatique

```gdscript
func _ready():
    GameRoot.event_bus.safe_connect("battle_ended", _on_battle_ended)

func _on_battle_ended(_results: Dictionary):
    clear_battle_data()

clear_battle_data()
├── _current_battle_data.clear()
├── _is_data_valid = false
├── _battle_id = ""
└── battle_data_cleared.emit()
```

#### Normalisation

```gdscript
_normalize_battle_data(data: Dictionary)
├── Pour unit in player_units + enemy_units:
│   ├── unit.current_hp = int(current_hp)
│   ├── unit.max_hp = int(max_hp)
│   └── if position is Array:
│           unit.position = Vector2i(pos[0], pos[1])
└── Pour obstacle in terrain_obstacles:
    └── obstacle.position = Vector2i(...)
```

**⚠️ Conversion JSON → Godot :** Les nombres JSON sont toujours `float`, il faut les convertir en `int`.

---

### 15. CampaignManager

**Fichier :** `scripts/managers/campaign_manager.gd`  
**Type :** Node (enfant de GameManager)  
**Rôle :** Gestion de la progression de campagne

#### État de Campagne

```gdscript
var campaign_state: Dictionary = {
    "current_chapter": 1,
    "current_battle": 1,
    "battles_won": 0
}
```

#### Chemins des Combats

```gdscript
const BATTLE_DATA_PATHS: Dictionary = {
    "tutorial": "res://data/battles/tutorial.json",
    "forest_battle": "res://data/battles/forest_battle.json",
    "village_defense": "res://data/battles/village_defense.json",
    "boss_fight": "res://data/battles/boss_fight.json"
}
```

#### Démarrage de Combat

```gdscript
start_battle(battle_id: String)
├── battle_data = load_battle_data_from_json(battle_id)
│   ├── json_loader.load_json_file(BATTLE_DATA_PATHS[id])
│   └── _convert_json_positions(data)  # Array → Vector2i
│
├── battle_data = _merge_player_team(battle_data)
│   ├── team = TeamManager.get_current_team()
│   ├── team_units = _convert_team_unit_to_battle(unit, index)
│   └── Décale alliés scénario, ajoute team au début
│
├── battle_data["battle_id"] = battle_id + "_" + timestamp
├── BattleDataManager.set_battle_data(battle_data)
└── GameRoot.event_bus.change_scene(BATTLE)
```

#### Merge Équipe Joueur

```gdscript
_merge_player_team(battle_data) -> Dictionary
├── team = TeamManager.get_current_team()
├── Pour chaque unit in team:
│   └── battle_unit = _convert_team_unit_to_battle(unit, index)
│       └── {
│               id, name,
│               position: Vector2i(2, 6 + index),
│               stats, abilities, color,
│               level, xp, current_hp
│           }
├── Décaler alliés scénario (position.x += 2)
└── Insérer team au début de player_units
```

#### Progression

```gdscript
start_new_campaign()
├── campaign_data = _load_campaign_start_from_json()
├── campaign_state = {
│       current_chapter: data.initial_state.chapter,
│       current_battle: data.initial_state.battle_index,
│       battles_won: 0
│   }
└── GameRoot.event_bus.campaign_started.emit()

_on_battle_ended(results)
├── if results.victory:
│   ├── campaign_state.battles_won += 1
│   └── _advance_campaign()
│       └── campaign_state.current_battle += 1
```

---

### 16. TeamManager

**Fichier :** `scripts/managers/team_manager.gd`  
**Type :** Autoload  
**Rôle :** Gestion du roster et de l'équipe du joueur

#### Configuration

```gdscript
const MAX_TEAM_SIZE: int = 8  # Roster complet
const TEAM_SAVE_PATH: String = "user://team_data.json"
const AVAILABLE_UNITS_PATH: String = "res://data/team/available_units.json"
```

#### Structure

```gdscript
var current_team: Array[Dictionary] = []  # Max 4 en combat
var roster: Array[Dictionary] = []  # Toutes unités recrutées (max 8)
var available_units: Dictionary = {}  # Templates recrutables
```

#### Gestion Équipe

```gdscript
add_to_team(unit_data: Dictionary) -> bool
├── if current_team.size() >= 4:
│   └── return false (équipe complète)
├── current_team.append(unit_data)
├── team_changed.emit()
└── _save_team()

remove_from_team(unit_id: String) -> bool
├── Recherche unit dans current_team
├── current_team.remove_at(index)
└── _save_team()
```

#### Recrutement

```gdscript
recruit_unit(unit_id: String) -> bool
├── if roster.size() >= MAX_TEAM_SIZE:
│   └── return false
├── if déjà recruté:
│   └── return false
├── unit_template = available_units[unit_id]
├── new_unit = _create_unit_instance(template)
│   └── {
│           ...template.duplicate(),
│           instance_id: unique_id,
│           level: 1,
│           xp: 0,
│           current_hp: stats.hp
│       }
├── roster.append(new_unit)
└── unit_recruited.emit(unit_id)
```

#### Système XP & Level Up

```gdscript
add_xp(unit_id: String, xp_amount: int)
├── unit.xp += xp_amount
├── xp_needed = _calculate_xp_for_level(level + 1)
│   └── return 100 * level  # Formule simple
└── if unit.xp >= xp_needed:
        _level_up(unit)

_level_up(unit: Dictionary)
├── unit.level += 1
├── unit.xp = 0
├── stats.hp *= 1.1
├── stats.attack *= 1.1
├── stats.defense *= 1.1
├── unit_leveled_up.emit(unit_id, level)
└── _save_team()
```

#### Sauvegarde/Chargement

```gdscript
_save_team()
├── save_data = {
│       current_team,
│       roster,
│       timestamp
│   }
└── FileAccess.write(JSON.stringify(save_data))

_load_team_from_save()
├── if not exists:
│   └── _create_default_team()
│       ├── recruit_unit("starter_knight")
│       └── recruit_unit("starter_mage")
└── else:
    └── Parse JSON et charger current_team + roster
```

---

## DATA LOADERS & VALIDATION

### 17. JSONDataLoader

**Fichier :** `scripts/data/loaders/json_data_loader.gd`  
**Type :** Class  
**Rôle :** Chargeur JSON générique avec cache

#### API

```gdscript
load_json_file(file_path: String, use_cache: bool = true) -> Variant
├── if use_cache and _cache.has(path):
│   └── return _cache[path]
├── FileAccess.open(path, READ)
├── json_string = file.get_as_text()
├── json = JSON.new()
├── json.parse(json_string)
├── if use_cache: _cache[path] = data
└── return data

load_json_directory(dir_path: String, recursive: bool) -> Dictionary
├── DirAccess.open(dir_path)
├── Pour chaque fichier .json:
│   └── result[key] = load_json_file(path)
└── Si recursive: descendre dans sous-dossiers
```

#### Validation

```gdscript
validate_schema(data: Dictionary, required_fields: Array) -> bool
└── Pour field in required_fields:
        if not data.has(field): return false

load_validated_json(path, required_fields) -> Variant
├── data = load_json_file(path)
└── if not validate_schema(data, required): return null
```

#### Cache

```gdscript
var _cache: Dictionary = {}

clear_cache(file_path: String = "")
├── if file_path.is_empty():
│   └── _cache.clear()  # Tout
└── else:
    └── _cache.erase(file_path)  # Fichier spécifique
```

---

### 18. Validation System

**Fichiers :**
- `scripts/data/validation/validator.gd` (générique)
- `scripts/data/validation/battle_data_validator.gd` (spécialisé)
- `scripts/data/validation/validation.gd` (DataValidationModule)

#### Validator (générique)

```gdscript
class_name Validator extends Node

class ValidationRule:
    var field_name: String
    var type: int  # TYPE_INT, TYPE_STRING, ...
    var required: bool = true
    var min_value: Variant = null
    var max_value: Variant = null
    var allowed_values: Array = []
    var custom_validator: Callable

class ValidationResult:
    var is_valid: bool = true
    var errors: Array[String] = []

add_rule(rule: ValidationRule)
validate(data: Dictionary) -> ValidationResult
```

#### BattleDataValidator

```gdscript
class_name BattleDataValidator extends Validator

func _init():
    add_rule(ValidationRule.new("name", TYPE_STRING, true))
    add_rule(ValidationRule.new("current_hp", TYPE_INT, true))
    add_rule(ValidationRule.new("max_hp", TYPE_INT, true))
    add_rule(ValidationRule.new("position", TYPE_VECTOR2I, true))

validate_battle_data(battle_data: Dictionary) -> ValidationResult
├── result = ValidationResult.new()
├── Pour unit in player_units:
│   ├── unit_data = _normalize_unit_data(unit)  # float → int
│   ├── unit_result = validate(unit_data)
│   └── if not valid: result.add_error()
└── Pour unit in enemy_units: (même chose)
```

**⚠️ Normalisation critique :**

```gdscript
_normalize_unit_data(unit_data: Dictionary) -> Dictionary
├── if typeof(current_hp) == TYPE_FLOAT:
│   └── current_hp = int(current_hp)
├── if typeof(max_hp) == TYPE_FLOAT:
│   └── max_hp = int(max_hp)
└── if stats has floats:
    └── Convertir en int
```

#### DataValidationModule

**Fichier :** `scripts/data/validation/validation.gd`  
**Rôle :** Valide toutes les données critiques au démarrage

```gdscript
const DATA_PATHS = {
    "rings": "res://data/ring/rings.json",
    "mana_effects": "res://data/mana_effects.json",
    "units": "res://data/team/available_units.json"
}

validate_all_data() -> ValidationReport
├── _validate_rings_file(report)
│   ├── Charge rings.json
│   ├── validate_rings(materialization_rings)
│   └── validate_rings(channeling_rings)
├── _validate_mana_effects_file(report)
└── _validate_units_file(report)
```

**ValidationReport :**

```gdscript
class ValidationReport:
    var is_valid: bool = true
    var errors: Array[String] = []
    var warnings: Array[String] = []
    var validated_files: Array[String] = []
```

---

### 19. Loaders Spécialisés

#### DialogueDataLoader

```gdscript
load_dialogue(dialogue_id: String) -> Dictionary
├── file_path = DIALOGUES_DIR + dialogue_id + ".json"
├── data = json_loader.load_json_file(file_path)
├── dialogues[dialogue_id] = data  # Cache
└── return data
```

#### BattleDataLoader (implicite via CampaignManager)

```gdscript
load_battle_data_from_json(battle_id: String) -> Dictionary
├── json_path = BATTLE_DATA_PATHS[battle_id]
├── battle_data = json_loader.load_json_file(json_path)
└── return _convert_json_positions(battle_data)
```

#### WorldMapDataLoader

```gdscript
static func load_world_map_data(map_id: String) -> Dictionary
├── json_path = WORLD_MAP_PATH + map_id + ".json"
├── raw_data = json_loader.load_json_file(json_path)
└── return _convert_map_positions(raw_data)

static func get_unlocked_locations(current_step: int) -> Array
└── Filter locations où unlocked_at_step <= current_step
```

---

## PATTERNS & UTILITAIRES

### 20. GlobalLogger

**Fichier :** `scripts/systems/logging/GameRoot.global_logger.gd`  
**Type :** Autoload  
**Rôle :** Système de logs avec niveaux et catégories

#### Niveaux de Log

```gdscript
enum LogLevel {
    DEBUG,    # Détails développement
    INFO,     # Informations générales
    WARNING,  # Avertissements
    ERROR,    # Erreurs récupérables
    CRITICAL  # Erreurs critiques
}
```

#### Configuration

```gdscript
var current_log_level: LogLevel = DEBUG
var enabled_categories: Array[String] = []  # Vide = toutes
var log_to_file: bool = true
var log_to_console: bool = true

const LOG_FILE_PATH = "user://logs/game.log"
const MAX_LOG_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
```

#### API

```gdscript
debug(category: String, message: String)
info(category: String, message: String)
warning(category: String, message: String)
error(category: String, message: String)
critical(category: String, message: String)
```

#### Format

```
[TIMESTAMP][LEVEL][CATEGORY] Message
[2026-01-29 16:45:12][INFO][BATTLE] Combat démarré
[2026-01-29 16:45:15][ERROR][DATA] Fichier introuvable: battle.json
```

#### Rotation Logs

```gdscript
_open_log_file()
├── if file_exists and size > MAX_LOG_FILE_SIZE:
│   └── _rotate_log_file()
│       └── DirAccess.rename(path, path + "_TIMESTAMP.log")
└── FileAccess.open(LOG_FILE_PATH, READ_WRITE)
```

---

### 21. DebugOverlay

**Fichier :** `scripts/systems/debug/debug_overlay.gd`  
**Type :** CanvasLayer (Autoload)  
**Rôle :** Interface de debug en jeu (F3)

#### Composition

```
DebugOverlay (CanvasLayer, layer=100)
└── PanelContainer
    └── ScrollContainer
        └── RichTextLabel (BBCode)
```

#### Variables Surveillées

```gdscript
var watched_variables: Dictionary = {}
# key -> { object: Node, property: String }

watch_variable(key: String, object: Node, property: String)
└── watched_variables[key] = {object, property}

# Mise à jour automatique dans _process()
_update_display()
└── Pour key in watched_variables:
        if is_instance_valid(obj):
            value = obj.get(property)
            text += "[cyan]%s:[/cyan] %s\n" % [key, value]
```

#### Affichage

**Sections :**

1. **Performance** : FPS, Mémoire
2. **Variables Surveillées** : Variables custom
3. **GameManager** : Scène actuelle, Loading
4. **EventBus** : Signaux actifs (TODO)
5. **Combat** : Phase, Tour, Unités (si en combat)

#### Toggle

```gdscript
func _input(event):
    if event.is_action_pressed("debug_toggle"):  # F3
        toggle_visibility()
```

---

### 22. JSONScenarioModule

**Fichier :** `scripts/narrative/json_scenario_module.gd`  
**Type :** Node  
**Rôle :** Scénarios de combat en JSON (remplace Lua)

#### Structure Scenario JSON

```json
{
  "intro_dialogue": [
    {"speaker": "Commander", "text": "Préparez-vous!"},
    {"speaker": "Hero", "text": "En position!"}
  ],
  "turn_events": {
    "turn_2": {
      "type": "dialogue",
      "dialogue": [...]
    }
  },
  "position_events": {
    "10,5": {
      "type": "spawn_units",
      "units": [...]
    }
  },
  "outro_victory": [...],
  "outro_defeat": [...]
}
```

#### Setup

```gdscript
setup_scenario(scenario_path: String)
├── scenario_data = json_loader.load_json_file(path)
└── print("Scénario chargé")
```

#### Triggers

```gdscript
trigger_turn_event(turn: int, is_player: bool)
├── turn_key = "turn_" + str(turn)
├── if scenario_data.turn_events.has(turn_key):
│   └── await _execute_json_event(event_data)

trigger_position_event(unit: BattleUnit3D, pos: Vector2i)
├── pos_key = str(pos.x) + "," + str(pos.y)
└── if scenario_data.position_events.has(pos_key):
        await _execute_json_event(event_data)
```

#### Exécution Événement

```gdscript
_execute_json_event(event_data: Dictionary)
├── match event_data.type:
│   "dialogue" → _play_json_dialogue(lines)
│   "spawn_units" → GameRoot.event_bus.emit("units_spawn_requested")
│   "trigger_cutscene" → GameRoot.event_bus.emit("cutscene_requested")

_play_json_dialogue(dialogue_lines: Array)
├── dialogue_data = DialogueData.new(id)
├── Pour line in lines:
│   └── dialogue_data.add_line(speaker, text)
├── Dialogue_Manager.start_dialogue(dialogue_data, dialogue_box)
└── await Dialogue_Manager.dialogue_ended
```

---

## CONFIGURATION PROJET

### project.godot (extraits pertinents)

**Autoloads combat/data :**

```ini
[autoload]
EventBus="*res://scripts/autoloads/event_bus.gd"
GameManager="*res://scripts/autoloads/game_manager.gd"
Dialogue_Manager="*res://scripts/managers/dialogue_manager.gd"
BattleDataManager="*res://scripts/managers/battle_data_manager.gd"
GlobalLogger="*res://scripts/systems/logging/GameRoot.global_logger.gd"
DebugOverlay="*res://scripts/systems/debug/debug_overlay.gd"
Version_Manager="*res://scripts/systems/versioning/version_manager.gd"
TeamManager="*res://scripts/managers/team_manager.gd"
```

**Inputs combat :**

```ini
[input]
ui_home={events=[...Key(A)]}  # Rotation caméra gauche
ui_end={events=[...Key(E)]}   # Rotation caméra droite
debug_toggle={events=[...Key(F3)]}  # Debug overlay
```

---

## POINTS D'ATTENTION

### ⚠️ Conversions JSON → Godot

**Problème :** Godot parse tous les nombres JSON en `float`

**Solutions :**

1. **HP & Stats :**
```gdscript
unit.current_hp = int(unit.current_hp)
unit.max_hp = int(unit.max_hp)
```

2. **Positions :**
```gdscript
if unit.position is Array:
    unit.position = Vector2i(int(pos[0]), int(pos[1]))
```

3. **Normalisation systématique :**
```gdscript
BattleDataValidator._normalize_unit_data(unit)
```

### ⚠️ Initialisation BattleUnit3D

**Ordre critique pour éviter division par zéro :**

```gdscript
# ✅ BON
temp_max_hp = data.stats.hp
temp_current_hp = data.hp
max_hp = temp_max_hp
current_hp = temp_current_hp or max_hp

# ❌ MAUVAIS
current_hp = data.hp
max_hp = data.stats.hp  # Trop tard, division déjà faite
```

### ⚠️ Injection de Dépendances

**DuoSystem REQUIERT terrain_module :**

```gdscript
# Dans BattleMapManager3D
duo_system.terrain_module = terrain_module
```

**Sans ça :** `validate_adjacency()` échoue.

### ⚠️ Material HP Bar

**Configuration critique pour éviter transparence :**

```gdscript
material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
material.no_depth_test = false
material.cull_mode = BaseMaterial3D.CULL_DISABLED
hp_bar_3d.sorting_offset = 0.1
```

### ⚠️ Collision Layers

**Convention :**
- Layer 1 : Terrain (StaticBody3D)
- Layer 2 : Unités (Area3D)
- Layer 3 : (réservé)

**Raycasting :**

```gdscript
query.collision_mask = 3  # Layers 1 et 2
query.collide_with_areas = true
```

### ⚠️ Torus Visibility

**Le torus est TOUJOURS visible :**

```gdscript
selection_indicator.visible = true  # Ne jamais mettre à false
_apply_torus_color()  # Changer la couleur selon l'état
```

### ⚠️ Auto-Advance Dialogue

**DialogueBox gère l'input, PAS Dialogue_Manager :**

```gdscript
# ❌ NE PAS faire dans Dialogue_Manager:
# func _input(event): advance_dialogue()

# ✅ Faire dans DialogueBox:
func _input(event):
    if is_visible and event.is_action_pressed("dialogue_advance"):
        _on_advance_requested()
```

---

## DÉPENDANCES INTER-SYSTÈMES

### Hiérarchie de Dépendances

```
EventBus (base)
└── BattleDataManager
    └── CampaignManager
        └── TeamManager
            └── BattleMapManager3D
                ├── TerrainModule3D
                ├── UnitManager3D
                │   └── BattleUnit3D
                ├── MovementModule3D
                ├── ActionModule3D
                ├── AIModule3D
                ├── ObjectiveModule
                ├── DuoSystem (REQUIERT terrain_module)
                ├── RingSystem
                ├── CommandHistory
                ├── BattleStateMachine
                └── JSONScenarioModule
```

### Flow de Démarrage Combat

```
1. User clique "Nouvelle Partie"
2. GameRoot.game_manager._on_game_started()
3. CampaignManager.start_new_campaign()
4. CampaignManager.start_battle("tutorial")
   ├── load_battle_data_from_json()
   ├── _merge_player_team()  ← TeamManager.get_current_team()
   └── BattleDataManager.set_battle_data()
5. GameRoot.event_bus.change_scene(BATTLE)
6. BattleMapManager3D._ready()
   ├── await _initialize_modules()
   └── if BattleDataManager.has_battle_data():
           initialize_battle(data)
```

### Signaux Critiques

**Combat :**

```gdscript
GameRoot.event_bus.battle_started(battle_id)
├── BattleMapManager3D écoute
└── Stats tracking démarre

GameRoot.event_bus.battle_ended(results)
├── CampaignManager._on_battle_ended()
├── BattleDataManager.clear_battle_data()
└── GameRoot.event_bus.change_scene(BATTLE_RESULTS)
```

**Duo :**

```gdscript
DuoSystem.duo_formed(duo_data)
└── BattleMapManager3D._on_duo_formed()
    └── GameRoot.event_bus.notify("Duo formé!")

DuoSystem.duo_broken(duo_id)
└── ActionModule3D nettoie références
```

---

## CHECKLIST DEBUG COMBAT

### Si combat ne démarre pas :

1. **BattleDataManager a des données ?**
   ```gdscript
   print(BattleDataManager.has_battle_data())
   print(BattleDataManager.get_battle_stats())
   ```

2. **Validation données réussie ?**
   ```gdscript
   # Regarder logs GlobalLogger
   GameRoot.global_logger.error("BATTLE_DATA", ...)
   ```

3. **Unités spawnées ?**
   ```gdscript
   print(unit_manager.get_all_units().size())
   ```

4. **Terrain chargé ?**
   ```gdscript
   print(terrain_module.grid[0][0])  # Doit retourner TileType
   ```

### Si sélection unité ne marche pas :

1. **Raycasting fonctionne ?**
   ```gdscript
   # Activer debug physics (Project Settings)
   # Vérifier collision_layer = 2 sur Area3D
   ```

2. **Métadonnée présente ?**
   ```gdscript
   print(area.has_meta("unit"))
   ```

3. **Input activé ?**
   ```gdscript
   print(set_process_input)  # Doit être true pendant tour joueur
   ```

### Si duo ne se forme pas :

1. **TerrainModule injecté ?**
   ```gdscript
   print(duo_system.terrain_module != null)
   ```

2. **Distance OK ?**
   ```gdscript
   var dist = terrain.get_distance(pos_a, pos_b)
   print("Distance:", dist, "Max:", DuoSystem.MAX_DUO_DISTANCE)
   ```

3. **Unités déjà en duo ?**
   ```gdscript
   print(duo_system.is_unit_in_duo(unit_a))
   ```

### Si HP bar invisible :

1. **Materials configurés ?**
   ```gdscript
   var mat = hp_bar_3d.get_surface_override_material(0)
   print(mat.transparency)  # Doit être DISABLED
   ```

2. **Billboard fonctionne ?**
   ```gdscript
   # Vérifier _process() copie rotation caméra
   ```

3. **Z-fighting ?**
   ```gdscript
   print(hp_bar_3d.position.z)  # Doit être > 0
   print(hp_bar_3d.sorting_offset)  # Doit être > 0
   ```

---

## CONCLUSION PARTIE 2

Cette partie a documenté :

✅ **Système de combat 3D complet** (BattleMapManager3D, BattleUnit3D)  
✅ **7 modules de combat** (Terrain, Units, Movement, Action, AI, Objectives, Scenario)  
✅ **4 systèmes avancés** (Duo, Rings, Command, StateMachine)  
✅ **3 managers critiques** (BattleData, Campaign, Team)  
✅ **Infrastructure data** (Loaders, Validation, Logging)

**Points clés à retenir :**

1. **Conversions JSON** : Toujours convertir `float` → `int` et `Array` → `Vector2i`
2. **Injection dépendances** : DuoSystem requiert `terrain_module`
3. **Ordre initialisation** : `max_hp` avant `current_hp` dans BattleUnit3D
4. **Materials HP bar** : `TRANSPARENCY_DISABLED` + `sorting_offset`
5. **Torus toujours visible** : Changer couleur, pas `visible`

**Systèmes non couverts (futures parties) :**

- Inventaire & Équipement détaillé
- Système de capacités (abilities)
- Système de progression (skills trees)
- VFX & Audio (particules, sons)
- UI avancée (HUD dynamique)
- Sauvegarde persistante
- Networking/Multiplayer (si applicable)

**Fichier créé :** `/home/claude/ARCHITECTURE_PART2.md`

---

**Navigation :**
- [← PART1 : UI, Dialogues, World Map](./ARCHITECTURE_PART1.md)
- [PART2 : Combat & Modules] (ce fichier)
- [→ PART3 : À venir] (capacités, inventaire, VFX)

# ARCHITECTURE_PART3.md - Formats de Données & Systèmes Finaux

**Tactical RPG Duos - Godot 4.5**  
**Date:** 2026-01-29  
**Partie:** 3/3 (Formats JSON, Items, Localisation, Schémas Finaux)

---

## TABLE DES MATIÈRES

1. [Vue d'ensemble](#vue-densemble)
2. [Système d'Items & Inventaire](#système-ditems--inventaire)
3. [Système d'Abilities](#système-dabilities)
4. [Système d'Ennemis](#système-dennemis)
5. [Formats de Données de Combat](#formats-de-données-de-combat)
6. [Système de Campaign](#système-de-campaign)
7. [Système de Locations & Maps](#système-de-locations--maps)
8. [Système de Mana & Effets](#système-de-mana--effets)
9. [Système de Localisation](#système-de-localisation)
10. [Schémas de Validation](#schémas-de-validation)
11. [Checklist d'Intégration](#checklist-dintégration)
12. [Index Global des Systèmes](#index-global-des-systèmes)

---

## VUE D'ENSEMBLE

### Architecture des Données

```
data/
├── abilities/           # Capacités (fireball.json, heal.json, ...)
├── battles/            # Données de combat (tutorial.json, boss_fight.json, ...)
├── campaign/           # Progression campagne (campaign_start.json)
├── dialogues/          # Dialogues (intro_prologue.json, village_elder.json)
├── enemies/            # Templates ennemis (goblin_warrior.json, ...)
├── items/
│   ├── consumables/    # Potions, scrolls
│   └── weapons/        # Armes, armures
├── mana/              # Effets de mana (mana_effects.json)
├── maps/
│   ├── locations/      # Détails locations (starting_village.json, ...)
│   ├── overworld.json  # Carte générale (legacy)
│   └── world_map_data.json  # Données world map
├── ring/              # Anneaux duo (rings.json)
├── scenarios/         # Scénarios combat (tutorial_scenario.json)
└── team/              # Unités recrutables (available_units.json)

localization/
└── dialogues.csv      # Traductions (en, fr, es)
```

### Loaders Disponibles

```gdscript
JSONDataLoader          # Chargeur générique
AbilityDataLoader      # Charge abilities/
DialogueDataLoader     # Charge dialogues/
EnemyDataLoader        # Charge enemies/
ItemDataLoader         # Charge items/ (récursif)
WorldMapDataLoader     # Charge maps/
```

---

## SYSTÈME D'ITEMS & INVENTAIRE

### Structure Item Générique

**Champs communs (tous items) :**

```json
{
  "id": "unique_item_id",
  "name": "Nom affiché",
  "description": "Description détaillée",
  "category": "weapon|armor|consumable|misc",
  "subcategory": "sword|potion|helmet|...",
  "rarity": "common|uncommon|rare|epic|legendary",
  "value": 150,           // Prix de vente (achat = value * 2)
  "weight": 3.5,
  "stackable": true|false,
  "max_stack": 99,
  "icon": "res://path/to/icon.png"
}
```

### Items Consommables

**Fichier :** `data/items/consumables/health_potion.json`

```json
{
  "id": "health_potion",
  "name": "Potion de vie",
  "description": "Restaure 50 PV",
  "category": "consumable",
  "subcategory": "potion",
  "rarity": "common",
  "value": 25,
  "weight": 0.2,
  "stackable": true,
  "max_stack": 99,
  "usable_in_combat": true,
  "usable_in_field": true,
  "effects": [
    {
      "type": "heal",
      "target": "self",
      "value": 50,
      "is_percentage": false
    }
  ],
  "use_animation": "res://animations/items/use_potion.tres",
  "icon": "res://assets/icons/items/health_potion.png"
}
```

**Champs spécifiques consommables :**

- `usable_in_combat` : Utilisable en combat
- `usable_in_field` : Utilisable hors combat
- `effects[]` : Liste d'effets
  - `type` : "heal", "damage", "buff", "debuff", "cleanse"
  - `target` : "self", "ally", "enemy", "all_allies", "all_enemies"
  - `value` : Valeur numérique
  - `is_percentage` : Si true, value en %

**Types d'effets :**

```gdscript
# Heal
{"type": "heal", "target": "self", "value": 50}

# Buff temporaire
{"type": "buff", "stat": "attack", "value": 10, "duration": 3}

# Cleanse (retirer statut)
{"type": "cleanse", "status": "poison"}

# Resurrection
{"type": "revive", "target": "ally", "hp_percent": 0.5}
```

### Items Équipables

**Fichier :** `data/items/weapons/iron_sword.json`

```json
{
  "id": "iron_sword",
  "name": "Épée en fer",
  "description": "Une épée solide en fer forgé",
  "category": "weapon",
  "subcategory": "sword",
  "rarity": "common",
  "value": 150,
  "weight": 3.5,
  "stackable": false,
  "max_stack": 1,
  "equippable": true,
  "equipment_slot": "main_hand",
  "stats": {
    "attack": 15,
    "strength": 2
  },
  "requirements": {
    "level": 5,
    "strength": 10
  },
  "effects": [],
  "icon": "res://assets/icons/items/iron_sword.png",
  "model": "res://assets/models/items/iron_sword.glb"
}
```

**Champs spécifiques équipables :**

- `equippable` : true
- `equipment_slot` : 
  - Armes : "main_hand", "off_hand", "two_hand"
  - Armures : "head", "chest", "legs", "feet", "hands"
  - Accessoires : "ring", "necklace", "accessory"
- `stats{}` : Bonus de stats
- `requirements{}` : Prérequis d'équipement
- `effects[]` : Effets passifs (regen, thorns, ...)
- `model` : Modèle 3D (pour affichage équipement)

**Slots d'équipement :**

```
main_hand     # Arme principale
off_hand      # Bouclier/Arme secondaire
two_hand      # Arme à 2 mains (occupe main_hand + off_hand)
head          # Casque
chest         # Armure
legs          # Jambières
feet          # Bottes
hands         # Gants
ring_1        # Anneau 1
ring_2        # Anneau 2
necklace      # Collier
accessory     # Accessoire spécial
```

### ItemDataLoader

**Fichier :** `scripts/data/loaders/item_data_loader.gd`

#### Chargement Récursif

```gdscript
const ITEMS_DIR = "res://data/items/"

var items: Dictionary = {}
var items_by_category: Dictionary = {}

func load_all_items():
    # Charge récursivement tous les .json
    items = _json_loader.load_json_directory(ITEMS_DIR, true)
    _organize_by_category()

func _organize_by_category():
    # Aplatit la hiérarchie de dossiers
    _flatten_items(items, items_by_category)
```

#### API

```gdscript
get_item(item_id: String) -> Dictionary
get_items_by_category(category: String) -> Array
```

**Exemple d'utilisation :**

```gdscript
# Chargement
var item_loader = ItemDataLoader.new()
item_loader.load_all_items()

# Récupération
var potion = item_loader.get_item("health_potion")
var all_weapons = item_loader.get_items_by_category("weapon")
```

### Système d'Inventaire (à implémenter)

**Structure proposée :**

```gdscript
class_name InventorySystem extends Node

var items: Dictionary = {}  # item_id -> quantity
var equipped: Dictionary = {}  # slot -> item_id
var max_weight: float = 100.0
var current_weight: float = 0.0

func add_item(item_id: String, quantity: int = 1) -> bool
func remove_item(item_id: String, quantity: int = 1) -> bool
func has_item(item_id: String, quantity: int = 1) -> bool
func get_quantity(item_id: String) -> int

func equip_item(item_id: String, slot: String) -> bool
func unequip_item(slot: String) -> bool
func get_equipped(slot: String) -> String

func use_item(item_id: String, target: BattleUnit3D) -> bool
func calculate_weight() -> float
```

---

## SYSTÈME D'ABILITIES

### Structure Ability

**Fichier :** `data/abilities/fireball.json`

```json
{
  "id": "fireball",
  "name": "Fireball",
  "description": "Launches a ball of fire at the enemy",
  "type": "offensive_magic",
  "cost": {
    "mp": 15,
    "cooldown": 2
  },
  "damage": {
    "base": 40,
    "scaling": "intelligence",
    "multiplier": 1.5
  },
  "range": 4,
  "area_effect": {
    "type": "circle",
    "radius": 1
  },
  "effects": [
    {
      "type": "damage",
      "element": "fire",
      "value": 40
    },
    {
      "type": "status",
      "status_id": "burning",
      "chance": 0.3,
      "duration": 3
    }
  ],
  "animation": "res://animations/abilities/fireball.tres",
  "icon": "res://assets/icons/abilities/fireball.png",
  "sound": "res://audio/sfx/fireball.ogg"
}
```

### Champs Détaillés

**Champs de base :**

```json
{
  "id": "unique_ability_id",
  "name": "Nom affiché",
  "description": "Description complète",
  "type": "offensive_magic|defensive_magic|support|physical|passive"
}
```

**Coûts :**

```json
{
  "cost": {
    "mp": 15,           // Coût en mana
    "hp": 0,            // Coût en HP (rare)
    "cooldown": 2,      // Tours de cooldown
    "charges": 3        // Nombre d'utilisations (optionnel)
  }
}
```

**Dégâts :**

```json
{
  "damage": {
    "base": 40,                    // Dégâts de base
    "scaling": "intelligence",     // Stat de scaling
    "multiplier": 1.5,             // Multiplicateur
    "type": "physical|magical"     // Type de dégâts
  }
}
```

**Portée & Zone :**

```json
{
  "range": 4,                      // Portée en cases
  "area_effect": {
    "type": "single|circle|line|cone|cross",
    "radius": 1,                   // Pour circle
    "length": 3,                   // Pour line/cone
    "width": 2                     // Pour cone
  }
}
```

**Effets :**

```json
{
  "effects": [
    {
      "type": "damage|heal|buff|debuff|status|knockback|teleport",
      "element": "fire|ice|lightning|holy|dark|nature|physical",
      "value": 40,
      "stat": "attack",              // Pour buff/debuff
      "status_id": "burning",        // Pour status
      "chance": 0.3,                 // Probabilité
      "duration": 3                  // Durée en tours
    }
  ]
}
```

**Assets :**

```json
{
  "animation": "res://path/to/animation.tres",
  "icon": "res://path/to/icon.png",
  "sound": "res://path/to/sound.ogg",
  "particle_effect": "res://path/to/particles.tscn"
}
```

### Types d'Abilities

**offensive_magic :**
- Attaques magiques (fireball, ice_storm, lightning_bolt)
- Scaling sur intelligence/magic
- Souvent AOE

**defensive_magic :**
- Boucliers, barrières (shield, ice_barrier)
- Buffs de défense

**support :**
- Soins, buffs d'équipe (heal, bless, haste)
- Peut cibler alliés

**physical :**
- Attaques physiques (heroic_strike, cleave)
- Scaling sur strength/attack

**passive :**
- Effets permanents (counter_attack, regeneration)
- Pas de coût, toujours actif

### AbilityDataLoader

**Fichier :** `scripts/data/loaders/ability_data_loader.gd`

```gdscript
const ABILITIES_DIR = "res://data/abilities/"

var abilities: Dictionary = {}  # ability_id -> ability_data

func load_all_abilities():
    abilities = _json_loader.load_json_directory(ABILITIES_DIR, false)

func get_ability(ability_id: String) -> Dictionary:
    return abilities.get(ability_id, {})

func validate_ability(data: Dictionary) -> bool:
    var required = ["id", "name", "type", "cost"]
    return _json_loader.validate_schema(data, required)
```

### Système d'Abilities (à implémenter)

**Structure proposée :**

```gdscript
class_name AbilitySystem extends Node

var ability_loader: AbilityDataLoader

func can_use_ability(unit: BattleUnit3D, ability_id: String) -> bool:
    var ability = ability_loader.get_ability(ability_id)
    return _check_cost(unit, ability) and _check_cooldown(unit, ability)

func use_ability(caster: BattleUnit3D, ability_id: String, target: BattleUnit3D):
    var ability = ability_loader.get_ability(ability_id)
    
    # Consommer coûts
    _consume_cost(caster, ability)
    
    # Appliquer effets
    for effect in ability.effects:
        _apply_effect(caster, target, effect)
    
    # Lancer animation
    _play_ability_animation(ability)
```

---

## SYSTÈME D'ENNEMIS

### Structure Ennemi

**Fichier :** `data/enemies/goblin_warrior.json`

```json
{
  "id": "goblin_warrior",
  "name": "Goblin Guerrier",
  "description": "Un goblin armé d'une épée rouillée",
  "type": "humanoid",
  "rank": "common",
  "stats": {
    "hp": 50,
    "mp": 10,
    "strength": 12,
    "defense": 8,
    "magic": 3,
    "magic_defense": 5,
    "speed": 15,
    "luck": 5
  },
  "resistances": {
    "physical": 0,
    "fire": -0.5,      // Faible au feu (-50%)
    "ice": 0,
    "lightning": 0,
    "dark": 0.2        // Résistant au dark (+20%)
  },
  "abilities": [
    "goblin_slash",
    "battle_cry"
  ],
  "ai_behavior": "aggressive_melee",
  "loot_table": {
    "gold": {"min": 5, "max": 15},
    "items": [
      {"item_id": "rusty_sword", "chance": 0.15},
      {"item_id": "leather_scraps", "chance": 0.4},
      {"item_id": "health_potion", "chance": 0.25}
    ]
  },
  "experience": 25,
  "sprite": "res://assets/sprites/enemies/goblin_warrior.png",
  "animations": {
    "idle": "res://animations/enemies/goblin_idle.tres",
    "attack": "res://animations/enemies/goblin_attack.tres",
    "hit": "res://animations/enemies/goblin_hit.tres",
    "death": "res://animations/enemies/goblin_death.tres"
  }
}
```

### Champs Détaillés

**Identité :**

```json
{
  "id": "unique_enemy_id",
  "name": "Nom affiché",
  "description": "Description",
  "type": "humanoid|beast|undead|demon|elemental|dragon",
  "rank": "common|elite|boss|miniboss|legendary"
}
```

**Stats :**

Identiques aux unités joueur, plus :
- `mp` : Mana (si utilise magie)
- `luck` : Influence critiques, drops

**Résistances :**

```json
{
  "resistances": {
    "physical": 0,     // 0 = normal
    "fire": -0.5,      // -0.5 = faible (-50% dégâts)
    "ice": 0.2,        // 0.2 = résistant (+20% dégâts)
    "lightning": -1.0, // -1.0 = vulnérable (double dégâts)
    "holy": 0,
    "dark": 1.0        // 1.0 = immunité (0 dégâts)
  }
}
```

**AI Behavior :**

```gdscript
"ai_behavior": 
    "aggressive_melee"    # Attaque au corps-à-corps
    "defensive"           # Défend position
    "ranged_kiter"        # Attaque à distance + fuite
    "support"             # Buff alliés, heal
    "berserker"           # Attaque coûte que coûte
    "tactical"            # Utilise terrain, focus cibles faibles
```

**Loot Table :**

```json
{
  "loot_table": {
    "gold": {
      "min": 5,
      "max": 15
    },
    "items": [
      {
        "item_id": "rusty_sword",
        "chance": 0.15      // 15% de drop
      },
      {
        "item_id": "health_potion",
        "chance": 0.25,
        "quantity_min": 1,
        "quantity_max": 3
      }
    ]
  },
  "experience": 25
}
```

### EnemyDataLoader

**Fichier :** `scripts/data/loaders/enemy_data_loader.gd`

```gdscript
const ENEMIES_DIR = "res://data/enemies/"

var enemies: Dictionary = {}  # enemy_id -> enemy_data

func load_all_enemies():
    enemies = _json_loader.load_json_directory(ENEMIES_DIR, true)

func get_enemy(enemy_id: String) -> Dictionary:
    return enemies.get(enemy_id, {})

func create_enemy_instance(enemy_id: String, level: int = 1) -> Dictionary:
    var base_data = get_enemy(enemy_id).duplicate(true)
    
    # Scaling stats par niveau
    for stat in base_data.stats:
        base_data.stats[stat] = _scale_stat(base_data.stats[stat], level)
    
    base_data["current_level"] = level
    return base_data

func _scale_stat(base_value: float, level: int) -> float:
    # +10% par niveau
    return base_value * (1.0 + (level - 1) * 0.1)
```

---

## FORMATS DE DONNÉES DE COMBAT

### Battle Data (complet)

**Fichier :** `data/battles/tutorial.json`

```json
{
  "battle_id": "tutorial",
  "scenario_file": "res://data/scenarios/tutorial_scenario.json",
  "name": "Combat Tutoriel",
  "description": "Apprenez les bases du combat",
  "terrain": "plains",
  "player_units": [
    {
      "name": "Knight",
      "id": "player_knight_1",
      "position": {"x": 3, "y": 7},
      "stats": {
        "hp": 100,
        "attack": 25,
        "defense": 15,
        "movement": 5,
        "range": 1
      },
      "abilities": ["basic_attack", "shield_bash"],
      "color": {"r": 0.2, "g": 0.6, "b": 0.9, "a": 1.0}
    }
  ],
  "enemy_units": [
    {
      "name": "Goblin Scout",
      "id": "enemy_goblin_1",
      "position": {"x": 15, "y": 7},
      "stats": {
        "hp": 50,
        "attack": 15,
        "defense": 8,
        "movement": 5,
        "range": 1
      },
      "abilities": ["basic_attack"],
      "color": {"r": 0.8, "g": 0.3, "b": 0.3, "a": 1.0}
    }
  ],
  "objectives": {
    "primary": [
      {
        "type": "defeat_all_enemies",
        "description": "Éliminez tous les ennemis"
      }
    ],
    "secondary": [
      {
        "type": "no_units_lost",
        "description": "Ne perdez aucune unité"
      }
    ]
  },
  "scenario": {
    "has_intro": true,
    "intro_dialogue": "tutorial_intro",
    "has_outro": true,
    "outro_victory": "tutorial_victory",
    "outro_defeat": "tutorial_defeat"
  }
}
```

### Champs Détaillés

**Structure de base :**

```json
{
  "battle_id": "unique_battle_id",
  "name": "Nom du combat",
  "description": "Description",
  "terrain": "plains|forest|mountain|castle|desert",
  "grid_size": {
    "width": 20,
    "height": 15
  }
}
```

**Unités :**

Position en objet `{"x": 3, "y": 7}` converti en `Vector2i` par CampaignManager.

```gdscript
# Conversion dans CampaignManager
unit.position = Vector2i(pos.x, pos.y)
```

**Objectifs :**

```json
{
  "objectives": {
    "primary": [
      {"type": "defeat_all_enemies"},
      {"type": "defeat_boss", "unit_id": "boss_id"},
      {"type": "survive_turns", "turns": 10},
      {"type": "reach_position", "position": {"x": 10, "y": 5}},
      {"type": "protect_unit", "unit_id": "vip_id"}
    ],
    "secondary": [
      {"type": "no_units_lost"},
      {"type": "complete_in_turns", "turns": 15}
    ]
  }
}
```

**Scénario :**

```json
{
  "scenario": {
    "has_intro": true,
    "intro_dialogue": "dialogue_id",
    "has_outro": true,
    "outro_victory": "victory_dialogue_id",
    "outro_defeat": "defeat_dialogue_id",
    "special_events": {
      "boss_half_hp": {
        "trigger": "unit_hp_below",
        "unit_id": "boss",
        "threshold": 0.5,
        "action": "summon_reinforcements"
      }
    }
  }
}
```

### Scenario Data

**Fichier :** `data/scenarios/tutorial_scenario.json`

```json
{
  "scenario_id": "tutorial",
  "intro_dialogue": [
    {"speaker": "Instructeur", "text": "Bienvenue !"},
    {"speaker": "Instructeur", "text": "Préparez-vous."}
  ],
  "turn_events": {
    "turn_3": {
      "type": "dialogue",
      "dialogue": [
        {"speaker": "Instructeur", "text": "Bien joué !"}
      ]
    }
  },
  "position_events": {
    "10,10": {
      "type": "dialogue",
      "dialogue": [
        {"speaker": "Système", "text": "Point stratégique !"}
      ]
    }
  },
  "outro_victory": [
    {"speaker": "Instructeur", "text": "Excellent !"}
  ],
  "outro_defeat": [
    {"speaker": "Instructeur", "text": "Réessayez."}
  ]
}
```

**Structure :**

- `intro_dialogue[]` : Dialogue avant combat
- `turn_events{}` : Événements par tour (clé = "turn_N")
- `position_events{}` : Événements par position (clé = "x,y")
- `outro_victory[]` : Dialogue victoire
- `outro_defeat[]` : Dialogue défaite

---

## SYSTÈME DE CAMPAIGN

### Campaign Start

**Fichier :** `data/campaign/campaign_start.json`

```json
{
  "campaign_id": "main_campaign",
  "title": "La Prophétie des Duos",
  "version": "1.0.0",
  "initial_state": {
    "chapter": 1,
    "battle_index": 0,
    "battles_won": 0,
    "unlocked_locations": ["starting_village"],
    "discovered_locations": ["starting_village"],
    "current_location": "starting_village"
  },
  "start_sequence": [
    {
      "type": "dialogue",
      "dialogue_id": "intro_prologue",
      "blocking": true
    },
    {
      "type": "notification",
      "message": "Bienvenue !",
      "duration": 2.5
    },
    {
      "type": "unlock_location",
      "location": "starting_village"
    },
    {
      "type": "transition",
      "target": "world_map",
      "fade_duration": 1.0
    }
  ],
  "chapters": [
    {
      "id": 1,
      "title": "L'Éveil",
      "description": "Le début de votre aventure",
      "battles": [
        {
          "battle_id": "tutorial",
          "required": true,
          "unlock_condition": null
        },
        {
          "battle_id": "forest_battle",
          "required": true,
          "unlock_condition": {
            "type": "battle_completed",
            "battle_id": "tutorial"
          }
        }
      ]
    }
  ],
  "initial_party": {
    "max_size": 4,
    "units": [
      {"unit_id": "knight_hero", "level": 1, "locked": false},
      {"unit_id": "archer_starter", "level": 1, "locked": false}
    ]
  },
  "initial_inventory": {
    "gold": 100,
    "items": [
      {"item_id": "health_potion", "quantity": 3},
      {"item_id": "iron_sword", "quantity": 1}
    ]
  },
  "divine_favor": {
    "astraeon": 0,
    "kharvul": 0
  }
}
```

### Séquence de Démarrage

**Types d'actions :**

```json
{
  "type": "dialogue",
  "dialogue_id": "intro_prologue",
  "blocking": true
}

{
  "type": "notification",
  "message": "Bienvenue dans Tactical RPG Duos !",
  "duration": 2.5
}

{
  "type": "unlock_location",
  "location": "starting_village"
}

{
  "type": "transition",
  "target": "world_map",
  "fade_duration": 1.0
}
```

### Chapitres

**Structure :**

```json
{
  "id": 1,
  "title": "Titre du chapitre",
  "description": "Description",
  "battles": [
    {
      "battle_id": "tutorial",
      "required": true,
      "unlock_condition": null
    },
    {
      "battle_id": "next_battle",
      "required": false,
      "unlock_condition": {
        "type": "battle_completed|chapter_completed|level_reached",
        "battle_id": "tutorial",
        "chapter_id": 1,
        "level": 5
      }
    }
  ]
}
```

### Gestion Campaign

**Dans CampaignManager :**

```gdscript
func start_new_campaign():
    var campaign_data = _load_campaign_start_from_json()
    
    # Initialiser état
    campaign_state = {
        current_chapter: campaign_data.initial_state.chapter,
        current_battle: campaign_data.initial_state.battle_index,
        battles_won: 0
    }
    
    # Lancer séquence
    for action in campaign_data.start_sequence:
        await _execute_start_action(action)
    
    GameRoot.event_bus.campaign_started.emit()
```

---

## SYSTÈME DE LOCATIONS & MAPS

### Location Data

**Fichier :** `data/maps/locations/starting_village.json`

```json
{
  "id": "starting_village",
  "name": "Village de Départ",
  "description": "Un paisible village",
  "type": "village",
  "population": 150,
  "actions": [
    {
      "id": "talk_to_elder",
      "type": "dialogue",
      "label": "💬 Parler à l'Ancien",
      "icon": "res://assets/icons/actions/dialogue.png",
      "dialogue_id": "village_elder",
      "unlocked_at_step": 0
    },
    {
      "id": "visit_shop",
      "type": "shop",
      "label": "🛒 Magasin",
      "icon": "res://assets/icons/actions/shop.png",
      "shop_id": "village_general_store",
      "unlocked_at_step": 0
    },
    {
      "id": "manage_team",
      "type": "team_management",
      "label": "👥 Gérer l'Équipe",
      "unlocked_at_step": 0
    }
  ],
  "npcs": [
    {
      "id": "elder_harold",
      "name": "Harold l'Ancien",
      "dialogue_id": "village_elder",
      "locations": [
        {
          "place_id": "town_square",
          "place_name": "Place du village",
          "chance": 60.0
        },
        {
          "place_id": "elder_house",
          "place_name": "Maison de l'ancien",
          "chance": 40.0
        }
      ]
    }
  ],
  "shops": [
    {
      "id": "village_general_store",
      "name": "Magasin Général",
      "inventory": [
        {"item_id": "health_potion", "stock": 10, "price": 25},
        {"item_id": "iron_sword", "stock": 2, "price": 150}
      ]
    }
  ]
}
```

### Types d'Actions

```json
// Dialogue
{
  "type": "dialogue",
  "label": "💬 Parler",
  "dialogue_id": "npc_id"
}

// Shop
{
  "type": "shop",
  "label": "🛒 Magasin",
  "shop_id": "shop_id"
}

// Battle
{
  "type": "battle",
  "label": "⚔️ Combat",
  "battle_id": "battle_id"
}

// Building (scène custom)
{
  "type": "building",
  "label": "🏰 Entrer",
  "scene": "res://scenes/world/buildings/castle.tscn"
}

// Quest Board
{
  "type": "quest_board",
  "label": "📋 Quêtes"
}

// Team Management
{
  "type": "team_management",
  "label": "👥 Équipe"
}

// Custom Event
{
  "type": "custom",
  "label": "🔍 Chercher",
  "event": {
    "type": "custom_event",
    "event_id": "event_id"
  }
}
```

### NPCs avec Probabilités

**Structure NPC :**

```json
{
  "id": "npc_id",
  "name": "Nom NPC",
  "dialogue_id": "dialogue_id",
  "locations": [
    {
      "place_id": "unique_place_id",
      "place_name": "Nom affiché",
      "chance": 60.0
    }
  ]
}
```

**Calcul de position :**

```gdscript
# Dans WorldMapDataLoader
static func _calculate_npc_position(npc: Dictionary) -> Dictionary:
    var roll = randf() * 100.0
    var cumulative = 0.0
    
    for loc in npc.locations:
        cumulative += loc.chance
        if roll <= cumulative:
            return {
                "npc": npc,
                "place_id": loc.place_id,
                "place_name": loc.place_name
            }
    
    # Fallback : première location
    return {...}
```

### World Map Data

**Fichier :** `data/maps/world_map_data.json`

```json
{
  "id": "main_world",
  "name": "Continent de Terramia",
  "grid_size": {"width": 1920, "height": 1080},
  "locations": [
    {
      "id": "starting_village",
      "name": "Village de Départ",
      "type": "village",
      "position": {"x": 400, "y": 300},
      "icon": "res://assets/icons/locations/village.png",
      "scale": 2.0,
      "color": {"r": 0.3, "g": 0.8, "b": 0.3, "a": 1.0},
      "unlocked_at_step": 0,
      "connections": ["dark_forest", "capital_city"]
    }
  ],
  "connections_visual": {
    "color": {"r": 0.7, "g": 0.7, "b": 0.7, "a": 0.8},
    "color_locked": {"r": 0.3, "g": 0.3, "b": 0.3, "a": 0.4},
    "width": 5.0,
    "dash_length": 20.0,
    "gap_length": 12.0
  },
  "connection_states": {
    "starting_village_to_dark_forest": "unlocked",
    "dark_forest_to_capital_city": "locked",
    "capital_city_to_eastern_port": "hidden"
  },
  "player": {
    "start_location": "starting_village",
    "icon": "res://icon.svg",
    "scale": 1.5,
    "bounce_speed": 1.5,
    "bounce_amount": 10.0,
    "move_speed": 300.0
  }
}
```

### WorldMapDataLoader

**Fichier :** `scripts/data/loaders/world_map_data_loader.gd`

```gdscript
const WORLD_MAP_PATH := "res://data/maps/"

static func load_world_map_data(map_id: String = "world_map_data") -> Dictionary:
    var json_path = WORLD_MAP_PATH + map_id + ".json"
    var data = json_loader.load_json_file(json_path)
    return _convert_map_positions(data)

static func load_location_data(location_id: String) -> Dictionary:
    var json_path = WORLD_MAP_PATH + "locations/" + location_id + ".json"
    return json_loader.load_json_file(json_path)

static func get_unlocked_locations(current_step: int, map_id: String) -> Array:
    var all_locations = get_all_locations(map_id)
    return all_locations.filter(
        func(loc): return loc.unlocked_at_step <= current_step
    )
```

---

## SYSTÈME DE MANA & EFFETS

### Mana Effects

**Fichier :** `data/mana/mana_effects.json`

```json
{
  "effects": [
    {
      "effect_id": "burn",
      "effect_name": "Brûlure",
      "mana_type": "FIRE",
      "duration": 3.0,
      "damage_over_time": 5,
      "stat_modifiers": {
        "defense": -5
      },
      "description": "Inflige des dégâts de feu sur la durée"
    },
    {
      "effect_id": "freeze",
      "effect_name": "Gel",
      "mana_type": "ICE",
      "duration": 2.0,
      "damage_over_time": 0,
      "stat_modifiers": {
        "movement": -2,
        "speed": -50
      },
      "description": "Ralentit significativement la cible"
    }
  ]
}
```

### Champs Effet de Mana

```json
{
  "effect_id": "unique_effect_id",
  "effect_name": "Nom affiché",
  "mana_type": "FIRE|ICE|LIGHTNING|HOLY|DARK|NATURE",
  "duration": 3.0,
  "damage_over_time": 5,        // Dégâts par tour (optionnel)
  "heal_over_time": 3,          // Soins par tour (optionnel)
  "stat_modifiers": {
    "attack": 10,               // Bonus/malus temporaires
    "defense": -5,
    "movement": -2,
    "speed": -50
  },
  "description": "Description de l'effet"
}
```

### Types de Mana

```
FIRE      → Burn (DoT), bonus attaque
ICE       → Freeze (slow), réduit mouvement
LIGHTNING → Stun (skip turn), bonus vitesse
HOLY      → Heal (HoT), bonus défense
DARK      → Curse (debuff), draine HP
NATURE    → Regen (HoT), bonus résistances
```

### Rings & Mana

**Fichier :** `data/ring/rings.json`

```json
{
  "materialization_rings": [
    {
      "ring_id": "mat_basic_line",
      "ring_name": "Anneau de Ligne Basique",
      "attack_shape": "line",
      "base_range": 3,
      "area_size": 1
    }
  ],
  "channeling_rings": [
    {
      "ring_id": "chan_fire",
      "ring_name": "Anneau de Feu",
      "mana_effect_id": "burn",
      "mana_potency": 1.0,
      "effect_duration": 3.0
    }
  ]
}
```

**Génération AttackProfile :**

```gdscript
# Dans RingSystem
var profile = generate_attack_profile("mat_basic_line", "chan_fire")
# profile = {
#   shape: "line",
#   range: 3,
#   area: 1,
#   mana_effect: "burn",
#   potency: 1.0,
#   duration: 3.0
# }
```

---

## SYSTÈME DE LOCALISATION

### Structure i18n

**Fichier :** `localization/dialogues.csv`

```csv
keys,en,fr,es
dialogue.intro.knight.001,"Prepare for battle!","Préparez-vous au combat !","¡Prepárense para la batalla!"
speaker.knight,"Sir Gaheris","Sire Gaheris","Sir Gaheris"
bark.damaged,"Ow!","Aïe !","¡Ay!"
```

### Configuration Project

**project.godot :**

```ini
[internationalization]
locale/translations=PackedStringArray(
    "res://localization/dialogues.en.translation",
    "res://localization/dialogues.fr.translation",
    "res://localization/dialogues.es.translation"
)
```

### Utilisation dans le Code

**Traduction de texte :**

```gdscript
# Clé de traduction
var text = tr("dialogue.intro.knight.001")

# Avec fallback
var text = line.get("text", "")
var text_key = line.get("text_key", "")
if text_key:
    text = tr(text_key)
```

**Convention de clés :**

```
dialogue.{context}.{character}.{number}
speaker.{character_id}
bark.{emotion}
ui.{element}.{action}
item.{item_id}.name
item.{item_id}.description
ability.{ability_id}.name
```

### Système de Langue

**LanguageManager (à implémenter) :**

```gdscript
class_name LanguageManager extends Node

const AVAILABLE_LANGUAGES = ["en", "fr", "es"]
var current_language: String = "en"

func set_language(lang: String):
    if lang in AVAILABLE_LANGUAGES:
        TranslationServer.set_locale(lang)
        current_language = lang
        GameRoot.event_bus.language_changed.emit(lang)

func get_current_language() -> String:
    return TranslationServer.get_locale()
```

---

## SCHÉMAS DE VALIDATION

### Validation des Données au Démarrage

**Dans DataValidationModule :**

```gdscript
const DATA_PATHS = {
    "rings": "res://data/ring/rings.json",
    "mana_effects": "res://data/mana/mana_effects.json",
    "units": "res://data/team/available_units.json",
    "abilities": "res://data/abilities/",  # Dossier
    "enemies": "res://data/enemies/",      # Dossier
    "items": "res://data/items/"           # Dossier
}

func validate_all_data() -> ValidationReport:
    var report = ValidationReport.new()
    
    _validate_rings_file(report)
    _validate_mana_effects_file(report)
    _validate_units_file(report)
    _validate_abilities_directory(report)
    _validate_enemies_directory(report)
    _validate_items_directory(report)
    
    return report
```

### Champs Requis par Type

**Rings :**

```gdscript
const REQUIRED_FIELDS = {
    "materialization_ring": [
        "ring_id", "ring_name", "attack_shape", "base_range"
    ],
    "channeling_ring": [
        "ring_id", "ring_name", "mana_effect_id"
    ]
}
```

**Mana Effects :**

```gdscript
const REQUIRED_FIELDS = {
    "mana_effect": [
        "effect_id", "mana_type"
    ]
}
```

**Items :**

```gdscript
const REQUIRED_FIELDS = {
    "item": [
        "id", "name", "category", "value"
    ]
}
```

**Abilities :**

```gdscript
const REQUIRED_FIELDS = {
    "ability": [
        "id", "name", "type", "cost"
    ]
}
```

**Enemies :**

```gdscript
const REQUIRED_FIELDS = {
    "enemy": [
        "id", "name", "stats", "ai_behavior"
    ]
}
```

### Validation Détaillée

**Exemple : Validation Ring :**

```gdscript
func validate_rings(rings: Array, ring_type: String) -> Array[String]:
    var errors: Array[String] = []
    var required = REQUIRED_FIELDS.get(ring_type, [])
    
    for i in range(rings.size()):
        var ring = rings[i]
        
        # Vérifier champs requis
        for field in required:
            if not ring.has(field):
                errors.append("[%d] Champ requis manquant: %s" % [i, field])
        
        # Vérifications spécifiques
        if ring_type == "materialization_ring":
            if ring.has("attack_shape"):
                var valid_shapes = ["line", "cone", "circle", "cross", "area"]
                if ring.attack_shape not in valid_shapes:
                    errors.append("[%d] attack_shape invalide" % i)
    
    return errors
```

---

## CHECKLIST D'INTÉGRATION

### ✅ Systèmes de Base

- [x] EventBus
- [x] SceneLoader & SceneRegistry
- [x] GameManager
- [x] GlobalLogger
- [x] DebugOverlay

### ✅ Systèmes de Combat

- [x] BattleMapManager3D
- [x] TerrainModule3D
- [x] UnitManager3D
- [x] MovementModule3D (A*)
- [x] ActionModule3D
- [x] AIModule3D
- [x] ObjectiveModule
- [x] DuoSystem
- [x] RingSystem
- [x] CommandHistory
- [x] BattleStateMachine

### ✅ Managers de Données

- [x] BattleDataManager
- [x] CampaignManager
- [x] TeamManager
- [x] Dialogue_Manager

### ✅ Data Loaders

- [x] JSONDataLoader
- [x] DialogueDataLoader
- [x] WorldMapDataLoader
- [ ] AbilityDataLoader *(fichier présent, non utilisé)*
- [ ] EnemyDataLoader *(fichier présent, non utilisé)*
- [ ] ItemDataLoader *(fichier présent, non utilisé)*

### ⚠️ Systèmes UI

- [x] DialogueBox
- [x] BarkSystem
- [x] WorldMapLocation
- [x] WorldMapConnection
- [x] WorldMapPlayer
- [ ] InventoryUI *(à implémenter)*
- [ ] ShopUI *(à implémenter)*
- [ ] TeamRosterUI *(partiellement implémenté)*
- [ ] AbilityMenu *(à implémenter)*

### ⚠️ Systèmes Gameplay

- [x] DialogueData
- [ ] AbilitySystem *(à implémenter)*
- [ ] InventorySystem *(à implémenter)*
- [ ] StatusEffectSystem *(à implémenter)*
- [ ] LootSystem *(à implémenter)*
- [ ] ShopSystem *(à implémenter)*
- [ ] QuestSystem *(à implémenter)*

### ⚠️ Validation & Testing

- [x] DataValidationModule
- [x] BattleDataValidator
- [x] Validator (générique)
- [ ] ItemValidator *(à créer)*
- [ ] AbilityValidator *(à créer)*
- [ ] EnemyValidator *(à créer)*

### 📊 Données JSON

**Présentes et valides :**
- [x] abilities/fireball.json
- [x] battles/tutorial.json, forest_battle.json, village_defense.json, boss_fight.json
- [x] campaign/campaign_start.json
- [x] dialogues/intro_prologue.json, village_elder.json
- [x] enemies/goblin_warrior.json
- [x] items/consumables/health_potion.json
- [x] items/weapons/iron_sword.json
- [x] mana/mana_effects.json
- [x] maps/locations/*.json
- [x] maps/world_map_data.json
- [x] ring/rings.json
- [x] scenarios/tutorial_scenario.json
- [x] team/available_units.json

**Manquantes (pour production) :**
- [ ] Plus d'abilities (heal, shield, lightning, etc.)
- [ ] Plus d'ennemis (orcs, dragons, boss)
- [ ] Plus d'items (armures, accessoires, scrolls)
- [ ] Plus de locations
- [ ] Plus de dialogues
- [ ] Plus de scenarios

---

## INDEX GLOBAL DES SYSTÈMES

### Hiérarchie Complète

```
AUTOLOADS (Godot)
├── EventBus
├── GameManager
│   ├── SceneLoader
│   └── CampaignManager
├── Dialogue_Manager
├── BattleDataManager
├── TeamManager
├── GlobalLogger
├── DebugOverlay
└── Version_Manager

SINGLETONS (Classes)
├── SceneRegistry (static)
└── WorldMapDataLoader (static)

SYSTÈMES DE COMBAT
├── BattleMapManager3D (scene root)
│   ├── TerrainModule3D
│   ├── UnitManager3D
│   ├── MovementModule3D
│   ├── ActionModule3D
│   ├── AIModule3D
│   ├── ObjectiveModule
│   ├── JSONScenarioModule
│   ├── BattleStatsTracker
│   ├── DuoSystem
│   ├── RingSystem
│   ├── DataValidationModule
│   ├── CommandHistory
│   └── BattleStateMachine
└── BattleUnit3D (instances)

SYSTÈMES UI
├── DialogueBox
├── BarkSystem
├── WorldMapLocation
├── WorldMapConnection
├── WorldMapPlayer
└── TeamRosterUI

DATA LOADERS
├── JSONDataLoader (générique)
├── AbilityDataLoader
├── DialogueDataLoader
├── EnemyDataLoader
├── ItemDataLoader
└── WorldMapDataLoader

VALIDATION
├── Validator (base)
├── ValidationRule
├── ValidationResult
├── BattleDataValidator
└── DataValidationModule

UTILITAIRES
├── Command (pattern)
├── CommandHistory
├── StateMachine (générique)
├── BattleStateMachine
└── Version_Manager
```

### Flow Complet d'une Partie

```
1. DÉMARRAGE
   ├── Godot _ready() → Autoloads initialisés
   ├── GameRoot.game_manager._ready()
   │   ├── SceneLoader créé
   │   ├── SceneRegistry validé
   │   ├── CampaignManager créé
   │   └── load_scene(MAIN_MENU)
   └── DataValidationModule.validate_all_data()

2. NOUVELLE PARTIE
   ├── User clique "Nouvelle Partie"
   ├── GameRoot.game_manager._on_game_started()
   ├── CampaignManager.start_new_campaign()
   │   ├── Load campaign_start.json
   │   ├── Initialiser campaign_state
   │   └── Exécuter start_sequence
   │       ├── DialogueBox.play(intro_prologue)
   │       ├── GameRoot.event_bus.notify("Bienvenue!")
   │       └── GameRoot.event_bus.change_scene(WORLD_MAP)
   └── WorldMap affichée avec starting_village déverrouillé

3. EXPLORATION
   ├── WorldMap.populate_locations()
   │   └── WorldMapDataLoader.load_world_map_data()
   ├── User clique sur location
   ├── WorldMapLocation._on_clicked()
   │   └── WorldMapDataLoader.load_location_data(location_id)
   ├── LocationMenu affiche actions disponibles
   └── User sélectionne action
       ├── Type "dialogue" → Dialogue_Manager.start_dialogue()
       ├── Type "shop" → ShopUI.open(shop_id)
       ├── Type "battle" → CampaignManager.start_battle(battle_id)
       └── Type "team_management" → TeamRosterUI.show()

4. COMBAT
   ├── CampaignManager.start_battle(battle_id)
   │   ├── Load battle data (JSON)
   │   ├── Merge avec TeamManager.get_current_team()
   │   ├── BattleDataManager.set_battle_data(data)
   │   └── GameRoot.event_bus.change_scene(BATTLE)
   │
   ├── BattleMapManager3D._ready()
   │   ├── await _initialize_modules()
   │   └── initialize_battle(BattleDataManager.get_battle_data())
   │       ├── _load_terrain()
   │       ├── _load_objectives()
   │       ├── _load_scenario()
   │       ├── _spawn_units()
   │       └── _start_battle()
   │
   ├── TOUR JOUEUR
   │   ├── unit_manager.reset_player_units()
   │   ├── User sélectionne unité (raycasting)
   │   ├── Menu d'actions ouvert
   │   ├── User choisit "Attack"
   │   │   └── DuoSystem.try_form_duo() (optionnel)
   │   ├── ActionModule3D.execute_attack()
   │   │   ├── calculate_damage()
   │   │   ├── target.take_damage()
   │   │   └── DamageNumber spawned
   │   └── User clique "End Turn"
   │
   ├── TOUR ENNEMI
   │   ├── unit_manager.reset_enemy_units()
   │   ├── AIModule3D.execute_enemy_turn()
   │   │   ├── evaluate_unit_action()
   │   │   ├── find_best_attack_target()
   │   │   └── execute_ai_action()
   │   └── current_turn++
   │
   ├── VICTOIRE
   │   ├── ObjectiveModule.all_objectives_completed()
   │   ├── _end_battle(true)
   │   │   ├── award_xp_to_survivors()
   │   │   ├── stats_tracker.get_final_stats()
   │   │   ├── _calculate_rewards()
   │   │   └── GameRoot.event_bus.battle_ended.emit(results)
   │   ├── BattleDataManager.clear_battle_data()
   │   └── GameRoot.event_bus.change_scene(BATTLE_RESULTS)
   │
   └── DÉFAITE
       └── Similaire mais without rewards

5. PROGRESSION
   ├── CampaignManager._on_battle_ended(results)
   ├── if victory:
   │   ├── campaign_state.battles_won++
   │   └── _advance_campaign()
   ├── TeamManager.add_xp(units)
   │   └── _level_up() si seuil atteint
   └── GameRoot.event_bus.change_scene(WORLD_MAP)
```

---

## CONVENTIONS DE NOMMAGE

### Fichiers JSON

```
data/
├── {category}/
│   ├── {item_id}.json          # Minuscules, underscore
│   └── {subcategory}/
│       └── {item_id}.json

Exemples:
data/abilities/fireball.json
data/items/weapons/iron_sword.json
data/enemies/goblin_warrior.json
data/maps/locations/starting_village.json
```

### IDs dans JSON

```json
{
  "id": "category_name"          // Minuscules, underscore
}

Exemples:
"fireball"
"health_potion"
"iron_sword"
"goblin_warrior"
"starting_village"
```

### Clés de Localisation

```
{context}.{element}.{number}

Exemples:
dialogue.intro.knight.001
speaker.knight
bark.damaged
ui.button.confirm
item.health_potion.name
ability.fireball.description
```

### Scripts GDScript

```
snake_case          # Variables, fonctions, fichiers
PascalCase          # Classes, types
UPPER_SNAKE_CASE    # Constantes

Exemples:
var health_potion: Item
const MAX_INVENTORY_SIZE: int = 100
func calculate_damage() -> int
class_name ItemDataLoader
```

---

## POINTS D'ATTENTION FINAUX

### ⚠️ Conversions de Types

**JSON → Godot toujours en float :**

```gdscript
# ❌ MAUVAIS
var hp = data.hp  # Type float

# ✅ BON
var hp = int(data.hp)  # Converti en int

# Position
if data.position is Array:
    position = Vector2i(int(pos[0]), int(pos[1]))
else:
    position = data.position  # Déjà Vector2i
```

### ⚠️ Gestion des Ressources

**Chargement d'assets :**

```gdscript
# ❌ MAUVAIS - Bloquer thread principal
var texture = load("res://path/to/texture.png")

# ✅ BON - Chargement asynchrone
ResourceLoader.load_threaded_request(path)
var texture = ResourceLoader.load_threaded_get(path)
```

### ⚠️ Validation au Runtime

**Toujours valider données externes :**

```gdscript
func load_item(item_id: String) -> Dictionary:
    var item = item_loader.get_item(item_id)
    
    # Validation
    if item.is_empty():
        push_error("Item introuvable: " + item_id)
        return {}
    
    if not item.has("category"):
        push_error("Item invalide (pas de category): " + item_id)
        return {}
    
    return item
```

### ⚠️ Sauvegarde

**Format de sauvegarde (proposition) :**

```json
{
  "version": "1.0.0",
  "timestamp": 1706542800,
  "campaign": {
    "chapter": 2,
    "battles_won": 5,
    "current_location": "capital_city"
  },
  "team": {
    "roster": [...],
    "current_team": [...]
  },
  "inventory": {
    "gold": 500,
    "items": {...}
  },
  "progression": {
    "unlocked_locations": [...],
    "completed_battles": [...],
    "discovered_npcs": [...]
  }
}
```

---

## CONCLUSION GÉNÉRALE

### Documentation Complète

**PART1 :** UI, Dialogues, World Map  
**PART2 :** Combat, Modules, Systèmes Avancés  
**PART3 :** Formats JSON, Items, Localisation *(ce fichier)*

### Systèmes Implémentés ✅

- ✅ Combat tactique 3D complet
- ✅ Système de duo
- ✅ Système d'anneaux (rings)
- ✅ Gestion d'équipe (roster)
- ✅ Système de dialogue
- ✅ World map avec locations
- ✅ Campaign manager
- ✅ Data loaders (JSON)
- ✅ Validation de données
- ✅ Localisation (i18n)
- ✅ Debug overlay
- ✅ Logging système
- ✅ Command pattern (undo/redo)
- ✅ State machine

### Systèmes à Implémenter 🚧

- 🚧 Inventaire complet
- 🚧 Système de shop
- 🚧 Système d'abilities en combat
- 🚧 Système de loot
- 🚧 Système de quêtes
- 🚧 Effets de statut en combat
- 🚧 VFX & particules
- 🚧 Audio système complet
- 🚧 Sauvegarde persistante
- 🚧 UI polish (transitions, animations)

### Données à Compléter 📝

**Priorité Haute :**
- Plus d'abilities (10-20 minimum)
- Plus d'ennemis (15-20 types)
- Plus d'items (30-50 items)
- Plus de dialogues (campagne complète)
- Plus de locations (5-10 locations)

**Priorité Moyenne :**
- Plus de scénarios de combat
- Plus de rings (combo matérialisation/canalisation)
- Plus d'effets de mana
- Assets visuels (icônes, sprites)
- Assets audio (musiques, SFX)

### Architecture Robuste

**Points forts :**
✅ Séparation claire des responsabilités  
✅ Event-driven (EventBus)  
✅ Data-driven (JSON)  
✅ Validation au démarrage  
✅ Patterns éprouvés (Command, State Machine)  
✅ Logging & debug intégrés  
✅ Modularité (chaque système indépendant)  

**Axes d'amélioration :**
⚠️ Tests unitaires (absents)  
⚠️ Documentation code (comments)  
⚠️ Performance profiling  
⚠️ Memory management (pooling)  
⚠️ Error recovery (crash handling)  

---

**Fichier créé :** `/mnt/user-data/outputs/ARCHITECTURE_PART3.md`

**Navigation :**
- [← PART1 : UI, Dialogues, World Map](./ARCHITECTURE_PART1.md)
- [← PART2 : Combat & Modules](./ARCHITECTURE_PART2.md)
- [PART3 : Formats JSON & Systèmes Finaux] (ce fichier)

---

**🎉 DOCUMENTATION COMPLÈTE !**

Le projet **Tactical RPG Duos** est maintenant entièrement documenté sur 3 parties couvrant :
- 22 systèmes principaux
- 40+ classes et modules
- 15+ formats de données JSON
- 100+ fonctions critiques

Cette documentation constitue une base solide pour le développement, la maintenance et l'extension du projet.



Nouveau Menu de Duo

## 🎯 Objectif

Remplacer le menu de sélection de duo simple par un menu enrichi avec :
- Mini-fiches des personnages (Support + Leader)
- Cases d'attaque coupées en deux (Mana + Arme)
- Design clair et informatif

## 📐 Schéma Visuel

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ⚔️ Formation de Duo ⚔️                             │
│                    Choisissez votre combinaison Mana + Arme                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐        ┌────────────────────────┐        ┌─────────────┐│
│  │              │        │                        │        │             ││
│  │   SUPPORT    │        │   OPTIONS DE DUO       │        │   LEADER    ││
│  │              │        │                        │        │             ││
│  │  ┌────────┐  │        │ ┌──────────┬─────────┐ │        │ ┌────────┐  ││
│  │  │Portrait│  │        │ │  MANA    │  ARME   │ │        │ │Portrait│  ││
│  │  └────────┘  │        │ │  🔵      │  ⚔️     │ │        │ └────────┘  ││
│  │              │        │ │  Feu     │  Lame   │ │        │             ││
│  │  Nom: Aria   │        │ └──────────┴─────────┘ │        │ Nom: Gaël   ││
│  │  Classe: Mage│        │                        │        │ Classe: Kn. ││
│  │              │        │ ┌──────────┬─────────┐ │        │             ││
│  │  HP: 80/100  │        │ │  MANA    │  ARME   │ │        │ HP: 120/120 ││
│  │  ATK: 25     │        │ │  🔵      │  ⚔️     │ │        │ ATK: 35     ││
│  │  DEF: 15     │        │ │  Glace   │  Lance  │ │        │ DEF: 25     ││
│  │              │        │ └──────────┴─────────┘ │        │             ││
│  └──────────────┘        │                        │        └─────────────┘│
│                          │ ┌──────────┬─────────┐ │                       │
│                          │ │  MANA    │  ARME   │ │                       │
│                          │ │  🔵      │  ⚔️     │ │                       │
│                          │ │  Foudre  │  Hache  │ │                       │
│                          │ └──────────┴─────────┘ │                       │
│                          │                        │                       │
│                          │  ┌────────────────┐   │                       │
│                          │  │ 🚶 Attaquer Seul│   │                       │
│                          │  └────────────────┘   │                       │
│                          │  ┌────────────────┐   │                       │
│                          │  │   ✕ Annuler    │   │                       │
│                          │  └────────────────┘   │                       │
│                          └────────────────────────┘                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📦 Fichiers créés

### 1. Scripts UI

#### `scripts/ui/duo_attack_option.gd`
- Représente une option d'attaque (case coupée)
- Affiche Mana (gauche) + Arme (droite)
- Supporte icônes ou texte fallback
- Émet `option_selected(mana_id, weapon_id)`

#### `scripts/ui/character_mini_card.gd`
- Mini-fiche d'un personnage
- Affiche portrait, nom, classe, stats (HP/ATK/DEF)
- Peut se configurer depuis BattleUnit3D ou Dictionary
- Colorie HP selon pourcentage

### 2. Scènes UI

#### `scenes/ui/duo_attack_option.tscn`
Structure :
```
DuoAttackOption (PanelContainer)
└── Button
    └── HBoxContainer
        ├── ManaPanel (PanelContainer, bleu)
        │   └── MarginContainer
        │       └── VBoxContainer
        │           ├── ManaIcon (TextureRect)
        │           └── ManaLabel (Label)
        └── WeaponPanel (PanelContainer, rouge)
            └── MarginContainer
                └── VBoxContainer
                    ├── WeaponIcon (TextureRect)
                    └── WeaponLabel (Label)
```

Couleurs par défaut :
- **Mana** : Bleu foncé (0.2, 0.3, 0.6, 0.8)
- **Arme** : Rouge foncé (0.6, 0.3, 0.2, 0.8)

#### `scenes/ui/character_mini_card.tscn`
Structure :
```
CharacterMiniCard (PanelContainer)
└── MarginContainer
    └── VBoxContainer
        ├── Portrait (TextureRect, 80x80)
        ├── NameLabel (Label, jaune/doré)
        ├── ClassLabel (Label, gris)
        ├── HSeparator
        └── StatsGrid (GridContainer, 2 cols)
            ├── HPLabel / HPValue (vert/jaune/rouge)
            ├── ATKLabel / ATKValue
            └── DEFLabel / DEFValue
```

### 3. Scène modifiée

#### `scenes/battle/battle_3d_MODIFIED.tscn`
Nouveau `DuoSelectionPopup` :
- Largeur : ~1000px
- Hauteur : ~500px
- Layout : 3 colonnes (Support | Options | Leader)
