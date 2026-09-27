import QtQuick

// The Prisma mark, drawn from inline SVG. With `lit` it is the full-color
// logo: three lights in additive RGB, each overlap filled with the sum of its
// lights (same shapes as assets/prisma-icon.svg). Otherwise it is three rings
// in `color`, so the bar icon takes the bar's color; `weight` is the ring
// stroke in viewBox units — heavier for the bar icon.
Image {
    id: root

    property color color: "white"
    property bool lit: false
    property real size: 16
    property real weight: 7

    readonly property string rings:
        '<g fill="none" stroke="' + String(color) + '" stroke-width="' + weight + '">' +
        '<circle cx="50" cy="35" r="24"/><circle cx="35" cy="62" r="24"/><circle cx="65" cy="62" r="24"/>' +
        '</g>'

    readonly property string lights:
        '<circle cx="50" cy="36" r="24" fill="#FF2E4D"/>' +
        '<circle cx="36" cy="60" r="24" fill="#2EE66B"/>' +
        '<circle cx="64" cy="60" r="24" fill="#2E6BFF"/>' +
        '<path d="M59.90 57.86A24 24 0 0 1 26.10 38.14A24 24 0 0 1 59.90 57.86Z" fill="#FFE14D"/>' +
        '<path d="M73.90 38.14A24 24 0 0 1 40.10 57.86A24 24 0 0 1 73.90 38.14Z" fill="#E44DFF"/>' +
        '<path d="M50.00 40.51A24 24 0 0 1 50.00 79.49A24 24 0 0 1 50.00 40.51Z" fill="#3DE8FF"/>' +
        '<path d="M59.90 57.86A24 24 0 0 1 40.10 57.86A24 24 0 0 1 50.00 40.51A24 24 0 0 1 59.90 57.86Z" fill="#FFFFFF"/>'

    width: size
    height: size
    sourceSize.width: Math.ceil(size * 2)
    sourceSize.height: Math.ceil(size * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true

    source: "data:image/svg+xml;utf8," + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">' +
        (lit ? lights : rings) + '</svg>')
}
