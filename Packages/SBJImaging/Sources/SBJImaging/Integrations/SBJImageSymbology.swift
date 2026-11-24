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

import SBJHelp

/// Imaging-specific actions. The same values drive controls, accessible names and help.
/// IDs are namespaced because a generic action such as Remove can mean something else
/// in a different editor.
public enum SBJImageNomenclature: SBJNomenclatureSet {
    public static let all: [String: SBJNomenclature] = [
        "image.view": .init(
            title: "View",
            details: "Open the image viewer.",
            symbol: SBJImageSymbology.viewPhoto),
        "image.choosePhotos": .init(
            title: "Photos",
            details: "Choose an image from the photo library.",
            symbol: SBJImageSymbology.choosePhotos),
        "image.camera": .init(
            title: "Camera",
            details: "Capture a new image using the camera.",
            symbol: SBJImageSymbology.camera),
        "image.chooseFile": .init(
            title: "Files",
            details: "Import an image from a file.",
            symbol: SBJImageSymbology.chooseFile),
        "image.paste": .init(
            title: "Paste",
            details: "Paste an image from the clipboard when an image is available.",
            symbol: SBJImageSymbology.pastePhoto),
        "image.edit": .init(
            title: "Edit",
            details: "Open the image editor.",
            symbol: SBJImageSymbology.editPhoto),
        "image.clear": .init(
            title: "Clear",
            details: "Remove the selected image.",
            symbol: SBJSymbology.delete),
        "image.crop": .init(
            title: "Crop",
            details: "Choose a crop shape. A checkmark identifies the selected crop.",
            symbol: SBJImageSymbology.crop),
        "image.swapCropDimensions": .init(
            title: "Swap Width and Height",
            details: "Transpose the width and height of a supported crop ratio, such as 4:3 to 3:4.",
            symbol: SBJImageSymbology.swapCropDimensions),
        "image.resetPanZoom": .init(
            title: "Reset Pan and Zoom",
            details: "Restore the image's fitted magnification and centered position. You can also double-tap the image.",
            symbol: SBJImageSymbology.resetPanZoom),
        "image.rotateLeft": .init(
            title: "Rotate Left 90 Degrees",
            details: "Rotate the image 90 degrees counterclockwise.",
            symbol: SBJImageSymbology.rotateLeft),
        "image.rotateRight": .init(
            title: "Rotate Right 90 Degrees",
            details: "Rotate the image 90 degrees clockwise.",
            symbol: SBJImageSymbology.rotateRight),
        "image.mirrorHorizontal": .init(
            title: "Mirror Horizontally",
            details: "Mirror the image from left to right.",
            symbol: SBJImageSymbology.mirrorHorizontal),
        "image.mirrorVertical": .init(
            title: "Mirror Vertically",
            details: "Mirror the image from top to bottom, when available.",
            symbol: SBJImageSymbology.mirrorVertical),
        "image.straighten": .init(
            title: "Straighten",
            details: "Open the fine-straightening control. The displayed angle includes quarter turns.",
            symbol: SBJImageSymbology.straighten),
        "image.resetStraighten": .init(
            title: "Reset Straighten",
            details: "Restore the rotation to its original value.",
            symbol: SBJImageSymbology.resetStraighten),
        "image.showMarkup": .init(
            title: "Show Markup Tools",
            details: "Show the drawing tools when markup is enabled.",
            symbol: SBJImageSymbology.markup),
        "image.hideMarkup": .init(
            title: "Hide Markup Tools",
            details: "Hide the drawing tools.",
            symbol: SBJImageSymbology.hideMarkup),
        "image.clearMarkup": .init(
            title: "Clear Markup",
            details: "Erase the drawing markup.",
            symbol: SBJImageSymbology.eraseMarkup),
        "image.undoMarkup": .init(
            title: "Undo Markup",
            details: "Undo the last drawing change.",
            symbol: SBJImageSymbology.undoMarkup),
        "image.redoMarkup": .init(
            title: "Redo Markup",
            details: "Redo the last undone drawing change.",
            symbol: SBJImageSymbology.redoMarkup),
        "image.share": .init(
            title: "Share",
            details: "Share the displayed or currently edited image, when sharing is enabled.",
            symbol: SBJSymbology.share),
        "image.closeViewer": .init(
            title: "Close",
            details: "Close the image viewer without changing the saved image.",
            symbol: SBJSymbology.close),
        "image.slideshow.close": .init(
            title: "Close Slideshow",
            details: "Close the current image slideshow.",
            symbol: .system("xmark")),
        "image.slideshow.previous": .init(
            title: "Previous Slide",
            details: "Show the previous image in the slideshow.",
            symbol: .system("chevron.left")),
        "image.slideshow.next": .init(
            title: "Next Slide",
            details: "Show the next image in the slideshow.",
            symbol: .system("chevron.right")),
        "image.slideshow.play": .init(
            title: "Play Slideshow",
            details: "Advance automatically through the available images.",
            symbol: .system("play.fill")),
        "image.slideshow.pause": .init(
            title: "Pause Slideshow",
            details: "Pause automatic advancement of the slideshow.",
            symbol: .system("pause.fill")),
        "image.slideshow.fullscreen": .init(
            title: "Toggle Full Screen",
            details: "Toggle the slideshow's full-screen presentation.",
            symbol: .system("arrow.up.left.and.arrow.down.right")),
        "image.slideshow.title": .init(title: "Slide Title", details: "Title of the currently displayed slide."),
        // Shared non-destructive image enhancement controls.
        "image.enhancement.heading": .init(title: "Image Enhancements", details: "Adjust exposure, contrast, color, and detail without changing the original image."),
        "image.enhancement.compare": .init(title: "Before/After", details: "Disable enhancements to compare the result with the original image."),
        "image.enhancement.exposure": .init(title: "Exposure", details: "Adjust the overall image exposure."),
        "image.enhancement.shadows": .init(title: "Shadows", details: "Adjust the shadow areas of the image."),
        "image.enhancement.highlights": .init(title: "Highlights", details: "Adjust the highlight areas of the image."),
        "image.enhancement.contrast": .init(title: "Contrast", details: "Adjust contrast between light and dark areas."),
        "image.enhancement.saturation": .init(title: "Saturation", details: "Adjust the intensity of image colors."),
        "image.enhancement.detail": .init(title: "Detail", details: "Adjust the image detail enhancement."),
        "image.enhancement.noise-reduction": .init(title: "Noise Reduction", details: "Adjust the strength of noise reduction."),
        "image.enhancement.dark": .init(title: "Dark", details: "Apply the dark enhancement preset."),
        "image.enhancement.faded": .init(title: "Faded", details: "Apply the faded enhancement preset."),
        "image.enhancement.grainy": .init(title: "Grainy", details: "Apply the grainy enhancement preset."),
        "image.enhancement.reset": .init(title: "Reset Enhancements", details: "Clear the enhancement adjustments."),
        // Movie playback and poster actions share this vocabulary across UI and accessibility.
        "movie.previousFrame": .init(
            title: "Previous Frame",
            details: "Move backward one video frame. Hold to continue stepping.",
            symbol: .system("backward.frame")),
        "movie.nextFrame": .init(
            title: "Next Frame",
            details: "Move forward one video frame. Hold to continue stepping.",
            symbol: .system("forward.frame")),
        "movie.play": .init(
            title: "Play Movie",
            details: "Resume movie playback.",
            symbol: .system("play.fill")),
        "movie.pause": .init(
            title: "Pause Movie",
            details: "Pause movie playback.",
            symbol: .system("pause.fill")),
        "movie.setPoster": .init(
            title: "Set Poster Frame",
            details: "Save the current playback frame as the movie's poster image.",
            symbol: .system("photo.stack")),
        "movie.clearPoster": .init(
            title: "Clear Poster Frame",
            details: "Remove the movie's saved poster frame.",
            symbol: .system("photo.slash")),
        "movie.fullscreen": .init(
            title: "Full Screen",
            details: "Show the movie in full screen.",
            symbol: .system("arrow.up.left.and.arrow.down.right")),
        "movie.enhancements": .init(
            title: "Image Enhancements",
            details: "Show image enhancement controls for movie playback.",
            symbol: .system("slider.horizontal.3")),
        "movie.inspectFrame": .init(
            title: "View Current Frame",
            details: "Inspect the current movie frame without changing the saved poster.",
            symbol: .system("photo")),
        "movie.embeddedPhotoOptions": .init(
            title: "Embedded Photo Options",
            details: "Open options for viewing or changing the embedded poster image.",
            symbol: .system("person.crop.artframe")),
        "movie.close": .init(
            title: "Close Movie",
            details: "Close the movie viewer.",
            symbol: .system("xmark")),
        "movie.savingPoster": .init(title: "Saving Poster Frame",
            details: "Saving the selected frame as the movie poster."),

    ]
}


public extension SBJHelpConfiguration {
    /// Help configuration for image import, viewing, and editing UI.
    static var imageHelp: Self {
        var configuration = Self.standard
        configuration.addSymbolSet(SBJImageSymbology.self)
        configuration.addNomenclatureSet(SBJImageNomenclature.self)
        return configuration
    }
}
