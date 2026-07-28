pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "functions"
import "." as Common

Singleton {
    id: root

    property QtObject m3colors: QtObject {
        property color m3primary: Color.accent
        property color m3onPrimary: Color.background
        property color m3primaryContainer: Style.selectedFill
        property color m3onPrimaryContainer: Color.foreground
        property color m3secondary: Color.accent
        property color m3onSecondary: Color.background
        property color m3secondaryContainer: Style.selectedFill
        property color m3onSecondaryContainer: Color.foreground
        property color m3background: Color.background
        property color m3onBackground: Color.foreground
        property color m3surface: Color.background
        property color m3surfaceContainerLow: Style.normalFill
        property color m3surfaceContainer: Color.popups.background
        property color m3surfaceContainerHigh: Style.hoverFill
        property color m3surfaceContainerHighest: Style.hoverFill
        property color m3onSurface: Color.foreground
        property color m3surfaceVariant: Style.hoverFill
        property color m3onSurfaceVariant: Color.foreground
        property color m3inverseSurface: Color.foreground
        property color m3inverseOnSurface: Color.background
        property color m3outline: Style.normalBorderColor
        property color m3outlineVariant: Style.hoverBorderColor
        property color m3shadow: "#000000"
    }

    property QtObject colors: QtObject {
        property color colSubtext: Qt.darker(Color.foreground, 1.4)
        property color colLayer0: Color.background
        property color colOnLayer0: Color.foreground
        property color colLayer0Border: Style.normalBorderColor
        property color colLayer1: Style.normalFill
        property color colOnLayer1: Color.foreground
        property color colOnLayer1Inactive: Qt.darker(Color.foreground, 1.4)
        property color colLayer1Hover: Style.hoverFill
        property color colLayer1Active: Style.selectedFill
        property color colLayer2: Color.popups.background
        property color colOnLayer2: Color.popups.text
        property color colLayer2Hover: Style.hoverFill
        property color colLayer2Active: Style.selectedFill
        property color colLayer2Border: Color.popups.border
        property color colPrimary: Color.accent
        property color colOnPrimary: Color.background
        property color colSecondary: Color.accent
        property color colSecondaryContainer: Style.selectedFill
        property color colOnSecondaryContainer: Color.foreground
        property color colTooltip: Color.tooltip.background
        property color colOnTooltip: Color.tooltip.text
        property color colShadow: Util.alpha(Color.background, 0.7)
        property color colOutline: Style.normalBorderColor
    }

    property QtObject rounding: QtObject {
        property int unsharpen: 2
        property int verysmall: 8
        property int small: Style.cornerRadius
        property int normal: Style.cornerRadius
        property int large: Style.cornerRadius
        property int full: 9999
        property int screenRounding: Style.cornerRadius
        property int windowRounding: Style.cornerRadius
    }

    property QtObject font: QtObject {
        property QtObject family: QtObject {
            property string main: Style.font.family
            property string title: Style.font.family
            property string expressive: Style.font.family
        }
        property QtObject pixelSize: QtObject {
            property int smaller: Style.font.caption
            property int small: Style.font.bodySmall
            property int normal: Style.font.body
            property int larger: Style.font.title
            property int huge: Style.font.display
        }
    }

    property QtObject animationCurves: QtObject {
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1]
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property real expressiveDefaultSpatialDuration: Common.Config.options.appearance.animation.duration.elementMove
        readonly property real expressiveEffectsDuration: Common.Config.options.appearance.animation.duration.elementMoveFast
    }

    property QtObject animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: Common.Config.options.appearance.animation.duration.elementMoveEnter
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }

    property QtObject sizes: QtObject {
        property real elevationMargin: Common.Config.options.appearance.sizes.elevationMargin
    }
}
