# AGENTS.md - Development Guidelines for 32 Bit- Spacer

## Overview
This is a Godot 4.5 3D game project called "32 Bit- Spacer" featuring NPC combat, player controls, and team-based gameplay mechanics.

## Build Commands

### Running the Game
```bash
# Open project in Godot Editor
godot --editor project.godot

# Run the game directly (export required for distribution)
godot --export "HTML5" --output game.html project.godot
```

### Building for Different Platforms
```bash
# Export for Linux
godot --export "Linux/X11" --output game.x86_64 project.godot

# Export for Windows
godot --export "Windows Desktop" --output game.exe project.godot

# Export for macOS
godot --export "macOS" --output game.dmg project.godot

# Export for HTML5 (web)
godot --export "HTML5" --output game.html project.godot
```

### Debug Builds
```bash
# Run with verbose output
godot --verbose --debug project.godot

# Run with remote debugger
godot --remote-debug 127.0.0.1:6007 project.godot
```

## Testing Commands

Godot doesn't have traditional unit testing built-in, but here are testing approaches:

### Scene Testing
```bash
# Test a specific scene
godot --scene "res://enviroment/Wold.tscn" project.godot

# Run with specific scene as main
godot --main-scene "res://NPCTeamFightUnOptimized/TeamFight.tscn" project.godot
```

### Script Validation
```bash
# Check GDScript syntax (run from project root)
find . -name "*.gd" -exec godot --check-only {} \;
```

### Performance Testing
```bash
# Run with performance monitoring
godot --benchmark project.godot

# Run with physics debugging
godot --debug-collisions project.godot
```

## Code Style Guidelines

### File Organization
- Use snake_case for file and directory names (e.g., `fight_agent.gd`, `player_controller.gd`)
- Group related scripts in logical directories (`player/`, `NPCs/`, `enviroment/`)
- Keep scene files (`.tscn`) in `assets/` directory
- Use UID-based scene references in `project.godot`

### GDScript Conventions

#### Class Structure
```typescript
extends CharacterBody3D

# Signals
signal health_changed(new_health)

# Constants (ALL_CAPS_WITH_UNDERSCORES)
const MAX_SPEED = 30
const ATTACK_COOLDOWN = 0.5

# Exported variables (configurable in editor)
@export var health: int = 100
@export var move_speed: float = 5.0
@export var attack_range: float = 2.0

# Onready variables (node references)
@onready var animation_player = $AnimationPlayer
@onready var collision_shape = $CollisionShape3D

# Regular variables
var current_target: Node3D
var is_attacking: bool = false

# Enums
enum State { IDLE, MOVING, ATTACKING, DEAD }
enum Team { HUMAN, XENO }

var current_state: State = State.IDLE
@export var team: Team

# Called when the node enters the scene tree
func _ready() -> void:
    # Initialize node
    pass

# Called every physics frame
func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE:
            _handle_idle_state(delta)
        State.MOVING:
            _handle_moving_state(delta)
        State.ATTACKING:
            _handle_attacking_state(delta)

# Private methods (prefixed with underscore)
func _handle_idle_state(_delta: float) -> void:
    # Implementation
    pass

func _handle_moving_state(delta: float) -> void:
    # Implementation
    pass

func _handle_attacking_state(delta: float) -> void:
    # Implementation
    pass

# Public methods
func take_damage(amount: int) -> void:
    health -= amount
    health_changed.emit(health)
    if health <= 0:
        die()

func die() -> void:
    current_state = State.DEAD
    # Death logic
```

#### Naming Conventions
- **Variables**: snake_case (e.g., `move_speed`, `current_target`, `is_attacking`)
- **Functions**: snake_case (e.g., `take_damage()`, `update_target()`)
- **Constants**: ALL_CAPS_WITH_UNDERSCORES (e.g., `MAX_SPEED`, `ATTACK_RANGE`)
- **Classes/Enums**: PascalCase (e.g., `CharacterController`, `State`)
- **Signals**: snake_case (e.g., `health_changed`, `target_acquired`)
- **Private methods**: prefix with underscore (e.g., `_update_physics()`)

#### Type Hints
- Always use type hints for function parameters and return values
- Use type hints for member variables when possible
- Use explicit types for exported variables

```gdscript
# Good
func take_damage(amount: int) -> void:
    pass

var current_target: Node3D

# Avoid
func take_damage(amount):
    pass

var current_target
```

#### Node References
- Use `@onready` for node references that are guaranteed to exist
- Use `get_node_or_null()` for optional node references
- Prefer `$` shorthand for direct children

```gdscript
# Good
@onready var camera = $Camera3D
@onready var animation_player = $AnimationPlayer

# For optional references
var optional_node = get_node_or_null("OptionalNode")
```

#### Error Handling
- Use assertions for programming errors
- Check for null references before using them
- Use `is_instance_valid()` for node validity checks

```gdscript
func attack_target(target: Node3D) -> void:
    assert(target != null, "Target cannot be null")
    if not is_instance_valid(target):
        return

    # Attack logic
    pass
```

#### Performance Considerations
- Use `_physics_process()` for physics-related updates
- Use `_process()` sparingly, only when needed
- Cache frequently accessed values
- Use `distance_squared_to()` instead of `distance_to()` when possible
- Avoid creating objects in hot paths

#### Physics and Movement
- Use `CharacterBody3D` for character movement
- Always call `move_and_slide()` after setting velocity
- Use appropriate collision layers and masks
- Clamp movement to prevent tunneling

```gdscript
func _physics_process(delta: float) -> void:
    var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = input_vector * move_speed
    move_and_slide()

    # Clamp position to bounds
    global_position.x = clamp(global_position.x, -bounds.x, bounds.x)
    global_position.z = clamp(global_position.z, -bounds.z, bounds.z)
```

#### State Management
- Use enums for state machines
- Use `match` statements for state handling
- Keep state transition logic clear and centralized

```gdscript
enum State { IDLE, CHASING, ATTACKING, FLEEING }

func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE:
            _handle_idle()
        State.CHASING:
            _handle_chasing(delta)
        State.ATTACKING:
            _handle_attacking(delta)
        State.FLEEING:
            _handle_fleeing(delta)
```

#### Code Comments
- Use `#` for single-line comments
- Comment complex logic, not obvious code
- Use TODO comments for temporary code or planned improvements
- Document function purposes when not self-evident

```gdscript
# TODO: Optimize this O(n^3) algorithm
func find_optimal_path() -> void:
    # Complex pathfinding logic here
    pass
```

#### Imports and Dependencies
- Godot auto-imports, no explicit imports needed
- Use `preload()` for scenes and scripts loaded at compile time
- Use `load()` for dynamic loading

```gdscript
# Preload for performance
const BulletScene = preload("res://Bullet.tscn")

# Dynamic loading
var enemy_scene = load("res://Enemy.tscn")
```

### Code Quality Checks
- Run the project regularly to catch runtime errors
- Use Godot's built-in debugger for complex issues
- Test scene transitions and state changes
- Verify physics interactions work correctly

### Version Control
- Commit frequently with clear, descriptive messages
- Use feature branches for new functionality
- Test changes before committing
- Include scene files and scripts in commits

### Best Practices
1. **Separation of Concerns**: Keep game logic, UI, and data separate
2. **DRY Principle**: Don't Repeat Yourself - extract common functionality
3. **Single Responsibility**: Each script/class should have one clear purpose
4. **Fail Fast**: Use assertions and early returns to catch errors quickly
5. **Performance First**: Optimize for 60 FPS, be mindful of draw calls and physics calculations

### Common Anti-patterns to Avoid
- Global variables (use singletons sparingly)
- Deep inheritance hierarchies (favor composition)
- Magic numbers (use named constants)
- Long functions (break into smaller, focused methods)
- Tight coupling between scripts (use signals for loose coupling)
