import Algorithms
import AppService
import SwiftUI
import SwiftUISupport
import UIKit

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
    let textView = UITextView()
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

//    let longPressGesture = UILongPressGestureRecognizer()
//    longPressGesture.addTarget(
//      context.coordinator,
//      action: #selector(Coordinator.handleLongPress(_:))
//    )
//    textView.addGestureRecognizer(longPressGesture)

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

    private struct CueRange {
      let cue: DisplayCue
      let range: NSRange
    }

    weak var textView: UITextView?
    private var cueRanges: [CueRange] = []
    private var attributedString = NSMutableAttributedString()

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
      
      self.currentCues = cues
      self.fontSize = fontSize
      self.pinnedCueIds = Set(pins.map(\.startCueRawIdentifier))
      
      buildAttributedString()
      
      self.textView?.attributedText = attributedString
      
      return;
      
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
          // Add separator
          let separatorText =
            index == 0 ? "━━━━━━━━━━━━━━━━━━━━\n" : "\n━━━━━━━━━━━━━━━━━━━━\n"
          let separatorAttributedString = NSAttributedString(
            string: separatorText,
            attributes: [
              .foregroundColor: UIColor.quaternaryLabel,
              .font: UIFont.systemFont(ofSize: fontSize * 0.7),
              .paragraphStyle: centerParagraphStyle(),
            ]
          )

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

      DispatchQueue.main.async {
        let range = cueRange.range
        if range.location < textView.text.count {
          // Get the rect for the text range using layout manager
          let glyphRange = textView.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
          let rect = textView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
          
          // Calculate the center position
          let visibleHeight = textView.bounds.height - textView.contentInset.top - textView.contentInset.bottom
          let centerY = visibleHeight / 2
          let targetY = rect.midY + textView.textContainerInset.top - centerY
          
          // Scroll to center the text
          let maxY = textView.contentSize.height - visibleHeight
          let clampedY = max(0, min(targetY, maxY))
          textView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: animated)
        }
      }
    }

    // MARK: - Gesture Handlers

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
      guard let textView = gesture.view as? UITextView else { return }

//      let location = gesture.location(in: textView)
//      let characterIndex = textView.characterIndex(for: location)
//
//      if let cue = findCue(at: characterIndex) {
//        handleCueTap(cue)
//
//        // Disable following when user taps
//        if isFollowingBinding.wrappedValue {
//          isFollowingBinding.wrappedValue = false
//        }
//      }
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
      guard gesture.state == .began,
        let textView = gesture.view as? UITextView
      else { return }

      let location = gesture.location(in: textView)
      let characterIndex = textView.characterIndex(for: location)

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
  func characterIndex(for point: CGPoint) -> Int {
    let adjustedPoint = CGPoint(
      x: point.x - textContainerInset.left,
      y: point.y - textContainerInset.top
    )

    let characterIndex = layoutManager.characterIndex(
      for: adjustedPoint,
      in: textContainer,
      fractionOfDistanceBetweenInsertionPoints: nil
    )

    return min(characterIndex, text.count - 1)
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
