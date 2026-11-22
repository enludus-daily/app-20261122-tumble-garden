import Foundation
import Observation
import SwiftUI
import UIKit

enum ActiveSheet: String, Identifiable {
    case shop, result, almanac, settings, paywall
    var id: String { rawValue }
}

/// 上に出る短い知らせ
struct Banner: Equatable, Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var tint: BannerTint = .plain
}

enum BannerTint { case plain, good, warn, rain }

/// アプリ全体の状態。決まりは Farm（Model/Farm.swift）、物理と動きは FarmScene
@MainActor
@Observable
final class AppModel {
    // 保存するもの
    var save = SaveData()
    var onboarded = false
    var soundOn = true
    var hapticsOn = true
    var paywallOffered = false

    // 遊んでいる畑
    var mode: PlayMode
    var farm: Farm
    var now: Date
    let calendar: Calendar
    /// 店に並んでいる道具
    var offers: [Tool] = []
    /// 季節の片付けで売れた額（店の画面に出す）
    var lastCleanup = 0
    var keptCrop: Crop?
    var result: RunResult?

    // 画面
    var activeSheet: ActiveSheet?
    var banner: Banner?
    var reduceMotion = false
    /// UI テスト：動きを止める（動きを減らす設定と同じ扱い）
    var calm = false
    var motionOff: Bool { reduceMotion || calm }
    var still = false
    var proOverride = false
    var onboardingPage = 0
    /// 季節が変わった瞬間（空の色を 1 秒かけて移す）
    var seasonFlip = 0
    /// 撮影のとき、物理が落ち着いたら SpriteKit の描画を止める（止まった絵にする）
    var scenePaused = false
    /// 撮影のとき、箱の中を止まった絵に差し替える（SpriteKit の描画を画面から外す）
    var frozen: UIImage?

    // 手応え（sensoryFeedback の引き金）
    var pressTick = 0
    var dropTick = 0
    var mergeTick = 0
    var bigMergeTick = 0
    var harvestTick = 0
    var warnTick = 0
    var failTick = 0
    var clearTick = 0

    let purchases: PurchaseStore
    @ObservationIgnored let scene: FarmScene
    private let persists: Bool
    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private var reachedAnnounced = false

    static let proID = ProductID.pro(bundleID: Bundle.main.bundleIdentifier ?? "com.enludus.daily.004")

    init(persists: Bool = true, now: Date = Date(), calendar: Calendar = .current) {
        self.persists = persists
        self.now = now
        self.calendar = calendar
        purchases = PurchaseStore(productIDs: [AppModel.proID], proProductIDs: [AppModel.proID])
        let today = Days.key(now, calendar: calendar)
        mode = .daily(today)
        farm = Farm(seed: PlayMode.daily(today).seed)
        scene = FarmScene(size: CGSize(width: 340, height: 440))
        scene.model = self
        if persists { load() }
        if let run = save.current {
            mode = run.mode
            farm = run.farm
            scene.load(run.crops)
            reachedAnnounced = farm.targetReached
        } else {
            scene.load(AppModel.starter(farm.season))
        }
    }

    /// 新しい畑の最初の作物（空の箱から始めない。最初の 1 回で合体が起きやすい並び）
    static func starter(_ season: Season) -> [PlacedCrop] {
        [
            PlacedCrop(crop: Crop(season: season, tier: 2), x: 0.22, y: 0.06),
            PlacedCrop(crop: Crop(season: season, tier: 1), x: 0.52, y: 0.045),
            PlacedCrop(crop: Crop(season: season, tier: 0), x: 0.78, y: 0.035),
        ]
    }

    var today: String { Days.key(now, calendar: calendar) }
    var yesterday: String { Days.offset(now, days: -1, calendar: calendar) }
    var isPro: Bool { proOverride || purchases.entitlements.isPro }
    var streak: Int { save.currentStreak(today: today, yesterday: yesterday) }
    var palette: SeasonPalette { SeasonPalette.of(farm.season) }
    var canPlay: Bool { onboarded && !farm.over && !farm.shopping && activeSheet == nil }
    var playedToday: Bool { save.daily[today] != nil }

    var modeTitle: String {
        switch mode {
        case .daily(let d): d == today ? tr("今日の畑", "Today's field") : trf("%@ の畑", "Field of %@", Days.short(d))
        case .free: tr("自由な畑", "Free field")
        }
    }

    /// Pro を買った・戻した：品評会の作物と店の 4 つ目を開ける
    func syncPro() {
        if farm.isPro != isPro {
            farm.isPro = isPro
            scene.refreshGhost()
        }
    }

    // MARK: 保存（できごとのたびに 1 回。毎秒は保存しない）

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: "save"), let s = try? JSONDecoder().decode(SaveData.self, from: data) { save = s }
        onboarded = d.bool(forKey: "onboarded")
        soundOn = d.object(forKey: "sound") as? Bool ?? true
        hapticsOn = d.object(forKey: "haptics") as? Bool ?? true
        paywallOffered = d.bool(forKey: "paywallOffered")
    }

    /// 季節の終わり・遊びの終わり・裏に回ったとき・設定を変えたときに呼ぶ
    func persist() {
        if !farm.over {
            save.current = RunSave(mode: mode, farm: farm, crops: scene.snapshot())
        }
        guard persists else { return }
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(save) { d.set(data, forKey: "save") }
        d.set(onboarded, forKey: "onboarded")
        d.set(soundOn, forKey: "sound")
        d.set(hapticsOn, forKey: "haptics")
        d.set(paywallOffered, forKey: "paywallOffered")
    }

    func setSound(_ on: Bool) { soundOn = on; persist() }
    func setHaptics(_ on: Bool) { hapticsOn = on; persist() }

    func setSkin(_ skin: BoxSkin) {
        guard !skin.isPro || isPro else {
            activeSheet = .paywall
            return
        }
        save.skin = skin
        persist()
    }

    func finishOnboarding() {
        withAnimation(motionOff ? nil : .easeOut(duration: 0.35)) { onboarded = true }
        persist()
        play(.season)
        showBanner(modeTitle, tr("なぞって、離すと落ちる。同じ作物で合体", "Drag, release to drop. Match crops to merge"))
    }

    // MARK: 遊びを始める

    func start(_ newMode: PlayMode) {
        mode = newMode
        farm = Farm(seed: newMode.seed, isPro: isPro)
        result = nil
        reachedAnnounced = false
        scene.load(AppModel.starter(farm.season))
        scene.setAim(0.5)
        seasonFlip += 1
        activeSheet = nil
        persist()
        play(.season)
        showBanner(modeTitle, farm.season.rule)
    }

    func startFree() { start(.free(UInt64.random(in: 1...UInt64.max - 1))) }

    func startDaily(_ day: String? = nil) {
        let d = day ?? today
        if d != today, !isPro {
            activeSheet = .paywall
            return
        }
        start(.daily(d))
    }

    // MARK: 遊びの手続き（FarmScene とボタンから）

    /// 落とす（いまの落とす所に）
    func drop() {
        guard canPlay else { return }
        if farm.outOfDays {
            closeSeason()
            return
        }
        guard scene.canDrop else { return }
        let x = scene.landingRatio
        guard let crop = farm.drop() else { return }
        scene.spawn(crop, x: x)
        if save.noteGrown(crop) { newCrop(crop) }
        dropTick += 1
        play(.drop)
        scene.refreshGhost()
        if farm.outOfDays {
            showBanner(tr("最後の日", "Last day"), farm.targetReached
                ? tr("目標に届いた。次の季節へ進もう", "Goal reached. On to the next season")
                : tr("出荷して目標に届かせよう。終わったら「締める」", "Ship to reach the goal, then tap Close"), tint: .warn)
        } else if farm.today == .rain {
            showBanner(tr("今日は雨", "Rainy day"), tr("合体が 2 段育つ。大物を狙おう", "Merges grow 2 steps. Go big"), tint: .rain)
        }
    }

    func pressed() {
        pressTick += 1
        play(.tap)
    }

    /// 同じ作物が触れた（FarmScene から）
    func merged(_ crop: Crop) -> MergeOutcome {
        let outcome = farm.merge(crop)
        switch outcome {
        case .grow(let grown, let rain):
            if save.noteGrown(grown) { newCrop(grown) }
            if grown.tier >= 4 || rain { bigMergeTick += 1 } else { mergeTick += 1 }
            play(.merge(grown.tier))
            if rain { play(.rain) }
        case .prize:
            bigMergeTick += 1
            play(.prize)
        }
        checkReached()
        return outcome
    }

    /// 出荷した（FarmScene から）。売れた額
    func harvested(_ crop: Crop) -> Int? {
        guard let coins = farm.harvest(crop) else { return nil }
        harvestTick += 1
        play(.harvest)
        checkReached()
        return coins
    }

    /// 出荷のボタン：いちばん上の出荷できる作物
    func harvestButton() {
        guard canPlay else { return }
        pressed()
        if !scene.harvestTop() {
            showBanner(tr("まだ出荷できない", "Nothing to ship yet"),
                       trf("%@ より大きく育ててから", "Grow crops to %@ or bigger first", CropBook.info(Crop(season: farm.season, tier: farm.minHarvestTier)).name), tint: .warn)
            missTick()
        }
    }

    /// じょうろ：今日を雨に
    func water() {
        guard canPlay else { return }
        if farm.cans == 0 {
            showBanner(tr("じょうろがない", "No watering can"), tr("季節の終わりの店で手に入る", "Pick one up at the season shop"), tint: .warn)
            missTick()
            return
        }
        if farm.water() {
            pressed()
            play(.rain)
            showBanner(tr("今日は雨にした", "Made it rain today"), tr("この日の合体は 2 段育つ", "Merges today grow 2 steps"), tint: .rain)
            scene.refreshGhost()
        }
    }

    func warned() {
        warnTick += 1
        play(.warn)
    }

    /// あふれた（FarmScene から）。かかしで助かったら true
    func overflowed() -> Bool {
        if farm.overflow() {
            warnTick += 1
            play(.warn)
            return true
        }
        endRun(reason: tr("箱からあふれた", "The bed overflowed"))
        return false
    }

    private func missTick() {
        warnTick += 1
        play(.miss)
    }

    private func newCrop(_ crop: Crop) {
        guard crop.tier >= 2 else { return }
        showBanner(trf("はじめての %@", "First %@", CropBook.info(crop).name), tr("図鑑に入った", "Added to your almanac"), tint: .good)
    }

    private func checkReached() {
        if farm.targetReached && !reachedAnnounced {
            reachedAnnounced = true
            clearTick += 1
            play(.goal)
            showBanner(tr("出荷の目標に届いた！", "Shipping goal reached!"), tr("下の「次の季節へ」で進める。残った日は手当てになる", "Tap Next season below. Leftover days pay a bonus"), tint: .good)
        }
    }

    // MARK: 季節

    /// 締める：目標に届いていれば次の季節へ、届いていなければその年で終わり
    func closeSeason() {
        if farm.targetReached {
            advanceSeason()
        } else if farm.closeIfFailed() {
            endRun(reason: tr("目標に届かなかった", "Missed the shipping goal"))
        }
    }

    /// 次の季節へ（目標に届いたあと）
    func advanceSeason() {
        guard farm.targetReached, !farm.shopping, !farm.over else { return }
        pressed()
        guard let end = farm.endSeason(leftovers: scene.leftovers()) else { return }
        keptCrop = end.kept
        lastCleanup = end.sold
        offers = farm.shopOffers()
        scene.clearForSeason(keep: end.kept)
        clearTick += 1
        play(.season)
        persist()
        activeSheet = .shop
    }

    /// 店で選んだ（nil は選ばない）
    func choose(_ tool: Tool?) {
        guard farm.shopping else { return }
        if tool == nil || offers.contains(tool!) {
            farm.chooseAndAdvance(tool)
        }
        reachedAnnounced = false
        withAnimation(.easeInOut(duration: 1.0)) { seasonFlip += 1 }
        activeSheet = nil
        scene.refreshGhost()
        persist()
        pressTick += 1
        play(.season)
        let title = trf("%d年目の%@", "Year %d · %@", farm.year, farm.season.name)
        showBanner(title, farm.season.rule)
        // 価値を感じた直後（はじめて季節を越えたとき）にだけ、1 回 Pro を見せる
        if !paywallOffered && !isPro && farm.seasonsCleared == 1 && !still && !Launch.isDemo {
            paywallOffered = true
            persist()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                if self.activeSheet == nil { self.activeSheet = .paywall }
            }
        }
    }

    private func endRun(reason: String) {
        farm.over = true
        let r = save.finish(farm, mode: mode, today: today, yesterday: yesterday)
        result = r
        failTick += 1
        play(.over)
        scene.refreshGhost()
        persist()
        showBanner(reason, trf("%d年目の%@まで", "Reached Year %d, %@", r.year, r.season.name), tint: .warn)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(self.motionOff ? 100 : 1200))
            self.activeSheet = .result
        }
    }

    // MARK: 知らせ・音

    func showBanner(_ title: String, _ detail: String, tint: BannerTint = .plain) {
        bannerTask?.cancel()
        withAnimation(motionOff ? nil : .spring(response: 0.35, dampingFraction: 0.8)) { banner = Banner(title: title, detail: detail, tint: tint) }
        guard !still else { return }
        bannerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.banner = nil }
        }
    }

    func play(_ cue: SoundBox.Cue) {
        guard soundOn, !still else { return }
        SoundBox.shared.play(cue)
    }

    /// 裏に回った：途中を保存する
    func backgrounded() {
        guard !still, !Launch.isDemo else { return }
        persist()
    }
}
