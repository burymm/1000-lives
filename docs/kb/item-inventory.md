# Предметы, инвентарь, экипировка, сундуки

## Схема систем

```
ItemResource (.tres)          — данные предмета (тип, размер, иконка, модель, дроп)
   ↓ создаётся из
ItemObject / PickupObject     — физический предмет в мире (Area3D)
   ↓ подбор (ItemSystem)
InventorySystem (игрок)
   ├── grid: GridInventory (10x5)          — сетка предметов
   └── equipment: EquipmentSystem
          ├── weapon_system  = RightHand   — оружие
          └── gadget_system  = LeftHand    — щит/факел
ChestInventory (5x5)         — extends GridInventory, у каждого сундука своя
```

## ItemResource (`player/item_system/item_resource.gd`)

- `object_type`: enum `DRINK | THROWN | OTHER | WEAPON`.
- `size: Vector2i` — занимаемая площадь в сетке.
- `icon` — иконка (используется autoload `ItemIcons`).
- `model` — 3D-модель для мира.
- `unique_loot_data` / `loot_table: NodePath` — если задан loot table, `ItemObject` при спавне генерирует дроп (предметы из сундука/источника).

## GridInventory (`grid_inventory.gd`)

- Сетка по умолчанию `Vector2i(10, 5)`.
- `items: Dictionary[Vector2i, GridItem]` — ключ = позиция клетки.
- API: `contains_item(id)`, `add_item`, `remove_item`, `get_specific_item` и др.
- `ChestInventory` (`chest_inventory.gd`) расширяет его со сеткой `Vector2i(5, 5)`.

## InventorySystem (`inventory_system.gd`)

- Агрегирует `grid` + `equipment`.
- Сигналы: `item_added`, `item_removed`, `equipment_changed` — по ним обновляется UI.

## EquipmentSystem (`equipment_system.gd`)

- Два слота-руки: `RightHand` (weapon_system) и `LeftHand` (gadget_system).
- `equip`/`unequip` по шаблонам (в `player/equipment_system/equipment/` лежат 3D-визуалы: `sword.tscn`, `shield.tscn`, `Ax.tscn`, `torch_gadget.tscn`).
- Экипированный предмет отображается в руках игрока.
- Сигнал `equipment_changed` обновляет визуалы/UI.

## UI и drag&drop (`ui/player_menu.gd`)

Меню строится кодом. Drag-данные различаются по строковому типу:

| Тип данных | Что это |
|------------|---------|
| `"inventory"` | Ячейка инвентаря игрока (GridInventory) |
| `"equipment"` | Слот экипировки (RightHand/LeftHand) |
| `"chest"` | Ячейка инвентаря сундука (ChestInventory) |

Логика:
- `_can_drop_data` / `_drop_data` определяют, из какого источника данные, и решают действие.
- Перенос между инвентарём игрока и сундуком — 1:1 через `_move_items` (позиция → позиция).
- Перетаскивание предмета на слот экипировки: `sword` → RightHand, `shield` → LeftHand; прочие предметы возвращаются в инвентарь.
- Предмет можно перетащить на свободную клетку **своей же сетки** (инвентаря или сундука) — `GridInventory.move_item()`; если цель занята ровно одним предметом и тот помещается на старое место, предметы меняются местами.
- Клик по слоту на силуэте выбирает экипированный предмет; кнопка **Drop** тогда вызывает `InventorySystem.drop_equipped(slot)` (снимает и выбрасывает в мир). Общий спавн брошенного предмета в мире — `_spawn_world_item()` (энергия + физический экземпляр перед игроком).
- Autoload `ItemIcons` рендерит иконку предмета прямо в ячейке сетки.
- Иконки на силуэте персонажа масштабируются единой логикой `_size_slot_icon` (все слоты): `scale = min(slot_w/icon_w, slot_h/icon_h) * SLOT_ICON_SHRINK` (0.8), размер и позиция задаются явно (нужен `EXPAND_IGNORE_SIZE`, иначе `TextureRect` клампится к нативному размеру текстуры). Старые фиксированные `HAND_ICON_SCALE`/`HEAD_ICON_SHRINK` убраны.

## Сундук (`interactable objects/chest/`)

- `chest_object.gd` + `chest.tscn`: физический сундук с `ChestInventory` (5x5).
- Взаимодействие: сенсор игрока → открыть сундук → в `player_menu.gd` появляется панель сундука (сетка сундука, обычно справа) рядом с инвентарём игрока (слева).
- Клик по предмету в сундуке → перенос в инвентарь игрока (через drag&drop / прямой клик).
- В редакторе сундук настраивается плагином `addons/chest_editor`.

## Как добавить новый предмет

1. Создать `ItemResource` (.tres) в `player/item_system/items/` (тип, размер, иконка, модель).
2. При необходимости — pickup-сцену `.tscn` (примеры: `sword_pickup.tscn`, `shield_pickup.tscn`, `potion.tscn`).
3. Добавить предмет в loot table сундука (плагин chest_editor) или в инвентарь игрока в сцене.
