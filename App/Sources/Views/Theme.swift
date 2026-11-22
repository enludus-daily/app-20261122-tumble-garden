import SwiftUI
import UIKit

// 見た目のトークン（1 か所で決める）。世界：明るい昼の畑と、季節で変わる空。
// 主役は木の育て箱の断面（杉の板・土の層・小石）と、粘土細工のようにころんとした作物。
// 書体は太めの丸いサンセリフ（.rounded の heavy）を見出しと数字に、本文は .rounded の semibold。
// 部品は「粘土のおもちゃ」：角の丸い厚みのある札（下に濃い段＝厚み）。白いカード＋薄い影は使わない。
// 前日まで（夕暮れの等角の塔、夜の島、明朝の淡い 1 色）と並べて、明るい昼の屋外で差をつける。

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// 季節の色（空・遠くの畑・主な操作の色）。季節が変わると 1 秒かけて移る
struct SeasonPalette: Equatable {
    var skyTop: UInt32
    var skyLow: UInt32
    var hillFar: UInt32
    var hill: UInt32
    /// 主な操作（落とす）の色と、その下の厚み
    var accent: UInt32
    var accentDeep: UInt32
    /// 札の地（季節の光で少し色づく）
    var panel: UInt32
    var panelEdge: UInt32
    /// 空に散るもの（花びら・光・落ち葉・雪）
    var speck: UInt32

    static func of(_ season: Season) -> SeasonPalette {
        switch season {
        case .spring:
            SeasonPalette(skyTop: 0x86CDF0, skyLow: 0xEAF6DA, hillFar: 0xC8E3A0, hill: 0x99C866, accent: 0xEE7E9C, accentDeep: 0xB9506F, panel: 0xFFF7EC, panelEdge: 0xE8D3BE, speck: 0xF8C3D2)
        case .summer:
            SeasonPalette(skyTop: 0x2B86DA, skyLow: 0xBFE5FF, hillFar: 0x8FCB6A, hill: 0x58A846, accent: 0xF9A826, accentDeep: 0xB9700A, panel: 0xFFFAEE, panelEdge: 0xEAD7B4, speck: 0xFFFFFF)
        case .autumn:
            SeasonPalette(skyTop: 0xEE9E58, skyLow: 0xFCE4B8, hillFar: 0xE3B46C, hill: 0xC4863B, accent: 0xD95F2A, accentDeep: 0x963A14, panel: 0xFFF3E2, panelEdge: 0xE9C9A3, speck: 0xE07A2E)
        case .winter:
            SeasonPalette(skyTop: 0x93ABC6, skyLow: 0xEEF3F7, hillFar: 0xDCE5EE, hill: 0xF4F7FA, accent: 0x4F7FB6, accentDeep: 0x2F5482, panel: 0xF8FBFD, panelEdge: 0xC9D6E3, speck: 0xFFFFFF)
        }
    }
}

/// 木と土（育て箱）
enum Wood {
    static let plank = Color(hex: 0xC48B52)
    static let plankLight = Color(hex: 0xD9A56C)
    static let plankDark = Color(hex: 0x8C5A2F)
    static let grain = Color(hex: 0xA46E3D)
    static let nail = Color(hex: 0x6E6A66)
    static let soil = Color(hex: 0x6E4A31)
    static let soilDeep = Color(hex: 0x4F3322)
    static let soilTop = Color(hex: 0x8A5E3E)
    static let pebble = Color(hex: 0xA59684)
    static let worm = Color(hex: 0x3E281A)
}

/// 文字（真っ黒にしない。土の焦げ茶）
enum Ink {
    static let text = Color(hex: 0x3A2B20)
    static let soft = Color(hex: 0x6E5A4A)
    static let faint = Color(hex: 0xA08E7E)
    static let onAccent = Color.white
    static let danger = Color(hex: 0xD8463A)
    static let coin = Color(hex: 0xE9A922)
    static let coinDeep = Color(hex: 0xA8720E)
}

enum Fonts {
    /// 見出し・数字（太い丸ゴシック）
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded).monospacedDigit() }
    /// 本文
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func small(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

/// 角丸の段階（粘土の札・ボタン・シート）
enum Radius {
    static let chip: CGFloat = 10
    static let tile: CGFloat = 16
    static let button: CGFloat = 20
    static let sheet: CGFloat = 28
}

/// 厚み（下の濃い段）の段階。影は使わず、粘土の厚みで浮かせる
enum Ledge {
    static let small: CGFloat = 3
    static let button: CGFloat = 5
    static let big: CGFloat = 7
}

/// 粘土の札：地の色＋下に濃い段（厚み）＋上のふちに光
struct ClaySlab: View {
    var fill: Color
    var edge: Color
    var radius: CGFloat = Radius.tile
    var ledge: CGFloat = Ledge.small

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(edge)
                .offset(y: ledge)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
        }
        .allowsHitTesting(false)
    }
}

/// 押すと厚みのぶん沈むボタン（粘土を押した手応え）
struct ClayButtonStyle: ButtonStyle {
    var fill: Color
    var edge: Color
    var text: Color = Ink.onAccent
    var radius: CGFloat = Radius.button
    var ledge: CGFloat = Ledge.button

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(text)
            .offset(y: pressed ? ledge - 1 : 0)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(edge).offset(y: ledge)
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill).offset(y: pressed ? ledge - 1 : 0)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5)
                        .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                        .offset(y: pressed ? ledge - 1 : 0)
                }
            )
            .padding(.bottom, ledge)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

/// 作物の絵を SwiftUI で出す（size は葉の余白も入れた四角の大きさ）
struct CropImage: View {
    var crop: Crop
    var size: CGFloat
    var silhouette = false

    var body: some View {
        Image(uiImage: CropArt.image(crop, diameter: size / CropArt.canvasScale))
            .renderingMode(silhouette ? .template : .original)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Ink.text.opacity(0.18))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
