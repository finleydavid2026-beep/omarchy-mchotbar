import QtQuick
import Quickshell
import Quickshell.Io

// Minecraft-style taskbar: nine item slots holding your apps, drawn with the
// exact pixel art from the reference HUD rather than re-drawn rectangles.
//
// The art lives in art/ next to this file:
//   slot.png / slot_selected.png  one inventory slot, normal and selected
//   hearts.png                    the health row
//   food.png                      the hunger row
// They are scaled with smooth: false so the pixels stay crisp.
//
// The layout is the HUD rearranged onto one row, which is what a taskbar
// needs: the health row at the left end, the nine slots in the middle, and the
// hunger row at the right end.
//
// The root is a plain Item carrying the three properties the bar host injects
// (`bar`, `moduleName`, `settings`). qs.Ui's BarWidget does not resolve from a
// third-party plugin's QML context, so these are declared by hand.
//
// The slot itself lives in McSlot.qml: an inline `component` declared in this
// file does not propagate the Repeater's model context into the delegate body,
// so the cell has to be its own file.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") + "/omarchy/mchotbar"
  readonly property string pinsPath: root.configDir + "/pins.json"
  readonly property string artDir: "art"

  // Slot geometry, taken from the art itself.
  readonly property int slotCount: 9
  readonly property int slotW: 56
  readonly property int slotH: 54
  readonly property int stripW: 226
  readonly property int stripH: 28

  implicitWidth: root.slotCount * root.slotW + root.stripW + root.foodW
  implicitHeight: root.slotH

  readonly property int foodW: 232

  // [{ index, id, name, icon, source }]
  property var slots: []
  property int selected: 0
  property var entryIndex: ({})

  FileView {
    id: pinsFile
    path: root.pinsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.reloadSlots(text())
    onLoadFailed: root.reloadSlots("")
    // `text()` is stale inside onFileChanged, so re-read and let onLoaded fire.
    onFileChanged: reload()
  }

  function appLibrary() {
    return (root.bar && root.bar.shell && root.bar.shell.appLibrary) ? root.bar.shell.appLibrary : null
  }

  // A `class:org.foo.Bar` pin names a window class, not a desktop id, so it
  // has to be mapped back to an entry. Matching any dotted segment of the
  // class against the installed desktop ids covers the usual reverse-domain
  // naming (org.localsend.localsend_app -> localsend).
  function resolvePin(pin) {
    if (!pin) return ""
    if (pin.indexOf("class:") !== 0) return root.entryIndex[pin] ? pin : ""
    var parts = pin.slice(6).split(".")
    for (var i = 0; i < parts.length; i++) if (root.entryIndex[parts[i]]) return parts[i]
    return ""
  }

  function reloadSlots(rawText) {
    var raw = String(rawText || "")
    var ids = []
    try {
      var parsed = JSON.parse(raw || "[]")
      if (Array.isArray(parsed)) ids = parsed
    } catch (e) { ids = [] }

    // Index every installed desktop entry once, so a pin resolves to its name
    // and icon without a per-slot lookup. sortedEntries returns
    // { entry, score, key, name } — the desktop entry itself is at .entry.
    var index = ({})
    var lib = root.appLibrary()
    if (lib) {
      try {
        var entries = lib.sortedEntries("")
        for (var i = 0; i < entries.length; i++) {
          var e = entries[i] ? entries[i].entry : null
          if (e) index[String(e.id)] = e
        }
      } catch (e) { }
    }
    root.entryIndex = index

    var next = []
    for (var s = 0; s < root.slotCount; s++) {
      var rawId = String(ids[s] || "")
      var id = root.resolvePin(rawId)
      var entry = index[id]
      var icon = entry ? String(entry.icon || "") : ""
      var source = ""
      if (lib && id) {
        try { source = lib.iconSource(icon) || "" } catch (e) { source = "" }
      }
      next.push({
        index: s,
        id: id,
        name: entry ? String(entry.name || id) : id,
        icon: icon,
        source: source
      })
    }
    root.slots = next
    if (root.selected >= next.length) root.selected = 0
  }

  function launchSlot(slot) {
    if (!slot || !slot.id) return
    root.selected = slot.index
    var lib = root.appLibrary()
    if (lib) {
      lib.launch(slot.id, slot.name)
    } else if (root.bar) {
      root.bar.run("gtk-launch " + root.bar.shellQuote(slot.id + ".desktop"))
    }
  }

  function hoverSlot(slot) {
    if (!slot || !slot.id || !root.bar || !root.bar.showTooltip) return
    root.bar.showTooltip(root, slot.name)
  }

  // Health row, left end.
  Image {
    anchors {
      left: parent.left
      verticalCenter: parent.verticalCenter
    }
    width: root.stripW
    height: root.stripH
    source: root.artDir + "/hearts.png"
    smooth: false
    asynchronous: true
  }

  // Hunger row, right end.
  Image {
    anchors {
      right: parent.right
      verticalCenter: parent.verticalCenter
    }
    width: root.foodW
    height: root.stripH
    source: root.artDir + "/food.png"
    smooth: false
    asynchronous: true
  }

  Row {
    anchors {
      left: parent.left
      leftMargin: root.stripW
      verticalCenter: parent.verticalCenter
    }
    spacing: 0
    Repeater {
      model: root.slots
      delegate: McSlot {
        slotW: root.slotW
        slotH: root.slotH
        artDir: root.artDir
        isSelected: modelData.index === root.selected
        hotbar: root
      }
    }
  }
}
