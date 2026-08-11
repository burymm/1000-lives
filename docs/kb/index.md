# База знаний проекта 1000-lives

Краткая справочная документация по кодовой базе Godot-проекта.
Цель — не перечитывать код целиком при каждой задаче: сначала сюда, потом в код.

## Навигация

| Документ | О чём |
|----------|-------|
| [architecture.md](architecture.md) | Движок, запуск, autoload, сцены, структура каталогов |
| [systems-map.md](systems-map.md) | Карта файлов по системам: где что лежит |
| [item-inventory.md](item-inventory.md) | Предметы, инвентарь, экипировка, сундуки, drag&drop в UI |
| [level.md](level.md) | Структура уровня (террейн GridMap, контент, окружение) и как его редактировать |
| [conventions.md](conventions.md) | Соглашения проекта (git, качество кода, именование) |

## Быстрый старт (30 секунд)

- Godot **4.7**, GDScript, рендер **GL Compatibility**.
- Запуск: `res://demo_level/world_castle.tscn` — главная сцена.
- Autoload: `ItemIcons` = `res://player/item_system/item_icon_renderer.gd` (иконки предметов в ячейках инвентаря) и `RunTimer` = `res://utility scripts/run_timer.gd` (таймер забега, лучшее время → `user://`).
- Репозиторий: Godot-проект живёт в подпапке `1000-lives/`; в корне — дизайн-концепция `readme.md`, доки `doc/`, задачи `tasks/`, правила `AGENTS.md`.
- Дизайн-доки (не код): `doc/README.md` (атрибуты и ресурсы), `doc/attributes/*.md`, `doc/resources/*.md`, `doc/backlog.md`, `doc/bestiary.md`, `doc/engine-notes.md`.

## Золотые правила

1. Изменения только по явной команде: никаких `git commit`/`push` без запроса.
2. Перед коммитом — показать `git status`/`git diff`, сообщение до 140 символов.
3. Повторяющийся код (~5+ строк в 2+ местах) — выносить в общий метод/базовый класс.
