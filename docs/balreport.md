# balreport.ado マニュアル（v1.1.0）📊

`balreport` は、2群間の共変量バランスを確認するために、**記述統計量 + standardized mean difference（SMD）+ variance ratio（VR）** をワンコマンドで作成するStataユーザー定義コマンドです。

連続変数では **平均（標準偏差）・中央値（Q1, Q3）・SMD・VR** を出力し、カテゴリ変数では **各カテゴリごとの度数（割合）・SMD** を出力します。重みなし・重み付きの両方に対応し、結果をExcel（`.xlsx`）やStataデータセット（`.dta`）として保存できます✅

Excelでは、連続変数の各群のセル内に次の2行を表示します。

~~~text
mean (SD)
median (Q1, Q3)
~~~

Q1は第1四分位値（25パーセンタイル）、Q3は第3四分位値（75パーセンタイル）です。中央値は第2四分位値（Q2）に相当します。

本書は **v1.1.0（2026年10月19日）** の仕様に対応しています。

---

## 0. 目的と特徴（Overview）

- ✅ 2群間の記述統計表を作成
- ✅ 連続変数：平均（SD）と中央値（Q1, Q3）をExcelの同じセルに2行で表示
- ✅ カテゴリ変数：各カテゴリごとのN（%）とSMDを表示
- ✅ 連続変数のSMD・VRを表示
- ✅ `i.sex` のような因子変数表記に対応
- ✅ `[fw=]`、`[aw=]`、`[pw=]`、`[iw=]` と重み付き分位点に対応
- ✅ 小数点以下の桁数、または有効数字の桁数を指定可能
- ✅ 記述統計・割合・SMD/VRの表示精度を個別に設定可能
- ✅ Excel出力と、丸め前の数値を含む結果データセットの保存に対応
- ✅ プロジェクト固有の設定や他の自作コマンドなしで動作

---

## 1. 動作要件（Requirements）

- Stata 18以上
- `balreport.ado` がStataのado検索パスにインストールされていること
- `by()` に指定する群変数が数値変数で、解析対象内に **ちょうど2つの非欠損値** を持つこと
- 集計する変数が数値変数であること

文字列のカテゴリ変数は、必要に応じて事前に `encode` などで数値化してください。

StataとMataの標準機能だけを使用します。`covbalx` や `swbin` などの追加コマンドは不要です。Excelファイルの作成にMicrosoft Excel本体は必要ありません。

---

## 2. インストール（Installation）

### 2.1 PLUSへのインストール

外部コマンドとして、Stataの `net install` でインストールします。

まず、保存先を確認します。

~~~stata
sysdir
~~~

次に、インストール先を `PLUS` に設定して導入します。

~~~stata
net set ado PLUS
net install balreport, from("PACKAGE_URL") replace
capture program drop balreport
which balreport
help balreport
~~~

`PACKAGE_URL` は置換用の表記です。`balreport.pkg`、`balreport.ado`、`balreport.sthlp` が置かれている実際のURLまたはローカルフォルダに置き換えてください。

GitHubのリポジトリ直下に配布ファイルを置く場合、URLは次の形です。

~~~text
https://raw.githubusercontent.com/OWNER/REPOSITORY/REF/
~~~

`OWNER`、`REPOSITORY`、`REF` は、それぞれ公開者、リポジトリ名、ブランチ名またはリリースタグに置き換えます。サブフォルダに置く場合は、そのフォルダ名を末尾に追加します。これはURLの書式例であり、公開済みのダウンロード先ではありません。

通常のGitHub閲覧ページや、末尾が `.ado` のファイルURLではなく、**パッケージを置いたフォルダのRaw URL** を指定します。

本コマンドは `sankyoh/balreport` リポジトリの `main` ブランチ、`stata` フォルダで配布しています。次のコマンドでインストールできます。

~~~stata
net set ado PLUS
net install balreport, from("https://raw.githubusercontent.com/sankyoh/balreport/main/stata") replace
~~~

上記URLは本コマンドの配布元です。自身のリポジトリへ複製して配布する場合は、実際のリポジトリ名やブランチ名に合わせてURLを変更してください。

### 2.2 インストール先

`net set ado PLUS` を指定すると、Stataは `sysdir` の `PLUS` に示されるフォルダへインストールします。本体とヘルプは通常、次の場所に入ります。

~~~text
PLUS/b/balreport.ado
PLUS/b/balreport.sthlp
~~~

PLUSの実際のパスはPCやOSによって異なります。特定のユーザー名やWindowsの絶対パスを、ado本体に書き込む必要はありません。

GitHub側には、上記2ファイルに加え、インストール対象を列挙する `balreport.pkg` と、パッケージ一覧用の `stata.toc` を配置します。本書 `balreport.md` はMarkdownの説明文書で、コマンドの動作に必須ではありません。Stata内では `help balreport` でヘルプを参照できます。

この配布構成では、本体・ヘルプ・配布定義・実行例 `sample.do` を `stata/` に、本書を `docs/balreport.md` に配置します。`net install` は本体とヘルプをインストールし、実行例は次の `net get` で現在の作業フォルダへ取得できます。

~~~stata
net get balreport, from("PACKAGE_URL")
do sample.do
~~~

`PACKAGE_URL` はインストール時と同じ配布元へ置き換えます。実行例はStata同梱の `auto` データを使用し、現在のデータを置き換えます。出力先は作業フォルダ内の `balreport_example_output` で、同名の出力ファイルは上書きします。本書は `net install` のインストール対象ではなく、GitHub上で閲覧する文書です。

### 2.3 プロジェクト内の版・PERSONAL版から切り替える場合

インストール後は、通常、次の設定は不要です。

~~~stata
adopath ++ "$PROJ/ado"
~~~

この行は、プロジェクト内の `ado` フォルダを **検索順序の先頭に追加する** 指定であり、インストール処理ではありません。PLUS版に切り替える場合は、呼び出し元doファイルから旧設定を削除します。

既に追加した検索先を現在のStataセッションから外すには、次を使います。`directory` は実際の旧フォルダに置き換えます。

~~~stata
adopath - "directory"
~~~

さらに、重複する版を確認します。

~~~stata
which balreport, all
~~~

PERSONAL、現在の作業フォルダ、または先に検索されるフォルダに旧版があると、PLUS版より優先されることがあります。不要になった `balreport.ado` と `balreport.sthlp` を検索パス外へ退避したうえで、読み込み済みのプログラムを解除します。

~~~stata
capture program drop balreport
which balreport
~~~

表示されたパスが、使用したいPLUS版を指していることを確認してください。

---

## 3. コマンド仕様（AI-readable spec）🤖

~~~yaml
command: balreport
version: "1.1.0"
requires: "Stata 18 or later"
dependencies: "built-in Stata and Mata only"
purpose: "Create a two-group descriptive statistics and covariate balance report"
inputs:
  varlist: "numeric variables; plain/c.var are continuous, i.var is categorical"
  by: "numeric variable with exactly two nonmissing levels in the eligible sample"
  if_in: "optional if/in qualifiers, placed before the weight expression"
  weights: [fweight, aweight, pweight, iweight]
group_order: "ascending numeric values: lower = group1, higher = group2"
statistics:
  continuous:
    group_cells: "mean (SD)\nmedian (Q1, Q3)"
    quantiles: "_pctile at 25, 50, 75; default definition, no altdef"
    smd: "(mean2 - mean1) / sqrt((variance1 + variance2) / 2)"
    vr: "variance2 / variance1"
  categorical:
    group_cells: "N (%) for each observed nonmissing category"
    smd: "one binary-proportion SMD per category, not one overall SMD"
    vr: "missing"
  smd_default: "absolute value; signed retains the sign"
weight_behavior:
  role: "descriptive / pseudo-population weights, not survey-design inference"
  missing: "excluded by Stata sample marking"
  negative: "rejected"
  zero: "excluded"
  fweight: "integer weights only"
  weighted_variance: "sum(w * (x - weighted_mean)^2) / sum(w)"
  unweighted_variance: "sum((x - mean)^2) / (n - 1)"
  iweight_quantiles: "pass unchanged weight values as aweights to _pctile only"
precision:
  mutually_exclusive: [decimals, sigfigs]
  length: "one or three integers; two integers are rejected"
  order: [continuous_summaries, percentages, smd_and_vr]
  decimals_range: [0, 10]
  sigfigs_range: [1, 15]
  default: "decimals(2 2 3)"
  single_value: "applies to all three categories"
  counts: "aw/pw/iw counts follow first setting; unweighted/fw counts stay integer"
  numeric_values: "not rounded in saved numeric columns or Excel SMD/VR cells"
outputs:
  displayed_table: "two physical rows for continuous variables"
  excel: "seven columns; one cell per group with two lines for continuous variables"
  saving: "display strings, numeric SMD/VR, and ten unrounded continuous summaries"
  input_dataset: "restored after reporting"
file_behavior:
  excel: "existing workbook protected unless replace; replace replaces the whole workbook"
  saving: "existing .dta is overwritten even without replace"
  relative_paths: "resolved against the current working directory"
unsupported:
  - "string variables"
  - "interactions using #"
  - "more than two groups"
  - "combining decimals() and sigfigs()"
~~~

---

## 4. 基本構文（Syntax）

~~~stata
balreport varlist [if] [in] [weight], ///
    by(groupvar) ///
    [ categorical(varlist) ///
      continuous(varlist) ///
      excel("filename.xlsx") ///
      saving("filename.dta") ///
      sheet("sheetname") ///
      replace ///
      signed ///
      noprint ///
      decimals(# [# #]) ///
      sigfigs(# [# #]) ]
~~~

角括弧は省略可能であることを表します。`decimals()` と `sigfigs()` は **どちらか一方だけ** を指定してください。両方とも省略すると `decimals(2 2 3)` が適用されます。

`if`・`in` を使う場合は、重み指定より前に置きます。

~~~stata
balreport age i.sex if exclusion==0 [pw=sw], by(trt)
~~~

---

## 5. 引数とオプション（Options）

### 5.1 必須オプション：`by(groupvar)`

2群を定義する数値変数を指定します。

~~~stata
balreport age bmi, by(trt)
~~~

`if`・`in`、群変数の欠損、重みの条件を適用した解析対象内で、群変数はちょうど2つの非欠損値を持つ必要があります。

値の小さい方が **Group 1**、大きい方が **Group 2** です。例えば `trt = 0, 1` なら、Group 1は `trt==0`、Group 2は `trt==1` です。値ラベルが付いている場合は表示に使われます。

### 5.2 変数型指定

| 指定 | 扱い | 例 |
|---|---|---|
| 通常の変数名 | デフォルトでは連続変数 | `age bmi` |
| `c.var` | 連続変数 | `c.age` |
| `i.var` | カテゴリ変数 | `i.sex i.stage` |
| `categorical()` | 列挙した変数をカテゴリ変数として扱う | `categorical(sex stage)` |
| `continuous()` | 列挙した変数を連続変数として扱う | `continuous(age bmi)` |

例えば、次の2つは同じ変数型の指定です。

~~~stata
balreport age i.sex i.stage, by(trt)
balreport age sex stage, by(trt) categorical(sex stage)
~~~

`categorical()` と `continuous()` は変数型を指定するオプションです。集計する変数は、コマンド直後の `varlist` にも含めてください。これらの明示指定は因子変数表記より優先されます。同じ変数を両オプションに入れるとエラーになります。

カテゴリ変数では、解析対象に存在する各非欠損カテゴリを集計します。回帰分析のように基準カテゴリを除外する表ではありません。交互作用（`#`、`##`）は使用できません。

### 5.3 重み指定

通常のStata weight構文を使います。

~~~stata
balreport age i.sex [pw=sw], by(trt)
~~~

| 種類 | 短縮表記 | 対応 |
|---|---|---|
| fweight | `[fw=frequency]` | 整数の頻度重み |
| aweight | `[aw=weightvar]` | 対応 |
| pweight | `[pw=weightvar]` | 対応 |
| iweight | `[iw=weightvar]` | 対応 |

このコマンドでは、重みを **疑似母集団・記述統計用の重み** として扱います。`svyset` に基づく標準誤差や信頼区間は算出しません。

平均・SDだけでなく、中央値・Q1・Q3にも重みを適用します。カテゴリ変数のNは当該カテゴリの重みの合計となり、`aw`・`pw`・`iw` では小数になり得ます。

### 5.4 Excel出力

#### `excel("filename.xlsx")`

結果をExcelへ保存します。`.xlsx` を省略すると自動で付与されます。

~~~stata
balreport age i.sex, by(trt) excel("balance.xlsx")
~~~

相対パスはStataの現在の作業フォルダを基準にします。別のフォルダへ保存する場合はパスを指定してください。

#### `replace`

既存のExcelファイルを上書きする場合に指定します。

~~~stata
balreport age i.sex, by(trt) excel("balance.xlsx") replace
~~~

`replace` がなければ、同名ファイルが存在するとエラーで停止します。`replace` は **ワークブック全体の置換** であり、既存ブックの他のシートを残して追記するオプションではありません。

新しいブックは一時ファイルとして作成・整形された後、指定先にコピーされます。

#### `sheet("sheetname")`

シート名を指定します。省略時は `balreport` です。

~~~stata
balreport age i.sex, by(trt) ///
    excel("balance.xlsx") sheet("Table1") replace
~~~

連続変数はセル内2行で表示され、折り返し、列幅、行の高さが自動設定されます。

### 5.5 Stataデータセット保存：`saving("filename.dta")`

結果をStataデータセットへ保存します。`.dta` を省略すると自動で付与されます。

~~~stata
balreport age i.sex, by(trt) saving("balance_result.dta")
~~~

表示用の文字列に加えて、SMD・VR、平均・SD・中央値・Q1・Q3の丸め前の数値を保存します。保存列の一覧は第7節を参照してください。

**`saving()` は同名の `.dta` があれば上書きします。** Excelと異なり、`replace` の有無にかかわらず上書きされます。

### 5.6 表示関連：`signed`・`noprint`

`signed` はSMDを符号付きで表示します。デフォルトでは絶対値です。

~~~stata
balreport age i.sex, by(trt) signed
~~~

符号の向きは **Group 2 − Group 1** です。VRは常にGroup 2の分散をGroup 1の分散で割った値です。

`noprint` はResultsウィンドウの集計表を非表示にします。Excelや`.dta`への保存は行えます。ファイル保存メッセージまで抑制するオプションではありません。

~~~stata
balreport age i.sex, by(trt) excel("balance.xlsx") replace noprint
~~~

### 5.7 小数点以下の桁数：`decimals()`

小数点以下を何桁表示するか指定します。指定できるのは **0～10の整数を1つ、または3つ** です。

3つ指定した場合の順序は次のとおりです。

| 順番 | 対象 | デフォルト |
|---|---|---|
| 1番目 | 平均・SD・中央値・Q1・Q3 | 小数点以下2桁 |
| 2番目 | 割合（%） | 小数点以下2桁 |
| 3番目 | SMD・VR | 小数点以下3桁 |

~~~stata
* デフォルトと同じ
balreport age i.sex, by(trt) decimals(2 2 3)

* 記述統計は1桁、割合は2桁、SMD・VRは4桁
balreport age i.sex, by(trt) decimals(1 2 4)

* 全項目を小数点以下2桁にする
balreport age i.sex, by(trt) decimals(2)
~~~

`decimals(2)` は `decimals(2 2 2)` と同じです。省略時の `decimals(2 2 3)` とはSMD・VRの表示桁数が異なります。

### 5.8 有効数字の桁数：`sigfigs()`

有効数字を何桁表示するか指定します。指定できるのは **1～15の整数を1つ、または3つ** です。3つ指定した場合の順序は `decimals()` と同じです。

~~~stata
* 記述統計は有効数字3桁、割合は2桁、SMD・VRは3桁
balreport age i.sex, by(trt) sigfigs(3 2 3)

* 全項目を有効数字3桁にする
balreport age i.sex, by(trt) sigfigs(3)
~~~

有効数字3桁の場合の例：

| 元の数値 | 表示 |
|---|---|
| `1.2` | `1.20` |
| `9.999` | `10.0` |
| `0.012345` | `0.0123` |
| `12345` | `1.23e+04` |
| `0` | `0.00` |

末尾の0を残して指定桁数を表します。丸めた値の10進指数が−4未満、または指定した有効数字の桁数以上の場合は、指数表記を使います。Excelでは `E` による表記になる場合があります。

### 5.9 桁数指定の共通ルール

- **`decimals()` と `sigfigs()` は同時指定できません。**
- 数字は1つ、または3つです。2つだけの指定はエラーになります。
- 一部だけ小数点桁数、残りを有効数字にする混在指定はできません。
- `aw`・`pw`・`iw` の重み付きNは、1番目の設定に従います。
- 重みなしのNと `fw` のNは整数のまま表示します。
- 割合は0～100の百分率に変換してから表示桁数を適用します。
- 桁数指定は表示にだけ適用します。`.dta`の数値列やExcelのSMD・VRの元の数値は丸めません。

旧オプションの `pctdecimals()` と `smddigits()` は使用できません。例えば、旧版の `decimals(2) pctdecimals(1) smddigits(3)` に相当する指定は、現在は `decimals(2 1 3)` です。

---

## 6. 統計量の定義（Statistical details）

### 6.1 連続変数

#### 平均・分散・SD

重みなしの場合、平均と標本分散を用います。

~~~text
mean = sum(x) / n
variance = sum((x - mean)^2) / (n - 1)
SD = sqrt(variance)
~~~

重み付きの場合は、次の定義です。

~~~text
weighted mean = sum(w * x) / sum(w)
weighted variance = sum(w * (x - weighted mean)^2) / sum(w)
weighted SD = sqrt(weighted variance)
~~~

各群・各変数について、解析条件を満たす非欠損値と正の重みを使います。重み付き分散の分母は、重みの種類によらず **`sum(w)`** です。

#### 中央値・四分位値

Stata標準の `_pctile` を使い、25・50・75パーセンタイルを求めます。`altdef` は指定せず、標準の分位点定義を用います。

- Q1：25パーセンタイル
- 中央値：50パーセンタイル
- Q3：75パーセンタイル

重み指定がある場合、分位点にも同じ重みの値を使います。ただし `_pctile` は `iweight` を直接受け付けないため、**分位点の計算に限り、`iweight` を値を変えずに `aweight` として渡します。**

#### SMD

~~~text
SMD = (mean2 - mean1) / sqrt((variance1 + variance2) / 2)
~~~

デフォルトでは絶対値、`signed` 指定時は符号付きの値です。SMDは平均と分散に基づき、中央値や四分位値からは計算しません。

#### VR

~~~text
VR = variance2 / variance1
~~~

VRが1なら、2群の分散が等しいことを表します。

### 6.2 カテゴリ変数

各非欠損カテゴリについて、N（%）を表示します。割合の分母は、その群で **当該変数が非欠損の観測** の数または重みの合計です。欠損カテゴリの行は作成しません。

~~~text
N = 当該カテゴリに属する観測数、またはその重みの合計
p = N / 当該変数が非欠損の観測数、またはその重みの合計
percentage = 100 * p
~~~

各カテゴリを0/1変数とみなし、カテゴリごとにSMDを計算します。

~~~text
SMD = (p2 - p1) / sqrt((p1 * (1 - p1) + p2 * (1 - p2)) / 2)
~~~

`p1`、`p2` は、それぞれGroup 1、Group 2における当該カテゴリの割合（0～1）です。

多カテゴリ変数全体を1つにまとめたSMDではなく、**カテゴリごとのSMD** を出します。カテゴリ変数ではVRは計算せず、欠損値になります。

### 6.3 欠損値・分散0の扱い

集計変数の欠損は変数ごとに除外します。全変数の完全ケースだけに自動で限定する方式ではないため、変数によって集計対象数が異なる場合があります。

連続変数で片方の群に有効な値がなければ、その群の要約統計は欠損になりますが、もう片方の群の要約統計は表示します。重みなしで群内の有効観測が1件しかない場合、平均・分位点は計算できますが、SDは欠損になります。

カテゴリ変数で片方の群に有効な値がなければ、その群の度数は0、割合は欠損になります。両群を通じて有効なカテゴリが存在しない場合は、`(no nonmissing levels)` の1行を出力し、両群の表示セルは空欄になります。

SMDの分母が0で群間差も0ならSMDを0とし、分母が0で群間差が0でなければ欠損とします。連続変数の分散が両群とも0ならVRを1とし、Group 1だけが0ならVRは欠損です。

---

## 7. 出力（Output）

### 7.1 画面とExcel

連続変数の群別セルは、次の構成です。

~~~text
平均 (SD)
中央値 (Q1, Q3)
~~~

Resultsウィンドウでは連続変数を2行に分け、`level` に `mean (SD)` と `median (Q1, Q3)` を表示します。SMD・VRは1行目に表示します。画面幅によって列が折り返される場合があります。

Excelでは **連続変数1つにつき1行** とし、各群のセル内で改行します。カテゴリ変数は1カテゴリにつき1行です。

| Excel列 | 内容 |
|---|---|
| Variable | 変数ラベル。ラベルがない場合は変数名 |
| Level | カテゴリの値ラベルまたは値。連続変数では空欄 |
| Type | `continuous` または `categorical` |
| Group 1の列 | 小さい方の群の要約統計。見出しは群の値ラベルまたは値 |
| Group 2の列 | 大きい方の群の要約統計。見出しは群の値ラベルまたは値 |
| SMD | 絶対値、または `signed` 指定時の符号付きSMD |
| VR | 分散比。カテゴリ変数では欠損 |

Excelの群別要約セルは文字列です。SMD・VRは数値セルとして保存し、表示形式で桁数を調整します。欠損値はResultsでは `.`、Excelの数値セルでは通常空欄になります。

### 7.2 `saving()` の保存列

`.dta`では、連続変数は1変数につき1観測、カテゴリ変数は1カテゴリにつき1観測です。

| 変数 | 内容 |
|---|---|
| `variable` | 変数ラベルまたは変数名 |
| `level` | カテゴリの値ラベルまたは値。連続変数は空欄 |
| `type` | `continuous` / `categorical` |
| `group1`, `group2` | 表示用文字列。連続変数は改行を含む |
| `smd`, `vr` | 丸め前の数値 |
| `mean1`, `mean2` | 各群の平均 |
| `sd1`, `sd2` | 各群のSD |
| `median1`, `median2` | 各群の中央値 |
| `q1_1`, `q1_2` | 各群のQ1 |
| `q3_1`, `q3_2` | 各群のQ3 |

上記の連続要約統計10列はdouble精度で保存され、カテゴリ行では欠損です。カテゴリのN・割合を独立した数値列として保存する仕様ではありません。

入力データセットは処理後に復元されます。集計結果を読み込む場合は、必要に応じて `preserve` / `restore` を使ってください。

### 7.3 戻り値（Stored results）

`balreport` はr-classコマンドです。実行直後の `return list` で次のマクロを確認できます。

| 戻り値 | 内容 |
|---|---|
| `r(byvar)` | 群変数名 |
| `r(group1)`, `r(group2)` | 群を定義する数値の文字列表現 |
| `r(group1_label)`, `r(group2_label)` | 表示に使う群ラベル |
| `r(command)` | `balreport` |
| `r(precision_mode)` | `decimal` または `significant` |
| `r(precision_digits)` | 3項目に展開した桁数指定。例：`2 2 3` |

各変数の統計量をr()の行列として返す仕様ではありません。数値を後処理する場合は `saving()` を使います。

---

## 8. 例：`sysuse auto` を使った実行例 🚗

以下はStataに同梱された自動車データを使う例です。`sysuse auto, clear` は現在のデータを置き換えるため、必要なデータは先に保存してください。

### 8.1 重みなし

~~~stata
sysuse auto, clear

* foreign は0/1の2群変数、rep78 はカテゴリ変数
balreport price mpg weight i.rep78, by(foreign)
~~~

### 8.2 Excel出力と小数点以下の桁数指定

~~~stata
sysuse auto, clear

balreport price mpg weight i.rep78, ///
    by(foreign) ///
    decimals(1 2 3) ///
    excel("balreport_auto.xlsx") ///
    sheet("Table1") replace
~~~

平均・SD・中央値・Q1・Q3は小数点以下1桁、割合は2桁、SMD・VRは3桁で表示します。

### 8.3 重み付き・有効数字指定

~~~stata
sysuse auto, clear

* 動作確認用の例示的な重み
generate double example_weight = 1 + _n/100

balreport price mpg weight i.rep78 [pw=example_weight], ///
    by(foreign) ///
    sigfigs(3 2 3) ///
    excel("balreport_weighted.xlsx") replace
~~~

ここで生成した重みは説明用です。実際の解析では、目的に応じて算出した重みを指定してください。中央値・四分位値にも重みが適用されます。

### 8.4 符号付きSMDと解析対象の限定

~~~stata
sysuse auto, clear

balreport price mpg weight i.rep78 if !missing(rep78), ///
    by(foreign) signed
~~~

この例は修理記録が非欠損の観測に限定します。SMDの符号はGroup 2 − Group 1です。

### 8.5 Excelと結果データセットの同時保存

~~~stata
sysuse auto, clear

balreport price mpg weight i.rep78, ///
    by(foreign) ///
    excel("balreport_auto.xlsx") ///
    saving("balreport_result.dta") ///
    replace noprint

return list

preserve
use "balreport_result.dta", clear
list variable mean1 median1 q1_1 q3_1 smd vr if type=="continuous", noobs
restore
~~~

---

## 9. 実務例：IPTW / Stabilized weight後のバランス確認

次は、解析用データを読み込み済みで、曝露変数が `trt`、重みが `sw`、共変量が `age sex stage`、除外フラグが `exclusion` の場合のテンプレートです。これらの変数名を実際のデータに合わせて変更してください。

~~~stata
* 重みなし
balreport age i.sex i.stage if exclusion==0, ///
    by(trt) ///
    decimals(1 1 3) ///
    excel("balance_unweighted.xlsx") replace

* 重み付き
balreport age i.sex i.stage if exclusion==0 [pw=sw], ///
    by(trt) ///
    decimals(1 1 3) ///
    excel("balance_weighted.xlsx") replace
~~~

`balreport` 自体は傾向スコアや重みを推定しません。重みなし・重み付きで同一の解析対象を比較したい場合は、重みの欠損や0による除外も考慮して、共通の対象フラグをあらかじめ作成します。

---

## 10. 事前チェック（Validation rules）✅

| 条件 | 扱い |
|---|---|
| 解析対象が0件 | エラー |
| 有効な `by()` の値が2つでない | エラー |
| `by()` が欠損 | 当該観測を除外 |
| 集計変数が欠損 | 変数ごとに当該観測を除外 |
| 重みが欠損 | Stata標準のサンプル選択処理で除外 |
| 重みが負 | エラー |
| 重みが0 | 当該観測を除外 |
| `fweight` に非整数 | エラー |
| 同じ変数を `categorical()` と `continuous()` に指定 | エラー |
| 交互作用・文字列変数 | 非対応 |
| `decimals()` と `sigfigs()` の併用 | エラー |
| 桁数を2つだけ指定、範囲外、非整数 | エラー |
| 既存Excelに `replace` なしで保存 | エラー |

旧説明文書にあった「重みの欠損は必ずエラーになる」という説明は、現在の挙動には当てはまりません。重みが欠損の観測は解析対象から除外されます。

---

## 11. よくあるエラーと対処（Troubleshooting）🧯

### (A) `command balreport is unrecognized`

インストール先と検索パスを確認します。

~~~stata
sysdir
adopath
which balreport, all
~~~

未インストールなら、第2節の手順で導入します。

### (B) `by() must have exactly two nonmissing levels`

`by()` の群数を、実際の解析条件と重みによる除外を考慮して確認します。

~~~stata
tab trt if exclusion==0 & !missing(sw) & sw>0, missing
~~~

重みがない場合は、重みに関する条件を外してください。

### (C) `Variable not found or not numeric`

変数名と型を確認します。文字列カテゴリは、必要に応じて数値化します。

~~~stata
encode sex_txt, gen(sex)
balreport age i.sex, by(trt)
~~~

### (D) カテゴリ変数なのに連続変数として扱われる

`i.` または `categorical()` を指定します。

~~~stata
balreport age i.sex i.stage, by(trt)
balreport age sex stage, by(trt) categorical(sex stage)
~~~

### (E) `file ... already exists; specify option replace to overwrite it`

Excel全体を上書きしてよい場合に `replace` を付けます。

~~~stata
balreport age i.sex, by(trt) excel("balance.xlsx") replace
~~~

ファイルへのアクセスエラーが出る場合は、保存先の存在・書き込み権限や、Excelでファイルを開いたままになっていないかも確認します。

### (F) `Specify either decimals() or sigfigs(), not both.`

桁数オプションは一方だけ残します。例えば小数点以下の桁数なら `decimals(1 2 3)`、有効数字なら `sigfigs(3 2 3)` とします。

### (G) `requires one number or three numbers`

`decimals(2 3)` のような2値指定はできません。全項目共通なら `decimals(2)`、項目別なら `decimals(2 2 3)` とします。

### (H) 新しいオプションが認識されない・旧版が動く

検索先の重複と、読み込み済みのプログラムを確認します。

~~~stata
which balreport, all
capture program drop balreport
which balreport
~~~

PERSONALやプロジェクト内の旧版が優先されている場合は、第2.3節に従って整理します。`pctdecimals()`・`smddigits()` はv1.1.0では廃止されているため、新しい3値指定へ置き換えてください。

### (I) 重み付きのNが小数になる・合計が元の人数と異なる

重み付きNは重みの合計であり、元の観測人数ではありません。`aw`・`pw`・`iw` では小数になり得ます。表示桁数を変えても、この集計方法は変わりません。

---

## 12. 設計上の注意（Notes）

### 12.1 SMD・VRと中央値の役割

SMDとVRは共変量バランスを確認する記述的指標で、p値による仮説検定ではありません。中央値と四分位値は分布の記述を補うための統計量で、SMD・VRの計算式を変更するものではありません。

### 12.2 重み付き分散と重みなし分散は分母が異なる

重み付き分散は `sum(w)`、重みなし分散は `n-1` で割ります。そのため、全員の重みを1にしても、重み付きと重みなしでSDが一致するとは限りません。`fweight` でも、このコマンドの重み付き分散は `sum(w)` を分母にします。

一方、全員の重みが1なら、中央値・四分位値は重みなしと同じ値になります。

### 12.3 分位点の定義

分位点はStataの `_pctile` の標準定義です。他のソフトウェアや異なる補間方式による分位点と一致しない場合があります。再現時には、重みの種類と分位点定義の両方を合わせてください。

### 12.4 表示用文字列と数値を区別する

`group1`・`group2` は表記用の文字列です。追加計算には、`saving()` の `mean1`、`median1`、`smd` などの数値列を使います。Excelの見た目の桁数を減らしても、SMD・VRのセル内部の数値は保持されます。

---

## 13. 関連ヘルプ・旧コマンドとの関係

- `help balreport`：本コマンドのStata内ヘルプ
- `help net`：外部コマンドのインストール・管理
- `help sysdir`：PLUS・PERSONALと検索パス
- `help pctile`：分位点の定義と `_pctile`
- `help export excel`：Stata標準のExcel出力

`balreport` は `covbalx v0.1.3` を基に、中央値・四分位値、セル内2行表示、表示精度の指定などを追加したコマンドです。既存の `covbal` と区別しやすい名称として `balreport` を使用します。

`covbalx` はインストール不要です。`balreport` を導入しても、別コマンドである `covbalx` や `covbal` を上書きしません。

---

## 14. 変更履歴（Changelog）

- **v1.0.0**
  - `covbalx v0.1.3` を基に、コマンド名を `balreport` として作成
  - 連続変数に中央値・Q1・Q3を追加し、重み付き分位点に対応
  - Excelの群別セルを平均（SD）／中央値（Q1, Q3）の2行表示に変更
  - `saving()` に丸め前の連続要約統計を追加
- **v1.1.0（2026年10月19日）**
  - `decimals()` と `sigfigs()` による表示精度の指定を実装
  - 記述統計・割合・SMD/VRを、それぞれ1つ目・2つ目・3つ目の値で指定
  - 両オプションの同時指定を禁止
  - デフォルトを `decimals(2 2 3)` に設定
  - `pctdecimals()` と `smddigits()` を3値指定に統合
  - 有効数字の末尾0・指数表記と、Excelの数値表示形式に対応
- **文書・配布整備（2026年10月19日、ado本体はv1.1.0のまま）**
  - ヘルプをPLUSへのインストールと汎用例を前提に更新
  - `balreport.pkg`・`stata.toc` を用意
  - 本Markdownマニュアルを作成

旧版の表示精度に合わせたい場合は、次を指定します。

~~~stata
balreport age i.sex, by(trt) decimals(2 1 3)
~~~

---

## 15. 最小テンプレート

以下は `age`、`sex`、`stage`、`trt`、`sw` が存在するデータを前提にしたテンプレートです。

~~~stata
* 重みなし：デフォルトは decimals(2 2 3)
balreport age i.sex i.stage, by(trt)

* 重み付き
balreport age i.sex i.stage [pw=sw], by(trt)

* 小数点以下の桁数を指定してExcel出力
balreport age i.sex i.stage [pw=sw], ///
    by(trt) ///
    decimals(1 1 3) ///
    excel("balance_table.xlsx") replace

* 有効数字を指定してExcelと結果データセットを保存
balreport age i.sex i.stage [pw=sw], ///
    by(trt) ///
    sigfigs(3 2 3) ///
    excel("balance_significant.xlsx") ///
    saving("balance_result.dta") ///
    replace noprint
~~~
