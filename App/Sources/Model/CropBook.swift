import Foundation

/// 作物の形（描き方と当たり判定。丸い果物を落とすだけの見た目にしないよう、作物ごとに形を変える）
enum CropShape: String, Sendable {
    case seed  // 小さなしずく形の種
    case sprout  // 双葉
    case round  // 丸い実（ミニトマト・かぶ）
    case berry  // いちご（下がとがる）
    case pod  // さや（そらまめ・オクラ）
    case root  // 根もの（にんじん・だいこん。縦長）
    case leafy  // 葉が巻く（キャベツ・はくさい）
    case long  // 細長い（とうもろこし・なす・ねぎ）
    case flat  // 平たい（かぼちゃ）
    case nut  // くり
    case cap  // きのこ
    case bloom  // ひまわり
    case melon  // 網目のある丸
}

struct CropInfo: Sendable {
    var ja: String
    var en: String
    var shape: CropShape
    /// 主な色・影の色・葉やへたの色
    var body: UInt32
    var shade: UInt32
    var leaf: UInt32
    /// 横 : 縦（当たり判定の楕円もこの比）
    var aspect: Double = 1

    var name: String { tr(ja, en) }
}

/// 季節ごとの 8 段（0 種 → 1 芽 → … → 6 いちばん上、7 は Pro の品評会の作物）
enum CropBook {
    static let allCrops: [Crop] = Season.allCases.flatMap { s in (0..<Crop.tiers).map { Crop(season: s, tier: $0) } }

    /// 段ごとの大きさ（箱の幅に対する半径の割合）
    static let radius: [Double] = [0.042, 0.056, 0.071, 0.088, 0.107, 0.13, 0.156, 0.19]

    static func radius(_ crop: Crop) -> Double { radius[min(max(crop.tier, 0), Crop.tiers - 1)] }

    static func info(_ crop: Crop) -> CropInfo {
        let ladder = ladders[crop.season] ?? ladders[.spring]!
        return ladder[min(max(crop.tier, 0), ladder.count - 1)]
    }

    private static let seed = CropInfo(ja: "種", en: "Seed", shape: .seed, body: 0xC69863, shade: 0x8E6439, leaf: 0x7FB04F, aspect: 0.82)
    private static let sprout = CropInfo(ja: "芽", en: "Sprout", shape: .sprout, body: 0x8CC65A, shade: 0x5E9A3A, leaf: 0xB4DE7C, aspect: 1.1)

    static let ladders: [Season: [CropInfo]] = [
        .spring: [
            seed, sprout,
            CropInfo(ja: "ラディッシュ", en: "Radish", shape: .round, body: 0xE65A6E, shade: 0xB23A52, leaf: 0x6FB04A),
            CropInfo(ja: "いちご", en: "Strawberry", shape: .berry, body: 0xEF4A52, shade: 0xB82D3B, leaf: 0x5FA843, aspect: 0.92),
            CropInfo(ja: "そらまめ", en: "Fava bean", shape: .pod, body: 0x9BCF6A, shade: 0x6A9E45, leaf: 0xD7EDB0, aspect: 1.55),
            CropInfo(ja: "にんじん", en: "Carrot", shape: .root, body: 0xF39133, shade: 0xC96A1C, leaf: 0x5DAA45, aspect: 0.6),
            CropInfo(ja: "キャベツ", en: "Cabbage", shape: .leafy, body: 0xA9D67C, shade: 0x77AE52, leaf: 0xDDF0BE),
            CropInfo(ja: "品評会のメロン", en: "Prize melon", shape: .melon, body: 0xB7D88A, shade: 0x84AE5E, leaf: 0xF3F7E4),
        ],
        .summer: [
            seed, sprout,
            CropInfo(ja: "ミニトマト", en: "Cherry tomato", shape: .round, body: 0xF2463A, shade: 0xBC2A25, leaf: 0x4F9A3C),
            CropInfo(ja: "オクラ", en: "Okra", shape: .pod, body: 0x76B851, shade: 0x4E8B36, leaf: 0xA9D884, aspect: 1.6),
            CropInfo(ja: "なす", en: "Eggplant", shape: .long, body: 0x6B3F8C, shade: 0x45265F, leaf: 0x4F8C3A, aspect: 0.7),
            CropInfo(ja: "とうもろこし", en: "Corn", shape: .long, body: 0xF6CF45, shade: 0xD6A324, leaf: 0x8CC25B, aspect: 0.55),
            CropInfo(ja: "すいか", en: "Watermelon", shape: .round, body: 0x3E9A4A, shade: 0x2A7034, leaf: 0x9BD07A, aspect: 1.08),
            CropInfo(ja: "品評会のひまわり", en: "Prize sunflower", shape: .bloom, body: 0xF7C531, shade: 0xD99A1A, leaf: 0x7A4E2A),
        ],
        .autumn: [
            seed, sprout,
            CropInfo(ja: "くり", en: "Chestnut", shape: .nut, body: 0x9A5B32, shade: 0x6B3A1E, leaf: 0xE2C49A),
            CropInfo(ja: "しいたけ", en: "Shiitake", shape: .cap, body: 0xA7704A, shade: 0x77482B, leaf: 0xF1E2C8, aspect: 1.15),
            CropInfo(ja: "さつまいも", en: "Sweet potato", shape: .pod, body: 0xB0476B, shade: 0x7F2E4C, leaf: 0xF0D59A, aspect: 1.5),
            CropInfo(ja: "かき", en: "Persimmon", shape: .round, body: 0xF08A2E, shade: 0xC2621A, leaf: 0x6E8E3A, aspect: 1.1),
            CropInfo(ja: "かぼちゃ", en: "Pumpkin", shape: .flat, body: 0xE9862C, shade: 0xB65F18, leaf: 0x6F8A3A, aspect: 1.3),
            CropInfo(ja: "品評会のおばけかぼちゃ", en: "Prize giant pumpkin", shape: .flat, body: 0xF2A23C, shade: 0xC5701E, leaf: 0x5E7E34, aspect: 1.35),
        ],
        .winter: [
            seed, sprout,
            CropInfo(ja: "かぶ", en: "Turnip", shape: .round, body: 0xF5F1EA, shade: 0xD3C9BC, leaf: 0x6DAE52),
            CropInfo(ja: "ねぎ", en: "Leek", shape: .long, body: 0xF2F4EA, shade: 0xC9D3B8, leaf: 0x5FA448, aspect: 0.5),
            CropInfo(ja: "だいこん", en: "Daikon", shape: .root, body: 0xF7F5EE, shade: 0xD5CFC2, leaf: 0x5E9F46, aspect: 0.55),
            CropInfo(ja: "ブロッコリー", en: "Broccoli", shape: .leafy, body: 0x4E9447, shade: 0x316B31, leaf: 0x9ACB7A),
            CropInfo(ja: "はくさい", en: "Napa cabbage", shape: .leafy, body: 0xE9F2C9, shade: 0xB9CC8E, leaf: 0x8DC066, aspect: 0.82),
            CropInfo(ja: "品評会の大きなかぶ", en: "Prize giant turnip", shape: .round, body: 0xF8F3F0, shade: 0xD8C4CC, leaf: 0x5DA849, aspect: 1.05),
        ],
    ]
}
