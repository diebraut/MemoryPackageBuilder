import QtQuick

QtObject {
    id: root

    // Bindbare Länge
    property int count: 0

    // Internes Array (nicht direkt von außen mutieren)
    property var _items: []

    signal changed()

    function _sync() {
        const n = _items.length
        if (count !== n)
            count = n
        changed()
    }

    function clear() {
        if (_items.length === 0)
            return
        _items.length = 0
        _sync()
    }

    function push(value) {
        _items.push(value)
        _sync()
    }

    function at(index) {
        return _items[index]
    }

    function set(index, value) {
        if (index < 0 || index >= _items.length)
            return
        _items[index] = value
        changed()
    }

    function remove(index) {
        splice(index, 1)
    }

    // ✅ wie Array.splice(start, deleteCount, ...items)
    function splice(start, deleteCount /*, ...items */) {
        // Argumente einsammeln
        const args = []
        for (let i = 0; i < arguments.length; i++)
            args.push(arguments[i])

        // start normalisieren ähnlich JS
        let s = start
        const len = _items.length
        if (s < 0) s = Math.max(len + s, 0)
        if (s > len) s = len

        // deleteCount normalisieren
        let dc = deleteCount
        if (dc === undefined || dc === null)
            dc = len - s
        dc = Math.max(0, Math.min(dc, len - s))

        args[0] = s
        args[1] = dc

        const removed = _items.splice.apply(_items, args)
        _sync()
        return removed
    }

    function insert(index, value) {
        splice(index, 0, value)
    }

    function toArray() {
        return _items
    }
}
