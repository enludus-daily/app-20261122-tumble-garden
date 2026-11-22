import SpriteKit
import UIKit

/// 箱の中の作物（SpriteKit の物理で落ちて、積もって、触れると合体する）
final class CropNode: SKSpriteNode {
    var crop: Crop = Crop(season: .spring, tier: 0)
    var merging = false
    var born: TimeInterval = 0
    var overSince: TimeInterval?
    var halfHeight: CGFloat = 0
}

/// 育て箱の中身（土の上の空間）。決まり（Farm）は AppModel が持ち、ここは物理と動きだけ。
/// 指でなぞって落とす所を決め、離すと落とす。出荷できる作物は長押し（0.45 秒）で出荷箱へ。
@MainActor
final class FarmScene: SKScene {
    weak var model: AppModel?

    /// 落とす所（箱の幅に対する割合）
    private(set) var aim: Double = 0.5
    private var ghost = SKSpriteNode()
    private var guide = SKShapeNode()
    private var line = SKShapeNode()
    private var windMarks = SKNode()
    private var cropsLayer = SKNode()
    private var fxLayer = SKNode()
    private var lastDrop: TimeInterval = -10
    private var now: TimeInterval = 0
    private var dangerShown = false
    private var built = false

    // 長押しの出荷
    private var holdNode: CropNode?
    private var holdStart: TimeInterval = 0
    private var holdRing = SKShapeNode()
    private var touchStart: CGPoint = .zero
    private var aiming = false

    static let lineRatio: CGFloat = 0.84
    static let spawnRatio: CGFloat = 0.93
    static let holdSeconds: TimeInterval = 0.45
    static let overflowSeconds: TimeInterval = 2.0

    var lineY: CGFloat { size.height * FarmScene.lineRatio }
    var canDrop: Bool { now - lastDrop > 0.42 }
    var crops: [CropNode] { cropsLayer.children.compactMap { $0 as? CropNode } }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = .zero
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.speed = 1
    }

    required init?(coder aDecoder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        if !built {
            // 起動の前に読み込んだ途中の畑（まだ箱の外にある）を、作った箱に入れ直す
            let placed = snapshot()
            build()
            if !placed.isEmpty { load(placed) }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 10, size.height > 10 else { return }
        let placed = oldSize.width > 10 ? snapshot(in: oldSize) : []
        build()
        if !placed.isEmpty { load(placed) }
    }

    private func build() {
        guard size.width > 10, size.height > 10 else { return }
        built = true
        removeAllChildren()
        cropsLayer = SKNode()
        fxLayer = SKNode()
        fxLayer.zPosition = 20
        addChild(cropsLayer)
        addChild(fxLayer)

        // 壁と床（上は開いている）
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size.height * 3))
        path.addLine(to: .zero)
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height * 3))
        physicsBody = SKPhysicsBody(edgeChainFrom: path)
        physicsBody?.friction = 0.6
        physicsBody?.restitution = 0.05

        // あふれの線（点線。危ないと赤く脈打つ）
        let lp = CGMutablePath()
        lp.move(to: CGPoint(x: 4, y: lineY))
        lp.addLine(to: CGPoint(x: size.width - 4, y: lineY))
        line = SKShapeNode(path: lp.copy(dashingWithPhase: 0, lengths: [7, 6]))
        line.strokeColor = UIColor.white.withAlphaComponent(0.7)
        line.lineWidth = 2
        line.zPosition = 5
        addChild(line)

        guide = SKShapeNode()
        guide.strokeColor = UIColor.white.withAlphaComponent(0.35)
        guide.lineWidth = 2
        guide.zPosition = 4
        addChild(guide)

        ghost = SKSpriteNode()
        ghost.alpha = 0.92
        ghost.zPosition = 10
        addChild(ghost)

        windMarks = SKNode()
        windMarks.zPosition = 9
        addChild(windMarks)

        holdRing = SKShapeNode(circleOfRadius: 10)
        holdRing.strokeColor = UIColor(hex: 0xFFE07A)
        holdRing.lineWidth = 4
        holdRing.fillColor = .clear
        holdRing.zPosition = 15
        holdRing.isHidden = true
        addChild(holdRing)
        refreshGhost()
    }

    // MARK: 作物

    func diameter(_ crop: Crop) -> CGFloat { CGFloat(CropBook.radius(crop)) * 2 * size.width }

    @discardableResult
    func makeNode(_ crop: Crop, at p: CGPoint, angle: CGFloat = 0) -> CropNode {
        let d = diameter(crop)
        let info = CropBook.info(crop)
        let node = CropNode(texture: SKTexture(image: CropArt.image(crop, diameter: d)))
        node.size = CGSize(width: d * CropArt.canvasScale, height: d * CropArt.canvasScale)
        node.crop = crop
        node.position = p
        node.zRotation = angle
        node.born = now
        node.zPosition = CGFloat(crop.tier)
        let r = CropArt.radii(info, diameter: d)
        node.halfHeight = max(r.width, r.height)
        let shape = CGMutablePath()
        let n = 14
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let pt = CGPoint(x: cos(a) * r.width * 0.96, y: sin(a) * r.height * 0.96)
            if i == 0 { shape.move(to: pt) } else { shape.addLine(to: pt) }
        }
        shape.closeSubpath()
        let body = SKPhysicsBody(polygonFrom: shape)
        body.restitution = 0.12
        body.friction = 0.55
        body.density = 1 + CGFloat(crop.tier) * 0.08
        body.angularDamping = 0.8
        body.linearDamping = 0.15
        body.categoryBitMask = 1
        body.collisionBitMask = 1
        body.contactTestBitMask = 0
        node.physicsBody = body
        cropsLayer.addChild(node)
        return node
    }

    /// 落とす（x は箱の幅に対する割合。風のずれは足してある）
    func spawn(_ crop: Crop, x: Double) {
        let d = diameter(crop)
        let half = d / 2 * 1.05
        let px = min(max(CGFloat(x) * size.width, half), size.width - half)
        let node = makeNode(crop, at: CGPoint(x: px, y: size.height * FarmScene.spawnRatio))
        node.physicsBody?.velocity = CGVector(dx: 0, dy: -60)
        lastDrop = now
        if !(model?.motionOff ?? false) {
            node.setScale(0.7)
            node.run(.sequence([.scale(to: 1.08, duration: 0.09), .scale(to: 1, duration: 0.08)]))
        }
    }

    func load(_ placed: [PlacedCrop]) {
        cropsLayer.removeAllChildren()
        for p in placed {
            makeNode(p.crop, at: CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height), angle: CGFloat(p.angle))
        }
    }

    func snapshot(in s: CGSize? = nil) -> [PlacedCrop] {
        let s = s ?? size
        guard s.width > 0, s.height > 0 else { return [] }
        return crops.filter { !$0.merging }.map {
            PlacedCrop(crop: $0.crop, x: Double($0.position.x / s.width), y: Double($0.position.y / s.height), angle: Double($0.zRotation))
        }
    }

    func leftovers() -> [Crop] { crops.filter { !$0.merging }.map(\.crop) }

    /// 季節の終わり：全部を出荷箱へ飛ばし、冬越しの 1 つを置く
    func clearForSeason(keep: Crop?) {
        for node in crops {
            node.physicsBody = nil
            node.merging = true
            if model?.motionOff ?? false {
                node.removeFromParent()
            } else {
                let delay = Double(node.position.x / max(1, size.width)) * 0.25
                node.run(.sequence([.wait(forDuration: delay), .group([.move(by: CGVector(dx: 0, dy: size.height * 1.2), duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
            }
        }
        if let keep {
            run(.wait(forDuration: (model?.motionOff ?? false) ? 0 : 0.7)) { [weak self] in
                guard let self else { return }
                let n = self.makeNode(keep, at: CGPoint(x: self.size.width / 2, y: self.diameter(keep) * 0.6))
                n.setScale(0.6)
                n.run(.scale(to: 1, duration: 0.25))
            }
        }
    }

    /// いちばん上にある出荷できる作物を出荷する（ボタン）
    @discardableResult
    func harvestTop() -> Bool {
        guard let model else { return false }
        let candidates = crops.filter { !$0.merging && model.farm.canHarvest($0.crop) }
        guard let top = candidates.max(by: { $0.position.y + $0.halfHeight < $1.position.y + $1.halfHeight }) else { return false }
        harvest(top)
        return true
    }

    private func harvest(_ node: CropNode) {
        guard let model, let coins = model.harvested(node.crop) else { return }
        node.merging = true
        node.physicsBody = nil
        floatText("+\(coins)", at: node.position, color: UIColor(hex: 0xFFE07A), size: 20 + CGFloat(node.crop.tier) * 2)
        if model.motionOff {
            node.removeFromParent()
        } else {
            node.run(.sequence([
                .scale(to: 1.15, duration: 0.08),
                .group([.move(to: CGPoint(x: size.width * 0.85, y: size.height * 1.15), duration: 0.42), .scale(to: 0.35, duration: 0.42), .rotate(byAngle: 1.2, duration: 0.42)]),
                .removeFromParent(),
            ]))
        }
    }

    /// 箱の中の今の絵（撮影で止まった絵に差し替えるため）
    func freezeImage() -> UIImage? {
        guard let view, view.bounds.width > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { _ in _ = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true) }
    }

    // MARK: 毎フレーム

    override func update(_ currentTime: TimeInterval) {
        now = currentTime
        guard let model else { return }
        mergeTouching(model)
        checkOverflow(model)
        if let h = holdNode {
            let t = (now - holdStart) / FarmScene.holdSeconds
            holdRing.isHidden = false
            holdRing.position = h.position
            holdRing.setScale(max(0.2, h.halfHeight / 10 * CGFloat(1.25 - 0.2 * min(1, t))))
            holdRing.alpha = CGFloat(min(1, t + 0.2))
            if t >= 1 {
                holdNode = nil
                holdRing.isHidden = true
                harvest(h)
            }
        }
    }

    private func mergeTouching(_ model: AppModel) {
        var used = Set<ObjectIdentifier>()
        for node in crops where !node.merging && !used.contains(ObjectIdentifier(node)) {
            guard let body = node.physicsBody else { continue }
            for other in body.allContactedBodies() {
                guard let o = other.node as? CropNode, o !== node, !o.merging, o.crop == node.crop, !used.contains(ObjectIdentifier(o)) else { continue }
                used.insert(ObjectIdentifier(node))
                used.insert(ObjectIdentifier(o))
                merge(node, o, model)
                break
            }
        }
    }

    private func merge(_ a: CropNode, _ b: CropNode, _ model: AppModel) {
        a.merging = true
        b.merging = true
        let mid = CGPoint(x: (a.position.x + b.position.x) / 2, y: (a.position.y + b.position.y) / 2)
        let v = CGVector(dx: ((a.physicsBody?.velocity.dx ?? 0) + (b.physicsBody?.velocity.dx ?? 0)) / 2, dy: 0)
        let outcome = model.merged(a.crop)
        let calm = model.motionOff
        for n in [a, b] {
            n.physicsBody = nil
            if calm { n.removeFromParent() } else {
                n.run(.sequence([.group([.move(to: mid, duration: 0.07), .fadeAlpha(to: 0.4, duration: 0.07)]), .removeFromParent()]))
            }
        }
        switch outcome {
        case .grow(let crop, let rain):
            let half = diameter(crop) / 2
            let p = CGPoint(x: min(max(mid.x, half), size.width - half), y: max(mid.y, half * 0.9))
            let n = makeNode(crop, at: p)
            n.physicsBody?.velocity = v
            if !calm {
                n.setScale(0.6)
                n.run(.sequence([.scale(to: 1.12, duration: 0.12), .scale(to: 0.97, duration: 0.08), .scale(to: 1, duration: 0.06)]))
                burst(at: p, color: UIColor(hex: CropBook.info(crop).body), count: 6 + crop.tier, radius: half * 1.4)
                if rain { burst(at: p, color: UIColor(hex: 0x7EC8F2), count: 10, radius: half * 1.9) }
            }
            if rain { floatText(tr("雨で 2 段！", "Rain: +2!"), at: CGPoint(x: p.x, y: p.y + half), color: UIColor(hex: 0xBFE6FF), size: 17) }
        case .prize(let coins):
            if !calm { burst(at: mid, color: UIColor(hex: 0xF6D04D), count: 22, radius: diameter(a.crop) * 1.2) }
            floatText(trf("品評会 +%d", "Fair prize +%d", coins), at: mid, color: UIColor(hex: 0xFFE07A), size: 24)
        }
    }

    private func checkOverflow(_ model: AppModel) {
        guard !model.farm.over, !model.farm.shopping else { return }
        var danger = false
        var worst: TimeInterval = 0
        for node in crops where !node.merging && now - node.born > 1.2 {
            if node.position.y + node.halfHeight * 0.8 > lineY {
                let since = node.overSince ?? now
                node.overSince = since
                danger = true
                worst = max(worst, now - since)
            } else {
                node.overSince = nil
            }
        }
        if danger != dangerShown {
            dangerShown = danger
            line.removeAllActions()
            if danger {
                line.strokeColor = UIColor(hex: 0xFF5A4A)
                model.warned()
                if !model.motionOff { line.run(.repeat(.sequence([.fadeAlpha(to: 0.3, duration: 0.25), .fadeAlpha(to: 1, duration: 0.25)]), count: 6)) }
            } else {
                line.strokeColor = UIColor.white.withAlphaComponent(0.7)
                line.alpha = 1
            }
        }
        if worst >= FarmScene.overflowSeconds {
            if model.overflowed() {
                // かかしが守った：線より上の作物を払う
                for node in crops where node.position.y + node.halfHeight * 0.8 > lineY - 10 {
                    node.merging = true
                    node.physicsBody = nil
                    node.run(.sequence([.group([.fadeOut(withDuration: 0.3), .scale(to: 0.3, duration: 0.3)]), .removeFromParent()]))
                }
                floatText(tr("かかしが守った！", "Scarecrow saved you!"), at: CGPoint(x: size.width / 2, y: lineY), color: .white, size: 20)
                dangerShown = false
                line.strokeColor = UIColor.white.withAlphaComponent(0.7)
            }
            for node in crops { node.overSince = nil }
        }
    }

    // MARK: 落とす所の表示

    func setAim(_ x: Double) {
        aim = min(max(x, 0.04), 0.96)
        refreshGhost()
    }

    /// 次の作物の影（風の日はずれた所に出す）
    func refreshGhost() {
        guard size.width > 10, let model else { return }
        let farm = model.farm
        let canDrop = !farm.over && !farm.shopping && !farm.outOfDays
        ghost.isHidden = !canDrop
        guide.isHidden = !canDrop
        windMarks.removeAllChildren()
        guard canDrop else { return }
        let crop = farm.nextCrop
        let d = diameter(crop)
        ghost.texture = SKTexture(image: CropArt.image(crop, diameter: d))
        ghost.size = CGSize(width: d * CropArt.canvasScale, height: d * CropArt.canvasScale)
        let x = landingX(for: crop)
        ghost.position = CGPoint(x: x, y: size.height * FarmScene.spawnRatio)
        let gp = CGMutablePath()
        gp.move(to: CGPoint(x: x, y: size.height * FarmScene.spawnRatio - d / 2))
        gp.addLine(to: CGPoint(x: x, y: 0))
        guide.path = gp.copy(dashingWithPhase: 0, lengths: [3, 7])
        let drift = farm.todayDrift
        if drift != 0 {
            // 風：ずれる向きに 3 本の線
            for i in 0..<3 {
                let s = SKShapeNode(rectOf: CGSize(width: 18, height: 3), cornerRadius: 1.5)
                s.fillColor = UIColor.white.withAlphaComponent(0.8)
                s.strokeColor = .clear
                s.position = CGPoint(x: x - CGFloat(drift > 0 ? 1 : -1) * (d * 0.7 + 8), y: size.height * FarmScene.spawnRatio + CGFloat(i - 1) * 8)
                windMarks.addChild(s)
            }
        }
    }

    func landingX(for crop: Crop) -> CGFloat {
        let half = diameter(crop) / 2 * 1.05
        let x = (CGFloat(aim) + CGFloat(model?.farm.todayDrift ?? 0)) * size.width
        return min(max(x, half), size.width - half)
    }

    var landingRatio: Double {
        guard let model, size.width > 0 else { return aim }
        return Double(landingX(for: model.farm.nextCrop) / size.width)
    }

    // MARK: 指

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let model, model.canPlay else { return }
        let p = t.location(in: self)
        touchStart = p
        aiming = false
        if let node = cropAt(p), model.farm.canHarvest(node.crop) {
            holdNode = node
            holdStart = now
            model.pressed()
        } else {
            aiming = true
            setAim(Double(p.x / size.width))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let model, model.canPlay else { return }
        let p = t.location(in: self)
        if holdNode != nil, hypot(p.x - touchStart.x, p.y - touchStart.y) > 14 {
            holdNode = nil
            holdRing.isHidden = true
            aiming = true
        }
        if aiming { setAim(Double(p.x / size.width)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let model else { return }
        let p = t.location(in: self)
        if holdNode != nil {
            // 長押しの前に離した：その場所に落とす
            holdNode = nil
            holdRing.isHidden = true
            setAim(Double(p.x / size.width))
            model.drop()
        } else if aiming {
            aiming = false
            model.drop()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        holdNode = nil
        holdRing.isHidden = true
        aiming = false
    }

    private func cropAt(_ p: CGPoint) -> CropNode? {
        crops.filter { !$0.merging && hypot($0.position.x - p.x, $0.position.y - p.y) < $0.halfHeight * 1.05 }
            .max { $0.zPosition < $1.zPosition }
    }

    // MARK: 飾り

    private func burst(at p: CGPoint, color: UIColor, count: Int, radius: CGFloat) {
        for i in 0..<count {
            // 決まった角度で散らす（毎回同じ散り方）
            let a = CGFloat(i) / CGFloat(count) * 2 * .pi + 0.3
            let dot = SKShapeNode(circleOfRadius: CGFloat(3 + (i % 3)))
            dot.fillColor = color
            dot.strokeColor = .clear
            dot.position = p
            dot.zPosition = 30
            fxLayer.addChild(dot)
            let to = CGPoint(x: p.x + cos(a) * radius, y: p.y + sin(a) * radius)
            let move = SKAction.move(to: to, duration: 0.32)
            move.timingMode = .easeOut
            dot.run(.sequence([.group([move, .fadeOut(withDuration: 0.36), .scale(to: 0.4, duration: 0.36)]), .removeFromParent()]))
        }
    }

    private func floatText(_ text: String, at p: CGPoint, color: UIColor, size s: CGFloat) {
        let label = SKLabelNode(text: text)
        label.fontName = UIFont.systemFont(ofSize: s, weight: .heavy).fontName
        if let rounded = UIFont.systemFont(ofSize: s, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            label.fontName = UIFont(descriptor: rounded, size: s).fontName
        }
        label.fontSize = s
        label.fontColor = color
        label.position = CGPoint(x: min(max(p.x, 70), size.width - 70), y: min(p.y, size.height - 30))
        label.zPosition = 40
        let shadow = SKLabelNode(text: text)
        shadow.fontName = label.fontName
        shadow.fontSize = s
        shadow.fontColor = UIColor(hex: 0x3A2B20, alpha: 0.55)
        shadow.position = CGPoint(x: 0, y: -2)
        shadow.zPosition = -1
        label.addChild(shadow)
        fxLayer.addChild(label)
        if model?.motionOff ?? false {
            label.run(.sequence([.wait(forDuration: 0.9), .removeFromParent()]))
        } else {
            label.setScale(0.6)
            label.run(.sequence([.scale(to: 1.1, duration: 0.12), .scale(to: 1, duration: 0.08), .group([.moveBy(x: 0, y: 46, duration: 0.8), .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
        }
    }
}
