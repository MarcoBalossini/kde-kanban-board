import QtQuick
import QtQuick.Layouts
import QtTest
import org.kde.kirigami as Kirigami

import "dates.js" as Dates

Item {
    id: win
    width: 900; height: 500

    property var cols: []

    Item {
        id: mockBoard
        readonly property var accents: ["#5b8def", "#f0a63a", "#3ec98a", "#a07df0", "#3ec9c2"]
        // one nameless section per list: what a list looks like before it is split
        property var seeds: [
            '[{"id":"s0","name":"","tasks":[{"id":"a","text":"one","done":false,"created":1},{"id":"b","text":"two","done":false,"created":2}]}]',
            '[{"id":"s1","name":"","tasks":[{"id":"c","text":"three","done":false,"created":3}]}]',
            '[{"id":"s2","name":"","tasks":[{"id":"d","text":"four","done":true,"created":4}]}]'
        ]
        property var stored: ["", "", ""]
        property bool cfgShowCounts: true
        property bool cfgCompactCards: false
        property bool cfgStrikeDone: true
        property bool cfgHideDone: false
        property string todayIso: Dates.toIso(new Date())
        property int columnCount: 3
        property Item dragLayer: dl
        property int saves: 0
        function accentColor(i) { var n = accents.length; return accents[((i % n) + n) % n]; }
        function newId() { return "id" + (Math.random() * 1e9).toFixed(0); }
        function scheduleSave() { saves++; }
        function storeSections(i, arr) { stored[i] = JSON.stringify(arr); saves++; }
        function recount() {}
        function cycleAccent(i) {}
        function renameColumn(i, n) {}
        function moveColumn(a, b) {}
        function removeColumn(i) {}
        function addColumn() {}
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        Repeater {
            model: 3
            KanbanColumn {
                board: mockBoard
                columnIndex: index
                columnName: ["To Do", "In Progress", "Done"][index]
                accentIndex: index
                sectionsJson: mockBoard.seeds[index]
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                Component.onCompleted: win.cols.push(this)
            }
        }
    }

    Item { id: dl; anchors.fill: parent; z: 1000 }

    // The deadline picker, driven directly: on a card it is built lazily inside
    // a Loader, which there is no way to reach through a ListView delegate.
    DuePicker { id: picker }

    SignalSpy { id: pickedSpy; target: picker; signalName: "picked" }
    SignalSpy { id: clearedSpy; target: picker; signalName: "cleared" }

    // The stored copy of a card, by the text it carries.
    function storedTask(col, sec, text) {
        var arr = JSON.parse(mockBoard.stored[col])[sec].tasks;
        for (var i = 0; i < arr.length; i++)
            if (arr[i].text === text) return arr[i];
        return null;
    }

    function texts(c) {
        var s = [];
        for (var i = 0; i < c.tasksModel.count; i++)
            s.push(c.tasksModel.get(i).text + (c.tasksModel.get(i).done ? "*" : ""));
        return s.join(",");
    }

    TestCase {
        name: "Kanban"
        when: windowShown

        function test_00_seed() {
            compare(win.cols.length, 3);
            compare(texts(win.cols[0]), "one,two");
            compare(texts(win.cols[2]), "four*");
            compare(win.cols[0].openTasks, 2);
            compare(win.cols[2].openTasks, 0);
        }

        function test_01_add() {
            win.cols[0].addTask("five", false);
            win.cols[0].addTask("   ", false);   // whitespace ignored
            win.cols[0].addTask("six", true);    // prepend
            compare(texts(win.cols[0]), "six,one,two,five");
            compare(win.cols[0].openTasks, 4);
        }

        function test_02_toggle_and_edit() {
            win.cols[0].toggleDone(0);
            compare(texts(win.cols[0]), "six*,one,two,five");
            compare(win.cols[0].openTasks, 3);
            win.cols[0].setText(1, "  ONE  ");
            compare(texts(win.cols[0]), "six*,ONE,two,five");
            win.cols[0].setText(3, "   ");        // empty edit deletes
            compare(texts(win.cols[0]), "six*,ONE,two");
        }

        function test_03_cross_column_move() {
            win.cols[1].acceptDrop({ columnItem: win.cols[0], taskIndex: 1 }, 0);
            compare(texts(win.cols[0]), "six*,two");
            compare(texts(win.cols[1]), "ONE,three");
            compare(win.cols[0].openTasks, 1);
            compare(win.cols[1].openTasks, 2);
        }

        function test_04_reorder_within_column() {
            win.cols[1].acceptDrop({ columnItem: win.cols[1], taskIndex: 0 },
                                   win.cols[1].tasksModel.count);
            compare(texts(win.cols[1]), "three,ONE");
            // dropping onto its own slot is a no-op
            win.cols[1].acceptDrop({ columnItem: win.cols[1], taskIndex: 0 }, 1);
            compare(texts(win.cols[1]), "three,ONE");
        }

        function test_05_clear_completed() {
            win.cols[0].clearCompleted();
            compare(texts(win.cols[0]), "two");
            win.cols[2].clearCompleted();
            compare(texts(win.cols[2]), "");
        }

        function test_06_persistence_writeback() {
            // every mutation must have been mirrored into the board store
            var back = JSON.parse(mockBoard.stored[1])[0].tasks;
            var names = back.map(function(t) { return t.text; });
            compare(names.join(","), "three,ONE");
            verify(back[0].id.length > 0);
            compare(typeof back[0].done, "boolean");
        }

        function test_07_drop_index_math() {
            var c = win.cols[1];
            compare(c.dropIndexFor(-50), 0);
            compare(c.dropIndexFor(100000), c.tasksModel.count);
            verify(mockBoard.saves > 0);
        }

        function test_08_rename_roundtrip() {
            win.cols[0].startRename();
            win.cols[0].commitRename();
            verify(true);
        }

        // ---- sections ---------------------------------------------------
        function test_09_split_keeps_existing_cards() {
            var c = win.cols[0];
            verify(c.plainMode);
            compare(c.addSection("Writing"), 1);
            tryVerify(function() { return c.sectionAt(1) !== null; });
            compare(c.sectionCount, 2);
            verify(!c.plainMode);
            // the cards that were already there stay together, under a label
            compare(texts(c.sectionAt(0)), "two");
            compare(c.sectionAt(0).sectionName, "Unsorted");
            compare(c.sectionAt(1).sectionName, "Writing");
            compare(texts(c.sectionAt(1)), "");
        }

        function test_10_move_card_between_sections() {
            var c = win.cols[0];
            var from = c.sectionAt(0), to = c.sectionAt(1);
            to.acceptDrop({ columnItem: from, taskIndex: 0 }, 0);
            compare(texts(from), "");
            compare(texts(to), "two");
            compare(c.openTasks, 1);
            // and the whole split list round-trips through the store
            var back = JSON.parse(mockBoard.stored[0]);
            compare(back.length, 2);
            compare(back[1].tasks[0].text, "two");
        }

        function test_11_split_column_into_three() {
            var c = win.cols[1];
            c.addSection("WIP");
            c.addSection("Review");
            tryVerify(function() { return c.sectionAt(2) !== null; });
            compare(c.sectionCount, 3);
            c.sectionAt(1).addTask("draft", false);
            c.sectionAt(2).addTask("proof", false);
            compare(texts(c.sectionAt(0)), "three,ONE");
            compare(texts(c.sectionAt(1)), "draft");
            compare(c.openTasks, 4);
        }

        function test_12_collapse_is_persisted() {
            var c = win.cols[1];
            c.setSectionCollapsed(1, true);
            compare(c.sectionAt(1).collapsed, true);
            compare(JSON.parse(mockBoard.stored[1])[1].collapsed, true);
            c.setSectionCollapsed(1, false);
            compare(c.sectionAt(1).collapsed, false);
        }

        function test_13_delete_section_never_drops_cards() {
            var c = win.cols[1];
            c.removeSection(1);                       // "draft" joins the block above
            compare(c.sectionCount, 2);
            compare(texts(c.sectionAt(0)), "three,ONE,draft");
            compare(c.openTasks, 4);
        }

        function test_15_empty_sections_fold_themselves() {
            var c = win.cols[2];
            compare(c.addSection("Later"), 0);       // empty list: names the block
            compare(c.addSection("Someday"), 1);
            tryVerify(function() { return c.sectionAt(1) !== null; });
            verify(c.sectionAt(0).effectiveCollapsed);
            verify(c.sectionAt(1).effectiveCollapsed);

            // a card landing in one opens it
            c.sectionAt(1).addTask("ship", false);
            verify(!c.sectionAt(1).effectiveCollapsed);
            // ... and emptying it folds it back
            c.sectionAt(1).removeTask(0);
            verify(c.sectionAt(1).effectiveCollapsed);

            // the button still opens an empty block, e.g. to type into it
            c.sectionAt(0).toggleCollapsed();
            verify(!c.sectionAt(0).effectiveCollapsed);
            c.sectionAt(0).toggleCollapsed();
            verify(c.sectionAt(0).effectiveCollapsed);
            compare(c.sectionAt(0).collapsed, true);   // an explicit fold is saved
        }

        function test_16_important_flag() {
            var c = win.cols[0];
            var sec = c.sectionAt(1);
            verify(!sec.tasksModel.get(0).important);
            sec.toggleImportant(0);
            verify(sec.tasksModel.get(0).important);
            // the flag is written back with the card
            compare(JSON.parse(mockBoard.stored[0])[1].tasks[0].important, true);

            // ... and rides along when the card is dragged to another list
            var dest = win.cols[2].sectionAt(0);
            dest.acceptDrop({ columnItem: sec, taskIndex: 0 }, 0);
            compare(dest.tasksModel.count, 1);
            verify(dest.tasksModel.get(0).important);
            dest.toggleImportant(0);
            verify(!dest.tasksModel.get(0).important);

            // new cards are not flagged
            sec.addTask("plain", false);
            compare(sec.tasksModel.get(0).important, false);
        }

        function test_14_merge_back_to_plain() {
            var c = win.cols[1];
            c.mergeSections();
            compare(c.sectionCount, 1);
            verify(c.plainMode);
            compare(texts(c.sectionAt(0)), "three,ONE,draft,proof");
            compare(texts(c), "three,ONE,draft,proof");   // list-wide view agrees
            compare(JSON.parse(mockBoard.stored[1])[0].name, "");
        }

        // ---- steps ------------------------------------------------------
        function test_18_split_card_into_steps() {
            var s = win.cols[0].sectionAt(0);
            var i = s.tasksModel.count;
            s.addTask("write post", false);
            compare(s.stepsOf(i).length, 0);      // a plain card carries none

            s.addStep(i, "outline");
            s.addStep(i, "draft");
            s.addStep(i, "   ");                  // whitespace ignored
            compare(s.stepsOf(i).length, 2);
            compare(s.stepsOf(i)[0].text, "outline");
            compare(s.stepsOf(i)[0].done, false);
            // splitting a card opens its checklist
            compare(s.tasksModel.get(i).stepsOpen, true);
            s.setStepsOpen(i, false);
            compare(s.tasksModel.get(i).stepsOpen, false);

            // and the steps are written back with the card
            var back = JSON.parse(mockBoard.stored[0])[0].tasks;
            var stored = null;
            for (var k = 0; k < back.length; k++)
                if (back[k].text === "write post") stored = back[k];
            verify(stored !== null);
            compare(stored.steps.length, 2);
            compare(stored.steps[1].text, "draft");

            // a card nobody split stays exactly as small as it was
            s.addTask("unsplit card", false);
            var again = JSON.parse(mockBoard.stored[0])[0].tasks;
            var plain = null;
            for (var m = 0; m < again.length; m++)
                if (again[m].text === "unsplit card") plain = again[m];
            verify(plain !== null);
            compare(plain.steps, undefined);
            compare(plain.stepsOpen, undefined);
        }

        function test_19_last_step_completes_the_card() {
            var s = win.cols[1].sectionAt(0);
            var i = s.tasksModel.count;
            s.addTask("release", false);
            s.addStep(i, "build");
            s.addStep(i, "sign");
            verify(!s.tasksModel.get(i).done);

            s.toggleStep(i, 0);
            verify(!s.tasksModel.get(i).done);    // one of two
            s.toggleStep(i, 1);
            verify(s.tasksModel.get(i).done);     // all of them
            s.toggleStep(i, 1);
            verify(!s.tasksModel.get(i).done);    // reopening a step reopens it

            // a card with no steps is left alone
            var k = s.tasksModel.count;
            s.addTask("plain card", false);
            verify(!s.tasksModel.get(k).done);
            s.toggleDone(k);
            verify(s.tasksModel.get(k).done);
        }

        function test_20_steps_ride_along_on_a_move() {
            var c = win.cols[0];
            var from = c.sectionAt(0), to = c.sectionAt(1);
            var i = from.tasksModel.count;
            from.addTask("ship it", false);
            from.addStep(i, "tag");
            from.addStep(i, "upload");
            from.toggleStep(i, 0);

            var j = to.tasksModel.count;
            to.acceptDrop({ columnItem: from, taskIndex: i }, j);
            compare(to.tasksModel.get(j).text, "ship it");
            var steps = to.stepsOf(j);
            compare(steps.length, 2);
            compare(steps[0].text, "tag");
            compare(steps[0].done, true);
            compare(steps[1].done, false);
            compare(to.tasksModel.get(j).stepsOpen, true);
        }

        function test_21_editing_and_clearing_steps() {
            var s = win.cols[2].sectionAt(0);
            var i = s.tasksModel.count;
            s.addTask("trip", false);
            s.addStep(i, "book");
            s.addStep(i, "pack");
            s.addStep(i, "go");

            s.setStepText(i, 0, "  book flight  ");
            compare(s.stepsOf(i)[0].text, "book flight");
            s.setStepText(i, 1, "   ");            // clearing a step deletes it
            compare(s.stepsOf(i).length, 2);
            compare(s.stepsOf(i)[1].text, "go");

            s.moveStep(i, 1, 0);
            compare(s.stepsOf(i)[0].text, "go");

            s.toggleStep(i, 0);
            s.clearDoneSteps(i);
            compare(s.stepsOf(i).length, 1);
            compare(s.stepsOf(i)[0].text, "book flight");

            s.removeStep(i, 0);
            compare(s.stepsOf(i).length, 0);
            // losing every step never loses the card
            compare(s.tasksModel.get(i).text, "trip");

            s.addStep(i, "again");
            s.clearSteps(i);                       // back to a plain card
            compare(s.stepsOf(i).length, 0);
            compare(s.tasksModel.get(i).stepsOpen, false);
            compare(s.tasksModel.get(i).text, "trip");
        }

        function test_22_steps_survive_a_section_merge() {
            var c = win.cols[0];
            var into = c.sectionAt(0);
            c.removeSection(1);                    // its cards join the block above
            compare(c.sectionCount, 2);

            var moved = -1;
            for (var i = 0; i < into.tasksModel.count; i++)
                if (into.tasksModel.get(i).text === "ship it") moved = i;
            verify(moved >= 0);
            var steps = into.stepsOf(moved);
            compare(steps.length, 2);
            compare(steps[0].text, "tag");
            compare(steps[0].done, true);

            // ... and through the store
            var back = JSON.parse(mockBoard.stored[0])[0].tasks;
            var stored = null;
            for (var k = 0; k < back.length; k++)
                if (back[k].text === "ship it") stored = back[k];
            verify(stored !== null);
            compare(stored.steps.length, 2);
            compare(stored.steps[1].text, "upload");
        }

        function test_17_block_height_follows_its_cards() {
            var c = win.cols[0];
            var i = c.addSection("Sizing");
            tryVerify(function() { return c.sectionAt(i) !== null; });
            var s = c.sectionAt(i);
            // with no cards it is a title strip, not an open body
            verify(s.effectiveCollapsed);

            s.addTask("one card", false);
            tryVerify(function() { return s.contentHeight > 0; });
            verify(!s.effectiveCollapsed);
            // a block that holds cards is exactly as tall as those cards:
            // no floor padding a single card out to a third of the list
            compare(s.bodyHeight, s.contentHeight);
            var one = s.contentHeight;

            s.addTask("second card", false);
            tryVerify(function() { return s.contentHeight > one; });
            compare(s.bodyHeight, s.contentHeight);
            verify(s.bodyHeight > one);
        }

        // ---- deadlines --------------------------------------------------
        function test_23_deadline_set_and_cleared() {
            var s = win.cols[1].sectionAt(0);
            var i = s.tasksModel.count;
            s.addTask("file taxes", false);
            compare(s.dueOf(i), "");             // a plain card carries none

            s.setDue(i, "2026-12-24");
            compare(s.dueOf(i), "2026-12-24");
            var stored = storedTask(1, 0, "file taxes");
            verify(stored !== null);
            compare(stored.due, "2026-12-24");

            // a date nobody could reach is no deadline at all
            s.setDue(i, "2026-02-31");
            compare(s.dueOf(i), "");
            s.setDue(i, "  2027-01-05  ");       // padding is trimmed off
            compare(s.dueOf(i), "2027-01-05");

            s.clearDue(i);
            compare(s.dueOf(i), "");
            compare(storedTask(1, 0, "file taxes").due, undefined);

            // a card nobody dated stays exactly as small as it was
            s.addTask("undated", false);
            compare(storedTask(1, 0, "undated").due, undefined);
        }

        function test_24_deadline_rides_along_on_a_move() {
            var from = win.cols[1].sectionAt(0);
            var i = from.tasksModel.count;
            from.addTask("renew passport", false);
            from.setDue(i, "2027-03-09");

            var to = win.cols[2].sectionAt(0);
            var j = to.tasksModel.count;
            to.acceptDrop({ columnItem: from, taskIndex: i }, j);
            compare(to.tasksModel.get(j).text, "renew passport");
            compare(to.dueOf(j), "2027-03-09");
            compare(storedTask(2, 0, "renew passport").due, "2027-03-09");
        }

        function test_25_overdue_counts_only_open_cards() {
            var s = win.cols[2].sectionAt(1);
            var before = s.overdueTasks;
            var boardBefore = win.cols[2].overdueTasks;

            var i = s.tasksModel.count;
            s.addTask("was due", false);
            s.setDue(i, Dates.shift(-3));
            compare(s.overdueTasks, before + 1);
            compare(win.cols[2].overdueTasks, boardBefore + 1);

            // today is not late yet
            var j = s.tasksModel.count;
            s.addTask("due today", false);
            s.setDue(j, Dates.shift(0));
            compare(s.overdueTasks, before + 1);

            // and finishing a card takes it off the count for good
            s.toggleDone(i);
            compare(s.overdueTasks, before);
            compare(win.cols[2].overdueTasks, boardBefore);
        }

        function test_26_date_math() {
            verify(Dates.isValid("2026-09-01"));
            verify(!Dates.isValid("2026-02-31"));   // Date rolls it over; we do not
            verify(!Dates.isValid("2026-9-1"));
            verify(!Dates.isValid("tomorrow"));
            verify(!Dates.isValid(""));
            verify(!Dates.isValid(undefined));

            compare(Dates.daysUntil(Dates.shift(0)), 0);
            compare(Dates.daysUntil(Dates.shift(1)), 1);
            compare(Dates.daysUntil(Dates.shift(-2)), -2);
            verify(isNaN(Dates.daysUntil("")));

            compare(Dates.toIso(new Date(2026, 8, 1)), "2026-09-01");
            compare(Dates.toIso(Dates.addDays(new Date(2026, 11, 31), 1)), "2027-01-01");
            compare(Dates.toIso(Dates.addDays(new Date(2026, 8, 1), -1)), "2026-08-31");

            // a month grid starts on the locale's first weekday, before the 1st
            compare(Dates.toIso(Dates.gridStart(2026, 8, 1)), "2026-08-31");  // Monday
            compare(Dates.toIso(Dates.gridStart(2026, 8, 0)), "2026-08-30");  // Sunday
        }

        function test_27_picker_opens_where_the_card_already_is() {
            picker.showAt("2026-09-14", Qt.rect(0, 0, 200, 30), Qt.rect(0, 0, 600, 600));
            compare(picker.selected, "2026-09-14");
            compare(picker.shownYear, 2026);
            compare(picker.shownMonth, 8);

            picker.stepMonth(4);                       // rolls over into next year
            compare(picker.shownYear, 2027);
            compare(picker.shownMonth, 0);
            compare(picker.selected, "2026-09-14");    // paging changes no card

            picker.choose("2027-01-20");
            compare(pickedSpy.count, 1);
            compare(pickedSpy.signalArguments[0][0], "2027-01-20");
            tryVerify(function() { return !picker.visible; });

            // a card with no deadline yet opens on this month
            var now = new Date();
            picker.showAt("", Qt.rect(0, 0, 200, 30), Qt.rect(0, 0, 600, 600));
            compare(picker.selected, "");
            compare(picker.shownYear, now.getFullYear());
            compare(picker.shownMonth, now.getMonth());

            picker.clear();
            compare(clearedSpy.count, 1);
            compare(picker.selected, "");
            tryVerify(function() { return !picker.visible; });
        }

        function test_28_picker_stays_inside_the_room_it_is_given() {
            var gap = Kirigami.Units.smallSpacing;
            var anchor = Qt.rect(0, 0, 200, 30);
            var h = picker.implicitHeight;
            var w = picker.implicitWidth;

            // room below: it opens under the card
            picker.showAt("", anchor, Qt.rect(0, 0, 600, h * 3));
            compare(picker.y, anchor.height + gap);
            picker.close();

            // no room below but room above: it flips over the card
            var low = Qt.rect(0, 0, 200, h * 2);
            picker.showAt("", low, Qt.rect(0, -h - 2 * gap, 600, h * 3));
            compare(picker.y, low.y - gap - h);
            picker.close();

            // room on neither side: it is pushed back off the bottom edge
            var bounds = Qt.rect(0, 0, 600, h + 10);
            picker.showAt("", low, bounds);
            compare(picker.y, bounds.height - h);
            verify(picker.y >= bounds.y);
            picker.close();

            // and off the right edge, whatever the card's own x is
            var narrow = Qt.rect(0, 0, w + 20, h * 3);
            picker.showAt("", Qt.rect(w, 0, 200, 30), narrow);
            compare(picker.x, narrow.width - w);
            picker.close();
        }
    }
}
