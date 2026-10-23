import Foundation
import SBJLocalization

/// Semantic imagery used by image import, viewing, and editing UI.
///
/// Keep image-specific vocabulary here rather than expanding the general
/// `SBJSymbology` namespace. Help for image UI merges this
/// vocabulary with the shared Foundation vocabulary so both can use `UI_name\`
/// tokens without repeating SF Symbol names in help content.
public enum SBJImageSymbology: SBJSymbolSet {
    public static let all: [String: SBJSymbol] = [
        "photo": .system("photo"),
        "photoFilled": .system("photo.fill"),
        "viewPhoto": .system("eye"),
        "choosePhotos": .system("photo.on.rectangle"),
        "camera": .system("camera"),
        "cameraUnavailable": .system("camera.slash"),
        "cameraCancel": .system("xmark.circle.fill"),
        "chooseFile": .system("folder"),
        "pastePhoto": .system("doc.on.clipboard"),
        "editPhoto": .system("pencil"),
        "crop": .system("crop"),
        "swapCropDimensions": .system("arrow.left.and.right.text.vertical"),
        "resetPanZoom": .system("arrow.down.left.and.arrow.up.right.rectangle"),
        "mirrorHorizontal": .system("arrow.left.and.right.righttriangle.left.righttriangle.right"),
        "mirrorVertical": .system("arrow.up.and.down"),
        "rotateLeft": .system("rotate.left"),
        "rotateRight": .system("rotate.right"),
        "straighten": .system("dial.medium"),
        "resetStraighten": .system("arrow.counterclockwise"),
        "markup": .system("pencil.tip"),
        "hideMarkup": .system("pencil.slash"),
        "eraseMarkup": .system("eraser"),
        "undoMarkup": .system("arrow.uturn.backward"),
        "redoMarkup": .system("arrow.uturn.forward"),
    ]

}
