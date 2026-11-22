import Foundation

/// 箱の中の作物の置き場所（箱の幅・高さに対する割合。画面の大きさが変わっても戻せる）
struct PlacedCrop: Codable, Equatable, Sendable {
    var crop: Crop
    var x: Double
    var y: Double
    var angle: Double = 0
}

/// 遊びの種類
enum PlayMode: Codable, Hashable, Sendable {
    /// 今日の畑（日付シード。全員同じ種と天気）
    case daily(String)
    /// 自由な畑（毎回ちがう）
    case free(UInt64)

    var seed: UInt64 {
        switch self {
        case .daily(let d): seedFrom("tumble-" + d)
        case .free(let s): s
        }
    }

    var isDaily: Bool { if case .daily = self { true } else { false } }
}

/// 遊びの途中（裏に回ったとき・季節の終わりに保存する）
struct RunSave: Codable, Equatable, Sendable {
    var mode: PlayMode
    var farm: Farm
    var crops: [PlacedCrop]
}

/// 箱の見た目（Pro で 2 つ増える）
enum BoxSkin: String, Codable, CaseIterable, Sendable {
    case cedar, dusk, greenhouse

    var name: String {
        switch self {
        case .cedar: tr("杉の育て箱", "Cedar bed")
        case .dusk: tr("夕暮れの畑", "Dusk field")
        case .greenhouse: tr("温室", "Greenhouse")
        }
    }

    var isPro: Bool { self != .cedar }
}

/// 1 回の遊びの結果
struct RunResult: Codable, Equatable, Sendable {
    var score: Int
    var year: Int
    var season: Season
    var best: Crop?
    var daily: Bool
}

/// 保存するもの（できごとのたびに 1 回。毎秒は保存しない）
struct SaveData: Codable, Equatable, Sendable {
    /// 育てたことのある作物（図鑑）
    var grown: Set<String> = []
    var bestScore = 0
    /// いちばん先まで進んだ季節（(年-1)*4 + 季節）
    var bestProgress = 0
    var runs = 0
    var bestCrop: Crop?
    /// 今日の畑の日ごとのいちばんの売上
    var daily: [String: Int] = [:]
    var lastDaily: String?
    var streak = 0
    var bestStreak = 0
    var current: RunSave?
    var skin: BoxSkin = .cedar
    var lastResult: RunResult?

    /// 図鑑に作物を入れる。初めてなら true
    mutating func noteGrown(_ crop: Crop) -> Bool {
        if let b = bestCrop {
            if crop.tier > b.tier { bestCrop = crop }
        } else {
            bestCrop = crop
        }
        return grown.insert(crop.key).inserted
    }

    /// 1 回の遊びが終わった
    mutating func finish(_ farm: Farm, mode: PlayMode, today: String, yesterday: String) -> RunResult {
        runs += 1
        bestScore = max(bestScore, farm.totalSales)
        bestProgress = max(bestProgress, farm.progressIndex)
        if case .daily(let day) = mode {
            daily[day] = max(daily[day] ?? 0, farm.totalSales)
            if day == today {
                if lastDaily == today {
                    // 同じ日の 2 回目は続けた日数を変えない
                } else if lastDaily == yesterday {
                    streak += 1
                } else {
                    streak = 1
                }
                lastDaily = today
                bestStreak = max(bestStreak, streak)
            }
        }
        current = nil
        let result = RunResult(score: farm.totalSales, year: farm.year, season: farm.season, best: farm.bestCrop, daily: mode.isDaily)
        lastResult = result
        return result
    }

    /// いま続いている日数（昨日も今日も遊んでいなければ 0）
    func currentStreak(today: String, yesterday: String) -> Int {
        lastDaily == today || lastDaily == yesterday ? streak : 0
    }

    func grownCount(in season: Season) -> Int {
        (0..<Crop.tiers).filter { grown.contains(Crop(season: season, tier: $0).key) }.count
    }
}

enum Days {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    static func offset(_ date: Date, days: Int, calendar: Calendar = .current) -> String {
        key(calendar.date(byAdding: .day, value: days, to: date) ?? date, calendar: calendar)
    }

    /// "2026-11-22" → "11/22"
    static func short(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return key }
        return "\(m)/\(d)"
    }
}

/// 共有の文（今日の畑の結果。外には送らず、共有シートに渡すだけ）
enum ShareText {
    static func make(_ r: RunResult, day: String?) -> String {
        let where_ = trf("%d年目の%@まで", "Reached Year %d, %@", r.year, r.season.name)
        let crop = r.best.map { CropBook.info($0).name } ?? "—"
        let head = day.map { trf("ころころ菜園 %@ の畑", "Tumble Garden — field of %@", Days.short($0)) } ?? tr("ころころ菜園", "Tumble Garden")
        return head + "\n" + where_ + " / " + trf("売上 %d", "Sales %d", r.score) + " / " + trf("いちばんの作物：%@", "Best crop: %@", crop)
    }
}
