# Combat System Game Design Document

## Executive Summary

The **Combat System** manages all offensive and defensive interactions in Space Rogue: Starbound Odyssey, providing a flexible framework for damage calculation, hit detection, and combat state management. It handles everything from laser fire to explosive impacts while maintaining clean separation between combat logic and entity-specific implementations.

**Key Features:**
- Modular weapon system with configurable damage types
- Real-time hit detection and damage application
- Combat state management (engaged, fleeing, neutral)
- Visual and audio feedback integration
- Performance-optimized for large-scale space battles

**Integration Points:**
- Receives targeting data from AI System
- Provides damage events to Progression System
- Integrates with Visual Effects System for impact feedback
- Works with Audio System for combat sound effects

## System Architecture

### Core Components

#### CombatManager (Central Coordinator)
```gdscript
class_name CombatManager
extends Node

var active_combatants: Array[CombatParticipant] = []
var damage_events: Array[DamageEvent] = []

func _physics_process(delta: float):
    process_damage_events()
    update_combat_states()
    cleanup_destroyed_entities()
```

#### DamageCalculator
- Calculates damage based on weapon stats and target defenses
- Applies damage multipliers and reductions
- Handles critical hits and special effects

#### HitDetectionSystem
- Raycasting for projectile weapons
- Area overlap detection for explosive effects
- Collision prediction for fast-moving projectiles

#### CombatStateManager
- Tracks engagement status between entities
- Manages combat music and audio cues
- Handles combat exit conditions

### Data Flow
1. Weapon fires → Projectile created
2. Hit detection finds target
3. Damage calculation applied
4. Target health updated
5. Visual/audio effects triggered
6. Combat state updated

### Performance Characteristics
- Supports 100+ simultaneous projectiles
- Efficient spatial queries for hit detection
- Configurable update frequencies
- Memory pooling for projectiles

## Technical Implementation

### Godot Node Structure
```
CombatSystem (Node)
├── CombatManager
├── DamageCalculator
├── HitDetectionSystem
├── WeaponManager
└── ProjectilePool
```

### Key Scripts

#### CombatParticipant.gd
```gdscript
class_name CombatParticipant
extends Node

@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var defense_rating: float = 1.0
@export var team_id: int = 0

signal health_changed(new_health: float, max_health: float)
signal took_damage(amount: float, source: CombatParticipant)
signal destroyed()

func take_damage(damage_data: DamageData) -> void:
    var actual_damage = calculate_damage_taken(damage_data)
    current_health -= actual_damage

    emit_signal("took_damage", actual_damage, damage_data.source)

    if current_health <= 0:
        emit_signal("destroyed")
        queue_free()

func calculate_damage_taken(damage_data: DamageData) -> float:
    var base_damage = damage_data.amount
    var defense_modifier = 1.0 - (defense_rating * 0.1)  # 10% reduction per defense point
    return max(0, base_damage * defense_modifier)
```

#### Weapon.gd
```gdscript
class_name Weapon
extends Node

@export var weapon_name: String = "Laser Cannon"
@export var damage: float = 15.0
@export var fire_rate: float = 5.0  # shots per second
@export var range: float = 50.0
@export var projectile_speed: float = 100.0
@export var energy_cost: float = 10.0

var last_fire_time: float = 0.0
var ammo_count: int = -1  # -1 = infinite

signal weapon_fired(projectile: Projectile)

func can_fire() -> bool:
    if ammo_count == 0:
        return false
    var current_time = Time.get_ticks_msec() / 1000.0
    return current_time - last_fire_time >= 1.0 / fire_rate

func fire(target_position: Vector3) -> bool:
    if not can_fire():
        return false

    last_fire_time = Time.get_ticks_msec() / 1000.0
    if ammo_count > 0:
        ammo_count -= 1

    var projectile = create_projectile(target_position)
    emit_signal("weapon_fired", projectile)
    return true

func create_projectile(target_position: Vector3) -> Projectile:
    var projectile = ProjectilePool.get_projectile()
    projectile.initialize(global_position, target_position, self)
    return projectile
```

#### DamageData.gd
```gdscript
class_name DamageData
extends RefCounted

var amount: float
var type: DamageType
var source: CombatParticipant
var critical: bool = false
var effects: Array[DamageEffect] = []

enum DamageType {
    KINETIC,
    ENERGY,
    EXPLOSIVE,
    RADIATION
}

func apply_effect(effect: DamageEffect) -> void:
    effects.append(effect)
```

## Entity Integration

### Required Interfaces

#### ICombatEntity
```gdscript
interface ICombatEntity:
    func get_combat_participant() -> CombatParticipant
    func on_combat_started(target: ICombatEntity)
    func on_combat_ended()
    func get_weapon_mounts() -> Array[Node3D]
```

#### WeaponMount
```gdscript
class WeaponMount:
    var position: Vector3
    var rotation: Vector3
    var allowed_weapon_types: Array[String]
    var current_weapon: Weapon
```

### Entity Types

#### Player Ship Entity
- Multiple weapon mounts
- Energy management system
- Upgrade integration

#### Enemy Entity
- AI-controlled weapon usage
- Tactical weapon selection
- Health-based weapon changes

#### Stationary Turret Entity
- Fixed firing arcs
- Area defense capabilities
- Power management

## API Reference

### Public Methods

#### CombatManager
```gdscript
func register_combatant(entity: ICombatEntity) -> void
func unregister_combatant(entity: ICombatEntity) -> void
func get_combatants_in_range(position: Vector3, radius: float) -> Array[ICombatEntity]
func apply_damage(target: ICombatEntity, damage_data: DamageData) -> void
func start_combat(attacker: ICombatEntity, defender: ICombatEntity) -> void
```

#### Weapon
```gdscript
func fire(target_position: Vector3) -> bool
func reload() -> void
func get_ammo_count() -> int
func upgrade_damage(multiplier: float) -> void
func upgrade_fire_rate(multiplier: float) -> void
```

### Configuration Options

#### Damage Types
- Kinetic: Physical projectiles, affected by armor
- Energy: Lasers and plasma, bypasses some armor
- Explosive: Area damage, splash effects
- Radiation: DoT effects, shield penetration

#### Combat Rules
- Friendly fire settings
- Team-based damage rules
- Environmental damage modifiers
- Critical hit chances

## Testing Strategy

### Unit Tests
- Damage calculation accuracy
- Weapon firing rates and cooldowns
- Hit detection precision
- Combat state transitions

### Integration Tests
- Full combat encounters between entities
- Weapon switching and upgrades
- Multi-entity battles
- Performance with 50+ combatants

### Edge Cases
- Zero health destruction
- Weapon overheating mechanics
- Environmental hazard interactions
- Network synchronization (if multiplayer)

## Reusability Guidelines

### Adapting for Other Projects

#### 2D Platformer Combat
```gdscript
# Modify hit detection for 2D
func perform_hit_detection(projectile: Projectile) -> Array[ICombatEntity]:
    var space_state = get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(global_position, target_position)
    var result = space_state.intersect_ray(query)
    return result.collider if result else null
```

#### Turn-Based Strategy
```gdscript
# Add turn management
func process_turn_based_combat():
    for combatant in active_combatants:
        if combatant.has_turn:
            combatant.perform_action()
            break  # Wait for turn completion
```

#### MOBA-Style Combat
```gdscript
# Add ability system integration
func cast_ability(ability: Ability, target: Vector3):
    if ability.cooldown_ready():
        var projectile = ability.create_projectile()
        projectile.fire(target)
        ability.start_cooldown()
```

### Extension Mechanisms

#### Custom Damage Types
```gdscript
class CustomDamageType extends DamageType:
    var special_effect: Callable

    func apply_special_effect(target: ICombatEntity):
        if special_effect:
            special_effect.call(target)
```

#### Combat Modifiers
```gdscript
class CombatModifier:
    var name: String
    var duration: float
    var damage_multiplier: float = 1.0
    var defense_multiplier: float = 1.0

    func apply_to_participant(participant: CombatParticipant):
        participant.damage_modifier *= damage_multiplier
        participant.defense_modifier *= defense_multiplier
```

This system provides a robust foundation for any game requiring combat mechanics, with clear separation between combat rules and entity-specific implementations.