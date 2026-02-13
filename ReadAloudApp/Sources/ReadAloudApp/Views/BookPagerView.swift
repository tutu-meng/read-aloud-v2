//
//  BookPagerView.swift
//  ReadAloudApp
//
//  Phase 2A: Replace TabView with UIPageViewController for efficient page rendering.
//  Only 3 views exist at any time (previous, current, next).
//

import SwiftUI
import UIKit

/// A UIPageViewController wrapper that efficiently displays book pages.
/// Unlike TabView+ForEach which creates views for all pages, this only
/// maintains up to 3 page view controllers at a time.
struct BookPagerView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ReaderViewModel
    let pageSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 0]
        )
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        // Disable the built-in page indicator dots
        pvc.view.subviews.forEach { subview in
            if subview is UIPageControl {
                subview.isHidden = true
            }
        }
        // Set initial page
        let initialVC = context.coordinator.makePageVC(for: viewModel.currentPage)
        pvc.setViewControllers([initialVC], direction: .forward, animated: false)
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        guard let currentVC = pvc.viewControllers?.first as? SinglePageViewController else { return }

        let displayedPage = currentVC.pageIndex

        // Update content of the currently displayed page (e.g., when cache refreshes)
        let content = viewModel.contentForPage(displayedPage)
        currentVC.updateContent(content, settings: viewModel.coordinator.userSettings)

        // If the viewModel's currentPage changed externally (e.g., restoreSavedPosition),
        // navigate the pager to match
        if displayedPage != viewModel.currentPage {
            let direction: UIPageViewController.NavigationDirection =
                viewModel.currentPage > displayedPage ? .forward : .reverse
            let newVC = context.coordinator.makePageVC(for: viewModel.currentPage)
            pvc.setViewControllers([newVC], direction: direction, animated: false)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let parent: BookPagerView

        init(_ parent: BookPagerView) {
            self.parent = parent
        }

        func makePageVC(for pageIndex: Int) -> SinglePageViewController {
            let content = parent.viewModel.contentForPage(pageIndex)
            return SinglePageViewController(
                pageIndex: pageIndex,
                content: content,
                settings: parent.viewModel.coordinator.userSettings,
                pageSize: parent.pageSize
            )
        }

        // MARK: - UIPageViewControllerDataSource

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? SinglePageViewController else { return nil }
            let prevIndex = vc.pageIndex - 1
            guard prevIndex >= 0 else { return nil }
            return makePageVC(for: prevIndex)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? SinglePageViewController else { return nil }
            let nextIndex = vc.pageIndex + 1
            guard nextIndex < parent.viewModel.totalPages else { return nil }
            return makePageVC(for: nextIndex)
        }

        // MARK: - UIPageViewControllerDelegate

        func pageViewController(_ pageViewController: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard completed,
                  let currentVC = pageViewController.viewControllers?.first as? SinglePageViewController else { return }
            // Sync viewModel's currentPage with the page that is now displayed
            DispatchQueue.main.async {
                self.parent.viewModel.currentPage = currentVC.pageIndex
            }
        }
    }
}

// MARK: - SinglePageViewController

/// A lightweight UIViewController that hosts a UITextView for a single page.
class SinglePageViewController: UIViewController {
    let pageIndex: Int
    private var content: String
    private var settings: UserSettings
    private let pageSize: CGSize
    private var textView: UITextView?

    init(pageIndex: Int, content: String, settings: UserSettings, pageSize: CGSize) {
        self.pageIndex = pageIndex
        self.content = content
        self.settings = settings
        self.pageSize = pageSize
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        // Extra 8pt bottom buffer accommodates Core Text/UITextView layout differences
        // Pagination calculates with 16pt insets, display shows with 24pt bottom for safety margin
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        tv.contentInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.maximumNumberOfLines = 0
        tv.textContainer.lineBreakMode = .byCharWrapping
        tv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tv)
        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: view.topAnchor),
            tv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        self.textView = tv
        applyContent()
    }

    func updateContent(_ newContent: String, settings newSettings: UserSettings) {
        content = newContent
        settings = newSettings
        applyContent()
    }

    private func applyContent() {
        guard let tv = textView else { return }
        tv.backgroundColor = backgroundColor(for: settings.theme)
        view.backgroundColor = tv.backgroundColor

        let attrStr = NSMutableAttributedString(string: content)
        let font = resolveFont(name: settings.fontName, size: settings.fontSize)
        let color = textColor(for: settings.theme)
        let fullRange = NSRange(location: 0, length: (content as NSString).length)
        attrStr.addAttribute(.font, value: font, range: fullRange)
        attrStr.addAttribute(.foregroundColor, value: color, range: fullRange)
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 4 * settings.lineSpacing
        ps.paragraphSpacing = 8 * settings.lineSpacing
        ps.lineBreakMode = .byCharWrapping
        attrStr.addAttribute(.paragraphStyle, value: ps, range: fullRange)
        tv.attributedText = attrStr
    }

    // MARK: - Helpers (mirrors PageView)

    private func resolveFont(name: String, size: CGFloat) -> UIFont {
        switch name {
        case "System": return UIFont.systemFont(ofSize: size)
        case "Georgia": return UIFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size)
        case "Helvetica": return UIFont(name: "Helvetica", size: size) ?? .systemFont(ofSize: size)
        case "Times New Roman": return UIFont(name: "Times New Roman", size: size) ?? .systemFont(ofSize: size)
        case "Courier": return UIFont(name: "Courier", size: size) ?? .systemFont(ofSize: size)
        case "Palatino": return UIFont(name: "Palatino-Roman", size: size) ?? .systemFont(ofSize: size)
        case "Baskerville": return UIFont(name: "Baskerville", size: size) ?? .systemFont(ofSize: size)
        default: return UIFont.systemFont(ofSize: size)
        }
    }

    private func backgroundColor(for theme: String) -> UIColor {
        switch theme {
        case "dark": return .black
        case "sepia": return UIColor(red: 0.95, green: 0.91, blue: 0.82, alpha: 1.0)
        default: return .systemBackground
        }
    }

    private func textColor(for theme: String) -> UIColor {
        switch theme {
        case "dark": return .white
        case "sepia": return UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        default: return .label
        }
    }
}
