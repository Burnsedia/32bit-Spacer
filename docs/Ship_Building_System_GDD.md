# Ship Building System Game Design Document

## Executive Summary

The **Ship Building System** enables players to construct and customize spacecraft from scavenged and crafted components in Space Rogue: Starbound Odyssey, providing deep strategic ship design with compatibility mechanics, stat balancing, and visual customization. It serves as the culmination of the mining, scavenging, and crafting systems while offering extensive player expression.

**Key Features:**
- Component-based ship assembly with compatibility systems
- Real-time stat calculation and balancing
- Visual ship customization and theming
- Multi-tier component progression
- Platform-optimized building interfaces
- Integration with all resource acquisition systems

**Integration Points:**
- Receives components from Mining and Scavenging Systems
- Provides ships to Movement and Combat Systems
- Works with Progression System for unlocks and experience
- Integrates with Visual Effects for ship appearance
- Affects UI System with building interfaces

## System Architecture

### Core Components

#### ShipBuilder (Main Coordinator)
```gdscript
class_name ShipBuilder
extends Node

@export var max_ship_slots: int = 3
@export var compatibility_check_enabled: bool = true
@export var auto_balance_enabled: bool = false

var available_hulls: Array[ShipHull] = []
var available_components: Dictionary = {}  # category -> Array[Component]
var active_ships: Array[PlayerShip] = []
var building_queue: Array[BuildJob] = []

func initialize_ship_building():
    load_ship_templates()
    load_component_database()
    setup_building_stations()

func start_ship_build(hull: ShipHull) -> bool:
    if not can_build_ship(hull):
        return false
    
    var build_job = BuildJob.new(hull, self)
    building_queue.append(build_job)
    
    # Platform-specific building interface
    if OS.get_name() in ["Android", "iOS"]:
        open_mobile_build_interface(build_job)
    else:
        open_pc_build_interface(build_job)
    
    return true

func install_component(ship: PlayerShip, component: Component, slot_index: int) -> bool:
    if not can_install_component(ship, component, slot_index):
        return false
    
    ship.install_component(component, slot_index)
    recalculate_ship_stats(ship)
    check_compatibility_issues(ship)
    
    return true

func recalculate_ship_stats(ship: PlayerShip):
    # Reset to base stats
    ship.reset_to_base_stats()
    
    # Apply hull modifiers
    ship.apply_hull_modifiers()
    
    # Apply component modifiers
    for component in ship.installed_components:
        if component:
            ship.apply_component_modifiers(component)
    
    # Final stat validation
    ship.validate_final_stats()

func check_compatibility_issues(ship: PlayerShip) -> Array[CompatibilityIssue]:
    var issues: Array[CompatibilityIssue] = []
    
    # Check power requirements
    var power_issues = check_power_compatibility(ship)
    issues.append_array(power_issues)
    
    # Check component conflicts
    var conflict_issues = check_component_conflicts(ship)
    issues.append_array(conflict_issues)
    
    # Check structural integrity
    var structural_issues = check_structural_integrity(ship)
    issues.append_array(structural_issues)
    
    return issues

func can_install_component(ship: PlayerShip, component: Component, slot_index: int) -> bool:
    # Check slot compatibility
    if not ship.hull.slot_types[slot_index].can_accept_component(component):
        return false
    
    # Check component requirements
    if not component.requirements_met(ship):
        return false
    
    # Check existing component conflicts
    for existing_component in ship.installed_components:
        if existing_component and component.conflicts_with(existing_component):
            return false
    
    return true

func complete_ship_build(build_job: BuildJob) -> PlayerShip:
    var new_ship = build_job.create_ship()
    active_ships.append(new_ship)
    
    # Add to player's fleet
    PlayerFleet.add_ship(new_ship)
    
    building_queue.erase(build_job)
    return new_ship
```

#### ShipHull (Base Structure)
```gdscript
class_name ShipHull
extends Resource

@export var hull_name: String
@export var hull_type: HullType
@export var size_class: SizeClass
@export var base_stats: ShipStats

enum HullType {
    FIGHTER,
    FREIGHTER,
    EXPLORER,
    BATTLESHIP,
    CUSTOM
}

enum SizeClass {
    SMALL,    # 1-2 crew, limited slots
    MEDIUM,   # 3-5 crew, balanced slots
    LARGE,    # 6-10 crew, many slots
    CAPITAL   # 10+ crew, extensive customization
}

@export var slot_types: Array[SlotType] = []
@export var visual_theme: String = "default"
@export var build_requirements: Dictionary = {}  # material -> quantity
@export var build_time: float = 300.0  # 5 minutes default

var model_scene: PackedScene
var icon_texture: Texture2D

func get_total_slot_count() -> int:
    return slot_types.size()

func get_slots_by_category(category: ComponentCategory) -> Array[int]:
    var matching_slots: Array[int] = []
    
    for i in range(slot_types.size()):
        if slot_types[i].accepted_categories.has(category):
            matching_slots.append(i)
    
    return matching_slots

func get_build_cost() -> Dictionary:
    return build_requirements.duplicate()

func can_afford_build(inventory: Dictionary) -> bool:
    for material in build_requirements:
        var required = build_requirements[material]
        var available = inventory.get(material, 0)
        if available < required:
            return false
    return true
```

#### Component (Modular Parts)
```gdscript
class_name Component
extends Resource

@export var component_name: String
@export var component_category: ComponentCategory
@export var tier: int = 1
@export var rarity: ComponentRarity

enum ComponentCategory {
    ENGINE,
    WEAPON,
    SHIELD,
    SENSOR,
    CARGO,
    CREW,
    SPECIAL
}

enum ComponentRarity {
    COMMON,
    UNCOMMON,
    RARE,
    EPIC,
    LEGENDARY
}

@export var stat_modifiers: Dictionary = {}  # stat_name -> modifier_value
@export var power_draw: float = 0.0
@export var weight: float = 1.0
@export var compatibility_tags: Array[String] = []
@export var conflict_tags: Array[String] = []
@export var requirements: Dictionary = {}  # prerequisite -> value

var icon_texture: Texture2D
var model_scene: PackedScene
var description: String

func get_stat_modifier(stat_name: String) -> float:
    return stat_modifiers.get(stat_name, 0.0)

func conflicts_with(other_component: Component) -> bool:
    # Check tag conflicts
    for tag in conflict_tags:
        if other_component.compatibility_tags.has(tag):
            return true
    
    for tag in other_component.conflict_tags:
        if compatibility_tags.has(tag):
            return true
    
    return false

func requirements_met(ship: PlayerShip) -> bool:
    for requirement in requirements:
        var required_value = requirements[requirement]
        var current_value = ship.get_stat_value(requirement)
        
        match requirement:
            "power_generation":
                if ship.get_total_power_generation() < required_value:
                    return false
            "hull_integrity":
                if ship.hull.size_class < required_value:
                    return false
            "crew_capacity":
                if ship.get_crew_capacity() < required_value:
                    return false
    
    return true

func get_power_efficiency() -> float:
    if power_draw <= 0:
        return 1.0
    return get_total_stat_bonus() / power_draw

func get_total_stat_bonus() -> float:
    var total = 0.0
    for modifier in stat_modifiers.values():
        total += abs(modifier)  # Sum of absolute modifier values
    return total
```

#### ShipStats (Calculated Performance)
```gdscript
class_name ShipStats
extends Resource

@export var max_health: float = 100.0
@export var armor_rating: float = 0.0
@export var shield_capacity: float = 0.0
@export var shield_regeneration: float = 0.0

@export var max_speed: float = 50.0
@export var acceleration: float = 10.0
@export var turn_rate: float = 2.0
@export var maneuverability: float = 1.0

@export var weapon_damage: float = 10.0
@export var weapon_fire_rate: float = 1.0
@export var weapon_range: float = 100.0
@export var weapon_accuracy: float = 0.8

@export var cargo_capacity: float = 10.0
@export var sensor_range: float = 200.0
@export var crew_capacity: int = 1
@export var power_generation: float = 10.0
@export var power_capacity: float = 10.0

func get_total_power_draw() -> float:
    # This would be calculated based on installed components
    return 0.0

func get_effective_health() -> float:
    return max_health * (1.0 + armor_rating)

func get_combat_effectiveness() -> float:
    return (weapon_damage * weapon_fire_rate * weapon_accuracy) / (1.0 / weapon_range)

func get_mobility_score() -> float:
    return (max_speed + acceleration + turn_rate) * maneuverability

func validate_stats() -> Array[String]:
    var warnings: Array[String] = []
    
    # Check power balance
    if get_total_power_draw() > power_generation:
        warnings.append("Insufficient power generation for installed components")
    
    # Check cargo balance
    if cargo_capacity < 0:
        warnings.append("Negative cargo capacity detected")
    
    # Check combat viability
    if weapon_damage <= 0 and shield_capacity <= 0:
        warnings.append("Ship has no offensive or defensive capabilities")
    
    return warnings

func get_summary_string() -> String:
    return """Health: {health}
Speed: {speed} | Acceleration: {accel}
Weapons: {damage} dmg @ {rate}/s
Cargo: {cargo} | Sensors: {sensors}
Power: {power_gen} gen / {power_draw} draw""".format({
        "health": "%.0f" % max_health,
        "speed": "%.0f" % max_speed,
        "accel": "%.0f" % acceleration,
        "damage": "%.0f" % weapon_damage,
        "rate": "%.1f" % weapon_fire_rate,
        "cargo": "%.0f" % cargo_capacity,
        "sensors": "%.0f" % sensor_range,
        "power_gen": "%.1f" % power_generation,
        "power_draw": "%.1f" % get_total_power_draw()
    })
```

### Building Interfaces

#### PC Building Interface (Complex)
- **Drag-and-Drop Assembly**: Visual component placement
- **Real-time Stat Updates**: Live calculation as components are added
- **Compatibility Warnings**: Visual indicators for conflicts
- **Save/Load Designs**: Preset ship configurations
- **Advanced Filtering**: Search and sort components

#### Mobile Building Interface (Simplified)
- **Touch-Based Assembly**: Tap slots, select from radial menus
- **Simplified Stats**: Key metrics only, expandable details
- **Gesture Controls**: Swipe to rotate components, pinch to zoom
- **Auto-Compatibility**: Suggest valid component combinations
- **Quick Presets**: Pre-built ship designs for different roles

## Technical Implementation

### Godot Node Structure
```
ShipBuildingSystem (Node)
├── ShipBuilder
├── ComponentDatabase (Resource)
├── ShipTemplates (Resource)
├── BuildingStations (Node3D)
│   ├── AssemblyBay (Node3D)
│   ├── ComponentStorage (Node3D)
│   └── TestFlightArea (Node3D)
└── ShipBuildingUI (CanvasLayer)
    ├── ComponentBrowser
    ├── ShipDesigner
    ├── StatCalculator
    └── CompatibilityChecker
```

### Key Scripts

#### ShipDesigner.gd (PC)
```gdscript
class_name ShipDesigner
extends Control

@onready var hull_display: MeshInstance3D = $HullDisplay
@onready var component_slots: Array[ComponentSlot] = []
@onready var stat_display: RichTextLabel = $StatDisplay
@onready var compatibility_panel: Panel = $CompatibilityPanel

var current_ship: PlayerShip
var dragged_component: Component

func _ready():
    setup_component_slots()
    connect_signals()

func setup_component_slots():
    for i in range(current_ship.hull.slot_types.size()):
        var slot = ComponentSlot.new()
        slot.slot_index = i
        slot.slot_type = current_ship.hull.slot_types[i]
        slot.position = calculate_slot_position(i)
        slot.component_selected.connect(on_component_selected)
        add_child(slot)
        component_slots.append(slot)

func on_component_selected(slot_index: int, component: Component):
    if ShipBuilder.can_install_component(current_ship, component, slot_index):
        ShipBuilder.install_component(current_ship, component, slot_index)
        update_visual_display()
        update_stat_display()
        check_compatibility()
    else:
        show_installation_error(slot_index, component)

func update_visual_display():
    # Update 3D model with installed components
    for slot in component_slots:
        if current_ship.installed_components[slot.slot_index]:
            var component = current_ship.installed_components[slot.slot_index]
            slot.display_component(component)

func update_stat_display():
    var stats = current_ship.calculate_current_stats()
    stat_display.text = stats.get_summary_string()

func check_compatibility():
    var issues = ShipBuilder.check_compatibility_issues(current_ship)
    
    # Clear existing warnings
    for child in compatibility_panel.get_children():
        child.queue_free()
    
    # Add new warnings
    for issue in issues:
        var warning_label = Label.new()
        warning_label.text = issue.description
        warning_label.modulate = Color.RED
        compatibility_panel.add_child(warning_label)

func _on_component_dragged(component: Component, slot: ComponentSlot):
    dragged_component = component
    
    # Show drag preview
    var preview = component.icon_texture.duplicate()
    add_child(preview)
    preview.global_position = get_viewport().get_mouse_position()

func _on_component_dropped(slot: ComponentSlot):
    if dragged_component and slot:
        on_component_selected(slot.slot_index, dragged_component)
    
    dragged_component = null
```

#### MobileShipDesigner.gd (Mobile)
```gdscript
class_name MobileShipDesigner
extends Control

@onready var ship_viewport: SubViewport = $ShipViewport
@onready var component_palette: GridContainer = $ComponentPalette
@onready var quick_stats: VBoxContainer = $QuickStats
@onready var slot_selector: OptionButton = $SlotSelector

var current_ship: PlayerShip
var selected_slot: int = 0

func _ready():
    setup_mobile_interface()
    setup_gesture_recognition()

func setup_mobile_interface():
    # Create touch-friendly component buttons
    for category in ComponentDatabase.get_categories():
        var category_button = Button.new()
        category_button.text = category.capitalize()
        category_button.pressed.connect(func(): show_category_components(category))
        component_palette.add_child(category_button)
    
    # Setup slot selector
    for i in range(current_ship.hull.slot_types.size()):
        slot_selector.add_item("Slot %d: %s" % [i+1, current_ship.hull.slot_types[i].name], i)

func show_category_components(category: String):
    # Clear existing components
    for child in component_palette.get_children():
        if child is ComponentButton:
            child.queue_free()
    
    # Add components for this category
    var components = ComponentDatabase.get_components_by_category(category)
    for component in components:
        if component.can_afford():
            var button = ComponentButton.new()
            button.component = component
            button.text = component.component_name
            button.pressed.connect(func(): select_component_for_slot(component))
            component_palette.add_child(button)

func select_component_for_slot(component: Component):
    selected_slot = slot_selector.selected
    
    if ShipBuilder.can_install_component(current_ship, component, selected_slot):
        ShipBuilder.install_component(current_ship, component, selected_slot)
        update_mobile_display()
        show_success_feedback()
    else:
        show_compatibility_error(component)

func update_mobile_display():
    # Update simplified stat display
    var stats = current_ship.calculate_current_stats()
    
    for child in quick_stats.get_children():
        child.queue_free()
    
    add_stat_label("Health", "%.0f" % stats.max_health)
    add_stat_label("Speed", "%.0f" % stats.max_speed)
    add_stat_label("Weapons", "%.0f dmg" % stats.weapon_damage)
    add_stat_label("Cargo", "%.0f" % stats.cargo_capacity)

func add_stat_label(label_text: String, value_text: String):
    var hbox = HBoxContainer.new()
    
    var label = Label.new()
    label.text = label_text + ":"
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    
    var value = Label.new()
    value.text = value_text
    value.horizontal_alignment = Label.ALIGNMENT_RIGHT
    
    hbox.add_child(label)
    hbox.add_child(value)
    quick_stats.add_child(hbox)

func setup_gesture_recognition():
    # Setup touch gestures for mobile interaction
    var gesture_recognizer = GestureRecognizer.new()
    gesture_recognizer.pinch_detected.connect(on_pinch_zoom)
    gesture_recognizer.rotate_detected.connect(on_rotate_ship)
    add_child(gesture_recognizer)

func on_pinch_zoom(scale_factor: float):
    ship_viewport.scale *= scale_factor

func on_rotate_ship(rotation_delta: float):
    ship_viewport.rotation.y += rotation_delta
```

## Entity Integration

### Required Interfaces

#### IShipBuildable
```gdscript
interface IShipBuildable:
    func get_ship_hulls() -> Array[ShipHull]
    func get_available_components() -> Dictionary
    func can_build_hull(hull: ShipHull) -> bool
    func start_build_job(hull: ShipHull) -> BuildJob
    func get_building_stations() -> Array[BuildingStation]
```

#### IShipComponent
```gdscript
interface IShipComponent:
    func get_component_category() -> ComponentCategory
    func get_stat_modifiers() -> Dictionary
    func get_power_draw() -> float
    func get_weight() -> float
    func conflicts_with(other: IShipComponent) -> bool
    func get_requirements() -> Dictionary
    func can_install_on_ship(ship: PlayerShip) -> bool
```

### Entity Types

#### PlayerShip Entity
- Component-based stat calculation
- Visual model updates with installed parts
- Compatibility validation and warnings
- Save/load support for custom configurations

#### BuildingStation Entity
- Construction time acceleration
- Component quality bonuses
- Special station abilities (auto-balancing, etc.)
- Upgradeable facilities

#### BuildJob Entity
- Asynchronous construction process
- Progress tracking and interruption
- Resource consumption over time
- Quality variation based on materials

## API Reference

### Public Methods

#### ShipBuilder
```gdscript
func get_available_hulls() -> Array[ShipHull]
func get_available_components(category: ComponentCategory) -> Array[Component]
func start_ship_build(hull: ShipHull) -> bool
func cancel_ship_build(build_job: BuildJob) -> void
func install_component(ship: PlayerShip, component: Component, slot_index: int) -> bool
func remove_component(ship: PlayerShip, slot_index: int) -> Component
func calculate_ship_stats(ship: PlayerShip) -> ShipStats
func check_compatibility(ship: PlayerShip) -> Array[CompatibilityIssue]
func save_ship_design(ship: PlayerShip, design_name: String) -> void
func load_ship_design(design_name: String) -> PlayerShip
```

#### ShipHull
```gdscript
func get_slot_count() -> int
func get_slots_by_category(category: ComponentCategory) -> Array[int]
func can_accept_component(component: Component, slot_index: int) -> bool
func get_build_cost() -> Dictionary
func get_hull_modifiers() -> Dictionary
func get_visual_theme() -> String
```

### Configuration Options

#### Building Parameters
- Build time multipliers per station tier
- Component quality variation ranges
- Compatibility strictness levels
- Auto-balancing sensitivity

#### Ship Design Limits
- Maximum components per ship
- Power consumption limits
- Structural integrity requirements
- Balance enforcement levels

## Testing Strategy

### Unit Tests
- Component compatibility validation
- Stat calculation accuracy
- Build time calculations
- Resource requirement checking

### Integration Tests
- Full ship building workflows
- Component interaction effects
- Cross-platform interface consistency
- Performance with complex ship designs

### Edge Cases
- Component installation conflicts
- Power requirement violations
- Build process interruptions
- Ship design validation failures

## Reusability Guidelines

### Adapting for Other Projects

#### Mech Building (Sci-Fi)
```gdscript
# Adapt for mech customization
class MechBuilder extends ShipBuilder:
    func adapt_hull_for_mech(hull: ShipHull) -> MechHull:
        var mech_hull = MechHull.new()
        mech_hull.base_hull = hull
        mech_hull.add_ground_movement_slots()
        mech_hull.convert_flight_to_jump()
        return mech_hull
```

#### Vehicle Building (Post-Apocalyptic)
```gdscript
# Adapt for car customization
class VehicleBuilder extends ShipBuilder:
    func adapt_hull_for_vehicle(hull: ShipHull) -> VehicleHull:
        var vehicle_hull = VehicleHull.new()
        vehicle_hull.base_hull = hull
        vehicle_hull.add_wheel_slots()
        vehicle_hull.add_engine_slots()
        vehicle_hull.convert_shields_to_armor()
        return vehicle_hull
```

#### Spaceship Building (4X Strategy)
```gdscript
# Add fleet-building mechanics
class FleetShipBuilder extends ShipBuilder:
    @export var fleet_size_limit: int = 12
    
    func build_fleet_design(design_name: String, quantity: int) -> Array[PlayerShip]:
        var design = load_ship_design(design_name)
        var fleet: Array[PlayerShip] = []
        
        for i in range(min(quantity, fleet_size_limit)):
            var ship = design.duplicate()
            ship.fleet_id = generate_fleet_id()
            fleet.append(ship)
        
        return fleet
```

### Extension Mechanisms

#### Custom Hull Types
```gdscript
class CustomHullGenerator:
    var base_hull_templates: Dictionary = {}
    var modification_rules: Dictionary = {}
    
    func generate_custom_hull(requirements: Dictionary) -> ShipHull:
        var base_template = select_base_template(requirements)
        var custom_hull = base_template.duplicate()
        
        # Apply modifications
        for modification in requirements.get("modifications", []):
            apply_modification(custom_hull, modification)
        
        # Validate final hull
        if validate_custom_hull(custom_hull):
            return custom_hull
        
        return null
    
    func apply_modification(hull: ShipHull, modification: Dictionary):
        var mod_type = modification.get("type")
        var mod_value = modification.get("value")
        
        match mod_type:
            "add_slots":
                add_slots_to_hull(hull, mod_value)
            "modify_stats":
                modify_hull_stats(hull, mod_value)
            "change_theme":
                hull.visual_theme = mod_value
```

#### Advanced Balancing System
```gdscript
class ShipBalancer:
    var balance_rules: Dictionary = {}
    var target_values: Dictionary = {}
    
    func balance_ship_design(ship: PlayerShip) -> Dictionary:
        var imbalances = find_imbalances(ship)
        var suggestions = generate_balance_suggestions(imbalances)
        var auto_fixes = calculate_auto_balancing(ship)
        
        return {
            "imbalances": imbalances,
            "suggestions": suggestions,
            "auto_fixes": auto_fixes
        }
    
    func find_imbalances(ship: PlayerShip) -> Array[Imbalance]:
        var imbalances: Array[Imbalance] = []
        
        # Check power balance
        var power_ratio = ship.get_power_generation() / ship.get_power_consumption()
        if power_ratio < 0.8:
            imbalances.append(Imbalance.new("power_deficit", power_ratio))
        
        # Check combat balance
        var combat_score = ship.get_combat_effectiveness()
        if combat_score < target_values.get("min_combat_score", 10):
            imbalances.append(Imbalance.new("weak_offense", combat_score))
        
        # Check mobility balance
        var mobility_score = ship.get_mobility_score()
        if mobility_score > target_values.get("max_mobility_score", 100):
            imbalances.append(Imbalance.new("overpowered_mobility", mobility_score))
        
        return imbalances
    
    func generate_balance_suggestions(imbalances: Array[Imbalance]) -> Array[String]:
        var suggestions: Array[String] = []
        
        for imbalance in imbalances:
            match imbalance.type:
                "power_deficit":
                    suggestions.append("Install more power generators or reduce power-hungry components")
                "weak_offense":
                    suggestions.append("Add weapon components or upgrade existing weapons")
                "overpowered_mobility":
                    suggestions.append("Consider adding weight (cargo) or reducing speed components")
        
        return suggestions
```

This ship building system provides a deep, rewarding culmination of the entire resource loop, offering players extensive creative freedom while maintaining balance and technical feasibility.