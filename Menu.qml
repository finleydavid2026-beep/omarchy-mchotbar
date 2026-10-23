import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Minecraft-styled app search menu, summoned on SUPER+E.
//
// App discovery goes through Quickshell's own DesktopEntries singleton rather
// than shell.appLibrary: the shell only hands the app-library capability to
// first-party menu plugins, so a third-party menu gets null there even when its
// manifest declares the "menu" kind. DesktopEntries is a global, so it works
// for any plugin.
//
// It is also its own panel rather than a restyle of omarchy.menu: omarchy.menu's
// look is driven by Color.menu.* and Style.* tokens that live in shell.toml, and
// this panel must not fight the Windows-style bar for those same values. Every
// colour here is hardcoded.
//
// A panel plugin only appears if it owns a PanelWindow on the overlay layer —
// a bare Item in the plugin tree renders nothing. The scrim and the card live
// inside that window.
Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned.
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property var results: []

  // Minecraft palette: the dark GUI grey, the slot grey, the selection grey,
  // and the yellow Minecraft uses for titles.
  readonly property color panelBg: "#2b2b2b"
  readonly property color panelEdge: "#555555"
  readonly property color fieldBg: "#1a1a1a"
  readonly property color text: "#ffffff"
  readonly property color title: "#ffff54"
  readonly property string font: "Monocraft Nerd Font"

  readonly property int panelWidth: 460
  readonly property int panelPad: 10
  readonly property int fieldHeight: 40
  readonly property int rowHeight: 44
  readonly property int maxRows: 8

  readonly property string pinsPath: Quickshell.env("XDG_CONFIG_HOME") + "/omarchy/mchotbar/pins.json"
  // Desktop ids the hotbar holds. When the search box is empty these sort
  // first, so the menu opens on your own apps rather than on Aether and Avahi.
  property var pinnedIds: []

  Process {
    id: pinsProc
    property string collected: ""
    command: ["cat", root.pinsPath]
    running: true
    stdout: SplitParser {
      onRead: function(data) { pinsProc.collected += data }
    }
    onExited: function() {
      var ids = []
      try {
        var parsed = JSON.parse(pinsProc.collected || "[]")
        if (Array.isArray(parsed)) ids = parsed
      } catch (e) { ids = [] }
      root.pinnedIds = ids
      root.refresh()
    }
  }

  function open(payloadJson) {
    root.filterText = ""
    root.selectedIndex = 0
    root.refresh()
    root.opened = true
  }

  function close() {
    root.opened = false
    root.filterText = ""
    root.results = []
  }

  function iconFor(entry) {
    var icon = String(entry.icon || "")
    if (icon) {
      if (icon.charAt(0) === "/") return Util.fileUrl(icon)
      var found = Quickshell.iconPath(icon, true)
      if (found && found.length > 0) return found
    }
    return Quickshell.iconPath("application-x-executable", true) || ""
  }

  function refresh() {
    var values = []
    try { values = DesktopEntries.applications.values || [] } catch (e) { values = [] }

    var q = root.filterText.trim().toLowerCase()
    var next = []
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (!entry || entry.noDisplay) continue
      var name = String(entry.name || entry.id || "")
      if (!name) continue

      if (q) {
        var keywords = ""
        try { keywords = (entry.keywords || []).join(" ") } catch (e) { keywords = "" }
        var hay = (name + " " + String(entry.genericName || "") + " " + keywords).toLowerCase()
        if (hay.indexOf(q) === -1) continue
      }

      next.push({
        index: next.length,
        id: String(entry.id || ""),
        name: name,
        subtext: String(entry.genericName || ""),
        icon: root.iconFor(entry),
        entry: entry
      })
    }

    next.sort(function(a, b) {
      var an = a.name.toLowerCase()
      var bn = b.name.toLowerCase()
      if (an < bn) return -1
      if (an > bn) return 1
      return 0
    })

    // Pinned apps first while the search box is empty.
    if (!q && root.pinnedIds.length > 0) {
      var rank = ({})
      for (var p = 0; p < root.pinnedIds.length; p++) rank[String(root.pinnedIds[p])] = p
      next.sort(function(a, b) {
        var ar = rank[a.id] !== undefined ? rank[a.id] : 999
        var br = rank[b.id] !== undefined ? rank[b.id] : 999
        if (ar !== br) return ar - br
        return 0
      })
    }
    if (next.length > root.maxRows) next = next.slice(0, root.maxRows)
    root.results = next
    if (root.selectedIndex >= next.length) root.selectedIndex = Math.max(0, next.length - 1)
  }

  function launch(row) {
    if (!row || !row.id) return
    try {
      if (row.entry && typeof row.entry.execute === "function") row.entry.execute()
    } catch (e) {
      Util.execDetached("gtk-launch " + Util.shellQuote(row.id + ".desktop"))
    }
    root.close()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    WlrLayershell.namespace: "mchotbar-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: "#000000"
      opacity: 0.55
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: root.panelWidth
      height: Math.min(root.panelPad * 2 + root.fieldHeight + 8 + root.rowHeight * Math.max(1, root.results.length), parent.height - 40)
      color: root.panelBg
      border.width: 2
      border.color: root.panelEdge

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        anchors.fill: parent
        anchors.margins: root.panelPad
        spacing: 8

        // Title bar, Minecraft-yellow.
        Text {
          textFormat: Text.PlainText
          text: "Apps"
          color: root.title
          font.family: root.font
          font.pixelSize: 16
          height: 20
        }

        // Search field.
        Rectangle {
          width: parent.width
          height: root.fieldHeight
          color: root.fieldBg
          border.width: 2
          border.color: root.filterText.length > 0 ? root.title : root.panelEdge

          Text {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: root.filterText.length > 0 ? root.filterText : "Search…"
            color: root.filterText.length > 0 ? root.text : "#888888"
            font.family: root.font
            font.pixelSize: 15
            elide: Text.ElideRight
          }
        }

        // Results.
        Column {
          width: parent.width
          spacing: 2
          Repeater {
            model: root.results
            delegate: McRow {
              isSelected: modelData.index === root.selectedIndex
              onPick: root.launch(modelData)
              onHover: root.selectedIndex = modelData.index
            }
          }
        }
      }

      Item {
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; return }
          if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            if (root.results.length > 0) root.launch(root.results[root.selectedIndex])
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Up) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Down) {
            root.selectedIndex = Math.min(Math.max(0, root.results.length - 1), root.selectedIndex + 1)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Backspace) {
            root.filterText = root.filterText.slice(0, -1)
            root.selectedIndex = 0
            root.refresh()
            event.accepted = true
            return
          }
          var typed = event.text
          if (typed && typed.length > 0 && typed.charCodeAt(0) >= 32) {
            root.filterText += typed
            root.selectedIndex = 0
            root.refresh()
            event.accepted = true
          }
        }
      }
    }
  }
}
