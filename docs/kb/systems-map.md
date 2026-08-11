# Карта файлов по системам

> Пути — от корня Godot-проекта (`1000-lives/`), если не сказано иное.

## Игрок (`player/`)

| Файл | Роль |
|------|------|
| `player_charbody3D.gd` / `.tscn` | Контроллер игрока (CharacterBody3D), движение/физика. Смерть: падение ниже `fall_death_height` (Y, по умолч. `-5.0`) или `health_system.died` → `death()`: `RunTimer.on_player_death()`, сигнал `death_started`, через 3 с ждёт нажатия любой кнопки → `reload_current_scene()` |
| `player_anim_tree.gd` | Управление AnimationTree игрока |
| `player_start.gd` / `.tscn` | Точка входа/спавна игрока |
| `player_stats.gd` | Статы персонажа |
| `player_targeting_model.gd` | Логика прицеливания/наведения |
| `player_targeting_system/player_targeting_system.gd` / `.tscn` | Система прицеливания: `eye_list.gd` (видимые цели), `gui_reticle.gd` (прицел) |
| `player_interact_sensors/sensor_cast.gd` / `.tscn` | Сенсор интеракции (raycast, что в фокусе) |
| `equipment_system/equipment_system.gd` / `.tscn` | Экипировка: руки `RightHand`/`LeftHand`, сигнал `equipment_changed` |
| `equipment_system/equipment/` | 3D-визуалы: `sword.tscn`, `shield.tscn`, `Ax.tscn`, `torch_gadget.tscn` + `TorchFlame.gd`, `weapon_streak.gd` (след оружия) |
| `item_system/item_system.gd` | Связка: подбор предметов из мира → инвентарь → иконки |
| `item_system/inventory_system.gd` | Инвентарь игрока: `grid` (GridInventory) + `equipment` (EquipmentSystem), сигналы `item_added`/`item_removed`/`equipment_changed` |
| `item_system/grid_inventory.gd` | Сеточный инвентарь (по умолчанию 10x5), `items: Dictionary[Vector2i, GridItem]` |
| `item_system/chest_inventory.gd` | extends GridInventory, сетка 5x5 — инвентарь сундука |
| `item_system/item_resource.gd` | Ресурс предмета: `object_type` (DRINK/THROWN/OTHER/WEAPON), `size`, `icon`, `model`, `unique_loot_data`, `loot_table` |
| `item_system/item_object.gd` | Физический предмет в мире; если задан `loot_table` — спавнит дроп |
| `item_system/pickup_object.gd` | Подбираемый объект (Area3D) |
| `item_system/item_icon_renderer.gd` | **Autoload `ItemIcons`**: иконки предметов в ячейках GridInventory |
| `item_system/items/` | Готовые предметы: `bread`, `potion`, `firebomb`, `rock` (+ вариации `rock_small/medium/large/boulder`), `shield`, `sword` (pickup .tscn) |
| `footfall_system/` | Шаги: `footfall_system.gd`/`.tscn`, `foostep_sound_system.gd`/`.tscn` |
| `animation_libraries/MeleeLib.res` | Анимации ближнего боя |

## UI (`ui/`)

| Файл | Роль |
|------|------|
| `player_menu.gd` / `.tscn` | Главное меню игрока; **строится кодом**: сетка инвентаря + панель сундука, drag&drop |
| `item_slot.gd` | Ячейка предмета (слот UI) |
| `health_bar.gd` | Полоска здоровья |
| `death_card.gd` | Класс карточки смерти (`LifeDeathCard`); в сценах напрямую не подключён — см. карточку внутри `player_charbody3d.tscn` |
| `run_time_card.gd` | Заполняет карточку смерти временами: «SURVIVED» (текущий забег) и «BEST» (рекорд) из autoload `RunTimer`; подключён к узлу `DeadBackground` |
| `contol_card.gd` | Карточка управления |
| `theme.tres` | Тема GUI проекта |

> Карточка смерти живёт **внутри `player/player_charbody3d.tscn`** (`TriggeredSounds/LifeCardAnimations/`): `AnimationPlayer` (анимации `lifecard`/`deadcard`), `DeadBackground` (градиент-фон, анимируется), внутри него — `Label` «GAME OVER» + `RunTimeLabel`/`BestTimeLabel` (заполняет `run_time_card.gd`). Сигнал `death_started` игрока → анимация + звук.

## Враги (`enemy/`)

| Файл | Роль |
|------|------|
| `enemy_base_root_motion.gd` / `.tscn` | База врага с root motion |
| `enemy_root_anim_tree.gd` | AnimationTree врага |
| `enemy_area_target_sensor.gd` / `.tscn` | Сенсор поиска цели (Area3D) |
| `health_system.gd` | Здоровье (у врагов/игрока) |
| `patrol_point.gd` | Точка патруля |

## Интерактив (`interactable objects/`)

| Папка | Файлы | Роль |
|-------|-------|------|
| `chest/` | `chest_object.gd`, `chest.tscn` | Сундук; внутри `ChestInventory` (5x5), открытие → панель в `player_menu.gd` |
| `doors/` | `door_object.gd`/`.tscn`, `gate_object.gd`/`.tscn` | Двери и ворота |
| `ladder/` | `ladder.gd`/`.tscn` | Лестницы |
| `lever/` | `lever_object.gd`/`.tscn` | Рычаги (переключатели) |
| `spawn_site/` | `spawn_site.gd`/`.tscn` | Точки спавна |

## Звук (`audio/`)

| Файл | Роль |
|------|------|
| `SoundFXSystem.gd` | Система звуковых эффектов |
| `default_bus_layout.tres` | Шины микшера |
| `bone_in_the_walls__level_loop_session.ogg` | Музыкальный луп уровня |

## Камеры (`cameras/`)

| Файл | Роль |
|------|------|
| `follow_cam/` | Камера, следующая за игроком |
| `area_cam/` | Камера-область (для зон/локаций) |

## Плагины (`addons/`)

| Папка | Роль |
|-------|------|
| `chest_editor/` | Редактор сундуков (включён в `project.godot`) |
| `ladder_gizmo/` | Устарел/отключён |

## Вспомогательное

| Путь | Роль |
|------|------|
| `utility scripts/switch_systems/` | Переключатели/условия |
| `utility scripts/switch_systems/condition_3d_gizmos/` | 3D-гизмо условий |
| `utility scripts/run_timer.gd` | **Autoload `RunTimer`**: таймер забега (время выживания + лучший результат), сохранение в `user://` |
| `demo_level/world_castle.tscn` | Главная демо-сцена |
| `demo_level/gridmap/` | Gridmap и материалы |

## Вне Godot-проекта (корень репозитория)

| Путь | Роль |
|------|------|
| `readme.md` | Дизайн-концепция игры |
| `doc/` | Дизайн-доки: атрибуты, ресурсы, бестиарий, backlog, engine-notes |
| `tasks/` | Задачи (task1.md, task2.md, task3.md) |
| `AGENTS.md` | Правила для агентов (git-политика, качество кода) |
| `docs/kb/` | Эта база знаний |
