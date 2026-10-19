import Foundation
import SBJDataDefinition
import SBJLocalization

/// Semantic imagery used by image import, viewing, and editing UI.
///
/// Keep image-specific vocabulary here rather than expanding the general
/// `SBJSymbology` namespace. Help for image UI merges this
/// vocabulary with the shared Foundation vocabulary so both can use `UI_name\`
/// tokens without repeating SF Symbol names in help content.
public enum SBJImageSymbology {
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

    private static func image(_ name: String) -> SBJSymbol {
        guard let reference = all[name] else {
            preconditionFailure("Unknown image semantic image: \(name)")
        }
        return reference
    }

    public static let photo = image("photo")
    public static let photoFilled = image("photoFilled")
    public static let viewPhoto = image("viewPhoto")
    public static let choosePhotos = image("choosePhotos")
    public static let camera = image("camera")
    public static let cameraUnavailable = image("cameraUnavailable")
    public static let cameraCancel = image("cameraCancel")
    public static let chooseFile = image("chooseFile")
    public static let pastePhoto = image("pastePhoto")
    public static let editPhoto = image("editPhoto")
    public static let crop = image("crop")
    public static let swapCropDimensions = image("swapCropDimensions")
    public static let resetPanZoom = image("resetPanZoom")
    public static let mirrorHorizontal = image("mirrorHorizontal")
    public static let mirrorVertical = image("mirrorVertical")
    public static let rotateLeft = image("rotateLeft")
    public static let rotateRight = image("rotateRight")
    public static let straighten = image("straighten")
    public static let resetStraighten = image("resetStraighten")
    public static let markup = image("markup")
    public static let hideMarkup = image("hideMarkup")
    public static let eraseMarkup = image("eraseMarkup")
    public static let undoMarkup = image("undoMarkup")
    public static let redoMarkup = image("redoMarkup")

    /// Shared + image-specific vocabulary for image help.
    public static var helpVocabulary: [String: SBJSymbol] {
        SBJSymbology.vocabulary(adding: all)
    }
}

public extension SBJHelpConfiguration {
    /// Help configuration for image import, viewing, and editing UI.
    static var image: Self {
        .init(semanticImages: SBJImageSymbology.helpVocabulary)
    }
}
