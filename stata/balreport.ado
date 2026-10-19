*! balreport.ado  v1.1.0  19oct2026
*! Covariate balance table with descriptive statistics, SMD, and VR
*! Derived from covbalx v0.1.3 for Toshiharu Mitsuhashi

program define balreport, rclass
    version 18.0

    /*
    Purpose
    -------
    Create a two-group covariate balance table.

    Features
    --------
    - Continuous variables: mean (SD) and median (Q1, Q3), SMD, variance ratio
    - Categorical variables: weighted/unweighted N (%), SMD for each category level
    - Supports fweight/aweight/pweight/iweight as pseudo-population weights
    - Excel continuous-variable cells have two lines with wrapping and row height
    - saving() retains unrounded numeric summaries as well as display strings
    - Select decimal places OR significant figures, with separate precision
      for descriptive statistics, percentages and balance diagnostics

    Important conventions
    ---------------------
    - by() must have exactly two nonmissing levels.
    - The first by() level is group 1; the second by() level is group 2.
    - SMD is calculated as group 2 minus group 1, then shown as absolute value
      unless option signed is specified.
    - VR is calculated as variance(group 2) / variance(group 1).
    - Categorical variables should be specified with factor notation, e.g. i.sex,
      or listed in categorical(). Interactions are not supported.
    - Quantiles use _pctile's default definition, with the supplied weights.
      iweights are passed as aweights for quantiles only (same weight values).
    - Weighted variance divides by sum(w); unweighted variance divides by n-1.
    */

    syntax varlist(fv) [if] [in] [fweight aweight pweight iweight], ///
        BY(varname numeric) ///
        [ CATEGORICAL(varlist numeric) ///
          CONTINUOUS(varlist numeric) ///
          EXCEL(string asis) ///
          SAVING(string asis) ///
          SHEET(string asis) ///
          REPLACE ///
          SIGNED ///
          NOPRINT ///
          DECimals(numlist integer min=1 max=3 >=0 <=10) ///
          SIGfigs(numlist integer min=1 max=3 >=1 <=15) ]

    // --------------------------
    // 0) Basic checks and setup
    // --------------------------
    if "`decimals'" != "" & "`sigfigs'" != "" {
        di as error "Specify either decimals() or sigfigs(), not both."
        exit 198
    }
    foreach opt in decimals sigfigs {
        local ndigits : word count ``opt''
        if `ndigits' == 2 {
            di as error "`opt'() requires one number or three numbers."
            di as error "Order: descriptive statistics, percentages, SMD/VR."
            exit 198
        }
        if `ndigits' == 1 local `opt' "``opt'' ``opt'' ``opt''"
    }
    if "`sigfigs'" != "" {
        local precision_mode "significant"
        local precision_digits "`sigfigs'"
        local pctsigfigs : word 2 of `sigfigs'
        local smdsigfigs : word 3 of `sigfigs'
        local sigfigs : word 1 of `sigfigs'
        local decimals 2
        local pctdecimals 2
        local smddigits 3
    }
    else {
        if "`decimals'" == "" local decimals "2 2 3"
        local precision_mode "decimal"
        local precision_digits "`decimals'"
        local pctdecimals : word 2 of `decimals'
        local smddigits : word 3 of `decimals'
        local decimals : word 1 of `decimals'
        local sigfigs 0
        local pctsigfigs 0
        local smdsigfigs 0
    }

    // Remove outer/double quotes that may be preserved by string asis options.
    // This makes excel("file.xlsx") and excel(file.xlsx) behave identically.
    local sheet `"`sheet'"'
    local sheet : subinstr local sheet `"""' "", all
    if `"`sheet'"' == "" {
        local sheet "balreport"
    }

    tempvar touse wvar
    marksample touse, novarlist strok
    markout `touse' `by'

    // --------------------------
    // 1) Weight handling
    // --------------------------
    local hasweight = 0
    if "`weight'" != "" {
        local hasweight = 1
        local wexpr = strtrim(subinstr("`exp'", "=", "", 1))
        quietly gen double `wvar' = `wexpr' if `touse'

        quietly count if `touse' & missing(`wvar')
        if r(N) > 0 {
            di as error "The weight variable/expression has missing values within the analysis sample."
            di as error "N with missing weight = " r(N)
            exit 2000
        }

        quietly count if `touse' & `wvar' < 0
        if r(N) > 0 {
            di as error "Negative weights are not allowed."
            di as error "N with negative weight = " r(N)
            exit 402
        }

        if "`weight'" == "fweight" {
            capture assert floor(`wvar') == `wvar' if `touse'
            if _rc {
                di as error "fweights must be nonnegative integers."
                exit 401
            }
        }

        // Zero weights are mathematically allowed, but they do not contribute.
        quietly replace `touse' = 0 if `touse' & `wvar' == 0
    }
    else {
        quietly gen double `wvar' = 1 if `touse'
    }

    // _pctile does not accept iweights. All weights here describe probability
    // mass; use their unchanged values as aweights for that calculation only.
    local qweight ""
    if `hasweight' {
        local qtype "`weight'"
        if "`qtype'" == "iweight" local qtype "aweight"
        local qweight "[`qtype'=`wvar']"
    }

    quietly count if `touse'
    if r(N) == 0 {
        di as error "No observations in the analysis sample."
        exit 2000
    }

    // --------------------------
    // 2) by() must have exactly two levels
    // --------------------------
    quietly levelsof `by' if `touse', local(bylvls)
    local ng : word count `bylvls'
    if `ng' != 2 {
        di as error "by() must have exactly two nonmissing levels in the analysis sample."
        di as error "Observed number of levels: `ng'"
        exit 420
    }

    local g1 : word 1 of `bylvls'
    local g2 : word 2 of `bylvls'

    local byvlab : value label `by'
    if "`byvlab'" != "" {
        local g1lab : label `byvlab' `g1'
        local g2lab : label `byvlab' `g2'
    }
    else {
        local g1lab "`g1'"
        local g2lab "`g2'"
    }

    // --------------------------
    // 3) Parse varlist and decide variable types
    // --------------------------
    local overlap : list categorical & continuous
    if "`overlap'" != "" {
        di as error "Variables cannot be listed in both categorical() and continuous(): `overlap'"
        exit 198
    }

    local workvars ""
    local worktypes ""
    local seen ""

    foreach tok of local varlist {
        if strpos("`tok'", "#") {
            di as error "Interactions are not supported: `tok'"
            exit 198
        }

        local base "`tok'"
        local ftype ""

        local dotpos = strpos("`tok'", ".")
        if `dotpos' > 0 {
            local prefix = substr("`tok'", 1, `dotpos' - 1)
            local base   = substr("`tok'", `dotpos' + 1, .)

            if "`prefix'" == "c" {
                local ftype "continuous"
            }
            else if substr("`prefix'", 1, 1) == "i" | substr("`prefix'", 1, 2) == "ib" | substr("`prefix'", 1, 1) == "b" {
                local ftype "categorical"
            }
            else {
                di as error "Unsupported factor-variable prefix in `tok'. Use plain variables, c.var, or i.var."
                exit 198
            }
        }

        capture confirm numeric variable `base'
        if _rc {
            di as error "Variable not found or not numeric: `base'"
            exit 111
        }

        local already : list posof "`base'" in seen
        if `already' > 0 {
            continue
        }

        local incat : list posof "`base'" in categorical
        local incont : list posof "`base'" in continuous

        if `incat' > 0 {
            local ftype "categorical"
        }
        if `incont' > 0 {
            local ftype "continuous"
        }
        if "`ftype'" == "" {
            local ftype "continuous"
        }

        local seen `seen' `base'
        local workvars `workvars' `base'
        local worktypes `worktypes' `ftype'
    }

    // --------------------------
    // 4) Prepare result container
    // --------------------------
    tempfile results
    tempname posth

    postfile `posth' ///
        str244 variable ///
        str244 level ///
        str16 type ///
        str244 group1 ///
        str244 group2 ///
        double smd ///
        double vr ///
        double mean1 double sd1 double median1 double q1_1 double q3_1 ///
        double mean2 double sd2 double median2 double q1_2 double q3_2 ///
        using `"`results'"', replace

    // --------------------------
    // 5) Main loop
    // --------------------------
    local k : word count `workvars'
    forvalues j = 1/`k' {
        local v : word `j' of `workvars'
        local vartype : word `j' of `worktypes'

        local varlab : variable label `v'
        if `"`varlab'"' == "" {
            local varlab "`v'"
        }

        if "`vartype'" == "continuous" {
            tempvar wx wss1 wss2
            tempname sw1 sw2 n1 n2 sx1 sx2 m1 m2 ss1 ss2 var1 var2 sd1 sd2 smd vr denom diff
            tempname q1_1 med1 q3_1 q1_2 med2 q3_2

            quietly count if `touse' & `by' == `g1' & !missing(`v')
            scalar `n1' = r(N)
            quietly count if `touse' & `by' == `g2' & !missing(`v')
            scalar `n2' = r(N)

            quietly summarize `wvar' if `touse' & `by' == `g1' & !missing(`v'), meanonly
            scalar `sw1' = r(sum)
            quietly summarize `wvar' if `touse' & `by' == `g2' & !missing(`v'), meanonly
            scalar `sw2' = r(sum)

            scalar `m1' = .
            scalar `m2' = .
            scalar `var1' = .
            scalar `var2' = .
            scalar `sd1' = .
            scalar `sd2' = .
            scalar `smd' = .
            scalar `vr' = .
            scalar `q1_1' = .
            scalar `med1' = .
            scalar `q3_1' = .
            scalar `q1_2' = .
            scalar `med2' = .
            scalar `q3_2' = .

            // Compute each group independently: a missing group must not hide
            // descriptive statistics for the other group.
            quietly gen double `wx' = `wvar' * `v' if `touse' & !missing(`v')
            forvalues h = 1/2 {
                if (`n`h'' > 0 & `sw`h'' > 0 & `sw`h'' < .) {
                    quietly summarize `wx' if `by' == `g`h'', meanonly
                    scalar `sx`h'' = r(sum)
                    scalar `m`h'' = `sx`h'' / `sw`h''

                    quietly gen double `wss`h'' = `wvar' * (`v' - `m`h'')^2 ///
                        if `touse' & `by' == `g`h'' & !missing(`v')
                    quietly summarize `wss`h'', meanonly
                    scalar `ss`h'' = r(sum)

                    if `hasweight' == 0 {
                        if (`n`h'' > 1) scalar `var`h'' = `ss`h'' / (`n`h'' - 1)
                    }
                    else {
                        scalar `var`h'' = `ss`h'' / `sw`h''
                    }
                    if (`var`h'' >= 0 & `var`h'' < .) scalar `sd`h'' = sqrt(`var`h'')

                    quietly _pctile `v' if `touse' & `by' == `g`h'' & !missing(`v') ///
                        `qweight', percentiles(25 50 75)
                    scalar `q1_`h'' = r(r1)
                    scalar `med`h'' = r(r2)
                    scalar `q3_`h'' = r(r3)
                }
            }

            if (`var1' < . & `var2' < .) {
                scalar `denom' = sqrt((`var1' + `var2') / 2)
                scalar `diff'  = `m2' - `m1'
                if (`denom' > 0) {
                    scalar `smd' = `diff' / `denom'
                }
                else if (`denom' == 0 & `diff' == 0) {
                    scalar `smd' = 0
                }
                if "`signed'" == "" & `smd' < . {
                    scalar `smd' = abs(`smd')
                }

                if (`var1' > 0 & `var2' < .) {
                    scalar `vr' = `var2' / `var1'
                }
                else if (`var1' == 0 & `var2' == 0) {
                    scalar `vr' = 1
                }
            }

            forvalues h = 1/2 {
                mata: st_local("ms", _balreport_num(st_numscalar("`m`h''"), `decimals', `sigfigs'))
                mata: st_local("sds", _balreport_num(st_numscalar("`sd`h''"), `decimals', `sigfigs'))
                mata: st_local("meds", _balreport_num(st_numscalar("`med`h''"), `decimals', `sigfigs'))
                mata: st_local("q1s", _balreport_num(st_numscalar("`q1_`h''"), `decimals', `sigfigs'))
                mata: st_local("q3s", _balreport_num(st_numscalar("`q3_`h''"), `decimals', `sigfigs'))
                local cell`h' = "`ms' (`sds')" + char(10) + "`meds' (`q1s', `q3s')"
            }

            post `posth' (`"`varlab'"') ("") ("continuous") (`"`cell1'"') (`"`cell2'"') (`smd') (`vr') ///
                (`m1') (`sd1') (`med1') (`q1_1') (`q3_1') ///
                (`m2') (`sd2') (`med2') (`q1_2') (`q3_2')
        }
        else if "`vartype'" == "categorical" {
            tempname sw1 sw2 c1 c2 p1 p2 smd vr denom diff

            quietly summarize `wvar' if `touse' & `by' == `g1' & !missing(`v'), meanonly
            scalar `sw1' = r(sum)
            quietly summarize `wvar' if `touse' & `by' == `g2' & !missing(`v'), meanonly
            scalar `sw2' = r(sum)

            quietly levelsof `v' if `touse' & !missing(`v'), local(vlvls)
            local nlev : word count `vlvls'
            if `nlev' == 0 {
                post `posth' (`"`varlab'"') ("(no nonmissing levels)") ("categorical") ("") ("") (.) (.) ///
                    (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
                continue
            }

            local vallab : value label `v'

            foreach lev of local vlvls {
                scalar `c1' = .
                scalar `c2' = .
                scalar `p1' = .
                scalar `p2' = .
                scalar `smd' = .
                scalar `vr' = .

                quietly summarize `wvar' if `touse' & `by' == `g1' & `v' == `lev', meanonly
                scalar `c1' = r(sum)
                quietly summarize `wvar' if `touse' & `by' == `g2' & `v' == `lev', meanonly
                scalar `c2' = r(sum)

                if (`sw1' > 0) scalar `p1' = `c1' / `sw1'
                if (`sw2' > 0) scalar `p2' = `c2' / `sw2'

                scalar `denom' = sqrt((`p1' * (1 - `p1') + `p2' * (1 - `p2')) / 2)
                scalar `diff'  = `p2' - `p1'
                if (`denom' > 0) {
                    scalar `smd' = `diff' / `denom'
                }
                else if (`denom' == 0 & `diff' == 0) {
                    scalar `smd' = 0
                }
                if "`signed'" == "" & `smd' < . {
                    scalar `smd' = abs(`smd')
                }

                if "`vallab'" != "" {
                    local levlab : label `vallab' `lev'
                }
                else {
                    local levlab "`lev'"
                }

                if "`weight'" == "" | "`weight'" == "fweight" {
                    local c1s : display %12.0f `c1'
                    local c2s : display %12.0f `c2'
                }
                else {
                    mata: st_local("c1s", _balreport_num(st_numscalar("`c1'"), `decimals', `sigfigs'))
                    mata: st_local("c2s", _balreport_num(st_numscalar("`c2'"), `decimals', `sigfigs'))
                }
                local p1pct = 100 * `p1'
                local p2pct = 100 * `p2'
                mata: st_local("p1s", _balreport_num(100*st_numscalar("`p1'"), `pctdecimals', `pctsigfigs'))
                mata: st_local("p2s", _balreport_num(100*st_numscalar("`p2'"), `pctdecimals', `pctsigfigs'))
                local c1s = strtrim("`c1s'")
                local c2s = strtrim("`c2s'")
                local p1s = strtrim("`p1s'")
                local p2s = strtrim("`p2s'")

                local cell1 "`c1s' (`p1s'%)"
                local cell2 "`c2s' (`p2s'%)"

                post `posth' (`"`varlab'"') (`"`levlab'"') ("categorical") (`"`cell1'"') (`"`cell2'"') (`smd') (.) ///
                    (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
            }
        }
        else {
            di as error "Internal error: unknown variable type for `v'."
            exit 198
        }
    }

    postclose `posth'

    // --------------------------
    // 6) Display and export
    // --------------------------
    preserve
        use `"`results'"', clear

        label variable variable "Variable"
        label variable level    "Level"
        label variable type     "Type"
        label variable group1   "`g1lab'"
        label variable group2   "`g2lab'"
        label variable smd      "SMD"
        label variable vr       "VR"
        forvalues h = 1/2 {
            label variable mean`h'   "Group `h': mean"
            label variable sd`h'     "Group `h': SD"
            label variable median`h' "Group `h': median"
            label variable q1_`h'    "Group `h': Q1 (25th percentile)"
            label variable q3_`h'    "Group `h': Q3 (75th percentile)"
        }

        if `smdsigfigs' == 0 {
            format smd vr %24.`smddigits'f
        }
        else {
            // Numeric saved values stay unrounded. The displayed table uses
            // strings and Excel uses a per-cell numeric format below.
            format smd vr %24.0g
        }

        if "`noprint'" == "" {
            di as text _n "Covariate balance table"
            di as text "Group 1: `g1lab' (`by'=`g1')"
            di as text "Group 2: `g2lab' (`by'=`g2')"
            if `hasweight' == 1 {
                di as text "Weighted using [`weight'`exp']"
            }
            if "`signed'" == "" {
                di as text "SMD is shown as absolute value. VR = variance(Group 2) / variance(Group 1)."
            }
            else {
                di as text "SMD = Group 2 - Group 1. VR = variance(Group 2) / variance(Group 1)."
            }
            di as text "Continuous cells: mean (SD); median (Q1, Q3)."
            // Use two physical rows in the Results window, while keeping one
            // observation per variable in saving() and one two-line Excel cell.
            tempname displayframe
            frame put variable level type group1 group2 smd vr, into(`displayframe')
            frame `displayframe' {
                tempvar order summary
                gen long `order' = _n
                expand 2 if type == "continuous", generate(`summary')
                replace group1 = substr(group1, 1, strpos(group1, char(10)) - 1) ///
                    if type == "continuous" & !`summary'
                replace group2 = substr(group2, 1, strpos(group2, char(10)) - 1) ///
                    if type == "continuous" & !`summary'
                replace group1 = substr(group1, strpos(group1, char(10)) + 1, .) if `summary'
                replace group2 = substr(group2, strpos(group2, char(10)) + 1, .) if `summary'
                replace level = "mean (SD)" if type == "continuous" & !`summary'
                replace level = "median (Q1, Q3)" if `summary'
                replace variable = "" if `summary'
                replace smd = . if `summary'
                replace vr = . if `summary'
                tempvar numeric_smd numeric_vr
                rename smd `numeric_smd'
                rename vr `numeric_vr'
                gen str32 smd = ""
                gen str32 vr = ""
                mata: st_sstore(., "smd", _balreport_nums(st_data(., "`numeric_smd'"), `smddigits', `smdsigfigs'))
                mata: st_sstore(., "vr", _balreport_nums(st_data(., "`numeric_vr'"), `smddigits', `smdsigfigs'))
                format smd vr %24s
                sort `order' `summary'
                list variable level group1 group2 smd vr, noobs abbreviate(24) separator(0)
            }
        }

        if `"`excel'"' != "" {
            local xlsx `"`excel'"'
            local xlsx : subinstr local xlsx `"""' "", all
            if !regexm(lower(`"`xlsx'"'), "\.xlsx$") {
                local xlsx `"`xlsx'.xlsx"'
            }

            if "`replace'" == "" {
                // Without replace, do not overwrite an existing workbook.
                // This follows Stata's usual replace semantics: existing output files
                // are protected unless option replace is explicitly specified.
                capture confirm file `"`xlsx'"'
                if !_rc {
                    di as error "file `xlsx' already exists; specify option replace to overwrite it"
                    exit 602
                }
            }

            // Stage the formatted workbook before replacing the destination.
            // Numeric summaries remain in saving(), not extra visible columns.
            tempfile bookbase
            local book `"`bookbase'.xlsx"'
            capture noisily {
                export excel variable level type group1 group2 smd vr using `"`book'"', ///
                    sheet(`"`sheet'"') firstrow(varlabels) replace
                mata: _balreport_format(st_local("book"), st_local("sheet"), `smddigits', `smdsigfigs')
                copy `"`book'"' `"`xlsx'"', `replace'
            }
            local export_rc = _rc
            capture erase `"`book'"'
            if `export_rc' exit `export_rc'
        }

        if `"`saving'"' != "" {
            local dta `"`saving'"'
            local dta : subinstr local dta `"""' "", all
            if !regexm(lower(`"`dta'"'), "\.dta$") {
                local dta `"`dta'.dta"'
            }
            save `"`dta'"', replace
        }
    restore

    return local byvar "`by'"
    return local group1 "`g1'"
    return local group2 "`g2'"
    return local group1_label "`g1lab'"
    return local group2_label "`g2lab'"
    return local command "balreport"
    return local precision_mode "`precision_mode'"
    return local precision_digits "`precision_digits'"
end

capture mata: mata drop _balreport_format()
capture mata: mata drop _balreport_num()
capture mata: mata drop _balreport_nums()
capture mata: mata drop _balreport_xlfmt()
mata:
string scalar _balreport_num(real scalar x, real scalar decimals, real scalar sigfigs)
{
    real scalar pos, exponent, lead, cut
    string scalar s, mantissa, figures, sign, exponent_text, zeros, fmt
    zeros = "000000000000000"
    if (missing(x)) return(strtrim(strofreal(x)))
    if (sigfigs==0) {
        fmt = "%32." + strofreal(decimals) + "f"
        s = strtrim(strofreal(x, fmt))
        // Display rounded zero without a misleading minus sign.
        if (strtoreal(s)==0 & substr(s,1,1)=="-") s = substr(s,2,.)
        return(s)
    }
    if (x==0) {
        if (sigfigs==1) return("0")
        return("0." + substr(zeros,1,sigfigs-1))
    }
    sign = (x<0 ? "-" : "")
    // Round in exponential form first, so carries across powers of ten are
    // handled before choosing decimal places. Never round the stored value.
    fmt = "%24." + strofreal(sigfigs-1) + "e"
    s = strtrim(strofreal(abs(x), fmt))
    pos = strpos(s,"e")
    exponent = strtoreal(substr(s,pos+1,.))
    mantissa = substr(s,1,pos-1)
    if (sigfigs==1) {
        // Stata's %w.0e means full precision, not one significant figure.
        // Round its first digit directly (avoids double rounding via %w.1e).
        lead = strtoreal(substr(mantissa,1,1))
        if (strtoreal(substr(mantissa,3,1))>=5) lead++
        if (lead==10) {
            lead = 1
            exponent++
        }
        mantissa = strofreal(lead)
    }
    figures = subinstr(mantissa,".","")
    if (exponent < -4 | exponent >= sigfigs) {
        exponent_text = strtrim(strofreal(abs(exponent),"%3.0f"))
        if (strlen(exponent_text)<2) exponent_text = "0" + exponent_text
        return(sign + mantissa + "e" + (exponent<0 ? "-" : "+") + exponent_text)
    }
    if (exponent<0) return(sign + "0." + substr(zeros,1,-exponent-1) + figures)
    cut = exponent+1
    s = substr(figures,1,cut)
    if (cut<sigfigs) s = s + "." + substr(figures,cut+1,.)
    return(sign+s)
}

string colvector _balreport_nums(real colvector values, real scalar decimals, real scalar sigfigs)
{
    real scalar i
    string colvector result
    result = J(rows(values),1,"")
    for (i=1; i<=rows(values); i++) result[i] = _balreport_num(values[i],decimals,sigfigs)
    return(result)
}

string scalar _balreport_xlfmt(real scalar x, real scalar decimals, real scalar sigfigs)
{
    real scalar pos, places
    string scalar s, fmt, zeros
    zeros = "0000000000000000000"
    places = decimals
    if (sigfigs>0) {
        s = _balreport_num(x,decimals,sigfigs)
        if (strpos(s,"e")) {
            fmt = "0"
            if (sigfigs>1) fmt = fmt + "." + substr(zeros,1,sigfigs-1)
            return(fmt+"E+00")
        }
        pos = strpos(s,".")
        places = (pos>0 ? strlen(s)-pos : 0)
    }
    fmt = "0"
    if (places>0) fmt = fmt + "." + substr(zeros,1,places)
    return(fmt)
}

void _balreport_format(string scalar filename, string scalar sheetname, real scalar digits, real scalar sigfigs)
{
    class xl scalar b
    real scalar n, i, j, k, width
    string matrix cells
    string colvector types
    string rowvector lines
    string scalar numfmt
    real matrix diagnostics

    // Default closed mode releases the workbook even if formatting fails.
    b.load_book(filename)
    b.set_sheet(sheetname)
    n = st_nobs()
    cells = st_sdata(., ("group1", "group2"))
    types = st_sdata(., "type")
    b.set_font((1,n+1), (1,7), "Calibri", 11)
    b.set_font_bold(1, (1,7), "on")
    b.set_text_wrap((1,n+1), (1,5), "on")
    b.set_vertical_align((1,n+1), (1,7), "center")
    b.set_column_width(1,1,40)
    b.set_column_width(2,2,22)
    b.set_column_width(3,3,14)
    b.set_column_width(6,7,12)
    b.set_row_height(1,1,32)
    b.set_row_height(2,n+1,22)
    for (j=1; j<=2; j++) {
        width = 28
        for (i=1; i<=n; i++) {
            lines = tokens(cells[i,j], char(10))
            for (k=1; k<=cols(lines); k++) width = max((width,strlen(lines[k])+2))
        }
        b.set_column_width(j+3,j+3,min((100,width)))
    }
    for (i=1; i<=n; i++) {
        if (types[i]=="continuous") b.set_row_height(i+1,i+1,34)
    }
    if (sigfigs==0) {
        b.set_number_format((2,n+1), (6,7), _balreport_xlfmt(0,digits,0))
    }
    else {
        diagnostics = st_data(., ("smd", "vr"))
        for (j=1; j<=2; j++) {
            width = 12
            for (i=1; i<=n; i++) {
                numfmt = _balreport_xlfmt(diagnostics[i,j],digits,sigfigs)
                b.set_number_format(i+1,j+5,numfmt)
                width = max((width,strlen(_balreport_num(diagnostics[i,j],digits,sigfigs))+2))
            }
            b.set_column_width(j+5,j+5,width)
        }
    }
}
end
