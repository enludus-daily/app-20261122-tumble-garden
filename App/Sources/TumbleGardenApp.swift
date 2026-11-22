import SwiftUI

@main
struct TumbleGardenApp: App {
    /// アプリ全体で 1 つだけ（App の init は何度も呼ばれることがあるので、ここで作り直さない）
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ZStack {
            if !model.onboarded {
                OnboardingView().transition(.opacity)
            } else {
                FarmView().transition(.opacity)
            }
        }
        .environment(model)
        // 昼の畑の色を自前で描くので、ライトに固定する（ダークでも同じ昼の空）
        .preferredColorScheme(.light)
        .sheet(item: $model.activeSheet, onDismiss: {
            // 店の途中で Pro を見に行ったら、店に戻る（季節の途中で止まらない）
            if model.farm.shopping, model.activeSheet == nil {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    if model.farm.shopping, model.activeSheet == nil { model.activeSheet = .shop }
                }
            }
        }) { sheet in
            SheetContent(sheet: sheet)
                .environment(model)
                .environment(\.locale, Lang.locale)
                .presentationCornerRadius(Radius.sheet)
                .presentationDetents(sheet == .shop || sheet == .result ? [.large] : [.medium, .large])
        }
        // 手応えの表（README）：押す・落とす・合体・大きな合体・出荷・危ない・終わり・目標/季節
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.dropTick) { _, _ in model.hapticsOn ? .impact(weight: .light, intensity: 0.6) : nil }
        .sensoryFeedback(trigger: model.mergeTick) { _, _ in model.hapticsOn ? .impact(flexibility: .soft, intensity: 0.8) : nil }
        .sensoryFeedback(trigger: model.bigMergeTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .sensoryFeedback(trigger: model.harvestTick) { _, _ in model.hapticsOn ? .impact(flexibility: .rigid, intensity: 0.9) : nil }
        .sensoryFeedback(trigger: model.warnTick) { _, _ in model.hapticsOn ? .warning : nil }
        .sensoryFeedback(trigger: model.failTick) { _, _ in model.hapticsOn ? .error : nil }
        .sensoryFeedback(trigger: model.clearTick) { _, _ in model.hapticsOn ? .success : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load(); model.syncPro() }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.backgrounded() }
            guard phase == .active, !model.still, !Launch.isDemo else { return }
            model.now = Date()
        }
        .environment(\.locale, Lang.locale)
    }
}

struct SheetContent: View {
    let sheet: ActiveSheet

    var body: some View {
        switch sheet {
        case .shop: ShopSheet()
        case .result: ResultSheet()
        case .almanac: AlmanacSheet()
        case .settings: SettingsSheet()
        case .paywall: PaywallSheet()
        }
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static let shared: AppModel = makeModel()

    /// 撮影の日（決まった日にして、今日の畑が毎回同じになるように）
    static func stageDate() -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 21, minute: 30)) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["save", "onboarded", "sound", "haptics", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            let model = AppModel(persists: false, now: stageDate())
            model.soundOn = false
            model.calm = true
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let model = AppModel(persists: false, now: stageDate())
        model.still = scene != nil
        let name = scene ?? ""
        model.onboarded = !name.hasPrefix("onboarding")
        model.onboardingPage = name == "onboarding2" ? 1 : (name == "onboarding3" ? 2 : 0)
        if name != "empty" && !name.hasPrefix("onboarding") {
            model.save = sampleSave(model)
        }
        return model
    }

    /// 見本：遊んで 5 日目くらい
    static func sampleSave(_ model: AppModel) -> SaveData {
        var s = SaveData()
        for season in Season.allCases {
            for t in 0...(season == .spring ? 6 : (season == .summer ? 5 : 3)) { _ = s.noteGrown(Crop(season: season, tier: t)) }
        }
        s.bestScore = 742
        s.bestProgress = 5
        s.runs = 9
        s.streak = 4
        s.bestStreak = 6
        s.lastDaily = model.yesterday
        for (i, v) in [212, 380, 455, 0, 512, 742].enumerated() where v > 0 {
            s.daily[Days.offset(model.now, days: -(6 - i), calendar: model.calendar)] = v
        }
        return s
    }

    /// 箱に作物を並べる（下から詰める。箱の縦横比はおよそ 1.35）
    static func pack(_ crops: [Crop]) -> [PlacedCrop] {
        let ratio = 1.35
        var out: [PlacedCrop] = []
        var x = 0.02
        var rowBase = 0.0
        var rowHeight = 0.0
        for c in crops {
            let r = CropBook.radius(c)
            if x + r * 2 > 0.98 {
                x = 0.02
                rowBase += rowHeight
                rowHeight = 0
            }
            let ry = r / ratio
            out.append(PlacedCrop(crop: c, x: x + r, y: rowBase + ry * 1.02, angle: Double(out.count % 3) * 0.2 - 0.2))
            x += r * 2 + 0.005
            rowHeight = max(rowHeight, ry * 2)
        }
        return out
    }

    static func sampleCrops(_ s: Season, pro: Bool = false) -> [Crop] {
        // 同じ段を入れない（撮影の途中で合体が起きないように）
        let tiers = pro ? [7, 5, 3, 6, 4, 2, 1, 0] : [5, 3, 6, 4, 2, 1, 0]
        return tiers.map { Crop(season: s, tier: $0) }
    }

    /// 見本の畑（季節・何日目・売上）
    static func stage(_ model: AppModel, season: Season, year: Int = 1, day: Int = 9, sales: Int? = nil, pro: Bool = false) {
        var farm = Farm(seed: model.mode.seed, isPro: pro)
        farm.season = season
        farm.year = year
        farm.days = season.baseDays
        farm.target = Farm.target(season, year: year, charm: false)
        farm.day = day
        farm.drawn = day
        farm.seasonSales = sales ?? farm.target * 3 / 5
        farm.totalSales = farm.seasonSales + (season == .spring && year == 1 ? 0 : 214)
        farm.scarecrows = 1
        farm.cans = season == .spring ? 0 : 1
        farm.seasonsCleared = season.rawValue + (year - 1) * 4
        model.farm = farm
        model.scene.load(pack(sampleCrops(season, pro: pro)))
        model.scene.setAim(0.42)
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        if !scene.hasPrefix("onboarding") && scene != "empty" && scene != "fresh" {
            stage(model, season: .spring)
        }
        try? await Task.sleep(for: .milliseconds(200))
        switch scene {
        case "farm": break
        case "rain":
            if let d = (0..<22).first(where: { model.farm.weather(onDay: $0) == .rain }) { model.farm.day = d; model.farm.drawn = d }
            model.scene.refreshGhost()
            model.showBanner(tr("今日は雨", "Rainy day"), tr("合体が 2 段育つ。大物を狙おう", "Merges grow 2 steps. Go big"), tint: .rain)
        case "reached":
            model.farm.seasonSales = model.farm.target + 12
            model.showBanner(tr("出荷の目標に届いた！", "Shipping goal reached!"), tr("下の「次の季節へ」で進める。残った日は手当てになる", "Tap Next season below. Leftover days pay a bonus"), tint: .good)
        case "summer": stage(model, season: .summer, day: 6)
        case "autumn": stage(model, season: .autumn, day: 14)
        case "winter": stage(model, season: .winter, year: 2, day: 11)
        case "greenhouse":
            model.proOverride = true
            model.save.skin = .greenhouse
            stage(model, season: .summer, day: 8, pro: true)
        case "dusk":
            model.proOverride = true
            model.save.skin = .dusk
            stage(model, season: .autumn, day: 12, pro: true)
        case "shop":
            model.farm.seasonSales = model.farm.target + 18
            model.advanceSeason()
        case "result":
            stage(model, season: .autumn, year: 1, day: 22, sales: 70)
            model.farm.totalSales = 455
            model.farm.bestCrop = Crop(season: .summer, tier: 6)
            model.farm.over = true
            model.result = RunResult(score: 455, year: 1, season: .autumn, best: Crop(season: .summer, tier: 6), daily: true)
            model.activeSheet = .result
        case "almanac", "empty": model.activeSheet = .almanac
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        default: break
        }
        // 物理が落ち着いたら描画を止める（撮影の絵を止める。動き続ける描画が右上の黒い丸の原因になる）
        try? await Task.sleep(for: .milliseconds(1800))
        model.scenePaused = true
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 春の畑 → 落として連鎖の合体（いちご→そらまめ→にんじん→キャベツ）→ 出荷して目標に届く → 店で堆肥 → 夏の空へ
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .milliseconds(Int(s * 1000))) }
        model.soundOn = true
        model.onboarded = true
        var farm = Farm(seed: model.mode.seed)
        farm.day = 12
        farm.drawn = 12
        farm.seasonSales = 18
        model.farm = farm
        // 連鎖が起きる並び：にんじん・そらまめ・いちごが右へ並び、いちごの上に落とす
        let s = Season.spring
        model.scene.load([
            PlacedCrop(crop: Crop(season: s, tier: 5), x: 0.17, y: 0.1),
            PlacedCrop(crop: Crop(season: s, tier: 4), x: 0.45, y: 0.08),
            PlacedCrop(crop: Crop(season: s, tier: 3), x: 0.67, y: 0.065),
            PlacedCrop(crop: Crop(season: s, tier: 2), x: 0.85, y: 0.05),
            PlacedCrop(crop: Crop(season: s, tier: 1), x: 0.93, y: 0.15),
            PlacedCrop(crop: Crop(season: s, tier: 0), x: 0.1, y: 0.3),
        ])
        await wait(1.2)
        model.showBanner(tr("今日の畑", "Today's field"), tr("なぞって、離すと落ちる", "Drag, then release to drop"))
        for x in stride(from: 0.4, through: 0.66, by: 0.04) {
            model.scene.setAim(x)
            await wait(0.06)
        }
        await wait(0.4)
        demoDrop(model, Crop(season: s, tier: 3), x: 0.67)
        await wait(3.2)
        // 小さな種も落として、次の日へ
        model.scene.setAim(0.86)
        await wait(0.4)
        demoDrop(model, Crop(season: s, tier: 2), x: 0.86)
        await wait(1.8)
        // いちばん大きな作物を出荷
        model.harvestButton()
        await wait(1.4)
        model.harvestButton()
        await wait(2.2)
        if model.farm.seasonSales < model.farm.target {
            model.farm.seasonSales = model.farm.target
        }
        model.advanceSeason()
        await wait(2.6)
        model.choose(model.offers.first)
        await wait(3.0)
    }

    /// デモだけ：落とす作物を決めて落とす（1 日進む）
    private static func demoDrop(_ model: AppModel, _ crop: Crop, x: Double) {
        model.farm.day += 1
        model.farm.drawn += 1
        model.scene.spawn(crop, x: x)
        model.dropTick += 1
        model.play(.drop)
        model.scene.refreshGhost()
    }
}
