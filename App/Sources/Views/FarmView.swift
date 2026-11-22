import SpriteKit
import SwiftUI

/// 畑の画面：季節の空・暦と出荷箱・天気予報・育て箱の断面・下に固定した主なボタン。
/// iPhone Duo の内側など横に広いとき（regular）は、左に暦と予報、右に育て箱を並べる
struct FarmView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ZStack {
            Backdrop(season: model.farm.season, skin: model.save.skin)
                .id(model.farm.season)
                .transition(.opacity)
                .ignoresSafeArea()
            if hSize == .regular {
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 12) {
                        TopBar()
                        StatusPanel(wide: true)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 330)
                    VStack(spacing: 10) {
                        BedView()
                        BottomBar()
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 8) {
                    TopBar()
                    StatusPanel(wide: false)
                    BedView()
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .safeAreaInset(edge: .bottom, spacing: 8) {
                    BottomBar().padding(.horizontal, 14).padding(.bottom, 4)
                }
            }
        }
        .animation(.easeInOut(duration: model.motionOff ? 0 : 1.0), value: model.farm.season)
        .onChange(of: model.isPro) { _, _ in model.syncPro() }
        .onAppear { model.syncPro() }
    }
}

// MARK: - 上の行

struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Button { model.pressed(); model.activeSheet = .almanac } label: {
                HStack(spacing: 6) {
                    CropImage(crop: Crop(season: model.farm.season, tier: 3), size: 26)
                    Text(tr("図鑑", "Almanac")).font(Fonts.small(14))
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
            }
            .buttonStyle(ClayButtonStyle(fill: Color(hex: model.palette.panel), edge: Color(hex: model.palette.panelEdge), text: Ink.text, radius: Radius.chip + 6, ledge: Ledge.small))
            .accessibilityIdentifier("main.almanac")

            Spacer(minLength: 4)
            VStack(spacing: 0) {
                Text(model.modeTitle).font(Fonts.title(16)).foregroundStyle(Ink.text)
                if model.streak > 0 {
                    Text(trf("%d 日つづけて", "%d-day streak", model.streak)).font(Fonts.small(11)).foregroundStyle(Ink.soft)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(ClaySlab(fill: Color(hex: model.palette.panel).opacity(0.92), edge: Color(hex: model.palette.panelEdge), radius: Radius.chip + 4))
            Spacer(minLength: 4)

            Button { model.pressed(); model.activeSheet = .settings } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 17, weight: .bold))
                    .frame(width: 40, height: 34)
            }
            .buttonStyle(ClayButtonStyle(fill: Color(hex: model.palette.panel), edge: Color(hex: model.palette.panelEdge), text: Ink.soft, radius: Radius.chip + 6, ledge: Ledge.small))
            .accessibilityLabel(tr("設定", "Settings"))
            .accessibilityIdentifier("main.settings")
        }
    }
}

// MARK: - 暦・出荷箱・天気予報・次の作物

struct StatusPanel: View {
    @Environment(AppModel.self) private var model
    var wide: Bool

    var body: some View {
        let farm = model.farm
        let p = model.palette
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                // 暦（日めくり）
                VStack(spacing: 1) {
                    Text(trf("%d年目", "Year %d", farm.year)).font(Fonts.small(11)).foregroundStyle(Ink.onAccent.opacity(0.9)).lineLimit(1)
                    Text(farm.season.name).font(Fonts.title(22)).foregroundStyle(Ink.onAccent)
                        .lineLimit(1).minimumScaleFactor(0.55)
                }
                .padding(.horizontal, 4)
                .frame(width: 70, height: 54)
                .background(ClaySlab(fill: Color(hex: p.accent), edge: Color(hex: p.accentDeep), radius: Radius.chip + 2))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(farm.daysLeft)").font(Fonts.number(26)).foregroundStyle(farm.daysLeft <= 3 ? Ink.danger : Ink.text)
                            .contentTransition(.numericText())
                        Text(tr("日のこり", "days left")).font(Fonts.small(12)).foregroundStyle(Ink.soft)
                    }
                    DayStrip(total: farm.days, used: farm.day, accent: Color(hex: p.accent))
                }
                Spacer(minLength: 0)
                ShipMeter()
            }
            HStack(spacing: 8) {
                WeatherChip(label: tr("今日", "Today"), weather: farm.over ? nil : farm.today, drift: farm.todayDrift)
                WeatherChip(label: tr("あす", "Tmrw"), weather: farm.daysLeft > 1 ? farm.tomorrow : nil, drift: 0)
                Spacer(minLength: 0)
                NextCrops()
            }
            if wide { WidePanelExtras() }
        }
        .padding(10)
        .background(ClaySlab(fill: Color(hex: p.panel).opacity(0.94), edge: Color(hex: p.panelEdge), radius: Radius.tile, ledge: Ledge.button))
    }
}

/// 季節の日を小さな四角で（使った日は塗る）
struct DayStrip: View {
    var total: Int
    var used: Int
    var accent: Color

    var body: some View {
        Canvas { ctx, size in
            let n = max(1, total)
            let gap: CGFloat = 1.5
            let w = (size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            for i in 0..<n {
                let r = CGRect(x: CGFloat(i) * (w + gap), y: 0, width: w, height: size.height)
                ctx.fill(Path(roundedRect: r, cornerRadius: 1.5), with: .color(i < used ? accent : Ink.faint.opacity(0.28)))
            }
        }
        .frame(width: 104, height: 7)
        .accessibilityHidden(true)
    }
}

/// 出荷箱：目標までの売上
struct ShipMeter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let farm = model.farm
        let frac = min(1, Double(farm.seasonSales) / Double(max(1, farm.target)))
        HStack(spacing: 6) {
            CrateGlyph(fill: frac).frame(width: 34, height: 28)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(farm.seasonSales)").font(Fonts.number(20)).foregroundStyle(farm.targetReached ? Color(hex: 0x3C8A3A) : Ink.text)
                    .contentTransition(.numericText())
                Text(trf("目標 %d", "Goal %d", farm.target)).font(Fonts.small(11)).foregroundStyle(Ink.soft)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 木の出荷箱（中身が目標までの割合で積もる）
struct CrateGlyph: View {
    var fill: Double

    var body: some View {
        Canvas { ctx, size in
            let body = CGRect(x: 0, y: size.height * 0.28, width: size.width, height: size.height * 0.72)
            // 中身（色とりどりの粒）
            let h = body.height * 0.9 * fill
            if fill > 0 {
                let inside = CGRect(x: 3, y: body.maxY - 2 - h, width: size.width - 6, height: h)
                ctx.fill(Path(roundedRect: inside, cornerRadius: 3), with: .color(Color(hex: 0xEE8A3A)))
                for (i, c) in [0xE65A6E, 0x8CC65A, 0xF6CF45].enumerated() where fill > 0.25 {
                    let x = 5 + CGFloat(i) * (size.width - 10) / 3
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: inside.minY - 4, width: 9, height: 9)), with: .color(Color(hex: UInt32(c))))
                }
            }
            for k in 0..<2 {
                let slat = CGRect(x: 0, y: body.minY + CGFloat(k) * body.height * 0.55, width: size.width, height: body.height * 0.4)
                ctx.fill(Path(roundedRect: slat, cornerRadius: 3), with: .color(Wood.plank))
                ctx.stroke(Path(roundedRect: slat, cornerRadius: 3), with: .color(Wood.plankDark), lineWidth: 1.2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 天気の札（今日・あす）
struct WeatherChip: View {
    var label: String
    var weather: Weather?
    var drift: Double

    var body: some View {
        HStack(spacing: 5) {
            WeatherIcon(weather: weather).frame(width: 24, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(Fonts.small(10)).foregroundStyle(Ink.soft)
                Text(weather?.name ?? "—").font(Fonts.small(13)).foregroundStyle(Ink.text)
            }
            if weather == .wind && drift != 0 {
                Image(systemName: drift > 0 ? "arrow.right" : "arrow.left").font(.system(size: 11, weight: .heavy)).foregroundStyle(Ink.soft)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).fill(weather == .rain ? Color(hex: 0xD7EEFB) : Color.white.opacity(0.55)))
        .accessibilityElement(children: .combine)
    }
}

/// 天気の絵（晴れ：太陽、雨：雲としずく、風：流れる線）
struct WeatherIcon: View {
    var weather: Weather?

    var body: some View {
        Canvas { ctx, s in
            switch weather {
            case .sunny:
                let c = CGPoint(x: s.width / 2, y: s.height / 2)
                for i in 0..<8 {
                    let a = Double(i) / 8 * 2 * .pi
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + cos(a) * 7, y: c.y + sin(a) * 7))
                    p.addLine(to: CGPoint(x: c.x + cos(a) * 10.5, y: c.y + sin(a) * 10.5))
                    ctx.stroke(p, with: .color(Color(hex: 0xF4B227)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 5.5, y: c.y - 5.5, width: 11, height: 11)), with: .color(Color(hex: 0xF9C93A)))
            case .rain:
                cloud(ctx, s, Color(hex: 0x8DA9C4))
                for i in 0..<3 {
                    let x = s.width * (0.3 + 0.2 * Double(i))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 1.6, y: s.height * 0.68, width: 3.2, height: 5)), with: .color(Color(hex: 0x3A8FD6)))
                }
            case .wind:
                for (i, w) in [0.8, 0.6, 0.7].enumerated() {
                    var p = Path()
                    let y = s.height * (0.28 + 0.22 * Double(i))
                    p.move(to: CGPoint(x: 2, y: y))
                    p.addQuadCurve(to: CGPoint(x: s.width * w, y: y), control: CGPoint(x: s.width * w * 0.5, y: y - 3))
                    ctx.stroke(p, with: .color(Color(hex: 0x7A9AB0)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            case nil:
                ctx.fill(Path(ellipseIn: CGRect(x: s.width / 2 - 3, y: s.height / 2 - 3, width: 6, height: 6)), with: .color(Ink.faint.opacity(0.5)))
            }
        }
        .accessibilityHidden(true)
    }

    private func cloud(_ ctx: GraphicsContext, _ s: CGSize, _ c: Color) {
        for (x, y, r) in [(0.32, 0.45, 0.22), (0.55, 0.38, 0.27), (0.72, 0.5, 0.2)] {
            ctx.fill(Path(ellipseIn: CGRect(x: s.width * (x - r), y: s.height * (y - r), width: s.width * r * 2, height: s.height * r * 2)), with: .color(c))
        }
    }
}

/// 次に落ちてくる作物（1 つ目を大きく）
struct NextCrops: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let next = model.farm.upcoming(3)
        HStack(spacing: 4) {
            Text(tr("つぎ", "Next")).font(Fonts.small(11)).foregroundStyle(Ink.soft).fixedSize()
            ForEach(Array(next.enumerated()), id: \.offset) { i, c in
                CropImage(crop: c, size: i == 0 ? 34 : 24).opacity(i == 0 ? 1 : 0.7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("次は %@", "Next: %@", CropBook.info(next[0]).name))
    }
}

/// 横に広いとき（Duo の内側）だけ出す：持っている道具と記録
struct WidePanelExtras: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let farm = model.farm
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(farm.season.rule).font(Fonts.body(13)).foregroundStyle(Ink.soft)
            HStack(spacing: 12) {
                ToolCount(tool: .scarecrow, count: farm.scarecrows)
                ToolCount(tool: .compost, count: farm.compost)
                ToolCount(tool: .wateringCan, count: farm.cans)
            }
            Text(trf("今年の売上 %d ・ いちばん %d", "Total %d · Best %d", farm.totalSales, model.save.bestScore)).font(Fonts.small(12)).foregroundStyle(Ink.soft)
        }
    }
}

struct ToolCount: View {
    var tool: Tool
    var count: Int

    var body: some View {
        HStack(spacing: 4) {
            ToolIcon(tool: tool).frame(width: 22, height: 22)
            Text("\(count)").font(Fonts.number(14)).foregroundStyle(count > 0 ? Ink.text : Ink.faint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tool.name) \(count)")
    }
}

// MARK: - 育て箱

struct BedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geo in
            let plank: CGFloat = 14
            let soil: CGFloat = max(30, geo.size.height * 0.075)
            ZStack(alignment: .topLeading) {
                BedFrame(skin: model.save.skin, plank: plank, soil: soil)
                    .allowsHitTesting(false)
                SpriteView(scene: model.scene, isPaused: model.scenePaused, options: [.allowsTransparency])
                    .frame(width: max(10, geo.size.width - plank * 2), height: max(10, geo.size.height - soil - 4))
                    .offset(x: plank, y: 4)
                    .accessibilityElement()
                    .accessibilityLabel(tr("育て箱。なぞって離すと落とす。大きな作物は長押しで出荷", "Raised bed. Drag and release to drop. Long-press big crops to ship"))
                    .accessibilityIdentifier("bed")
                if let b = model.banner {
                    BannerView(banner: b)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.horizontal, plank + 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(b.id)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

/// 木の育て箱の断面：左右の杉板（木目と釘）、下に土の層（小石・ミミズの通り道）
struct BedFrame: View {
    var skin: BoxSkin
    var plank: CGFloat
    var soil: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let wood = skin == .dusk ? Color(hex: 0x9A5A3C) : Wood.plank
            let woodDark = skin == .dusk ? Color(hex: 0x6A3522) : Wood.plankDark
            let grain = skin == .dusk ? Color(hex: 0x7E452D) : Wood.grain
            // 箱の中の空気（ほんの少し影）
            let inner = CGRect(x: plank, y: 0, width: size.width - plank * 2, height: size.height - soil)
            ctx.fill(Path(inner), with: .linearGradient(Gradient(colors: [Color.white.opacity(0.0), Color.black.opacity(0.06)]), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: inner.maxY)))
            if skin == .greenhouse {
                // 温室のガラス
                ctx.fill(Path(inner), with: .color(Color(hex: 0xE6F6F2, opacity: 0.35)))
                for k in 1..<4 {
                    let x = inner.minX + inner.width * CGFloat(k) / 4
                    ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: inner.maxY)) }, with: .color(.white.opacity(0.7)), lineWidth: 2)
                }
                ctx.stroke(Path { $0.move(to: CGPoint(x: inner.minX, y: inner.height * 0.45)); $0.addLine(to: CGPoint(x: inner.maxX, y: inner.height * 0.45)) }, with: .color(.white.opacity(0.7)), lineWidth: 2)
                for k in 0..<3 {
                    let x = inner.minX + inner.width * (0.12 + 0.3 * CGFloat(k))
                    ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 20)); $0.addLine(to: CGPoint(x: x + 30, y: 70)) }, with: .color(.white.opacity(0.5)), lineWidth: 3)
                }
            }
            // 土の層
            let soilRect = CGRect(x: 0, y: size.height - soil, width: size.width, height: soil)
            ctx.fill(Path(roundedRect: soilRect, cornerRadius: 10), with: .linearGradient(Gradient(colors: [Wood.soilTop, Wood.soil, Wood.soilDeep]), startPoint: CGPoint(x: 0, y: soilRect.minY), endPoint: CGPoint(x: 0, y: soilRect.maxY)))
            var rng = SeededRNG(seed: 404)
            for _ in 0..<26 {
                let x = soilRect.minX + CGFloat(rng.unit()) * soilRect.width
                let y = soilRect.minY + 6 + CGFloat(rng.unit()) * (soil - 10)
                let r = 1.5 + CGFloat(rng.unit()) * 3
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 1.4, height: r)), with: .color(Wood.pebble.opacity(0.85)))
            }
            // ミミズの通り道
            var worm = Path()
            worm.move(to: CGPoint(x: size.width * 0.62, y: soilRect.minY + soil * 0.45))
            worm.addCurve(to: CGPoint(x: size.width * 0.8, y: soilRect.minY + soil * 0.7), control1: CGPoint(x: size.width * 0.68, y: soilRect.minY + soil * 0.9), control2: CGPoint(x: size.width * 0.74, y: soilRect.minY + soil * 0.3))
            ctx.stroke(worm, with: .color(Wood.worm.opacity(0.6)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            // 左右の板
            for x in [CGFloat(0), size.width - plank] {
                let board = CGRect(x: x, y: 0, width: plank, height: size.height)
                ctx.fill(Path(roundedRect: board, cornerRadius: 5), with: .linearGradient(Gradient(colors: [wood, woodDark]), startPoint: CGPoint(x: board.minX, y: 0), endPoint: CGPoint(x: board.maxX, y: 0)))
                for k in 0..<4 {
                    var g = Path()
                    let gx = board.minX + 3 + CGFloat(k) * 2.5
                    g.move(to: CGPoint(x: gx, y: 10))
                    g.addCurve(to: CGPoint(x: gx + 1, y: size.height - 10), control1: CGPoint(x: gx + 2.5, y: size.height * 0.3), control2: CGPoint(x: gx - 2, y: size.height * 0.7))
                    ctx.stroke(g, with: .color(grain.opacity(0.6)), lineWidth: 0.8)
                }
                for y in [size.height * 0.2, size.height * 0.6, size.height - soil * 0.5] {
                    ctx.fill(Path(ellipseIn: CGRect(x: board.midX - 2.5, y: y - 2.5, width: 5, height: 5)), with: .color(Wood.nail))
                }
            }
            // 上のふちの横板
            for x in [CGFloat(-4), size.width - plank - 6] {
                ctx.fill(Path(roundedRect: CGRect(x: x, y: -6, width: plank + 10, height: 10), cornerRadius: 4), with: .color(wood))
            }
        }
    }
}

// MARK: - 下に固定した主なボタン

struct BottomBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let farm = model.farm
        let p = model.palette
        VStack(spacing: 8) {
            if farm.targetReached && !farm.shopping && !farm.over && !farm.outOfDays {
                Button { model.advanceSeason() } label: {
                    HStack(spacing: 6) {
                        Text(tr("次の季節へ", "Next season")).font(Fonts.title(16))
                        Image(systemName: "arrow.right").font(.system(size: 14, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity).frame(height: 40)
                }
                .buttonStyle(ClayButtonStyle(fill: Color(hex: 0x5BAE4C), edge: Color(hex: 0x37792E), radius: Radius.button - 4, ledge: Ledge.small))
                .accessibilityIdentifier("main.advance")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                Button { model.harvestButton() } label: {
                    VStack(spacing: 1) {
                        CrateGlyph(fill: 0.6).frame(width: 30, height: 22)
                        Text(tr("出荷", "Ship")).font(Fonts.small(12))
                    }
                    .frame(width: 76, height: 56)
                }
                .buttonStyle(ClayButtonStyle(fill: Color(hex: p.panel), edge: Color(hex: p.panelEdge), text: Ink.text))
                .accessibilityIdentifier("main.harvest")

                Button { mainAction() } label: {
                    VStack(spacing: 0) {
                        Text(mainTitle).font(Fonts.title(20)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(mainDetail).font(Fonts.small(11)).opacity(0.9).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity).frame(height: 56)
                }
                .buttonStyle(ClayButtonStyle(fill: Color(hex: p.accent), edge: Color(hex: p.accentDeep)))
                .accessibilityIdentifier("main.drop")

                Button { model.water() } label: {
                    VStack(spacing: 1) {
                        ToolIcon(tool: .wateringCan).frame(width: 26, height: 22)
                        Text(farm.cans > 0 ? trf("雨 ×%d", "Rain ×%d", farm.cans) : tr("じょうろ ", "Can")).font(Fonts.small(12))
                    }
                    .frame(width: 76, height: 56)
                    .opacity(farm.cans > 0 ? 1 : 0.55)
                }
                .buttonStyle(ClayButtonStyle(fill: Color(hex: p.panel), edge: Color(hex: p.panelEdge), text: Ink.text))
                .accessibilityIdentifier("main.water")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: farm.targetReached)
    }

    private var mainTitle: String {
        let farm = model.farm
        if farm.over { return tr("結果を見る", "See results") }
        if farm.outOfDays { return farm.targetReached ? tr("次の季節へ", "Next season") : tr("今季を締める", "Close season") }
        return tr("落とす", "Drop")
    }

    private var mainDetail: String {
        let farm = model.farm
        if farm.over { return trf("売上 %d", "Sales %d", farm.totalSales) }
        if farm.outOfDays { return trf("売上 %d / 目標 %d", "%d of %d shipped", farm.seasonSales, farm.target) }
        return trf("%@・あと %d 日", "%@ · %d days left", CropBook.info(farm.nextCrop).name, farm.daysLeft)
    }

    private func mainAction() {
        let farm = model.farm
        if farm.over {
            model.activeSheet = .result
        } else {
            model.pressed()
            model.drop()
        }
    }
}

/// 道具の絵（自前の形）
struct ToolIcon: View {
    var tool: Tool

    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            switch tool {
            case .wateringCan:
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.22, y: h * 0.35, width: w * 0.48, height: h * 0.55), cornerRadius: 4), with: .color(Color(hex: 0x4FA3D9)))
                ctx.stroke(Path { p in p.move(to: CGPoint(x: w * 0.68, y: h * 0.62)); p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.24)) }, with: .color(Color(hex: 0x2F7DB5)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                ctx.stroke(Path { p in p.addArc(center: CGPoint(x: w * 0.3, y: h * 0.45), radius: h * 0.22, startAngle: .degrees(100), endAngle: .degrees(260), clockwise: false) }, with: .color(Color(hex: 0x2F7DB5)), lineWidth: 2.5)
            case .scarecrow:
                ctx.stroke(Path { p in p.move(to: CGPoint(x: w / 2, y: h * 0.3)); p.addLine(to: CGPoint(x: w / 2, y: h)); p.move(to: CGPoint(x: w * 0.1, y: h * 0.5)); p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.5)) }, with: .color(Wood.plankDark), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.34, y: h * 0.12, width: w * 0.32, height: h * 0.3)), with: .color(Color(hex: 0xF2D9A6)))
                ctx.fill(Path { p in p.move(to: CGPoint(x: w * 0.2, y: h * 0.18)); p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.18)); p.addLine(to: CGPoint(x: w * 0.5, y: 0)); p.closeSubpath() }, with: .color(Color(hex: 0xD9A53A)))
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.32, y: h * 0.42, width: w * 0.36, height: h * 0.3), cornerRadius: 3), with: .color(Color(hex: 0xD8463A)))
            case .compost:
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.15, y: h * 0.3, width: w * 0.7, height: h * 0.65), cornerRadius: 5), with: .color(Color(hex: 0xC9A16A)))
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.15, y: h * 0.18, width: w * 0.7, height: h * 0.28)), with: .color(Wood.soil))
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.42, y: h * 0.02, width: w * 0.2, height: h * 0.25)), with: .color(Color(hex: 0x7FB04F)))
            case .windbreak:
                for k in 0..<4 {
                    let x = w * (0.15 + 0.23 * CGFloat(k))
                    ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: h * 0.1)); p.addLine(to: CGPoint(x: x, y: h * 0.95)) }, with: .color(Wood.plankDark), lineWidth: 2)
                }
                for k in 0..<3 {
                    let y = h * (0.25 + 0.22 * CGFloat(k))
                    ctx.stroke(Path { p in p.move(to: CGPoint(x: w * 0.1, y: y)); p.addLine(to: CGPoint(x: w * 0.9, y: y)) }, with: .color(Color(hex: 0x5BAE4C)), lineWidth: 2)
                }
            case .bigCrate:
                CrateDrawing.draw(ctx, CGRect(origin: .zero, size: s))
            case .wheelbarrow:
                ctx.fill(Path { p in p.move(to: CGPoint(x: w * 0.1, y: h * 0.35)); p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.35)); p.addLine(to: CGPoint(x: w * 0.6, y: h * 0.65)); p.addLine(to: CGPoint(x: w * 0.2, y: h * 0.65)); p.closeSubpath() }, with: .color(Color(hex: 0x4F7FB6)))
                ctx.stroke(Path { p in p.move(to: CGPoint(x: w * 0.7, y: h * 0.45)); p.addLine(to: CGPoint(x: w * 0.98, y: h * 0.3)) }, with: .color(Wood.plankDark), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.3, y: h * 0.62, width: w * 0.3, height: h * 0.32)), with: .color(Ink.text))
            case .charm:
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.28, y: h * 0.2, width: w * 0.44, height: h * 0.72), cornerRadius: 6), with: .color(Color(hex: 0xE9A922)))
                ctx.stroke(Path { p in p.move(to: CGPoint(x: w / 2, y: h * 0.2)); p.addLine(to: CGPoint(x: w / 2, y: 0)) }, with: .color(Color(hex: 0xD8463A)), lineWidth: 2)
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.4, y: h * 0.42, width: w * 0.2, height: h * 0.2)), with: .color(Color(hex: 0x5BAE4C)))
            }
        }
        .accessibilityHidden(true)
    }
}

enum CrateDrawing {
    static func draw(_ ctx: GraphicsContext, _ r: CGRect) {
        for k in 0..<3 {
            let slat = CGRect(x: r.minX + 1, y: r.minY + r.height * (0.2 + 0.27 * CGFloat(k)), width: r.width - 2, height: r.height * 0.22)
            ctx.fill(Path(roundedRect: slat, cornerRadius: 2), with: .color(Wood.plank))
            ctx.stroke(Path(roundedRect: slat, cornerRadius: 2), with: .color(Wood.plankDark), lineWidth: 1)
        }
    }
}

// MARK: - 知らせ

struct BannerView: View {
    var banner: Banner

    var body: some View {
        let colors: (Color, Color) = switch banner.tint {
        case .plain: (Color(hex: 0xFFF8EC), Color(hex: 0xE2CBB2))
        case .good: (Color(hex: 0xE9F7D9), Color(hex: 0x9FCB7E))
        case .warn: (Color(hex: 0xFFE9DF), Color(hex: 0xE7A88E))
        case .rain: (Color(hex: 0xE0F1FC), Color(hex: 0x8DC0E3))
        }
        VStack(spacing: 2) {
            Text(banner.title).font(Fonts.title(16)).foregroundStyle(Ink.text).multilineTextAlignment(.center)
            Text(banner.detail).font(Fonts.body(12)).foregroundStyle(Ink.soft).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(ClaySlab(fill: colors.0, edge: colors.1, radius: Radius.tile, ledge: Ledge.small))
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 季節の空

/// 空・太陽・雲・遠くの畑の畝・季節の粒（花びら・光・落ち葉・雪）。止まった絵（くり返しの動きは使わない）
struct Backdrop: View {
    var season: Season
    var skin: BoxSkin

    var body: some View {
        let p = SeasonPalette.of(season)
        Canvas { ctx, size in
            let w = size.width, h = size.height
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Color(hex: p.skyTop), Color(hex: p.skyLow)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.75)))
            // 太陽
            let sun = CGPoint(x: w * 0.82, y: h * (season == .autumn ? 0.2 : 0.1))
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 60, y: sun.y - 60, width: 120, height: 120)), with: .color(Color.white.opacity(0.25)))
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 30, y: sun.y - 30, width: 60, height: 60)), with: .color(season == .autumn ? Color(hex: 0xFFD08A) : Color(hex: 0xFFF3B8)))
            // 雲（夏は入道雲）
            let clouds: [(CGFloat, CGFloat, CGFloat)] = season == .summer ? [(0.18, 0.2, 1.6), (0.6, 0.26, 0.9)] : [(0.15, 0.14, 0.8), (0.55, 0.22, 0.6)]
            for (x, y, s) in clouds {
                for (dx, dy, r) in [(-30.0, 8.0, 26.0), (0, -10, 34), (32, 4, 28), (12, -34, 26)] where season == .summer || dy > -20 {
                    let c = CGPoint(x: w * x + CGFloat(dx) * s, y: h * y + CGFloat(dy) * s)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - CGFloat(r) * s, y: c.y - CGFloat(r) * s, width: CGFloat(r) * 2 * s, height: CGFloat(r) * 2 * s)), with: .color(.white.opacity(season == .winter ? 0.6 : 0.85)))
                }
            }
            // 遠くの丘と畑の畝
            for (i, col) in [p.hillFar, p.hill].enumerated() {
                let base = h * (0.62 + 0.1 * CGFloat(i))
                var hill = Path()
                hill.move(to: CGPoint(x: 0, y: h))
                hill.addLine(to: CGPoint(x: 0, y: base))
                hill.addCurve(to: CGPoint(x: w, y: base - 10), control1: CGPoint(x: w * 0.3, y: base - 50 + CGFloat(i) * 20), control2: CGPoint(x: w * 0.7, y: base + 30))
                hill.addLine(to: CGPoint(x: w, y: h))
                ctx.fill(hill, with: .color(Color(hex: col)))
                for k in 0..<6 {
                    var row = Path()
                    let y = base + 18 + CGFloat(k) * 16
                    row.move(to: CGPoint(x: -10, y: y + CGFloat(i) * 4))
                    row.addQuadCurve(to: CGPoint(x: w + 10, y: y - 6), control: CGPoint(x: w * 0.5, y: y - 14))
                    ctx.stroke(row, with: .color(Color.black.opacity(0.06)), lineWidth: 3)
                }
            }
            // 季節の粒（決まった並び）
            var rng = SeededRNG(seed: UInt64(season.rawValue + 7))
            for _ in 0..<(season == .winter ? 40 : 18) {
                let x = CGFloat(rng.unit()) * w
                let y = CGFloat(rng.unit()) * h * 0.6
                let r = 2 + CGFloat(rng.unit()) * 3
                switch season {
                case .spring, .autumn:
                    var leaf = Path(ellipseIn: CGRect(x: -r * 1.4, y: -r * 0.7, width: r * 2.8, height: r * 1.4))
                    leaf = leaf.applying(CGAffineTransform(rotationAngle: CGFloat(rng.unit()) * 3).concatenating(CGAffineTransform(translationX: x, y: y)))
                    ctx.fill(leaf, with: .color(Color(hex: p.speck).opacity(0.85)))
                case .summer:
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 0.8, height: r * 0.8)), with: .color(.white.opacity(0.5)))
                case .winter:
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.9)))
                }
            }
            if skin == .dusk {
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Color(hex: 0x6B4E8E, opacity: 0.45), Color(hex: 0xF29A5C, opacity: 0.25), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.8)))
            }
        }
        .accessibilityHidden(true)
    }
}
