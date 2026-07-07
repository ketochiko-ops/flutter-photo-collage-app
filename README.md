# Photo Collage Studio

Flutter製のローカルファーストな写真フレーム合成・組み写真作成アプリです。

## 対応方針

- iPhone / iPad / Android / macOS をFlutterでターゲットにします。
- 画像合成、縮小、JPEG再圧縮は端末ローカルで実行します。
- 広告枠は `google_mobile_ads` でiOS / Androidに対応しています。
- EXIFからカメラ、レンズ、焦点距離、絞り、シャッタースピード、ISOを読み取り、取得できない値は手入力できます。
- 使用画像と `project.json` を1つのプロジェクトフォルダに保存し、後から読み直せます。

## セットアップ

この環境ではFlutter SDKがPATHに無かったため、プラットフォーム生成とテスト実行は未実施です。Flutterを導入後に下記を実行してください。

```powershell
flutter create --platforms=android,ios,macos .
flutter pub get
flutter test
```

## 開発実行

```powershell
flutter run -d macos
flutter run -d ios
flutter run -d android
```

## テスト一覧

`flutter test` で下記のテストを実行します。

- `test/models_test.dart`
  - `PhotoMetadata`: 撮影情報の表示順と、ISO表記が一度だけ付与されることを確認します。
  - `CollageLayout`: グリッド配置の矩形がガター込みで安定して計算されることを確認します。
  - `CollageLayout`: 指定列数が画像枚数を超える場合、画像枚数に合わせて列数が制限されることを確認します。
  - `ExportSettings`: 書き出し設定をJSONへ変換し、復元しても内容が維持されることを確認します。
  - `SizeLimiter`: 目標バイト数を超過した場合だけJPEG品質の再試行が必要になることを確認します。
  - `ProjectDocument`: プロジェクト情報、使用画像、撮影情報、書き出し設定をJSONから復元できることを確認します。
- `test/project_repository_test.dart`
  - `ProjectRepository`: `project.json` の保存、元画像の `assets` フォルダへのコピー、保存済みプロジェクトの再読み込みを確認します。

## 主な画面

- `Frame`: 1枚の画像に余白フレームと撮影情報を合成し、JPEGで書き出します。
- `Collage`: 複数画像をグリッド状の組み写真としてJPEGで書き出します。
- `Project`: 保存済みプロジェクトフォルダの `project.json` と使用画像を読み込みます。

## 広告設定

現在はGoogleのテスト広告IDを使っています。本番公開前に `lib/main.dart` の `AdSlot` 内にある `adUnitId` を本番IDへ差し替えてください。

Android / iOS のネイティブ設定は `flutter create` 後に追加します。

- Android: `android/app/src/main/AndroidManifest.xml` にAdMob App IDを追加
- iOS: `ios/Runner/Info.plist` に `GADApplicationIdentifier` を追加

macOSではGoogle Mobile Adsが公式サポート外のため、App Store配布時は別SDKまたは自社広告枠に差し替える想定です。アプリ側は広告表示領域を分離してあるので交換しやすい構造です。

## 実装メモ

- 合成処理: `lib/services/local_image_composer.dart`
- EXIF読み取り: `lib/services/metadata_extractor.dart`
- プロジェクト保存: `lib/services/project_repository.dart`
- テスト: `test/models_test.dart`, `test/project_repository_test.dart`

## 既知の注意点

- iOS / iPadOS の任意保存場所はOSのFiles連携とアプリサンドボックスの制約を受けます。
- HEICの読み込み可否はFlutterエンジンとOSコーデックに依存します。
- 任意フォントはFlutterに登録済み、またはOSで利用できるフォントファミリー名を指定します。
