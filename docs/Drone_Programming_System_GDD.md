# Drone Programming System Game Design Document

## Executive Summary

The **Drone Programming System** enables players to create and customize AI companions in Space Rogue: Starbound Odyssey, providing deep strategic gameplay through programmable behaviors. It supports multiple programming paradigms (DSL, Lua scripting, visual scripting) with platform-specific implementations to ensure accessibility across PC and mobile platforms.

**Key Features:**
- Multi-paradigm programming (DSL for mobile, Lua for PC, visual for accessibility)
- Event-driven behavior system with state machines
- Fleet management and coordination
- Performance-optimized execution
- Progressive complexity for different skill levels

**Integration Points:**
- Receives commands from Player Ship (owner)
- Provides combat support to Combat System
- Uses world data from World Generation System
- Integrates with UI System for programming interfaces
- Affects Progression System through drone unlocks

## System Architecture

### Core Components

#### DroneProgram (Base Programming Interface)
```gdscript
class_name DroneProgram
extends Resource

@export var program_name: String
@export var program_type: ProgramType
@export var max_complexity: int = 10
@export var supported_platforms: Array[String] = ["pc", "mobile"]

enum ProgramType {
    VISUAL_SCRIPT,
    LUA_SCRIPT,
    DSL_CONFIG
}

var compiled_program: Callable
var validation_errors: Array[String]

func compile_program(source_code: String) -> bool:
    match program_type:
        ProgramType.LUA_SCRIPT:
            return compile_lua(source_code)
        ProgramType.DSL_CONFIG:
            return compile_dsl(source_code)
        ProgramType.VISUAL_SCRIPT:
            return compile_visual(source_code)
    return false

func execute_drone_logic(drone: Drone, world_state: Dictionary):
    if compiled_program:
        compiled_program.call(drone, world_state)
```

#### DroneController (Runtime Execution)
```gdscript
class_name DroneController
extends Node

@export var max_drones: int = 3
@export var execution_budget_ms: float = 16.0  # 60fps budget

var active_drones: Array[Drone] = []
var program_cache: Dictionary = {}  # program_id -> compiled program

func spawn_drone(program: DroneProgram, spawn_position: Vector3) -> Drone:
    if active_drones.size() >= max_drones:
        return null
    
    var drone = DroneScene.instantiate()
    drone.program = program
    drone.position = spawn_position
    drone.owner_ship = get_parent()  # Player ship
    
    active_drones.append(drone)
    add_child(drone)
    return drone

func execute_drone_programs(delta: float):
    var start_time = Time.get_ticks_usec()
    var execution_time = 0.0
    
    for drone in active_drones:
        if execution_time >= execution_budget_ms * 1000:
            break  # Prevent frame drops
        
        var world_state = gather_world_state_for_drone(drone)
        drone.execute_program(world_state, delta)
        
        execution_time = Time.get_ticks_usec() - start_time
    
    # Performance monitoring
    if execution_time > execution_budget_ms * 1000 * 0.8:
        push_warning("Drone execution time high: ", execution_time / 1000, "ms")
```

#### ProgrammingInterface (Cross-Platform Editor)
```gdscript
class_name ProgrammingInterface
extends Control

@export var interface_mode: InterfaceMode
@export var available_blocks: Array[CodeBlock]

enum InterfaceMode {
    VISUAL_EDITOR,
    TEXT_EDITOR,
    DSL_BUILDER
}

var current_program: DroneProgram
var undo_stack: Array[ProgramState] = []

func _ready():
    setup_interface_for_platform()
    load_available_blocks()

func setup_interface_for_platform():
    if OS.get_name() in ["Android", "iOS"]:
        interface_mode = InterfaceMode.DSL_BUILDER
        # Mobile-optimized interface
    else:
        interface_mode = InterfaceMode.TEXT_EDITOR
        # Full-featured PC interface

func create_program_from_interface() -> DroneProgram:
    match interface_mode:
        InterfaceMode.VISUAL_EDITOR:
            return create_from_visual_blocks()
        InterfaceMode.TEXT_EDITOR:
            return create_from_text_input()
        InterfaceMode.DSL_BUILDER:
            return create_from_dsl_config()
```

### Programming Paradigms

#### 1. DSL Configuration (Mobile-Friendly)
**Simple rule-based system:**
```
WHEN enemy_detected AND health_above 50%
THEN attack_enemy WITH weapon_primary

WHEN cargo_full OR low_fuel
THEN return_to_owner VIA safe_path

WHEN owner_damaged
THEN defend_owner WITH aggressive_stance
```

#### 2. Lua Scripting (PC Full-Featured)
**Complete programming freedom:**
```lua
function init()
    patrol_radius = 100
    aggression_level = 0.7
end

function update(delta)
    local enemies = scan_enemies(75)
    
    if #enemies > 0 and health_percentage > 30 then
        engage_nearest_enemy()
    elseif cargo_percentage > 80 then
        return_to_owner()
    else
        patrol_area(owner_position, patrol_radius)
    end
end

function on_event(event)
    if event.type == "owner_command" then
        handle_command(event.data)
    end
end
```

#### 3. Visual Scripting (Accessibility Option)
**Node-based programming:**
- Drag-and-drop behavior blocks
- Visual connections between states
- Real-time program validation
- Beginner-friendly interface

### Event System

#### Drone Events
```gdscript
enum DroneEventType {
    OWNER_COMMAND,
    SECTOR_CHANGED,
    ENEMY_DETECTED,
    CARGO_FULL,
    HEALTH_LOW,
    RESOURCE_FOUND,
    ALLY_DAMAGED,
    MISSION_COMPLETE
}

class DroneEvent:
    var type: DroneEventType
    var data: Dictionary
    var priority: int = 0
    var timestamp: float
```

#### Event Processing
- **Priority Queue**: High-priority events interrupt current behavior
- **Event Filtering**: Drones only respond to relevant events
- **State Preservation**: Events can modify drone state variables
- **Coordination**: Events can trigger fleet-wide responses

## Technical Implementation

### Godot Node Structure
```
DroneProgrammingSystem (Node)
├── ProgrammingInterface (Control)
├── DroneController (Node)
├── ProgramCompiler (Node)
├── EventSystem (Node)
└── Drone Templates (Resource)
    ├── MiningDrone
    ├── CombatDrone
    ├── ScoutDrone
    └── CustomDrone
```

### Platform-Specific Implementations

#### PC Implementation (Full Featured)
- **Lua Integration**: GDLua or custom Lua wrapper
- **Text Editor**: Syntax highlighting, autocomplete
- **Debug Tools**: Breakpoints, variable inspection
- **Performance**: Full execution budget

#### Mobile Implementation (Simplified)
- **DSL Builder**: Touch-friendly rule constructor
- **Visual Scripting**: Simplified node editor
- **Pre-compiled Programs**: Limited customization
- **Performance**: Reduced execution complexity

### Key Scripts

#### LuaInterpreter.gd (PC)
```gdscript
class_name LuaInterpreter
extends Node

var lua_state: LuaState
var safe_function_whitelist: Array[String] = [
    "move_to", "attack_target", "scan_area", "return_home",
    "set_variable", "get_variable", "broadcast_message"
]

func initialize_lua_environment():
    lua_state = LuaState.new()
    
    # Register safe functions
    for func_name in safe_function_whitelist:
        lua_state.register_function(func_name, Callable(self, func_name))
    
    # Set up global state
    lua_state.set_global("drone", null)  # Set per drone
    lua_state.set_global("owner", null)
    lua_state.set_global("world", {})

func execute_lua_program(program_code: String, drone: Drone, world_state: Dictionary) -> bool:
    lua_state.set_global("drone", drone)
    lua_state.set_global("owner", drone.owner_ship)
    lua_state.set_global("world", world_state)
    
    var result = lua_state.do_string(program_code)
    
    if result != OK:
        push_error("Lua execution error: ", lua_state.get_last_error())
        return false
    
    return true
```

#### DSLInterpreter.gd (Mobile)
```gdscript
class_name DSLInterpreter
extends Node

var dsl_rules: Array[DSLRule] = []
var variable_store: Dictionary = {}

class DSLRule:
    var conditions: Array[DSLCondition]
    var actions: Array[DSLAction]
    
    func evaluate(drone: Drone, world_state: Dictionary) -> bool:
        for condition in conditions:
            if not condition.check(drone, world_state, variable_store):
                return false
        return true
    
    func execute(drone: Drone, world_state: Dictionary):
        for action in actions:
            action.perform(drone, world_state, variable_store)

func parse_dsl_code(dsl_code: String) -> Array[DSLRule]:
    var rules: Array[DSLRule] = []
    var lines = dsl_code.split("\n")
    
    var current_rule: DSLRule = null
    
    for line in lines:
        line = line.strip_edges()
        
        if line.begins_with("WHEN "):
            current_rule = DSLRule.new()
            current_rule.conditions = parse_conditions(line.substr(5))
            rules.append(current_rule)
        elif line.begins_with("THEN "):
            if current_rule:
                current_rule.actions = parse_actions(line.substr(5))
    
    return rules

func execute_dsl_program(rules: Array[DSLRule], drone: Drone, world_state: Dictionary):
    for rule in rules:
        if rule.evaluate(drone, world_state):
            rule.execute(drone, world_state)
            break  # Execute first matching rule
```

## Entity Integration

### Required Interfaces

#### IDroneEntity
```gdscript
interface IDroneEntity:
    func get_drone_program() -> DroneProgram
    func execute_program(world_state: Dictionary, delta: float) -> void
    func get_drone_capabilities() -> Array[String]
    func on_program_error(error_message: String) -> void
```

#### IProgrammableEntity
```gdscript
interface IProgrammableEntity:
    func get_programming_interface() -> ProgrammingInterface
    func validate_program(program: DroneProgram) -> Array[String]
    func get_available_functions() -> Array[String]
    func compile_program(source: String) -> DroneProgram
```

### Entity Types

#### Player Drone Entity
- Lua scripting on PC, DSL on mobile
- Fleet coordination capabilities
- Upgradeable through progression

#### NPC Drone Entity
- Pre-programmed behaviors
- Limited customization
- Used by enemy factions

#### Station Defense Drone
- Area protection programming
- Automated patrol routes
- Limited user modification

## API Reference

### Public Methods

#### DroneController
```gdscript
func spawn_drone(program: DroneProgram, position: Vector3) -> Drone
func despawn_drone(drone: Drone) -> void
func update_drone_program(drone: Drone, new_program: DroneProgram) -> bool
func get_active_drones() -> Array[Drone]
func send_fleet_command(command: String, parameters: Dictionary) -> void
func get_drone_performance_metrics() -> Dictionary
```

#### ProgrammingInterface
```gdscript
func open_programming_interface(drone: Drone) -> void
func save_program(program: DroneProgram, filename: String) -> bool
func load_program(filename: String) -> DroneProgram
func validate_program_syntax(source: String) -> Array[String]
func get_program_complexity_score(program: DroneProgram) -> float
func export_program_for_sharing(program: DroneProgram) -> String
```

### Configuration Options

#### Programming Limits
- Maximum program size (lines of code, number of rules)
- Execution time limits per frame
- Memory usage restrictions
- Function call frequency limits

#### Platform Settings
- Available programming paradigms per platform
- Interface complexity settings
- Tutorial mode availability
- Advanced feature unlocks

## Testing Strategy

### Unit Tests
- Program compilation validation
- Syntax error detection
- Execution performance benchmarks
- Event processing accuracy

### Integration Tests
- Cross-platform program compatibility
- Drone behavior consistency
- UI interaction workflows
- Performance scaling with multiple drones

### Edge Cases
- Program compilation failures
- Runtime execution errors
- Platform compatibility issues
- Performance limits with complex programs

## Reusability Guidelines

### Adapting for Other Projects

#### RTS Game Unit AI
```gdscript
# Extend for unit formations
func create_formation_program(formation_type: String) -> DroneProgram:
    var program = DroneProgram.new()
    program.add_rule("maintain_formation", formation_type)
    program.add_rule("coordinate_with_squad", true)
    return program
```

#### Robot Companion Game
```gdscript
# Add emotional state system
class EmotionalDroneController extends DroneController:
    var drone_mood: float = 0.5  # 0.0 = angry, 1.0 = happy
    
    func update_emotional_state(drone: Drone):
        # Modify behavior based on treatment
        if drone.was_praised_recently:
            drone_mood = min(1.0, drone_mood + 0.1)
        elif drone.was_damaged_by_owner:
            drone_mood = max(0.0, drone_mood - 0.2)
```

#### Educational Programming Game
```gdscript
# Add tutorial progression
class TutorialDroneController extends DroneController:
    var tutorial_stage: int = 0
    
    func advance_tutorial():
        tutorial_stage += 1
        unlock_new_programming_features()
        show_tutorial_hint()
```

### Extension Mechanisms

#### Custom Programming Languages
```gdscript
class CustomLanguageInterpreter extends Node:
    var language_grammar: Dictionary
    var builtin_functions: Dictionary
    
    func compile_custom_program(source: String) -> Callable:
        # Parse custom language syntax
        var ast = parse_source_to_ast(source)
        
        # Generate executable function
        return generate_executable_function(ast)
```

#### Program Sharing System
```gdscript
class ProgramSharingSystem:
    static func export_program(program: DroneProgram) -> String:
        var export_data = {
            "name": program.program_name,
            "type": program.program_type,
            "source": program.get_source_code(),
            "metadata": program.get_metadata()
        }
        return JSON.stringify(export_data)
    
    static func import_program(import_data: String) -> DroneProgram:
        var data = JSON.parse_string(import_data)
        var program = DroneProgram.new()
        program.load_from_export_data(data)
        return program
```

This drone programming system provides a flexible, multi-paradigm approach to AI companion creation, scaling from simple mobile-friendly DSL rules to full Lua scripting on PC, while maintaining performance and accessibility across platforms.