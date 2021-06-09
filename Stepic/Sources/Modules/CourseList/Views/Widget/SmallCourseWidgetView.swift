import SnapKit
import UIKit

extension SmallCourseWidgetView {
    struct Appearance {
        let coverViewInsets = LayoutInsets(top: 16, left: 16)
        let coverViewWidthHeight: CGFloat = 80.0

        let badgeImageViewInsets = LayoutInsets(right: 16)
        let badgeImageViewSize = CGSize(width: 18, height: 18)

        let titleLabelInsets = LayoutInsets(top: 16, left: 16, bottom: 16, right: 16)
    }
}

final class SmallCourseWidgetView: UIView, CourseWidgetViewProtocol {
    let appearance: Appearance
    let colorMode: CourseListColorMode

    private lazy var coverView = CourseWidgetCoverView()

    private lazy var badgeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = self.colorMode.courseWidgetBadgeTintColor
        return imageView
    }()

    private lazy var titleLabel = CourseWidgetLabel(
        appearance: self.colorMode.courseWidgetTitleLabelAppearance
    )

    init(
        frame: CGRect = .zero,
        colorMode: CourseListColorMode = .default,
        appearance: Appearance = Appearance()
    ) {
        self.appearance = appearance
        self.colorMode = colorMode
        super.init(frame: frame)

        self.setupView()
        self.addSubviews()
        self.makeConstraints()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: CourseWidgetViewModel) {
        self.coverView.coverImageURL = viewModel.coverImageURL
        self.coverView.shouldShowAdaptiveMark = viewModel.isAdaptive

        self.titleLabel.text = viewModel.title

        self.updateBadgeImageView(viewModel: viewModel)
    }

    private func updateBadgeImageView(viewModel: CourseWidgetViewModel) {
        let badgeImage: UIImage? = {
            if viewModel.isWishlistAvailable {
                let imageName = viewModel.isWishlisted ? "wishlist-like-filled" : "wishlist-like"
                return UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
            } else if let userCourse = viewModel.userCourse {
                return userCourse.isFavorite
                    ? UIImage(named: "course-widget-favorite")?.withRenderingMode(.alwaysTemplate)
                    : nil
            } else {
                return nil
            }
        }()

        self.badgeImageView.image = badgeImage
        self.badgeImageView.isHidden = badgeImage == nil
    }
}

extension SmallCourseWidgetView: ProgrammaticallyInitializableViewProtocol {
    func setupView() {
        self.backgroundColor = self.colorMode.courseWidgetBackgroundColor
    }

    func addSubviews() {
        self.addSubview(self.coverView)
        self.addSubview(self.badgeImageView)
        self.addSubview(self.titleLabel)
    }

    func makeConstraints() {
        self.coverView.translatesAutoresizingMaskIntoConstraints = false
        self.coverView.snp.makeConstraints { make in
            make.top
                .equalToSuperview()
                .offset(self.appearance.coverViewInsets.top)
            make.leading
                .equalToSuperview()
                .offset(self.appearance.coverViewInsets.left)
            make.height
                .width
                .equalTo(self.appearance.coverViewWidthHeight)
        }

        self.badgeImageView.translatesAutoresizingMaskIntoConstraints = false
        self.badgeImageView.snp.makeConstraints { make in
            make.top.equalTo(self.coverView.snp.top)
            make.trailing.equalToSuperview().offset(-self.appearance.badgeImageViewInsets.right)
            make.size.equalTo(self.appearance.badgeImageViewSize)
        }

        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.snp.makeConstraints { make in
            make.top
                .equalTo(self.coverView.snp.bottom)
                .offset(self.appearance.titleLabelInsets.top)
            make.leading
                .equalToSuperview()
                .offset(self.appearance.titleLabelInsets.left)
            make.bottom
                .lessThanOrEqualToSuperview()
                .offset(-self.appearance.titleLabelInsets.bottom)
            make.trailing
                .equalToSuperview()
                .offset(-self.appearance.titleLabelInsets.right)
        }
    }
}
