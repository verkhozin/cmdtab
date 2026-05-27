---
name: cmdtab
type: idea
status: seed
category: devtools
stack: standalone
created: 2026-05-06
updated: 2026-05-06
tags: [macos, swift, app-switcher, cmd-tab, productivity]
parent: "[[macTools]]"
---

# cmdtab — кастомный Cmd+Tab с группами

- One-liner: Замена стандартного Cmd+Tab переключателя. Apps можно объединять в группы («Dev», «Comms», «Music»), переключаться между группами, кастомизировать внешний вид.

## Сценарии

- Группа «Work» в одном Cmd+Tab, «Personal» в другом — переключаешься в нужный контекст одним хоткеем
- Видишь только релевантные app в текущей группе — меньше шума
- Кастомизация: размер иконок, blur, размещение на экране, расстояние между элементами
- Опционально: drag-and-drop в самом switcher'е чтобы перекидывать window между app'ами

## Подвохи

- Полностью заменить системный Cmd+Tab — нельзя без ставить замены через accessibility-trick. Чаще делают свой хоткей и уживаются параллельно.
- Иконки приложений в высоком разрешении — иногда грязные, нужен fallback chain
- AppleScript / AX-вызов для активации окна выбранного app

## MVP

Перехват custom-хоткея → custom switcher с одной группой. Без UI настроек на старте — группы хардкодим в JSON. 4-5 дней.

## Status

🟡 Seed.
