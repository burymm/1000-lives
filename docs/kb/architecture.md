# Архитектура

## Движок и настройки

- Godot 4.7, GDScript. Рендер: GL Compatibility (`gl_compatibility`) — low-end / веб.
- Окно 1920x1080, stretch mode `canvas_items`, aspect `expand`.
- GUI theme: `res://ui/theme.tres`.
- `physics/common/enable_object_picking=true` — клик по объектам в 3D.

## Запуск и autoload

- Главная сцена: `res://demo_level/world_castle.tscn` (см. `project.godot` → `[application] run/main_scene`).
- Autoload (`project.godot` → `[autoload]`):
  - `ItemIcons` = `res://player/item_system/item_icon_renderer.gd` — рендер иконок предметов в ячейках GridInventory (TextureRect прямо в ячейке).

## Editor-плагины

- Включён: `res://addons/chest_editor/plugin.cfg` — редактор сундуков (заполнение loot table / предметов сундука). Папка `addons/ladder_gizmo/` — отключён/устарел.

## Структура каталогов (корень проекта Godot)

| Каталог | Роль |
|---------|------|
| `player/` | Всё про игрока: контроллер, анимации, предметы, инвентарь, экипировка, сенсоры, шаги |
| `ui/` | Меню игрока, HUD (здоровье, слоты), карточки смерти и управления |
| `enemy/` | Враги: базовая механика, root motion, анимации, сенсоры, здоровье, патруль |
| `interactable objects/` | Интерактив: сундуки, двери, ворота, лестницы, рычаги, точки спавна |
| `audio/` | SoundFXSystem, layout шин, музыка/звуки |
| `cameras/` | Камеры: follow (за игроком), area |
| `demo_level/` | Демо-сцена `world_castle.tscn`, gridmap |
| `addons/` | Плагины редактора |
| `utility scripts/` | Вспомогательные: switch-системы, 3D-гизмо условий |

## Поток запуска сцены

1. Godot грузит `world_castle.tscn`: игрок, сундуки, враги, двери, ворота, лестницы, точки спавна, gridmap.
2. Autoload `ItemIcons` доступен сразу и рендерит иконки предметов в ячейках инвентаря.
3. Игрок: `player/player_charbody3d.tscn` (CharacterBody3D) + `player/player_start.tscn` (точка входа/спавна).
4. Управление: input actions из `project.godot` → `[input]`; интеракция с миром — через `player/player_interact_sensors/sensor_cast.tscn` (raycast-сенсор).
