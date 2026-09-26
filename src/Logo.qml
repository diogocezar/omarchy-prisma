import QtQuick

// The Prisma mark: three overlapping rings, the additive RGB diagram, drawn
// from inline SVG so it takes any color. Pass `colors` (three) to paint each
// ring on its own, as the panel hero does; otherwise every ring is `color`.
// `weight` is the stroke width in viewBox units — heavier for the bar icon.
Image {
    id: root

    property color color: "white"
    property var colors: []
    property real size: 16
    property real weight: 7

    function ring(i) { return String(colors.length === 3 ? colors[i] : color) }

    width: size
    height: size
    sourceSize.width: Math.ceil(size * 2)
    sourceSize.height: Math.ceil(size * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true

    source: "data:image/svg+xml;utf8," + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">' +
        '<g fill="none" stroke-width="' + weight + '">' +
        '<circle cx="50" cy="35" r="24" stroke="' + ring(0) + '"/>' +
        '<circle cx="35" cy="62" r="24" stroke="' + ring(1) + '"/>' +
        '<circle cx="65" cy="62" r="24" stroke="' + ring(2) + '"/>' +
        '</g></svg>')
}
