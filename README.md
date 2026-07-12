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

## macOS でのデバッグ実行

事前に以下をインストールしてください。

- Flutter SDK
- Xcode
- Xcode Command Line Tools
- VS Code または Android Studio

このリポジトリではmacOSデスクトップ用ランナーを同梱しています。VS Codeでフォルダを開き、デバイスに `macOS` を選んで `F5` を押すとデバッグ実行できます。

### 1. Xcodeの状態確認

macOSデスクトップアプリのビルドにはフル版Xcodeが必要です。Xcodeをインストール後、以下で `xcodebuild` が使えることを確認してください。

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

`xcode-select -p` が `/Library/Developer/CommandLineTools` を指している場合、`flutter run -d macos` が `unable to find utility "xcodebuild"` で失敗します。その場合も上記の `xcode-select` コマンドでXcode本体へ切り替えてください。

App StoreからXcodeを入れる場合は、App Storeで `Xcode` を検索してインストールします。Homebrewで `mas` を導入済みの場合は、CLIからApp Storeページを開くこともできます。

```bash
mas open 497799835
```

### 2. FlutterのmacOSデバイス確認

macOSデスクトップが無効な環境では、初回のみ以下を実行してください。

```bash
flutter config --enable-macos-desktop
```

次に依存関係を取得し、macOSデバイスが見えることを確認します。

```bash
flutter pub get
flutter devices
```

`flutter devices` に `macOS (desktop) • macos` が表示されれば準備完了です。

### 3. デバッグ起動

ターミナルから実行する場合:

```bash
flutter run -d macos
```

起動に成功すると、`build/macos/Build/Products/Debug/flutter_photo_collage_app.app` が生成され、Dart VM ServiceとFlutter DevToolsのURLが表示されます。

### 4. 生成済みアプリを通常起動

```bash
open build/macos/Build/Products/Debug/flutter_photo_collage_app.app
```

写真の読み込み、JPEG書き出し、プロジェクト保存はmacOSのファイル選択ダイアログ経由で行います。macOSアプリのサンドボックス設定には、ユーザーが選択したファイル/フォルダへの読み書き権限を追加しています。
