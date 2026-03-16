import AppKit
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    private let inspector = ProfileSmithQuickLookInspector()

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let inspection = (try? inspector.inspect(url: request.fileURL)) ?? QuickLookInspection(
            fileURL: request.fileURL,
            fileKind: QuickLookFileKind(url: request.fileURL),
            title: request.fileURL.deletingPathExtension().lastPathComponent,
            bundleIdentifier: nil,
            appIDName: nil,
            teamName: nil,
            teamIdentifier: nil,
            profileType: nil,
            platform: nil,
            uuid: nil,
            creationDate: nil,
            expirationDate: nil,
            applicationIdentifier: nil,
            certificateCount: 0,
            deviceCount: 0,
            entitlements: [],
            infoPlist: nil,
            certificates: []
        )

        let reply = QLThumbnailReply(contextSize: request.maximumSize, drawing: { context in
            Self.drawThumbnail(in: context, size: request.maximumSize, inspection: inspection)
        })

        handler(reply, nil)
    }

    private static func drawThumbnail(in context: CGContext, size: CGSize, inspection: QuickLookInspection) -> Bool {
        let bounds = CGRect(origin: .zero, size: size)
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        NSColor.white.setFill()
        bounds.fill()

        let outerRect = bounds.insetBy(dx: max(8, size.width * 0.04), dy: max(8, size.height * 0.04))
        let cardPath = NSBezierPath(roundedRect: outerRect, xRadius: 24, yRadius: 24)
        inspection.fileKind.tintColor.setFill()
        cardPath.fill()

        let stripeRect = CGRect(x: outerRect.minX, y: outerRect.minY, width: outerRect.width, height: max(44, outerRect.height * 0.24))
        let stripePath = NSBezierPath(roundedRect: stripeRect, xRadius: 24, yRadius: 24)
        inspection.fileKind.accentColor.setFill()
        stripePath.fill()

        NSColor.white.setFill()
        CGRect(x: stripeRect.minX, y: stripeRect.midY, width: stripeRect.width, height: stripeRect.height / 2).fill()

        let badgeRect = CGRect(x: outerRect.minX + 20, y: outerRect.minY + 18, width: outerRect.width - 40, height: 24)
        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: min(15, size.width * 0.075), weight: .bold),
            .foregroundColor: NSColor.white,
            .kern: 1.2,
        ]
        NSString(string: inspection.fileKind.badgeText.uppercased()).draw(in: badgeRect, withAttributes: badgeAttributes)

        let titleRect = CGRect(
            x: outerRect.minX + 20,
            y: outerRect.minY + max(58, outerRect.height * 0.28),
            width: outerRect.width - 40,
            height: outerRect.height * 0.34
        )
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.lineBreakMode = .byTruncatingTail
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: min(28, size.width * 0.13), weight: .bold),
            .foregroundColor: NSColor(calibratedWhite: 0.11, alpha: 1),
            .paragraphStyle: titleStyle,
        ]
        NSString(string: inspection.title).draw(in: titleRect, withAttributes: titleAttributes)

        let lines = [
            inspection.bundleIdentifier,
            inspection.teamName,
            inspection.expirationDate.map { "到期 \(QuickLookFormatters.timestampString(from: $0))" },
        ].compactMap { $0 }.prefix(3)

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineBreakMode = .byTruncatingTail
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: min(16, size.width * 0.07), weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.34, alpha: 1),
            .paragraphStyle: bodyStyle,
        ]

        var currentY = titleRect.maxY + 12
        for line in lines {
            let rect = CGRect(x: outerRect.minX + 20, y: currentY, width: outerRect.width - 40, height: 20)
            NSString(string: line).draw(in: rect, withAttributes: bodyAttributes)
            currentY += 24
        }

        return true
    }
}
