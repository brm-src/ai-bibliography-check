import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string pluginId: "io.github.brm-src.ai-bibliography-check"
  readonly property bool isSpanish: uiLanguage === "es"
  readonly property int cardWidth: Math.min(Style.space(520), panel.width - Style.gapsOut * 2)
  readonly property int cardHeight: Math.min(
    root.hasReport ? Style.space(560) : Style.space(430),
    panel.height - Style.bar.sizeHorizontal - Style.gapsOut * 3)
  property bool opened: false
  property bool busy: false
  property bool backdropReady: false
  property bool hasReport: false
  property string uiLanguage: Qt.locale().name.toLowerCase().startsWith("es") ? "es" : "en"
  property string sourceText: ""
  property string status: ""
  property var report: ({})
  property var callback: null

  function words(es, en) { return root.isSpanish ? es : en }

  readonly property string idleHint: words(
    "Pega una bibliografía y presiona revisar.",
    "Paste a bibliography and press check.")

  function errorText(payload) {
    switch (payload.errorCode) {
      case "empty": return root.words("Pega o escribe una bibliografía primero.", "Paste or type a bibliography first.")
      case "too-long": return root.words("Es demasiado larga. Usa menos de 12.000 caracteres.", "That is too long. Use fewer than 12,000 characters.")
      case "check-unavailable": return root.words("No hay conexión con aismell. Intenta de nuevo.", "aismell is unavailable. Try again.")
      default: return root.words("No pude revisar la bibliografía.", "I could not check the bibliography.")
    }
  }

  function open() {
    root.opened = true
    root.backdropReady = false
    backdropGuard.restart()
    root.hasReport = false
    root.report = ({})
    root.status = root.idleHint
    root.runHelper("read-clipboard", "", function(payload) {
      if (payload.ok && String(payload.source || "").trim() !== "") root.sourceText = String(payload.source)
    })
  }

  function close() {
    root.opened = false
    root.backdropReady = false
    backdropGuard.stop()
    root.busy = false
    root.callback = null
  }

  function toggle() { if (root.opened) root.close(); else root.open() }

  function runHelper(command, input, done) {
    if (root.busy) return
    root.busy = true
    root.callback = done
    helper.inputText = String(input || "")
    helper.command = ["python3", root.helperPath, command]
    helper.running = true
  }

  readonly property string helperPath: Qt.resolvedUrl("bibliography_check.py").toString().replace("file://", "")

  function handlePayload(raw) {
    root.busy = false
    var payload
    try { payload = JSON.parse(String(raw || "{}")) }
    catch (error) {
      root.status = root.words("No pude leer la respuesta.", "I could not read the response.")
      return
    }
    if (root.callback) root.callback(payload)
    root.callback = null
  }

  function check() {
    if (!root.sourceText.trim()) {
      root.status = root.words("Pega o escribe una bibliografía primero.", "Paste or type a bibliography first.")
      return
    }
    root.status = root.words("Revisando estructura y señales de aismell…", "Checking structure and aismell signals…")
    root.runHelper("check-stdin", root.sourceText, function(payload) {
      if (!payload.ok) {
        root.hasReport = false
        root.report = ({})
        root.status = root.errorText(payload)
        return
      }
      root.report = payload.report || ({})
      root.hasReport = true
      root.status = root.words("Revisión lista. Lee los hallazgos antes de corregir.", "Check complete. Read the findings before editing.")
    })
  }

  function statusLabel() {
    if (!root.hasReport) return ""
    if (root.report.status === "attention") return root.words("necesita atención", "needs attention")
    if (root.report.status === "review") return root.words("conviene revisar", "worth reviewing")
    return root.words("sin problemas claros", "no clear problems")
  }

  function findingLabel(item) {
    var number = item.entry ? (root.words("Entrada ", "Entry ") + item.entry + " · ") : ""
    return number + String(item.message || "")
  }

  IpcHandler {
    target: root.pluginId
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function show(): string { root.open(); return "ok" }
    function hide(): string { root.close(); return "ok" }
    function toggle(): string { root.toggle(); return "ok" }
    function check(): string { root.check(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
  }

  Process {
    id: helper
    property string inputText: ""
    stdinEnabled: true
    onStarted: { write(inputText + "\u001e"); inputText = "" }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handlePayload(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.busy) {
        root.busy = false
        root.status = root.words("No pude completar la revisión.", "I could not complete the check.")
      }
    }
  }

  Timer {
    id: backdropGuard
    interval: 200
    repeat: false
    onTriggered: root.backdropReady = true
  }

  PanelWindow {
    id: panel
    screen: Quickshell.screens[0]
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {
      x: card.x
      y: card.y
      width: card.visible ? card.width : 0
      height: card.visible ? card.height : 0
    }
    WlrLayershell.namespace: root.pluginId
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_W && (event.modifiers & Qt.MetaModifier)) {
          root.close(); event.accepted = true
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: "transparent"
      MouseArea { anchors.fill: parent; enabled: root.backdropReady; onClicked: root.close() }
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Style.bar.sizeHorizontal + Style.gapsOut
      anchors.rightMargin: Style.gapsOut
      radius: Style.cornerRadius
      color: Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding
      MouseArea { anchors.fill: parent }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.spacing.md

        Row {
          width: parent.width
          height: titleColumn.implicitHeight
          Column {
            id: titleColumn
            width: parent.width - closeButton.width - Style.spacing.md
            spacing: Style.spacing.xs
            Text {
              text: root.words("aismell · revisión editorial", "aismell · editorial review")
              color: Color.accent
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.8
            }
            Text {
              text: root.words("revisar bibliografía", "check bibliography")
              color: Color.menu.text
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              width: parent.width
              text: root.words(
                "Encuentra años o autores ausentes, duplicados, mezcla de estilos y señales de redacción formulaica. No inventa una validación externa.",
                "Finds missing years or authors, duplicates, mixed styles, and formulaic writing signals. It does not fake external validation.")
              color: Color.menu.text
              opacity: 0.66
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
            }
          }
          Button {
            id: closeButton
            anchors.verticalCenter: parent.verticalCenter
            text: "×"
            fontSize: Style.font.iconLarge
            tooltipText: root.words("Cerrar (Esc)", "Close (Esc)")
            onClicked: root.close()
          }
        }

        Text {
          width: parent.width
          text: root.status
          color: Color.menu.text
          opacity: 0.72
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }

        Item {
          width: parent.width
          height: Style.space(5)
          visible: root.busy
          clip: true
          Rectangle { anchors.fill: parent; radius: height / 2; color: Color.menu.text; opacity: 0.14 }
          Rectangle {
            id: progressIndicator
            width: Math.max(Style.space(72), parent.width * 0.28)
            height: parent.height
            radius: height / 2
            color: Color.accent
            x: -width
            SequentialAnimation on x {
              running: root.busy
              loops: Animation.Infinite
              NumberAnimation { from: -progressIndicator.width; to: progressIndicator.parent.width; duration: 900; easing.type: Easing.InOutQuad }
              PauseAnimation { duration: 120 }
            }
          }
        }

        BorderSurface {
          width: parent.width
          height: Style.space(150)
          radius: Style.cornerRadius
          color: Style.controlFill(false, false, Color.menu.text, Color.accent)
          borderSpec: Border.controlSpec("normal", Color.menu.text, Color.accent)
          padding: Style.spacing.controlPaddingX
          TextEdit {
            id: sourceEditor
            anchors.fill: parent
            anchors.topMargin: parent.contentTopInset
            anchors.rightMargin: parent.contentRightInset
            anchors.bottomMargin: parent.contentBottomInset
            anchors.leftMargin: parent.contentLeftInset
            text: root.sourceText
            color: Color.menu.text
            opacity: 0.9
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            textFormat: TextEdit.PlainText
            Keys.onEscapePressed: root.close()
            onTextChanged: {
              if (activeFocus && text !== root.sourceText) {
                root.sourceText = text
                root.hasReport = false
                root.report = ({})
                root.status = root.idleHint
              }
            }
            Text {
              visible: sourceEditor.text === "" && !sourceEditor.activeFocus
              anchors.fill: parent
              text: root.words("Una entrada por línea o separada por espacios en blanco.", "One entry per line or separated by blank lines.")
              color: Color.menu.text
              opacity: 0.45
              font: sourceEditor.font
              wrapMode: Text.Wrap
            }
          }
        }

        Row {
          id: actions
          width: parent.width
          spacing: Style.spacing.sm
          Button {
            text: root.words("revisar", "check")
            selected: true
            active: root.sourceText.trim() !== "" && !root.busy
            tooltipText: root.words("Analiza la bibliografía con aismell.", "Analyze the bibliography with aismell.")
            onClicked: root.check()
          }
          Button {
            text: root.words("limpiar", "clear")
            selected: false
            active: !root.busy
            onClicked: { root.sourceText = ""; root.hasReport = false; root.report = ({}); root.status = root.idleHint }
          }
          Item { width: Math.max(0, parent.width - 180 - poweredBy.width); height: 1 }
          Item {
            id: poweredBy
            width: Style.space(150)
            height: parent.height
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "powered by: aismell"
              color: Color.menu.text
              opacity: 0.62
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: Qt.openUrlExternally("https://aismell.me")
            }
          }
        }

        Flickable {
          width: parent.width
          height: parent.height - y
          contentWidth: width
          contentHeight: resultsColumn.implicitHeight
          clip: true
          visible: root.hasReport
          Column {
            id: resultsColumn
            width: parent.width
            spacing: Style.spacing.sm
            Row {
              width: parent.width
              spacing: Style.spacing.md
              Text {
                text: root.hasReport ? String(root.report.score || 0) + "/100" : ""
                color: Color.accent
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Column {
                width: parent.width - 100
                Text {
                  text: root.statusLabel()
                  color: Color.menu.text
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  text: root.words(
                    String(root.report.entryCount || 0) + " entradas · " + String((root.report.findings || []).length) + " hallazgos",
                    String(root.report.entryCount || 0) + " entries · " + String((root.report.findings || []).length) + " findings")
                  color: Color.menu.text
                  opacity: 0.62
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
            Text {
              width: parent.width
              visible: root.report.analysis && root.report.analysis.truncated
              text: root.words("aismell analizó los primeros 3.000 caracteres; las comprobaciones estructurales cubren todo el texto.", "aismell analyzed the first 3,000 characters; structural checks cover the full text.")
              color: Color.menu.text
              opacity: 0.58
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }
            Repeater {
              model: root.report.findings || []
              delegate: Text {
                width: resultsColumn.width
                text: "• " + root.findingLabel(modelData)
                color: modelData.severity === "high" ? Color.accent : Color.menu.text
                opacity: modelData.severity === "high" ? 0.95 : 0.76
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
              }
            }
            Text {
              width: parent.width
              text: root.words(
                "Esto revisa el texto pegado. No confirma que una fuente exista ni que un DOI resuelva.",
                "This checks the pasted text. It does not confirm that a source exists or that a DOI resolves.")
              color: Color.menu.text
              opacity: 0.52
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }
          }
        }
      }
    }
  }
}
