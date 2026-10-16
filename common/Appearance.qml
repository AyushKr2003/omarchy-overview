pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "functions"
import "." as Common

// Motion and shadow tokens for the workspace-grid layout.
Singleton {
    id: root

    property QtObject colors: QtObject {
        property color colShadow: ColorUtils.applyAlpha(Color.background, 0.7)
    }

    property QtObject animation: QtObject {
        property QtObject elementMoveEnter: QtObject {
            property int duration: Common.Config.options.appearance.animation.duration.elementMoveEnter
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: Common.Config.options.appearance.animation.duration.elementMoveFast
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: [0.34, 0.80, 0.34, 1.00, 1, 1]
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
