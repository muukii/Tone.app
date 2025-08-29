import Algorithms
import AppService
import SwiftUI
import SwiftUISupport
import UIKit

// MARK: - Custom Separator Attachment

/// Custom view for displaying separators in the text view
@MainActor
class SeparatorAttachmentView: UIView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    
    // Draw a gradient line
    let colors = [
      UIColor.quaternaryLabel.withAlphaComponent(0.2).cgColor,
      UIColor.quaternaryLabel.withAlphaComponent(0.6).cgColor,
      UIColor.quaternaryLabel.withAlphaComponent(0.2).cgColor
    ]
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let locations: [CGFloat] = [0.0, 0.5, 1.0]
    
    guard let gradient = CGGradient(
      colorsSpace: colorSpace,
      colors: colors as CFArray,
      locations: locations
    ) else { return }
    
    let startPoint = CGPoint(x: 0, y: rect.height / 2)
    let endPoint = CGPoint(x: rect.width, y: rect.height / 2)
    
    context.drawLinearGradient(
      gradient,
      start: startPoint,
      end: endPoint,
      options: []
    )
  }
}

/// View provider for the separator attachment
@MainActor
class SeparatorAttachmentViewProvider: NSTextAttachmentViewProvider {
  override func loadView() {
    super.loadView()
    
    // Set to track text container bounds for responsive width
    tracksTextAttachmentViewBounds = true
    
    // Create and set the custom separator view
    let separatorView = SeparatorAttachmentView(frame: .zero)
    self.view = separatorView
  }
  
  override func attachmentBounds(
    for attributes: [NSAttributedString.Key : Any],
    location: NSTextLocation,
    textContainer: NSTextContainer?,
    proposedLineFragment: CGRect,
    position: CGPoint
  ) -> CGRect {
    // Return bounds with full width and custom height
    return CGRect(
      x: 0,
      y: 0,
      width: proposedLineFragment.width,
      height: 24  // Height for the separator
    )
  }
}

/// Text attachment for separators
class SeparatorAttachment: NSTextAttachment {
  
  override func viewProvider(
    for parentView: UIView?,
    location: any NSTextLocation,
    textContainer: NSTextContainer?
  ) -> NSTextAttachmentViewProvider? {
    let provider = SeparatorAttachmentViewProvider.init(
      textAttachment: self,
      parentView: parentView,
      textLayoutManager: textContainer?.textLayoutManager,
      location: location
    )
    
    return provider
  }
  
}

@MainActor
struct PlayerTextView: View, PlayerDisplay {

  unowned let controller: PlayerController
  private let actionHandler: @MainActor (PlayerAction) async -> Void
  let service: Service
  private let pins: [PinEntity]

  @State var isFollowing: Bool = true

  init(
    controller: PlayerController,
    pins: [PinEntity],
    service: Service,
    actionHandler: @escaping @MainActor (PlayerAction) async -> Void
  ) {
    self.controller = controller
    self.pins = pins
    self.service = service
    self.actionHandler = actionHandler
  }

  var body: some View {
    ZStack {
      TextView(
        controller: controller,
        pins: pins,
        fontSize: service.chunkFontSize,
        isFollowing: $isFollowing,
        actionHandler: actionHandler
      )

      Button {
        isFollowing = true
      } label: {
        Image(systemName: "arrow.up.backward.circle.fill")
      }
      .buttonStyle(.bordered)
      .buttonBorderShape(.roundedRectangle)
      .opacity(isFollowing ? 0 : 1)
      .relative(horizontalAlignment: .trailing, verticalAlignment: .bottom)
      .padding(20)
    }
  }
}

// MARK: - TextView UIViewRepresentable

private struct TextView: UIViewRepresentable {

  unowned let controller: PlayerController
  let pins: [PinEntity]
  let fontSize: Double
  @Binding var isFollowing: Bool
  let actionHandler: @MainActor (PlayerAction) async -> Void

  func makeUIView(context: Context) -> UITextView {
    // Register the separator view provider once
    let textView = UITextView()
    
    // Force TextKit 2 usage - prevent fallback to TextKit 1
    if #available(iOS 16.0, *) {
      _ = textView.textLayoutManager // Access to force initialization
    }
    
    textView.delegate = context.coordinator
    textView.isEditable = false
    textView.isSelectable = false
    textView.showsVerticalScrollIndicator = true
    textView.contentInsetAdjustmentBehavior = .automatic
    textView.backgroundColor = .systemBackground
    textView.textContainerInset = UIEdgeInsets(
      top: 20,
      left: 16,
      bottom: 20,
      right: 16
    )

    // Add gesture recognizers
    let tapGesture = UITapGestureRecognizer()
    tapGesture.addTarget(
      context.coordinator,
      action: #selector(Coordinator.handleTap(_:))
    )
    textView.addGestureRecognizer(tapGesture)

    let longPressGesture = UILongPressGestureRecognizer()
    longPressGesture.addTarget(
      context.coordinator,
      action: #selector(Coordinator.handleLongPress(_:))
    )
    textView.addGestureRecognizer(longPressGesture)

    return textView
  }

  func updateUIView(_ textView: UITextView, context: Context) {
    let coordinator = context.coordinator
    coordinator.textView = textView
    coordinator.update(
      cues: controller.cues,
      currentCue: controller.currentCue,
      playingRange: controller.playingRange,
      pins: pins,
      fontSize: fontSize,
      isFollowing: isFollowing
    )
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      controller: controller,
      actionHandler: actionHandler,
      isFollowingBinding: $isFollowing
    )
  }

  // MARK: - Coordinator

  final class Coordinator: NSObject, UITextViewDelegate {
    
    /// TextKitのバージョンを指定するenum
    enum TextKitVersion {
      case automatic  // システムが自動選択（デフォルト）
      case textKit1   // TextKit 1を強制使用
      case textKit2   // TextKit 2を強制使用
    }

    private struct CueRange {
      let cue: DisplayCue
      let range: NSRange
    }

    weak var textView: UITextView?
    private var cueRanges: [CueRange] = []
    private var attributedString = NSMutableAttributedString()
    
    // TextKitバージョンの強制設定（デバッグ/テスト用）
    var forcedTextKitVersion: TextKitVersion = .textKit1

    private let controller: PlayerController
    private let actionHandler: @MainActor (PlayerAction) async -> Void
    private let isFollowingBinding: Binding<Bool>

    // Current state
    private var currentCues: [DisplayCue] = []
    private var currentCue: DisplayCue?
    private var playingRange: PlayingRange?
    private var pinnedCueIds: Set<String> = []
    private var fontSize: Double = 16
    
    // Performance tracking
    private var isUserScrolling = false
    private var previousCurrentCue: DisplayCue?
    private var previousPlayingRange: PlayingRange?

    init(
      controller: PlayerController,
      actionHandler: @escaping @MainActor (PlayerAction) async -> Void,
      isFollowingBinding: Binding<Bool>
    ) {
      self.controller = controller
      self.actionHandler = actionHandler
      self.isFollowingBinding = isFollowingBinding
    }

    func update(
      cues: [DisplayCue],
      currentCue: DisplayCue?,
      playingRange: PlayingRange?,
      pins: [PinEntity],
      fontSize: Double,
      isFollowing: Bool
    ) {
      
      // Skip expensive updates while user is scrolling
      if isUserScrolling {
        return
      }
      
      let pinnedIds = Set(pins.map(\.startCueRawIdentifier))

      // Check if we need to rebuild the attributed string (more efficient comparison)
      let needsRebuild =
        !currentCues.elementsEqual(cues, by: { $0.id == $1.id }) ||
        self.fontSize != fontSize ||
        self.pinnedCueIds != pinnedIds

      if needsRebuild {
        self.currentCues = cues
        self.fontSize = fontSize
        self.pinnedCueIds = pinnedIds
        buildAttributedString()
      }

      // Update dynamic styling only if current cue or playing range changed
      let wasCurrentCue = self.currentCue
      let wasPlayingRange = self.previousPlayingRange
      self.currentCue = currentCue
      self.playingRange = playingRange
      
      if currentCue != wasCurrentCue || playingRange != wasPlayingRange {
        updateDynamicStyling()
        self.previousCurrentCue = wasCurrentCue
        self.previousPlayingRange = wasPlayingRange
      }

      // Update text view when content or styling changed
      if let textView = textView {
        if needsRebuild || currentCue != wasCurrentCue || playingRange != wasPlayingRange {
          textView.attributedText = attributedString
        }
      }

      // Auto scroll to current cue
      if isFollowing,
        let currentCue = currentCue,
        currentCue != wasCurrentCue,
        let textView = textView,
        !textView.isDragging && !textView.isDecelerating
      {
        scrollToCue(currentCue, in: textView, animated: true)
      }
    }

    private func buildAttributedString() {
      attributedString = NSMutableAttributedString()
      cueRanges.removeAll()

      var currentLocation = 0

      for (index, cue) in currentCues.enumerated() {
        if cue.backed.kind == .separator {
          // Add custom separator view attachment
          let separatorAttachment = SeparatorAttachment()
          let separatorAttributedString = NSMutableAttributedString()
          
          // Add newline before separator (except for first item)
          if index != 0 {
            separatorAttributedString.append(NSAttributedString(string: "\n"))
          }
          
          // Add the attachment
          separatorAttributedString.append(NSAttributedString(attachment: separatorAttachment))
          
          // Add newline after separator
          separatorAttributedString.append(NSAttributedString(string: "\n"))

          let range = NSRange(
            location: currentLocation,
            length: separatorAttributedString.length
          )
          cueRanges.append(CueRange(cue: cue, range: range))

          attributedString.append(separatorAttributedString)
          currentLocation += separatorAttributedString.length

        } else {
          // Add text cue
          let text = cue.backed.text.trimmingCharacters(
            in: .whitespacesAndNewlines
          )
          let cueText = (index == 0 ? "" : " ") + text

          let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor.label,
            .paragraphStyle: defaultParagraphStyle(),
          ]

          let cueAttributedString = NSMutableAttributedString(
            string: cueText,
            attributes: baseAttributes
          )

          // Add mark indicator if pinned
          if pinnedCueIds.contains(cue.id) {
            let markIndicator = "📍 "
            let markAttributedString = NSAttributedString(
              string: markIndicator,
              attributes: [
                .font: UIFont.systemFont(ofSize: fontSize * 0.8),
                .foregroundColor: UIColor.systemBlue,
              ]
            )
            let insertionPoint = cueText.hasPrefix("\n\n") ? 2 : 0
            cueAttributedString.insert(markAttributedString, at: insertionPoint)
          }

          let range = NSRange(
            location: currentLocation,
            length: cueAttributedString.length
          )
          cueRanges.append(CueRange(cue: cue, range: range))

          // Store cue identifier as custom attribute for tap detection
          let textRange = NSRange(
            location: 0,
            length: cueAttributedString.length
          )
          cueAttributedString.addAttribute(
            NSAttributedString.Key("CueIdentifier"),
            value: cue.id,
            range: textRange
          )

          attributedString.append(cueAttributedString)
          currentLocation += cueAttributedString.length
        }
      }
    }

    private func updateDynamicStyling() {
      // Reset dynamic attributes
      let fullRange = NSRange(location: 0, length: attributedString.length)
      attributedString.removeAttribute(.backgroundColor, range: fullRange)
      
      // Track which cues need updates
      let changedCues = cueRanges.filter { cueRange in
        let cue = cueRange.cue
        let wasCurrentCue = (cue == previousCurrentCue)
        let isCurrentCue = (cue == currentCue)
        let wasInPlayingRange = previousPlayingRange?.contains(cue) ?? false
        let isInPlayingRange = playingRange?.contains(cue) ?? false
        
        return wasCurrentCue != isCurrentCue || wasInPlayingRange != isInPlayingRange
      }
      
      // Only update attributes for changed cues
      for cueRange in changedCues {
        let cue = cueRange.cue
        let range = cueRange.range

        // Skip separator styling
        if cue.backed.kind == .separator {
          continue
        }

        // Apply current cue highlighting
        if cue == currentCue {
          attributedString.addAttribute(
            .backgroundColor,
            value: UIColor.systemYellow.withAlphaComponent(0.3),
            range: range
          )
          // Make current cue text bold and normal opacity
          attributedString.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            range: range
          )
          attributedString.addAttribute(
            .foregroundColor,
            value: UIColor.label,
            range: range
          )
        } else {
          // Non-current cues are dimmed
          attributedString.addAttribute(
            .font,
            value: UIFont.systemFont(ofSize: fontSize, weight: .medium),
            range: range
          )
          attributedString.addAttribute(
            .foregroundColor,
            value: UIColor.secondaryLabel,
            range: range
          )
        }

        // Apply playing range highlighting (overlay on top of current highlighting)
        if let playingRange = playingRange, playingRange.contains(cue) {
          attributedString.addAttribute(
            .backgroundColor,
            value: UIColor.systemBlue.withAlphaComponent(0.2),
            range: range
          )
        }
      }
    }

    private func scrollToCue(
      _ cue: DisplayCue,
      in textView: UITextView,
      animated: Bool
    ) {
      guard let cueRange = cueRanges.first(where: { $0.cue == cue }) else {
        return
      }

      let range = cueRange.range
      guard range.location < textView.attributedText.length else {
        return
      }

      // Ensure we're on the main thread
      if Thread.isMainThread {
        performScrollToCue(range: range, in: textView, animated: animated)
      } else {
        DispatchQueue.main.async {
          self.performScrollToCue(range: range, in: textView, animated: animated)
        }
      }
    }
    
    private func performScrollToCue(range: NSRange, in textView: UITextView, animated: Bool) {
      // Get the bounding rect for the text range
      let rect = getBoundingRect(for: range, in: textView)
      
      // Calculate the visible area (accounting for insets)
      let visibleHeight = textView.bounds.height - textView.adjustedContentInset.top - textView.adjustedContentInset.bottom
      let centerY = visibleHeight / 2
      
      // Calculate target Y position to center the text
      let targetY = rect.midY - centerY
      
      // Clamp to valid scroll range
      let maxY = max(0, textView.contentSize.height - visibleHeight)
      let clampedY = max(-textView.adjustedContentInset.top, min(targetY, maxY))
      
      // Scroll to the position
      textView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: animated)
    }
    
    /// 適切なTextKitバージョンを選択して境界矩形を取得
    /// forcedTextKitVersionプロパティで特定のバージョンを強制可能
    /// - Parameters:
    ///   - range: 対象の範囲
    ///   - textView: 対象のUITextView
    /// - Returns: 境界矩形
    private func getBoundingRect(for range: NSRange, in textView: UITextView) -> CGRect {
      switch forcedTextKitVersion {
      case .automatic:
        // 自動選択: TextKit 2を優先、利用不可ならTextKit 1を使用
        if textView.textLayoutManager != nil {
          return textKit2_boundingRect(for: range, in: textView)
        } else {
          return textKit1_boundingRect(for: range, in: textView)
        }
        
      case .textKit1:
        // TextKit 1を強制使用
        return textKit1_boundingRect(for: range, in: textView)
        
      case .textKit2:
        // TextKit 2を強制使用（利用不可の場合はTextKit 1にフォールバック）
        if textView.textLayoutManager != nil {
          return textKit2_boundingRect(for: range, in: textView)
        } else {
          print("⚠️ TextKit 2 forced but not available, falling back to TextKit 1")
          return textKit1_boundingRect(for: range, in: textView)
        }
      }
    }

    // MARK: - Gesture Handlers

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
      guard let textView = gesture.view as? UITextView else { return }

      let location = gesture.location(in: textView)
      let characterIndex = textView.textKit2_characterIndex(for: location)

      if let cue = findCue(at: characterIndex) {
        handleCueTap(cue)

        // Disable following when user taps
        if isFollowingBinding.wrappedValue {
          isFollowingBinding.wrappedValue = false
        }
      }
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
      guard gesture.state == .began,
        let textView = gesture.view as? UITextView
      else { return }

      let location = gesture.location(in: textView)
      let characterIndex = textView.textKit2_characterIndex(for: location)

      if let cue = findCue(at: characterIndex) {
        handleCueLongPress(cue, at: location, in: textView)
      }
    }

    private func findCue(at characterIndex: Int) -> DisplayCue? {
      return cueRanges.first { cueRange in
        NSLocationInRange(characterIndex, cueRange.range)
      }?.cue
    }

    private func handleCueTap(_ cue: DisplayCue) {
      if cue.backed.kind == .separator {
        return  // Separators are not tappable for navigation
      }

      if controller.isRepeating {
        if var currentRange = playingRange {
          currentRange.select(cue: cue)
          controller.setRepeat(range: currentRange)
        }
      } else {
        controller.move(to: cue)
      }
    }

    private func handleCueLongPress(
      _ cue: DisplayCue,
      at point: CGPoint,
      in textView: UITextView
    ) {
      let alertController = UIAlertController(
        title: nil,
        message: nil,
        preferredStyle: .actionSheet
      )

      if cue.backed.kind == .separator {
        // Separator-specific actions
        alertController.addAction(
          UIAlertAction(title: "Delete Separator", style: .destructive) { _ in
            Task {
              await self.actionHandler(.onDeleteSeparator(cueId: cue.id))
            }
          }
        )
      } else {
        // Text cue actions
        alertController.addAction(
          UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = cue.backed.text
          }
        )

        // Mark actions
        if pinnedCueIds.contains(cue.id) {
          alertController.addAction(
            UIAlertAction(title: "Remove Mark", style: .default) { _ in
              // TODO: Handle remove mark
            }
          )
        } else {
          alertController.addAction(
            UIAlertAction(title: "Add Mark", style: .default) { _ in
              // TODO: Handle add mark
            }
          )
        }

        alertController.addAction(
          UIAlertAction(title: "Insert Separator Before", style: .default) {
            _ in
            Task {
              await self.actionHandler(.onInsertSeparator(beforeCueId: cue.id))
            }
          }
        )
      }

      alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

      // Present from the view controller
      if let viewController = textView.findViewController() {
        if let popover = alertController.popoverPresentationController {
          popover.sourceView = textView
          popover.sourceRect = CGRect(
            origin: point,
            size: CGSize(width: 1, height: 1)
          )
        }
        viewController.present(alertController, animated: true)
      }
    }

    // MARK: - UITextViewDelegate

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
      isUserScrolling = true
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
      if !decelerate {
        isUserScrolling = false
      }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      isUserScrolling = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      // Disable auto-following when user scrolls manually
      if scrollView.isTracking {
        Task { @MainActor in
          isFollowingBinding.wrappedValue = false
        }
      }
    }

    // MARK: - Helper methods
    
    // MARK: TextKit 1 Implementation (for comparison)
    
    /// TextKit 1版: NSLayoutManagerを使用した範囲の矩形計算
    /// - Parameters:
    ///   - range: 計算対象のNSRange
    ///   - textView: 対象のUITextView
    /// - Returns: テキスト範囲の境界矩形
    private func textKit1_boundingRect(for range: NSRange, in textView: UITextView) -> CGRect {
      let layoutManager = textView.layoutManager
      let textContainer = textView.textContainer
      
      // レイアウトを確実にする
      layoutManager.ensureLayout(forCharacterRange: range)
      
      // 文字範囲からグリフ範囲を取得
      let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
      
      // グリフ範囲の境界矩形を取得
      let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
      
      // テキストコンテナのインセットを加算
      return rect.offsetBy(
        dx: textView.textContainerInset.left,
        dy: textView.textContainerInset.top
      )
    }
    
    /// TextKit 1版: タップ位置から文字インデックスを取得
    /// - Parameters:
    ///   - point: タップ位置
    ///   - textView: 対象のUITextView
    /// - Returns: 文字インデックス
    private func textKit1_characterIndex(for point: CGPoint, in textView: UITextView) -> Int {
      let layoutManager = textView.layoutManager
      let textContainer = textView.textContainer
      
      // テキストコンテナ座標に変換
      let locationInTextContainer = CGPoint(
        x: point.x - textView.textContainerInset.left,
        y: point.y - textView.textContainerInset.top
      )
      
      // グリフインデックスを取得
      let glyphIndex = layoutManager.glyphIndex(
        for: locationInTextContainer,
        in: textContainer,
        fractionOfDistanceThroughGlyph: nil
      )
      
      // グリフインデックスから文字インデックスに変換
      let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
      
      return characterIndex
    }
    
    // MARK: TextKit 2 Implementation (current/improved)

    /// TextKit 2版: NSTextLayoutManagerを使用した範囲の矩形計算
    /// shadowfacts.netの記事を参考に実装
    /// - Parameters:
    ///   - range: 計算対象のNSRange
    ///   - textView: 対象のUITextView
    /// - Returns: テキスト範囲の境界矩形
    private func textKit2_boundingRect(for range: NSRange, in textView: UITextView) -> CGRect {
      guard let textLayoutManager = textView.textLayoutManager else {
        // Simple fallback calculation
        return CGRect(x: 0, y: CGFloat(range.location) * 20, width: textView.bounds.width, height: 20)
      }
      
      // Convert NSRange to document-relative locations
      guard let textContentManager = textLayoutManager.textContentManager else {
        return CGRect(x: 0, y: CGFloat(range.location) * 20, width: textView.bounds.width, height: 20)
      }
      
      // Calculate start and end locations
      let docStart = textContentManager.documentRange.location
      guard let startLocation = textContentManager.location(docStart, offsetBy: range.location),
            let endLocation = textContentManager.location(startLocation, offsetBy: range.length) else {
        return CGRect(x: 0, y: CGFloat(range.location) * 20, width: textView.bounds.width, height: 20)
      }
      
      // Create text range
      guard let textRange = NSTextRange(location: startLocation, end: endLocation) else {
        return CGRect(x: 0, y: CGFloat(range.location) * 20, width: textView.bounds.width, height: 20)
      }
      
      // Ensure layout for the range
      textLayoutManager.ensureLayout(for: textRange)
      
      // Enumerate text segments to find exact bounds
      var boundingRect = CGRect.zero
      var foundFirst = false
      
      textLayoutManager.enumerateTextSegments(
        in: textRange,
        type: .standard,
        options: [.rangeNotRequired]
      ) { textSegmentRange, textSegmentFrame, _, _ in
        if !foundFirst {
          boundingRect = textSegmentFrame
          foundFirst = true
        } else {
          boundingRect = boundingRect.union(textSegmentFrame)
        }
        return true  // Continue enumeration
      }
      
      // If we didn't find any segments, try fragment-based approach
      if boundingRect.isEmpty {
        textLayoutManager.enumerateTextLayoutFragments(
          from: startLocation,
          options: [.ensuresLayout]
        ) { layoutFragment in
          // Check if this fragment intersects our range
          if layoutFragment.rangeInElement.intersects(textRange) {
            if !foundFirst {
              boundingRect = layoutFragment.layoutFragmentFrame
              foundFirst = true
            } else {
              boundingRect = boundingRect.union(layoutFragment.layoutFragmentFrame)
            }
          }
          
          // Stop if we've passed our range
          let fragmentEnd = layoutFragment.rangeInElement.endLocation
          if textContentManager.offset(from: startLocation, to: fragmentEnd) >= range.length {
            return false  // Stop enumeration
          }
          
          return true  // Continue
        }
      }
      
      // Add text container inset to the rect
      return boundingRect.offsetBy(
        dx: textView.textContainerInset.left,
        dy: textView.textContainerInset.top
      )
    }

    private func defaultParagraphStyle() -> NSParagraphStyle {
      let style = NSMutableParagraphStyle()
      style.lineSpacing = 6
      style.paragraphSpacing = 12
      style.alignment = .left
      return style
    }

    private func centerParagraphStyle() -> NSParagraphStyle {
      let style = NSMutableParagraphStyle()
      style.alignment = .center
      style.paragraphSpacing = 8
      return style
    }
  }
}

// MARK: - UIKit Extensions

extension UIView {
  func findViewController() -> UIViewController? {
    var responder: UIResponder? = self
    while responder != nil {
      responder = responder?.next
      if let viewController = responder as? UIViewController {
        return viewController
      }
    }
    return nil
  }
}

extension UITextView {
  func textRange(from nsRange: NSRange) -> UITextRange? {
    guard let start = position(from: beginningOfDocument, offset: nsRange.location),
          let end = position(from: start, offset: nsRange.length) else {
      return nil
    }
    return textRange(from: start, to: end)
  }
  
  /// TextKit 2版: タップ位置から文字インデックスを取得
  /// shadowfacts.netの記事に基づく実装
  /// - Parameter point: タップ位置（UITextView座標系）
  /// - Returns: 文字インデックス
  func textKit2_characterIndex(for point: CGPoint) -> Int {
    // Use TextKit 2 API (iOS 18+)
    // Implementation based on: https://shadowfacts.net/2022/textkit-2/
    guard let textLayoutManager = textLayoutManager else {
      // TextKit 2 should always be available on iOS 18+
      return 0
    }
    
    // Convert point to text container coordinates
    let pointInContainer = CGPoint(
      x: point.x - textContainerInset.left,
      y: point.y - textContainerInset.top
    )
    
    // Get the text layout fragment at the point
    guard let fragment = textLayoutManager.textLayoutFragment(for: pointInContainer) else {
      return 0
    }
    
    // Convert to fragment coordinates
    let pointInFragment = CGPoint(
      x: pointInContainer.x - fragment.layoutFragmentFrame.minX,
      y: pointInContainer.y - fragment.layoutFragmentFrame.minY
    )
    
    // Find the line fragment containing the point
    guard let lineFragment = fragment.textLineFragments.first(where: { lineFragment in
      lineFragment.typographicBounds.contains(pointInFragment)
    }) else {
      return 0
    }
    
    // Convert to line fragment coordinates
    let pointInLine = CGPoint(
      x: pointInFragment.x - lineFragment.typographicBounds.minX,
      y: pointInFragment.y - lineFragment.typographicBounds.minY
    )
    
    // Get character index within the line fragment
    let charIndexInLine = lineFragment.characterIndex(for: pointInLine)
    
    // Convert to document-relative index
    let fragmentStart = textLayoutManager.offset(
      from: textLayoutManager.documentRange.location,
      to: fragment.rangeInElement.location
    )
    
    let absoluteIndex = charIndexInLine + fragmentStart
    return min(absoluteIndex, text.count - 1)
  }
}

// MARK: - Preview

#if DEBUG

  #Preview("PlayerTextView") {
    VStack {
      Text("UITextView版のプレビュー")
      Spacer()
    }
  }

#endif
