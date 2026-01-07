# AI System Game Design Document

## Executive Summary

The **AI System** provides intelligent behavior for non-player entities in Space Rogue: Starbound Odyssey, enabling dynamic and responsive NPC actions. It uses a modular architecture combining behavior trees, vector steering algorithms, and Craig Reynolds' Boids model to create believable AI that adapts to player actions and environmental conditions.

**Key Features:**
- Behavior tree-based decision making
- Vector steering algorithms (seek, flee, pursue, evade, wander, obstacle avoidance)
- Boids algorithm for swarm enemies (separation, alignment, cohesion)
- Group coordination and emergent behaviors
- Adaptive difficulty scaling
- Performance-optimized for multiple AI entities

**Integration Points:**
- Receives position data from Movement System
- Provides targeting information to Combat System
- Uses world data from World Generation System
- Integrates with Audio System for AI voice responses

## System Architecture

### Core Components

#### AIManager (Central Coordinator)
```gdscript
class_name AIManager
extends Node

var active_agents: Array[AIAgent] = []
var behavior_trees: Dictionary = {}
var navigation_system: NavigationSystem

func _process(delta: float):
    update_agents(delta)
    process_group_behaviors()
    optimize_performance()
```

#### AIAgent (Individual AI Controller)
```gdscript
class_name AIAgent
extends Node

@export var behavior_profile: BehaviorProfile
@export var difficulty_level: float = 1.0

var current_state: AIState
var target_entity: Node3D
var steering_behaviors: Array[SteeringBehavior] = []
var current_steering_force: Vector3 = Vector3.ZERO

signal state_changed(new_state: AIState, old_state: AIState)
signal target_acquired(target: Node3D)
signal target_lost()
```

#### BehaviorTreeSystem
- Hierarchical decision trees
- Composite, decorator, and leaf nodes
- Dynamic behavior modification
- Performance profiling

#### SteeringSystem
- Vector-based steering force calculations
- Boids algorithm for swarm enemies (separation, alignment, cohesion)
- Classic steering behaviors for individual enemies (seek, flee, pursue, evade, wander, obstacle avoidance)
- Dynamic obstacle avoidance using force fields and predictive calculations
- Group movement coordination through behavioral composition and emergent behaviors

### Data Flow
1. Environmental sensors gather data (positions, velocities, obstacles)
2. Behavior tree evaluates conditions and selects steering behaviors
3. Steering forces calculated based on selected behaviors
4. Forces applied to movement system with priority weighting
5. Movement executed and feedback received for behavior adjustment

### Performance Characteristics
- Supports 20-50 active AI agents simultaneously
- Configurable update frequencies (steering calculations every 1-4 frames)
- Spatial partitioning for efficient neighbor detection
- Steering force caching and behavioral composition optimization
- Boids calculations batched for swarm enemies

## Technical Implementation

### Godot Node Structure
```
AISystem (Node)
├── AIManager
├── SteeringSystem
├── BehaviorTreeManager
└── AI Agents (Node)
    ├── SwarmEnemyAI (AIAgent)  # Uses Boids
    ├── HunterEnemyAI (AIAgent) # Uses classic steering
    ├── AllyAI (AIAgent)
    └── NeutralAI (AIAgent)
```

### Key Scripts

#### AIAgent.gd
```gdscript
class_name AIAgent
extends Node

enum AIState {
    IDLE,
    PATROL,
    CHASE,
    ATTACK,
    FLEE,
    GUARD,
    FORMATION
}

@export var detection_range: float = 50.0
@export var attack_range: float = 20.0
@export var flee_health_threshold: float = 0.3

var current_state: AIState = AIState.IDLE
var behavior_tree: BehaviorTree
var navigation_target: Vector3
var group_id: int = -1

func _ready():
    initialize_behavior_tree()
    connect_signals()

func _process(delta: float):
    update_sensors()
    execute_behavior_tree(delta)
    perform_current_action(delta)

func update_sensors():
    # Update knowledge of environment
    detect_nearby_entities()
    assess_threats()
    evaluate_opportunities()

func execute_behavior_tree(delta: float):
    if behavior_tree:
        behavior_tree.tick(delta)

func perform_current_action(delta: float):
    match current_state:
        AIState.IDLE:
            idle_behavior(delta)
        AIState.PATROL:
            patrol_behavior(delta)
        AIState.CHASE:
            chase_behavior(delta)
        AIState.ATTACK:
            attack_behavior(delta)
        AIState.FLEE:
            flee_behavior(delta)
```

#### BehaviorTree.gd
```gdscript
class_name BehaviorTree
extends Node

enum NodeStatus {
    RUNNING,
    SUCCESS,
    FAILURE
}

class BTNode:
    func tick(delta: float) -> NodeStatus:
        # Override in subclasses
        return NodeStatus.FAILURE

class Sequence extends BTNode:
    var children: Array[BTNode] = []

    func tick(delta: float) -> NodeStatus:
        for child in children:
            var status = child.tick(delta)
            if status != NodeStatus.SUCCESS:
                return status
        return NodeStatus.SUCCESS

class Selector extends BTNode:
    var children: Array[BTNode] = []

    func tick(delta: float) -> NodeStatus:
        for child in children:
            var status = child.tick(delta)
            if status != NodeStatus.FAILURE:
                return status
        return NodeStatus.FAILURE

class Condition extends BTNode:
    var condition_func: Callable

    func tick(delta: float) -> NodeStatus:
        return NodeStatus.SUCCESS if condition_func.call() else NodeStatus.FAILURE

class Action extends BTNode:
    var action_func: Callable

    func tick(delta: float) -> NodeStatus:
        return action_func.call()
```

#### SteeringSystem.gd
```gdscript
class_name SteeringSystem
extends Node

@export var max_steering_force: float = 5.0
@export var neighbor_detection_radius: float = 20.0

var spatial_partition: Dictionary = {}  # Grid-based spatial partitioning

func calculate_steering_force(agent: AIAgent, delta: float) -> Vector3:
    var total_force = Vector3.ZERO

    for behavior in agent.steering_behaviors:
        var force = behavior.calculate_force(agent, delta)
        total_force += force

    # Limit total force to prevent unrealistic acceleration
    return total_force.limit_length(max_steering_force)

func update_spatial_partition(agents: Array[AIAgent]) -> void:
    spatial_partition.clear()

    for agent in agents:
        var grid_pos = world_to_grid(agent.global_position)
        if not spatial_partition.has(grid_pos):
            spatial_partition[grid_pos] = []
        spatial_partition[grid_pos].append(agent)

func get_neighbors(agent: AIAgent, radius: float) -> Array[AIAgent]:
    var neighbors: Array[AIAgent] = []
    var agent_grid = world_to_grid(agent.global_position)

    # Check surrounding grid cells
    for x in range(-1, 2):
        for y in range(-1, 2):
            for z in range(-1, 2):
                var check_grid = agent_grid + Vector3i(x, y, z)
                if spatial_partition.has(check_grid):
                    for other_agent in spatial_partition[check_grid]:
                        if other_agent != agent and agent.global_position.distance_to(other_agent.global_position) <= radius:
                            neighbors.append(other_agent)

    return neighbors

func world_to_grid(position: Vector3) -> Vector3i:
    var grid_size = 10.0  # 10 unit grid cells
    return Vector3i(
        floor(position.x / grid_size),
        floor(position.y / grid_size),
        floor(position.z / grid_size)
    )
```

#### BoidsBehavior.gd
```gdscript
class_name BoidsBehavior
extends SteeringBehavior

@export var separation_radius: float = 5.0
@export var alignment_radius: float = 10.0
@export var cohesion_radius: float = 15.0

@export var separation_weight: float = 1.5
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0

func calculate_force(agent: AIAgent, delta: float) -> Vector3:
    var neighbors = SteeringSystem.get_neighbors(agent, max(separation_radius, alignment_radius, cohesion_radius))

    var separation = calculate_separation(agent, neighbors) * separation_weight
    var alignment = calculate_alignment(agent, neighbors) * alignment_weight
    var cohesion = calculate_cohesion(agent, neighbors) * cohesion_weight

    return separation + alignment + cohesion

func calculate_separation(agent: AIAgent, neighbors: Array[AIAgent]) -> Vector3:
    var force = Vector3.ZERO
    var count = 0

    for neighbor in neighbors:
        var distance = agent.global_position.distance_to(neighbor.global_position)
        if distance > 0 and distance < separation_radius:
            var push_force = (agent.global_position - neighbor.global_position).normalized()
            push_force /= distance  # Stronger force when closer
            force += push_force
            count += 1

    if count > 0:
        force /= count

    return force

func calculate_alignment(agent: AIAgent, neighbors: Array[AIAgent]) -> Vector3:
    var average_velocity = Vector3.ZERO
    var count = 0

    for neighbor in neighbors:
        var distance = agent.global_position.distance_to(neighbor.global_position)
        if distance > 0 and distance < alignment_radius:
            average_velocity += neighbor.velocity
            count += 1

    if count > 0:
        average_velocity /= count
        return (average_velocity - agent.velocity).normalized()

    return Vector3.ZERO

func calculate_cohesion(agent: AIAgent, neighbors: Array[AIAgent]) -> Vector3:
    var center_of_mass = Vector3.ZERO
    var count = 0

    for neighbor in neighbors:
        var distance = agent.global_position.distance_to(neighbor.global_position)
        if distance > 0 and distance < cohesion_radius:
            center_of_mass += neighbor.global_position
            count += 1

    if count > 0:
        center_of_mass /= count
        return (center_of_mass - agent.global_position).normalized()

    return Vector3.ZERO
```

#### SteeringBehavior.gd (Base Class)
```gdscript
class_name SteeringBehavior
extends Node

@export var weight: float = 1.0
@export var enabled: bool = true

func calculate_force(agent: AIAgent, delta: float) -> Vector3:
    # Override in subclasses
    return Vector3.ZERO
```

#### SeekBehavior.gd
```gdscript
class_name SeekBehavior extends SteeringBehavior

func calculate_force(agent: AIAgent, delta: float) -> Vector3:
    if not agent.target_entity:
        return Vector3.ZERO

    var desired_velocity = (agent.target_entity.global_position - agent.global_position).normalized()
    desired_velocity *= agent.max_speed

    return (desired_velocity - agent.velocity) * weight
```

#### FleeBehavior.gd
```gdscript
class_name FleeBehavior extends SteeringBehavior

@export var flee_distance: float = 30.0

func calculate_force(agent: AIAgent, delta: float) -> Vector3:
    if not agent.target_entity:
        return Vector3.ZERO

    var distance = agent.global_position.distance_to(agent.target_entity.global_position)
    if distance > flee_distance:
        return Vector3.ZERO

    var desired_velocity = (agent.global_position - agent.target_entity.global_position).normalized()
    desired_velocity *= agent.max_speed

    return (desired_velocity - agent.velocity) * weight
```

## Entity Integration

### Required Interfaces

#### IAIEntity
```gdscript
interface IAIEntity:
    func get_ai_agent() -> AIAgent
    func get_movement_controller() -> MovementController
    func get_combat_participant() -> CombatParticipant
    func on_ai_decision_made(decision: String)
    func get_detection_range() -> float
```

#### BehaviorProfile
```gdscript
class BehaviorProfile:
    var aggression_level: float = 1.0
    var caution_level: float = 1.0
    var group_behavior: bool = false
    var preferred_range: float = 20.0
    var flee_threshold: float = 0.3
    var patrol_points: Array[Vector3] = []
```

### Entity Types

#### Enemy Patrol Ship
- Patrols designated routes
- Engages threats within range
- Coordinates with nearby allies

#### Aggressive Hunter
- Actively seeks player targets
- Uses hit-and-run tactics
- Adapts to player weapon preferences

#### Defensive Guardian
- Protects specific locations
- Calls for reinforcements
- Uses environmental advantages

## API Reference

### Public Methods

#### AIManager
```gdscript
func register_agent(agent: AIAgent) -> void
func unregister_agent(agent: AIAgent) -> void
func set_global_difficulty(multiplier: float) -> void
func pause_all_ai() -> void
func resume_all_ai() -> void
func get_agents_in_range(position: Vector3, radius: float) -> Array[AIAgent]
```

#### AIAgent
```gdscript
func set_state(new_state: AIState) -> void
func set_target(entity: Node3D) -> void
func clear_target() -> void
func add_steering_behavior(behavior: SteeringBehavior) -> void
func remove_steering_behavior(behavior_type: String) -> void
func get_steering_force() -> Vector3
func evaluate_threat_level(entity: Node3D) -> float
```

### Configuration Options

#### AI Difficulty Settings
- Reaction time multipliers
- Accuracy modifiers
- Decision-making complexity
- Group coordination effectiveness

#### Behavior Customization
- Personality profiles (aggressive, cautious, erratic)
- Tactical preferences (ranged, melee, hit-and-run)
- Environmental adaptation rules

## Testing Strategy

### Unit Tests
- Behavior tree execution correctness
- Steering force calculations accuracy
- Boids algorithm emergent behaviors
- State transition logic
- Sensor data processing

### Integration Tests
- AI vs Player combat scenarios with steering behaviors
- Boids swarm formation and movement patterns
- Steering behavior combinations and priority weighting
- Environmental interaction responses (obstacle avoidance)
- Performance scaling with multiple agents

### Edge Cases
- Steering force conflicts and oscillation
- Boids edge cases (single boid, empty neighborhoods)
- Target switching during steering behavior transitions
- AI behavior with incomplete sensor data
- Memory and performance limits with many steering behaviors

## Reusability Guidelines

### Adapting for Other Projects

#### 2D Platformer AI
```gdscript
# Modify for 2D steering
func calculate_2d_steering_force(agent: AIAgent2D, delta: float) -> Vector2:
    var total_force = Vector2.ZERO

    for behavior in agent.steering_behaviors:
        var force = behavior.calculate_force_2d(agent, delta)
        total_force += force

    return total_force.limit_length(max_steering_force)
```

#### RTS Game AI
```gdscript
# Add group command system
class GroupAI extends AIAgent:
    var subordinates: Array[AIAgent] = []

    func issue_group_command(command: GroupCommand):
        for subordinate in subordinates:
            subordinate.receive_command(command)
```

#### Puzzle Game AI
```gdscript
# Simplify for non-combat scenarios
func create_puzzle_ai():
    var tree = BehaviorTree.new()
    tree.root = Sequence.new([
        Condition.new(func(): return puzzle_piece_available()),
        Action.new(func(): return move_to_piece()),
        Action.new(func(): return solve_puzzle_step())
    ])
    return tree
```

### Extension Mechanisms

#### Custom Behavior Nodes
```gdscript
class CustomBehaviorNode extends BehaviorTree.BTNode:
    var custom_condition: Callable
    var custom_action: Callable

    func tick(delta: float) -> NodeStatus:
        if custom_condition and not custom_condition.call():
            return NodeStatus.FAILURE

        if custom_action:
            return custom_action.call()

        return NodeStatus.SUCCESS
```

#### Adaptive Steering Behaviors
```gdscript
class AdaptiveSteeringAgent extends AIAgent:
    var behavior_effectiveness: Dictionary = {}

    func learn_from_steering_result(result: SteeringResult):
        # Update steering behavior weights based on effectiveness
        var behavior_name = result.behavior_name
        var effectiveness = result.effectiveness

        if not behavior_effectiveness.has(behavior_name):
            behavior_effectiveness[behavior_name] = 1.0

        # Adjust weight based on performance
        behavior_effectiveness[behavior_name] = lerp(
            behavior_effectiveness[behavior_name],
            effectiveness,
            0.1  # Learning rate
        )

        adjust_steering_weights(behavior_effectiveness)
```

This AI system provides sophisticated NPC behavior while maintaining clean separation between AI logic and entity-specific implementations, making it highly reusable across different game types.