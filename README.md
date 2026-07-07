# Photo Collage Studio

Flutter製のローカルファーストな写真フレーム作成・コラージュ作成アプリです。

## 対応環境

- Windows 11
- Android
- iOS / iPadOS
- macOS

画像合成、縮小、JPEG書き出しは端末ローカルで実行します。EXIFからカメラ、レンズ、焦点距離、絞り、シャッタースピード、ISOを読み取り、取得できない値は手入力できます。

## Windows 11 + VS Code でのデバッグ実行

事前に以下をインストールしてください。

- Flutter SDK
- VS Code
- VS Code拡張機能: Flutter / Dart
- Visual Studio 2022 の「Desktop development with C++」
- Windowsの開発者モード

このリポジトリではWindowsデスクトップ用ランナーを同梱しています。VS Codeでフォルダを開き、デバイスに `Windows` を選んで `F5` を押すとデバッグ実行できます。

PowerShellから実行する場合:

```powershell
flutter pub get
flutter run -d windows
```

Windowsデスクトップが無効な環境では、初回のみ以下を実行してください。

```powershell
flutter config --enable-windows-desktop
```

プラグインを使うFlutter Windowsアプリではシンボリックリンクが必要です。未設定の場合は、Windowsの「設定 > システム > 開発者向け」から「開発者モード」を有効にしてください。

## テスト

```powershell
flutter test
```

主なテスト:

- `test/models_test.dart`
- `test/project_repository_test.dart`
- `test/widget_test.dart`

## 主な機能

- `Frame`: 1枚の写真に余白フレームと撮影情報を合成し、JPEGで書き出します。
- `Collage`: 複数画像をグリッド状に合成し、JPEGで書き出します。
- `Project`: 使用画像と `project.json` をプロジェクトフォルダに保存し、後から読み込み直せます。

## 実装メモ

- 画像合成: `lib/services/local_image_composer.dart`
- EXIF読み取り: `lib/services/metadata_extractor.dart`
- プロジェクト保存: `lib/services/project_repository.dart`

Google Mobile AdsはAndroid / iOSのみで初期化します。Windowsデスクトップ実行時は広告枠は空表示になります。
