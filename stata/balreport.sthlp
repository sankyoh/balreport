{smcl}
{* *! version 1.1.0 19oct2026}{...}
{title:balreport -- Two-group descriptive statistics and balance report}

{pstd}
Continuous variables are reported as mean (SD) and median (Q1, Q3).
Excel displays these on two lines within each group cell. Categorical variables
are reported as N (%). SMD and variance ratio (VR) retain the covbalx definitions.

{title:Installation and requirements}

{pstd}
{cmd:balreport} is a standalone community-contributed command for Stata 18 or
later. It uses only built-in Stata and Mata functionality. No other
community-contributed commands, including covbalx, are required. All helper
functions are included in balreport.ado. Microsoft Excel is not required to
create an xlsx workbook.

{pstd}
Install from the directory or URL containing balreport.pkg, balreport.ado and
balreport.sthlp. Replace PACKAGE_URL below with that directory or URL:

{phang2}{cmd:net set ado PLUS}{p_end}
{phang2}{cmd:net install balreport, from("PACKAGE_URL") replace}{p_end}
{phang2}{cmd:capture program drop balreport}{p_end}
{phang2}{cmd:which balreport}{p_end}
{phang2}{cmd:help balreport}{p_end}

{pstd}
For GitHub distribution, PACKAGE_URL must be the raw-content directory that
contains the package files, for example
{it:https://raw.githubusercontent.com/OWNER/REPOSITORY/REF/} when the files are
at the repository root. Replace OWNER, REPOSITORY and REF with the actual owner,
repository and branch name or release tag. Append a subdirectory when needed.
This URL is a template, not a published download location. The normal GitHub
repository page or a URL ending in .ado is not the package directory.

{pstd}
This command is distributed in the repository sankyoh/balreport, with the
package files in its stata directory.
PACKAGE_URL is https://raw.githubusercontent.com/sankyoh/balreport/main/stata.
Use the actual source URL if distributing a fork at a different location.

{pstd}
The optional sample.do uses only Stata's bundled automobile dataset. Retrieve
it into the current working directory with
{cmd:net get balreport, from("PACKAGE_URL")}, then run {cmd:do sample.do}.
The example replaces data in memory and creates or replaces files inside
balreport_example_output under the working directory. The detailed Japanese
manual is docs/balreport.md in the repository.

{pstd}
{cmd:sysdir} shows the location of PLUS on the current computer. Stata normally
places the installed files in its b subdirectory: PLUS/b/balreport.ado and
PLUS/b/balreport.sthlp. The actual root differs between computers and operating
systems; no user-specific absolute path should be placed in this command.
Installation does not require a project directory, a global macro named PROJ,
or an {cmd:adopath ++} line. After installation, run {cmd:balreport} directly
on the dataset currently in memory. Relative output filenames are resolved
against Stata's current working directory; supply a full path to save elsewhere.

{pstd}
When migrating from a local copy, remove the old project-directory
{cmd:adopath ++} line from the calling do-file. A previously added directory
can be removed from the current search path with {cmd:adopath - "directory"}.
Use {cmd:which balreport, all} to find duplicate copies. Copies in PERSONAL,
the current directory, or an earlier search directory may take precedence over
PLUS. Move obsolete balreport.ado and balreport.sthlp copies outside the search
path, then run {cmd:capture program drop balreport} to unload the cached command.
Verify that {cmd:which balreport} now reports the intended PLUS copy.

{title:Syntax}

{p 8 12 2}
{cmd:balreport} {varlist} {ifin} [{it:weight}], {cmd:by(}{varname}{cmd:)}
[{cmd:categorical(}{varlist}{cmd:)} {cmd:continuous(}{varlist}{cmd:)}
{cmd:excel(}{it:filename}{cmd:)} {cmd:saving(}{it:filename}{cmd:)}
{cmd:sheet(}{it:sheetname}{cmd:)} {cmd:replace} {cmd:signed} {cmd:noprint}
{cmd:decimals(}{it:#} [{it:# #}]{cmd:)} |
{cmd:sigfigs(}{it:#} [{it:# #}]{cmd:)}]

{pstd}
Requires Stata 18 or later. Supports fweights, aweights, pweights and iweights.
by() must contain exactly two nonmissing numeric levels. The lower level is
group 1 and the higher level is group 2. Use i.var or categorical() for
categorical variables. Plain variables and c.var are continuous by default.
Interactions and string variables are not supported.

{title:Statistics and missing values}

{pstd}
All summaries use the same if/in restriction and positive weights. Missing
values are excluded separately for each variable. A continuous variable with no
usable values in one group has missing summaries for that group; summaries in
the other group are still reported. For categorical variables, a group with no
usable values has zero counts and missing percentages. If no categories are
observed in either group, one placeholder row is reported.
Negative weights are rejected, zero weights are excluded, and fweights must be
integers. Native Stata sample marking excludes observations with missing weights.

{pstd}
Q1, median and Q3 are the 25th, 50th and 75th percentiles from
{helpb pctile:_pctile}, using the default definition (no altdef).
Weights are retained for percentile calculations. Because _pctile does not
accept iweights, iweights are passed as aweights with unchanged values for
percentiles only. Weights describe a pseudo-population; no survey-design
standard errors or percentile confidence intervals are computed.

{pstd}
Unweighted variance divides the squared-deviation sum by n-1. Weighted variance
divides the weighted squared-deviation sum by sum(w), as in covbalx v0.1.3.
Thus all-one weights give the same percentiles as no weights but need not give
the same SD. SMD = (mean2-mean1)/sqrt((variance1+variance2)/2), absolute by default;
signed retains its sign. VR = variance2/variance1. SMD and VR do not use medians.
Categorical SMD is reported separately for each level; categorical VR is missing.

{title:Output options}

{pstd}
excel() writes an xlsx workbook with columns Variable, Level, Type, the two
groups, SMD and VR. The default sheet is balreport. Continuous group cells contain
mean (SD), a line break, then median (Q1, Q3). Wrapping, column widths and row
heights are set with Stata's built-in Mata xl class. replace allows replacement
of the whole workbook. The workbook is prepared in a temporary file before it
is copied to the destination. Without replace, an existing workbook is protected.

{pstd}
saving() retains variable, level, type, group1, group2, smd and vr, plus unrounded
double-precision mean1, sd1, median1, q1_1, q3_1, mean2, sd2, median2, q1_2 and
q3_2. These additional numeric columns are missing for categorical rows.
As in covbalx, saving() overwrites an existing dta file.

{title:Display precision}

{pstd}
Specify either {cmd:decimals()} or {cmd:sigfigs()}; they cannot be combined.
Both accept one integer or three integers in this order:
(1) mean, SD, median, Q1 and Q3; (2) percentages; (3) SMD and VR.
One integer applies to all three categories. Two integers are not accepted.

{pstd}
{cmd:decimals(2 2 3)} is the default: continuous summaries and percentages
have two decimal places, and SMD/VR have three. Allowed values are 0 through 10.
{cmd:decimals(1 2 4)} selects one, two and four decimal places respectively.
{cmd:decimals(2)} sets all three categories to two decimal places.

{pstd}
{cmd:sigfigs(3 2 3)} selects three significant figures for continuous summaries,
two for percentages and three for SMD/VR. Allowed values are 1 through 15.
{cmd:sigfigs(3)} selects three significant figures for all three categories.
Trailing zeros are retained, e.g. 1.2 becomes 1.20 with three significant
figures. Rounding is applied before deciding the decimal position, so 9.999
becomes 10.0. Values with rounded exponent below -4 or at least the requested
number of significant figures use scientific notation (e.g. 1.23e+04).
Zero is shown as 0 followed by the required decimal zeros (0.00 for three
significant figures); missing values remain dots.

{pstd}
Counts from aweights, pweights and iweights follow the first precision setting,
even when their numeric values are integers. Observed counts and fweight counts
remain integers. Percentages are formatted on the 0-100
scale. These options affect display only: saved numeric summaries and Excel
SMD/VR cells retain their original numeric values. Excel uses per-cell numeric
formats to match the requested significant figures.

{pstd}
Version 1.1 replaces the old pctdecimals() and smddigits() options with the
second and third entries of decimals(). To reproduce version 1.0's default
precision, specify decimals(2 1 3). A single decimals(#) now applies to all
three categories. The Results window uses two physical rows for continuous
variables. noprint suppresses that display. The input dataset is restored.

{title:Examples}

{pstd}
These examples use Stata's bundled automobile dataset. They require no project
files or external datasets. {cmd:sysuse auto, clear} replaces the data in memory;
save your current data first if needed.

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:balreport price mpg i.rep78, by(foreign)}{p_end}
{phang2}{cmd:balreport price mpg i.rep78, by(foreign) excel("balance.xlsx") replace}{p_end}
{phang2}{cmd:balreport price mpg i.rep78, by(foreign) decimals(1 2 3) excel("decimal.xlsx") replace}{p_end}
{phang2}{cmd:balreport price mpg i.rep78, by(foreign) sigfigs(3 2 3) excel("significant.xlsx") replace}{p_end}

{pstd}
For illustration, generate positive example weights. In an analysis, use your
own appropriately constructed weight variable.

{phang2}{cmd:generate double example_weight = 1 + _n/100}{p_end}
{phang2}{cmd:balreport price mpg i.rep78 [pw=example_weight], by(foreign) excel("weighted.xlsx") replace}{p_end}
{phang2}{cmd:balreport price mpg [iw=example_weight], by(foreign) saving("summary.dta") noprint}{p_end}

{title:Stored results}

{pstd}
r(byvar), r(group1), r(group2), r(group1_label), r(group2_label),
and r(command) (balreport). r(precision_mode) is decimal or significant;
r(precision_digits) contains the three resolved precision settings.

{title:Origin}

{pstd}
Based on covbalx v0.1.3 (24jun2026), prepared for Toshiharu Mitsuhashi.
The original covbalx command is neither required nor modified by this package.

{title:Author and license}

{pstd}
Toshiharu Mitsuhashi. GitHub: https://github.com/sankyoh.
Distributed under the MIT License; see LICENSE in the repository root.
