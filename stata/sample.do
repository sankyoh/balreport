/*
-------------------------------------------------------------------------------
 balreport: examples using Stata's bundled automobile dataset
 Version 1.1.0 | 19 October 2026 | Stata 18 or later

 Repository: https://github.com/sankyoh/balreport
 Install balreport separately; this do-file does not download or install anything.
 No other community-contributed commands are required.

 IMPORTANT
 - sysuse auto, clear replaces the dataset in memory. Save your data first.
 - Run this file from a writable working directory.
 - Output is written to balreport_example_output under the current directory.
 - Existing example workbooks and summary datasets are replaced when rerun.
-------------------------------------------------------------------------------
*/

version 18.0
set more off

capture which balreport
if _rc {
    display as error "balreport is not installed or is not on the ado search path."
    display as error "Install the published balreport package, then rerun this file."
    exit 199
}
which balreport

local outdir "balreport_example_output"
capture mkdir "`outdir'"

sysuse auto, clear

// ---------------------------------------------------------------------------
// 1. Basic report: continuous and categorical variables
// ---------------------------------------------------------------------------
// Plain variables are continuous; i.rep78 requests a row for each repair level.
// by(foreign) compares Domestic (0, group 1) with Foreign (1, group 2).
// Continuous cells contain mean (SD), followed by median (Q1, Q3).
// Default precision: decimals(2 2 3).

balreport price mpg i.rep78, by(foreign) ///
    excel("`outdir'/default.xlsx") replace

// The categorical() option is an alternative to i.var notation.
balreport price mpg rep78, by(foreign) categorical(rep78)

// ---------------------------------------------------------------------------
// 2. Decimal places: summaries, percentages, and SMD/VR
// ---------------------------------------------------------------------------
// The three settings apply to:
// (1) mean, SD, median, Q1, Q3; (2) percentages; (3) SMD and variance ratio.
// A single number, such as decimals(2), applies to all three categories.

balreport price mpg i.rep78, by(foreign) decimals(1 2 3) ///
    excel("`outdir'/decimal.xlsx") sheet("Decimal places") replace

// ---------------------------------------------------------------------------
// 3. Significant figures
// ---------------------------------------------------------------------------
// Use either decimals() or sigfigs(); they cannot be specified together.
// Scientific notation is used when needed to show the requested precision.
// Excel SMD and VR cells retain their underlying numeric values.

balreport price mpg i.rep78, by(foreign) sigfigs(3 2 3) ///
    excel("`outdir'/significant.xlsx") sheet("Significant figures") replace

// ---------------------------------------------------------------------------
// 4. Positive example weights and a restricted analysis sample
// ---------------------------------------------------------------------------
// These arbitrary positive weights illustrate syntax only. They are not
// propensity-score weights and do not represent a substantive analysis.
// In your own analysis, supply an appropriately constructed weight variable.
// Stata's if/in qualifiers precede the weight specification.
// Weighted means, SDs and quantiles use the same restricted sample.

generate double example_weight = 1 + _n/100

balreport price mpg i.rep78 if mpg >= 20 & !missing(mpg) ///
    [pw=example_weight], by(foreign) decimals(2 2 3) ///
    excel("`outdir'/weighted.xlsx") replace

// fweights, aweights and iweights are also supported. iweights are passed as
// aweights with unchanged values for quantiles only. Weighted variance divides
// by sum(w), whereas unweighted variance divides by n-1. Therefore, all-one
// weights can produce a different SD from an unweighted report.

// ---------------------------------------------------------------------------
// 5. Save unrounded summaries and inspect returned metadata
// ---------------------------------------------------------------------------
// saving() writes display strings plus unrounded numeric summaries, SMD and VR.
// It overwrites an existing .dta file. noprint suppresses the Results table.
// This example uses the full dataset, without the preceding if restriction.

balreport price mpg i.rep78 [pw=example_weight], by(foreign) ///
    sigfigs(3 2 3) saving("`outdir'/weighted_raw.dta") noprint
return list

// Examine selected numeric columns without replacing the working dataset.
// Numeric summaries are missing for categorical rows.
preserve
use "`outdir'/weighted_raw.dta", clear
list variable type mean1 median1 mean2 median2 smd vr, noobs
restore

// ---------------------------------------------------------------------------
// 6. Signed standardized mean differences
// ---------------------------------------------------------------------------
// SMD is absolute by default. signed retains the sign of mean2 - mean1.
// Foreign cars have lower mean weight in this dataset, giving a negative SMD.
// VR always uses variance(group 2) / variance(group 1).

balreport weight mpg, by(foreign) signed

display as text "Examples complete. Output directory: `outdir'"
