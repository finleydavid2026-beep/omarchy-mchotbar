import QtQuick
import Quickshell
import Quickshell.Io

// Minecraft-style taskbar: nine item slots holding your apps, plus a health row
// that shows the battery and an armour row that shows wifi signal strength.
//
// The art is the exact pixel art from the reference HUD, cropped into
// art/heart.png and art/armor.png and tiled. A full row is ten icons; the count
// shown follows the value, and the unused ones stay at low opacity so the row
// keeps its width instead of jumping around.
//
//   hearts  battery percentage  (0-100% -> 0-10 hearts)
//   armour  wifi signal         (0-100  -> 0-10 chestplates)
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

  // Icon strip geometry, also from the art: the source strips are ten icons at
  // a 22px pitch.
  readonly property int iconCount: 10
  readonly property int iconW: 22
  readonly property int iconH: 25
  // Gap between the three sections, so the hearts and the hotbar read as
  // separate rows rather than one continuous strip.
  readonly property int gap: 18

  property int battery: 0     // 0-100
  property int wifi: 0        // 0-100

  readonly property int heartCount: Math.round(root.battery * root.iconCount / 100)
  readonly property int armorCount: Math.round(root.wifi * root.iconCount / 100)


  implicitWidth: root.iconCount * root.iconW * 2 + root.slotCount * root.slotW + root.gap * 2
  implicitHeight: root.slotH

  // [{ index, id, name, icon, source }]
  property var slots: []
  property int selected: 0
  property var entryIndex: ({})

  // ---- battery ------------------------------------------------------------
  // Read straight from sysfs; no omarchy service needed.
  Process {
    id: batteryProc
    property string collected: ""
    command: ["bash", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0"]
    running: true
    onRunningChanged: function() { if (batteryProc.running) batteryProc.collected = "" }
    stdout: SplitParser {
      onRead: function(data) { batteryProc.collected += data }
    }
    onExited: function() {
      var value = parseInt(String(batteryProc.collected || "0").replace(/[^0-9]/g, ""), 10)
      if (!isFinite(value)) value = 0
      root.battery = Math.max(0, Math.min(100, value))
    }
  }

  // ---- wifi ---------------------------------------------------------------
  // nmcli reports the active connection's signal as 0-100.
  Process {
    id: wifiProc
    property string collected: ""
    command: ["bash", "-c", "nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}'"]
    running: true
    onRunningChanged: function() { if (wifiProc.running) wifiProc.collected = "" }
    stdout: SplitParser {
      onRead: function(data) { wifiProc.collected += data }
    }
    onExited: function() {
      var value = parseInt(String(wifiProc.collected || "0").replace(/[^0-9]/g, ""), 10)
      if (!isFinite(value)) value = 0
      root.wifi = Math.max(0, Math.min(100, value))
    }
  }

  // Re-poll both every few seconds.
  // Poll both, but never overlap runs: a second run while the first is still
  // writing makes `collected` accumulate ("2626"), which clamps to 100.
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: function() {
      if (!batteryProc.running) batteryProc.running = true
      if (!wifiProc.running) wifiProc.running = true
    }
  }

  // ---- app slots ----------------------------------------------------------
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

  // ---- health row (battery) ----------------------------------------------
  Row {
    anchors {
      left: parent.left
      verticalCenter: parent.verticalCenter
    }
    spacing: 0
    Repeater {
      model: root.iconCount
      delegate: Image {
        required property int index
        width: root.iconW
        height: root.iconH
        source: root.artDir + "/heart.png"
        smooth: false
        asynchronous: true
        opacity: index < root.heartCount ? 1 : 0.18
      }
    }
  }

  // ---- app slots ----------------------------------------------------------
  Row {
    anchors {
      left: parent.left
      leftMargin: root.iconCount * root.iconW + root.gap
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

  // ---- armour row (wifi) --------------------------------------------------
  Row {
    anchors {
      left: parent.left
      leftMargin: root.iconCount * root.iconW + root.gap + root.slotCount * root.slotW + root.gap
      verticalCenter: parent.verticalCenter
    }
    spacing: 0
    Repeater {
      model: root.iconCount
      delegate: Image {
        required property int index
        width: root.iconW
        height: root.iconH
        source: root.artDir + "/armor.png"
        smooth: false
        asynchronous: true
        opacity: index < root.armorCount ? 1 : 0.18
      }
    }
  }
}
