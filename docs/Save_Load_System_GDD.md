# Save/Load System Game Design Document

## Executive Summary

The **Save/Load System** provides robust game state persistence for Space Rogue: Starbound Odyssey, enabling players to save progress, share runs, and maintain roguelike replayability. It handles serialization, data validation, and cross-platform compatibility while maintaining clean separation between save logic and game systems.

**Key Features:**
- Comprehensive game state serialization
- Roguelike run-based save system
- Data integrity validation and corruption handling
- Cross-platform save compatibility
- Performance-optimized save operations

**Integration Points:**
- Receives data from all systems (Progression, World Generation, etc.)
- Provides save data to UI System for display
- Works with Audio System for preference persistence
- Integrates with Steam/cloud services for sharing

## System Architecture

### Core Components

#### SaveManager (Central Coordinator)
```gdscript
class_name SaveManager
extends Node

@export var save_directory: String = "user://saves/"
@export var max_save_slots: int = 10
@export var auto_save_interval: float = 300.0  # 5 minutes

var current_save_data: SaveData
var save_slots: Array[SaveSlotInfo] = []
var auto_save_timer: float = 0.0

func _ready():
    initialize_save_system()
    load_save_slot_list()

func save_game(slot_name: String = "autosave", description: String = "") -> bool:
    var save_data = collect_save_data()
    save_data.metadata.slot_name = slot_name
    save_data.metadata.description = description
    save_data.metadata.timestamp = Time.get_unix_time_from_system()

    return save_to_file(save_data)

func load_game(slot_name: String) -> bool:
    var save_data = load_from_file(slot_name)
    if save_data and validate_save_data(save_data):
        apply_save_data(save_data)
        return true
    return false

func collect_save_data() -> SaveData:
    var save_data = SaveData.new()

    # Collect data from all systems
    save_data.player_data = get_player_save_data()
    save_data.world_data = get_world_save_data()
    save_data.progression_data = get_progression_save_data()
    save_data.settings_data = get_settings_save_data()

    return save_data
```

#### DataSerializer
- JSON-based serialization with compression
- Custom data type handling
- Version compatibility management
- Binary data optimization for large assets

#### IntegrityChecker
- Save file corruption detection
- Data validation against schemas
- Backup and recovery mechanisms
- Cheat detection and prevention

#### CloudSyncManager
- Steam Cloud integration
- Cross-device synchronization
- Conflict resolution
- Offline play support

### Data Flow
1. Save requested by player or system
2. Data collected from all game systems
3. Data validated and serialized
4. File written with integrity checks
5. Load process reverses the flow with validation

### Performance Characteristics
- Save operations complete in <100ms
- Load operations complete in <200ms
- Memory-efficient data structures
- Background processing for heavy operations

## Technical Implementation

### Godot Node Structure
```
SaveLoadSystem (Node)
├── SaveManager
├── DataSerializer
├── IntegrityChecker
├── CloudSyncManager
└── Save Slots (Directory)
    ├── slot_01.save
    ├── slot_02.save
    └── autosave.save
```

### Key Scripts

#### SaveData.gd
```gdscript
class_name SaveData
extends Resource

@export var version: String = "1.0.0"
@export var metadata: SaveMetadata
@export var player_data: PlayerSaveData
@export var world_data: WorldSaveData
@export var progression_data: ProgressionSaveData
@export var settings_data: SettingsSaveData

func _init():
    metadata = SaveMetadata.new()
    player_data = PlayerSaveData.new()
    world_data = WorldSaveData.new()
    progression_data = ProgressionSaveData.new()
    settings_data = SettingsSaveData.new()

func validate() -> bool:
    # Version compatibility check
    if not is_version_compatible(version):
        return false

    # Data integrity checks
    if not player_data.validate():
        return false

    if not world_data.validate():
        return false

    if not progression_data.validate():
        return false

    return true

func is_version_compatible(save_version: String) -> bool:
    var current_version = ProjectSettings.get_setting("application/config/version")
    return save_version == current_version  # For now, strict version matching
```

#### SaveMetadata.gd
```gdscript
class_name SaveMetadata
extends Resource

@export var slot_name: String = "New Save"
@export var description: String = ""
@export var timestamp: int = 0
@export var play_time: float = 0.0
@export var game_version: String = "1.0.0"
@export var player_level: int = 1
@export var screenshot_path: String = ""

func get_formatted_timestamp() -> String:
    var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
    return "%02d/%02d/%04d %02d:%02d" % [
        datetime.day, datetime.month, datetime.year,
        datetime.hour, datetime.minute
    ]

func get_play_time_formatted() -> String:
    var hours = int(play_time / 3600)
    var minutes = int((play_time - hours * 3600) / 60)
    var seconds = int(play_time - hours * 3600 - minutes * 60)

    if hours > 0:
        return "%dh %dm %ds" % [hours, minutes, seconds]
    else:
        return "%dm %ds" % [minutes, seconds]
```

#### PlayerSaveData.gd
```gdscript
class_name PlayerSaveData
extends Resource

@export var position: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var level: int = 1
@export var experience: int = 0
@export var unlocked_upgrades: Array[String] = []
@export var inventory: Array[String] = []
@export var ship_customization: Dictionary = {}

func validate() -> bool:
    # Health bounds check
    if health < 0 or health > max_health:
        return false

    # Level progression check
    if level < 1 or level > 10:
        return false

    # Position sanity check
    if position.length() > 10000:  # Too far from origin
        return false

    return true

func apply_to_player(player: Node) -> void:
    if player.has_method("set_position"):
        player.set_position(position)

    if player.has_method("set_rotation"):
        player.set_rotation(rotation)

    if player.has_method("set_health"):
        player.set_health(health, max_health)

    if player.has_method("set_level"):
        player.set_level(level)

    if player.has_method("set_experience"):
        player.set_experience(experience)

    # Apply upgrades and inventory
    for upgrade_id in unlocked_upgrades:
        player.unlock_upgrade(upgrade_id)

    for item_id in inventory:
        player.add_to_inventory(item_id)
```

#### DataSerializer.gd
```gdscript
class_name DataSerializer
extends Node

const COMPRESSION_LEVEL = 6  # Balanced compression/speed

func serialize_save_data(save_data: SaveData) -> PackedByteArray:
    # Convert to dictionary for JSON serialization
    var data_dict = save_data_to_dict(save_data)

    # Serialize to JSON
    var json_string = JSON.stringify(data_dict, "\t")

    # Compress
    var uncompressed = json_string.to_utf8_buffer()
    var compressed = uncompressed.compress(FileAccess.COMPRESSION_GZIP, COMPRESSION_LEVEL)

    return compressed

func deserialize_save_data(data: PackedByteArray) -> SaveData:
    # Decompress
    var decompressed = data.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)

    if decompressed.is_empty():
        push_error("Failed to decompress save data")
        return null

    # Parse JSON
    var json = JSON.new()
    var parse_result = json.parse(decompressed.get_string_from_utf8())

    if parse_result != OK:
        push_error("Failed to parse save data JSON: " + json.get_error_message())
        return null

    var data_dict = json.get_data()

    # Convert back to SaveData
    return dict_to_save_data(data_dict)

func save_data_to_dict(save_data: SaveData) -> Dictionary:
    return {
        "version": save_data.version,
        "metadata": instance_to_dict(save_data.metadata),
        "player_data": instance_to_dict(save_data.player_data),
        "world_data": instance_to_dict(save_data.world_data),
        "progression_data": instance_to_dict(save_data.progression_data),
        "settings_data": instance_to_dict(save_data.settings_data)
    }

func dict_to_save_data(data_dict: Dictionary) -> SaveData:
    var save_data = SaveData.new()

    save_data.version = data_dict.get("version", "1.0.0")
    save_data.metadata = dict_to_instance(data_dict.get("metadata", {}), SaveMetadata)
    save_data.player_data = dict_to_instance(data_dict.get("player_data", {}), PlayerSaveData)
    save_data.world_data = dict_to_instance(data_dict.get("world_data", {}), WorldSaveData)
    save_data.progression_data = dict_to_instance(data_dict.get("progression_data", {}), ProgressionSaveData)
    save_data.settings_data = dict_to_instance(data_dict.get("settings_data", {}), SettingsSaveData)

    return save_data
```

## Entity Integration

### Required Interfaces

#### ISaveableEntity
```gdscript
interface ISaveableEntity:
    func get_save_data() -> Dictionary
    func load_save_data(data: Dictionary) -> void
    func validate_save_data(data: Dictionary) -> bool
    func get_entity_type() -> String
```

#### SaveDataValidator
```gdscript
class SaveDataValidator:
    static var validation_schemas: Dictionary = {}

    static func validate_data(entity_type: String, data: Dictionary) -> bool:
        var schema = validation_schemas.get(entity_type)
        if not schema:
            return true  # No schema = assume valid

        return validate_against_schema(data, schema)

    static func validate_against_schema(data: Dictionary, schema: Dictionary) -> bool:
        # Basic validation - check required fields and types
        for field_name in schema:
            var field_schema = schema[field_name]
            if not data.has(field_name):
                if field_schema.get("required", false):
                    return false
                continue

            var field_value = data[field_name]
            var expected_type = field_schema.get("type")

            if expected_type and typeof(field_value) != expected_type:
                return false

        return true
```

### Entity Types

#### Player Entity
- Position, rotation, stats
- Inventory and equipment
- Ship customization

#### World Entity
- Sector exploration state
- Spawn point activation
- Environmental changes

#### Progression Entity
- Experience and level
- Unlocked upgrades
- Achievement progress

## API Reference

### Public Methods

#### SaveManager
```gdscript
func save_game(slot_name: String = "autosave", description: String = "") -> bool
func load_game(slot_name: String) -> bool
func delete_save_slot(slot_name: String) -> bool
func get_save_slots() -> Array[SaveSlotInfo]
func export_save(slot_name: String, export_path: String) -> bool
func import_save(import_path: String, slot_name: String) -> bool
```

#### SaveData
```gdscript
func validate() -> bool
func get_file_size_estimate() -> int
func get_summary() -> String
func apply_to_game() -> void
func create_backup() -> SaveData
```

### Configuration Options

#### Save Settings
- Auto-save frequency
- Maximum save slots
- Compression level
- Backup retention policy

#### Compatibility Settings
- Version migration rules
- Data conversion handlers
- Backward compatibility modes

## Testing Strategy

### Unit Tests
- Data serialization/deserialization accuracy
- Save file corruption detection
- Version compatibility handling
- Memory usage during save operations

### Integration Tests
- Full game state save/load cycles
- Cross-session progression continuity
- Save file import/export functionality
- Performance impact measurement

### Edge Cases
- Corrupted save file recovery
- Disk space limitations
- Version upgrade scenarios
- Multiplayer save conflicts

## Reusability Guidelines

### Adapting for Other Projects

#### Simple Save System
```gdscript
# Minimal implementation for basic games
func simple_save_game():
    var save_data = {
        "player_position": player.position,
        "player_health": player.health,
        "current_level": game.current_level
    }

    var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
    file.store_var(save_data)
    file.close()

func simple_load_game():
    if not FileAccess.file_exists("user://savegame.save"):
        return

    var file = FileAccess.open("user://savegame.save", FileAccess.READ)
    var save_data = file.get_var()
    file.close()

    player.position = save_data.player_position
    player.health = save_data.player_health
    game.current_level = save_data.current_level
```

#### Cloud Save System
```gdscript
# Add cloud synchronization
func sync_to_cloud(save_data: SaveData):
    if SteamManager.is_steam_running():
        var cloud_data = serialize_save_data(save_data)
        SteamManager.cloud_write_file("savegame.dat", cloud_data)

func load_from_cloud() -> SaveData:
    if SteamManager.is_steam_running():
        var cloud_data = SteamManager.cloud_read_file("savegame.dat")
        if cloud_data:
            return deserialize_save_data(cloud_data)
    return null
```

#### Encrypted Save System
```gdscript
# Add encryption for sensitive data
func encrypt_save_data(data: PackedByteArray, key: String) -> PackedByteArray:
    var crypto = Crypto.new()
    var encrypted = crypto.encrypt(Crypto.AES_MODE_CBC, key.sha256_buffer(), data)
    return encrypted

func decrypt_save_data(data: PackedByteArray, key: String) -> PackedByteArray:
    var crypto = Crypto.new()
    var decrypted = crypto.decrypt(Crypto.AES_MODE_CBC, key.sha256_buffer(), data)
    return decrypted
```

### Extension Mechanisms

#### Custom Save Formats
```gdscript
class CustomSaveFormat extends DataSerializer:
    func serialize_to_binary(save_data: SaveData) -> PackedByteArray:
        var buffer = StreamPeerBuffer.new()

        # Write version
        buffer.put_u32(save_data.version.split(".").map(func(x): return int(x)))

        # Write player data in custom format
        buffer.put_vector3(save_data.player_data.position)
        buffer.put_float(save_data.player_data.health)

        return buffer.data_array

    func deserialize_from_binary(data: PackedByteArray) -> SaveData:
        var buffer = StreamPeerBuffer.new()
        buffer.data_array = data

        var save_data = SaveData.new()

        # Read version
        var version_parts = []
        for i in 3:
            version_parts.append(buffer.get_u32())
        save_data.version = "%d.%d.%d" % version_parts

        # Read player data
        save_data.player_data.position = buffer.get_vector3()
        save_data.player_data.health = buffer.get_float()

        return save_data
```

#### Save Game Editor
```gdscript
class SaveGameEditor:
    static func modify_save_data(save_data: SaveData, modifications: Dictionary):
        for key in modifications:
            match key:
                "add_experience":
                    save_data.progression_data.experience += modifications[key]
                "unlock_upgrade":
                    save_data.progression_data.unlocked_upgrades.append(modifications[key])
                "set_position":
                    save_data.player_data.position = modifications[key]

    static func validate_modified_save(save_data: SaveData) -> bool:
        # Check for exploits or invalid modifications
        if save_data.player_data.health > save_data.player_data.max_health:
            return false

        if save_data.progression_data.level > 10:
            return false

        return true
```

This save/load system provides a solid foundation for game persistence, with robust data handling and extensibility for future features like cloud saves and advanced serialization formats.