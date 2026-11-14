/// MoveLeftRightCalculation.swift

import Cocoa

class MoveByStepCalculation: WindowCalculation {
    override func calculateRect(_ params: RectCalculationParameters) -> RectResult {
        var rect = params.window.rect
        let step = CGFloat(max(1, Defaults.widthStepSize.value))

        switch params.action {
        case .moveLeft:
            rect.origin.x -= step
        case .moveRight:
            rect.origin.x += step
        case .moveUp:
            rect.origin.y += step
        case .moveDown:
            rect.origin.y -= step
        default:
            break
        }

        let visibleFrame = params.visibleFrameOfScreen
        let minimumX = visibleFrame.minX
        let minimumY = visibleFrame.minY
        let maximumX = max(minimumX, visibleFrame.maxX - rect.width)
        let maximumY = max(minimumY, visibleFrame.maxY - rect.height)
        rect.origin.x = min(max(rect.origin.x, minimumX), maximumX)
        rect.origin.y = min(max(rect.origin.y, minimumY), maximumY)

        return RectResult(rect)
    }
}

class MoveLeftRightCalculation: MoveByStepCalculation {}

