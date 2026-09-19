import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

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
        color: Util.alpha(Color.background, 0.72)

        BorderSurface {
          id: card
          anchors.centerIn: parent
          width: Math.min(520, Math.max(360, parent.width - Style.space(48)))
          height: content.implicitHeight + Style.space(40)
          padding: Style.space(20)
          color: Color.background
          borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
          radius: Style.cornerRadius

          Column {
            id: content
            anchors.fill: parent
            spacing: Style.space(10)

            Row {
              width: parent.width
              spacing: Style.space(10)

              BorderSurface {
                width: Style.space(38)
                height: Style.space(38)
                anchors.verticalCenter: parent.verticalCenter
                color: Util.alpha(Color.accent, 0.12)
                borderSpec: Border.flat(Util.alpha(Color.accent, 0.55), Style.normalBorderWidth)
                radius: Style.cornerRadius

                Text {
                  anchors.centerIn: parent
                  text: "󰌾"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.icon
                }
              }

              Column {
                width: parent.width - Style.space(48)
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: "Autorização segura"
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Text {
                  width: parent.width
                  text: "LLM local  •  solicitação única"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Text {
              width: parent.width
              text: "Revise a solicitação antes de liberar esta credencial."
              color: Util.alpha(Color.popups.text, 0.68)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            BorderSurface {
              width: parent.width
              implicitHeight: details.implicitHeight + Style.space(20)
              padding: Style.space(10)
              color: Util.alpha(Color.popups.text, 0.035)
              borderSpec: Border.flat(Util.alpha(Color.popups.border, 0.72), Style.normalBorderWidth)
              radius: Style.cornerRadius

              Column {
                id: details
                anchors.fill: parent
                spacing: Style.space(6)

                Text {
                  width: parent.width
                  text: "SOLICITAÇÃO"
                  color: Util.alpha(Color.popups.text, 0.55)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  width: parent.width
                  text: root.request ? root.request.command : ""
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                  maximumLineCount: 3
                  elide: Text.ElideMiddle
                }

                Text {
                  width: parent.width
                  visible: !!root.request && (root.request.tty !== "" || root.request.pid !== "")
                  text: root.request ? ((root.request.tty || "sessão local") +
                                        (root.request.pid ? "   •   PID " + root.request.pid : "")) : ""
                  color: Util.alpha(Color.popups.text, 0.58)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }

            Text {
              width: parent.width
              text: root.request && root.request.prompt ? root.request.prompt : "Senha"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            TextField {
              id: passwordInput
              width: parent.width
              height: Style.space(44)
              focus: root.open
              password: true
              placeholderText: "Digite a senha nesta janela segura"
              onAccepted: {
                if (text.length > 0) {
                  root.approved(text)
                  text = ""
                }
              }
              Component.onCompleted: forceActiveFocus()
            }

            Row {
              width: parent.width
              spacing: Style.space(10)

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "AUTORIZAR"
                active: true
                bordered: true
                focusable: true
                enabled: passwordInput.text.length > 0
                onClicked: {
                  if (passwordInput.text.length > 0) {
                    root.approved(passwordInput.text)
                    passwordInput.text = ""
                  }
                }
              }

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "FECHAR"
                accent: Color.urgent
                foreground: Color.popups.text
                background: "transparent"
                bordered: true
                focusable: true
                onClicked: root.cancelled()
              }
            }
          }
        }
      }
    }
  }
}
