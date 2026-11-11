
# MRBLUE - 2D Godot Learning Project

<p align="center">
  <img  src="/mrblue_game/Recording 2025-07-20 135407.gif">
</p>

## 📖 About
A simple 2D platformer I'm developing to learn Godot Engine and game development fundamentals. 

## 🎮 Features
- 1-4 players on one screen (two keyboard halves + four gamepads), runs full screen (F11 toggles a window)
- 5 heroes, each with their own size, passive, **special move** (dash button) and **ultimate** (full mana bar)
- Gold: coins, enemies and time bonuses pay gold; hearts carry over between levels
- **The Tipsy Slime** tavern between levels: a store (permanent upgrades), a bar (pie, punch, extra lives, a bet, rumors) and two minigames
- Minigames: **Sky Duel** (fly, dodge bullet patterns, shoot down Baron Bat) and **Shooting Gallery** (first-person target practice)
- 10 levels in 2 worlds; three of them scroll on their own (1-4, 2-3, 2-4)
- 2 bosses with telegraphed attacks and three phases: Queen Slime (1-5) and King Pinky (2-5)
- Enemies: pinkies, slimes, spiky slimes, rock-throwing grumps, bats, chargers, lava fireballs
- Springs, crumbling planks, elevators, moving platforms, spikes, lava, checkpoints
- Levels are plain text in `scripts/level_data.gd` (legend at the top of the file)

| Hero | Size | Passive | Move (dash button) | Ultimate |
|---|---|---|---|---|
| PRONTO | medium | runs faster | **Turbo Dash**: invincible burst, also in the air | **Pronto Rush**: 3 s of invincible speed |
| ELI | small | jumps higher, wall slide + wall jump | **Dive Kick**: diagonal kick that bounces off enemies | **Sky Slam**: leap, crash, shockwave |
| SHEE | medium | hold jump to glide | **Blink**: short teleport in any direction | **Storm Wings**: 5 s of flight with lightning |
| GUENI | huge | 5 hearts, down in the air = ground pound | **Bull Charge**: armored ram, smashes crates | **Firewall**: team heal + 4 s shield |
| IHEB | big | always has rocks | **Rock Jump**: boulder down, hero up | **Rock Storm**: rain of boulders |

## ⌨️ Controls
| | Move | Jump | Action (run / throw) | Dash (special move) | Ultimate |
|---|---|---|---|---|---|
| Keys 1 | A D (S = down) | W / Space | F | Left Shift / G | E / Q |
| Keys 2 | Arrows | Up | Enter | Right Shift | Right Ctrl |
| Gamepad | Stick / D-pad | A | X | B / LB | Y / RB |

```bash
git clone https://github.com/gueni/mrblue.git
```

