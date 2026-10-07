import QtQuick

// A Flickable that scrolls the way the rest of the desktop does.
//
// Qt Quick on Wayland stops dead when the fingers leave the trackpad: the
// compositor sends no momentum events, only ScrollEnd, and Flickable just
// stops there. So Flickable keeps tracking the fingers 1:1 itself, and the
// handler below only watches -- `blocking: false` passes every event on --
// measuring how fast the page was moving and, on ScrollEnd, throwing it on at
// that speed. A glide covers v² / 2a, so a fast swipe travels quadratically
// further than a slow one: the "throw it and it keeps going" feel.
//
// Taking the whole gesture over instead was rejected: Flickable would still
// see ScrollBegin (it carries no delta, so the handler declines it) but never
// the matching ScrollEnd, and be left mid-drag. Mouse wheel events
// (NoScrollPhase) are left to Qt's own wheel handling. acceptedDevices must
// name TouchPad: Qt's Wayland backend marks trackpad scrolls as synthesized,
// which a WheelHandler ignores by default.
//
// Taken from Omvision's journal page (~/Code/omvision), so every scrolling
// page here glides the way that one does.
Flickable {
  id: root

  clip: true
  boundsBehavior: Flickable.StopAtBounds
  // The friction on the glide (flick() decelerates by this; a mouse wheel
  // uses Qt's separate wheel deceleration and is untouched).
  flickDeceleration: 1250
  maximumFlickVelocity: 12000

  WheelHandler {
    target: null
    blocking: false
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    // Velocity is read over the last `windowMs` ms of the gesture; if the
    // fingers rested longer than `restMs` before lifting, there is no glide,
    // so a careful scroll to a spot stays put.
    readonly property int windowMs: 80
    readonly property int restMs: 50
    readonly property real boost: 1.5
    readonly property real minVelocity: 100
    property var samples: []

    onWheel: (event) => {
      const now = Date.now()
      if (event.phase === Qt.ScrollUpdate) {
        samples.push({ t: now, dy: event.pixelDelta.y })
        while (samples.length > 0 && now - samples[0].t > windowMs) samples.shift()
      } else if (event.phase === Qt.ScrollEnd) {
        const s = samples
        samples = []
        if (s.length < 2 || now - s[s.length - 1].t > restMs) return
        let dy = 0
        for (let i = 1; i < s.length; ++i) dy += s[i].dy
        const ms = s[s.length - 1].t - s[0].t
        if (ms <= 0) return
        const v = dy / ms * 1000 * boost
        if (Math.abs(v) < minVelocity) return
        // Later, not now: Flickable handles this same ScrollEnd right after
        // us, and its returnToBounds() can reset the timeline a flick started
        // here would run on. Putting fingers back down (ScrollBegin) resets
        // it on purpose, which catches the glide.
        Qt.callLater(() => root.flick(0, v))
      }
    }
  }
}
