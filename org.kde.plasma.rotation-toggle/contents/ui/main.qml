/*
 * Toggle KScreen auto-rotation policy (Never ↔ Always) via system tray icon.
 * Pure QML: talks to kscreen-doctor (libkscreen CLI) and the Plasma OSD service.
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5S
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PC3

PlasmoidItem {
    id: root

    property bool autoRotation: false
    property bool hasAccel: false
    property string outputName: ""

    // KScreen::Output::AutoRotatePolicy: 0=Never 1=InTabletMode 2=Always
    property int policy: 0

    // KScreen::Output::Type: 7=Panel
    readonly property int panelOutputType: 7

    Plasmoid.icon: {
        if (!hasAccel)        return "input-tablet-symbolic"
        if (autoRotation)     return "rotation-allowed-symbolic"
        return "rotation-locked-symbolic"
    }

    Plasmoid.status: autoRotation ? PlasmaCore.Types.ActiveStatus
                                  : PlasmaCore.Types.PassiveStatus

    toolTipMainText: autoRotation ? i18n("Auto-rotate: On") : i18n("Auto-rotate: Off")
    toolTipSubText: hasAccel ? outputName : i18n("No auto-rotating display found")

    // ── toggle ────────────────────────────────────────────────────────
    function doToggle() {
        if (!hasAccel || outputName === "")
            return

        const turningOn = !autoRotation
        toggleSource.connectedSources = [
            "kscreen-doctor output." + outputName + ".autoRotatePolicy."
                + (turningOn ? "always" : "never")
        ]

        // optimistic update, the poll below confirms it
        autoRotation = turningOn
        policy = turningOn ? 2 : 0
        Plasmoid.configuration.autoRotationEnabled = turningOn
        showOsd(turningOn ? "rotation-allowed-symbolic" : "rotation-locked-symbolic",
                turningOn ? i18n("Auto-rotate: on") : i18n("Auto-rotate: off"))
    }

    // ── OSD via plasmashell's D-Bus service ───────────────────────────
    function showOsd(icon, text) {
        // the text may contain spaces, so it is passed as one quoted argument
        osdSource.connectedSources = [
            "dbus-send --session --type=method_call"
                + " --dest=org.kde.plasmashell /org/kde/osdService"
                + " org.kde.osdService.showText"
                + " string:" + icon + " \"string:" + text + "\""
        ]
    }

    onExpandedChanged: (expanded) => {
        if (expanded) {
            doToggle()
            Qt.callLater(function() { root.expanded = false })
        }
    }

    compactRepresentation: Kirigami.Icon {
        source: Plasmoid.icon
        active: root.autoRotation
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        collapseMarginsHint: true
        ColumnLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Heading { text: i18n("Screen Auto-Rotation"); level: 2; Layout.alignment: Qt.AlignHCenter }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    source: root.autoRotation ? "rotation-allowed-symbolic" : "rotation-locked-symbolic"
                    width: Kirigami.Units.iconSizes.small; height: Kirigami.Units.iconSizes.small
                }
                PC3.Switch {
                    checked: root.autoRotation
                    text: root.autoRotation ? i18nc("@item:switch", "On") : i18nc("@item:switch", "Off")
                    onToggled: root.doToggle()
                }
            }
        }
    }

    // ── status poll: read autoRotatePolicy from kscreen-doctor ────────
    function applyConfigJson(raw) {
        var cfg = null
        try {
            cfg = JSON.parse(raw)
        } catch (e) {
            return
        }
        if (!cfg || !cfg.outputs || cfg.outputs.length === 0)
            return

        var panel = null
        var fallback = null
        for (var i = 0; i < cfg.outputs.length; ++i) {
            const out = cfg.outputs[i]
            if (!out.connected || !out.enabled)
                continue
            if (fallback === null)
                fallback = out
            if (out.type === panelOutputType) {
                panel = out
                break
            }
        }

        const chosen = panel || fallback
        if (chosen === null) {
            hasAccel = false
            outputName = ""
            return
        }

        hasAccel = true
        outputName = chosen.name
        policy = chosen.autoRotatePolicy !== undefined ? chosen.autoRotatePolicy : 0
        autoRotation = policy !== 0
    }

    P5S.DataSource {
        id: statusSource
        engine: "executable"
        connectedSources: ["kscreen-doctor -j"]
        interval: 3000
        onNewData: (sourceName, data) => {
            if (data["exit code"] !== 0)
                return
            root.applyConfigJson(data["stdout"] || "")
        }
    }

    // ── one-shot runners ──────────────────────────────────────────────
    P5S.DataSource {
        id: toggleSource
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: { toggleSource.connectedSources = [] }
    }
    P5S.DataSource {
        id: osdSource
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: { osdSource.connectedSources = [] }
    }
}
