# Структура уровня и как его модифицировать

## Общая схема

Уровень — сборка из трёх слоёв:

| Слой | Где | Что это |
|------|-----|---------|
| Террейн | `NavigationRegion3D` → `Staging` (инстанс `stagingCSG.tscn`, ставится 2 раза) | Геометрия/архитектура |
| Контент | Прямо в `world_castle.tscn` | Игрок, пикапы, враги, интерактив, камеры |
| Окружение | Прямо в `world_castle.tscn` | Небо/туман, свет, музыка |

Главная сцена: `demo_level/world_castle.tscn` (текстовый .tscn, ~537 строк).
Террейн вынесен в отдельную библиотечную сцену `demo_level/stagingCSG.tscn` — оба инстанса в `world_castle.tscn` используют её.

## Террейн (`demo_level/stagingCSG.tscn`)

| Узел | Назначение |
|------|-----------|
| `CityGrid` | GridMap, ячейка 4×4 — крупные блоки |
| `LevelGrid` | GridMap, ячейка 1×1 — детали |
| `Node3D` | Декор: `RockMultiMesh`, `PlankMultimesh`, `OmniLight3D`, факелы `Lighting/Torch*` (`torch.tscn`) |

Общие ресурсы:
- Меш-библиотека: `demo_level/gridmap/gridmap_basic.tres` (меши из `tilemap_basic.glb`).
- Материалы: `demo_level/gridmap/gridmap_materials/`.

## Контент в `world_castle.tscn`

| Группа | Узлы |
|--------|------|
| Игрок | `PlayerCharacterBodySoulsBase` (инстанс `player_charbody3d.tscn`) |
| Пикапы | `BreadPickup` ×3, `Rock*` ×5 (rock.tscn, разные item_resource) |
| Камера | `AreaCam` (Area3D + Pivot + Camera3D, скрипт `cameras/area_cam/area_cam.gd`) |
| Враги | `Enemies/EnemyBase` ×10 + патрульные `Path3D`/`PathFollow3D` |
| Интерактив | `Interactables/`: `ChestObject*` ×4, `DoorObject*` ×2, `GateObject*` ×2, `LeverObject*` ×2, `Ladder*` ×5, `SpawnSite` |
| UI | `ControlCard` (подсказки управления) |
| Звук | `Music` (AudioStreamPlayer) |

## Как редактировать

- **Террейн:** открыть `stagingCSG.tscn`, кистью GridMap (`LevelGrid`/`CityGrid`) рисовать из меш-библиотеки. Правки библиотечной сцены применяются к обоим инстансам Staging.
- **Объекты:** открыть `world_castle.tscn`, в дереве сцены перемещать/дублировать/удалять узлы (позиции — `transform` узла).
- **Связи:** рычаг → ворота через `node_to_control` (NodePath); враг → цель через `default_target` (указывает на патрульные точки).
- **Окружение:** `WorldEnvironment` (sky/fog) и два `DirectionalLight3D` в главной сцене.
- **Вручную .tscn не править** — сетки клеток и данные GridMap хранятся как `PackedInt32Array`, редактируются только в редакторе.

## Важно: навигация врагов

При изменении террейна **перепечь** `NavigationMesh` (у `NavigationRegion3D` baked-меш `NavigationMesh_8axki` в начале файла): выделить `NavigationRegion3D` → кнопка Bake. Иначе враги пойдут по старым путям.
