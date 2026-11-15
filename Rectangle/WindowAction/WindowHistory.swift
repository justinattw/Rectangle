/// WindowHistory.swift

import Foundation

class WindowHistory {
    var stackPlacements = [CGWindowID: OverlapOffsetGeometry.StackPlacementRecord]()

    private func pruneStackPlacements(frames: [CGWindowID: CGRect]) {
        stackPlacements = stackPlacements.filter { id, record in
            frames[id].map { OverlapOffsetGeometry.approximatelyEqual($0, record.frame) } ?? false
        }
    }

    func stackMembers(for windowID: CGWindowID, frames: [CGWindowID: CGRect], sameSizeOnly: Bool) -> Set<CGWindowID>? {
        pruneStackPlacements(frames: frames)
        guard let anchor = stackPlacements[windowID] else { return nil }
        return Set(stackPlacements.compactMap { id, record in
            guard OverlapOffsetGeometry.approximatelyEqual(record.groupBase, anchor.groupBase),
                  !sameSizeOnly || StackBadgeGeometry.isSameSize(record.frame, as: anchor.frame) else { return nil }
            return id
        })
    }

    func stackSpan(near origin: CGPoint, frames: [CGWindowID: CGRect], tolerance: CGFloat = 4) -> CGVector {
        pruneStackPlacements(frames: frames)
        guard let anchor = stackPlacements.values.first(where: {
            abs($0.frame.minX - origin.x) <= tolerance && abs($0.frame.minY - origin.y) <= tolerance
        }) else { return .zero }
        let members = stackPlacements.values.filter {
            OverlapOffsetGeometry.approximatelyEqual($0.groupBase, anchor.groupBase)
        }.map { record in
            CGPoint(x: record.frame.minX - record.base.screenFlipped.minX,
                    y: record.frame.minY - record.base.screenFlipped.minY)
        }
        return CGVector(dx: (members.map(\.x).max() ?? 0) - (members.map(\.x).min() ?? 0),
                        dy: (members.map(\.y).max() ?? 0) - (members.map(\.y).min() ?? 0))
    }
    
    var restoreRects = [CGWindowID: CGRect]() // the last window frame that the user positioned
    
    var lastRectangleActions = [CGWindowID: RectangleAction]() // the last window frame that this app positioned
    
    var preMaximizeRects = [CGWindowID: CGRect]() // the normalized window frame right before this app last maximized / almost maximized it

    func recordAction(windowId: CGWindowID?,
                      resultingRect: CGRect,
                      action: WindowAction,
                      subAction: SubWindowAction?,
                      incrementCount: Bool = true) {
        guard let windowId else { return }
        let newCount: Int
        if let lastRectangleAction = lastRectangleActions[windowId],
           lastRectangleAction.action == action {
            newCount = incrementCount ? lastRectangleAction.count + 1 : lastRectangleAction.count
        } else {
            newCount = 1
        }

        lastRectangleActions[windowId] = RectangleAction(
            action: action,
            subAction: subAction,
            rect: resultingRect,
            count: newCount
        )
    }
}
