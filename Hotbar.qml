import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Minecraft-style taskbar: nine item slots holding your apps.
//
// The look follows Minecraft's own hotbar rather than a generic dock:
//   - each slot is a grey square with a light top/left edge and a dark
//     bottom/right edge, which is what gives the inset "slot" read
//   - the selected slot gets a white border and its item is drawn larger,
//     the same way Minecraft raises the active slot
//   - clicking a slot launches the app
//
// The slot list lives in ~/.config/omarchy/mchotbar/pins.json as a plain array
// of desktop ids (["chromium", "steam", ...]). install.sh seeds it from the
// Omarchy hotbar's existing pins so your apps are already there.
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

  // Slot geometry. Minecraft's hotbar is 9 slots with a small gap.
  readonly property int slotCount: 9
  readonly property int slotSize: 44
  readonly property int slotGap: 4
  readonly property int slotPad: 6

  implicitWidth: root.slotCount * root.slotSize + (root.slotCount - 1) * root.slotGap + root.slotPad * 2
  implicitHeight: root.slotSize + root.slotPad * 2

  // [{ index, id, name, icon, source }]
  property var slots: []
  property int selected: 0

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

  function reloadSlots(rawText) {
    var raw = String(rawText || "")

    var ids = []
    try {
      var parsed = JSON.parse(raw || "[]")
      if (Array.isArray(parsed)) ids = parsed
    } catch (e) { ids = [] }

    // Index every installed desktop entry once, so a pin resolves to its name
    // and icon without a per-slot lookup.
    var index = ({})
    var lib = root.appLibrary()
    if (lib) {
      try {
        // sortedEntries returns { entry, score, key, name }; the desktop
        // entry itself lives at .entry.
        var entries = lib.sortedEntries("")
        for (var i = 0; i < entries.length; i++) {
          var e = entries[i] ? entries[i].entry : null
          if (e) index[String(e.id)] = e
        }
      } catch (e) { }
    }

    // A `class:org.foo.Bar` pin names a window class, not a desktop id, so it
    // has to be mapped back to an entry. Matching any dotted segment of the
    // class against the installed desktop ids covers the usual reverse-domain
    // naming (org.localsend.localsend_app -> localsend).
    function resolvePin(pin) {
      if (!pin) return ""
      if (pin.indexOf("class:") !== 0) return index[pin] ? pin : ""
      var parts = pin.slice(6).split(".")
      for (var i = 0; i < parts.length; i++) if (index[parts[i]]) return parts[i]
      return ""
    }

    var next = []
    for (var s = 0; s < root.slotCount; s++) {
      var rawId = String(ids[s] || "")
      var id = resolvePin(rawId)
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

  Row {
    anchors.centerIn: parent
    spacing: root.slotGap
    Repeater {
      model: root.slots
      delegate: McSlot {
        isSelected: modelData.index === root.selected
        hotbar: root
      }
    }
  }
}
