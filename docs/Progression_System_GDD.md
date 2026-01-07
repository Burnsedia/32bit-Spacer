# Progression System Game Design Document

## Executive Summary

The **Progression System** manages player growth, unlocks, and meta-game advancement in Space Rogue: Starbound Odyssey. It provides a rewarding progression loop through experience points, leveling, upgrades, and achievements while maintaining clean separation between progression mechanics and entity implementations.

**Key Features:**
- Experience-based leveling with stat progression
- Modular upgrade system with multiple paths
- Achievement tracking and rewards
- Persistent progression data
- Balance-adjustable growth curves

**Integration Points:**
- Receives combat data from Combat System
- Provides stat modifiers to Movement and Combat Systems
- Integrates with UI System for progression displays
- Works with Save/Load System for persistence

## System Architecture

### Core Components

#### ProgressionManager (Central Coordinator)
```gdscript
class_name ProgressionManager
extends Node

@export var player_profile: PlayerProfile

var experience_system: ExperienceSystem
var upgrade_system: UpgradeSystem
var achievement_system: AchievementSystem

func _ready():
    initialize_systems()
    connect_signals()

func grant_experience(amount: int, source: String) -> void:
    experience_system.add_experience(amount, source)
    check_achievements("experience_gained", {"amount": amount, "source": source})

func level_up() -> void:
    upgrade_system.unlock_level_upgrades(player_profile.current_level)
    emit_signal("player_leveled_up", player_profile.current_level)
    check_achievements("level_up", {"level": player_profile.current_level})
```

#### ExperienceSystem
- Experience point calculation and distribution
- Level progression curves
- Multiplier systems for bonuses
- Experience source tracking

#### UpgradeSystem
- Upgrade tree management
- Prerequisite checking
- Stat modification application
- Upgrade persistence

#### AchievementSystem
- Achievement definition and tracking
- Progress monitoring
- Reward distribution
- Unlocking mechanics

### Data Flow
1. Combat/exploration events generate experience
2. Experience applied to player progression
3. Level thresholds trigger level-ups
4. Upgrade choices presented to player
5. Stat modifications applied to relevant systems

### Performance Characteristics
- Lightweight processing (runs on events, not frames)
- Efficient data structures for large upgrade trees
- Configurable caching for frequently accessed data
- Minimal memory footprint

## Technical Implementation

### Godot Node Structure
```
ProgressionSystem (Node)
├── ProgressionManager
├── ExperienceSystem
├── UpgradeSystem
├── AchievementSystem
└── PlayerProfile (Resource)
```

### Key Scripts

#### PlayerProfile.gd
```gdscript
class_name PlayerProfile
extends Resource

@export var player_name: String = "Pilot"
@export var current_level: int = 1
@export var experience: int = 0
@export var experience_to_next_level: int = 100

@export var base_stats: Dictionary = {
    "max_health": 100,
    "damage_multiplier": 1.0,
    "speed_multiplier": 1.0,
    "fire_rate_multiplier": 1.0
}

@export var unlocked_upgrades: Array[String] = []
@export var completed_achievements: Array[String] = []
@export var permanent_unlocks: Array[String] = []

var current_stats: Dictionary = base_stats.duplicate()

func apply_upgrade(upgrade: UpgradeDefinition) -> void:
    for stat in upgrade.stat_modifiers:
        current_stats[stat] = current_stats.get(stat, 1.0) * upgrade.stat_modifiers[stat]

    unlocked_upgrades.append(upgrade.upgrade_id)

func calculate_experience_to_next_level() -> int:
    # Exponential growth curve
    return int(100 * pow(1.2, current_level - 1))

func can_afford_upgrade(upgrade: UpgradeDefinition) -> bool:
    # Check if player has required resources/currency
    return true  # Placeholder - implement based on game economy

func has_prerequisites(upgrade: UpgradeDefinition) -> bool:
    for prereq in upgrade.prerequisites:
        if not unlocked_upgrades.has(prereq):
            return false
    return true
```

#### ExperienceSystem.gd
```gdscript
class_name ExperienceSystem
extends Node

@export var base_experience_per_enemy: int = 25
@export var experience_multipliers: Dictionary = {
    "enemy_type": 1.0,
    "difficulty": 1.0,
    "streak": 1.0,
    "time_bonus": 1.0
}

signal experience_gained(amount: int, total: int, source: String)
signal level_up(new_level: int)

func add_experience(amount: int, source: String = "unknown") -> void:
    var final_amount = calculate_modified_experience(amount, source)

    player_profile.experience += final_amount
    emit_signal("experience_gained", final_amount, player_profile.experience, source)

    while player_profile.experience >= player_profile.experience_to_next_level:
        perform_level_up()

func calculate_modified_experience(base_amount: int, source: String) -> int:
    var multiplier = 1.0

    # Apply source-specific multipliers
    match source:
        "enemy_defeat":
            multiplier *= experience_multipliers.get("enemy_type", 1.0)
        "exploration":
            multiplier *= 1.5
        "achievement":
            multiplier *= 2.0

    # Apply global multipliers
    multiplier *= experience_multipliers.get("difficulty", 1.0)
    multiplier *= experience_multipliers.get("streak", 1.0)

    return int(base_amount * multiplier)

func perform_level_up() -> void:
    player_profile.experience -= player_profile.experience_to_next_level
    player_profile.current_level += 1
    player_profile.experience_to_next_level = player_profile.calculate_experience_to_next_level()

    # Apply level-up bonuses
    apply_level_bonuses()

    emit_signal("level_up", player_profile.current_level)

func apply_level_bonuses() -> void:
    # Base stat increases per level
    player_profile.base_stats["max_health"] += 10
    player_profile.base_stats["damage_multiplier"] *= 1.05
    player_profile.base_stats["speed_multiplier"] *= 1.02

    # Refresh current stats
    player_profile.current_stats = player_profile.base_stats.duplicate()

    # Re-apply all upgrades to new base stats
    for upgrade_id in player_profile.unlocked_upgrades:
        var upgrade = UpgradeDatabase.get_upgrade(upgrade_id)
        if upgrade:
            player_profile.apply_upgrade(upgrade)
```

#### UpgradeDefinition.gd
```gdscript
class_name UpgradeDefinition
extends Resource

@export var upgrade_id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var cost: int = 0
@export var max_level: int = 1

@export var prerequisites: Array[String] = []
@export var stat_modifiers: Dictionary = {}
@export var ability_unlocks: Array[String] = []
@export var visual_effects: Array[String] = []

@export_multiline var flavor_text: String

func get_tooltip_text() -> String:
    var text = display_name + "\n\n" + description
    if not stat_modifiers.is_empty():
        text += "\n\nStats:"
        for stat in stat_modifiers:
            var value = stat_modifiers[stat]
            if value > 1.0:
                text += "\n" + stat.capitalize() + ": +" + str(int((value - 1.0) * 100)) + "%"
            elif value < 1.0:
                text += "\n" + stat.capitalize() + ": " + str(int((1.0 - value) * 100)) + "%"

    if not ability_unlocks.is_empty():
        text += "\n\nUnlocks:"
        for ability in ability_unlocks:
            text += "\n• " + ability

    return text

func can_purchase(profile: PlayerProfile) -> bool:
    if profile.unlocked_upgrades.has(upgrade_id):
        return false

    if not profile.has_prerequisites(self):
        return false

    return profile.can_afford_upgrade(self)
```

## Entity Integration

### Required Interfaces

#### IProgressableEntity
```gdscript
interface IProgressableEntity:
    func get_player_profile() -> PlayerProfile
    func on_level_up(new_level: int)
    func on_upgrade_applied(upgrade: UpgradeDefinition)
    func get_experience_reward() -> int
```

#### UpgradeDatabase
```gdscript
class UpgradeDatabase:
    static var upgrades: Dictionary = {}

    static func register_upgrade(upgrade: UpgradeDefinition) -> void:
        upgrades[upgrade.upgrade_id] = upgrade

    static func get_upgrade(upgrade_id: String) -> UpgradeDefinition:
        return upgrades.get(upgrade_id)

    static func get_available_upgrades(profile: PlayerProfile) -> Array[UpgradeDefinition]:
        var available: Array[UpgradeDefinition] = []
        for upgrade in upgrades.values():
            if upgrade.can_purchase(profile):
                available.append(upgrade)
        return available
```

### Entity Types

#### Player Entity
- Experience accumulation from combat
- Level-up stat bonuses
- Upgrade selection and application

#### Enemy Entity
- Experience rewards on defeat
- Scaling difficulty based on player level

#### Environment Entity
- Exploration experience bonuses
- Secret area discoveries

## API Reference

### Public Methods

#### ProgressionManager
```gdscript
func grant_experience(amount: int, source: String = "unknown") -> void
func get_player_level() -> int
func get_experience_progress() -> float  # 0.0 to 1.0
func unlock_upgrade(upgrade_id: String) -> bool
func get_available_upgrades() -> Array[UpgradeDefinition]
func reset_progress() -> void  # For roguelike runs
```

#### PlayerProfile
```gdscript
func apply_upgrade(upgrade: UpgradeDefinition) -> void
func get_stat_value(stat_name: String) -> float
func has_upgrade(upgrade_id: String) -> bool
func get_upgrade_level(upgrade_id: String) -> int
func export_save_data() -> Dictionary
func import_save_data(data: Dictionary) -> void
```

### Configuration Options

#### Experience Curves
- Linear: Fixed XP per level
- Exponential: Increasing XP requirements
- Hybrid: Mix of both approaches

#### Upgrade Trees
- Linear progression paths
- Branching specialization trees
- Web of interconnected upgrades

## Testing Strategy

### Unit Tests
- Experience calculation accuracy
- Level-up threshold verification
- Upgrade prerequisite checking
- Stat modifier application

### Integration Tests
- Full progression loop from combat to upgrade
- Save/load cycle integrity
- Achievement trigger verification
- Multi-session progression continuity

### Edge Cases
- Level cap handling
- Upgrade tree dead-ends
- Experience overflow scenarios
- Achievement race conditions

## Reusability Guidelines

### Adapting for Other Projects

#### RPG Game Progression
```gdscript
# Add skill points system
@export var skill_points_per_level: int = 3

func perform_level_up():
    super.perform_level_up()  # Call parent
    player_profile.skill_points += skill_points_per_level
    emit_signal("skill_points_gained", skill_points_per_level)
```

#### Idle Game Progression
```gdscript
# Add offline progression
func calculate_offline_progress(time_offline: float):
    var offline_experience = base_experience_rate * time_offline
    var capped_experience = min(offline_experience, max_offline_cap)
    grant_experience(capped_experience, "offline_progress")
```

#### Battle Royale Progression
```gdscript
# Add zone-based scaling
func apply_zone_progression(zone_level: int):
    var zone_multiplier = 1.0 + (zone_level * 0.1)
    experience_multipliers["zone"] = zone_multiplier
```

### Extension Mechanisms

#### Custom Upgrade Types
```gdscript
class CustomUpgradeDefinition extends UpgradeDefinition:
    var custom_effect: Callable

    func apply_custom_effect(entity: IProgressableEntity):
        if custom_effect:
            custom_effect.call(entity)
```

#### Achievement Templates
```gdscript
class AchievementTemplate:
    var achievement_id: String
    var condition_checker: Callable
    var reward_granter: Callable

    func check_condition(profile: PlayerProfile) -> bool:
        return condition_checker.call(profile)

    func grant_reward(profile: PlayerProfile):
        reward_granter.call(profile)
```

This progression system provides a flexible foundation for any game requiring player advancement, with clear separation between progression logic and game-specific implementations.