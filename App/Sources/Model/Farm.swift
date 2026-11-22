import Foundation

// 畑の 1 年の決まり（SpriteKit から切り離した型。テストはここに書く）。
// 1 回落とす＝1 日。季節ごとに日数と出荷の目標があり、届けば次の季節へ、日数が尽きて届かなければその年で終わり。
// 同じ作物が触れると 1 段育つ（雨の日は 2 段）。いちばん上の段どうしは品評会へ出して大きく売れる。

/// 決まった種から同じ並びを出す乱数（今日の畑は全員同じ種・同じ天気）
struct SeededRNG: RandomNumberGenerator, Sendable {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<1 の小数
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// 文字列から種を作る（FNV-1a。日付 "2026-11-22" → 毎回同じ数）
func seedFrom(_ text: String) -> UInt64 {
    var h: UInt64 = 0xCBF2_9CE4_8422_2325
    for b in text.utf8 {
        h ^= UInt64(b)
        h = h &* 0x100_0000_01B3
    }
    return h
}

enum Season: Int, CaseIterable, Codable, Sendable {
    case spring, summer, autumn, winter

    var next: Season { Season(rawValue: (rawValue + 1) % 4) ?? .spring }

    var name: String {
        switch self {
        case .spring: tr("春", "Spring")
        case .summer: tr("夏", "Summer")
        case .autumn: tr("秋", "Autumn")
        case .winter: tr("冬", "Winter")
        }
    }

    /// 季節ごとの決まり（同じ遊びでも季節で考えることが変わる）
    var rule: String {
        switch self {
        case .spring: tr("春は雨が多い。雨の日の合体は 2 段育つ", "Spring brings rain. Rainy merges grow 2 steps")
        case .summer: tr("夏はよく育つ。芽から落ちてくる", "Summer grows fast. Sprouts fall more often")
        case .autumn: tr("実りの秋。出荷の値が 1.2 倍", "Harvest season. Crops sell for 1.2×")
        case .winter: tr("冬は日が短い。18 日で出荷する", "Short days. Only 18 days to ship")
        }
    }

    /// 季節の日数（手押し車で +4）
    var baseDays: Int { self == .winter ? 18 : 22 }

    /// 1 年目の出荷の目標
    var baseTarget: Int {
        switch self {
        case .spring: 60
        case .summer: 90
        case .autumn: 120
        case .winter: 110
        }
    }

    /// 雨・風の出やすさ（晴れは残り）
    var rainChance: Double { self == .spring ? 0.34 : (self == .winter ? 0.16 : 0.24) }
    var windChance: Double { self == .winter ? 0.08 : (self == .autumn ? 0.24 : 0.18) }

    /// 落ちてくる作物の段の出やすさ（0 段・1 段・2 段）
    var dropWeights: [Double] { self == .summer ? [0.28, 0.47, 0.25] : [0.5, 0.35, 0.15] }

    var priceRate: Double { self == .autumn ? 1.2 : 1 }
}

/// 作物（季節と段）。0 段＝種、1 段＝芽、6 段がいちばん上、7 段は Pro の品評会の作物
struct Crop: Hashable, Codable, Sendable {
    var season: Season
    var tier: Int

    static let freeTop = 6
    static let proTop = 7
    static let tiers = 8

    var key: String { "\(season.rawValue)-\(tier)" }

    /// 段ごとの値（段が上がるほど、種 1 つあたりの値が上がる）
    static let prices = [1, 3, 7, 16, 36, 80, 180, 400]

    var basePrice: Int { Crop.prices[min(max(tier, 0), Crop.tiers - 1)] }
}

enum Weather: String, Codable, CaseIterable, Sendable {
    case sunny, rain, wind

    var name: String {
        switch self {
        case .sunny: tr("晴れ", "Sunny")
        case .rain: tr("雨", "Rain")
        case .wind: tr("風", "Windy")
        }
    }

    var note: String {
        switch self {
        case .sunny: tr("ふつうの日", "A normal day")
        case .rain: tr("合体が 2 段育つ", "Merges grow 2 steps")
        case .wind: tr("落ちる所がずれる", "Drops drift sideways")
        }
    }
}

/// 季節の終わりの店の道具（3 つから 1 つ。Pro は 4 つから）
enum Tool: String, Codable, CaseIterable, Sendable {
    case scarecrow, compost, wateringCan, windbreak, bigCrate, wheelbarrow, charm

    var name: String {
        switch self {
        case .scarecrow: tr("かかし", "Scarecrow")
        case .compost: tr("堆肥", "Compost")
        case .wateringCan: tr("じょうろ", "Watering can")
        case .windbreak: tr("防風ネット", "Windbreak")
        case .bigCrate: tr("大きな出荷箱", "Big crate")
        case .wheelbarrow: tr("手押し車", "Wheelbarrow")
        case .charm: tr("豊作のお守り", "Harvest charm")
        }
    }

    var detail: String {
        switch self {
        case .scarecrow: tr("1 回だけ、箱からあふれても助かる", "Saves you once when the bed overflows")
        case .compost: tr("次の 3 つの種が 1 段育って落ちる", "Next 3 drops fall one step bigger")
        case .wateringCan: tr("好きな日を 1 回、雨の日にする", "Turn any one day into a rainy day")
        case .windbreak: tr("次の季節は風でずれない", "No wind drift next season")
        case .bigCrate: tr("次の季節は、いちごの段から出荷できる", "Next season, ship from step 3 up")
        case .wheelbarrow: tr("次の季節の日数が 4 日ふえる", "Next season lasts 4 more days")
        case .charm: tr("次の季節の目標が 15% 下がる", "Next season's goal is 15% lower")
        }
    }

    /// 次の季節だけ効く道具
    var isSeasonal: Bool { [.windbreak, .bigCrate, .wheelbarrow, .charm].contains(self) }
}

/// 合体の結果
enum MergeOutcome: Equatable, Sendable {
    /// 1 つの大きな作物になる（rainBoost：雨で 2 段育った）
    case grow(Crop, rainBoost: Bool)
    /// いちばん上の段どうし：品評会に出して売れる
    case prize(coins: Int)
}

/// 1 回の遊び（1 年目の春から、目標に届かなくなるまで）
struct Farm: Codable, Equatable, Sendable {
    let seed: UInt64
    var isPro: Bool

    var year = 1
    var season: Season = .spring
    /// 今日（この季節で何日目か。0 始まり。落とすたびに 1 進む）
    var day = 0
    var days: Int
    var target: Int
    var seasonSales = 0
    /// これまでの売上の合計（季節の片付けで売れた分も入る）
    var totalSales = 0
    /// これまでに落とした数（並びの番号）
    var drawn = 0

    var compost = 0
    var scarecrows = 0
    var cans = 0
    /// 今日だけ雨にした（じょうろ）
    var wateredDay: Int?
    /// この季節に効いている道具
    var perks: Set<Tool> = []
    /// 次の季節に効く道具
    var pendingPerks: Set<Tool> = []

    var over = false
    /// 季節が終わって、店で選ぶのを待っている
    var shopping = false
    var bestCrop: Crop?
    var seasonsCleared = 0

    init(seed: UInt64, isPro: Bool = false) {
        self.seed = seed
        self.isPro = isPro
        days = Season.spring.baseDays
        target = Farm.target(.spring, year: 1, charm: false)
    }

    static func target(_ season: Season, year: Int, charm: Bool) -> Int {
        let raw = Double(season.baseTarget) * (1 + 0.4 * Double(year - 1)) * (charm ? 0.85 : 1)
        return max(5, Int((raw / 5).rounded()) * 5)
    }

    var topTier: Int { isPro ? Crop.proTop : Crop.freeTop }
    var daysLeft: Int { max(0, days - day) }
    var targetReached: Bool { seasonSales >= target }
    var outOfDays: Bool { daysLeft == 0 }
    var minHarvestTier: Int { perks.contains(.bigCrate) ? 2 : 3 }
    /// 何年目の何の季節か（記録用。春＝0）
    var progressIndex: Int { (year - 1) * 4 + season.rawValue }

    // MARK: 天気

    private func roll(_ salt: UInt64, _ a: Int, _ b: Int) -> SeededRNG {
        SeededRNG(seed: seed ^ (salt &* 0x9E37_79B9) ^ (UInt64(a) &* 0x1000_0001) ^ (UInt64(b) &* 0xC2B2_AE35))
    }

    /// その日の天気（年・季節・日で決まる。じょうろの日は雨）
    func weather(onDay d: Int) -> Weather {
        if wateredDay == d { return .rain }
        var rng = roll(0x57EA, progressIndex, d)
        let x = rng.unit()
        if x < season.rainChance { return .rain }
        if x < season.rainChance + season.windChance { return .wind }
        return .sunny
    }

    var today: Weather { weather(onDay: day) }
    var tomorrow: Weather { weather(onDay: day + 1) }

    /// 風の日に落ちる所のずれ（箱の幅に対する割合。-0.14〜0.14）。防風ネットがあれば 0
    func drift(onDay d: Int) -> Double {
        guard weather(onDay: d) == .wind, !perks.contains(.windbreak) else { return 0 }
        var rng = roll(0x3D1F, progressIndex, d)
        let side: Double = rng.unit() < 0.5 ? -1 : 1
        return side * (0.08 + 0.06 * rng.unit())
    }

    var todayDrift: Double { drift(onDay: day) }

    // MARK: 落とす

    /// n 番目に落ちてくる作物の段（堆肥の前）
    private func baseTier(at index: Int) -> Int {
        var rng = roll(0xD20B, index, 0)
        let x = rng.unit()
        let w = season.dropWeights
        if x < w[0] { return 0 }
        if x < w[0] + w[1] { return 1 }
        return 2
    }

    /// これから落ちてくる作物（今の 1 つ目が次に落ちる）
    func upcoming(_ count: Int) -> [Crop] {
        (0..<count).map { i in
            let boost = i < compost ? 1 : 0
            return Crop(season: season, tier: baseTier(at: drawn + i) + boost)
        }
    }

    var nextCrop: Crop { upcoming(1)[0] }

    /// 1 つ落とす（1 日進む）。日数が尽きている・終わっている・店の途中なら nil
    mutating func drop() -> Crop? {
        guard !over, !shopping, !outOfDays else { return nil }
        let crop = nextCrop
        drawn += 1
        if compost > 0 { compost -= 1 }
        day += 1
        note(crop)
        return crop
    }

    /// 落としたあとの合体は「落とした日」の天気で決まる
    var mergeDay: Int { max(0, day - 1) }

    // MARK: 合体・出荷

    /// 同じ作物 2 つが触れた
    mutating func merge(_ crop: Crop) -> MergeOutcome {
        if crop.tier >= topTier {
            let coins = Int(Double(crop.basePrice * 3) * season.priceRate)
            seasonSales += coins
            totalSales += coins
            return .prize(coins: coins)
        }
        let rainy = weather(onDay: mergeDay) == .rain
        let up = rainy ? 2 : 1
        let grown = Crop(season: crop.season, tier: min(topTier, crop.tier + up))
        note(grown)
        return .grow(grown, rainBoost: rainy && grown.tier - crop.tier == 2)
    }

    func canHarvest(_ crop: Crop) -> Bool { !over && !shopping && crop.tier >= minHarvestTier }

    func price(_ crop: Crop) -> Int { Int((Double(crop.basePrice) * season.priceRate).rounded()) }

    /// 出荷箱へ。売れた額（出荷できない段なら nil）
    mutating func harvest(_ crop: Crop) -> Int? {
        guard canHarvest(crop) else { return nil }
        let coins = price(crop)
        seasonSales += coins
        totalSales += coins
        return coins
    }

    /// 箱からあふれた。かかしがあれば助かる（true）
    mutating func overflow() -> Bool {
        guard !over else { return false }
        if scarecrows > 0 {
            scarecrows -= 1
            return true
        }
        over = true
        return false
    }

    /// じょうろで今日を雨にする
    mutating func water() -> Bool {
        guard cans > 0, !over, !shopping, !outOfDays, today != .rain else { return false }
        cans -= 1
        wateredDay = day
        return true
    }

    /// 日数が尽きて目標に届かなかった
    mutating func closeIfFailed() -> Bool {
        guard outOfDays, !targetReached, !over else { return false }
        over = true
        return true
    }

    // MARK: 季節を進める

    /// 季節を締める。いちばん大きな 1 つを冬越しで残し、ほかは半値で売る
    mutating func endSeason(leftovers: [Crop]) -> (kept: Crop?, sold: Int)? {
        guard targetReached, !over, !shopping else { return nil }
        let sorted = leftovers.sorted { $0.tier > $1.tier }
        let kept = sorted.first.map { Crop(season: season.next, tier: min($0.tier, Crop.freeTop - 1)) }
        let sold = sorted.dropFirst().reduce(0) { $0 + price($1) / 2 }
        // 残った日は 1 日 2 の手当て
        let bonus = daysLeft * 2
        totalSales += sold + bonus
        seasonsCleared += 1
        shopping = true
        return (kept, sold + bonus)
    }

    /// 店に並ぶ道具（季節ごとに決まる。Pro は 4 つ）
    func shopOffers() -> [Tool] {
        var rng = roll(0x5409, progressIndex, 0)
        var all = Tool.allCases
        all.shuffle(using: &rng)
        return Array(all.prefix(isPro ? 4 : 3))
    }

    /// 店で道具を選んで、次の季節を始める（nil は何も選ばない）
    mutating func chooseAndAdvance(_ tool: Tool?) {
        guard shopping else { return }
        if let tool {
            switch tool {
            case .scarecrow: scarecrows += 1
            case .compost: compost += 3
            case .wateringCan: cans += 1
            case .windbreak, .bigCrate, .wheelbarrow, .charm: pendingPerks.insert(tool)
            }
        }
        if season == .winter { year += 1 }
        season = season.next
        perks = pendingPerks
        pendingPerks = []
        day = 0
        wateredDay = nil
        days = season.baseDays + (perks.contains(.wheelbarrow) ? 4 : 0)
        target = Farm.target(season, year: year, charm: perks.contains(.charm))
        seasonSales = 0
        shopping = false
    }

    private mutating func note(_ crop: Crop) {
        if let b = bestCrop {
            if crop.tier > b.tier { bestCrop = crop }
        } else {
            bestCrop = crop
        }
    }
}
