import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "markus.cellular"

  readonly property string scriptPath: Qt.resolvedUrl("cellular-status.sh").toString().replace("file://", "")

  property string state: "none"  // "none" | "connected" | anything else ModemManager reports
  property string operatorName: ""
  property int signalPercent: -1
  property string ownNumber: ""
  property string accessTech: ""
  property string nmUuid: ""
  property bool popupOpen: false

  readonly property bool present: state !== "none"
  readonly property bool connected: state === "connected"

  // Optimistic switch state: while a toggle is in flight, the knob shows the
  // requested state immediately instead of waiting for the next poll to
  // confirm it. `refresh()` after the process exits reconciles either way —
  // snapping to the real state if the action failed. Toggle and forget share
  // one action process since only one nmcli action ever runs at a time.
  property bool actionBusy: false
  property bool desiredOn: false
  property bool forgetConfirmOpen: false
  readonly property bool switchOn: actionBusy ? desiredOn : connected

  function toggleConnection() {
    if (actionBusy || nmUuid === "") return
    desiredOn = !connected
    actionBusy = true
    actionProc.command = ["nmcli", "connection", desiredOn ? "up" : "down", nmUuid]
    actionProc.running = true
  }

  function requestForget() {
    if (actionBusy || nmUuid === "") return
    forgetConfirmOpen = true
  }

  function forgetConnection() {
    forgetConfirmOpen = false
    if (actionBusy || nmUuid === "") return
    actionBusy = true
    actionProc.command = ["nmcli", "connection", "delete", nmUuid]
    actionProc.running = true
  }

  // Recreates the profile this widget was set up with (1&1, APN "internet")
  // so a forgotten connection isn't a dead end without a terminal.
  function setupConnection() {
    if (actionBusy) return
    actionBusy = true
    actionProc.command = ["bash", "-c",
      "nmcli connection add type gsm ifname cdc-wdm0 con-name '1&1 Mobile' apn internet && nmcli connection up '1&1 Mobile'"]
    actionProc.running = true
  }

  // Glyphs verified against the installed JetBrainsMono Nerd Font cmap:
  // md-signal_cellular_outline/1/2/3 and md-signal_off. Written as literal
  // characters (not \u escapes) because QML/JS \uXXXX only consumes 4 hex
  // digits, which truncates 5-digit supplementary-plane codepoints like these.
  readonly property string icon: {
    if (!connected) return "󰞃"
    if (signalPercent < 0) return "󰢿"
    if (signalPercent < 35) return "󰢼"
    if (signalPercent < 70) return "󰢽"
    return "󰢾"
  }

  readonly property string stateLabel: {
    if (!present) return "No modem detected"
    if (state === "connected") return "Connected"
    if (state === "registered") return "Registered (no data session)"
    if (state === "searching") return "Searching…"
    if (state === "enabled" || state === "disabled") return "Not connected"
    return state.length > 0 ? state.charAt(0).toUpperCase() + state.slice(1) : "Unknown"
  }

  readonly property string tooltip: {
    if (!present) return "No mobile modem detected"
    if (!connected) return "Mobile modem present (not connected)"
    var pct = signalPercent >= 0 ? signalPercent + "%" : "…"
    return operatorName + " · " + pct + " · Mobile Data"
  }

  function close() { popupOpen = false }
  function toggle() { popupOpen = !popupOpen; if (popupOpen) refresh() }

  IpcHandler {
    target: "markus.cellular"
    function toggle(): void { root.toggle() }
    function close(): void { root.close() }
  }

  visible: present
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function updateStatus(raw) {
    var parts = String(raw || "").replace(/\r?\n+$/, "").split("\t")
    root.state = parts[0] || "none"
    root.operatorName = parts[1] || ""
    root.signalPercent = parts[2] !== undefined && parts[2] !== "" ? parseInt(parts[2], 10) : -1
    root.ownNumber = parts[3] || ""
    root.accessTech = parts[4] || ""
    root.nmUuid = parts[5] || ""
  }

  Component.onCompleted: refresh()

  Process {
    id: statusProc
    command: ["bash", root.scriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateStatus(text)
    }
  }

  Process {
    id: actionProc
    onExited: function(exitCode) {
      root.actionBusy = false
      root.refresh()
    }
  }

  Timer {
    interval: root.popupOpen ? 3000 : 10000
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    tooltipText: root.popupOpen ? "" : root.tooltip
    onPressed: { root.refresh(); root.popupOpen = !root.popupOpen }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(260))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        Text {
          textFormat: Text.PlainText
          text: root.icon
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.displayLarge
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          spacing: Style.space(2)
          width: parent.width - Style.space(46)

          Text {
            textFormat: Text.PlainText
            text: root.present ? (root.operatorName || "Mobile Data") : "Mobile Data"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.stateLabel
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
          }
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Row {
        width: parent.width
        visible: root.nmUuid !== ""
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText
          text: "Mobile Data"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - toggleSwitch.width - forgetButton.width - Style.space(6)
        }

        // Same glyph/urgent-hover treatment as "Forget network" in the
        // built-in Wi-Fi panel, for a consistent destructive-action look.
        PanelActionButton {
          id: forgetButton
          anchors.verticalCenter: parent.verticalCenter
          enabled: !root.actionBusy
          iconText: "󰅙"
          tooltipText: "Forget connection"
          foreground: root.bar.foreground
          hoverColor: root.bar.urgent
          fontFamily: root.bar.fontFamily
          onClicked: root.requestForget()
        }

        ToggleSwitch {
          id: toggleSwitch
          anchors.verticalCenter: parent.verticalCenter
          checked: root.switchOn
          busy: root.actionBusy
          foreground: root.bar.foreground
          onToggled: root.toggleConnection()
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
        visible: root.nmUuid !== ""
      }

      Column {
        width: parent.width
        spacing: Style.space(8)
        visible: root.present && root.nmUuid === ""

        Text {
          textFormat: Text.PlainText
          text: "No connection profile set up."
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Button {
          text: root.actionBusy ? "Setting up…" : "Set Up Mobile Data"
          bordered: true
          enabled: !root.actionBusy
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          anchors.horizontalCenter: parent.horizontalCenter
          onClicked: root.setupConnection()
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
        visible: root.present && root.nmUuid === ""
      }

      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.present

        Row {
          width: parent.width
          Text {
            text: "Signal"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            width: parent.width / 2
          }
          Text {
            text: root.signalPercent >= 0 ? root.signalPercent + "%" : "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignRight
            width: parent.width / 2
          }
        }

        Row {
          width: parent.width
          visible: root.accessTech !== ""
          Text {
            text: "Network"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            width: parent.width / 2
          }
          Text {
            text: root.accessTech.toUpperCase()
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignRight
            width: parent.width / 2
          }
        }

        Row {
          width: parent.width
          visible: root.ownNumber !== ""
          Text {
            text: "Number"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            width: parent.width / 2
          }
          Text {
            text: root.ownNumber
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignRight
            width: parent.width / 2
          }
        }
      }
    }

    ConfirmDialog {
      anchors.fill: parent
      opened: root.forgetConfirmOpen
      z: 10
      message: "Forget the mobile data connection? You can set it up again from this popup."
      confirmText: "Forget"
      fontFamily: root.bar.fontFamily
      onCanceled: root.forgetConfirmOpen = false
      onConfirmed: root.forgetConnection()
    }
  }
}
