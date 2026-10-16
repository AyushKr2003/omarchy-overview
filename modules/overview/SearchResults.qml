import QtQuick
import Quickshell
import "../../common"
import "../../common/functions"
import "../../services"

/**
 * The results panel that replaces the window grid while there is a query.
 */
Rectangle {
    id: panel

    property var results: SearchService.results
    property int selectedIndex: GlobalStates.resultIndex
    signal activated(var result)

    readonly property real rowHeight: Math.round(Style.spacing.popupRowHeight * 1.6)
    readonly property real headerHeight: Math.round(Style.font.caption * 2.2)
    // Height that shows every row without scrolling.
    readonly property real contentHeightHint: {
        let headers = 0;
        for (let i = 0; i < results.length; i++) {
            if (i === 0 || results[i - 1]?.category !== results[i].category)
                headers++;
        }
        return results.length * rowHeight + headers * headerHeight + Style.spacing.popupPadding * 2;
    }

    radius: Style.cornerRadius
    color: ColorUtils.applyAlpha(Color.launcher.background, 0.95)
    border.width: Style.normalBorderWidth
    border.color: Color.launcher.border
    clip: true

    StyledText {
        anchors.centerIn: parent
        visible: panel.results.length === 0
        text: "No results"
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        color: ColorUtils.applyAlpha(Color.launcher.text, 0.5)
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: Style.spacing.popupPadding
        model: panel.results
        currentIndex: panel.selectedIndex
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: Style.duration(90)
        spacing: 0
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool showHeader: index === 0 || panel.results[index - 1]?.category !== modelData.category
            readonly property bool isSelected: index === panel.selectedIndex
            width: list.width
            height: panel.rowHeight + (showHeader ? panel.headerHeight : 0)

            StyledText {
                visible: row.showHeader
                x: Style.spacing.rowPaddingX
                height: panel.headerHeight
                text: row.modelData.category
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                color: ColorUtils.applyAlpha(Color.launcher.text, 0.55)
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                id: body
                y: row.showHeader ? panel.headerHeight : 0
                width: parent.width
                height: panel.rowHeight
                radius: Math.max(4, Style.cornerRadius * 0.6)
                color: row.isSelected ? Color.launcher.selectedBackground
                    : rowArea.containsMouse ? ColorUtils.applyAlpha(Color.launcher.selectedBackground, 0.6) : "transparent"
                border.width: row.isSelected ? Style.normalBorderWidth : 0
                border.color: Color.accent

                Item {
                    id: iconBox
                    x: Style.spacing.rowPaddingX
                    anchors.verticalCenter: parent.verticalCenter
                    width: panel.rowHeight - Style.spacing.lg * 2
                    height: width

                    Image {
                        anchors.fill: parent
                        visible: `${row.modelData.icon ?? ""}`.length > 0
                        source: row.modelData.icon ?? ""
                        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                        sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: `${row.modelData.icon ?? ""}`.length === 0
                        text: row.modelData.glyph || "•"
                        font.family: row.modelData.glyphFont || Style.font.menuFamily || Style.font.family
                        font.pixelSize: Math.round(parent.height * 0.7)
                        color: row.isSelected ? Color.launcher.selectedText : Color.launcher.text
                    }
                }

                Column {
                    anchors.left: iconBox.right
                    anchors.leftMargin: Style.spacing.lg * 1.5
                    anchors.right: parent.right
                    anchors.rightMargin: Style.spacing.rowPaddingX
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing.xxs

                    StyledText {
                        width: parent.width
                        text: row.modelData.title
                        elide: Text.ElideRight
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        font.weight: row.isSelected ? Font.DemiBold : Font.Normal
                        color: row.isSelected ? Color.launcher.selectedText : Color.launcher.text
                    }

                    StyledText {
                        width: parent.width
                        visible: text.length > 0
                        text: row.modelData.subtitle ?? ""
                        elide: Text.ElideMiddle
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        color: ColorUtils.applyAlpha(Color.launcher.text, 0.6)
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: GlobalStates.resultIndex = row.index
                    onClicked: panel.activated(row.modelData)
                }
            }
        }
    }
}
