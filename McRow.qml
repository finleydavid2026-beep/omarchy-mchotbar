import QtQuick

// One result row in the Minecraft menu. Its own file for the same reason as
// McSlot.qml: the Repeater's model context does not reach a delegate body that
// uses an inline component declared in the parent file.
Rectangle {
  id: root

  required property var modelData
  required property bool isSelected

  signal pick()
  signal hover()

  readonly property color text: "#ffffff"
  readonly property color subtext: "#aaaaaa"
  readonly property string font: "Monocraft Nerd Font"

  width: parent.width
  height: 44
  color: isSelected ? "#4a4a4a" : "#3a3a3a"

  Row {
    anchors.fill: parent
    anchors.leftMargin: 8
    anchors.rightMargin: 8
    spacing: 8

    Image {
      width: 24
      height: 24
      anchors.verticalCenter: parent.verticalCenter
      asynchronous: true
      smooth: false
      source: root.modelData.icon
      visible: root.modelData.icon.length > 0
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 40

      Text {
        textFormat: Text.PlainText
        text: root.modelData.name
        color: root.text
        font.family: root.font
        font.pixelSize: 14
        elide: Text.ElideRight
        width: parent.width
      }
      Text {
        textFormat: Text.PlainText
        text: root.modelData.subtext
        color: root.subtext
        font.family: root.font
        font.pixelSize: 11
        elide: Text.ElideRight
        width: parent.width
        visible: root.modelData.subtext.length > 0
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.hover()
    onClicked: root.pick()
  }
}
