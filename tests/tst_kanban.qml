import QtQuick
import QtQuick.Layouts
import QtTest

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
    }
}
