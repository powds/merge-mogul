# Build Status Report - Merge Mogul

## Project Overview
- **Engine**: Godot 4.6 (Forward Plus)
- **Platform**: Android (min SDK 21, target SDK 34)
- **Main Scene**: `res://main.tscn` ✓

---

## Project Structure

### Autoloads (5 registered)
| Autoload | Path | Purpose |
|----------|------|---------|
| SaveSystem | `scripts/autoload/save_system.gd` | Static JSON save/load functions |
| Settings | `scripts/autoload/settings.gd` | User preferences (audio, display) |
| Audio | `scripts/autoload/audio.gd` | SFX player pool system |
| AdManager | `scripts/autoload/ad_manager.gd` | Ad stubs (banner, interstitial, rewarded) |
| VaultManager | `scripts/autoload/vault_manager.gd` | PIN auth, decoy vault, lockout |

### Missing Autoload
| File | Issue |
|------|-------|
| `scripts/autoload/game_state.gd` | **NOT registered** - defines `GameState` enum used by game logic |

### Scene Scripts (.gd in scenes/)
| File | Extends | Purpose |
|------|---------|---------|
| `main.gd` | Control | Entry point, menu/game state transitions |
| `scenes/menus/main_menu.gd` | Control | Main menu UI |
| `scenes/game/item.gd` | Node2D | MergeItem class (tier-based items) |
| `scenes/game/ui.gd` | CanvasLayer | In-game UI overlay |
| `scenes/vault/vault_manager.gd` | Node | Vault UI controller |
| `scenes/utility/app_launcher.gd` | Control | App launcher UI |
| `scenes/utility/gallery.gd` | Control | Gallery viewer |
| `scenes/utility/file_browser.gd` | Node | File browser logic |

### Game Scripts (.gd in scripts/game/)
| File | Extends | Purpose |
|------|---------|---------|
| `scripts/game/game.gd` | Node2D | Main game logic |
| `scripts/game/game_manager.gd` | Node | Game manager |
| `scripts/game/board.gd` | Node | Board logic |
| `scripts/game/item.gd` | Area2D | Item class (separate from scenes version) |
| `scripts/game/ui.gd` | CanvasLayer | Game UI layer |

### Other Scripts
| File | Extends | Purpose |
|------|---------|---------|
| `scripts/vault/vault_storage.gd` | Node | Vault storage logic |

### Scenes (.tscn - 15 total)
| Scene | Purpose |
|-------|---------|
| `main.tscn` | Main entry point |
| `scenes/menus/main_menu.tscn` | Main menu |
| `scenes/game/game.tscn` | Main game |
| `scenes/game/board.tscn` | Game board grid |
| `scenes/game/cell.tscn` | Board cell |
| `scenes/game/item.tscn` | Item visual |
| `scenes/game/ui.tscn` | Game UI |
| `scenes/vault/vault_main.tscn` | Vault main UI |
| `scenes/vault/vault_settings.tscn` | Vault settings |
| `scenes/vault/pin_screen.tscn` | PIN entry screen |
| `scenes/menus/settings.tscn` | Settings menu |
| `scenes/menus/achievements.tscn` | Achievements screen |
| `scenes/utility/gallery.tscn` | Gallery viewer |
| `scenes/utility/file_browser.tscn` | File browser |
| `scenes/utility/apps_list.tscn` | Apps list |

### Assets
| Directory | Status |
|-----------|--------|
| `assets/images/` | ✓ 9 item tier images present |
| `assets/audio/sfx/` | ✗ **MISSING** - no audio files |

---

## What Works

- ✓ Main scene correctly configured in project.godot
- ✓ All 5 autoloads properly registered and loadable
- ✓ Android export configuration complete
- ✓ Settings system with persistence (ConfigFile)
- ✓ Save system with JSON storage
- ✓ Vault system with PIN auth, decoy vault, lockout
- ✓ Ad manager stub implementation ready for real SDK
- ✓ Menu navigation (main menu → game)
- ✓ Item tier system (8 tiers with images)
- ✓ Game board and cell structure
- ✓ UI layer structure

---

## What's Broken

1. **`game_state.gd` not registered as autoload**
   - File exists at `scripts/autoload/game_state.gd`
   - Defines `GameState` enum used by game logic
   - **Missing from `[autoload]` section in project.godot**
   - Will cause runtime errors if code references `GameState` enum

2. **Duplicate item classes**
   - `scripts/game/item.gd` defines `class_name Item` (extends Area2D)
   - `scenes/game/item.gd` defines `class_name MergeItem` (extends Node2D)
   - Confusing naming, potential conflicts

---

## What's Missing

1. **Audio files** - `assets/audio/sfx/` directory doesn't exist
   - Referenced: `ui_click.ogg`, `ui_hover.ogg`, `merge.ogg`, `level_up.ogg`
   - Audio autoload will log warnings but won't crash

2. **Music system** - Audio autoload only handles SFX, no music player

3. **Icon.svg** - Referenced in project.godot but not found in project root

4. **game_state.gd registration** - Needs to be added to autoloads

5. **Some scenes may need implementation**:
   - achievements.tscn
   - apps_list.tscn
   - file_browser implementation completeness

---

## Recommended Fixes

### 1. Add game_state to autoloads (Critical)
In `project.godot`, add:
```
GameState="*res://scripts/autoload/game_state.gd"
```

### 2. Create audio directory
```bash
mkdir -p assets/audio/sfx/
# Add placeholder audio files
```

### 3. Resolve duplicate item classes
Decide which item class is canonical and remove/rename the other.
