import Foundation
import Testing
@testable import TumbleGarden

// 畑の決まり（Farm）の振る舞い。SpriteKit の物理から切り離して確かめる。

/// 天気が条件に合う種と日を探す（日付シードは決まっているので、テストは毎回同じ）
private func findDay(_ want: Weather, in farm: Farm, from: Int = 0) -> Int? {
    (from..<60).first { farm.weather(onDay: $0) == want }
}

struct FarmBasicsTests {
    @Test func aNewFarmStartsInSpringOfYearOne() {
        let farm = Farm(seed: 1)
        #expect(farm.year == 1)
        #expect(farm.season == .spring)
        #expect(farm.daysLeft == Season.spring.baseDays)
        #expect(farm.target == 60)
        #expect(!farm.over)
    }

    @Test func theSameSeedGivesTheSameDropsAndWeather() {
        let a = Farm(seed: seedFrom("2026-11-22"))
        let b = Farm(seed: seedFrom("2026-11-22"))
        #expect(a.upcoming(30) == b.upcoming(30))
        #expect((0..<22).map { a.weather(onDay: $0) } == (0..<22).map { b.weather(onDay: $0) })
    }

    @Test func differentDaysGiveDifferentFields() {
        let a = Farm(seed: seedFrom("2026-11-22"))
        let b = Farm(seed: seedFrom("2026-11-23"))
        #expect(a.upcoming(30) != b.upcoming(30))
    }

    @Test func dropsAreSeedsSproutsOrSmallCrops() {
        let farm = Farm(seed: 42)
        let tiers = Set(farm.upcoming(200).map(\.tier))
        #expect(tiers.isSubset(of: [0, 1, 2]))
        #expect(tiers.count == 3)
    }

    @Test func droppingUsesADayAndShowsTheNextCrop() {
        var farm = Farm(seed: 7)
        let preview = farm.upcoming(3)
        let dropped = farm.drop()
        #expect(dropped == preview[0])
        #expect(farm.day == 1)
        #expect(farm.daysLeft == Season.spring.baseDays - 1)
        #expect(farm.nextCrop == preview[1])
    }

    @Test func noDropsAfterTheDaysRunOut() {
        var farm = Farm(seed: 7)
        for _ in 0..<farm.days { let d = farm.drop(); #expect(d != nil) }
        #expect(farm.outOfDays)
        let r1 = farm.drop()
        #expect(r1 == nil)
    }
}

struct MergeTests {
    @Test func twoSameCropsGrowOneStepOnASunnyDay() throws {
        var farm = Farm(seed: 3)
        let sunny = try #require(findDay(.sunny, in: farm))
        farm.day = sunny + 1  // 晴れの日に落とした直後
        let outcome = farm.merge(Crop(season: .spring, tier: 2))
        #expect(outcome == .grow(Crop(season: .spring, tier: 3), rainBoost: false))
    }

    @Test func rainMakesMergesGrowTwoSteps() throws {
        var farm = Farm(seed: 3)
        let rainy = try #require(findDay(.rain, in: farm))
        farm.day = rainy + 1
        let outcome = farm.merge(Crop(season: .spring, tier: 2))
        #expect(outcome == .grow(Crop(season: .spring, tier: 4), rainBoost: true))
    }

    @Test func rainNeverGrowsPastTheTop() throws {
        var farm = Farm(seed: 3)
        let rainy = try #require(findDay(.rain, in: farm))
        farm.day = rainy + 1
        let outcome = farm.merge(Crop(season: .spring, tier: Crop.freeTop - 1))
        #expect(outcome == .grow(Crop(season: .spring, tier: Crop.freeTop), rainBoost: false))
    }

    @Test func twoTopCropsGoToTheFairAndSell() {
        var farm = Farm(seed: 3)
        let outcome = farm.merge(Crop(season: .spring, tier: Crop.freeTop))
        #expect(outcome == .prize(coins: Crop.prices[Crop.freeTop] * 3))
        #expect(farm.seasonSales == Crop.prices[Crop.freeTop] * 3)
    }

    @Test func proGrowsThePrizeCropInstead() throws {
        var farm = Farm(seed: 3, isPro: true)
        let sunny = try #require(findDay(.sunny, in: farm))
        farm.day = sunny + 1
        let r2 = farm.merge(Crop(season: .spring, tier: Crop.freeTop))
        #expect(r2 == .grow(Crop(season: .spring, tier: Crop.proTop), rainBoost: false))
    }

    @Test func mergingRemembersTheBestCrop() throws {
        var farm = Farm(seed: 3)
        let sunny = try #require(findDay(.sunny, in: farm))
        farm.day = sunny + 1
        _ = farm.merge(Crop(season: .spring, tier: 4))
        #expect(farm.bestCrop == Crop(season: .spring, tier: 5))
    }

    @Test func wateringTurnsTodayIntoRain() throws {
        var farm = Farm(seed: 3)
        let sunny = try #require(findDay(.sunny, in: farm))
        farm.day = sunny
        farm.cans = 1
        let r3 = farm.water()
        #expect(r3)
        #expect(farm.today == .rain)
        #expect(farm.cans == 0)
        _ = farm.drop()
        let r4 = farm.merge(Crop(season: .spring, tier: 1))
        #expect(r4 == .grow(Crop(season: .spring, tier: 3), rainBoost: true))
    }

    @Test func windShiftsTheDropUnlessThereIsAWindbreak() throws {
        var farm = Farm(seed: 11)
        let windy = try #require(findDay(.wind, in: farm))
        #expect(farm.drift(onDay: windy) != 0)
        farm.perks.insert(.windbreak)
        #expect(farm.drift(onDay: windy) == 0)
        let sunny = try #require(findDay(.sunny, in: farm))
        #expect(farm.drift(onDay: sunny) == 0)
    }
}

struct HarvestAndSeasonTests {
    @Test func smallCropsCannotBeShipped() {
        var farm = Farm(seed: 5)
        let r5 = farm.harvest(Crop(season: .spring, tier: 2))
        #expect(r5 == nil)
        let r6 = farm.harvest(Crop(season: .spring, tier: 3))
        #expect(r6 == farm.price(Crop(season: .spring, tier: 3)))
        #expect(farm.seasonSales == r6)
    }

    @Test func aBigCrateLetsYouShipSmallerCrops() {
        var farm = Farm(seed: 5)
        farm.perks = [.bigCrate]
        let r7 = farm.harvest(Crop(season: .spring, tier: 2))
        #expect(r7 == Crop.prices[2])
    }

    @Test func autumnPaysMore() {
        var farm = Farm(seed: 5)
        farm.season = .autumn
        let crop = (3...5).map { Crop(season: .autumn, tier: $0) }.first { $0 != farm.marketPick }!
        #expect(farm.price(crop) == Int((Double(crop.basePrice) * 1.2).rounded()))
    }

    @Test func theMarketPickSellsForDouble() {
        let farm = Farm(seed: 5)
        let pick = farm.marketPick
        #expect((3...5).contains(pick.tier))
        #expect(pick.season == farm.season)
        #expect(farm.price(pick) == pick.basePrice * 2)
        #expect(Farm(seed: 5).marketPick == pick)
    }

    @Test func reachingTheTargetLetsTheSeasonAdvance() {
        var farm = Farm(seed: 5)
        #expect(farm.endSeason(leftovers: []) == nil)
        _ = farm.harvest(Crop(season: .spring, tier: 5))
        #expect(farm.targetReached)
        let end = farm.endSeason(leftovers: [Crop(season: .spring, tier: 1), Crop(season: .spring, tier: 4), Crop(season: .spring, tier: 3)])
        // いちばん大きな 1 つを次の季節の同じ段として残し、ほかは半値＋残りの日の手当て
        #expect(end?.kept == Crop(season: .summer, tier: 4))
        #expect(end?.sold == Crop.prices[1] / 2 + farm.price(Crop(season: .spring, tier: 3)) / 2 + farm.daysLeft * 2)
        #expect(farm.shopping)
        farm.chooseAndAdvance(nil)
        #expect(farm.season == .summer)
        #expect(farm.day == 0)
        #expect(farm.seasonSales == 0)
        #expect(farm.target == 90)
        #expect(!farm.shopping)
    }

    @Test func runningOutOfDaysShortOfTheTargetEndsTheYear() {
        var farm = Farm(seed: 5)
        for _ in 0..<farm.days { _ = farm.drop() }
        let r8 = farm.closeIfFailed()
        #expect(r8)
        #expect(farm.over)
        let r9 = farm.drop()
        #expect(r9 == nil)
    }

    @Test func overflowEndsTheRunUnlessAScarecrowHelps() {
        var farm = Farm(seed: 5)
        farm.scarecrows = 1
        let r10 = farm.overflow()
        #expect(r10)
        #expect(!farm.over)
        let o = farm.overflow()
        #expect(!o)
        #expect(farm.over)
    }

    @Test func afterWinterComesTheNextYearWithHigherGoals() {
        var farm = Farm(seed: 5)
        for _ in 0..<4 {
            farm.seasonSales = farm.target
            _ = farm.endSeason(leftovers: [])
            farm.chooseAndAdvance(nil)
        }
        #expect(farm.year == 2)
        #expect(farm.season == .spring)
        #expect(farm.target == Farm.target(.spring, year: 2, charm: false))
        #expect(farm.target > 60)
        #expect(farm.seasonsCleared == 4)
    }

    @Test func seasonalToolsWorkOnlyForTheNextSeason() {
        var farm = Farm(seed: 5)
        farm.seasonSales = farm.target
        _ = farm.endSeason(leftovers: [])
        farm.chooseAndAdvance(.wheelbarrow)
        #expect(farm.days == Season.summer.baseDays + 4)
        farm.seasonSales = farm.target
        _ = farm.endSeason(leftovers: [])
        farm.chooseAndAdvance(.charm)
        #expect(farm.days == Season.autumn.baseDays)
        #expect(farm.target == Farm.target(.autumn, year: 1, charm: true))
        #expect(farm.target < Farm.target(.autumn, year: 1, charm: false))
    }

    @Test func compostBoostsTheNextThreeDrops() {
        var farm = Farm(seed: 5)
        let plain = farm.upcoming(5)
        farm.seasonSales = farm.target
        _ = farm.endSeason(leftovers: [])
        farm.chooseAndAdvance(.compost)
        farm.season = .spring  // 同じ季節で並びを比べる
        let boosted = farm.upcoming(5)
        #expect(zip(plain.prefix(3), boosted.prefix(3)).allSatisfy { $1.tier == $0.tier + 1 })
        #expect(Array(plain.suffix(2)) == Array(boosted.suffix(2)))
        _ = farm.drop()
        #expect(farm.compost == 2)
    }

    @Test func theShopOffersThreeToolsOrFourWithPro() {
        let free = Farm(seed: 9).shopOffers()
        let pro = Farm(seed: 9, isPro: true).shopOffers()
        #expect(free.count == 3)
        #expect(Set(free).count == 3)
        #expect(pro.count == 4)
        #expect(Array(pro.prefix(3)) == free)
    }
}

struct CatalogTests {
    @Test func everySeasonHasEightCropsWithNamesInBothLanguages() {
        for season in Season.allCases {
            for tier in 0..<Crop.tiers {
                let info = CropBook.info(Crop(season: season, tier: tier))
                #expect(!info.ja.isEmpty)
                #expect(!info.en.isEmpty)
            }
        }
        #expect(CropBook.allCrops.count == 32)
        #expect(Set(CropBook.allCrops.map(\.key)).count == 32)
    }
}

struct RecordsTests {
    @Test func playingTodaysFieldOnConsecutiveDaysBuildsAStreak() {
        var save = SaveData()
        var farm = Farm(seed: 1)
        farm.totalSales = 120
        _ = save.finish(farm, mode: .daily("2026-11-21"), today: "2026-11-21", yesterday: "2026-11-20")
        #expect(save.streak == 1)
        _ = save.finish(farm, mode: .daily("2026-11-22"), today: "2026-11-22", yesterday: "2026-11-21")
        #expect(save.streak == 2)
        // 同じ日の 2 回目は数えない
        _ = save.finish(farm, mode: .daily("2026-11-22"), today: "2026-11-22", yesterday: "2026-11-21")
        #expect(save.streak == 2)
        #expect(save.currentStreak(today: "2026-11-23", yesterday: "2026-11-22") == 2)
        #expect(save.currentStreak(today: "2026-11-25", yesterday: "2026-11-24") == 0)
    }

    @Test func aSkippedDayRestartsTheStreak() {
        var save = SaveData()
        let farm = Farm(seed: 1)
        _ = save.finish(farm, mode: .daily("2026-11-20"), today: "2026-11-20", yesterday: "2026-11-19")
        _ = save.finish(farm, mode: .daily("2026-11-22"), today: "2026-11-22", yesterday: "2026-11-21")
        #expect(save.streak == 1)
        #expect(save.bestStreak == 1)
    }

    @Test func freePlayKeepsTheBestScoreButNotTheStreak() {
        var save = SaveData()
        var farm = Farm(seed: 1)
        farm.totalSales = 300
        let r = save.finish(farm, mode: .free(99), today: "2026-11-22", yesterday: "2026-11-21")
        #expect(save.bestScore == 300)
        #expect(save.streak == 0)
        #expect(!r.daily)
        #expect(save.current == nil)
    }

    @Test func theAlmanacRemembersNewCropsOnce() {
        var save = SaveData()
        let first = save.noteGrown(Crop(season: .summer, tier: 4))
        let second = save.noteGrown(Crop(season: .summer, tier: 4))
        #expect(first)
        #expect(!second)
        #expect(save.grownCount(in: .summer) == 1)
        #expect(save.bestCrop == Crop(season: .summer, tier: 4))
    }

    @Test func aRunInProgressSurvivesSaving() throws {
        var save = SaveData()
        var farm = Farm(seed: 5)
        _ = farm.drop()
        save.current = RunSave(mode: .daily("2026-11-22"), farm: farm, crops: [PlacedCrop(crop: Crop(season: .spring, tier: 3), x: 0.4, y: 0.1)])
        let data = try JSONEncoder().encode(save)
        let back = try JSONDecoder().decode(SaveData.self, from: data)
        #expect(back == save)
    }

    @Test func theDailyFieldIsTheSameForEveryone() {
        #expect(PlayMode.daily("2026-11-22").seed == PlayMode.daily("2026-11-22").seed)
        #expect(PlayMode.daily("2026-11-22").seed != PlayMode.daily("2026-11-23").seed)
    }
}
