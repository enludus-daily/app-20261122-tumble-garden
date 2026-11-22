import UIKit

/// 作物の絵（粘土細工のように、ころんとしたやわらかい陰影とつや）。端末の中で描く。
/// 画像は「直径 d の作物」を 1.45 倍の正方形に描く（葉やへたがはみ出す余白）。当たり判定の楕円は中心に同じ比で置く。
@MainActor
enum CropArt {
    static let canvasScale: CGFloat = 1.45
    private static var cache: [String: UIImage] = [:]

    static func image(_ crop: Crop, diameter: CGFloat) -> UIImage {
        let d = max(8, (diameter * 2).rounded() / 2)
        let key = "\(crop.key)@\(d)"
        if let img = cache[key] { return img }
        let side = d * canvasScale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let img = renderer.image { ctx in
            draw(crop, in: ctx.cgContext, side: side, diameter: d)
        }
        cache[key] = img
        return img
    }

    /// 楕円の半径（横・縦）。面積は同じ直径の円に近くする
    static func radii(_ info: CropInfo, diameter d: CGFloat) -> CGSize {
        let a = CGFloat(info.aspect)
        return CGSize(width: d / 2 * a.squareRoot(), height: d / 2 / a.squareRoot())
    }

    // MARK: -

    private static func draw(_ crop: Crop, in g: CGContext, side: CGFloat, diameter d: CGFloat) {
        let info = CropBook.info(crop)
        let r = radii(info, diameter: d)
        let c = CGPoint(x: side / 2, y: side / 2)
        let body = UIColor(hex: info.body)
        let shade = UIColor(hex: info.shade)
        let leaf = UIColor(hex: info.leaf)
        let rect = CGRect(x: c.x - r.width, y: c.y - r.height, width: r.width * 2, height: r.height * 2)
        let line = max(1, d * 0.035)

        switch info.shape {
        case .seed:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: c.x, y: rect.minY))
            p.addCurve(to: CGPoint(x: c.x, y: rect.maxY), controlPoint1: CGPoint(x: rect.maxX + r.width * 0.25, y: c.y - r.height * 0.1), controlPoint2: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addCurve(to: CGPoint(x: c.x, y: rect.minY), controlPoint1: CGPoint(x: rect.minX, y: rect.maxY), controlPoint2: CGPoint(x: rect.minX - r.width * 0.25, y: c.y - r.height * 0.1))
            clay(g, p, rect, body, shade)
            stroke(g, line: line * 0.8, color: shade.withAlphaComponent(0.6)) {
                $0.move(to: CGPoint(x: c.x, y: rect.minY + r.height * 0.35)); $0.addLine(to: CGPoint(x: c.x, y: rect.maxY - r.height * 0.25))
            }

        case .sprout:
            let husk = CGRect(x: c.x - r.width * 0.55, y: c.y + r.height * 0.15, width: r.width * 1.1, height: r.height * 0.85)
            clay(g, UIBezierPath(ovalIn: husk), husk, UIColor(hex: 0xC69863), UIColor(hex: 0x8E6439))
            stroke(g, line: line * 1.4, color: shade) {
                $0.move(to: CGPoint(x: c.x, y: husk.minY + 2)); $0.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r.height * 0.35), controlPoint: CGPoint(x: c.x + r.width * 0.12, y: c.y))
            }
            for s in [-1.0, 1.0] {
                let leafRect = CGRect(x: -r.width * 0.55, y: -r.height * 0.24, width: r.width * 1.1, height: r.height * 0.48)
                g.saveGState()
                g.translateBy(x: c.x + CGFloat(s) * r.width * 0.42, y: c.y - r.height * 0.5)
                g.rotate(by: CGFloat(s) * -0.5)
                clay(g, UIBezierPath(ovalIn: leafRect), leafRect, body, shade)
                g.restoreGState()
            }

        case .round:
            let name = info.en
            if name.contains("Turnip") || name == "Radish" {
                tallLeaves(g, c: CGPoint(x: c.x, y: rect.minY + r.height * 0.15), r: r, leaf: leaf, count: 3, length: r.height * 0.95)
                stroke(g, line: line, color: shade) {
                    $0.move(to: CGPoint(x: c.x, y: rect.maxY - 2)); $0.addQuadCurve(to: CGPoint(x: c.x + r.width * 0.12, y: rect.maxY + r.height * 0.3), controlPoint: CGPoint(x: c.x - r.width * 0.05, y: rect.maxY + r.height * 0.15))
                }
            }
            clay(g, UIBezierPath(ovalIn: rect), rect, body, shade)
            if name == "Watermelon" {
                g.saveGState()
                UIBezierPath(ovalIn: rect).addClip()
                for i in -2...2 {
                    let x = c.x + CGFloat(i) * r.width * 0.42
                    stroke(g, line: line * 2.2, color: UIColor(hex: 0x1F5A2A).withAlphaComponent(0.85)) {
                        $0.move(to: CGPoint(x: x, y: rect.minY))
                        var y = rect.minY
                        var k = 0
                        while y < rect.maxY {
                            y += r.height * 0.18
                            k += 1
                            $0.addLine(to: CGPoint(x: x + (k % 2 == 0 ? -1 : 1) * r.width * 0.06, y: y))
                        }
                    }
                }
                g.restoreGState()
                gloss(g, rect)
                curlStem(g, top: CGPoint(x: c.x, y: rect.minY), r: r, color: leaf, line: line)
            } else if name.contains("tomato") || name == "Persimmon" {
                star(g, center: CGPoint(x: c.x, y: rect.minY + r.height * 0.12), radius: r.width * (name == "Persimmon" ? 0.42 : 0.36), points: name == "Persimmon" ? 4 : 5, color: leaf)
            } else {
                // かぶ・ラディッシュ：根もとに白いすじ
                if name == "Radish" {
                    g.saveGState(); UIBezierPath(ovalIn: rect).addClip()
                    g.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
                    g.fillEllipse(in: CGRect(x: c.x - r.width * 0.5, y: c.y + r.height * 0.45, width: r.width, height: r.height * 0.8))
                    g.restoreGState()
                }
            }

        case .berry:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: c.x, y: rect.maxY))
            p.addCurve(to: CGPoint(x: rect.minX, y: c.y - r.height * 0.35), controlPoint1: CGPoint(x: c.x - r.width * 0.55, y: rect.maxY - r.height * 0.1), controlPoint2: CGPoint(x: rect.minX, y: c.y + r.height * 0.2))
            p.addCurve(to: CGPoint(x: rect.maxX, y: c.y - r.height * 0.35), controlPoint1: CGPoint(x: rect.minX + r.width * 0.1, y: rect.minY - r.height * 0.15), controlPoint2: CGPoint(x: rect.maxX - r.width * 0.1, y: rect.minY - r.height * 0.15))
            p.addCurve(to: CGPoint(x: c.x, y: rect.maxY), controlPoint1: CGPoint(x: rect.maxX, y: c.y + r.height * 0.2), controlPoint2: CGPoint(x: c.x + r.width * 0.55, y: rect.maxY - r.height * 0.1))
            clay(g, p, rect, body, shade)
            g.setFillColor(UIColor(hex: 0xFCE6A0).cgColor)
            for row in 0..<4 {
                for col in 0..<(4 - row) {
                    let x = c.x + (CGFloat(col) - CGFloat(3 - row) / 2) * r.width * 0.4
                    let y = c.y - r.height * 0.25 + CGFloat(row) * r.height * 0.32
                    g.fillEllipse(in: CGRect(x: x - d * 0.018, y: y - d * 0.028, width: d * 0.036, height: d * 0.056))
                }
            }
            star(g, center: CGPoint(x: c.x, y: rect.minY + r.height * 0.05), radius: r.width * 0.5, points: 5, color: leaf)

        case .pod:
            let path = UIBezierPath(roundedRect: rect, cornerRadius: r.height)
            if info.en == "Sweet potato" {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: rect.minX - r.width * 0.05, y: c.y))
                p.addCurve(to: CGPoint(x: rect.maxX + r.width * 0.05, y: c.y), controlPoint1: CGPoint(x: rect.minX + r.width * 0.3, y: rect.minY - r.height * 0.3), controlPoint2: CGPoint(x: rect.maxX - r.width * 0.3, y: rect.minY - r.height * 0.3))
                p.addCurve(to: CGPoint(x: rect.minX - r.width * 0.05, y: c.y), controlPoint1: CGPoint(x: rect.maxX - r.width * 0.3, y: rect.maxY + r.height * 0.3), controlPoint2: CGPoint(x: rect.minX + r.width * 0.3, y: rect.maxY + r.height * 0.3))
                clay(g, p, rect, body, shade)
                stroke(g, line: line * 0.8, color: shade.withAlphaComponent(0.7)) {
                    for k in [-0.3, 0.1, 0.45] {
                        $0.move(to: CGPoint(x: c.x + CGFloat(k) * r.width, y: c.y - r.height * 0.45))
                        $0.addQuadCurve(to: CGPoint(x: c.x + CGFloat(k) * r.width + r.width * 0.08, y: c.y + r.height * 0.45), controlPoint: CGPoint(x: c.x + CGFloat(k) * r.width + r.width * 0.12, y: c.y))
                    }
                }
            } else {
                clay(g, path, rect, body, shade)
                // 中の豆のふくらみ
                for k in [-0.5, 0.0, 0.5] {
                    let bump = CGRect(x: c.x + CGFloat(k) * r.width - r.height * 0.42, y: c.y - r.height * 0.5, width: r.height * 0.84, height: r.height * 0.84)
                    g.setFillColor(UIColor(hex: info.leaf).withAlphaComponent(0.45).cgColor)
                    g.fillEllipse(in: bump)
                }
                gloss(g, rect)
                stroke(g, line: line * 1.6, color: shade) {
                    $0.move(to: CGPoint(x: rect.minX + 2, y: c.y)); $0.addQuadCurve(to: CGPoint(x: rect.minX - r.width * 0.2, y: c.y - r.height * 0.6), controlPoint: CGPoint(x: rect.minX - r.width * 0.15, y: c.y))
                }
            }

        case .root:
            tallLeaves(g, c: CGPoint(x: c.x, y: rect.minY + r.height * 0.1), r: r, leaf: leaf, count: 4, length: r.height * 0.7)
            let p = UIBezierPath()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY + r.height * 0.25))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r.height * 0.25), controlPoint: CGPoint(x: c.x, y: rect.minY - r.height * 0.15))
            p.addCurve(to: CGPoint(x: c.x + r.width * 0.05, y: rect.maxY), controlPoint1: CGPoint(x: rect.maxX + r.width * 0.05, y: c.y + r.height * 0.2), controlPoint2: CGPoint(x: c.x + r.width * 0.35, y: rect.maxY - r.height * 0.1))
            p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + r.height * 0.25), controlPoint1: CGPoint(x: c.x - r.width * 0.3, y: rect.maxY - r.height * 0.1), controlPoint2: CGPoint(x: rect.minX - r.width * 0.05, y: c.y + r.height * 0.2))
            clay(g, p, rect, body, shade)
            stroke(g, line: line * 0.8, color: shade.withAlphaComponent(0.65)) {
                for k in stride(from: -0.2, through: 0.6, by: 0.26) {
                    let y = c.y + CGFloat(k) * r.height
                    let w = r.width * (0.7 - CGFloat(k) * 0.5) * 0.45
                    $0.move(to: CGPoint(x: c.x - w, y: y)); $0.addLine(to: CGPoint(x: c.x - w * 0.3, y: y + 1))
                    $0.move(to: CGPoint(x: c.x + w * 0.2, y: y + r.height * 0.12)); $0.addLine(to: CGPoint(x: c.x + w, y: y + r.height * 0.11))
                }
            }

        case .leafy:
            if info.en == "Broccoli" {
                let stem = CGRect(x: c.x - r.width * 0.28, y: c.y, width: r.width * 0.56, height: r.height)
                clay(g, UIBezierPath(roundedRect: stem, cornerRadius: r.width * 0.2), stem, UIColor(hex: 0x9ACB7A), UIColor(hex: 0x6A9E50))
                let florets: [(Double, Double, Double)] = [(-0.55, -0.05, 0.45), (0.55, -0.05, 0.45), (0, -0.45, 0.5), (-0.3, -0.55, 0.4), (0.32, -0.52, 0.42), (0, 0.05, 0.45)]
                for (x, y, s) in florets {
                    let fr = CGRect(x: c.x + CGFloat(x) * r.width - CGFloat(s) * r.width, y: c.y + CGFloat(y) * r.height - CGFloat(s) * r.height, width: CGFloat(s) * r.width * 2, height: CGFloat(s) * r.height * 2)
                    clay(g, UIBezierPath(ovalIn: fr), fr, body, shade)
                }
            } else if info.en == "Napa cabbage" {
                let p = UIBezierPath(roundedRect: rect, cornerRadius: r.width * 0.9)
                clay(g, p, rect, body, shade)
                let top = CGRect(x: rect.minX - r.width * 0.05, y: rect.minY - r.height * 0.05, width: rect.width + r.width * 0.1, height: r.height * 0.95)
                clay(g, frilly(top, bumps: 5), top, leaf, UIColor(hex: 0x5E9A44))
                stroke(g, line: line, color: UIColor.white.withAlphaComponent(0.8)) {
                    $0.move(to: CGPoint(x: c.x, y: rect.maxY - 3)); $0.addLine(to: CGPoint(x: c.x, y: rect.minY + r.height * 0.3))
                }
            } else {
                // キャベツ：外の葉と巻いた葉
                let outer = rect.insetBy(dx: -r.width * 0.08, dy: -r.height * 0.04)
                clay(g, frilly(outer, bumps: 7), outer, leaf.blend(body, 0.4), shade)
                let inner = rect.insetBy(dx: r.width * 0.18, dy: r.height * 0.18)
                clay(g, UIBezierPath(ovalIn: inner), inner, body.blend(.white, 0.25), shade)
                stroke(g, line: line, color: shade.withAlphaComponent(0.55)) {
                    $0.move(to: CGPoint(x: inner.minX + r.width * 0.1, y: c.y)); $0.addQuadCurve(to: CGPoint(x: inner.maxX - r.width * 0.05, y: inner.minY + r.height * 0.15), controlPoint: CGPoint(x: c.x, y: inner.minY - r.height * 0.05))
                    $0.move(to: CGPoint(x: c.x, y: rect.maxY - r.height * 0.05)); $0.addQuadCurve(to: CGPoint(x: c.x - r.width * 0.1, y: c.y), controlPoint: CGPoint(x: c.x + r.width * 0.12, y: c.y + r.height * 0.4))
                }
            }

        case .long:
            if info.en == "Corn" {
                for s in [-1.0, 1.0] {
                    let husk = UIBezierPath()
                    husk.move(to: CGPoint(x: c.x, y: rect.maxY + r.height * 0.05))
                    husk.addQuadCurve(to: CGPoint(x: c.x + CGFloat(s) * r.width * 0.55, y: rect.minY + r.height * 0.4), controlPoint: CGPoint(x: c.x + CGFloat(s) * r.width * 1.35, y: c.y + r.height * 0.4))
                    husk.addQuadCurve(to: CGPoint(x: c.x, y: rect.maxY + r.height * 0.05), controlPoint: CGPoint(x: c.x + CGFloat(s) * r.width * 0.4, y: c.y + r.height * 0.3))
                    g.setFillColor(leaf.cgColor); husk.fill()
                }
                clay(g, UIBezierPath(ovalIn: rect), rect, body, shade)
                g.saveGState(); UIBezierPath(ovalIn: rect).addClip()
                g.setFillColor(UIColor(hex: 0xFFE27A).cgColor)
                let kw = r.width * 0.36, kh = r.height * 0.15
                var y = rect.minY + kh * 0.3
                var row = 0
                while y < rect.maxY {
                    var x = rect.minX + (row % 2 == 0 ? 0 : kw / 2)
                    while x < rect.maxX {
                        g.fillEllipse(in: CGRect(x: x + 1, y: y + 1, width: kw - 2, height: kh - 2))
                        x += kw
                    }
                    y += kh
                    row += 1
                }
                g.restoreGState()
                gloss(g, rect)
                let lower = UIBezierPath()
                lower.move(to: CGPoint(x: c.x - r.width * 0.9, y: rect.maxY - r.height * 0.05))
                lower.addQuadCurve(to: CGPoint(x: c.x + r.width * 0.9, y: rect.maxY - r.height * 0.05), controlPoint: CGPoint(x: c.x, y: c.y + r.height * 0.1))
                lower.addQuadCurve(to: CGPoint(x: c.x - r.width * 0.9, y: rect.maxY - r.height * 0.05), controlPoint: CGPoint(x: c.x, y: rect.maxY + r.height * 0.15))
                g.setFillColor(leaf.cgColor); lower.fill()
            } else if info.en == "Leek" {
                let white = CGRect(x: rect.minX, y: c.y - r.height * 0.1, width: rect.width, height: r.height * 1.1)
                tallLeaves(g, c: CGPoint(x: c.x, y: c.y - r.height * 0.05), r: CGSize(width: r.width * 1.3, height: r.height), leaf: leaf, count: 3, length: r.height * 0.95)
                clay(g, UIBezierPath(roundedRect: white, cornerRadius: r.width), white, body, shade)
                stroke(g, line: line * 0.7, color: UIColor(hex: 0xC9B89A)) {
                    for k in -2...2 { $0.move(to: CGPoint(x: c.x, y: rect.maxY)); $0.addLine(to: CGPoint(x: c.x + CGFloat(k) * r.width * 0.25, y: rect.maxY + r.height * 0.18)) }
                }
            } else {
                // なす
                let p = UIBezierPath()
                p.move(to: CGPoint(x: c.x, y: rect.minY + r.height * 0.1))
                p.addCurve(to: CGPoint(x: c.x + r.width * 0.15, y: rect.maxY), controlPoint1: CGPoint(x: rect.maxX - r.width * 0.2, y: rect.minY + r.height * 0.1), controlPoint2: CGPoint(x: rect.maxX + r.width * 0.15, y: rect.maxY))
                p.addCurve(to: CGPoint(x: c.x, y: rect.minY + r.height * 0.1), controlPoint1: CGPoint(x: rect.minX - r.width * 0.25, y: rect.maxY + r.height * 0.05), controlPoint2: CGPoint(x: rect.minX + r.width * 0.2, y: rect.minY + r.height * 0.1))
                clay(g, p, rect, body, shade)
                star(g, center: CGPoint(x: c.x, y: rect.minY + r.height * 0.15), radius: r.width * 0.62, points: 5, color: leaf)
                stroke(g, line: line * 1.6, color: leaf) {
                    $0.move(to: CGPoint(x: c.x, y: rect.minY + r.height * 0.1)); $0.addLine(to: CGPoint(x: c.x + r.width * 0.05, y: rect.minY - r.height * 0.12))
                }
            }

        case .flat:
            clay(g, UIBezierPath(ovalIn: rect), rect, body, shade)
            stroke(g, line: line * 1.1, color: shade.withAlphaComponent(0.75)) {
                for k in [-0.55, -0.2, 0.2, 0.55] {
                    let x = c.x + CGFloat(k) * r.width
                    $0.move(to: CGPoint(x: x, y: rect.minY + r.height * 0.12))
                    $0.addQuadCurve(to: CGPoint(x: x, y: rect.maxY - r.height * 0.12), controlPoint: CGPoint(x: x + CGFloat(k) * r.width * 0.35, y: c.y))
                }
            }
            let stem = CGRect(x: c.x - r.width * 0.08, y: rect.minY - r.height * 0.22, width: r.width * 0.16, height: r.height * 0.35)
            clay(g, UIBezierPath(roundedRect: stem, cornerRadius: r.width * 0.05), stem, leaf, leaf.blend(.black, 0.3))
            if crop.tier == Crop.proTop {
                // 品評会のリボン
                ribbon(g, at: CGPoint(x: c.x + r.width * 0.55, y: c.y + r.height * 0.35), size: d * 0.22)
            }

        case .nut:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: c.x, y: rect.minY - r.height * 0.05))
            p.addCurve(to: CGPoint(x: rect.maxX, y: c.y + r.height * 0.35), controlPoint1: CGPoint(x: c.x + r.width * 0.45, y: rect.minY + r.height * 0.05), controlPoint2: CGPoint(x: rect.maxX, y: c.y - r.height * 0.1))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: c.y + r.height * 0.35), controlPoint: CGPoint(x: c.x, y: rect.maxY + r.height * 0.25))
            p.addCurve(to: CGPoint(x: c.x, y: rect.minY - r.height * 0.05), controlPoint1: CGPoint(x: rect.minX, y: c.y - r.height * 0.1), controlPoint2: CGPoint(x: c.x - r.width * 0.45, y: rect.minY + r.height * 0.05))
            clay(g, p, rect, body, shade)
            g.saveGState(); p.addClip()
            g.setFillColor(leaf.cgColor)
            g.fillEllipse(in: CGRect(x: rect.minX - r.width * 0.2, y: c.y + r.height * 0.42, width: rect.width + r.width * 0.4, height: r.height * 1.2))
            g.restoreGState()

        case .cap:
            let stem = CGRect(x: c.x - r.width * 0.3, y: c.y - r.height * 0.05, width: r.width * 0.6, height: r.height * 1.05)
            clay(g, UIBezierPath(roundedRect: stem, cornerRadius: r.width * 0.25), stem, leaf, UIColor(hex: 0xCDB892))
            let capRect = CGRect(x: rect.minX - r.width * 0.05, y: rect.minY, width: rect.width + r.width * 0.1, height: r.height * 1.15)
            let cap = UIBezierPath()
            cap.move(to: CGPoint(x: capRect.minX, y: capRect.maxY))
            cap.addCurve(to: CGPoint(x: capRect.maxX, y: capRect.maxY), controlPoint1: CGPoint(x: capRect.minX, y: capRect.minY - r.height * 0.3), controlPoint2: CGPoint(x: capRect.maxX, y: capRect.minY - r.height * 0.3))
            cap.addQuadCurve(to: CGPoint(x: capRect.minX, y: capRect.maxY), controlPoint: CGPoint(x: c.x, y: capRect.maxY - r.height * 0.18))
            clay(g, cap, capRect, body, shade)
            g.setFillColor(UIColor(hex: 0xF1E2C8).withAlphaComponent(0.8).cgColor)
            for (x, y) in [(-0.45, 0.25), (0.1, -0.2), (0.5, 0.15), (-0.1, 0.35)] {
                g.fillEllipse(in: CGRect(x: c.x + CGFloat(x) * r.width - d * 0.03, y: capRect.minY + r.height * CGFloat(0.5 + y) - d * 0.02, width: d * 0.06, height: d * 0.04))
            }

        case .bloom:
            let petal = UIColor(hex: info.body)
            for i in 0..<14 {
                g.saveGState()
                g.translateBy(x: c.x, y: c.y)
                g.rotate(by: CGFloat(i) / 14 * 2 * .pi)
                let pr = CGRect(x: -r.width * 0.16, y: -r.height * 1.0, width: r.width * 0.32, height: r.height * 0.6)
                clay(g, UIBezierPath(ovalIn: pr), pr, petal, shade)
                g.restoreGState()
            }
            let center = rect.insetBy(dx: r.width * 0.42, dy: r.height * 0.42)
            clay(g, UIBezierPath(ovalIn: center), center, leaf, leaf.blend(.black, 0.35))
            g.setFillColor(UIColor(hex: 0x4A2E18).cgColor)
            for i in 0..<12 {
                let a = CGFloat(i) * 2.4
                let rr = center.width * 0.38 * (CGFloat(i) / 12).squareRoot()
                g.fillEllipse(in: CGRect(x: c.x + cos(a) * rr - d * 0.015, y: c.y + sin(a) * rr - d * 0.015, width: d * 0.03, height: d * 0.03))
            }
            ribbon(g, at: CGPoint(x: c.x + r.width * 0.62, y: c.y + r.height * 0.55), size: d * 0.2)

        case .melon:
            clay(g, UIBezierPath(ovalIn: rect), rect, body, shade)
            g.saveGState(); UIBezierPath(ovalIn: rect).addClip()
            stroke(g, line: line * 0.9, color: leaf.withAlphaComponent(0.85)) {
                for k in stride(from: -1.2, through: 1.2, by: 0.3) {
                    $0.move(to: CGPoint(x: c.x + CGFloat(k) * r.width, y: rect.minY))
                    $0.addQuadCurve(to: CGPoint(x: c.x + CGFloat(k) * r.width + r.width * 0.3, y: rect.maxY), controlPoint: CGPoint(x: c.x + CGFloat(k) * r.width + r.width * 0.4, y: c.y))
                    $0.move(to: CGPoint(x: rect.minX, y: c.y + CGFloat(k) * r.height))
                    $0.addQuadCurve(to: CGPoint(x: rect.maxX, y: c.y + CGFloat(k) * r.height + r.height * 0.25), controlPoint: CGPoint(x: c.x, y: c.y + CGFloat(k) * r.height - r.height * 0.15))
                }
            }
            g.restoreGState()
            gloss(g, rect)
            stroke(g, line: line * 2, color: UIColor(hex: 0x6E8A3A)) {
                $0.move(to: CGPoint(x: c.x, y: rect.minY + 2)); $0.addLine(to: CGPoint(x: c.x, y: rect.minY - r.height * 0.18))
                $0.move(to: CGPoint(x: c.x - r.width * 0.18, y: rect.minY - r.height * 0.18)); $0.addLine(to: CGPoint(x: c.x + r.width * 0.18, y: rect.minY - r.height * 0.18))
            }
            ribbon(g, at: CGPoint(x: c.x + r.width * 0.6, y: c.y + r.height * 0.5), size: d * 0.2)
        }
        if crop.tier == Crop.proTop, info.shape == .round {
            ribbon(g, at: CGPoint(x: c.x + r.width * 0.6, y: c.y + r.height * 0.5), size: d * 0.2)
        }
    }

    // MARK: 描く道具

    /// 粘土の陰影：地の色 → 下に影の色 → 左上に光 → 小さなつや
    private static func clay(_ g: CGContext, _ path: UIBezierPath, _ rect: CGRect, _ body: UIColor, _ shade: UIColor) {
        g.saveGState()
        // 下の接地の影（ほんの少し）
        g.setFillColor(UIColor.black.withAlphaComponent(0.10).cgColor)
        let foot = path.copy() as? UIBezierPath ?? path
        foot.apply(CGAffineTransform(translationX: 0, y: max(1, rect.height * 0.04)))
        foot.fill()
        path.addClip()
        g.setFillColor(body.cgColor)
        g.fill(rect.insetBy(dx: -rect.width, dy: -rect.height))
        let space = CGColorSpaceCreateDeviceRGB()
        if let grad = CGGradient(colorsSpace: space, colors: [shade.withAlphaComponent(0).cgColor, shade.withAlphaComponent(0.75).cgColor] as CFArray, locations: [0.35, 1]) {
            g.drawLinearGradient(grad, start: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY + rect.height * 0.1), options: [.drawsAfterEndLocation])
        }
        if let light = CGGradient(colorsSpace: space, colors: [UIColor.white.withAlphaComponent(0.42).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
            let p = CGPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.28)
            g.drawRadialGradient(light, startCenter: p, startRadius: 0, endCenter: p, endRadius: max(rect.width, rect.height) * 0.55, options: [])
        }
        g.restoreGState()
        gloss(g, rect)
    }

    private static func gloss(_ g: CGContext, _ rect: CGRect) {
        g.setFillColor(UIColor.white.withAlphaComponent(0.6).cgColor)
        let w = max(2, rect.width * 0.16), h = max(1.5, rect.height * 0.09)
        g.saveGState()
        g.translateBy(x: rect.minX + rect.width * 0.3, y: rect.minY + rect.height * 0.22)
        g.rotate(by: -0.6)
        g.fillEllipse(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        g.restoreGState()
    }

    private static func stroke(_ g: CGContext, line: CGFloat, color: UIColor, _ build: (UIBezierPath) -> Void) {
        let p = UIBezierPath()
        build(p)
        p.lineWidth = line
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        color.setStroke()
        p.stroke()
    }

    private static func tallLeaves(_ g: CGContext, c: CGPoint, r: CGSize, leaf: UIColor, count: Int, length: CGFloat) {
        for i in 0..<count {
            let t = count == 1 ? 0 : CGFloat(i) / CGFloat(count - 1) - 0.5
            g.saveGState()
            g.translateBy(x: c.x + t * r.width * 0.4, y: c.y)
            g.rotate(by: t * 1.1)
            let lr = CGRect(x: -r.width * 0.17, y: -length, width: r.width * 0.34, height: length)
            clay(g, UIBezierPath(ovalIn: lr), lr, leaf, leaf.blend(.black, 0.3))
            g.restoreGState()
        }
    }

    private static func star(_ g: CGContext, center: CGPoint, radius: CGFloat, points: Int, color: UIColor) {
        let p = UIBezierPath()
        for i in 0..<(points * 2) {
            let a = CGFloat(i) / CGFloat(points * 2) * 2 * .pi - .pi / 2
            let rr = i % 2 == 0 ? radius : radius * 0.35
            let pt = CGPoint(x: center.x + cos(a) * rr, y: center.y + sin(a) * rr * 0.55)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.close()
        color.setFill()
        p.fill()
        UIColor.black.withAlphaComponent(0.15).setStroke()
        p.lineWidth = 0.8
        p.stroke()
    }

    private static func curlStem(_ g: CGContext, top: CGPoint, r: CGSize, color: UIColor, line: CGFloat) {
        stroke(g, line: line * 1.5, color: color.blend(.black, 0.25)) {
            $0.move(to: CGPoint(x: top.x, y: top.y + 2))
            $0.addCurve(to: CGPoint(x: top.x + r.width * 0.25, y: top.y - r.height * 0.2), controlPoint1: CGPoint(x: top.x, y: top.y - r.height * 0.2), controlPoint2: CGPoint(x: top.x + r.width * 0.35, y: top.y))
        }
    }

    /// ふちが波打つ形（葉）
    private static func frilly(_ rect: CGRect, bumps: Int) -> UIBezierPath {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let p = UIBezierPath()
        let n = bumps * 2
        for i in 0...n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let k: CGFloat = i % 2 == 0 ? 1 : 0.9
            let pt = CGPoint(x: c.x + cos(a) * rect.width / 2 * k, y: c.y + sin(a) * rect.height / 2 * k)
            if i == 0 { p.move(to: pt) } else {
                let am = (CGFloat(i) - 0.5) / CGFloat(n) * 2 * .pi
                let cp = CGPoint(x: c.x + cos(am) * rect.width / 2 * 1.06, y: c.y + sin(am) * rect.height / 2 * 1.06)
                p.addQuadCurve(to: pt, controlPoint: cp)
            }
        }
        p.close()
        return p
    }

    /// 品評会のリボン（Pro の 8 段目の印）
    private static func ribbon(_ g: CGContext, at p: CGPoint, size s: CGFloat) {
        let blue = UIColor(hex: 0x3B6FD8)
        for k in [-1.0, 1.0] {
            let tail = UIBezierPath()
            tail.move(to: p)
            tail.addLine(to: CGPoint(x: p.x + CGFloat(k) * s * 0.35, y: p.y + s * 0.9))
            tail.addLine(to: CGPoint(x: p.x + CGFloat(k) * s * 0.05, y: p.y + s * 0.75))
            tail.close()
            blue.blend(.black, 0.2).setFill(); tail.fill()
        }
        let disc = CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)
        g.setFillColor(blue.cgColor); g.fillEllipse(in: disc)
        g.setFillColor(UIColor(hex: 0xF6D04D).cgColor); g.fillEllipse(in: disc.insetBy(dx: s * 0.22, dy: s * 0.22))
    }
}

extension UIColor {
    func blend(_ other: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1)
    }
}
