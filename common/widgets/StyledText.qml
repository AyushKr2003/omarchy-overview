import QtQuick
import ".."

Text {
    id: root
    property bool animateChange: false

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    font {
        hintingPreference: Font.PreferFullHinting
        family: Style.font.family
        pixelSize: Style.font.bodySmall
    }
    color: Color.foreground
}
