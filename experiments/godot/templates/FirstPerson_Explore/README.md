# First Person Exploration Template for Godot 4

A basic template for creating first-person exploration games in Godot 4.

## Features

- First-person character controller with smooth movement and mouse look
- Jump mechanics
- Basic level with walls and floor
- Simple input mapping

## Project Structure

```
FirstPerson_Explore/
├── project.godot          # Godot project configuration
├── scenes/
│   ├── level.tscn         # Main level scene with player and environment
│   └── player.tscn        # Player character scene
└── scripts/
	└── player.gd          # Player movement and look script
```

## How to Use

1. Open the project in Godot 4
2. The main scene is set to `scenes/level.tscn` in project.godot
3. Press F5 to run the game
4. Use WASD keys to move, mouse to look around, and Space to jump

## Customization

- Adjust player speed, sensitivity, and jump force in `scripts/player.gd`
- Modify the level in `scenes/level.tscn` by adding more geometry or changing existing elements
- Extend the player script to add interaction systems, inventory, etc.

## Requirements

- Godot 4.x

## License

This template is free to use and modify for personal and commercial projects.
