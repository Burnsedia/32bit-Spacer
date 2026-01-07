# Scavenging System Game Design Document

## Executive Summary

The **Scavenging System** enables players to salvage valuable components and resources from derelict ships and space debris in Space Rogue: Starbound Odyssey, providing an alternative resource acquisition method to mining. It features risk-reward mechanics, environmental storytelling, and platform-optimized interactions that complement the mining system.

**Key Features:**
- Risk-based salvage operations with time pressure
- Component extraction from derelict vessels
- Environmental hazard integration
- Quality-based salvage outcomes
- Narrative integration through ship logs and discoveries
- Platform-adaptive mechanics (PC precision, mobile touch)

**Integration Points:**
- Provides ship parts to Ship Building System
- Supplies components to Crafting System
- Works with Combat System for hazard encounters
- Integrates with Progression System for skill progression
- Affects UI System with salvage mini-games

## System Architecture

### Core Components

#### ScavengingController (Main Coordinator)
```gdscript
class_name ScavengingController
extends Node

@export var max_scavenging_range: float = 25.0
@export var base_scavenging_time: float = 8.0
@export var hazard_check_frequency: float = 2.0  # seconds

var active_scavenging: Array[ScavengingOperation] = []
var discovered_sites: Array[ScavengingSite] = []
var player_scavenging_skill: float = 1.0

func start_scavenging(site: ScavengingSite) -> bool:
    if active_scavenging.size() >= 1:  # One at a time
        return false
    
    if not can_reach_site(site):
        return false
    
    var operation = ScavengingOperation.new(site, self)
    active_scavenging.append(operation)
    
    # Platform-specific initialization
    if OS.get_name() in ["Android", "iOS"]:
        initialize_mobile_scavenging(operation)
    else:
        initialize_pc_scavenging(operation)
    
    return true

func update_scavenging(delta: float):
    for operation in active_scavenging:
        operation.update(delta)
        
        if operation.is_complete():
            complete_scavenging(operation)
        elif operation.has_failed():
            fail_scavenging(operation)

func complete_scavenging(operation: ScavengingOperation):
    var results = operation.site.extract_components(operation.quality_rating)
    add_components_to_inventory(results.components)
    
    # Award experience and check discoveries
    award_scavenging_experience(results.quality)
    check_for_story_discoveries(results.discoveries)
    
    active_scavenging.erase(operation)
    operation.cleanup()

func fail_scavenging(operation: ScavengingOperation):
    active_scavenging.erase(operation)
    operation.cleanup()
    
    # Handle failure consequences
    apply_failure_penalties(operation.failure_reason)

func discover_scavenging_sites(sector_coords: Vector2i):
    # Generate sites based on sector seed
    var sector_seed = CoordinateSeedGenerator.coords_to_seed(sector_coords)
    var rng = RandomNumberGenerator.new()
    rng.seed = sector_seed
    
    var site_count = rng.randi_range(2, 5)
    
    for i in range(site_count):
        var site = generate_random_scavenging_site(rng)
        site.position = generate_random_position_in_sector(rng)
        discovered_sites.append(site)
```

#### ScavengingSite (Salvage Location)
```gdscript
class_name ScavengingSite
extends Node3D

@export var site_type: SiteType
@export var difficulty_level: float = 1.0
@export var hazard_level: float = 0.5
@export var story_significance: int = 0  # 0-5 scale

enum SiteType {
    DERELICT_SHIP,
    SPACE_DEBRIS,
    ABANDONED_STATION,
    CRASHED_PROBE,
    ANCIENT_WRECK
}

var component_inventory: Dictionary = {}  # component_type -> {quantity, quality, condition}
var story_elements: Array[StoryElement] = []
var scavenged_percentage: float = 0.0
var hazard_triggers: Array[HazardTrigger] = []

func _ready():
    initialize_components()
    setup_hazards()

func initialize_components():
    match site_type:
        SiteType.DERELICT_SHIP:
            initialize_ship_components()
        SiteType.SPACE_DEBRIS:
            initialize_debris_components()
        SiteType.ABANDONED_STATION:
            initialize_station_components()
        SiteType.CRASHED_PROBE:
            initialize_probe_components()
        SiteType.ANCIENT_WRECK:
            initialize_ancient_components()

func initialize_ship_components():
    # Military ship components
    component_inventory["engine_core"] = {"quantity": 1, "quality": 0.8, "condition": 0.6}
    component_inventory["shield_emitter"] = {"quantity": 2, "quality": 0.7, "condition": 0.5}
    component_inventory["weapon_mount"] = {"quantity": 1, "quality": 0.9, "condition": 0.7}
    
    # Add story elements
    story_elements.append(StoryElement.new("captains_log", "emergency transmission"))
    story_elements.append(StoryElement.new("black_box", "final moments recording"))

func extract_components(quality_rating: float) -> Dictionary:
    var extracted = {"components": {}, "quality": quality_rating, "discoveries": []}
    
    for component_type in component_inventory:
        var component_data = component_inventory[component_type]
        var extract_chance = quality_rating * (1.0 - component_data.condition * 0.5)
        
        if randf() < extract_chance:
            var quantity = component_data.quantity
            if randf() < 0.3:  # 30% chance for partial extraction
                quantity = randi_range(1, component_data.quantity)
            
            extracted.components[component_type] = {
                "quantity": quantity,
                "quality": component_data.quality * quality_rating,
                "condition": component_data.condition
            }
            
            # Mark as scavenged
            scavenged_percentage += (quantity / component_data.quantity) * (1.0 / component_inventory.size())
    
    # Extract story discoveries
    for story_element in story_elements:
        if randf() < quality_rating * 0.8:
            extracted.discoveries.append(story_element)
    
    # Trigger random hazard if not careful
    if randf() < hazard_level * (1.0 - quality_rating):
        trigger_random_hazard()
    
    return extracted

func trigger_random_hazard():
    var hazard = hazard_triggers.pick_random()
    
    match hazard.type:
        "explosion":
            create_explosion_effect()
            damage_nearby_entities(hazard.severity)
        "radiation":
            apply_radiation_effect(hazard.severity)
        "hostile_entity":
            spawn_defensive_entity(hazard.severity)
```

#### ScavengingOperation (Active Salvage Process)
```gdscript
class_name ScavengingOperation
extends Node

enum OperationState {
    APPROACHING,
    SCANNING,
    EXTRACTING,
    COMPLETING,
    FAILED
}

var site: ScavengingSite
var controller: ScavengingController
var state: OperationState = OperationState.APPROACHING
var progress: float = 0.0
var total_time: float
var quality_rating: float = 0.5  # 0.0 to 1.0
var hazard_timer: float = 0.0
var failure_reason: String = ""

func _init(scavenging_site: ScavengingSite, scavenging_controller: ScavengingController):
    site = scavenging_site
    controller = scavenging_controller
    total_time = calculate_scavenging_time()

func calculate_scavenging_time() -> float:
    var base_time = 10.0
    base_time *= site.difficulty_level
    base_time *= (2.0 - controller.player_scavenging_skill)  # Better skill = faster
    return base_time

func update(delta: float):
    hazard_timer += delta
    
    # Check for hazards
    if hazard_timer >= controller.hazard_check_frequency:
        check_for_hazards()
        hazard_timer = 0.0
    
    match state:
        OperationState.APPROACHING:
            handle_approach(delta)
        OperationState.SCANNING:
            handle_scanning(delta)
        OperationState.EXTRACTING:
            handle_extraction(delta)

func handle_approach(delta: float):
    # Move toward site (handled by movement system)
    var distance = global_position.distance_to(site.global_position)
    
    if distance < 5.0:  # Close enough
        state = OperationState.SCANNING
        progress = 0.0

func handle_scanning(delta: float):
    progress += delta * 2.0  # Fast scanning
    
    if progress >= 2.0:  # 2 second scan
        state = OperationState.EXTRACTING
        progress = 0.0
        quality_rating = calculate_initial_quality()

func handle_extraction(delta: float):
    progress += delta
    
    # Quality can improve with good timing
    update_quality_rating(delta)
    
    if progress >= total_time:
        state = OperationState.COMPLETING

func calculate_initial_quality() -> float:
    # Base quality from player skill
    var base_quality = controller.player_scavenging_skill
    
    # Site difficulty modifier
    base_quality *= (2.0 - site.difficulty_level) / 2.0
    
    # Random variation
    base_quality *= randf_range(0.7, 1.3)
    
    return clamp(base_quality, 0.1, 1.0)

func update_quality_rating(delta: float):
    # Quality improves with careful, steady work
    var quality_change = delta * 0.1 * (1.0 - site.hazard_level)
    quality_rating = clamp(quality_rating + quality_change, 0.0, 1.0)

func check_for_hazards():
    var hazard_roll = randf()
    var hazard_threshold = site.hazard_level * (1.0 - quality_rating * 0.5)
    
    if hazard_roll < hazard_threshold:
        trigger_hazard()

func trigger_hazard():
    var hazard_types = ["structural_failure", "radiation_leak", "defensive_systems", "time_pressure"]
    failure_reason = hazard_types.pick_random()
    state = OperationState.FAILED

func is_complete() -> bool:
    return state == OperationState.COMPLETING

func has_failed() -> bool:
    return state == OperationState.FAILED

func cleanup():
    # Remove visual effects, reset timers
    queue_free()
```

### Scavenging Methods

#### PC Scavenging (Precision-Focused)
- **Manual Control**: Precise EVA operations with full 3D movement
- **Tool Selection**: Choose specific tools for different component types
- **Risk Management**: Monitor hazard indicators and abort if needed
- **Quality Control**: Careful extraction maintains component integrity

#### Mobile Scavenging (Touch-Optimized)
- **Tap Extraction**: Touch components to salvage them
- **Timing Mini-Games**: Tap at the right moment for better quality
- **Gesture Controls**: Swipe to avoid hazards, pinch to zoom
- **Auto-Assist**: Optional automatic quality maintenance

### Story Integration

#### Narrative Discoveries
```gdscript
class StoryElement:
    var element_type: String
    var content: String
    var significance: int  # 1-5 scale
    var follow_up_quests: Array[String]
    
    func get_formatted_content() -> String:
        match element_type:
            "captains_log":
                return format_log_entry(content)
            "black_box":
                return format_recording(content)
            "personal_effects":
                return format_artifacts(content)
            "system_logs":
                return format_technical_logs(content)
```

#### Environmental Storytelling
- **Ship Histories**: Each derelict vessel has a unique backstory
- **Crew Fates**: Discover what happened to the previous occupants
- **Sector Lore**: Connect discoveries across multiple scavenging sites
- **Moral Choices**: Some discoveries present ethical dilemmas

## Technical Implementation

### Godot Node Structure
```
ScavengingSystem (Node)
├── ScavengingController
├── SiteGenerator
├── ScavengingOperations (Node)
│   ├── ActiveOperations (Node)
│   └── CompletedOperations (Node)
├── ScavengingSites (Node3D)
│   ├── DerelictShips (Node3D)
│   ├── SpaceDebris (Node3D)
│   └── AbandonedStations (Node3D)
└── ScavengingUI (CanvasLayer)
    ├── SiteScanner
    ├── SalvageInterface
    └── HazardWarnings
```

### Platform-Specific Interfaces

#### PC Scavenging Interface
```gdscript
class PCScavengingInterface extends Control:
    @onready var progress_bar: ProgressBar = $ProgressBar
    @onready var quality_indicator: Label = $QualityIndicator
    @onready var hazard_warnings: VBoxContainer = $HazardWarnings
    
    var current_operation: ScavengingOperation
    
    func _ready():
        connect_operation_signals()
    
    func update_display():
        if current_operation:
            progress_bar.value = current_operation.progress / current_operation.total_time
            quality_indicator.text = "Quality: %.1f%%" % (current_operation.quality_rating * 100)
            
            # Update hazard warnings
            update_hazard_display()
    
    func update_hazard_display():
        # Clear existing warnings
        for child in hazard_warnings.get_children():
            child.queue_free()
        
        # Add current hazard warnings
        for hazard in current_operation.site.hazard_triggers:
            if hazard.is_active:
                var warning = create_hazard_warning(hazard)
                hazard_warnings.add_child(warning)
    
    func create_hazard_warning(hazard: HazardTrigger) -> Panel:
        var panel = Panel.new()
        var label = Label.new()
        label.text = hazard.description
        panel.add_child(label)
        return panel
    
    func _input(event):
        if event.is_action_pressed("abort_scavenging"):
            abort_current_operation()
```

#### Mobile Scavenging Interface
```gdscript
class MobileScavengingInterface extends Control:
    @onready var progress_circle: TextureProgressBar = $ProgressCircle
    @onready var quality_gauge: TextureProgressBar = $QualityGauge
    @onready var hazard_alerts: VBoxContainer = $HazardAlerts
    
    var touch_zones: Dictionary = {}
    
    func _ready():
        setup_touch_zones()
        connect_mobile_signals()
    
    func setup_touch_zones():
        # Create interactive touch zones for components
        touch_zones["engine_room"] = create_touch_zone("Engine Components", Vector2(100, 200))
        touch_zones["cargo_hold"] = create_touch_zone("Cargo Materials", Vector2(300, 200))
        touch_zones["bridge"] = create_touch_zone("Data Systems", Vector2(200, 100))
    
    func create_touch_zone(component_type: String, position: Vector2) -> TouchZone:
        var zone = TouchZone.new()
        zone.component_type = component_type
        zone.position = position
        zone.size = Vector2(80, 80)
        zone.pressed.connect(func(): salvage_component(component_type))
        add_child(zone)
        return zone
    
    func salvage_component(component_type: String):
        # Start mini-game for component extraction
        start_extraction_mini_game(component_type)
    
    func start_extraction_mini_game(component_type: String):
        var mini_game = ExtractionMiniGame.new()
        mini_game.component_type = component_type
        mini_game.completed.connect(on_mini_game_completed)
        add_child(mini_game)
    
    func on_mini_game_completed(success: bool, quality: float, component_type: String):
        if success:
            ScavengingController.extract_component(component_type, quality)
            show_success_feedback()
        else:
            show_failure_feedback()
```

### Key Scripts

#### ExtractionMiniGame.gd (Mobile)
```gdscript
class_name ExtractionMiniGame
extends Control

signal completed(success: bool, quality: float, component_type: String)

@export var component_type: String
@export var game_duration: float = 3.0

var target_zones: Array[Rect2] = []
var player_inputs: Array[Vector2] = []
var quality_score: float = 0.0
var time_remaining: float = 0.0

func _ready():
    setup_mini_game()
    time_remaining = game_duration

func setup_mini_game():
    # Create random target zones
    for i in range(3):
        var zone = Rect2(
            randf_range(50, get_viewport_rect().size.x - 100),
            randf_range(100, get_viewport_rect().size.y - 200),
            60, 60
        )
        target_zones.append(zone)
        
        # Create visual zone
        var zone_visual = ColorRect.new()
        zone_visual.color = Color(0, 1, 0, 0.3)
        zone_visual.position = zone.position
        zone_visual.size = zone.size
        add_child(zone_visual)

func _process(delta: float):
    time_remaining -= delta
    
    if time_remaining <= 0:
        calculate_final_quality()
        completed.emit(quality_score > 0.5, quality_score, component_type)
        queue_free()

func _input(event):
    if event is InputEventScreenTouch and event.pressed:
        player_inputs.append(event.position)
        
        # Check if touch hit a target zone
        for i in range(target_zones.size()):
            if target_zones[i].has_point(event.position):
                quality_score += 0.3  # Good hit
                show_hit_feedback(event.position)
                target_zones.remove_at(i)
                break

func calculate_final_quality() -> float:
    var base_quality = quality_score
    
    # Bonus for speed
    var speed_bonus = (game_duration - time_remaining) / game_duration
    base_quality += speed_bonus * 0.2
    
    # Clamp to valid range
    return clamp(base_quality, 0.0, 1.0)

func show_hit_feedback(position: Vector2):
    var feedback = Label.new()
    feedback.text = "+"
    feedback.position = position
    feedback.add_theme_color_override("font_color", Color.GREEN)
    add_child(feedback)
    
    # Animate and remove
    var tween = create_tween()
    tween.tween_property(feedback, "modulate:a", 0.0, 1.0)
    tween.finished.connect(func(): feedback.queue_free())
```

## Entity Integration

### Required Interfaces

#### IScavengingSite
```gdscript
interface IScavengingSite:
    func get_site_type() -> ScavengingSite.SiteType
    func get_difficulty_level() -> float
    func get_hazard_level() -> float
    func can_be_scavenged() -> bool
    func get_component_inventory() -> Dictionary
    func extract_components(quality: float) -> Dictionary
    func get_story_elements() -> Array[StoryElement]
```

#### IScavengingEntity
```gdscript
interface IScavengingEntity:
    func get_scavenging_controller() -> ScavengingController
    func get_scavenging_skill() -> float
    func can_perform_scavenging(site: ScavengingSite) -> bool
    func get_scavenging_tools() -> Array[String]
    func consume_scavenging_resource(resource_type: String, amount: float) -> bool
```

### Entity Types

#### Derelict Ship Entity
- Multiple component rooms with different salvage challenges
- Story-rich environments with logs and personal effects
- Variable stability affecting scavenging safety
- Size-based scavenging time and yield

#### Space Debris Entity
- Quick salvage opportunities with lower quality components
- Environmental hazards from unstable debris fields
- Strategic positioning for efficient multi-target scavenging
- Random component distribution

#### Abandoned Station Entity
- Complex multi-room layouts requiring exploration
- High-value component caches with security challenges
- Story hubs connecting multiple narrative threads
- Reusable stations with regenerating components

## API Reference

### Public Methods

#### ScavengingController
```gdscript
func start_scavenging(site: ScavengingSite) -> bool
func abort_scavenging() -> void
func get_scavenging_progress(site: ScavengingSite) -> float
func get_discovered_sites() -> Array[ScavengingSite]
func upgrade_scavenging_skill(increase: float) -> void
func unlock_scavenging_tool(tool_name: String) -> void
func get_scavenging_efficiency(site: ScavengingSite) -> float
```

#### ScavengingSite
```gdscript
func get_scavengable_components() -> Dictionary
func get_hazard_rating() -> float
func get_story_significance() -> int
func is_scavenged() -> bool
func get_remaining_value() -> float
func trigger_hazard() -> void
```

### Configuration Options

#### Scavenging Parameters
- Base scavenging times and quality calculations
- Hazard trigger probabilities and effects
- Component extraction success rates
- Story discovery chances

#### Quality Systems
- Quality rating ranges and effects
- Component condition degradation over time
- Skill-based quality bonuses
- Tool quality multipliers

## Testing Strategy

### Unit Tests
- Component extraction calculations
- Quality rating algorithms
- Hazard trigger probabilities
- Story element discovery rates

### Integration Tests
- Full scavenging workflows from approach to completion
- Cross-platform interface consistency
- Story discovery and narrative integration
- Performance with multiple active sites

### Edge Cases
- Scavenging interruption and resumption
- Component inventory capacity limits
- Hazard cascade effects
- Quality rating boundary conditions

## Reusability Guidelines

### Adapting for Other Projects

#### Post-Apocalyptic Scavenging
```gdscript
# Add radiation and contamination mechanics
class PostApocScavengingController extends ScavengingController:
    @export var radiation_damage_rate: float = 0.5
    
    func calculate_radiation_exposure(site: ScavengingSite) -> float:
        return site.hazard_level * site.difficulty_level
    
    func apply_radiation_damage(exposure: float):
        # Apply radiation sickness debuff
        player.apply_status_effect("radiation_sickness", exposure)
```

#### Underwater Salvage
```gdscript
# Add pressure and diving mechanics
class UnderwaterScavengingController extends ScavengingController:
    @export var max_depth: float = 500.0
    
    func calculate_depth_penalty(site: ScavengingSite) -> float:
        var depth = site.position.y  # Assuming Y is depth
        return clamp(depth / max_depth, 0.0, 1.0)
    
    func apply_depth_penalties(depth_penalty: float, operation: ScavengingOperation):
        operation.total_time *= (1.0 + depth_penalty)
        operation.quality_rating *= (1.0 - depth_penalty * 0.3)
```

#### Fantasy Ruins Exploration
```gdscript
# Add magical hazards and discoveries
class FantasyScavengingController extends ScavengingController:
    var magical_hazards = ["cursed_treasure", "summoned_guardians", "reality_fractures"]
    
    func generate_magical_hazard() -> String:
        return magical_hazards.pick_random()
    
    func apply_magical_effect(hazard_type: String, operation: ScavengingOperation):
        match hazard_type:
            "cursed_treasure":
                # Add curse debuff but bonus loot
                operation.add_curse_debuff()
                operation.multiply_loot_value(2.0)
```

### Extension Mechanisms

#### Custom Scavenging Mini-Games
```gdscript
class CustomScavengingMiniGame:
    var game_type: String
    var difficulty: float
    var time_limit: float
    var success_conditions: Array[Callable]
    
    func start_game(site: ScavengingSite, component_type: String):
        match game_type:
            "timing_game":
                start_timing_mini_game(difficulty)
            "pattern_game":
                start_pattern_mini_game(difficulty)
            "precision_game":
                start_precision_mini_game(difficulty)
    
    func evaluate_success(player_performance: Dictionary) -> float:
        var success_score = 0.0
        
        for condition in success_conditions:
            if condition.call(player_performance):
                success_score += 1.0 / success_conditions.size()
        
        return success_score
```

#### Dynamic Site Generation
```gdscript
class DynamicSiteGenerator:
    var site_templates: Dictionary = {}
    var environmental_modifiers: Dictionary = {}
    
    func generate_site_from_template(template_name: String, position: Vector3, modifiers: Array) -> ScavengingSite:
        var template = site_templates[template_name]
        var site = ScavengingSite.new()
        
        # Apply base template
        site.site_type = template.site_type
        site.component_inventory = template.components.duplicate()
        site.hazard_triggers = template.hazards.duplicate()
        
        # Apply environmental modifiers
        for modifier in modifiers:
            modifier.apply_to_site(site)
        
        # Apply positional modifiers
        apply_positional_modifiers(site, position)
        
        return site
    
    func apply_positional_modifiers(site: ScavengingSite, position: Vector3):
        # Modify components based on location
        var distance_from_center = position.length()
        
        if distance_from_center > 100:  # Deep space
            site.difficulty_level *= 1.5
            site.hazard_level *= 1.2
            # Add rare component bonuses
```

This scavenging system provides a rich alternative to mining, with risk-reward mechanics, narrative depth, and platform-optimized interactions that create compelling exploration opportunities.