import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: root

  property bool open: false
  property var request: null
  signal approved(string secret)
  signal cancelled()

  function screenNamed(name) {
    var wanted = String(name || "")
    for (var i = 0; i < Quickshell.screens.length; i++) {
      var candidate = Quickshell.screens[i]
      if (candidate && String(candidate.name || "") === wanted) return candidate
    }
    return null
  }

  function fallbackScreen() {
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  }

  readonly property var targetScreen: screenNamed(root.request ? root.request.screen : "") || fallbackScreen()

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: overlayWindow
      required property var modelData
      screen: modelData
      visible: root.open && root.targetScreen !== null && modelData === root.targetScreen
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "mauricio-secure-input"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      Rectangle {
        anchors.fill: parent
        color: "#99000000"

        Rectangle {
          id: card
          anchors.centerIn: parent
          width: Math.min(560, Math.max(320, parent.width - 48))
          height: content.implicitHeight + 40
          radius: 14
          color: "#202020"
          border.color: "#6ba4ff"
          border.width: 2

          Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 20
            spacing: 12

            Text {
              width: parent.width
              text: "Autorização solicitada pela LLM"
              color: "white"
              font.pixelSize: 20
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: root.request ? ("Comando: " + root.request.command +
                                    "\nOrigem: LLM local" +
                                    "\nPID: " + root.request.pid +
                                    "\nTTY: " + root.request.tty) : ""
              color: "#d0d0d0"
              wrapMode: Text.Wrap
            }

            TextInput {
              id: passwordInput
              width: parent.width
              height: 38
              focus: root.open
              echoMode: TextInput.Password
              color: "white"
              font.pixelSize: 16
              selectByMouse: false
              activeFocusOnPress: true
              onAccepted: {
                if (text.length > 0) {
                  root.approved(text)
                  text = ""
                }
              }
              Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                z: -1
                radius: 6
                color: "#303030"
                border.color: passwordInput.activeFocus ? "#6ba4ff" : "#555555"
              }
              Component.onCompleted: forceActiveFocus()
            }

            Row {
              width: parent.width
              spacing: 10

              Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: 40
                radius: 7
                color: "#376bb5"
                Text { anchors.centerIn: parent; text: "Autorizar"; color: "white"; font.bold: true }
                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    if (passwordInput.text.length > 0) {
                      root.approved(passwordInput.text)
                      passwordInput.text = ""
                    }
                  }
                }
              }

              Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: 40
                radius: 7
                color: "#7a3030"
                Text { anchors.centerIn: parent; text: "[Fechar]"; color: "white"; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: root.cancelled() }
              }
            }
          }
        }
      }
    }
  }
}
