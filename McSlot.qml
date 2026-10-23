import QtQuick

// One Minecraft hotbar slot. Lives in its own file so the Repeater's model
// context (modelData) resolves normally — an inline `component` declared in the
// same file does not propagate that context to the delegate body.
//
// The bevel is four thin edges rather than a border, so the light top/left and
// dark bottom/right sides stay correct wherever they meet.
Item {
  id: root

  required property var modelData
  required property bool isSelected
  readonly property var slot: modelData
  readonly property bool filled: slot && slot.id.length > 0

  // The owning hotbar, set by the delegate. Used for launch, selection and the
  // hover tooltip.
  property var hotbar: null

  width: 44
  height: 44

  Rectangle {
    anchors.fill: parent
    color: "#8b8b8b"
  }

  Rectangle {
    anchors {
      top: parent.top
      left: parent.left
      right: parent.right
    }
    height: 2
    color: "#ffffff"
  }
  Rectangle {
    anchors {
      top: parent.top
      bottom: parent.bottom
      left: parent.left
    }
    width: 2
    color: "#ffffff"
  }
  Rectangle {
    anchors {
      bottom: parent.bottom
      left: parent.left
      right: parent.right
    }
    height: 2
    color: "#373737"
  }
  Rectangle {
    anchors {
      top: parent.top
      bottom: parent.bottom
      right: parent.right
    }
    width: 2
    color: "#373737"
  }

  // The item, raised and enlarged on the selected slot — Minecraft draws the
  // active hotbar slot slightly larger.
  Image {
    anchors.centerIn: parent
    width: parent.isSelected ? parent.width * 0.78 : parent.width * 0.62
    height: width
    asynchronous: true
    smooth: false
    source: root.slot ? root.slot.source : ""
    visible: root.slot && root.slot.source.length > 0
  }

  // Selection outline.
  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: root.isSelected ? 3 : 0
    border.color: "#ffffff"
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
