import Nuke
import UIKit

extension CourseCoverImageView {
    struct Appearance {
        var placeholderImage = UIImage(named: "lesson_cover_50")
        var imageFadeInDuration: TimeInterval = 0.15
    }
}

final class CourseCoverImageView: UIImageView {
    let appearance: Appearance

    override var image: UIImage? {
        didSet {
            if self.image == nil {
                self.image = self.appearance.placeholderImage
            }
        }
    }

    init(frame: CGRect = .zero, appearance: Appearance = Appearance()) {
        self.appearance = appearance
        super.init(frame: frame)

        self.setupView()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadImage(url: URL?) {
        if let url = url {
            var options = ImageLoadingOptions(
                transition: ImageLoadingOptions.Transition.fadeIn(
                    duration: self.appearance.imageFadeInDuration
                )
            )
            if #available(iOS 15.0, *) {
                options.processors.append(ImageProcessingIos15())
            }

            Nuke.loadImage(
                with: url,
                options: options,
                into: self,
                completion: nil
            )
        } else {
            self.image = nil
        }
    }
}

extension CourseCoverImageView: ProgrammaticallyInitializableViewProtocol {
    func setupView() {
        self.image = nil
    }
}

@available(iOS 15.0, *)
class ImageProcessingIos15: ImageProcessing {
    func process(_ image: PlatformImage) -> PlatformImage? {
        image.preparingForDisplay()
    }

    let identifier = "ImageProcessingIos15"
}
