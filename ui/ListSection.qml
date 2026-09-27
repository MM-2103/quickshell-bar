// ListSection.qml
// A labelled group of ListRows: "CONNECTED · 1" followed by one delegate
// per model entry. Hides itself when the model is empty. Views that also
// gate on something else (radio off) override visible and include count.

import QtQuick
import qs

Column {
    id: section

    property string label: ""
    property alias model: rep.model
    property alias delegate: rep.delegate
    readonly property int count: rep.count

    width: parent ? parent.width : 0
    spacing: 4
    visible: count > 0

    SectionHeader {
        label: section.label
        count: section.count
    }

    Repeater { id: rep }
}
