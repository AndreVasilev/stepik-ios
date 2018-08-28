//
//  StepViewController.swift
//  ExamEGERussian
//
//  Created by Ivan Magda on 31/07/2018.
//  Copyright © 2018 Alex Karpov. All rights reserved.
//

import Foundation
import Agrume
import PromiseKit
import SnapKit

class StepViewController: UIViewController {
    // MARK: - Types

    private struct Theme {
        static let viewInitialHeight: CGFloat = 5.0

        struct StepWebView {
            static let horizontalSpacing: CGFloat = 2.0
            static let topSpacing: CGFloat = 5.0
        }
    }

    // MARK: - Instance Properties

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!

    private var stepWebViewHeight: Constraint!
    private weak var quizView: UIView?
    private lazy var quizPlaceholderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    var presenter: StepPresenter?

    private lazy var stepWebView: StepWebView = {
        let stepWebView = StepWebView()
        stepWebView.translatesAutoresizingMaskIntoConstraints = false
        stepWebView.scrollView.isScrollEnabled = false

        return stepWebView
    }()

    // For updates after rotation only when controller not presented
    private var shouldRefreshOnAppear: Bool = false

    // MARK: - UIViewController Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()

        activityIndicator.startAnimating()
        presenter?.refreshStep()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        triggerViewLayoutUpdate()

        if shouldRefreshOnAppear {
            refreshWebView()
        }

        fadeIn()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        shouldRefreshOnAppear = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Private API

    private func triggerViewLayoutUpdate() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func setup() {
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didScreenRotate),
            name: .UIDeviceOrientationDidChange,
            object: nil
        )

        setupQuizPlaceholderView()
        setupWebView()
    }

    private func setupQuizPlaceholderView() {
        scrollView.addSubview(quizPlaceholderView)
        quizPlaceholderView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.trailing.leading.bottom.equalToSuperview()
        }
    }

    private func fadeIn(duration: TimeInterval = 0.75) {
        let key = "alpha"

        scrollView.layer.removeAnimation(forKey: key)

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = duration
        scrollView.layer.add(animation, forKey: key)
    }
}

// MARK: - StepViewController (StepView) -

extension StepViewController: StepView {
    func update(with htmlText: String) {
        let processor = HTMLProcessor(html: htmlText)
        let html = processor.injectDefault().html
        stepWebView.loadHTMLString(html, baseURL: URL(fileURLWithPath: Bundle.main.bundlePath))
    }

    func updateQuiz(with controller: UIViewController) {
        quizView = controller.view
        addChildViewController(controller)

        quizPlaceholderView.addSubview(quizView!)
        quizView!.snp.makeConstraints {
            $0.edges.equalTo(quizPlaceholderView)
        }
        controller.didMove(toParentViewController: self)

        triggerViewLayoutUpdate()
    }

    func displayError(title: String, message: String) {
        presentAlert(withTitle: title, message: message)
    }
}

// MARK: - StepViewController (Actions) -

extension StepViewController {
    @objc private func didScreenRotate() {
        refreshWebView()
        fadeIn()

        shouldRefreshOnAppear = !shouldRefreshOnAppear
    }
}

// MARK: - StepViewController (StepWebView) -

extension StepViewController {
    private func setupWebView() {
        scrollView.insertSubview(stepWebView, at: 0)
        stepWebView.snp.makeConstraints { make in
            stepWebViewHeight = make.height.equalTo(Theme.viewInitialHeight).constraint
            make.bottom.equalTo(quizPlaceholderView.snp.top)
            make.leading.equalTo(scrollView).offset(Theme.StepWebView.horizontalSpacing)
            make.trailing.equalTo(scrollView).offset(-Theme.StepWebView.horizontalSpacing)
            make.top.equalTo(scrollView).offset(Theme.StepWebView.topSpacing)
        }

        stepWebView.didFinishNavigation = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }

            strongSelf.stepWebView.alignImages().then {
                strongSelf.stepWebView.getContentHeight()
            }.done { [weak self] height in
                self?.resetWebViewHeight(Float(height))
                self?.triggerViewLayoutUpdate()
                self?.activityIndicator.stopAnimating()
            }.catch { error in
                print("Error after did finish navigation: \(error)")
            }
        }

        stepWebView.onOpenImage = { [weak self] imageURL in
            guard let strongSelf = self else {
                return
            }

            Agrume(imageUrl: imageURL).showFrom(strongSelf)
        }
    }

    private func resetWebViewHeight(_ height: Float) {
        stepWebViewHeight.update(offset: height)
    }

    private func refreshWebView() {
        assert(Thread.isMainThread)

        activityIndicator.startAnimating()
        resetWebViewHeight(5.0)

        stepWebView.reloadContent().then {
            self.stepWebView.alignImages()
        }.then {
            self.stepWebView.getContentHeight()
        }.done { [weak self] height in
            self?.resetWebViewHeight(Float(height))
            self?.triggerViewLayoutUpdate()
            self?.activityIndicator.stopAnimating()
        }.catch { error in
            print("Error while refreshing: \(error)")
        }
    }
}