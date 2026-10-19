# Changelog / 変更履歴

This file records known code changes and publication preparation. Code dates below are not claims of a GitHub release date.

ここでは確認できるコードの変更と公開準備を記録します。コードの日付は、GitHubで公開した日付を意味しません。

## Repository publication / リポジトリ公開 — 19 October 2026

Published the source and documentation at https://github.com/sankyoh/balreport.
This is the initial repository publication; the ado remains v1.1.0 and no DOI
or versioned GitHub Release is claimed here.

ソースと文書を https://github.com/sankyoh/balreport で公開しました。
ado本体はv1.1.0のままで、今回の公開はDOIの発行やバージョン付きGitHub Releaseの作成を意味しません。

## Publication preparation / 公開準備

The ado remains **v1.1.0**, dated **19 October 2026**. These packaging and documentation changes do not change the statistical calculations.

ado本体は **v1.1.0（2026年10月19日）** のままです。以下は配布構成と文書の整備であり、統計計算の変更ではありません。

- Prepared a standalone Stata package in `stata/`, with `balreport.pkg` and `stata.toc` for `net install` into PLUS.
- Added bilingual repository documentation, a detailed manual in `docs/`, citation metadata, an MIT license, and an example do-file using Stata's bundled `auto` data.
- Documented installation, update/reload steps, duplicate ado search paths, precision options, and output-file replacement behavior.
- The GitHub installation commands describe the intended location after publication; preparing these files does not publish the repository or create a release.

- `stata/` に外部配布用ファイルをまとめ、`balreport.pkg`・`stata.toc` によるPLUSへの導入に対応。
- 日英のREADME、`docs/` の詳細マニュアル、引用情報、MITライセンス、Stata同梱の `auto` データを使う実行例を整備。
- インストール・更新・再読み込み、旧版との検索パスの重複、表示精度、保存時の上書きの挙動を説明。
- GitHubのインストールURLは公開後の配置先を示すもので、ファイル作成自体はリポジトリの公開やリリース作成を行いません。

## 1.1.0 — 19 October 2026

### Added / 追加

- Mutually exclusive `decimals()` and `sigfigs()` display-precision options.
- One-value settings for all statistics, or three-value settings for continuous summaries, percentages, and SMD/VR, in that order.
- Significant-figure formatting with trailing zeros, scientific notation, and matching Excel numeric display formats.
- Returned macros `r(precision_mode)` and `r(precision_digits)`.

- `decimals()`（小数点以下の桁数）と `sigfigs()`（有効数字）を追加し、同時指定を禁止。
- 1値なら全項目共通、3値なら連続要約統計・割合・SMD/VRの順に個別指定。
- 有効数字の末尾0・指数表記とExcelの数値表示形式に対応。
- 戻り値 `r(precision_mode)`・`r(precision_digits)` を追加。

### Changed / 変更

- Default precision is `decimals(2 2 3)`.
- `pctdecimals()` and `smddigits()` are replaced by the second and third values of the precision option.
- `decimals(2)` now applies two decimal places to all three categories; it is different from the default `decimals(2 2 3)`.
- Display precision does not round the saved numeric statistics or the underlying SMD/VR values in Excel.

- デフォルトを `decimals(2 2 3)` に設定。
- `pctdecimals()`・`smddigits()` を廃止し、精度オプションの2番目・3番目の値へ統合。
- `decimals(2)` は全項目を小数点以下2桁とする指定に変更。省略時の `decimals(2 2 3)` とは異なる。
- 表示精度を変更しても、保存する統計量の数値列やExcelのSMD・VRの内部数値は保持。

### Migration / 移行例

```stata
* Previous precision syntax / 旧指定
* decimals(2) pctdecimals(1) smddigits(3)

* Equivalent current precision / 現在の対応する指定
balreport price mpg i.rep78, by(foreign) decimals(2 1 3)
```

The command example assumes Stata's `auto` data are already loaded. The former options are no longer accepted.

実行例はStataの `auto` データを読み込み済みであることを前提とします。旧オプションは受け付けません。

## 1.0.0

- Created `balreport` from `covbalx v0.1.3`, under a distinct command name.
- Added medians, Q1, and Q3 for continuous variables, including weighted quantiles.
- Changed each continuous-variable Excel group cell to two lines: mean (SD), followed by median (Q1, Q3).
- Added unrounded continuous summary columns to the dataset produced by `saving()`.

- `covbalx v0.1.3` を基に、独立したコマンド名 `balreport` として作成。
- 連続変数の中央値・Q1・Q3を追加し、重み付き分位点に対応。
- Excelの各群の連続変数セルを、平均（SD）／中央値（Q1, Q3）の2行表示に変更。
- `saving()` の結果データセットに、丸め前の連続要約統計の列を追加。
