import QtQuick
import "../../common"
import "../../common/functions"
import "../../services"

/**
 * The search field. Text arrives through the overview's key handler (every
 * monitor shares GlobalStates.query), so this only draws it.
 */
Rectangle {
    id: pill

    property bool focused: false
    readonly property bool hasText: GlobalStates.query.length > 0

    implicitWidth: Math.max(Style.spacing.searchableDropdownWidth * 1.6, Math.min(560, row.implicitWidth + Style.spacing.controlPaddingX * 4))
    implicitHeight: Style.spacing.controlHeight + Style.spacing.inputPaddingY * 2
    radius: 0
    color: ColorUtils.applyAlpha(Color.launcher.background, 0.92)
    border.width: focused || hasText ? Math.max(3, Style.space(3)) : Style.normalBorderWidth + 1
    border.color: focused || hasText ? Color.accent : Color.launcher.border

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.spacing.controlPaddingX * 1.5
        anchors.right: parent.right
        anchors.rightMargin: Style.spacing.controlPaddingX * 1.5
        spacing: Style.spacing.lg

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            font.pixelSize: Style.font.title
            color: ColorUtils.applyAlpha(Color.launcher.text, 0.7)
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - row.spacing - Style.font.title * 1.5
            height: queryText.implicitHeight

            StyledText {
                id: queryText
                width: Math.min(implicitWidth, parent.width - caret.width)
                text: pill.hasText ? GlobalStates.query : "Type to search apps, windows, actions…"
                elide: Text.ElideLeft
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                color: pill.hasText ? Color.launcher.text : ColorUtils.applyAlpha(Color.launcher.text, 0.45)
            }

            Rectangle {
                id: caret
                visible: pill.focused || pill.hasText
                x: pill.hasText ? queryText.width + 1 : 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, Style.space(2))
                height: queryText.implicitHeight
                color: Color.accent

                SequentialAnimation on opacity {
                    running: caret.visible && !Style.reduceMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 530 }
                    NumberAnimation { to: 1; duration: 530 }
                }
            }
        }
    }
}
