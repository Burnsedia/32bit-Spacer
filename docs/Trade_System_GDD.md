# Trade System Game Design Document

## Executive Summary

The **Trade System** implements a dynamic economy for Space Rogue: Starbound Odyssey, enabling players to buy, sell, and trade goods between space stations, mobile traders, and discovered caches. It adds strategic depth through resource management, market fluctuations, and economic decision-making while maintaining clean separation between trade logic and game entities.

**Key Features:**
- Dynamic market economy with fluctuating prices
- Multiple trader types (stations, mobile traders, black markets)
- Comprehensive goods system (weapons, resources, information)
- Negotiation and relationship mechanics
- Economic events and market disruptions
- Performance-optimized trade calculations

**Integration Points:**
- Receives resources from Sector Generator (stations, caches)
- Provides credits and items to Progression System
- Works with Inventory System for item management
- Integrates with UI System for trading interfaces
- Affects AI System (trader behaviors and merchant fleets)

## System Architecture

### Core Components

#### TradeManager (Central Coordinator)
```gdscript
class_name TradeManager
extends Node

enum GoodsCategory {
    WEAPONS,
    SHIP_PARTS,
    RESOURCES,
    CONSUMABLES,
    INFORMATION,
    SPECIAL
}

enum TraderType {
    STATION,
    MOBILE_TRADER,
    BLACK_MARKET,
    FACTION_VENDOR,
    DISTRESS_SELLER
}

@export var starting_credits: int = 1000
@export var market_update_interval: float = 300.0  # 5 minutes
@export var price_volatility: float = 0.2

var player_credits: int = 0
var market_data: Dictionary = {}  # String -> MarketData
var active_traders: Array[Trader] = []
var trade_history: Array[TradeRecord] = []
var economic_events: Array[EconomicEvent] = []

signal credits_changed(new_amount: int)
signal trade_completed(trade_record: TradeRecord)
signal market_updated()
signal economic_event_triggered(event: EconomicEvent)
```

#### MarketDynamicsSystem
- Price fluctuation calculations based on supply/demand
- Economic event generation and application
- Market trend analysis and prediction
- Cross-sector trade route simulation

#### TraderAISystem
- Station and mobile trader behaviors
- Inventory management for NPCs
- Negotiation AI with personality traits
- Trade route planning and optimization

#### InventoryManagementSystem
- Player and NPC inventory handling
- Item stacking and categorization
- Trade transaction processing
- Item validation and serialization

### Data Flow
1. Game systems generate goods and traders
2. Market dynamics update prices based on activity
3. Player interacts with traders through UI
4. Transactions processed and records created
5. Economic events trigger market changes
6. All changes reflected in UI and save data

### Performance Characteristics
- Market updates: Minimal CPU impact (<1ms per update)
- Trade calculations: <10ms per transaction
- Memory usage: <5MB for market data
- Supports 50+ active traders simultaneously
- Efficient data structures for large inventories

## Technical Implementation

### Godot Node Structure
```
TradeSystem (Node)
├── TradeManager
├── MarketDynamicsSystem
├── TraderAISystem
├── InventoryManagementSystem
├── TraderSpawner
│   └── Active Traders (Node3D)
│       ├── TradingStations (Node3D)
│       ├── MobileTraders (CharacterBody3D)
│       └── BlackMarketLocations (Node3D)
└── MarketDataStorage
```

### Key Scripts

#### TradeRecord.gd
```gdscript
class_name TradeRecord
extends Resource

enum TransactionType {
    BUY,
    SELL,
    TRADE
}

@export var timestamp: int
@export var transaction_type: TransactionType
@export var trader_name: String
@export var item_id: String
@export var quantity: int
@export var unit_price: float
@export var total_value: float
@export var profit_loss: float = 0.0

func _init(trader: String, item: String, qty: int, price: float, type: TransactionType):
    timestamp = Time.get_unix_time_from_system()
    trader_name = trader
    item_id = item
    quantity = qty
    unit_price = price
    total_value = price * qty
    transaction_type = type

func calculate_profit_loss(original_price: float) -> void:
    match transaction_type:
        TransactionType.BUY:
            # We'll calculate profit when selling
            pass
        TransactionType.SELL:
            profit_loss = (unit_price - original_price) * quantity
        TransactionType.TRADE:
            # Trade profit/loss calculation
            pass
```

#### MarketData.gd
```gdscript
class_name MarketData
extends Resource

@export var item_id: String
@export var base_price: float
@export var current_price: float
@export var supply: int = 100
@export var demand: int = 100
@export var volatility: float = 0.1
@export var last_update: int = 0

@export var price_history: Array[float] = []
@export var max_history_length: int = 50

func update_price() -> void:
    var current_time = Time.get_unix_time_from_system()
    var time_since_update = current_time - last_update

    if time_since_update < 60:  # Update at most once per minute
        return

    last_update = current_time

    # Calculate supply/demand ratio
    var supply_demand_ratio = float(demand) / max(supply, 1)

    # Add some randomness based on volatility
    var random_factor = randf_range(-volatility, volatility)

    # Calculate new price
    var new_price = base_price * supply_demand_ratio * (1.0 + random_factor)

    # Apply price floors and ceilings
    new_price = max(new_price, base_price * 0.1)  # Minimum 10% of base price
    new_price = min(new_price, base_price * 10.0)  # Maximum 10x base price

    # Update price and history
    current_price = new_price
    price_history.append(new_price)

    # Maintain history length
    if price_history.size() > max_history_length:
        price_history.remove_at(0)

func adjust_supply(amount: int) -> void:
    supply = max(0, supply + amount)

func adjust_demand(amount: int) -> void:
    demand = max(0, demand + amount)

func get_price_trend() -> float:
    if price_history.size() < 2:
        return 0.0

    var recent_prices = price_history.slice(-5)  # Last 5 prices
    if recent_prices.size() < 2:
        return 0.0

    var first_price = recent_prices[0]
    var last_price = recent_prices.back()

    return (last_price - first_price) / first_price

func get_market_sentiment() -> String:
    var trend = get_price_trend()

    if trend > 0.1:
        return "bullish"
    elif trend < -0.1:
        return "bearish"
    else:
        return "neutral"
```

#### Trader.gd
```gdscript
class_name Trader
extends Node3D

@export var trader_name: String
@export var trader_type: TradeManager.TraderType
@export var faction: String = "independent"
@export var personality_trait: String = "neutral"

var inventory: Dictionary = {}  # item_id -> quantity
var credits: int = 10000
var relationship_level: float = 0.0  # -1.0 to 1.0 (hostile to friendly)

@export var buy_modifier: float = 1.0  # How much they pay for goods
@export var sell_modifier: float = 1.0  # How much they charge for goods
@export var stock_refresh_time: float = 3600.0  # 1 hour
@export var last_stock_refresh: int = 0

func _ready():
    initialize_inventory()
    last_stock_refresh = Time.get_unix_time_from_system()

func initialize_inventory() -> void:
    match trader_type:
        TradeManager.TraderType.STATION:
            _initialize_station_inventory()
        TradeManager.TraderType.MOBILE_TRADER:
            _initialize_mobile_inventory()
        TradeManager.TraderType.BLACK_MARKET:
            _initialize_black_market_inventory()

func _initialize_station_inventory() -> void:
    # Stations have broad but shallow inventory
    var station_goods = [
        "basic_repair_kit", "fuel_cell", "standard_ammo",
        "common_weapon_mod", "basic_ship_part"
    ]

    for good in station_goods:
        inventory[good] = randi_range(5, 20)

func _initialize_mobile_inventory() -> void:
    # Mobile traders specialize in certain goods
    var specializations = ["weapons", "ship_parts", "consumables"]
    var specialization = specializations[randi() % specializations.size()]

    match specialization:
        "weapons":
            inventory["laser_cannon"] = randi_range(1, 3)
            inventory["plasma_blaster"] = randi_range(0, 2)
        "ship_parts":
            inventory["engine_upgrade"] = randi_range(1, 2)
            inventory["shield_generator"] = randi_range(0, 2)
        "consumables":
            inventory["health_pack"] = randi_range(5, 15)
            inventory["ammo_pack"] = randi_range(10, 30)

func can_afford_transaction(item_id: String, quantity: int, is_buying: bool) -> bool:
    var market_data = TradeManager.get_market_data(item_id)
    if not market_data:
        return false

    var price = market_data.current_price
    if is_buying:
        price *= sell_modifier
    else:
        price *= buy_modifier

    var total_cost = price * quantity

    if is_buying:
        return credits >= total_cost
    else:
        return inventory.get(item_id, 0) >= quantity

func execute_transaction(item_id: String, quantity: int, is_buying: bool) -> bool:
    if not can_afford_transaction(item_id, quantity, is_buying):
        return false

    var market_data = TradeManager.get_market_data(item_id)
    var price = market_data.current_price

    if is_buying:
        price *= sell_modifier
        credits -= price * quantity
        inventory[item_id] = inventory.get(item_id, 0) + quantity
        market_data.adjust_supply(-quantity)  # Reduce supply
    else:
        price *= buy_modifier
        credits += price * quantity
        inventory[item_id] = inventory.get(item_id, 0) - quantity
        market_data.adjust_supply(quantity)  # Increase supply

    # Create trade record
    var record = TradeRecord.new(trader_name, item_id, quantity, price, TradeRecord.TransactionType.SELL if is_buying else TradeRecord.TransactionType.BUY)
    TradeManager.add_trade_record(record)

    # Update relationship
    update_relationship(is_buying, quantity)

    return true

func update_relationship(was_good_deal: bool, transaction_size: int) -> void:
    var relationship_change = 0.01 * transaction_size

    if was_good_deal:
        relationship_level += relationship_change
    else:
        relationship_level -= relationship_change

    relationship_level = clamp(relationship_level, -1.0, 1.0)

func get_relationship_status() -> String:
    if relationship_level > 0.5:
        return "friendly"
    elif relationship_level < -0.5:
        return "hostile"
    else:
        return "neutral"

func refresh_stock() -> void:
    var current_time = Time.get_unix_time_from_system()
    if current_time - last_stock_refresh >= stock_refresh_time:
        _refresh_inventory()
        last_stock_refresh = current_time

func _refresh_inventory() -> void:
    # Randomly add/remove items based on market conditions
    for item_id in inventory.keys():
        var change = randi_range(-2, 3)  # -2 to +3
        inventory[item_id] = max(0, inventory[item_id] + change)
```

#### EconomicEvent.gd
```gdscript
class_name EconomicEvent
extends Resource

enum EventType {
    MARKET_CRASH,
    BOOM_PERIOD,
    SUPPLY_SHORTAGE,
    DEMAND_SURGE,
    TRADE_WAR,
    DISCOVERY
}

@export var event_type: EventType
@export var title: String
@export var description: String
@export var duration: float  # In seconds
@export var affected_goods: Array[String]
@export var effect_strength: float = 1.0

var start_time: int = 0
var active: bool = false

func trigger() -> void:
    active = true
    start_time = Time.get_unix_time_from_system()

    match event_type:
        EventType.MARKET_CRASH:
            _trigger_market_crash()
        EventType.BOOM_PERIOD:
            _trigger_boom_period()
        EventType.SUPPLY_SHORTAGE:
            _trigger_supply_shortage()
        EventType.DEMAND_SURGE:
            _trigger_demand_surge()
        EventType.TRADE_WAR:
            _trigger_trade_war()
        EventType.DISCOVERY:
            _trigger_discovery()

func update() -> void:
    if not active:
        return

    var current_time = Time.get_unix_time_from_system()
    if current_time - start_time >= duration:
        deactivate()

func deactivate() -> void:
    active = false
    # Reverse the effects
    match event_type:
        EventType.MARKET_CRASH:
            _end_market_crash()
        EventType.BOOM_PERIOD:
            _end_boom_period()
        EventType.SUPPLY_SHORTAGE:
            _end_supply_shortage()
        EventType.DEMAND_SURGE:
            _end_demand_surge()
        EventType.TRADE_WAR:
            _end_trade_war()
        EventType.DISCOVERY:
            _end_discovery()

func _trigger_market_crash() -> void:
    for good_id in affected_goods:
        var market_data = TradeManager.get_market_data(good_id)
        if market_data:
            market_data.current_price *= (1.0 - effect_strength * 0.5)
            market_data.volatility *= 2.0

func _trigger_boom_period() -> void:
    for good_id in affected_goods:
        var market_data = TradeManager.get_market_data(good_id)
        if market_data:
            market_data.current_price *= (1.0 + effect_strength * 0.3)
            market_data.demand *= (1.0 + effect_strength * 0.5)
```

## Entity Integration

### Required Interfaces

#### ITradeableEntity
```gdscript
interface ITradeableEntity:
    func get_inventory() -> Dictionary
    func can_trade_item(item_id: String, quantity: int) -> bool
    func execute_trade(item_id: String, quantity: int, credits: int) -> bool
    func get_trade_reputation() -> float
```

#### IMarketAwareEntity
```gdscript
interface IMarketAwareEntity:
    func on_market_updated(market_data: Dictionary)
    func on_economic_event(event: EconomicEvent)
    func get_market_preferences() -> Array[String]
```

### Entity Types

#### TradingStation Entity
- Fixed location trading hubs
- Broad inventory with steady prices
- Quest and service integration

#### MobileTrader Entity
- AI-controlled trader ships
- Dynamic inventory and pricing
- Route-based movement patterns

#### BlackMarket Entity
- Hidden locations with rare goods
- Risk/reward trading mechanics
- Faction reputation requirements

## API Reference

### Public Methods

#### TradeManager
```gdscript
func buy_item(trader: Trader, item_id: String, quantity: int) -> bool
func sell_item(trader: Trader, item_id: String, quantity: int) -> bool
func get_market_price(item_id: String) -> float
func get_player_credits() -> int
func add_credits(amount: int) -> void
func trigger_economic_event(event_type: EconomicEvent.EventType, affected_goods: Array[String]) -> void
func get_trade_history(days_back: int) -> Array[TradeRecord]
func calculate_profit_loss() -> float
```

#### Trader
```gdscript
func get_available_items() -> Array[String]
func get_item_quantity(item_id: String) -> int
func get_buy_price(item_id: String) -> float
func get_sell_price(item_id: String) -> float
func negotiate_price(item_id: String, is_buying: bool, player_reputation: float) -> float
func refresh_inventory() -> void
func get_relationship_status() -> String
```

### Configuration Options

#### Market Settings
- Base prices for all goods
- Volatility ranges per item category
- Supply/demand update frequencies
- Economic event probabilities

#### Trader Settings
- Inventory refresh rates
- Relationship impact weights
- Negotiation skill modifiers
- Faction-specific price adjustments

## Testing Strategy

### Unit Tests
- Price calculation accuracy
- Transaction processing
- Inventory management
- Market data updates

### Integration Tests
- Full trade cycles with multiple traders
- Economic event triggers and effects
- Cross-session persistence
- UI integration for trading

### Edge Cases
- Insufficient credits/funds
- Inventory capacity limits
- Market crash recovery
- Trader relationship extremes

## Reusability Guidelines

### Adapting for Other Projects

#### Fantasy RPG Trading
```gdscript
# Add magic item trading
class MagicItemTrader extends Trader:
    func get_enchanted_price(item: MagicItem) -> float:
        var base_price = item.base_value
        var enchantment_multiplier = 1.0 + item.enchantment_level * 0.25
        return base_price * enchantment_multiplier
```

#### Space 4X Game
```gdscript
# Add interstellar trade routes
class TradeRoute:
    var start_station: Station
    var end_station: Station
    var goods_flow: Dictionary
    var travel_time: float
    var risk_factor: float

    func simulate_trade() -> void:
        for good_id in goods_flow:
            var amount = goods_flow[good_id]
            start_station.adjust_inventory(good_id, -amount)
            end_station.adjust_inventory(good_id, amount)
```

#### Mobile Game Microtransactions
```gdscript
# Add premium currency system
class PremiumTrader extends Trader:
    var premium_currency: int = 0

    func buy_premium_item(item_id: String) -> bool:
        var item_data = PremiumShop.get_item(item_id)
        if premium_currency >= item_data.cost:
            premium_currency -= item_data.cost
            # Grant item
            return true
        return false
```

### Extension Mechanisms

#### Custom Trade Logic
```gdscript
class CustomTradeRule:
    var name: String
    var condition: Callable
    var modifier: Callable

    func applies_to_trade(trader: Trader, item_id: String) -> bool:
        return condition.call(trader, item_id)

    func modify_transaction(trade_data: Dictionary) -> Dictionary:
        return modifier.call(trade_data)
```

#### Dynamic Market Events
```gdscript
class MarketEventGenerator:
    static func generate_random_event() -> EconomicEvent:
        var event_types = EconomicEvent.EventType.values()
        var random_type = event_types[randi() % event_types.size()]

        var event = EconomicEvent.new()
        event.event_type = random_type
        event.duration = randf_range(300, 1800)  # 5-30 minutes
        event.effect_strength = randf_range(0.5, 2.0)

        # Randomly select affected goods
        var all_goods = TradeManager.get_all_goods()
        var affected_count = randi_range(1, min(3, all_goods.size()))
        event.affected_goods = []

        for i in range(affected_count):
            var random_good = all_goods[randi() % all_goods.size()]
            if not event.affected_goods.has(random_good):
                event.affected_goods.append(random_good)

        return event
```

This trade system provides a comprehensive economic framework for any game requiring resource management and merchant interactions, with clean separation between market mechanics and entity implementations.