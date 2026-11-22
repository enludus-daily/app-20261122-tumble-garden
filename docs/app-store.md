# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.004（枠の使い回し。App Store Connect の App は段取りランのものを、asc の metadata で上書きする） |
| アプリ名 | ころころ菜園：落として育てる畑 / Tumble Garden: Merge Farm（AI が決めた。本人の許可 2026-11-04） |
| サポート URL | https://github.com/enludus-daily/app-20261122-tumble-garden/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261122-tumble-garden/blob/main/PRIVACY.md |
| 年齢区分の答え（下書き） | すべて「なし」（暴力・ギャンブル・Web・生成 AI・ユーザー間の交流なし）。4+ 相当の見込み。入力は本人 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：パズルゲーム（落として合体 × 農場の一年）。懐中電灯・効果音・壁紙・タイマー・占いなどではない。前日までの毎日のアプリと遊び・見た目・部品が違う（Theme・部品は新しく作った）
- 既存のアプリとの意味のある違い：マス目の合体農場（Merge Farm 系）と違い、物理で落として積む。落ち物の合体（Suika 系）と違い、季節ごとに段が入れ替わり、出荷の目標・天気予報・店の道具で 1 年をめぐる
- 長く使える価値（4.2）：日付シードの今日の畑（全員同じ）、作物図鑑 32 種、年ごとに上がる目標、道具 7 種の組み合わせ
- 他社の名前・商標・見た目を使っていないか：使っていない。「落として合体」の仕組みだけを借り、丸い果物を箱に落とす見た目は真似していない（木の育て箱の断面・形の違う野菜・季節の空。絵はすべて端末の中で描く自作）。名前に他社の名前を入れていない
- Apple Intelligence：使わない
- 課金の審査：Pro（com.enludus.daily.004.pro、段取りランの商品を使い回し、名前・説明・価格を products で更新）は、このバージョンと一緒に審査に出す（提出は本人）

## 収益の道筋（本人が選ぶ）

- 選んだ形：買い切りの Pro ¥480（非消耗型・家族共有）。広告なし
- 理由と比べた表・勝算の表：README の「課金」

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ。共有は iOS の共有シートに文を渡すだけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。課金の審査用の画像は `docs/iap/paywall.png`。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
