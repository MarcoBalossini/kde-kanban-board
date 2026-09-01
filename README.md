# Kanban Board — Plasma 6 widget

A minimal kanban board that lives on your KDE desktop (or in a panel).
Pure QML/KPackage — no compilation needed.

![screenshot](doc/board.png)

![dark](doc/board-dark.png)

## Install

```bash
./install.sh
```

Then right-click the desktop → **Add Widgets…** → **Kanban Board**.

Run `./install.sh` again after any edit. **A widget already on the desktop will
keep running the old QML**: plasmashell holds it in memory and also keeps a
compiled QML disk cache, so an upgrade alone changes nothing on screen. To
install, drop the cache and restart the shell in one go:

```bash
./install.sh --restart
```

Remove with `./uninstall.sh`.

## Use

| Action | How |
| --- | --- |
| Add a task | `+` in a list header, or the **Add task** row at the bottom |
| Add several in a row | keep typing — the field stays open after <kbd>Enter</kbd> |
| Complete a task | click the circle |
| Flag a task as important | hover it, click the ☆ — the card gets a red frame |
| Edit a task | double-click it |
| Delete a task | hover it, click the ✕ (or clear the text while editing) |
| Move a task | drag it — within a list or across lists |
| Give a card a deadline | hover it, click 📅 (or right-click → *Set deadline…*) |
| Change or drop a deadline | click the date chip on the card; **No deadline** clears it |
| Split a card into steps | hover it, click ☑ (or right-click → *Split into steps*) — then type the steps |
| Tick a step | click its circle — the card completes itself once every step is ticked |
| Show / hide the steps | click the progress bar on the card |
| Edit / delete a step | double-click it; hover it and click the ✕ (or clear the text) |
| Back to a plain card | right-click → *Remove all steps* |
| Rename a list | double-click its name, or ⋮ → *Rename list* |
| Split a list | ⋮ → *Split into sections* — then name the new block |
| Add another section | the **Add section** row at the bottom of a split list |
| Rename a section | double-click its name, or its ⋮ → *Rename section* |
| Collapse a section | the arrow button left of its name |
| Reorder sections | section ⋮ → *Move up / Move down* |
| Undo the split | ⋮ → *Merge sections* |
| Recolor a list | click the dot next to its name |
| Add / remove / reorder lists | the `+` panel at the right end of the board, ⋮ → *Move left/right*, *Delete list* |
| Clear finished work | ⋮ → *Clear completed* (per list, or per section) |

A card that is late says so on the card, and the list and section headers say
how many of theirs are late, so work does not go missing inside a folded block.

An important card keeps its list's colour and gains a solid red frame. No list
accent is red — the palette is blue, amber, green, violet, teal — so the frame
never competes with a column, and it stays on the card when it is dragged
elsewhere.

<kbd>Esc</kbd> cancels any inline edit.

## Sections

A list can be split vertically into named blocks — *Research* → **WIP / Writing
/ Review** — instead of spreading one workflow over several boards. Blocks stack
inside the list they belong to, keep the list's colour, and are drop targets in
their own right: dragging a card between two blocks of the same list is the same
gesture as dragging it to another list.

A block is exactly as tall as the cards in it — one card is one card's worth of
list, not a fixed slice of it — and it grows and shrinks as cards come and go.
An empty block folds itself down to its title strip and unfolds the moment a
card lands in it, so a *Review* nobody is using costs one line instead of a
third of the list. The arrow button opens one anyway — to type straight into it
— and folding a block by hand sticks until you open it again. A folded block is
still a drop target: drop a card on the strip and it opens.

Splitting a list that already holds cards keeps them together in a block named
*Unsorted*; rename it and carry on. Deleting a block never deletes work — its
cards join the block above it (or below, for the first one) — and *Merge
sections* folds everything back into one plain list, in order.

A list nobody has split has no section chrome at all, so an unsplit board looks
and behaves exactly as before.

## Steps

A card that is really several things is split into steps instead of into three
cards: a checklist that belongs to the card and travels with it. The card keeps
one line of text and gains a progress bar — `2/5` — that folds the checklist
away; click the bar to open it again. Whether it is open is remembered per card.

Steps drive their card, not the other way round. Ticking the last step completes
the card, and reopening a step reopens it, so a card's circle never disagrees
with its checklist. A card with no steps is untouched by any of this and its
circle works exactly as it always did.

Steps ride along with the card: drag it to another section or another list and
the checklist goes with it, ticks included. Clearing a step's text deletes it,
the same gesture as on a card, and *Remove all steps* turns a split card back
into a plain one without touching the card itself.

## Deadlines

A card can be due on a day — a day, not a minute, so a card is late from the
morning after and never from some arbitrary hour. The date sits on the card as a
small chip, under its text: **Today**, **Tomorrow**, **Yesterday**, a weekday
name for the rest of this week, and a date beyond that. Amber for today and
tomorrow, red once the day has passed, muted on a card that is finished — a
completed card is never late, however long it sat there.

Clicking the chip (or the 📅 that appears on hover) opens the picker: **Today**,
**Tomorrow** and **Next week** for the dates people actually pick, a month grid
for the rest, and **No deadline** to take the date off again. It opens on the
month the card is already due in, so correcting a date never starts by paging
back to it, and the month name is a button back to this month.

Late work is counted where it can still be seen: a red *n late* next to a list's
name and next to a section's, so a folded *Review* holding an overdue card still
admits it, and the panel badge turns red while anything is overdue. Deadlines
ride along with the card when it is dragged elsewhere, and a card nobody dated
carries no date field at all.

## Settings

Right-click the widget → **Configure Kanban Board…**: background opacity
(0–100%; the widget paints its own background, so this is a real slider), list
width, per-list task counters, compact cards, and strike-through or hiding of
completed tasks. The board name is used only for the panel tooltip.

## Where the data lives

The board is stored as JSON in the widget's own config, so every instance keeps
its own board and it survives restarts. Each list holds a list of sections; a
board written before sections existed (`version: 1`) is read as one nameless
section per list and rewritten as `version: 2` on the next change. A card only
carries a `steps` array once it has been split, and a `due` day ("YYYY-MM-DD",
with no timezone on it, so a board keeps the day it was given) once it has been
dated, so a board of plain cards is byte-for-byte what it was:

```
~/.config/plasma-org.kde.plasma.desktop-appletsrc
```

## Layout

```
package/
  metadata.json                 plugin id, icon, category
  contents/
    config/main.xml             config keys + defaults
    config/config.qml           config page list
    ui/main.qml                 applet root: board model, load/save, header
    ui/KanbanColumn.qml         one list: header, section stack, scroller, menu
    ui/KanbanSection.qml        one block of a list: cards, drop target, menu
    ui/TaskCard.qml             one card: check, star, text, deadline, steps, drag source
    ui/TaskComposer.qml         inline "add task" / "add step" field
    ui/DuePicker.qml            deadline picker: quick rows plus a month grid
    ui/dates.js                 day arithmetic for deadlines ("YYYY-MM-DD")
    icons/org.kde.plasma.kanbanboard.svg   widget logo (also copied into the icon theme)
    ui/configGeneral.qml        settings page
tests/run.sh                    headless behaviour tests (qmltestrunner)
assets/logo.svg, logo.png       standalone logo, for docs and listings
```

Tasks are held in the section model as JSON, not only inside the delegates, so a
rebuilt or scrolled-away column can never lose them.

## Tests

```bash
./tests/run.sh
```

Runs the list/card/section logic (add, edit, complete, flag as important, set
and clear deadlines, day arithmetic, overdue counting, drag between lists and
between sections, reorder, split, collapse, delete and merge sections, split a
card into steps, clear completed, write-back) headlessly with
`qmltestrunner-qt6`.

## Requirements

Plasma 6, Qt 6, KDE Frameworks 6. Developed against Plasma 6.7 / Qt 6.11.
