# Mining System Game Design Document

## Executive Summary

The **Mining System** enables players to extract valuable resources from asteroids and environmental objects in Space Rogue: Starbound Odyssey, providing the raw materials foundation for the crafting and ship building systems. It features multiple mining methods with varying efficiency, risk/reward tradeoffs, and platform-optimized controls.

**Key Features:**
- Multiple mining methods (beam, explosive, manual)
- Resource rarity and quality systems
- Environmental interaction mechanics
- Risk-based mining with potential hazards
- Performance-optimized resource extraction
- Platform-adaptive controls (PC precision, mobile touch)

**Integration Points:**
- Provides raw materials to Crafting System
- Works with Movement System for positioning
- Affects Combat System through mining hazards
- Integrates with Visual Effects for mining animations
- Contributes to Progression System through mining skills

## System Architecture

### Core Components

#### MiningController (Main Coordinator)
```gdscript
class_name MiningController
extends Node

@export var max_concurrent_mining: int = 3
@export var mining_range: float = 50.0
@export var beam_energy_cost: float = 2.0  # per second

var active_mining_operations: Array[MiningOperation] = []
var mining_inventory: Dictionary = {}  # resource_type -> quantity
var player_ship: PlayerShip

func _ready():
    player_ship = get_parent()

func start_mining(target: MiningTarget, method: MiningMethod) -> bool:
    if active_mining_operations.size() >= max_concurrent_mining:
        return false
    
    if not can_reach_target(target):
        return false
    
    var operation = MiningOperation.new(target, method, self)
    active_mining_operations.append(operation)
    
    match method:
        MiningMethod.BEAM:
            start_beam_mining(operation)
        MiningMethod.EXPLOSIVE:
            start_explosive_mining(operation)
        MiningMethod.MANUAL:
            start_manual_mining(operation)
    
    return true

func update_mining_operations(delta: float):
    for operation in active_mining_operations:
        operation.update(delta)
        
        if operation.is_complete():
            complete_mining_operation(operation)
        elif operation.has_failed():
            fail_mining_operation(operation)

func complete_mining_operation(operation: MiningOperation):
    var resources = operation.target.extract_resources(operation.method)
    add_resources_to_inventory(resources)
    
    active_mining_operations.erase(operation)
    operation.cleanup()
    
    # Award experience and check for bonuses
    award_mining_experience(operation)
    check_for_resource_bonuses(resources)

func fail_mining_operation(operation: MiningOperation):
    active_mining_operations.erase(operation)
    operation.cleanup()
    
    # Handle failure consequences
    handle_mining_failure(operation.failure_reason)
```

#### MiningTarget (Resource Source)
```gdscript
class_name MiningTarget
extends StaticBody3D

@export var resource_composition: Dictionary  # resource_type -> {quantity, quality, rarity}
@export var mining_difficulty: float = 1.0
@export var stability: float = 1.0  # Chance of hazardous events
@export var size_category: SizeCategory

enum SizeCategory {
    SMALL,      # Quick mining, low yield
    MEDIUM,     # Balanced time/yield
    LARGE,      # Long mining, high yield
    UNIQUE      # Special properties
}

var current_integrity: float = 1.0
var mining_operations: Array[MiningOperation] = []

func can_be_mined(method: MiningMethod) -> bool:
    match method:
        MiningMethod.BEAM:
            return true  # Most versatile
        MiningMethod.EXPLOSIVE:
            return size_category != SizeCategory.UNIQUE  # Risk of destruction
        MiningMethod.MANUAL:
            return size_category in [SizeCategory.SMALL, SizeCategory.MEDIUM]
    return false

func calculate_mining_time(method: MiningMethod) -> float:
    var base_time = 5.0  # Base mining time
    
    # Size modifier
    match size_category:
        SizeCategory.SMALL: base_time *= 0.5
        SizeCategory.LARGE: base_time *= 2.0
        SizeCategory.UNIQUE: base_time *= 3.0
    
    # Method modifier
    match method:
        MiningMethod.BEAM: base_time *= 0.8
        MiningMethod.EXPLOSIVE: base_time *= 0.3
        MiningMethod.MANUAL: base_time *= 1.5
    
    # Difficulty modifier
    base_time *= mining_difficulty
    
    return base_time

func extract_resources(method: MiningMethod) -> Dictionary:
    var extracted = {}
    var extraction_efficiency = get_extraction_efficiency(method)
    
    for resource_type in resource_composition:
        var resource_data = resource_composition[resource_type]
        var base_quantity = resource_data.quantity
        var actual_quantity = int(base_quantity * extraction_efficiency * randf_range(0.8, 1.2))
        
        extracted[resource_type] = {
            "quantity": actual_quantity,
            "quality": resource_data.quality,
            "rarity": resource_data.rarity
        }
    
    # Reduce remaining resources
    current_integrity -= extraction_efficiency
    if current_integrity <= 0:
        queue_free()  # Asteroid depleted
    
    return extracted

func get_extraction_efficiency(method: MiningMethod) -> float:
    match method:
        MiningMethod.BEAM: return 0.9  # High efficiency
        MiningMethod.EXPLOSIVE: return 0.6  # Lower due to waste
        MiningMethod.MANUAL: return 0.4  # Labor intensive
    return 0.5
```

#### MiningOperation (Individual Mining Process)
```gdscript
class_name MiningOperation
extends Node

enum OperationState {
    INITIALIZING,
    ACTIVE,
    COMPLETING,
    FAILED
}

var target: MiningTarget
var method: MiningMethod
var controller: MiningController
var state: OperationState = OperationState.INITIALIZING
var progress: float = 0.0
var total_time: float
var failure_reason: String = ""

func _init(target_obj: MiningTarget, mining_method: MiningMethod, mining_controller: MiningController):
    target = target_obj
    method = mining_method
    controller = mining_controller
    total_time = target.calculate_mining_time(method)
    
    target.mining_operations.append(self)

func update(delta: float):
    match state:
        OperationState.INITIALIZING:
            initialize_operation()
        OperationState.ACTIVE:
            progress_operation(delta)
        OperationState.COMPLETING:
            complete_operation()
        OperationState.FAILED:
            handle_failure()

func initialize_operation():
    match method:
        MiningMethod.BEAM:
            # Start beam visual effect
            create_mining_beam_effect()
        MiningMethod.EXPLOSIVE:
            # Prepare explosive
            arm_explosive_device()
        MiningMethod.MANUAL:
            # Start EVA sequence
            begin_manual_mining()
    
    state = OperationState.ACTIVE

func progress_operation(delta: float):
    progress += delta
    
    # Check for random events
    if randf() < target.stability * delta * 0.1:
        trigger_random_event()
    
    # Update visual effects
    update_mining_effects(progress / total_time)
    
    if progress >= total_time:
        state = OperationState.COMPLETING

func trigger_random_event():
    var event_roll = randf()
    
    if event_roll < 0.1:  # 10% chance
        # Asteroid instability
        failure_reason = "asteroid_instability"
        state = OperationState.FAILED
    elif event_roll < 0.15:  # 5% chance
        # Bonus resource discovery
        discover_bonus_resource()
    elif event_roll < 0.2:  # 5% chance
        # Equipment malfunction
        if method == MiningMethod.BEAM:
            failure_reason = "beam_overheat"
            state = OperationState.FAILED

func is_complete() -> bool:
    return state == OperationState.COMPLETING

func has_failed() -> bool:
    return state == OperationState.FAILED

func cleanup():
    target.mining_operations.erase(self)
    remove_mining_effects()
    queue_free()
```

### Mining Methods

#### Beam Mining (Primary PC Method)
- **Precision Control**: Mouse-aimed mining beam
- **Continuous Operation**: Hold to mine, variable power levels
- **Energy Management**: Consumes ship energy
- **High Efficiency**: Best resource yield
- **Low Risk**: Minimal environmental hazards

#### Explosive Mining (High-Risk Method)
- **Area Effect**: Damages multiple nearby asteroids
- **Quick Results**: Fast resource extraction
- **Resource Waste**: Lower efficiency due to destruction
- **Dangerous**: Can damage nearby ships or create debris
- **Chain Reactions**: May trigger asteroid field instability

#### Manual Mining (Mobile-Friendly)
- **EVA Operations**: Spacewalk-style resource collection
- **Mini-Game Elements**: Timing-based collection mechanics
- **Low Efficiency**: Small resource amounts per operation
- **Safe**: No risk to ship or environment
- **Skill-Based**: Player dexterity affects yield

### Resource System

#### Resource Categories
- **Metals**: Iron, titanium, rare earth elements
- **Crystals**: Energy crystals, data crystals
- **Gases**: Fuel gases, reactive compounds
- **Organics**: Alien biomass, rare compounds
- **Exotics**: Quantum materials, ancient artifacts

#### Quality & Rarity System
```gdscript
enum ResourceQuality {
    POOR,       # 50% base value
    STANDARD,   # 100% base value
    PREMIUM,    # 150% base value
    PERFECT     # 200% base value
}

enum ResourceRarity {
    COMMON,     # Easy to find
    UNCOMMON,   # Moderate availability
    RARE,       # Hard to find
    EPIC,       # Very rare
    LEGENDARY   # Extremely rare
}
```

## Technical Implementation

### Godot Node Structure
```
MiningSystem (Node)
├── MiningController
├── ResourceDatabase (Resource)
├── MiningBeam (Node3D)
├── ExplosiveDevice (RigidBody3D)
├── MiningTargets (Node3D)
│   ├── AsteroidField (Node3D)
│   ├── SpaceDebris (Node3D)
│   └── PlanetaryResources (Node3D)
└── MiningUI (Control)
    ├── MiningHUD
    ├── ResourceScanner
    └── MiningControls
```

### Platform-Specific Controls

#### PC Controls
- **Beam Mining**: Right-click to aim, hold left-click to mine
- **Explosive Mining**: Select target, choose explosive type, launch
- **Manual Mining**: Approach target, initiate EVA sequence
- **Multi-Target**: Queue multiple mining operations

#### Mobile Controls
- **Beam Mining**: Virtual joystick for aiming, tap-and-hold to mine
- **Explosive Mining**: Touch target, swipe to select explosive power
- **Manual Mining**: Tap target, follow on-screen timing prompts
- **Auto-Mine**: Toggle automatic mining of nearby targets

### Key Scripts

#### MiningBeam.gd (PC)
```gdscript
class_name MiningBeam
extends Node3D

@export var beam_length: float = 50.0
@export var beam_width: float = 2.0
@export var mining_power: float = 10.0
@export var energy_cost: float = 5.0

var target_position: Vector3
var is_active: bool = false
var current_target: MiningTarget

@onready var beam_mesh: MeshInstance3D = $BeamMesh
@onready var particles: GPUParticles3D = $BeamParticles

func _ready():
    deactivate_beam()

func activate_beam(target_pos: Vector3):
    target_position = target_pos
    is_active = true
    
    # Update beam visuals
    update_beam_visuals()
    
    # Check for valid target
    current_target = find_mining_target_at_position(target_pos)
    
    if current_target:
        start_mining_target(current_target)
    else:
        # Mining empty space - reduced efficiency
        mine_empty_space()

func deactivate_beam():
    is_active = false
    current_target = null
    beam_mesh.visible = false
    particles.emitting = false

func update_beam_visuals():
    if not is_active:
        return
    
    # Update beam mesh to connect ship to target
    var beam_direction = (target_position - global_position).normalized()
    var beam_distance = global_position.distance_to(target_position)
    
    # Scale and rotate beam mesh
    beam_mesh.scale = Vector3(beam_width, beam_width, beam_distance)
    beam_mesh.look_at(target_position, Vector3.UP)
    
    beam_mesh.visible = true
    particles.emitting = true

func _process(delta: float):
    if is_active:
        # Consume energy
        consume_energy(delta)
        
        # Update beam position if ship is moving
        update_beam_targeting()
        
        # Check for target depletion
        if current_target and current_target.current_integrity <= 0:
            complete_mining_operation()
```

#### MiningTouchControls.gd (Mobile)
```gdscript
class_name MiningTouchControls
extends Control

@export var joystick_sensitivity: float = 2.0
@export var auto_mine_range: float = 30.0

var virtual_joystick: VirtualJoystick
var mining_targets: Array[MiningTarget] = []
var selected_target: MiningTarget
var is_mining: bool = false

func _ready():
    setup_touch_controls()
    connect_signals()

func setup_touch_controls():
    # Create virtual mining controls
    virtual_joystick = VirtualJoystick.new()
    virtual_joystick.position = Vector2(50, get_viewport_rect().size.y - 150)
    add_child(virtual_joystick)
    
    # Mining buttons
    create_mining_method_buttons()

func _process(delta: float):
    update_targeting()
    
    if is_mining and selected_target:
        continue_mining_operation(delta)

func update_targeting():
    # Update virtual cursor position based on joystick
    var joystick_input = virtual_joystick.get_output()
    var cursor_position = get_viewport_rect().size / 2 + joystick_input * 100
    
    # Cast ray from camera through cursor
    var camera = get_viewport().get_camera_3d()
    var ray_origin = camera.project_ray_origin(cursor_position)
    var ray_direction = camera.project_ray_normal(cursor_position)
    
    # Find mining targets in ray path
    selected_target = find_target_along_ray(ray_origin, ray_direction)
    
    # Update targeting visuals
    update_targeting_display(selected_target)

func start_mining_operation(method: MiningMethod):
    if not selected_target or not selected_target.can_be_mined(method):
        return
    
    is_mining = true
    MiningController.start_mining(selected_target, method)
    
    # Show mining progress UI
    show_mining_progress(method)

func create_mining_method_buttons():
    var button_container = HBoxContainer.new()
    button_container.position = Vector2(get_viewport_rect().size.x - 200, 50)
    add_child(button_container)
    
    # Beam mining button
    var beam_button = Button.new()
    beam_button.text = "BEAM"
    beam_button.pressed.connect(func(): start_mining_operation(MiningMethod.BEAM))
    button_container.add_child(beam_button)
    
    # Explosive mining button
    var explosive_button = Button.new()
    explosive_button.text = "BLAST"
    explosive_button.pressed.connect(func(): start_mining_operation(MiningMethod.EXPLOSIVE))
    button_container.add_child(explosive_button)
    
    # Manual mining button
    var manual_button = Button.new()
    manual_button.text = "EVA"
    manual_button.pressed.connect(func(): start_mining_operation(MiningMethod.MANUAL))
    button_container.add_child(manual_button)
```

## Entity Integration

### Required Interfaces

#### IMiningTarget
```gdscript
interface IMiningTarget:
    func can_be_mined(method: MiningMethod) -> bool
    func calculate_mining_time(method: MiningMethod) -> float
    func extract_resources(method: MiningMethod) -> Dictionary
    func get_mining_difficulty() -> float
    func on_mining_started(method: MiningMethod) -> void
    func on_mining_completed(method: MiningMethod, resources: Dictionary) -> void
    func on_mining_failed(method: MiningMethod, reason: String) -> void
```

#### IMiningEntity
```gdscript
interface IMiningEntity:
    func get_mining_controller() -> MiningController
    func get_mining_capabilities() -> Array[MiningMethod]
    func can_perform_mining_operation(target: MiningTarget, method: MiningMethod) -> bool
    func get_mining_skill_level() -> float
    func consume_mining_energy(amount: float) -> bool
```

### Entity Types

#### Asteroid Entity
- Multiple size categories with different yields
- Resource composition based on asteroid type
- Stability mechanics for risk/reward
- Visual depletion as resources are extracted

#### Space Debris Entity
- Salvageable ship parts and equipment
- Variable stability and hazard levels
- Quick mining with potential bonuses
- Environmental storytelling elements

#### Planetary Resource Entity
- Surface mining mechanics
- Atmospheric interference effects
- High-value rare resources
- Exploration and discovery elements

## API Reference

### Public Methods

#### MiningController
```gdscript
func start_mining(target: MiningTarget, method: MiningMethod) -> bool
func stop_mining(target: MiningTarget) -> void
func get_mining_progress(target: MiningTarget) -> float
func get_available_mining_targets() -> Array[MiningTarget]
func get_resource_inventory() -> Dictionary
func upgrade_mining_capability(method: MiningMethod, upgrade_level: int) -> void
func calculate_mining_efficiency(method: MiningMethod, target: MiningTarget) -> float
```

#### MiningTarget
```gdscript
func get_resource_composition() -> Dictionary
func get_mining_difficulty() -> float
func get_stability_rating() -> float
func is_depleted() -> bool
func get_remaining_resources() -> Dictionary
func apply_environmental_effect(effect: MiningEffect) -> void
```

### Configuration Options

#### Mining Parameters
- Beam power levels and energy costs
- Explosive yield and safety radii
- Manual mining success rates and timing
- Resource quality multipliers

#### Environmental Settings
- Asteroid field density and composition
- Hazard spawn rates and effects
- Planetary mining restrictions
- Space weather impact on mining

## Testing Strategy

### Unit Tests
- Mining method calculations and validations
- Resource extraction algorithms
- Energy consumption mechanics
- Target depletion logic

### Integration Tests
- Full mining workflows from targeting to extraction
- Cross-system interactions (combat during mining)
- Platform-specific control schemes
- Performance with multiple concurrent operations

### Edge Cases
- Mining target destruction during operation
- Energy depletion during mining
- Environmental hazard triggers
- Resource inventory capacity limits

## Reusability Guidelines

### Adapting for Other Projects

#### 2D Mining Game
```gdscript
# Convert to 2D mining mechanics
func calculate_2d_mining_path(surface_points: Array[Vector2]) -> Array[Vector2]:
    # Calculate optimal mining path along surface
    var mining_path = []
    for point in surface_points:
        if can_mine_point_2d(point):
            mining_path.append(point)
    return mining_path
```

#### Underwater Mining
```gdscript
# Add pressure and depth mechanics
class UnderwaterMiningController extends MiningController:
    @export var max_depth: float = 1000.0
    @export var pressure_damage_rate: float = 0.1
    
    func calculate_depth_pressure(depth: float) -> float:
        return depth / max_depth
    
    func apply_pressure_damage(miner: MiningEntity, depth: float):
        var pressure = calculate_depth_pressure(depth)
        var damage = pressure * pressure_damage_rate
        miner.take_environmental_damage(damage)
```

#### Magical Mining (Fantasy Setting)
```gdscript
# Add magical mining effects
class MagicalMiningController extends MiningController:
    var mana_cost_multiplier: float = 1.5
    
    func cast_mining_spell(spell_type: String, target: MiningTarget):
        match spell_type:
            "transmutation":
                # Convert resources to more valuable types
                transmute_resources(target)
            "conjuration":
                # Create resources from nothing
                conjure_resources(target)
            "divination":
                # Reveal hidden resource deposits
                reveal_hidden_deposits(target)
```

### Extension Mechanisms

#### Custom Mining Methods
```gdscript
class CustomMiningMethod:
    var method_name: String
    var energy_cost: float
    var mining_time: float
    var efficiency: float
    var risk_factor: float
    var required_tools: Array[String]
    
    func can_use_method(miner: MiningEntity) -> bool:
        for tool in required_tools:
            if not miner.has_tool(tool):
                return false
        return true
    
    func execute_mining(target: MiningTarget, miner: MiningEntity):
        # Custom mining logic implementation
        pass
```

#### Resource Processing Pipeline
```gdscript
class ResourceProcessingPipeline:
    var processing_stages: Array[ProcessingStage] = []
    
    func process_raw_resource(raw_resource: Dictionary) -> Dictionary:
        var processed_resource = raw_resource.duplicate()
        
        for stage in processing_stages:
            processed_resource = stage.process(processed_resource)
        
        return processed_resource
    
    func add_processing_stage(stage: ProcessingStage):
        processing_stages.append(stage)
```

This mining system provides a comprehensive resource extraction framework that scales from simple mobile touch mining to complex PC beam operations, while integrating seamlessly with the broader crafting and exploration systems.