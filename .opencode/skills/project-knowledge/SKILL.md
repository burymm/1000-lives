---
name: project-knowledge
description: Use when working in the 1000-lives Godot project and you need to understand where systems/files live, how inventory/items/chests/equipment work, or which conventions apply. Loads a compact project map so you can skip re-discovering the codebase (searching, listing directories, reading project.godot).
---

# База знаний: 1000-lives (Godot 4.7)

Компактная карта проекта. Если нужны детали — читай `docs/kb/` (глубокие доки), затем код.

## Быстрые факты

- Godot **4.7**, GDScript, рендер **GL Compatibility**.
- Главная сцена: `res://demo_level/world_castle.tscn`.
- Autoload: `ItemIcons` = `res://player/item_system/item_icon_renderer.gd` (иконки предметов в ячейках инвентаря).
- Editor-плагин: `res://addons/chest_editor/plugin.cfg` (редактор сундуков).
- Репозиторий: Godot-проект в `1000-lives/`, дизайн в `doc/`, задачи в `tasks/`, правила — `AGENTS.md`.

## Структура Godot-проекта

| Каталог | Роль |
|---------|------|
| `player/` | Контроллер, анимации, предметы/инвентарь/экипировка, сенсоры, шаги |
| `ui/` | `player_menu.gd` (инвентарь+сундук, drag&drop), HUD, карточки смерти/управления |
| `enemy/` | Враги: база, root motion, анимации, сенсоры, здоровье, патруль |
| `interactable objects/` | `chest/`, `doors/`, `gate`, `ladder/`, `lever/`, `spawn_site/` |
| `audio/` | `SoundFXSystem.gd`, музыка |
| `cameras/` | follow_cam, area_cam |
| `demo_level/` | `world_castle.tscn` (главная сцена), gridmap |
| `addons/` | chest_editor (включён), ladder_gizmo (устарел) |
| `utility scripts/` | switch_systems, condition_3d_gizmos |

## Ключевые файлы

- Контроллер игрока: `player/player_charbody3D.gd` (CharacterBody3D). Спавн: `player_start.tscn`.
- Интеракция: `player/player_interact_sensors/sensor_cast.gd` (raycast-сенсор).
- Прицеливание: `player/player_targeting_system/player_targeting_system.gd` (+ `eye_list.gd`, `gui_reticle.gd`).
- Здоровье: `enemy/health_system.gd` (общий для врагов/игрока).
- Сеточный инвентарь: `player/item_system/grid_inventory.gd` (10x5, `items: Dictionary[Vector2i, GridItem]`), подкласс `chest_inventory.gd` (5x5).
- Инвентарь игрока: `item_system/inventory_system.gd` (grid + equipment, сигналы item_added/item_removed/equipment_changed).
- Экипировка: `equipment_system/equipment_system.gd` — руки `RightHand` (weapon) / `LeftHand` (gadget); 3D-визуалы в `equipment_system/equipment/` (`sword.tscn`, `shield.tscn`, `Ax.tscn`, `torch_gadget.tscn`).
- Предмет: `item_system/item_resource.gd` (object_type DRINK/THROWN/OTHER/WEAPON, size, icon, loot_table) → `item_object.gd`/`pickup_object.gd`. Готовые: `item_system/items/` (bread, potion, firebomb, rock, shield, sword).
- Сундук: `interactable objects/chest/chest_object.gd` + `chest.tscn` (ChestInventory 5x5), панель в `ui/player_menu.gd`.
- Шаги: `player/footfall_system/`.

## Поток предметов (коротко)

1. Мир: `ItemObject`/`PickupObject` → подбор через `ItemSystem`.
2. `InventorySystem` (игрок) = grid (10x5) + equipment (RightHand/LeftHand).
3. Сундук: открыли → панель в `player_menu.gd`, сетка сундука 5x5 рядом с инвентарём; перенос 1:1.
4. Drag&drop в UI: типы данных `"inventory"`, `"equipment"`, `"chest"`; sword→RightHand, shield→LeftHand.
5. Иконки в ячейках рисует autoload `ItemIcons`.

## Правила (AGENTS.md)

- Git: коммиты/пуши только по явной команде; перед коммитом `git status`/`git diff`; сообщение ≤140 символов.
- Код: повторяющийся фрагмент ~5+ строк в 2+ местах → выносить в общий метод/базовый класс.

## Куда углубиться

- `docs/kb/index.md` — навигация по базе знаний.
- `docs/kb/architecture.md` — запуск, autoload, структура.
- `docs/kb/systems-map.md` — полная карта файлов.
- `docs/kb/item-inventory.md` — детали инвентаря/сундуков/экипировки.
- `docs/kb/conventions.md` — соглашения, именование.
- `doc/` — дизайн-доки (атрибуты, ресурсы, бестиарий, backlog). Концепция — `readme.md` в корне репо.
