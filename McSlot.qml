import QtQuick

// One Minecraft hotbar slot, drawn with the exact pixel art from the reference
// HUD (art/slot.png) and the selected variant (art/slot_selected.png). The app
// icon is drawn on top of the slot interior.
//
// Lives in its own file for the same reason as McRow.qml: the Repeater's model
// context does not reach a delegate body that uses an inline component declared
// in the parent file.
Item {
  id: root

  required property var modelData
  required property bool isSelected
  required property int slotW
  required property int slotH
  required property string artDir

  // The owning hotbar, set by the delegate. Used for launch, selection and the
  // hover tooltip.
  property var hotbar: null

  readonly property var slot: modelData
  readonly property bool filled: slot && slot.id.length > 0

  width: slotW
  height: slotH

  // The slot itself — the real pixels, scaled without smoothing.
  Image {
    anchors.fill: parent
    source: root.isSelected ? root.artDir + "/slot_selected.png" : root.artDir + "/slot.png"
    smooth: false
    asynchronous: true
  }

  // The app icon, drawn inside the slot interior.
  Image {
    anchors.centerIn: parent
    width: parent.width * 0.66
    height: parent.width * 0.66
    asynchronous: true
    smooth: false
    source: root.slot ? root.slot.source : ""
    visible: root.slot && root.slot.source.length > 0
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: function() {
      if (root.hotbar) root.hotbar.launchSlot(root.slot)
    }
    onEntered: function() {
      if (root.hotbar) root.hotbar.hoverSlot(root.slot)
    }
  }
}
