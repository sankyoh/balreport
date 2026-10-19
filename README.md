# balreport

Create two-group descriptive statistics and covariate balance tables in Stata, with weighted quantiles, Excel export, and configurable display precision.

**Version:** 1.1.0 · **Code date:** 19 October 2026 · **Requires:** Stata 18 or later · **License:** [MIT](LICENSE)

[日本語](#日本語) | [English](#english) | [Detailed manual / 詳細マニュアル](docs/balreport.md) | [Changelog / 変更履歴](CHANGELOG.md)

不具合の報告や改善案は、[GitHub Issues](https://github.com/sankyoh/balreport/issues) にお寄せください。Stataのバージョン、使用したコマンド、エラーメッセージ、架空データで再現できる最小例を添えてください。

Please report bugs or suggestions through [GitHub Issues](https://github.com/sankyoh/balreport/issues), including your Stata version, command, error message, and a minimal example using synthetic data.

## 日本語

### 概要

`balreport` は、2群間の記述統計量と共変量バランスをまとめるStataユーザー定義コマンドです。

- 連続変数：平均、標準偏差、中央値、Q1・Q3、標準化平均差（SMD）、分散比（VR）
- カテゴリ変数：各カテゴリの度数・割合とSMD
- 重みなし、および `fweight`・`aweight`・`pweight`・`iweight` に対応
- 重み付きの中央値・四分位値に対応
- ExcelとStataデータセットへの保存に対応
- 小数点以下の桁数、または有効数字を項目別に指定可能

Excelでは、連続変数の各群のセルを次の2行で表示します。

```text
mean (SD)
median (Q1, Q3)
```

StataとMataの標準機能だけを使います。`covbalx`、`covbal`、`swbin`、Microsoft Excel本体は必要ありません。

### インストール

GitHubの `sankyoh/balreport` リポジトリから、次のコマンドでインストールできます。

```stata
net set ado PLUS
net install balreport, from("https://raw.githubusercontent.com/sankyoh/balreport/main/stata/") replace
capture program drop balreport
which balreport
help balreport
```

`sysdir` に表示される `PLUS` がインストール先です。通常、本体とヘルプは `PLUS/b/` に配置されます。プロジェクト固有の `adopath` 設定は不要です。

旧版がPERSONALやプロジェクト内にある場合は、次で重複を確認します。

```stata
which balreport, all
```

先に検索される場所の旧版は検索パス外へ退避し、古い `adopath` の追加設定を呼び出し元から除いてください。その後 `capture program drop balreport` を実行し、`which balreport` が利用したいPLUS版を示すことを確認します。

実行例を現在の作業フォルダへ取得するには、次を使います。

```stata
net get balreport, from("https://raw.githubusercontent.com/sankyoh/balreport/main/stata/")
```

取得する `sample.do` はStata同梱の `auto` データを使います。実行前にファイルの内容を確認してください。

### 構文

```stata
balreport varlist [if] [in] [weight], by(groupvar) ///
    [categorical(varlist) continuous(varlist) ///
     excel("filename.xlsx") saving("filename.dta") sheet("sheetname") ///
     replace signed noprint decimals(# [# #]) sigfigs(# [# #])]
```

`by()` には、解析対象内でちょうど2つの非欠損値を持つ数値変数を指定します。通常の変数名・`c.var` は連続変数、`i.var` はカテゴリ変数として扱います。`categorical()`・`continuous()` で明示指定することもできます。

| オプション | 内容 |
| --- | --- |
| `excel()` | Excelへ出力。連続変数の各群のセルは2行表示 |
| `saving()` | 表示用文字列と丸め前の数値を `.dta` へ保存 |
| `sheet()` | Excelのシート名。既定値は `balreport` |
| `replace` | 同名のExcelワークブック全体を上書き |
| `signed` | SMDを符号付きで表示。省略時は絶対値 |
| `noprint` | Resultsウィンドウの表を非表示 |
| `decimals()` | 小数点以下の桁数。0～10の整数を1つまたは3つ |
| `sigfigs()` | 有効数字の桁数。1～15の整数を1つまたは3つ |

**`decimals()` と `sigfigs()` は同時指定できません。** 3つの値は順に、①平均・SD・中央値・Q1・Q3、②割合（%）、③SMD・VRへ適用します。1つなら全項目に共通適用し、2つだけの指定はできません。省略時は **`decimals(2 2 3)`** です。

`aw`・`pw`・`iw` の重み付き度数は1番目の設定に従い、重みなし・`fw` の度数は整数で表示します。表示桁数を変更しても、保存する数値列やExcelのSMD・VRの内部数値は丸めません。

### 実行例

現在のデータを保存してから実行してください。`sysuse auto, clear` はメモリ内のデータを置き換えます。

```stata
sysuse auto, clear

* 基本形：連続変数とカテゴリ変数
balreport price mpg weight i.rep78, by(foreign)

* 小数桁を指定し、Excelと数値結果を保存
balreport price mpg weight i.rep78, by(foreign) ///
    decimals(1 2 3) excel("balreport_auto.xlsx") ///
    saving("balreport_result.dta") replace

* 説明用の重み。実際の解析では目的に合う重みを指定
generate double example_weight = 1 + _n/100
balreport price mpg weight i.rep78 [pw=example_weight], ///
    by(foreign) sigfigs(3 2 3) ///
    excel("balreport_weighted.xlsx") replace

return list
```

中央値・四分位値にも指定した重みが適用されます。`balreport` 自体は重みや傾向スコアを推定しません。

### 保存結果

`balreport` はr-classコマンドです。`return list` で次のマクロを確認できます。

| 戻り値 | 内容 |
| --- | --- |
| `r(byvar)` | 群変数名 |
| `r(group1)`・`r(group2)` | 群の数値の文字列表現。小さい値がGroup 1 |
| `r(group1_label)`・`r(group2_label)` | 表示する群ラベル |
| `r(command)` | `balreport` |
| `r(precision_mode)` | `decimal` または `significant` |
| `r(precision_digits)` | 3項目に展開した桁数指定 |

統計量はr()の行列では返しません。`saving()` の数値列に、`smd`・`vr` と、各群の平均・SD・中央値・Q1・Q3を保存します。保存列の一覧や定義は[詳細マニュアル](docs/balreport.md)を参照してください。

### 定義と制限

- Stata 18以上が必要です。集計対象・群変数は数値変数を使います。3群以上、文字列変数、交互作用表記は非対応です。
- 欠損値は変数ごとに除外します。重みは正の値を使い、0と欠損は対象から除きます。負の重みはエラーです。
- 重み付き分散の分母は `sum(w)`、重みなし分散の分母は `n-1` です。重みをすべて1にしてもSDは一致するとは限りません。
- 分位点は `_pctile` の標準定義を使います。`iweight` は分位点の計算に限り、同じ値を `aweight` として渡します。
- SMDの向きはGroup 2 − Group 1、VRはGroup 2の分散／Group 1の分散です。群の順序は数値の昇順です。
- カテゴリ変数のSMDは各カテゴリについて計算し、変数全体の単一SMDやVRは算出しません。
- 重みは記述統計用として扱います。調査デザインに基づく標準誤差、信頼区間、p値は算出しません。
- `saving()` は同名の `.dta` を **`replace` の有無にかかわらず上書き**します。Excelは `replace` が必要で、指定時はワークブック全体を置き換えます。

## English

### Overview

`balreport` is a user-written Stata command for describing two groups and assessing covariate balance.

- Continuous variables: mean, SD, median, Q1, Q3, standardized mean difference (SMD), and variance ratio (VR)
- Categorical variables: counts, percentages, and an SMD for each category
- Unweighted summaries and `fweight`, `aweight`, `pweight`, and `iweight`
- Weighted medians and quartiles
- Excel and Stata dataset export
- Separate display precision for summaries, percentages, and SMD/VR

Each continuous-variable group cell in Excel contains two lines: `mean (SD)` and `median (Q1, Q3)`. The command uses built-in Stata and Mata functionality only; neither other user-written commands nor Microsoft Excel is required.

### Installation

Install directly from the `sankyoh/balreport` repository on GitHub:

```stata
net set ado PLUS
net install balreport, from("https://raw.githubusercontent.com/sankyoh/balreport/main/stata/") replace
capture program drop balreport
which balreport
help balreport
```

Stata installs the ado and help files under the `PLUS` directory shown by `sysdir`, normally in its `b` subdirectory. No project-specific `adopath` setting is needed.

Use `which balreport, all` to find older copies in PERSONAL, the current directory, or custom search paths. Move unwanted copies outside the search path and remove obsolete project path additions. Then run `capture program drop balreport` and confirm the selected location with `which balreport`.

Download the ancillary `sample.do` into the current working directory with:

```stata
net get balreport, from("https://raw.githubusercontent.com/sankyoh/balreport/main/stata/")
```

### Syntax and precision

```stata
balreport varlist [if] [in] [weight], by(groupvar) ///
    [categorical(varlist) continuous(varlist) ///
     excel("filename.xlsx") saving("filename.dta") sheet("sheetname") ///
     replace signed noprint decimals(# [# #]) sigfigs(# [# #])]
```

Use numeric variables. Plain variable names and `c.var` are continuous; `i.var` is categorical. The `by()` variable must have exactly two nonmissing levels in the eligible sample.

| Option | Meaning |
| --- | --- |
| `decimals()` | Decimal places: one or three integers from 0 to 10 |
| `sigfigs()` | Significant figures: one or three integers from 1 to 15 |
| `excel()` | Save an Excel workbook |
| `saving()` | Save display strings and unrounded numeric summaries in a `.dta` file |
| `sheet()` | Worksheet name; default: `balreport` |
| `replace` | Replace the entire existing Excel workbook |
| `signed` | Retain the SMD sign; otherwise show absolute SMD |
| `noprint` | Suppress the displayed results table |

**`decimals()` and `sigfigs()` are mutually exclusive.** Three values apply to (1) mean, SD, median, Q1, and Q3; (2) percentages; and (3) SMD and VR. One value applies to all three categories. Two values are invalid. The default is **`decimals(2 2 3)`**.

Weighted counts for `aw`, `pw`, and `iw` follow the first setting. Unweighted and `fw` counts remain integers. Precision changes affect presentation only: saved numeric columns and the underlying numeric SMD/VR Excel cells retain their values.

### Examples

Save any current data before running `sysuse auto, clear`.

```stata
sysuse auto, clear

* Unweighted report
balreport price mpg weight i.rep78, by(foreign)

* Decimal places and file export
balreport price mpg weight i.rep78, by(foreign) ///
    decimals(1 2 3) excel("balreport_auto.xlsx") ///
    saving("balreport_result.dta") replace

* Illustrative weights; replace with appropriate analysis weights
generate double example_weight = 1 + _n/100
balreport price mpg weight i.rep78 [pw=example_weight], ///
    by(foreign) sigfigs(3 2 3) ///
    excel("balreport_weighted.xlsx") replace

return list
```

Weights also apply to medians and quartiles. `balreport` does not estimate weights or propensity scores.

### Stored results

The command returns macros `r(byvar)`, `r(group1)`, `r(group2)`, `r(group1_label)`, `r(group2_label)`, `r(command)`, `r(precision_mode)`, and `r(precision_digits)`. It does not return a matrix of per-variable statistics.

Use `saving()` for further calculations. Its numeric columns include `smd`, `vr`, and each group's mean, SD, median, Q1, and Q3. Group display strings are saved separately. The input dataset is restored after reporting.

### Definitions and limitations

- Requires Stata 18 or later. More than two groups, string variables, and interactions are unsupported.
- Missing values are excluded separately for each summarized variable. Zero and missing weights are excluded; negative weights are rejected.
- Weighted variance divides by `sum(w)`; unweighted variance divides by `n-1`. Unit weights need not reproduce the unweighted SD.
- Quantiles use the default `_pctile` definition. For quantiles only, `iweight` values are passed unchanged as `aweight`.
- Groups follow ascending numeric values. Signed SMD uses Group 2 minus Group 1; VR is variance(Group 2) divided by variance(Group 1).
- Categorical SMDs are computed for individual categories. No overall multicategory SMD or categorical VR is provided.
- Weights are used for descriptive summaries, not survey-design inference. Standard errors, confidence intervals, and p-values are not calculated.
- **`saving()` overwrites an existing `.dta` file regardless of `replace`.** Excel export requires `replace` to overwrite an existing file, and replaces the whole workbook.

See the [detailed Japanese manual](docs/balreport.md) and `help balreport` for formulas, missing-value conventions, output columns, and troubleshooting.

## Files

```text
balreport/
├── README.md
├── LICENSE
├── CITATION.cff
├── CHANGELOG.md
├── .gitignore
├── docs/
│   └── balreport.md
└── stata/
    ├── balreport.ado
    ├── balreport.sthlp
    ├── balreport.pkg
    ├── stata.toc
    └── sample.do
```

`stata/` is the Stata net-install directory. `sample.do` is an ancillary example for `net get`; the ado and help files are installed by `net install`.

## Documentation and references

- [Detailed manual / 詳細マニュアル](docs/balreport.md)
- [Changes and compatibility notes / 変更履歴](CHANGELOG.md)
- [Stata: net](https://www.stata.com/manuals/rnet.pdf)
- [Stata: sysdir and adopath](https://www.stata.com/manuals/psysdir.pdf)
- [Stata: pctile and _pctile](https://www.stata.com/manuals/dpctile.pdf)

`balreport` was developed from `covbalx v0.1.3`, adding weighted quartiles, two-line Excel summaries, and display precision controls. `covbalx` is not a dependency, and installation does not replace `covbalx` or `covbal`.

## Author, citation, and license

**Toshiharu Mitsuhashi** — GitHub: [@sankyoh](https://github.com/sankyoh)

引用情報は [CITATION.cff](CITATION.cff) を参照してください。利用時には使用バージョンも記録してください。

See [CITATION.cff](CITATION.cff) for citation metadata, and record the version used in your analysis.

Distributed under the [MIT License](LICENSE).
