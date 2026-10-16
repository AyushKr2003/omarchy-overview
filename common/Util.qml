pragma Singleton
import QtQuick

QtObject {
  id: root

  // file:// URL with each path segment percent-encoded so spaces and
  // special chars in user paths don't break Image.source.
  function fileUrl(path) {
    if (!path) return ""
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
  }
}
