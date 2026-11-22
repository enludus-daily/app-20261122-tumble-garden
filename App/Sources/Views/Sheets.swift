import StoreKit
import SwiftUI

/// シートの枠：季節の札の地、題、閉じる
struct SheetFrame<Content: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var title: String
    var closable = true
    @ViewBuilder var content: Content

    var body: some View {
        let p = model.palette
        VStack(spacing: 0) {
            HStack {
                Text(title).font(Fonts.title(22)).foregroundStyle(Ink.text)
                Spacer()
                if closable {
                    Button { model.pressed(); dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).frame(width: 38, height: 34)
                    }
                    .buttonStyle(ClayButtonStyle(fill: Color(hex: p.panel), edge: Color(hex: p.panelEdge), text: Ink.soft, radius: Radius.chip + 4, ledge: Ledge.small))
                    .accessibilityLabel(tr("閉じる", "Close"))
                    .accessibilityIdentifier("main.close")
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)
            ScrollView {
                content.padding(.horizontal, 20).padding(.bottom, 24)
            }
        }
        .background(Color(hex: p.panel).ignoresSafeArea())
    }
}

// MARK: - 季節の終わりの店

struct ShopSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let farm = model.farm
        let p = model.palette
        SheetFrame(title: trf("%@の出荷おわり！", "%@ shipped!", farm.season.name), closable: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Stat(value: "\(farm.seasonSales)", label: trf("売上（目標 %d）", "Sales (goal %d)", farm.target))
                    Stat(value: "+\(model.lastCleanup)", label: tr("片付けと残りの日", "Leftovers & spare days"))
                    Stat(value: "\(farm.totalSales)", label: tr("今年の合計", "Run total"))
                }
                if let kept = model.keptCrop {
                    HStack(spacing: 10) {
                        CropImage(crop: kept, size: 54)
                        Text(trf("いちばん大きな%@を、次の季節へ持ち越す", "Your biggest crop carries over as %@", CropBook.info(kept).name))
                            .font(Fonts.body(14)).foregroundStyle(Ink.soft)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.white.opacity(0.6)))
                }
                Text(tr("道具を 1 つえらぶ", "Pick one tool")).font(Fonts.title(18)).foregroundStyle(Ink.text)
                ForEach(Array(model.offers.enumerated()), id: \.offset) { i, tool in
                    Button { model.choose(tool) } label: {
                        HStack(spacing: 12) {
                            ToolIcon(tool: tool).frame(width: 40, height: 40)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(Color(hex: p.skyLow)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tool.name).font(Fonts.title(17)).foregroundStyle(Ink.text)
                                Text(tool.detail).font(Fonts.body(13)).foregroundStyle(Ink.soft).multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if i == 3 { ProBadge() }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(ClayButtonStyle(fill: Color.white.opacity(0.85), edge: Color(hex: p.panelEdge), text: Ink.text, radius: Radius.tile, ledge: Ledge.small))
                    .accessibilityIdentifier("main.tool\(i)")
                }
                if !model.isPro {
                    Button { model.activeSheet = nil; Task { @MainActor in try? await Task.sleep(for: .milliseconds(400)); model.activeSheet = .paywall } } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text(tr("Pro なら、いつも 4 つから選べる", "With Pro, always choose from 4")).font(Fonts.body(13))
                        }
                        .foregroundStyle(Ink.soft).frame(maxWidth: .infinity).padding(10)
                        .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Ink.faint.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    }
                    .buttonStyle(.plain)
                    .opacity(0.9)
                }
                Text(trf("次は %@：%@", "Next: %@ — %@", farm.season.next.name, farm.season.next.rule))
                    .font(Fonts.body(13)).foregroundStyle(Ink.soft)
            }
        }
        .interactiveDismissDisabled(true)
    }
}

/// 店から Pro を見に行ったあと、店に戻れるように（季節の途中で止まらない）
extension AppModel {
    var needsShop: Bool { farm.shopping && activeSheet == nil }
}

struct Stat: View {
    var value: String
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Fonts.number(22)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(Fonts.small(11)).foregroundStyle(Ink.soft).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO").font(Fonts.small(10)).foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: 0x3B6FD8)))
    }
}

// MARK: - 1 年の結果

struct ResultSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let r = model.result ?? model.save.lastResult ?? RunResult(score: 0, year: 1, season: .spring, best: nil, daily: true)
        let p = model.palette
        SheetFrame(title: tr("今年はここまで", "Season's over")) {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(trf("%d年目の%@まで", "Reached Year %d, %@", r.year, r.season.name)).font(Fonts.title(18)).foregroundStyle(Ink.soft)
                    Text("\(r.score)").font(Fonts.number(56)).foregroundStyle(Ink.text)
                    Text(tr("売上の合計", "Total sales")).font(Fonts.small(12)).foregroundStyle(Ink.soft)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ClaySlab(fill: Color.white.opacity(0.8), edge: Color(hex: p.panelEdge), radius: Radius.tile, ledge: Ledge.button))
                if let best = r.best {
                    HStack(spacing: 12) {
                        CropImage(crop: best, size: 72)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("いちばんの作物", "Best crop")).font(Fonts.small(12)).foregroundStyle(Ink.soft)
                            Text(CropBook.info(best).name).font(Fonts.title(20)).foregroundStyle(Ink.text)
                        }
                        Spacer()
                    }
                }
                HStack(spacing: 12) {
                    Stat(value: "\(model.save.bestScore)", label: tr("いちばんの売上", "Best sales"))
                    Stat(value: "\(model.streak)", label: tr("今日の畑・続けた日", "Daily streak"))
                    Stat(value: "\(model.save.grown.count)/32", label: tr("図鑑", "Almanac"))
                }
                ShareLink(item: ShareText.make(r, day: r.daily ? model.dailyDay : nil)) {
                    Label(tr("結果を共有", "Share result"), systemImage: "square.and.arrow.up").font(Fonts.body(15)).frame(maxWidth: .infinity).frame(height: 46)
                }
                .buttonStyle(ClayButtonStyle(fill: Color.white.opacity(0.85), edge: Color(hex: p.panelEdge), text: Ink.text))
                Button { model.startFree() } label: {
                    Text(tr("自由な畑で、もう 1 年", "Another year (free field)")).font(Fonts.title(17)).frame(maxWidth: .infinity).frame(height: 52)
                }
                .buttonStyle(ClayButtonStyle(fill: Color(hex: p.accent), edge: Color(hex: p.accentDeep)))
                .accessibilityIdentifier("main.again")
                Button { model.startDaily() } label: {
                    Text(tr("今日の畑をもう一度", "Replay today's field")).font(Fonts.title(16)).frame(maxWidth: .infinity).frame(height: 46)
                }
                .buttonStyle(ClayButtonStyle(fill: Color(hex: 0x5BAE4C), edge: Color(hex: 0x37792E)))
                Text(tr("今日の畑は全員同じ種と天気。明日はまた別の畑", "Everyone gets the same seeds and weather today. A new field tomorrow"))
                    .font(Fonts.body(12)).foregroundStyle(Ink.soft).multilineTextAlignment(.center)
            }
        }
    }
}

extension AppModel {
    var dailyDay: String? { if case .daily(let d) = mode { d } else { nil } }
}

// MARK: - 図鑑と記録

struct AlmanacSheet: View {
    @Environment(AppModel.self) private var model
    @State private var confirmFree = false

    var body: some View {
        let save = model.save
        let p = model.palette
        SheetFrame(title: tr("図鑑と記録", "Almanac & records")) {
            VStack(alignment: .leading, spacing: 16) {
                if save.grown.isEmpty {
                    VStack(spacing: 6) {
                        Text(tr("まだ何も育てていない", "Nothing grown yet")).font(Fonts.title(17)).foregroundStyle(Ink.text)
                        Text(tr("畑に種を落とすと、育てた作物がここに並ぶ。32 種を集めよう", "Drop seeds in the bed and your crops show up here. Collect all 32"))
                            .font(Fonts.body(13)).foregroundStyle(Ink.soft).multilineTextAlignment(.center)
                        Button { model.activeSheet = nil } label: {
                            Text(tr("畑にもどる", "Back to the field")).font(Fonts.title(15)).frame(width: 180, height: 42)
                        }
                        .buttonStyle(ClayButtonStyle(fill: Color(hex: p.accent), edge: Color(hex: p.accentDeep)))
                    }
                    .frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.white.opacity(0.6)))
                }
                HStack(spacing: 10) {
                    Stat(value: "\(save.bestScore)", label: tr("いちばんの売上", "Best sales"))
                    Stat(value: progressText(save.bestProgress), label: tr("いちばん先の季節", "Furthest season"))
                    Stat(value: "\(model.streak)", label: trf("続けた日（最長 %d）", "Streak (best %d)", save.bestStreak))
                }
                DailyStrip()
                HStack(spacing: 10) {
                    Button { model.startDaily() } label: {
                        Text(tr("今日の畑", "Today's field")).font(Fonts.title(15)).frame(maxWidth: .infinity).frame(height: 44)
                    }
                    .buttonStyle(ClayButtonStyle(fill: Color(hex: 0x5BAE4C), edge: Color(hex: 0x37792E)))
                    .accessibilityIdentifier("main.newDaily")
                    Button { confirmFree = true } label: {
                        Text(tr("自由な畑", "Free field")).font(Fonts.title(15)).frame(maxWidth: .infinity).frame(height: 44)
                    }
                    .buttonStyle(ClayButtonStyle(fill: Color(hex: p.accent), edge: Color(hex: p.accentDeep)))
                    .accessibilityIdentifier("main.newFree")
                }
                .confirmationDialog(tr("いまの畑を終えて、自由な畑をはじめる？", "End this field and start a free one?"), isPresented: $confirmFree, titleVisibility: .visible) {
                    Button(tr("はじめる", "Start")) { model.startFree() }
                    Button(tr("やめる", "Cancel"), role: .cancel) {}
                }
                Text(trf("育てた作物 %d / 32", "Crops grown %d / 32", save.grown.count)).font(Fonts.title(18)).foregroundStyle(Ink.text)
                ForEach(Season.allCases, id: \.self) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(s.name).font(Fonts.title(14)).foregroundStyle(Ink.onAccent)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(Capsule().fill(Color(hex: SeasonPalette.of(s).accent)))
                            Text(s.rule).font(Fonts.small(11)).foregroundStyle(Ink.soft).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 6) {
                            ForEach(0..<Crop.tiers, id: \.self) { t in
                                CropCell(crop: Crop(season: s, tier: t))
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color(hex: SeasonPalette.of(s).skyLow).opacity(0.8)))
                }
            }
        }
    }

    private func progressText(_ i: Int) -> String {
        trf("%d 年目の%@", "Y%d %@", i / 4 + 1, (Season(rawValue: i % 4) ?? .spring).name)
    }
}

struct CropCell: View {
    @Environment(AppModel.self) private var model
    var crop: Crop

    var body: some View {
        let grown = model.save.grown.contains(crop.key)
        let locked = crop.tier == Crop.proTop && !model.isPro
        VStack(spacing: 2) {
            ZStack {
                CropImage(crop: crop, size: 54, silhouette: !grown)
                if locked && !grown {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Ink.soft)
                }
            }
            Text(grown ? CropBook.info(crop).name : "？").font(Fonts.small(10)).foregroundStyle(grown ? Ink.text : Ink.faint)
                .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
                .frame(height: 26)
        }
        .onTapGesture { if locked { model.activeSheet = .paywall } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(grown ? CropBook.info(crop).name : tr("まだ育てていない", "Not grown yet"))
    }
}

/// 過去 14 日の今日の畑（遊んだ日は売上。Pro は過去の日も遊べる）
struct DailyStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let days = (0..<14).reversed().map { Days.offset(model.now, days: -$0, calendar: model.calendar) }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tr("今日の畑（14 日）", "Daily fields (14 days)")).font(Fonts.title(15)).foregroundStyle(Ink.text)
                Spacer()
                if !model.isPro { HStack(spacing: 4) { ProBadge(); Text(tr("過去の日も遊べる", "Replay past days")).font(Fonts.small(10)).foregroundStyle(Ink.soft) } }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { d in
                        let score = model.save.daily[d]
                        Button { model.startDaily(d) } label: {
                            VStack(spacing: 2) {
                                Text(Days.short(d)).font(Fonts.small(10)).foregroundStyle(Ink.soft)
                                Text(score.map { "\($0)" } ?? "—").font(Fonts.number(13)).foregroundStyle(score == nil ? Ink.faint : Ink.text)
                            }
                            .frame(width: 48, height: 46)
                            .background(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).fill(d == model.today ? Color(hex: model.palette.accent).opacity(0.25) : Color.white.opacity(0.7)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 設定

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let p = model.palette
        SheetFrame(title: tr("設定", "Settings")) {
            VStack(alignment: .leading, spacing: 14) {
                Group {
                    Toggle(tr("効果音", "Sound effects"), isOn: Binding(get: { model.soundOn }, set: { model.setSound($0) }))
                    Toggle(tr("振動", "Haptics"), isOn: Binding(get: { model.hapticsOn }, set: { model.setHaptics($0) }))
                }
                .font(Fonts.body(16)).foregroundStyle(Ink.text).tint(Color(hex: p.accent))
                Text(tr("育て箱の見た目", "Bed style")).font(Fonts.title(16)).foregroundStyle(Ink.text)
                HStack(spacing: 8) {
                    ForEach(BoxSkin.allCases, id: \.self) { skin in
                        Button { model.setSkin(skin) } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Backdrop(season: model.farm.season, skin: skin)
                                    BedFrame(skin: skin, plank: 6, soil: 12)
                                    CropImage(crop: Crop(season: model.farm.season, tier: 4), size: 34).offset(y: 6)
                                }
                                .frame(height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous).strokeBorder(model.save.skin == skin ? Color(hex: p.accent) : .clear, lineWidth: 3))
                                HStack(spacing: 3) {
                                    Text(skin.name).font(Fonts.small(11)).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.7)
                                    if skin.isPro && !model.isPro { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(Ink.soft) }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider()
                Button { model.pressed(); model.activeSheet = .paywall } label: {
                    HStack {
                        ProBadge()
                        Text(model.isPro ? tr("Pro を使っています。ありがとう！", "You have Pro. Thank you!") : tr("Pro を見る", "See Pro")).font(Fonts.body(16))
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Ink.faint)
                    }
                    .foregroundStyle(Ink.text)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("main.seePro")
                Button {
                    Task { await model.purchases.restore() }
                } label: {
                    Text(tr("購入を復元", "Restore purchases")).font(Fonts.body(16)).foregroundStyle(Ink.text)
                }
                .buttonStyle(.plain)
                Button {
                    model.activeSheet = nil
                    model.onboardingPage = 0
                    withAnimation { model.onboarded = false }
                } label: {
                    Text(tr("遊び方をもう一度見る", "How to play")).font(Fonts.body(16)).foregroundStyle(Ink.text)
                }
                .buttonStyle(.plain)
                Link(tr("プライバシーポリシー", "Privacy policy"), destination: URL(string: "https://github.com/enludus-daily/app-20261122-tumble-garden/blob/main/PRIVACY.md")!)
                    .font(Fonts.body(16)).foregroundStyle(Ink.text)
                Text(tr("データはこの端末の中だけに保存します。通信・広告・追跡はありません。", "Your data stays on this device. No network, ads, or tracking."))
                    .font(Fonts.body(12)).foregroundStyle(Ink.soft)
            }
        }
    }
}

// MARK: - Pro

struct PaywallSheet: View {
    @Environment(AppModel.self) private var model
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        let p = model.palette
        let product = model.purchases.products.first
        SheetFrame(title: tr("ころころ菜園 Pro", "Tumble Garden Pro")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: -6) {
                    ForEach(Season.allCases, id: \.self) { s in
                        CropImage(crop: Crop(season: s, tier: Crop.proTop), size: 78)
                    }
                }
                .frame(maxWidth: .infinity)
                Feature(icon: "rosette", title: tr("品評会の作物 4 種", "4 prize crops"), detail: tr("いちばん上の段どうしが、もう一段育つ：メロン・ひまわり・おばけかぼちゃ・大きなかぶ", "Top crops grow one step further: melon, sunflower, giant pumpkin, giant turnip"))
                Feature(icon: "calendar", title: tr("過去 14 日の今日の畑", "Last 14 daily fields"), detail: tr("見のがした日の畑も、同じ種と天気で遊べる", "Play the days you missed with the same seeds and weather"))
                Feature(icon: "storefront", title: tr("店の道具を 4 つから選べる", "Shop offers 4 tools"), detail: tr("季節の終わりの選択肢が 1 つ増える", "One more choice at every season's end"))
                Feature(icon: "paintpalette", title: tr("育て箱の見た目 2 種", "2 bed styles"), detail: tr("夕暮れの畑・温室", "Dusk field and greenhouse"))
                Text(tr("無料でも 1 年を最後まで遊べます。広告はありません。", "The full year is free to play. No ads, ever."))
                    .font(Fonts.body(13)).foregroundStyle(Ink.soft)
                if model.isPro {
                    Text(tr("Pro を使っています。ありがとう！", "You have Pro. Thank you!")).font(Fonts.title(17)).foregroundStyle(Color(hex: 0x3C8A3A))
                        .frame(maxWidth: .infinity)
                } else {
                    Button {
                        guard let product else { return }
                        busy = true
                        Task {
                            let outcome = await model.purchases.purchase(product)
                            busy = false
                            switch outcome {
                            case .purchased: message = nil; model.syncPro(); model.clearTick += 1; model.play(.goal)
                            case .pending: message = tr("承認を待っています", "Waiting for approval")
                            case .failed: message = tr("購入できませんでした。もう一度お試しください", "Purchase failed. Please try again")
                            case .cancelled: break
                            }
                        }
                    } label: {
                        VStack(spacing: 1) {
                            Text(product.map { trf("%@ で Pro にする", "Get Pro for %@", $0.displayPrice) } ?? tr("Pro にする", "Get Pro")).font(Fonts.title(18))
                            Text(tr("1 回の購入で、ずっと", "One purchase, forever")).font(Fonts.small(11)).opacity(0.9)
                        }
                        .frame(maxWidth: .infinity).frame(height: 58)
                    }
                    .buttonStyle(ClayButtonStyle(fill: Color(hex: p.accent), edge: Color(hex: p.accentDeep)))
                    .disabled(product == nil || busy)
                    .accessibilityIdentifier("main.buyPro")
                    if model.purchases.loadState == .unavailable || (model.purchases.loadState == .ready && product == nil) {
                        Text(tr("App Store に接続できません。あとでもう一度お試しください", "Can't reach the App Store. Please try again later"))
                            .font(Fonts.body(12)).foregroundStyle(Ink.danger)
                    }
                    if let message { Text(message).font(Fonts.body(12)).foregroundStyle(Ink.soft) }
                    Button { Task { await model.purchases.restore(); model.syncPro() } } label: {
                        Text(tr("購入を復元", "Restore purchases")).font(Fonts.body(14)).foregroundStyle(Ink.soft).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct Feature: View {
    @Environment(AppModel.self) private var model
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: model.palette.accentDeep))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(hex: model.palette.skyLow)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Fonts.title(16)).foregroundStyle(Ink.text)
                Text(detail).font(Fonts.body(13)).foregroundStyle(Ink.soft).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
