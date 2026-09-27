import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon + popup for Prisma, built on the shell's native panel kit. Settings
// live in the shell's store (shell.json); every change is pushed to OpenRGB
// through prisma.py, which also starts the OpenRGB server when needed, so the
// shell starting up is what brings the lights back after a reboot.
//
// A color is stored as a "look": "theme:<key>" (a color of the active theme,
// kept as a reference so the lights follow theme changes), "#RRGGBB",
// "rainbow" or "off". settings.devices[key] = {name, color} holds renames and
// per-device looks; a device without its own look uses settings.color.
Panel {
    id: root
    moduleName: "diogocezar.prisma"  // must match manifest id
    ipcTarget: "diogocezar.prisma"

    readonly property bool   lightsOn: setting("enabled", true)
    readonly property string mode: setting("mode", "all") === "each" ? "each" : "all"
    readonly property string sharedLook: setting("color", "theme:accent")
    readonly property var    deviceSettings: setting("devices", ({}))
    readonly property int    argbLeds: setting("argbLeds", 24)
    readonly property string language: setting("language", "auto")
    onLanguageChanged: Strings.language = language

    readonly property color  foreground: bar ? bar.foreground : Color.foreground
    readonly property color  barForeground: bar ? bar.barForeground : Color.foreground
    readonly property color  dim: Qt.darker(foreground, 1.55)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

    readonly property real swatchSize: Style.space(26)

    // two rows of seven, by hue
    readonly property var fixedColors: [
        {key: "red", hex: "#FF0000"}, {key: "orange", hex: "#FF4000"},
        {key: "amber", hex: "#FF9000"}, {key: "yellow", hex: "#FFFF00"},
        {key: "lime", hex: "#80FF00"}, {key: "green", hex: "#00FF00"},
        {key: "turquoise", hex: "#00FF80"}, {key: "cyan", hex: "#00FFFF"},
        {key: "sky", hex: "#0080FF"}, {key: "blue", hex: "#0000FF"},
        {key: "purple", hex: "#8000FF"}, {key: "pink", hex: "#FF00FF"},
        {key: "rose", hex: "#FF0080"}, {key: "white", hex: "#FFFFFF"}
    ]

    // detected devices: [{key, name, type}] from `prisma.py devices`
    property var devices: []
    property bool detecting: false
    // last failure, shown in the popup; empty when all is well
    property string error: ""
    // device row whose color picker is open (per-device mode)
    property string expandedKey: ""
    property string editingKey: ""
    // a text field has the keyboard: keep panel shortcuts out of its way
    property bool typing: false

    function localPath(relativePath) {
        var url = Qt.resolvedUrl(relativePath).toString();
        return url.startsWith("file://") ? decodeURIComponent(url.substring(7)) : url;
    }

    function writeSettings(patch) {
        var updated = Object.assign({}, root.settings, patch);
        if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, updated);
    }

    // Merge `fields` into settings.devices[key]; empty values drop the field,
    // and the entry with it once nothing is left. `extra` rides along in the
    // same write (two writes in a row would race on root.settings).
    function patchDevice(key, fields, extra) {
        var all = Object.assign({}, root.deviceSettings);
        var entry = Object.assign({}, all[key] || {});
        for (var f in fields) {
            if (fields[f]) entry[f] = fields[f]; else delete entry[f];
        }
        if (Object.keys(entry).length) all[key] = entry; else delete all[key];
        writeSettings(Object.assign({devices: all}, extra || {}));
    }

    // The look `omarchy theme set` used to give: every device on the theme
    // accent, following later theme changes. Renames are kept.
    readonly property bool followingTheme: lightsOn && mode === "all" && sharedLook === "theme:accent"
    function useTheme() {
        var all = {};
        for (var key in root.deviceSettings)
            if (root.deviceSettings[key].name) all[key] = {name: root.deviceSettings[key].name};
        writeSettings({enabled: true, mode: "all", color: "theme:accent", devices: all});
    }

    // --- Theme palette --------------------------------------------------------
    // Read straight from the theme's colors.toml so every palette color is
    // offered, not only the few the shell keeps. `omarchy theme set` swaps the
    // theme directory and then rewrites theme.name, so that file's change is
    // the cue to re-read; the shell's accent changing is a second one.
    readonly property string themeDir: Quickshell.env("HOME") + "/.local/state/omarchy/current"
    property var themePalette: ({})

    function parseTheme(raw) {
        var out = {};
        var re = /^\s*([A-Za-z0-9_]+)\s*=\s*"#?([0-9A-Fa-f]{6})"/gm;
        var m;
        while ((m = re.exec(raw)) !== null) out[m[1]] = "#" + m[2].toUpperCase();
        root.themePalette = out;
    }

    FileView {
        id: themeFile
        path: root.themeDir + "/theme/colors.toml"
        printErrors: false
        onLoaded: root.parseTheme(text())
    }
    FileView {
        path: root.themeDir + "/theme.name"
        watchChanges: true
        printErrors: false
        onFileChanged: themeFile.reload()
    }
    Connections {
        target: Color
        function onAccentChanged() { themeFile.reload() }
    }

    // Theme swatches: accent and text first, then the palette without repeats.
    readonly property var themeSwatches: {
        var out = [], seen = {};
        var keys = ["accent", "foreground"];
        for (var i = 1; i <= 15; i++) if (i !== 7 && i !== 8) keys.push("color" + i);
        for (var k = 0; k < keys.length; k++) {
            var hex = root.themePalette[keys[k]];
            if (!hex || seen[hex] || hex === "#000000") continue;
            seen[hex] = true;
            out.push({look: "theme:" + keys[k], hex: hex, key: keys[k]});
        }
        return out;
    }

    function swatchName(key) {
        if (key === "accent" || key === "foreground") return Strings.t(key);
        return Strings.t("themeSwatch", key.replace("color", ""));
    }

    // --- Looks ----------------------------------------------------------------
    // look -> "#RRGGBB" | "rainbow" | "off"
    function resolve(look) {
        look = String(look || "");
        if (look === "rainbow" || look === "off") return look;
        if (look.indexOf("theme:") === 0)
            return root.themePalette[look.substring(6)] || root.themePalette.accent || String(Color.accent).toUpperCase();
        return /^#?[0-9A-Fa-f]{6}$/.test(look) ? "#" + look.replace("#", "").toUpperCase() : "#FFFFFF";
    }

    function ownLook(key) {
        var entry = root.deviceSettings[key];
        return entry && entry.color ? entry.color : "";
    }
    function lookFor(key) {
        if (!root.lightsOn) return "off";
        return root.mode === "each" && ownLook(key) ? ownLook(key) : root.sharedLook;
    }
    function displayName(device) {
        var entry = root.deviceSettings[device.key];
        return entry && entry.name ? entry.name : device.name;
    }

    function describe(look) {
        look = String(look || "");
        if (look === "off") return Strings.t("off");
        if (look === "rainbow") return Strings.t("rainbow");
        if (look.indexOf("theme:") === 0) return Strings.t("themeColor");
        for (var i = 0; i < fixedColors.length; i++)
            if (fixedColors[i].hex === resolve(look)) return Strings.t(fixedColors[i].key);
        return resolve(look);
    }
    readonly property string status: !lightsOn ? Strings.t("off")
                                   : mode === "each" ? Strings.t("eachStatus")
                                   : describe(sharedLook)

    // --- Backend --------------------------------------------------------------
    function payload() {
        var looks = {};
        if (!root.lightsOn) return {"*": "off"};
        looks["*"] = resolve(root.sharedLook).replace("#", "");
        if (root.mode === "each")
            for (var i = 0; i < root.devices.length; i++) {
                var key = root.devices[i].key;
                looks[key] = resolve(lookFor(key)).replace("#", "");
            }
        return looks;
    }

    Process {
        id: applyProc
        environment: ({PRISMA_ARGB_LEDS: String(root.argbLeds)})
        stderr: StdioCollector { id: applyErr }
        onExited: function (code) { root.error = code === 0 ? "" : (applyErr.text.trim() || ("exit " + code)) }
    }

    function apply() {
        // wait for the palette, or a theme look would go out as a fallback
        if (applyProc.running || root.detecting || !root.themePalette.accent) { applyDebounce.restart(); return; }
        applyProc.command = ["python3", localPath("prisma.py"), "apply", JSON.stringify(payload())];
        applyProc.running = true;
    }

    Process {
        id: devicesProc
        environment: ({PRISMA_ARGB_LEDS: String(root.argbLeds)})
        stdout: StdioCollector { id: devicesOut }
        stderr: StdioCollector { id: devicesErr }
        onExited: function (code) {
            root.detecting = false;
            if (code !== 0) {
                root.error = devicesErr.text.trim() || ("exit " + code);
                return;
            }
            try {
                root.devices = JSON.parse(devicesOut.text);
                root.error = "";
            } catch (e) {
                root.error = String(e);
            }
            applyDebounce.restart();
        }
    }

    function detect(rescan) {
        if (devicesProc.running) return;
        root.detecting = true;
        devicesProc.command = ["python3", localPath("prisma.py"), rescan ? "rescan" : "devices"];
        devicesProc.running = true;
    }

    // settings change → push to OpenRGB; debounced so one edit is one call
    Timer { id: applyDebounce; interval: 200; onTriggered: root.apply() }
    readonly property string payloadKey: JSON.stringify(payload())
    onPayloadKeyChanged: applyDebounce.restart()
    onArgbLedsChanged: applyDebounce.restart()
    Component.onCompleted: {
        Strings.language = language;
        detect(false);
    }

    onOpenedChanged: {
        editingKey = "";
        typing = false;
        if (opened) {
            if (panelFlick) panelFlick.contentY = 0;
            Qt.callLater(function () { keyCatcher.forceActiveFocus() });
        }
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        useActiveColor: false
        tooltipText: root.error !== "" ? Strings.t("error") : Strings.t("tooltip", root.status)
        onPressed: function (b) {
            if (b === Qt.MiddleButton) root.writeSettings({enabled: !root.lightsOn});
            else root.toggle();
        }

        iconComponent: Component {
            Logo {
                size: Math.round(Style.bar.iconCanvas * 0.85)
                weight: 9
                color: root.error !== "" ? Color.urgent
                     : root.lightsOn ? root.barForeground : Qt.darker(root.barForeground, 1.9)
            }
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(360))
        contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(820))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            // hand every key to the text field while one is focused
            blocked: root.typing || root.editingKey !== ""

            onCloseRequested: root.close()
            onTabRequested: function (direction) { root.switchPanel(direction) }
            onMoveRequested: function (dx, dy) {
                if (dx !== 0) root.writeSettings({mode: root.mode === "all" ? "each" : "all"});
                if (dy !== 0)
                    panelFlick.contentY = Math.max(0, Math.min(panelFlick.contentY + dy * Style.space(56),
                        panelFlick.contentHeight - panelFlick.height));
            }

            Flickable {
                id: panelFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: column.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: column
                    width: panelFlick.width
                    spacing: Style.space(12)

                    PanelHero {
                        width: parent.width
                        title: "Prisma"
                        meta: root.status
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        iconOpacity: root.lightsOn ? 1.0 : 0.45

                        iconComponent: Component {
                            Logo {
                                size: Style.font.display * 1.25
                                weight: 6
                                lit: root.lightsOn
                                color: root.foreground
                            }
                        }

                        trailingControl: Component {
                            ToggleSwitch {
                                checked: root.lightsOn
                                foreground: root.foreground
                                onToggled: root.writeSettings({enabled: !root.lightsOn})
                            }
                        }
                    }

                    Text {
                        visible: root.error !== ""
                        width: parent.width
                        textFormat: Text.PlainText
                        text: Strings.t("error") + ": " + root.error
                        color: Color.urgent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }

                    PanelSeparator { width: parent.width; foreground: root.foreground }

                    // --- Quick actions: follow the theme, and the mode switch
                    Column {
                        width: parent.width
                        spacing: Style.space(8)
                        opacity: root.lightsOn ? 1.0 : 0.5
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Button {
                            width: parent.width
                            text: Strings.t("useTheme")
                            tooltipText: Strings.t("useThemeHint")
                            selected: root.followingTheme
                            bordered: true
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            onClicked: root.useTheme()
                        }

                        // segmented control, two equal halves
                        Row {
                            id: modeSwitch
                            width: parent.width
                            spacing: Style.space(8)
                            Repeater {
                                model: [{value: "all", label: Strings.t("modeAll")},
                                        {value: "each", label: Strings.t("modeEach")}]
                                delegate: Button {
                                    required property var modelData
                                    width: (modeSwitch.width - modeSwitch.spacing) / 2
                                    text: modelData.label
                                    selected: root.mode === modelData.value
                                    bordered: true
                                    foreground: root.foreground
                                    fontFamily: root.fontFamily
                                    onClicked: root.writeSettings({mode: modelData.value})
                                }
                            }
                        }
                    }

                    // --- Shared color (all-together mode)
                    Column {
                        visible: root.mode === "all"
                        width: parent.width
                        spacing: Style.space(10)
                        opacity: root.lightsOn ? 1.0 : 0.5

                        SectionHeader {
                            width: parent.width
                            title: Strings.t("color")
                            valueText: root.describe(root.sharedLook)
                            valueColor: root.resolve(root.sharedLook)
                        }

                        ColorPicker {
                            width: parent.width
                            value: root.sharedLook
                            onPicked: function (look) { root.writeSettings({color: look, enabled: true}) }
                        }
                    }

                    PanelSeparator { width: parent.width; foreground: root.foreground }

                    // --- Devices
                    Column {
                        width: parent.width
                        spacing: Style.space(4)
                        opacity: root.lightsOn ? 1.0 : 0.5

                        SectionHeader {
                            width: parent.width
                            title: Strings.t("devices")
                            valueText: root.detecting ? "" : String(root.devices.length)

                            PanelActionButton {
                                anchors.verticalCenter: parent.verticalCenter
                                iconText: "󰑐"
                                tooltipText: Strings.t("rescan") + " · " + Strings.t("rescanHint")
                                enabled: !root.detecting
                                foreground: root.foreground
                                fontFamily: root.fontFamily
                                onClicked: root.detect(true)
                            }
                        }

                        Item { width: 1; height: Style.space(4) }

                        Text {
                            visible: root.detecting || root.devices.length === 0
                            width: parent.width
                            topPadding: Style.space(4)
                            bottomPadding: Style.space(4)
                            textFormat: Text.PlainText
                            text: root.detecting ? Strings.t("detecting") : Strings.t("noDevices")
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                        }

                        Repeater {
                            model: root.detecting ? [] : root.devices
                            delegate: DeviceRow {
                                required property var modelData
                                device: modelData
                                width: column.width
                            }
                        }

                        Text {
                            visible: root.devices.length > 0 && !root.detecting
                            width: parent.width
                            topPadding: Style.space(8)
                            textFormat: Text.PlainText
                            text: root.editingKey !== "" ? Strings.t("renameEditing")
                                : Strings.t(root.mode === "each" ? "renameHint" : "renameHintAll")
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    // --- Components -------------------------------------------------------------

    // Section title on the left; on the right an optional value (with a color
    // dot when `valueColor` is set) and whatever children are given.
    component SectionHeader: Item {
        id: section
        property string title: ""
        property string valueText: ""
        property string valueColor: ""
        default property alias trailing: trailingRow.data
        implicitHeight: Math.max(header.implicitHeight, trailingRow.implicitHeight)

        PanelSectionHeader {
            id: header
            anchors.left: parent.left
            anchors.right: trailingRow.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: section.title.toUpperCase()
            foreground: root.foreground
            fontFamily: root.fontFamily
        }

        Row {
            id: trailingRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Swatch {
                visible: section.valueColor !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(12)
                look: section.valueColor
                interactive: false
            }
            Text {
                visible: section.valueText !== ""
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: section.valueText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
            }
        }
    }

    // One device: its current color, the (renamable) name and type; in
    // per-device mode a click opens its own color picker below it.
    component DeviceRow: Column {
        id: row
        property var device: ({})
        readonly property bool expanded: root.mode === "each" && root.expandedKey === device.key
        spacing: Style.space(6)

        Rectangle {
            width: parent.width
            implicitHeight: Math.max(Style.space(36), rowContent.implicitHeight + Style.space(12))
            radius: Style.cornerRadius
            color: row.expanded || rowHover.hovered ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"

            HoverHandler { id: rowHover; enabled: root.mode === "each"; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                enabled: root.mode === "each"
                onTapped: root.expandedKey = row.expanded ? "" : row.device.key
            }

            Item {
                id: rowContent
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                implicitHeight: Math.max(dot.height, nameCol.implicitHeight)

                Swatch {
                    id: dot
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(14)
                    look: root.lookFor(row.device.key)
                    interactive: false
                }

                Column {
                    id: nameCol
                    anchors.left: dot.right
                    anchors.leftMargin: Style.space(10)
                    anchors.right: side.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)

                    DeviceName { width: parent.width; device: row.device }

                    // per-device mode: what this one is set to
                    Text {
                        visible: root.mode === "each"
                        width: parent.width
                        textFormat: Text.PlainText
                        text: root.ownLook(row.device.key) ? root.describe(root.ownLook(row.device.key))
                                                           : Strings.t("sameAsAll")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: side
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: Strings.typeLabel(row.device.type)
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                    }
                    Text {
                        visible: root.mode === "each"
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.expanded ? "▴" : "▾"
                        color: rowHover.hovered || row.expanded ? Color.accent : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                    }
                }
            }
        }

        ColorPicker {
            visible: row.expanded
            width: parent.width - Style.space(16)
            x: Style.space(8)
            inherit: true
            value: root.ownLook(row.device.key)
            onPicked: function (look) { root.patchDevice(row.device.key, {color: look}, {enabled: true}) }
        }

        Item { visible: row.expanded; width: 1; height: Style.space(6) }
    }

    // Device name that turns into a text field on click.
    component DeviceName: Item {
        id: nameItem
        property var device: ({})
        readonly property bool editing: root.editingKey !== "" && root.editingKey === device.key

        implicitHeight: editing ? field.implicitHeight : label.implicitHeight

        Text {
            id: label
            visible: !nameItem.editing
            width: Math.min(implicitWidth, parent.width)
            textFormat: Text.PlainText
            text: root.displayName(nameItem.device)
            color: nameHover.hovered ? Color.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight

            HoverHandler { id: nameHover; cursorShape: Qt.IBeamCursor }
            TapHandler { onTapped: root.editingKey = nameItem.device.key }
            PanelToolTip { visible: nameHover.hovered; text: Strings.t("renameTooltip"); fontFamily: root.fontFamily }
        }

        TextField {
            id: field
            visible: nameItem.editing
            width: parent.width
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            foreground: root.foreground
            horizontalPadding: Style.spacing.controlGap
            verticalPadding: Style.space(2)
            onVisibleChanged: if (visible) {
                text = root.displayName(nameItem.device);
                selectAll();
                Qt.callLater(forceActiveFocus);
            }
            onAccepted: {
                var name = text.trim();
                root.editingKey = "";
                root.patchDevice(nameItem.device.key, {name: name !== nameItem.device.name ? name : ""});
            }
            Keys.onEscapePressed: root.editingKey = ""
        }
    }

    // Theme colors, fixed colors, then effects and a hex field, on one grid so
    // every row lines up column by column. `inherit` adds "same as all" (an
    // empty look) for per-device pickers.
    component ColorPicker: Column {
        id: picker
        property string value: ""
        property bool inherit: false
        signal picked(string look)
        spacing: Style.space(6)

        // 7 columns, spread so the first and last touch the edges
        readonly property int columns: 7
        readonly property real gap: Math.max(0, (width - columns * root.swatchSize) / (columns - 1))

        GroupLabel { width: parent.width; text: Strings.t("theme") }
        SwatchGrid {
            width: parent.width
            columns: picker.columns
            columnSpacing: picker.gap
            model: root.themeSwatches
            delegate: Swatch {
                required property var modelData
                look: modelData.look
                tip: root.swatchName(modelData.key) + " · " + modelData.hex
                selected: picker.value === modelData.look
                onPicked: picker.picked(modelData.look)
            }
        }

        GroupLabel { width: parent.width; text: Strings.t("colors") }
        SwatchGrid {
            width: parent.width
            columns: picker.columns
            columnSpacing: picker.gap
            model: root.fixedColors
            delegate: Swatch {
                required property var modelData
                look: modelData.hex
                tip: Strings.t(modelData.key)
                selected: picker.value.toUpperCase() === modelData.hex
                onPicked: picker.picked(modelData.hex)
            }
        }

        GroupLabel { width: parent.width; text: Strings.t("effects") }
        Row {
            id: extras
            width: parent.width
            spacing: picker.gap

            Swatch {
                look: "rainbow"
                tip: Strings.t("rainbow")
                selected: picker.value === "rainbow"
                onPicked: picker.picked("rainbow")
            }
            Swatch {
                look: "off"
                tip: Strings.t("turnOff")
                selected: picker.value === "off"
                onPicked: picker.picked("off")
            }
            Button {
                visible: picker.inherit
                anchors.verticalCenter: parent.verticalCenter
                text: Strings.t("sameAsAll")
                tooltipText: Strings.t("sameAsAllHint")
                selected: picker.value === ""
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.space(3)
                onClicked: picker.picked("")
            }
            TextField {
                anchors.verticalCenter: parent.verticalCenter
                // fills whatever the row has left
                width: Math.max(Style.space(80), extras.width - x)
                placeholderText: Strings.t("hexPlaceholder")
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                foreground: root.foreground
                verticalPadding: Style.space(3)
                maximumLength: 7
                // shows the current custom color, if that's what's picked
                text: /^#[0-9A-Fa-f]{6}$/.test(picker.value) ? picker.value.toUpperCase() : ""
                onActiveFocusChanged: root.typing = activeFocus
                onAccepted: {
                    var v = text.trim().replace("#", "");
                    if (/^[0-9A-Fa-f]{6}$/.test(v)) {
                        picker.picked("#" + v.toUpperCase());
                        keyCatcher.forceActiveFocus();
                    } else {
                        ToolTip.show(Strings.t("hexInvalid"), 2000);
                    }
                }
                Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }
        }
    }

    component GroupLabel: Text {
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
    }

    component SwatchGrid: Grid {
        property alias model: rep.model
        property alias delegate: rep.delegate
        rowSpacing: Style.space(6)
        Repeater { id: rep }
    }

    // A round color chip. "rainbow" draws a spectrum, "off" a crossed-out chip.
    component Swatch: Item {
        id: swatch
        property string look: ""
        property string tip: ""
        property bool selected: false
        property bool interactive: true
        signal picked()

        readonly property string resolved: root.resolve(look)
        width: root.swatchSize
        height: width

        // selection ring
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: swatch.selected || (swatch.interactive && hover.hovered) ? 2 : 0
            border.color: swatch.selected ? root.foreground : root.dim
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: swatch.interactive ? 4 : 0
            radius: width / 2
            color: swatch.resolved === "off" ? "transparent"
                 : swatch.resolved === "rainbow" ? "white" : swatch.resolved
            border.width: swatch.resolved === "off" ? 1 : 0
            border.color: root.dim
            gradient: swatch.resolved === "rainbow" ? spectrum : null

            Gradient {
                id: spectrum
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#FF0000" }
                GradientStop { position: 0.2; color: "#FFFF00" }
                GradientStop { position: 0.4; color: "#00FF00" }
                GradientStop { position: 0.6; color: "#00FFFF" }
                GradientStop { position: 0.8; color: "#0000FF" }
                GradientStop { position: 1.0; color: "#FF00FF" }
            }

            // the slash on "off"
            Rectangle {
                visible: swatch.resolved === "off"
                anchors.centerIn: parent
                width: parent.width * 1.1
                height: 1.5
                rotation: -45
                color: root.dim
            }
        }

        HoverHandler { id: hover; enabled: swatch.interactive; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: swatch.interactive; onTapped: swatch.picked() }
        PanelToolTip {
            visible: swatch.interactive && hover.hovered && swatch.tip !== ""
            text: swatch.tip
            fontFamily: root.fontFamily
        }
    }
}
