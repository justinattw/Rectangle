/// OverlapOffsetGeometry

import Foundation

/// Geometry handling for the overlap offset: where a window lands when it arrives
/// on a position other windows already occupy.
enum OverlapOffsetGeometry {

    /// Bounds how long a hung app can stall the overlap scan's accessibility calls.
    /// Matches the badge's timeout for the same reason.
    static let axScanTimeout: Float = 0.25

    /// AppKit coordinates: positive Y goes up. Keep-size stacks use only the
    /// available screen span; fit stacks reserve the whole span inside the snap area.
    static func stackFrames(base: CGRect, count: Int, offset: CGVector,
                            screenFrame: CGRect, fit: Bool) -> [CGRect]? {
        guard count > 0, count < 10_000 else { return nil }
        return stackFrames(bases: Array(repeating: base, count: count), offset: offset,
                           screenFrame: screenFrame, fit: fit)
    }

    static func stackFrames(bases: [CGRect], offset: CGVector,
                            screenFrame: CGRect, fit: Bool) -> [CGRect]? {
        guard !bases.isEmpty, bases.count < 10_000,
              bases.allSatisfy({ !$0.isEmpty && !$0.isNull }),
              offset.dx.isFinite, offset.dy.isFinite else { return nil }
        let layers = CGFloat(bases.count - 1)
        var step = offset
        if !fit, layers > 0 {
            let bounds = bases.reduce(CGRect.null) { $0.union($1) }
            step.dx = copysign(min(abs(step.dx), max(0, screenFrame.width - bounds.width) / layers), step.dx)
            step.dy = copysign(min(abs(step.dy), max(0, screenFrame.height - bounds.height) / layers), step.dy)
        }
        let span = CGVector(dx: step.dx * layers, dy: step.dy * layers)
        var frames: [CGRect] = []
        for (index, base) in bases.enumerated() {
            let width = base.width - (fit ? abs(span.dx) : 0)
            let height = base.height - (fit ? abs(span.dy) : 0)
            guard width >= 1, height >= 1 else { return nil }
            frames.append(CGRect(x: base.minX + CGFloat(index) * step.dx - (fit ? min(0, span.dx) : 0),
                                 y: base.minY + CGFloat(index) * step.dy - (fit ? min(0, span.dy) : 0),
                                 width: width, height: height))
        }
        guard !fit else { return frames }
        let group = frames.reduce(CGRect.null) { $0.union($1) }
        let dx = min(max(group.minX, screenFrame.minX), max(screenFrame.minX, screenFrame.maxX - group.width)) - group.minX
        let dy = min(max(group.minY, screenFrame.minY), max(screenFrame.minY, screenFrame.maxY - group.height)) - group.minY
        return frames.map { $0.offsetBy(dx: dx, dy: dy) }
    }

    static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        !lhs.isNull && !rhs.isNull
            && abs(lhs.minX - rhs.minX) <= 2 && abs(lhs.minY - rhs.minY) <= 2
            && abs(lhs.width - rhs.width) <= 2 && abs(lhs.height - rhs.height) <= 2
    }

    static func sameStackArea(_ lhs: CGRect, _ rhs: CGRect, in screenFrame: CGRect, sameSizeOnly: Bool) -> Bool {
        if approximatelyEqual(lhs, rhs) { return true }
        guard !sameSizeOnly, !lhs.isEmpty, !rhs.isEmpty,
              abs(lhs.minY - rhs.minY) <= 2, abs(lhs.height - rhs.height) <= 2 else { return false }
        let leftAligned = lhs.midX < screenFrame.midX - 2 && rhs.midX < screenFrame.midX - 2
            && abs(lhs.minX - rhs.minX) <= 2
        let rightAligned = lhs.midX > screenFrame.midX + 2 && rhs.midX > screenFrame.midX + 2
            && abs(lhs.maxX - rhs.maxX) <= 2
        return leftAligned || rightAligned
    }

    struct StackPlacementRecord {
        let base: CGRect
        let groupBase: CGRect
        let frame: CGRect
        let order: Int

        init(base: CGRect, groupBase: CGRect? = nil, frame: CGRect, order: Int) {
            self.base = base
            self.groupBase = groupBase ?? base
            self.frame = frame
            self.order = order
        }
    }

    /// Plans without changing other windows. Commit only after the arriving window
    /// accepts its size, so a refused resize cannot leave the older layers rearranged.
    struct WindowStackPlacement {
        struct Member {
            let id: CGWindowID
            let element: AccessibilityElement
            let before: CGRect
            let target: CGRect
            let base: CGRect
        }

        let base: CGRect
        let groupBase: CGRect
        let windowID: CGWindowID
        let element: AccessibilityElement
        let target: CGRect
        let members: [Member]

        static func plan(base: CGRect, windowID: CGWindowID?, element: AccessibilityElement,
                         screen: NSScreen, history: WindowHistory, animator: WindowAnimator,
                         windowElements: (() -> [AccessibilityElement]) = { AccessibilityElement.getAllWindowElements() }) -> Self? {
            let offset = Defaults.overlapOffset
            guard let windowID, offset.dx != 0 || offset.dy != 0 else { return nil }
            let screenFrame = screen.adjustedVisibleFrame()
            let sameSizeOnly = Defaults.stackSameSizeOnly.userEnabled
            let footprints = Set(NSApp.windows.compactMap { $0 is FootprintWindow ? CGWindowID($0.windowNumber) : nil })
            var candidates: [(id: CGWindowID, element: AccessibilityElement, frame: CGRect,
                              order: Int, base: CGRect, groupBase: CGRect)] = []
            for other in windowElements() {
                AXUIElementSetMessagingTimeout(other.axElement, OverlapOffsetGeometry.axScanTimeout)
                defer { AXUIElementSetMessagingTimeout(other.axElement, 0) }
                guard let id = other.getWindowId(), id != windowID, !footprints.contains(id),
                      other.isWindow == true, other.isMinimized != true,
                      other.isHidden != true, other.isSheet != true else { continue }
                let frame = animator.destination(for: other) ?? other.frame
                let record = history.stackPlacements[id]
                if let record, !OverlapOffsetGeometry.approximatelyEqual(record.frame, frame) {
                    history.stackPlacements.removeValue(forKey: id)
                }
                if let record = history.stackPlacements[id],
                   OverlapOffsetGeometry.sameStackArea(record.base, base, in: screenFrame, sameSizeOnly: sameSizeOnly) {
                    candidates.append((id, other, frame, record.order, record.base, record.groupBase))
                } else if history.stackPlacements[id] == nil,
                          OverlapOffsetGeometry.sameStackArea(frame.screenFlipped, base, in: screenFrame, sameSizeOnly: sameSizeOnly) {
                    candidates.append((id, other, frame, -1, frame.screenFlipped, frame.screenFlipped))
                }
            }
            candidates.sort { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
            guard let frames = OverlapOffsetGeometry.stackFrames(bases: candidates.map(\.base) + [base],
                                                                 offset: offset, screenFrame: screenFrame,
                                                                 fit: Defaults.stackFitToSnapArea.enabled) else {
                Logger.log("Stack cannot fit in its snap area with the requested offsets")
                NSSound.beep()
                return nil
            }
            var members: [Member] = []
            for (index, candidate) in candidates.enumerated() {
                let target = frames[index].screenFlipped
                guard acceptsSize(target.size, element: candidate.element, current: candidate.frame) else {
                    Logger.log("Stack layout exceeds a member's window size restrictions")
                    NSSound.beep()
                    return nil
                }
                members.append(Member(id: candidate.id, element: candidate.element, before: candidate.frame,
                                      target: target, base: candidate.base))
            }
            let target = frames[candidates.count].screenFlipped
            guard acceptsSize(target.size, element: element, current: element.frame) else {
                Logger.log("Stack layout exceeds the arriving window's size restrictions")
                NSSound.beep()
                return nil
            }
            return Self(base: base, groupBase: candidates.first?.groupBase ?? base,
                        windowID: windowID, element: element, target: target, members: members)
        }

        private static func acceptsSize(_ size: CGSize, element: AccessibilityElement, current: CGRect) -> Bool {
            if !element.isResizable(), size != current.size { return false }
            let minimum = element.minimumSize ?? .zero
            return size.width >= minimum.width && size.height >= minimum.height
        }

        func commit(actualFrame: CGRect, history: WindowHistory, animator: WindowAnimator) {
            guard OverlapOffsetGeometry.approximatelyEqual(actualFrame, target) else {
                history.stackPlacements.removeValue(forKey: windowID)
                Logger.log("Stack was not rearranged because the arriving window refused its frame")
                return
            }
            for member in members { animator.cancel(for: member.element) }
            animator.afterPendingWrites {
                guard OverlapOffsetGeometry.approximatelyEqual(element.frame, actualFrame),
                      animator.destination(for: element) == nil else {
                    Logger.log("Stack layout cancelled because the arriving window moved again")
                    return
                }
                for member in members {
                    guard OverlapOffsetGeometry.approximatelyEqual(member.element.frame, member.before) else {
                        Logger.log("Stack layout cancelled because a member moved externally")
                        return
                    }
                }
                var moved: [Member] = []
                for member in members {
                    if history.restoreRects[member.id] == nil { history.restoreRects[member.id] = member.before }
                    member.element.setFrame(member.target)
                    moved.append(member)
                    guard OverlapOffsetGeometry.approximatelyEqual(member.element.frame, member.target) else {
                        Logger.log("Stack member refused its frame; restoring the previous layer positions")
                        for previous in moved {
                            previous.element.setFrame(previous.before)
                            history.stackPlacements.removeValue(forKey: previous.id)
                        }
                        NSSound.beep()
                        return
                    }
                }
                for (index, member) in members.enumerated() {
                    history.stackPlacements[member.id] = StackPlacementRecord(base: member.base, groupBase: groupBase,
                                                                             frame: member.target, order: index)
                    if let previous = history.lastRectangleActions[member.id] {
                        history.lastRectangleActions[member.id] = RectangleAction(action: previous.action,
                            subAction: previous.subAction, rect: member.target, count: previous.count)
                    }
                }
                history.stackPlacements[windowID] = StackPlacementRecord(base: base, groupBase: groupBase,
                                                                        frame: actualFrame, order: members.count)
            }
        }
    }

    /// Windows are matched by their top-left corner, so that a small window
    /// landing on a larger one at the same corner still counts as an overlap.
    static func topLeft(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX, y: rect.maxY)
    }

    /// Whether a frame is large enough to count as covering the screen.
    static func coversScreen(_ rect: CGRect, screenFrame: CGRect) -> Bool {
        rect.width > screenFrame.width * 0.9 && rect.height > screenFrame.height * 0.9
    }

    /// How far the window can shift on each axis without crossing the far
    /// edge of the visible frame. Zero on an axis that has no room: shifting
    /// there anyway would push the window flush against that edge, which both
    /// hides the window underneath again and eats any gap on that side.
    static func offsetStep(for rect: CGRect, in screenFrame: CGRect, by offset: CGFloat) -> CGVector {
        offsetStep(for: rect, in: screenFrame, by: CGVector(dx: offset, dy: offset))
    }

    static func offsetStep(for rect: CGRect, in screenFrame: CGRect, by offset: CGVector) -> CGVector {
        CGVector(dx: offset.dx > 0 && rect.maxX + offset.dx <= screenFrame.maxX ? offset.dx : 0,
                 dy: offset.dy > 0 && rect.maxY + offset.dy <= screenFrame.maxY ? offset.dy : 0)
    }

    /// Whether the window has room to shift at all. A window sized to the
    /// whole visible frame (a maximized window with no gaps) does not, so the
    /// caller can skip scanning for overlaps entirely.
    static func canOffset(_ rect: CGRect, in screenFrame: CGRect, by offset: CGFloat) -> Bool {
        let step = offsetStep(for: rect, in: screenFrame, by: offset)
        return step.dx != 0 || step.dy != 0
    }

    static func canOffset(_ rect: CGRect, in screenFrame: CGRect, by offset: CGVector) -> Bool {
        let step = offsetStep(for: rect, in: screenFrame, by: offset)
        return step.dx != 0 || step.dy != 0
    }

    /// The rect to place, shifted clear of any window already at its top-left
    /// corner, up to `maxCascade` times. Returns the rect unchanged when it
    /// overlaps nothing or has nowhere left to go.
    static func cascadedRect(_ rect: CGRect,
                             occupiedTopLefts: [CGPoint],
                             screenFrame: CGRect,
                             offset: CGFloat,
                             maxCascade: Int,
                             tolerance: CGFloat = 4) -> CGRect {
        cascadedRect(rect, occupiedTopLefts: occupiedTopLefts, screenFrame: screenFrame,
                     offset: CGVector(dx: offset, dy: offset), maxCascade: maxCascade, tolerance: tolerance)
    }

    static func cascadedRect(_ rect: CGRect,
                             occupiedTopLefts: [CGPoint],
                             screenFrame: CGRect,
                             offset: CGVector,
                             maxCascade: Int,
                             tolerance: CGFloat = 4) -> CGRect {
        guard offset.dx > 0 || offset.dy > 0 else { return rect }
        var candidate = rect
        for _ in 0..<max(0, maxCascade) {
            let corner = topLeft(of: candidate)
            let overlaps = occupiedTopLefts.contains { occupied in
                abs(occupied.x - corner.x) < tolerance && abs(occupied.y - corner.y) < tolerance
            }
            guard overlaps else { break }

            let step = offsetStep(for: candidate, in: screenFrame, by: offset)
            guard step.dx != 0 || step.dy != 0 else { break }
            candidate.origin.x += step.dx
            candidate.origin.y += step.dy
        }
        return candidate
    }
    
}
