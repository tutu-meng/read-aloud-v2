//
//  PaginationLayoutParityTests.swift
//  ReadAloudAppTests
//
//  BUG-5: Diagnose and verify that pagination-calculated page content
//  fits within UITextView without clipping.
//

import XCTest
@testable import ReadAloudApp

final class PaginationLayoutParityTests: XCTestCase {

    /// CJK sample text long enough to span multiple pages
    private func makeCJKSample() -> String {
        // ~2000 CJK characters — enough for several pages at font size 16
        let block = "诡秘之主的世界观设定非常庞大，融合了蒸汽朋克、克苏鲁神话和维多利亚时代的元素。故事讲述了一个穿越者克莱恩在这个充满神秘力量的世界中，从一名普通的夜莲花学者逐渐成长为掌控命运的存在。每一个序列的途径都有着独特的能力体系，而非凡者之间的博弈更是精彩纷呈。这是一段关于探索未知、对抗疯狂、守护人性的史诗旅程。在这个世界里，真相往往隐藏在层层迷雾之后，而每一次揭露都可能带来更深的恐惧。克莱恩必须在保持理智的同时，不断攀登序列的阶梯，最终面对那些超越人类认知的古老存在。\n"
        return String(repeating: block, count: 10)
    }

    /// Build a UITextView configured identically to SinglePageViewController
    private func makeDisplayTextView(drawableSize: CGSize, content: String, settings: UserSettings) -> UITextView {
        // Frame = drawable size + insets (matches how BookPagerView/SinglePageViewController works)
        let inset: CGFloat = 16
        let frame = CGRect(
            x: 0, y: 0,
            width: drawableSize.width + 2 * inset,
            height: drawableSize.height + 2 * inset
        )
        let tv = UITextView(frame: frame)
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        tv.contentInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.maximumNumberOfLines = 0
        tv.textContainer.lineBreakMode = .byCharWrapping
        tv.attributedText = TextStyling.createAttributedString(from: content, settings: settings)
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        return tv
    }

    // MARK: - Diagnostic Test

    /// Paginate CJK text and check whether UITextView can render each page without clipping.
    func testPaginationContentFitsInUITextView() {
        let settings = UserSettings()  // default: System 16, lineSpacing 1.2
        let drawableSize = CGSize(width: 370, height: 607)  // typical iPhone 16 Pro
        let bounds = CGRect(origin: .zero, size: drawableSize)
        let sampleText = makeCJKSample()

        let paginationService = PaginationService(textContent: sampleText, userSettings: settings)
        let fullAttrStr = TextStyling.createAttributedString(from: sampleText, settings: settings)

        var currentIndex = 0
        var pageNum = 0
        var overflowPages: [(page: Int, overflow: CGFloat, chars: Int)] = []

        while currentIndex < (sampleText as NSString).length {
            pageNum += 1
            let range = paginationService.calculatePageRange(
                from: currentIndex,
                in: bounds,
                with: fullAttrStr
            )
            guard range.length > 0 else { break }

            // Extract page content (same as BackgroundPaginationService.calculateBatch)
            let nsContent = sampleText as NSString
            let safeLen = min(range.length, max(0, nsContent.length - range.location))
            let pageContent = nsContent.substring(with: NSRange(location: range.location, length: safeLen))

            // Create UITextView and measure
            let tv = makeDisplayTextView(drawableSize: drawableSize, content: pageContent, settings: settings)
            let usedRect = tv.layoutManager.usedRect(for: tv.textContainer)

            let overflow = usedRect.height - drawableSize.height
            if overflow > 0.5 {  // allow 0.5pt tolerance for sub-pixel rounding
                overflowPages.append((page: pageNum, overflow: overflow, chars: safeLen))
                print("[BUG-5] Page \(pageNum): OVERFLOW by \(overflow)pt (\(safeLen) chars, usedRect.height=\(usedRect.height), available=\(drawableSize.height))")
            } else {
                print("[BUG-5] Page \(pageNum): OK (usedRect.height=\(usedRect.height), available=\(drawableSize.height), margin=\(-overflow)pt)")
            }

            currentIndex = range.location + safeLen
            if pageNum > 50 { break }  // cap for test speed
        }

        print("[BUG-5] Summary: \(overflowPages.count) / \(pageNum) pages overflow")
        for p in overflowPages {
            print("  Page \(p.page): +\(p.overflow)pt overflow, \(p.chars) chars")
        }

        // The test FAILS if any page overflows — this is expected BEFORE the fix
        XCTAssertEqual(overflowPages.count, 0, "Found \(overflowPages.count) pages where content overflows UITextView bounds")
    }

    /// Verify no character gaps between consecutive pages
    func testNoCharacterGapsBetweenPages() {
        let settings = UserSettings()
        let drawableSize = CGSize(width: 370, height: 607)
        let bounds = CGRect(origin: .zero, size: drawableSize)
        let sampleText = makeCJKSample()

        let paginationService = PaginationService(textContent: sampleText, userSettings: settings)
        let fullAttrStr = TextStyling.createAttributedString(from: sampleText, settings: settings)

        var currentIndex = 0
        var allContent = ""
        var pageNum = 0

        while currentIndex < (sampleText as NSString).length {
            pageNum += 1
            let range = paginationService.calculatePageRange(
                from: currentIndex,
                in: bounds,
                with: fullAttrStr
            )
            guard range.length > 0 else { break }

            let nsContent = sampleText as NSString
            let safeLen = min(range.length, max(0, nsContent.length - range.location))
            let pageContent = nsContent.substring(with: NSRange(location: range.location, length: safeLen))
            allContent += pageContent
            currentIndex = range.location + safeLen
            if pageNum > 50 { break }
        }

        // Concatenated pages should equal the original text (up to where we paginated)
        let expected = (sampleText as NSString).substring(to: currentIndex)
        XCTAssertEqual(allContent, expected, "Concatenated page contents don't match original text — character gap detected")
    }
}
