#if os(macOS)
import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI

enum VariableBlurDirection: Hashable {
    case blurredTopClearBottom
    case blurredBottomClearTop
}

/// Progressive (variable) blur strip. Fakes the macOS scroll edge over a transparent titlebar so the
/// gallery toolbar can stay borderless while content blurs out as it passes under it.
///
/// Uses the private `CABackdropLayer` + `CAFilter(type: "variableBlur")` with a gradient alpha mask
/// (alpha 1 = max blur, alpha 0 = no blur). Class/selector names are obfuscated like upstream
/// `nikstar/VariableBlur` to avoid literal private-symbol references.
struct VariableBlurView: NSViewRepresentable {
    var maxBlurRadius: CGFloat = 18
    var direction: VariableBlurDirection = .blurredTopClearBottom
    var startOffset: CGFloat = 0

    func makeNSView(context: Context) -> VariableBlurNSView {
        VariableBlurNSView(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }

    func updateNSView(_ nsView: VariableBlurNSView, context: Context) {
        nsView.apply(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }
}

final class VariableBlurNSView: NSView {
    private struct AppliedConfiguration: Equatable {
        let maxBlurRadius: CGFloat
        let direction: VariableBlurDirection
        let startOffset: CGFloat
    }

    private struct GradientCacheKey: Hashable {
        let direction: VariableBlurDirection
        let startOffsetMillis: Int
    }

    private static let sharedCIContext = CIContext(options: [.useSoftwareRenderer: false])
    private static var gradientMaskCache: [GradientCacheKey: CGImage] = [:]

    private let backdropLayer: CALayer
    private var appliedConfiguration: AppliedConfiguration?

    init(maxBlurRadius: CGFloat, direction: VariableBlurDirection, startOffset: CGFloat) {
        if let backdropClass = NSClassFromString(["CA", "Backdrop", "Layer"].joined()) as? CALayer.Type {
            backdropLayer = backdropClass.init()
        } else {
            backdropLayer = CALayer()
        }
        super.init(frame: .zero)
        wantsLayer = true
        let host = CALayer()
        host.masksToBounds = true
        host.addSublayer(backdropLayer)
        layer = host
        apply(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdropLayer.frame = bounds
        CATransaction.commit()
    }

    func apply(maxBlurRadius: CGFloat, direction: VariableBlurDirection, startOffset: CGFloat) {
        let next = AppliedConfiguration(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        )
        guard appliedConfiguration != next else { return }
        guard let filter = Self.makeVariableBlurFilter(
            maxBlurRadius: maxBlurRadius,
            direction: direction,
            startOffset: startOffset
        ) else { return }
        appliedConfiguration = next
        backdropLayer.filters = [filter]
    }

    private static func makeVariableBlurFilter(
        maxBlurRadius: CGFloat,
        direction: VariableBlurDirection,
        startOffset: CGFloat
    ) -> NSObject? {
        let filterClassName = String("retliFAC".reversed()) // CAFilter
        guard let filterClass = NSClassFromString(filterClassName) as? NSObject.Type else { return nil }
        let selector = NSSelectorFromString(String(":epyThtiWretlif".reversed())) // filterWithType:
        guard let filter = filterClass.perform(selector, with: "variableBlur")?
            .takeUnretainedValue() as? NSObject
        else { return nil }
        let gradient = makeGradientImage(startOffset: startOffset, direction: direction)
        filter.setValue(maxBlurRadius, forKey: "inputRadius")
        filter.setValue(gradient, forKey: "inputMaskImage")
        filter.setValue(true, forKey: "inputNormalizeEdges")
        return filter
    }

    /// Vertical alpha gradient. `blurredTopClearBottom` is opaque (max blur) at the top of the view,
    /// clearing toward the bottom. Layer geometry is y-up, so "top" is the high-y end.
    private static func makeGradientImage(
        width: CGFloat = 100,
        height: CGFloat = 100,
        startOffset: CGFloat,
        direction: VariableBlurDirection
    ) -> CGImage? {
        let key = GradientCacheKey(
            direction: direction,
            startOffsetMillis: Int((startOffset * 1000).rounded())
        )
        if let cached = gradientMaskCache[key] {
            return cached
        }
        // Smoothstep falloff (not linear) so the blur tapers gradually with no hard edge.
        let gradient = CIFilter.smoothLinearGradient()
        gradient.color0 = CIColor.black
        gradient.color1 = CIColor.clear
        switch direction {
        case .blurredTopClearBottom:
            gradient.point0 = CGPoint(x: 0, y: height)
            gradient.point1 = CGPoint(x: 0, y: startOffset * height)
        case .blurredBottomClearTop:
            gradient.point0 = CGPoint(x: 0, y: 0)
            gradient.point1 = CGPoint(x: 0, y: height - startOffset * height)
        }
        guard let output = gradient.outputImage,
              let image = sharedCIContext.createCGImage(output, from: CGRect(x: 0, y: 0, width: width, height: height))
        else { return nil }
        gradientMaskCache[key] = image
        return image
    }
}
#endif
