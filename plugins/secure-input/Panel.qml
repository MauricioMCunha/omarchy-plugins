import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var bar
  property string moduleName
  property var settings
  property bool open: false
  property var requests: []
  property var selected: null

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-secure-input"
  readonly property string socketPath: runtimeDir + "/broker.sock"
  readonly property string tokenPath: runtimeDir + "/token"
  readonly property string bridgePath: Quickshell.env("HOME") + "/DEV/omarchy-plugins"
    + "/services/secure_input_broker/bridge.py"

  implicitWidth: 34
  implicitHeight: bar ? bar.barSize : 26

  function triggerPress(button) {
    root.open = !root.open
    if (root.open) pollProc.running = true
  }

  function poll() {
    if (!pollProc.running) pollProc.running = true
  }

  function approveSecret(secret) {
    if (!root.selected || !secret) return
    approveProc.command = ["python3", root.bridgePath, "--socket", root.socketPath,
      "--token-file", root.tokenPath, "approve", root.selected.request_id,
      root.selected.nonce]
    approveProc.running = true
    approveProc.write(secret + "\n")
  }

  function approve() { approveSecret(secretInput.text) }

  function cancelRequest() {
    if (!root.selected) return
    cancelProc.command = ["python3", root.bridgePath, "--socket", root.socketPath,
      "--token-file", root.tokenPath, "cancel", root.selected.request_id]
    cancelProc.running = true
  }

  Process {
    id: pollProc
    command: ["python3", root.bridgePath, "--socket", root.socketPath,
      "--token-file", root.tokenPath, "pending"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var value = JSON.parse(text || "{}")
          root.requests = value.requests || []
          if (root.requests.length > 0 && !root.selected)
            root.selected = root.requests[0]
        } catch (e) {
          root.requests = []
        }
      }
    }
    onExited: pollTimer.restart()
  }

  Process {
    id: approveProc
    stdinEnabled: true
    stdout: StdioCollector {}
    onExited: { root.selected = null; root.poll() }
  }

  Process {
    id: cancelProc
    stdout: StdioCollector {}
    onExited: { root.selected = null; root.poll() }
  }

  SecureOverlay {
    id: secureOverlay
    open: root.selected !== null && root.requests.length > 0
    request: root.selected
    onApproved: root.approveSecret(secret)
    onCancelled: root.cancelRequest()
  }

  Timer {
    id: pollTimer
    interval: 1500
    repeat: true
    running: root.open
    onTriggered: root.poll()
  }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: "transparent"

    Canvas {
      id: securityIcon
      anchors.centerIn: parent
      width: Math.min(parent.width, 24)
      height: Math.min(parent.height, 24)

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var accent = root.requests.length ? "#f59e0b" : "#aab4c8"
        ctx.strokeStyle = accent
        ctx.fillStyle = accent
        ctx.lineWidth = 1.8
        ctx.lineJoin = "round"

        // Shield outline.
        ctx.beginPath()
        ctx.moveTo(width * 0.50, height * 0.08)
        ctx.lineTo(width * 0.82, height * 0.20)
        ctx.lineTo(width * 0.78, height * 0.57)
        ctx.quadraticCurveTo(width * 0.72, height * 0.80, width * 0.50, height * 0.93)
        ctx.quadraticCurveTo(width * 0.28, height * 0.80, width * 0.22, height * 0.57)
        ctx.lineTo(width * 0.18, height * 0.20)
        ctx.closePath()
        ctx.stroke()

        // Keyhole inside the shield.
        ctx.beginPath()
        ctx.arc(width * 0.50, height * 0.43, width * 0.10, 0, Math.PI * 2)
        ctx.fill()
        ctx.fillRect(width * 0.455, height * 0.48, width * 0.09, height * 0.22)
      }

      Connections {
        target: root
        function onRequestsChanged() { securityIcon.requestPaint() }
      }
    }

    MouseArea { anchors.fill: parent; onClicked: root.triggerPress(0) }
  }

  PopupWindow {
    id: popup
    visible: root.open
    color: "transparent"
    implicitWidth: 430
    implicitHeight: root.selected ? 280 : 130
    anchor {
      window: root.QsWindow.window
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.x: 0
      rect.y: root.height + 8
    }
    Rectangle {
      anchors.fill: parent
      color: Color.popups.background
      border.color: Color.popups.border
      border.width: 2
      radius: 10
      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10
        Text { text: root.selected ? "Autorização necessária" : "Nenhuma autorização pendente"; color: Color.popups.text; font.bold: true; font.pixelSize: 16 }
        Text { visible: !!root.selected; text: root.selected ? ("Comando: " + root.selected.command + "\\nPID: " + root.selected.pid + "\\nTTY: " + root.selected.tty) : ""; color: Color.muted; wrapMode: Text.Wrap; width: parent.width }
        TextInput {
          id: secretInput
          visible: !!root.selected
          width: parent.width
          echoMode: TextInput.Password
          color: Color.popups.text
          focus: true
          onAccepted: root.approve()
        }
        Row {
          spacing: 8
          visible: !!root.selected
          Rectangle {
            width: 100
            height: 34
            color: Color.accent
            radius: 6
            Text { anchors.centerIn: parent; text: "Autorizar"; color: Color.popups.text }
            MouseArea { anchors.fill: parent; onClicked: root.approve() }
          }
          Rectangle {
            width: 100
            height: 34
            color: Color.urgent
            radius: 6
            Text { anchors.centerIn: parent; text: "Cancelar"; color: Color.popups.text }
            MouseArea { anchors.fill: parent; onClicked: root.cancelRequest() }
          }
        }
      }
    }
  }
}
