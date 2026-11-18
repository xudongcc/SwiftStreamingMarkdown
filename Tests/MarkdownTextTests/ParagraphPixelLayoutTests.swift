//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if canImport(UIKit)
import Markdown
@testable import SwiftStreamingMarkdown
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct ParagraphPixelLayoutTests {
  @Test(arguments: [false, true], [
    "The library is open. **Please bring your notebook.**",
    "**Weekly notes** 已整理，欢迎阅读更新内容。",
    "## **Weekly notes** 已整理，欢迎阅读更新内容。"
  ])
  func centeredMarkdownHasRoomForTextAtItsPlacedWidth(useCallout: Bool, source: String) async throws {
    let expected = source.replacingOccurrences(of: "## ", with: "").replacingOccurrences(of: "**", with: "")
    let defaults = MarkdownRenderConfig.default.withShouldAnimateText(value: false)
    let config: MarkdownRenderConfig
    if useCallout {
      let base = defaults.paragraphStyle.textFonts
      let font = UIFont.preferredFont(forTextStyle: .callout)
      let fonts = TextFonts(
        normal: font,
        italic: base.italic?.withSize(font.pointSize),
        bold: base.bold?.withSize(font.pointSize),
        boldItalic: base.boldItalic?.withSize(font.pointSize),
        preferredLetterSpacing: nil,
        preferredLineHeight: nil
      )
      config = defaults.withParagraphStyle(value: .init(textFonts: fonts, textColor: .primary))
    } else {
      config = defaults
    }

    let document = await RenderableDocument(document: Markdown.Document(parsing: source), config: config)
    let widths: [CGFloat] = [320, 458, 670, 671, 671 + 2 / 3, 694 + 2 / 3, 700]
    for width in widths {
      let root = DocumentView(renderableDocument: document, config: config)
        .frame(width: width)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      try await inspectParagraph(in: root) { paragraph in
        #expect(paragraph.text == expected)
        let naturalSize = paragraph.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let placedSize = paragraph.sizeThatFits(CGSize(width: paragraph.bounds.width, height: .greatestFiniteMagnitude))
        #expect(paragraph.bounds.height >= placedSize.height, "Frame width \(width), natural \(naturalSize), placed \(placedSize), bounds \(paragraph.bounds)")
        #expect(abs(paragraph.bounds.height - naturalSize.height) <= 1)
      }
    }
  }

  @Test
  func tableCellWithInlineAttachmentUsesParagraphLayout() async throws {
    let source = """
    | Topic | Notes |
    | --- | --- |
    | Reading | Reading list [9F742443](https://example.com?citationMarker=9F742443&citationTitle=Library&citationA11yValue=Library) |
    """
    let config = MarkdownRenderConfig.default.withShouldAnimateText(value: false)
    let document = await RenderableDocument(document: Markdown.Document(parsing: source), config: config)
    let root = DocumentView(renderableDocument: document, config: config)
    try await inspectParagraph(in: root) { paragraph in
      #expect(paragraph.text.contains("Reading list"))
      #expect(paragraph.attributedText.containsAttachments(in: NSRange(location: 0, length: paragraph.attributedText.length)))
      let placedSize = paragraph.sizeThatFits(CGSize(width: paragraph.bounds.width, height: .greatestFiniteMagnitude))
      #expect(paragraph.bounds.height >= placedSize.height)
    }
  }

  private func inspectParagraph(in root: some View, inspect: (ParagraphUIView) -> Void) async throws {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 160))
    let host = UIHostingController(rootView: root)
    window.rootViewController = host
    window.isHidden = false
    defer { window.isHidden = true }
    host.view.layoutIfNeeded()
    await Task.yield()
    inspect(try #require(paragraph(in: host.view)))
  }

  private func paragraph(in view: UIView) -> ParagraphUIView? {
    if let textView = view as? ParagraphUIView {
      return textView
    }
    return view.subviews.lazy.compactMap { paragraph(in: $0) }.first
  }
}
#endif
