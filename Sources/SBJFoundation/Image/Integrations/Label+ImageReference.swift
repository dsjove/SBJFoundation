import SwiftUI

public extension Label where Title == Text, Icon == Image {
    init(_ title: LocalizedStringKey, image: ImageReference) {
        self = Label { Text(title) } icon: { Image(image) }
    }
    init(_ title: String, image: ImageReference) {
        self = Label { Text(title) } icon: { Image(image) }
    }
}
