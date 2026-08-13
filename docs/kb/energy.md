# Энергия игрока

Дизайн: `doc/resources/energy.md`, задача `tasks/task5.md`. Код: `player/energy_system.gd`.

## Роль

`EnergySystem` — узел в `player/player_charbody3d.tscn` (Node, `class_name EnergySystem`). Энергия тратится всегда (от массы) и за действия; при 0 — смерть (`player_node.death()`).

Подключается: `player_node` (игрок) + `inventory_system` (для восстановления едой). В сцене корень игрока получает `energy_system = NodePath("EnergySystem")`.

## Ключевые точки

- **Масса:** тело = `strength / 10` (450 → 45 кг), рука = 5 % тела; общая `m` = тело + надетое + инвентарь. Пересчитывается динамически → пороги тоже.
- **Стоимости:** стояние `m/1000`; отдых `m/3000`; шаг `m/100` (ступеньки ×1.5/×1.15, лестница ×3/×2, бег +100 %); прыжок 6 шагов; спрыгивание 2 шага; кувырок 4 шага; подбор предмета 2 взмаха; выброс 1 взмах; бросок 5 взмахов; атака `swing_cost`; защита `block_cost`/с.
- **Пороги:** `can_attack()` (2 взмаха), `can_block()` (5 с щита), `can_move()` (5 шагов).
- **Отдых:** `resting` + сигнал `rest_toggled`; расход ×3 дешевле; нельзя двигаться/драться, инвентарь доступен.
- **Восстановление:** еда/напитки из инвентаря → `_on_item_used` → плавное восстановление за `digest_time` (`energy`/`digest_time` на `ItemResource`). Хлеб 5000 за 5 с.
- **Сигналы:** `energy_updated(current, max)` (на каждое списание/восстановление), `rest_toggled(resting)`.

## Гейтинг действий (игрок, `player_charbody3D.gd`)

Помощники: `_can_fight()` / `_can_block_guard()` / `_can_move()` / `_is_resting()` (строки ~325-335). Используются в:

- `_input` — атака/бросок/гаджеты (fight), прыжок/кувырок/бег (move), вся активность выключена в отдыхе;
- `start_guard()` — блокировка без энергии не начинается;
- `set_root_move()` / `set_root_climb()` — при «не могу двигаться» ввод обнуляется;
- `throw_equipped()` — гейт `_can_fight()`.

## Ввод (project.godot)

- Действие **`rest`** = клавиша **R** (переключатель отдыха). Старое `use_item` с R **убран** — еда/питьё только через инвентарь (`player_menu.gd` `_on_use_pressed` → `player_node.use_item()` → сигнал `use_item_started` → `inventory_system._on_item_used_signal` → `item_used` → энергия).
- Надпись «REST» — узел `GUI/RestLabel` в `player_charbody3d.tscn`; видимость управляется `_on_rest_toggled`.

## Стоимости в коде вне energy_system

- Подбор предмета: `pickup_object.gd` `activate()` → `spend_swings(2.0, item.weight)`.
- Выброс из инвентаря: `inventory_system.gd` `drop_item()` → `spend_swings(1.0, item.weight)`.

## chest_editor и параметры еды

- `addons/chest_editor/chest_grid_editor.gd` при добавлении предмета в сундук делает **локальную копию** (`clone_item()` + `resource_local_to_scene = true`) — каждый предмет в мире независим, `weight`/`energy`/`digest_time` правятся прямо в редакторе карт.
- Клик по предмету в гриде → выделение → спинбоксы Weight/Energy/Digest time ниже; замена — drag&drop или двойной клик; удаление — ПКМ.

## Статус в меню

Вкладка «Status» (`player_menu.gd`): текущая энергия и расход при стоянии (`standing_drain()`), обновляются в `_process` пока меню открыто.

## Debug HUD (кнопка «*», numpad)

Тогл в `player_charbody3D.gd` (`_toggle_debug_hud`, действие `debug_hud` в `project.godot`, numpad `*` и `Shift+8`, также F8). Панель строится кодом (CanvasLayer layer 20). Показывает: энергию, текущий расход/с и его режим (`last_drain_mode`: stand/walk/stairs up/climb up/rest/… + guard/sprint), массу и стоимости (step/swing/block), пороги, и журнал последних действий из `energy_system.spent_report` (сигнал `spent_report(amount, label)` эмитится на jump/dodge/attack/throw/fall/pickup/drop — метки передаются через опц. параметр `label` в `spend`/`spend_steps`/`spend_swings`).

## Переопределения на пикапах (per-pickup values)

`pickup_object.gd` (PickupObject) имеет экспортируемые значения `weight` / `energy` / `digest_time` (значение `-1` = наследовать из `item_resource`). Решение: `effective_weight()/effective_energy()/effective_digest_time()`. При подборе `activate(player)` собирает предмет через `build_item()` (клонирует `item_resource` и применяет значения) — в инвентарь попадает копия с индивидуальными значениями. Так каждый хлеб/камень в мире может отличаться от общего `.tres`-шаблона без создания отдельных файлов. В инспекторе узла пикапа поля называются Weight / Energy / Digest Time.
