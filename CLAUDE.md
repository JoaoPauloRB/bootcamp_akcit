# Ashes of the Forge — Implementation Guide

## Overview

Top-down Zelda-like action RPG. Swordsman explores 3 areas, fights slimes and skeletons, forges upgrades at an anvil, defeats the Skeleton Warrior boss.

## Project Structure

```
ashes-of-the-forge/
├── project.godot
├── GDD.md
├── CLAUDE.md
├── assets/
│   ├── sprites/
│   │   ├── player/          # Swordsman lvl1/2/3
│   │   ├── enemies/         # Slimes, Skeletons, Orcs
│   │   ├── npcs/            # Knight, Rogue, Wizard
│   │   └── items/           # Weapons
│   ├── tilesets/            # Dungeon, Floor, Wall, Water tiles
│   ├── audio/
│   │   ├── music/           # xDeviruchi tracks
│   │   └── sfx/             # Kenney RPG + Interface
│   └── ui/                  # Full RPG UI kit
├── scenes/
│   ├── player/
│   ├── enemies/
│   ├── world/
│   └── ui/
├── scripts/
│   ├── player/
│   ├── enemies/
│   ├── world/
│   ├── components/          # Reusable: health, AI, hitbox
│   └── autoloads/           # GameManager, Events
└── resources/
```

## Collision Layers

| Layer # | Name | Bitmask | Layer Value | Used By |
|---------|------|---------|-------------|---------|
| 1 | World | 1 | 1 | Walls, obstacles, tilemap collision |
| 2 | Player | 2 | 2 | Player CharacterBody2D |
| 3 | Enemies | 4 | 4 | Enemy CharacterBody2D |
| 4 | PlayerHitbox | 8 | 8 | Sword swing Area2D |
| 5 | EnemyHitbox | 16 | 16 | Enemy attack Area2D |
| 6 | Pickups | 32 | 32 | Dropped items, resources |

### Collision Matrix

| Entity | Layer (I am) | Mask (I detect) |
|--------|-------------|-----------------|
| Player body | 2 | 1 (walls) |
| Enemy body | 3 | 1 (walls), 3 (other enemies) |
| Player sword hitbox | 4 | 5 (enemy hurtbox) — NOT USED, see below |
| Enemy attack hitbox | 5 | 4 (player hurtbox) — NOT USED, see below |
| Player hurtbox | 4 | 5 (enemy hitbox) |
| Enemy hurtbox | 5 | 4 (player hitbox) |
| Pickup | 6 | 2 (player) |

**Damage pattern:** Use Area2D hitbox/hurtbox. NEVER use body-to-body collision for damage. Use `area_entered` + periodic `get_overlapping_areas()` polling for contact damage.

## Input Map

| Action | Keys | Usage |
|--------|------|-------|
| move_up | W, Up Arrow | Movement |
| move_down | S, Down Arrow | Movement |
| move_left | A, Left Arrow | Movement |
| move_right | D, Right Arrow | Movement |
| attack | J, Z, Space | Sword attack |
| interact | K, X, Enter | NPC talk, Anvil use |
| pause | Escape, P | Pause menu |

## Player Stats

| Stat | Value |
|------|-------|
| Speed | 80 px/s |
| HP | 3 hearts (6 half-hearts) |
| Max HP | 6 hearts (12 half-hearts) |
| Attack damage | 1 heart |
| Attack cooldown | 0.4s |
| Invincibility after hit | 1.0s |
| Stun duration | 0.3s |

## Enemy Stats

### Slimes
| Stat | Green | Blue | Red |
|------|-------|------|-----|
| HP (hits) | 2 | 3 | 4 |
| Damage | 0.5 heart | 1 heart | 1.5 hearts |
| Speed | 30 px/s | 40 px/s | 50 px/s |
| Aggro range | none (wander) | 96 px | 128 px |

### Skeletons
| Stat | Base | Warrior (Boss) |
|------|------|----------------|
| HP (hits) | 4 | 10 |
| Damage | 1 heart | 2 hearts |
| Speed | 50 px/s | 60 px/s |
| Aggro range | 96 px | always |

## Coding Conventions

- GDScript 4.x with static typing on ALL variables and functions
- Group exports: `@export_group("Stats")`, `@export_group("Combat")`
- Signals for decoupled communication (Events autoload bus)
- Components pattern: HealthComponent, HitboxComponent, HurtboxComponent
- AnimatedSprite2D with SpriteFrames (default approach)
- State machine for player and complex enemies (idle, run, attack, hurt, dead)
- NO magic numbers — use @export or const
- Directions: use Vector2 for facing, map to animation names

## Autoloads

| Name | Purpose |
|------|---------|
| GameManager | Game state, current room, player data, respawn |
| Events | Signal bus for decoupled communication |

## Build Order

1. Player (movement + animation)
2. Sword attack (hitbox)
3. Slime enemy (AI + damage)
4. Combat system (health, damage, death)
5. World (3 rooms with transitions)
6. Forging system (Anvil + visual upgrade)
7. Skeleton enemy + Boss
8. HUD (hearts, resources)
9. NPCs + dialogue
10. Audio (music per room + SFX)
11. Polish (screen shake, hit flash, particles)

## Anti-Patterns (DO NOT)

- Do NOT use body-to-body collision for damage
- Do NOT guess sprite sheet layouts — analyze first
- Do NOT use `area_entered` alone for contact damage (add polling)
- Do NOT block all input during hurt state (keep stun short: 0.3s)
- Do NOT forget post-respawn invincibility (2.0s cooldown)
- Do NOT put UI in world space — use CanvasLayer
- Do NOT share keybinds between attack and interact
- Do NOT skip audio — add it in Phase 4
- Do NOT use TileMap (deprecated) — use TileMapLayer
