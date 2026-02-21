# 32bit-spacer

![32bit-spacer](icon.png)

**A retro-futuristic space exploration roguelike** built in Godot 4.5. Pilot your ship through procedurally generated sectors, scavenge for parts, craft advanced equipment, and program AI drones in this deep space survival adventure.

## 🌟 Features

### Core Gameplay
- **Infinite Sector Exploration**: Procedurally generated universe with coordinate-based deterministic seeding
- **Resource Loop**: Mine asteroids, scavenge derelict ships, craft components, build ships
- **Real-time Combat**: Fast-paced space dogfights with upgradeable weapons
- **Roguelike Progression**: Permadeath with persistent unlocks and meta-progression

### Advanced Systems
- **Drone Programming**: Multi-paradigm AI creation (Lua scripting, visual DSL, config-based)
- **Ship Building**: Component-based assembly with stat balancing and compatibility systems
- **Dynamic Economy**: Market fluctuations, merchant AI, trade routes
- **Complex Crafting**: Mining → Scavenging → Refining → Assembly pipeline

### Technical Features
- **Cross-Platform**: PC (Windows/Mac/Linux) with mobile adaptation
- **Modular Architecture**: Clean system separation for easy expansion
- **Performance Optimized**: Handles 50+ simultaneous entities
- **Comprehensive Documentation**: Enterprise-level GDDs for all systems

## 🚀 Quick Start

### Prerequisites
- **Godot 4.5+** (Mono version for C# features)
- **4GB RAM minimum** (8GB recommended)
- **OpenGL 3.3+ compatible graphics card**

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Burnsedia/32bit-Spacer.git
   cd 32bit-Spacer
   ```

2. **Open in Godot:**
   ```bash
   godot --editor project.godot
   ```

3. **Run the game:**
   - Press `F5` in Godot editor
   - Or export and run the executable

### Basic Controls

| Action | PC | Mobile |
|--------|----|--------|
| Movement | WASD | Virtual Joystick |
| Aim/Fire | Mouse | Touch & Drag |
| Boost | Space | Boost Button |
| Brake | Shift | Brake Button |
| Mining | Right Click | Tap Target |
| Scavenging | Approach Ship | Touch Mini-game |
| Open Menu | Tab | Menu Button |

## 🎮 Gameplay Overview

### The Journey
You are a stranded spacer whose jump drive has failed, leaving you adrift in an unknown sector of space. Your goal: repair your jump drive by collecting rare components scattered across the infinite universe.

### Core Loop
1. **Explore**: Navigate between sectors using jump drive charges
2. **Gather**: Mine asteroids and scavenge derelict ships for materials
3. **Craft**: Refine materials into components and build equipment
4. **Combat**: Fight space pirates and automated defenses
5. **Progress**: Upgrade your ship, unlock new technologies, expand your fleet

### Key Mechanics

#### Resource Management
- **Mining**: Extract minerals from asteroids using mining beams
- **Scavenging**: Salvage components from abandoned spacecraft
- **Crafting**: Transform raw materials into usable equipment
- **Trading**: Buy/sell goods with space stations and mobile merchants

#### Ship Building & Customization
- **Component Assembly**: Build ships from scavenged and crafted parts
- **Stat Balancing**: Manage power consumption, structural integrity, and performance
- **Visual Customization**: Customize ship appearance and equipment loadouts

#### Drone Programming
- **Lua Scripting**: Write complex AI behaviors for companion drones
- **Visual DSL**: Create behaviors with drag-and-drop interfaces
- **Config-Based**: Simple rule systems for mobile play
- **Fleet Coordination**: Command multiple drones with synchronized behaviors

#### Combat & Survival
- **Real-time Space Combat**: Dogfight with enemy ships and turrets
- **Tactical Positioning**: Use asteroids and debris for cover
- **Weapon Variety**: Lasers, missiles, plasma weapons with upgrade paths
- **Risk/Reward**: High-risk areas offer better rewards

## 🏗️ System Architecture

### Core Systems
- **Movement System**: 6DOF space flight with vector steering
- **Combat System**: Real-time weapon firing and damage calculation
- **AI System**: Vector steering with boids for swarm behavior
- **Progression System**: XP, leveling, and upgrade management

### World Systems
- **Sector Generator**: Infinite universe with coordinate-based seeding
- **Trade System**: Dynamic economy with merchant AI
- **Mining System**: Resource extraction with multiple methods
- **Scavenging System**: Component salvage from derelict ships

### Support Systems
- **UI System**: Neo-retro interface with accessibility features
- **Audio System**: Spatial sound with dynamic music
- **Visual Effects**: Particle systems and shader effects
- **Save/Load System**: Game persistence with cloud sync

### Advanced Features
- **Drone Programming System**: Multi-paradigm AI creation
- **Ship Building System**: Component assembly with stat balancing
- **Crafting Pipeline**: Mining → Scavenging → Refining → Assembly

## 📚 Documentation

Comprehensive Game Design Documents are available in the `docs/` directory:

### Core Documentation
- **[GAME_DESIGN_DOCUMENT.md](docs/GAME_DESIGN_DOCUMENT.md)**: Complete project overview
- **[AGENTS.md](AGENTS.md)**: Development guidelines and coding standards

### System Documentation
- [Movement_System_GDD.md](docs/Movement_System_GDD.md) - 3D physics and steering
- [Combat_System_GDD.md](docs/Combat_System_GDD.md) - Weapons and damage
- [AI_System_GDD.md](docs/AI_System_GDD.md) - Vector steering and boids
- [Progression_System_GDD.md](docs/Progression_System_GDD.md) - XP and upgrades
- [World_Generation_System_GDD.md](docs/World_Generation_System_GDD.md) - Procedural sectors
- [UI_System_GDD.md](docs/UI_System_GDD.md) - Interface design
- [Audio_System_GDD.md](docs/Audio_System_GDD.md) - Sound and music
- [Visual_Effects_System_GDD.md](docs/Visual_Effects_System_GDD.md) - Particles and shaders
- [Save_Load_System_GDD.md](docs/Save_Load_System_GDD.md) - Persistence
- [Sector_Generator_System_GDD.md](docs/Sector_Generator_System_GDD.md) - Infinite universe
- [Trade_System_GDD.md](docs/Trade_System_GDD.md) - Economy and merchants
- [Drone_Programming_System_GDD.md](docs/Drone_Programming_System_GDD.md) - AI creation
- [Mining_System_GDD.md](docs/Mining_System_GDD.md) - Resource extraction
- [Scavenging_System_GDD.md](docs/Scavenging_System_GDD.md) - Component salvage
- [Ship_Building_System_GDD.md](docs/Ship_Building_System_GDD.md) - Ship assembly

## 🛠️ Development

### Project Structure
```
32bit-spacer/
├── scenes/           # Godot scene files
├── scripts/          # GDScript source code
│   ├── player/       # Player-related systems
│   ├── ai/          # AI and drone systems
│   ├── world/       # World generation
│   └── ui/          # Interface systems
├── resources/        # Game assets and data
├── docs/            # Design documents
├── AGENTS.md        # Development guidelines
└── project.godot    # Godot project file
```

### Building from Source

1. **Clone and setup:**
   ```bash
   git clone https://github.com/Burnsedia/32bit-Spacer.git
   cd 32bit-Spacer
   ```

2. **Open in Godot 4.5:**
   ```bash
   godot --editor project.godot
   ```

3. **Export for your platform:**
   - Project → Export
   - Choose target platform
   - Configure export settings

### Testing
```bash
# Run tests (when implemented)
godot --run-tests project.godot

# Check GDScript syntax
find scripts/ -name "*.gd" -exec godot --check-only {} \;
```

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Follow the coding standards in `AGENTS.md`
4. Test your changes thoroughly
5. Submit a pull request

### Coding Standards
- Follow the guidelines in `AGENTS.md`
- Use GDScript type hints
- Write comprehensive documentation
- Test on multiple platforms

### Reporting Issues
- Use GitHub Issues for bugs and feature requests
- Include system information and reproduction steps
- Attach screenshots/logs when applicable

## 📋 Roadmap

### Version 0.1.0 (Current)
- ✅ Core movement and combat systems
- ✅ Basic world generation
- ✅ UI framework
- ✅ Documentation suite

### Version 0.2.0 (Next)
- [ ] Mining and scavenging mechanics
- [ ] Basic crafting system
- [ ] Ship building foundation
- [ ] Save/load system

### Version 0.3.0
- [ ] Drone programming (Lua scripting)
- [ ] Advanced AI behaviors
- [ ] Trade system
- [ ] Sector exploration

### Version 1.0.0 (Full Release)
- [ ] Complete crafting pipeline
- [ ] All drone programming paradigms
- [ ] Full trade economy
- [ ] Mobile platform support

## 🎯 Vision & Philosophy

**32bit-spacer** is designed as a love letter to classic space games with modern depth. The project emphasizes:

- **Emergent Gameplay**: Simple rules create complex, replayable experiences
- **Player Agency**: Deep customization through crafting and programming
- **Narrative Freedom**: Environmental storytelling without railroading
- **Technical Excellence**: Clean architecture and comprehensive documentation
- **Accessibility**: Multiple control schemes and difficulty options

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Godot Engine**: Incredible open-source game engine
- **FreeCodeCamp**: Original inspiration for roguelike mechanics
- **Space Game Community**: Endless inspiration from classic and modern titles
- **Open Source Community**: Libraries and tools that made this possible

## 📞 Contact & Support

- **Project Lead**: Burnsedia
- **Repository**: [GitHub](https://github.com/Burnsedia/32bit-Spacer)
- **Issues**: [GitHub Issues](https://github.com/Burnsedia/32bit-Spacer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Burnsedia/32bit-Spacer/discussions)

---

**Fly safe, spacer. The void is waiting.** 🚀✨
