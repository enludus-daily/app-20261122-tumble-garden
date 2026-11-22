import SwiftUI

/// 遊び方（最初の 1 回だけ 3 枚：落とす → 出荷する → 季節が進む）。設定からもう一度見られる
struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let page = model.onboardingPage
        ZStack {
            Backdrop(season: Season(rawValue: min(page, 3)) ?? .spring, skin: .cedar).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(tr("ころころ菜園", "Tumble Garden"))
                    .font(Fonts.title(30)).foregroundStyle(Ink.text)
                    .padding(.top, 18)
                Text(tr("落として合体、出荷して季節を進める", "Drop, merge, ship — and grow through the seasons"))
                    .font(Fonts.body(14)).foregroundStyle(Ink.soft).multilineTextAlignment(.center)
                VStack(spacing: 14) {
                    Group {
                        switch page {
                        case 0: DropMergeIllustration()
                        case 1: ShipIllustration()
                        default: SeasonsIllustration()
                        }
                    }
                    .frame(height: 230)
                    Text(title(page)).font(Fonts.title(22)).foregroundStyle(Ink.text).multilineTextAlignment(.center)
                    Text(detail(page)).font(Fonts.body(15)).foregroundStyle(Ink.soft).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: 520)
                .background(ClaySlab(fill: Color(hex: 0xFFF8EC).opacity(0.95), edge: Color(hex: 0xE2CBB2), radius: Radius.sheet, ledge: Ledge.big))
                .padding(.horizontal, 18)
                .id(page)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                Spacer(minLength: 0)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == page ? Ink.text : Ink.faint.opacity(0.4)).frame(width: i == page ? 22 : 8, height: 8)
                }
                Spacer(minLength: 12)
                if page < 2 {
                    Button {
                        model.pressed()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { model.onboardingPage += 1 }
                    } label: {
                        Text(tr("つぎへ", "Next")).font(Fonts.title(18)).frame(width: 150, height: 52)
                    }
                    .buttonStyle(ClayButtonStyle(fill: Color(hex: 0xEE7E9C), edge: Color(hex: 0xB9506F)))
                    .accessibilityIdentifier("main.onboardNext")
                } else {
                    Button { model.finishOnboarding() } label: {
                        Text(tr("畑をはじめる", "Start farming")).font(Fonts.title(18)).frame(width: 190, height: 52)
                    }
                    .buttonStyle(ClayButtonStyle(fill: Color(hex: 0x5BAE4C), edge: Color(hex: 0x37792E)))
                    .accessibilityIdentifier("main.onboardStart")
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 8).padding(.top, 8)
        }
    }

    private func title(_ page: Int) -> String {
        switch page {
        case 0: tr("なぞって、離すと落ちる", "Drag, then release to drop")
        case 1: tr("大きく育てて出荷する", "Grow big, then ship")
        default: tr("目標に届けば、次の季節へ", "Hit the goal, move to the next season")
        }
    }

    private func detail(_ page: Int) -> String {
        switch page {
        case 0: tr("同じ作物がふれると合体して一段大きく育つ。雨の日は 2 段。1 回落とすと 1 日が過ぎる", "Matching crops merge and grow a step — two on rainy days. Each drop is one day")
        case 1: tr("いちごの段から上は、長押しか「出荷」で出荷箱へ。大きいほど高く売れる。点線の上に 2 秒いたらあふれ", "From strawberries up, long-press or tap Ship to sell. Bigger sells higher. Stay above the dotted line 2 s and it overflows")
        default: tr("季節ごとに作物の段が入れ替わる。天気予報を見て、雨の日に大物を狙おう。店で道具を 1 つ選べる", "Each season swaps the crop ladder. Watch the forecast and go big on rainy days. Pick a tool at the shop")
        }
    }
}

/// 1 枚目：同じ作物 2 つ → 合体
struct DropMergeIllustration: View {
    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 4) {
                CropImage(crop: Crop(season: .spring, tier: 3), size: 62).rotationEffect(.degrees(-8))
                CropImage(crop: Crop(season: .spring, tier: 3), size: 62).rotationEffect(.degrees(10))
            }
            Image(systemName: "arrow.right").font(.system(size: 22, weight: .heavy)).foregroundStyle(Ink.faint)
            CropImage(crop: Crop(season: .spring, tier: 4), size: 110)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MiniBed())
    }
}

/// 2 枚目：作物 → 出荷箱
struct ShipIllustration: View {
    var body: some View {
        HStack(spacing: 14) {
            CropImage(crop: Crop(season: .summer, tier: 5), size: 110)
            Image(systemName: "arrow.right").font(.system(size: 22, weight: .heavy)).foregroundStyle(Ink.faint)
            VStack(spacing: 6) {
                CrateGlyph(fill: 0.7).frame(width: 90, height: 72)
                Text("+80").font(Fonts.number(26)).foregroundStyle(Ink.coinDeep)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MiniBed())
    }
}

/// 3 枚目：4 つの季節の段
struct SeasonsIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Season.allCases, id: \.self) { s in
                HStack(spacing: 8) {
                    Text(s.name).font(Fonts.title(14)).foregroundStyle(Ink.onAccent)
                        .frame(width: 44, height: 26)
                        .background(ClaySlab(fill: Color(hex: SeasonPalette.of(s).accent), edge: Color(hex: SeasonPalette.of(s).accentDeep), radius: Radius.chip))
                    LadderRow(season: s, upTo: 6)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 季節の段を小さく並べる
struct LadderRow: View {
    var season: Season
    var upTo: Int

    var body: some View {
        HStack(spacing: -2) {
            ForEach(2...upTo, id: \.self) { t in
                CropImage(crop: Crop(season: season, tier: t), size: 22 + CGFloat(t) * 3)
            }
        }
    }
}

/// 案内の絵の下に敷く、小さな育て箱
struct MiniBed: View {
    var body: some View {
        BedFrame(skin: .cedar, plank: 10, soil: 22)
            .opacity(0.55)
            .allowsHitTesting(false)
    }
}
