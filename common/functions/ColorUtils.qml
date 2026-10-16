pragma Singleton
import Quickshell

Singleton {
    id: root

    // The colour with its alpha replaced by `alpha` (clamped to 0..1).
    function applyAlpha(color, alpha) {
        var c = Qt.color(color);
        var a = Math.max(0, Math.min(1, alpha));
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
