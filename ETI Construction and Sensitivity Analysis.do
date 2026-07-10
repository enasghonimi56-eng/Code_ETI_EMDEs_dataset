*========================================================================
* ETI for Emerging Market and Developing Economies (EMDEs) CONSTRUCTION 
* Dataset: 141 countries, 2000-2023, 32 Variables
*========================================================================
* HOW TO RUN
*   1. Put the raw data file ("Data/Dataset paper.xlsx", 32 indicators),
*          this file is NOT included in this repository. Only the FINAL
*          constructed ETI dataset is published. Every raw indicator's
*          original source is listed in the paper's Table of the ETI
*          framework, so the raw panel can be reassembled by any user
*          from those public databases.     
*   2. Open Stata, then run (edit the path to match your machine):
*         cd "C:/path/to/project_folder"
*         do "ETI_Construction_Sensitivity_Analysis.do"
*   3. All outputs (datasets, tables, figures) are written automatically
*      to a new "Output" subfolder created by this script.
*   Requires Stata 15+ and the community package "estout" (installed
*   automatically below if missing).
*========================================================================

* SETUP
clear all
set more off
version 15

* ---- Project paths (edit only if your folder names differ) ----
global root "."                                  // project folder (must contain /Data)
global raw  "$root/Data/Dataset paper.xlsx"       // raw input file
global out  "$root/Output"                        // all outputs go here
global fig  "$out/figures"
global res  "$out/results"

capture mkdir "$out"
capture mkdir "$fig"
capture mkdir "$res"
cd "$out"

* ---- Required package ----
capture which estout
if _rc {
    display "Installing required package: estout ..."
    ssc install estout, replace
}

*============================
* PART (1): DATA PREPARATION
*============================

* STEP (1): Load raw data
import excel "$raw" , sheet("All sample") firstrow clear

* Fix country name spacing issues
replace Country = trim(Country)

* STEP (2): 80% Data Availability Threshold Following SDI (Sachs et al, 2019, 2025) methodology
local allvars nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coepc coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys leb

egen n_miss = rowmiss(`allvars')
local n_total : word count `allvars'
gen miss_pct = (n_miss / `n_total') * 100
bysort id: egen mean_miss_pct = mean(miss_pct)

*Excluded countries
list id Country mean_miss_pct if mean_miss_pct > 20, sepby(id) noobs

* Drop countries > 20% missing
drop if mean_miss_pct > 20
drop n_miss miss_pct mean_miss_pct

drop id
sort Country year
egen id = group(Country)

* Save cleaned data
save "$out/data_cleaned.dta", replace

* STEP (3): MAR Test
use "$out/data_cleaned.dta", clear

gen miss_nei   = missing(nei)
gen miss_eptdl = missing(eptdl)
gen miss_ict   = missing(ict)
gen miss_gcf   = missing(gcf)
gen miss_ictg = missing(ictg)

logit miss_nei   gdppc urban leb i.year
logit miss_eptdl gdppc urban leb i.year
logit miss_ict   gdppc urban leb i.year
logit miss_gcf   gdppc urban leb i.year
logit miss_ictg gdppc urban leb i.year

drop miss_nei miss_eptdl miss_ict miss_gcf miss_ictg
save "$out/data_cleaned.dta", replace


* STEP (4): Multiple Imputation-Predictive Mean Matching (MICE-PMM)

use "$out/data_cleaned.dta", clear

* Distribution check before imputation
misstable patterns `allvars'

* Re-encode region
replace region = strtrim(region)
capture drop region_num
encode region, gen(region_num)

* Set panel structure
xtset id year

* Declare MI structure
mi set wide

* Register variables 
mi register imputed nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys 
	
mi register regular id year region_num coepc leb oil_price pop urban 

* Check missing before imputation
misstable summarize nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys

* Run MICE-PMM 
* we use coepc leb oil_price pop urban as a predictors 
mi impute chained (pmm, knn(10)) nei (pmm, knn(10)) egpc (pmm, knn(10)) deg (pmm, knn(10)) fes (pmm, knn(10)) eptdl (pmm, knn(10)) accurb (pmm, knn(10)) accrural (pmm, knn(10)) acccook (pmm, knn(10)) ecpc (pmm, knn(10)) eninten (pmm, knn(10)) coper (pmm, knn(10)) chees (pmm, knn(10)) rec (pmm, knn(10)) gdppc (pmm, knn(10)) gcf (pmm, knn(10)) efi (pmm, knn(10)) ps (pmm, knn(10)) mscps (pmm, knn(10)) investre (pmm, knn(10)) rcb (pmm, knn(10)) iui (pmm, knn(10)) mcs (pmm, knn(10)) ti (pmm, knn(10)) ict (pmm, knn(10)) ictg (pmm, knn(10)) stja (pmm, knn(10)) empser (pmm, knn(10)) empin (pmm, knn(10)) mys (pmm, knn(10)) eys = coepc leb oil_price pop urban i.year i.region_num, add(50) burnin(30) rseed(9876) force savetrace("$out/mi_trace", replace)

* Save imputed dataset
save "$out/mi_dataset.dta", replace

* ──────────────────────────────────────────────────────────────────────────────
* STEP (5): MICE-PMM Quality Checks (Descriptive, KDE, Trace, Correlation, RE) 
* ──────────────────────────────────────────────────────────────────────────────
use "$out/mi_dataset.dta", clear

* TEST (1): Descriptive Statistics (before m= 0 vs after m= 25) 
* Orginal Data
use "$out/mi_dataset.dta", clear
mi extract 0, clear

estpost summarize nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys
estimates store obs

* data after MICE-PMM
use "$out/mi_dataset.dta", clear
mi extract 25, clear

estpost summarize nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys
estimates store imp25

* comparative table
esttab obs imp25 using "$out/Test1_DescStats.csv", cells("count(fmt(0) label(N)) mean(fmt(2) label(Mean)) sd(fmt(2) label(SD)) min(fmt(2) label(Min)) max(fmt(2) label(Max))") mtitles("Observed" "Imputed m=25") title("Test 1: Descriptive Statistics Before vs After Imputation") replace

display "✓ Test 1 Done: Test1_DescStats.csv"

* TEST (2): Convergence Check - Trace Plots 
use "$out/mi_trace.dta", clear

local mlist     "1 5 10 15 20 25 30 35 40 50"
local colorlist "red blue green orange purple cranberry teal sienna magenta olive"

* Group 1
local g1vars "nei ict ictg eptdl gcf gdppc"
local g1names ""
foreach var of local g1vars {
    local cmd_mean ""
    local cmd_sd ""
    local i = 1
    foreach m of local mlist {
        local col : word `i' of `colorlist'
        local cmd_mean "`cmd_mean' (line `var'_mean iter if m==`m', lwidth(thin) lcolor(`col'))"
        local cmd_sd "`cmd_sd' (line `var'_sd iter if m==`m', lwidth(thin) lcolor(`col'))"
        local i = `i' + 1
    }
    twoway `cmd_mean', title("Mean of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(tm_`var', replace) nodraw
    twoway `cmd_sd', title("Sd of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(ts_`var', replace) nodraw
    local g1names "`g1names' tm_`var' ts_`var'"
    display "✓ `var'"
}
graph combine `g1names', cols(6) rows(2) title("Trace plots of summaries of imputed values from 50 chains", size(small) color(black)) graphregion(fcolor(ltblue%40) color(white)) imargin(small) xsize(20) ysize(7)
graph export "$fig/trace_group1_nei_gdppc.png", replace width(4000) height(1400)
graph drop `g1names'
display "✓ Group 1 saved"

* Group 2
local g2vars "rec eninten accrural accurb acccook chees"
local g2names ""
foreach var of local g2vars {
    local cmd_mean ""
    local cmd_sd ""
    local i = 1
    foreach m of local mlist {
        local col : word `i' of `colorlist'
        local cmd_mean "`cmd_mean' (line `var'_mean iter if m==`m', lwidth(thin) lcolor(`col'))"
        local cmd_sd "`cmd_sd' (line `var'_sd iter if m==`m', lwidth(thin) lcolor(`col'))"
        local i = `i' + 1
    }
    twoway `cmd_mean', title("Mean of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(tm_`var', replace) nodraw
    twoway `cmd_sd', title("Sd of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(ts_`var', replace) nodraw
    local g2names "`g2names' tm_`var' ts_`var'"
    display "✓ `var'"
}
graph combine `g2names', cols(6) rows(2) title("Trace plots of summaries of imputed values from 50 chains", size(small) color(black)) graphregion(fcolor(ltblue%40) color(white)) imargin(small) xsize(20) ysize(7)
graph export "$fig/trace_group2_rec_chees.png", replace width(4000) height(1400)
graph drop `g2names'
display "✓ Group 2 saved"

* Group 3
local g3vars "efi empser empin mys mcs mscps"
local g3names ""
foreach var of local g3vars {
    local cmd_mean ""
    local cmd_sd ""
    local i = 1
    foreach m of local mlist {
        local col : word `i' of `colorlist'
        local cmd_mean "`cmd_mean' (line `var'_mean iter if m==`m', lwidth(thin) lcolor(`col'))"
        local cmd_sd "`cmd_sd' (line `var'_sd iter if m==`m', lwidth(thin) lcolor(`col'))"
        local i = `i' + 1
    }
    twoway `cmd_mean', title("Mean of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(tm_`var', replace) nodraw
    twoway `cmd_sd', title("Sd of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(ts_`var', replace) nodraw
    local g3names "`g3names' tm_`var' ts_`var'"
    display "✓ `var'"
}
graph combine `g3names', cols(6) rows(2) title("Trace plots of summaries of imputed values from 50 chains", size(small) color(black)) graphregion(fcolor(ltblue%40) color(white)) imargin(small) xsize(20) ysize(7)
graph export "$fig/trace_group3_efi_mscps.png", replace width(4000) height(1400)
graph drop `g3names'
display "✓ Group 3 saved"

* Group 4
local g4vars "ps rcb stja ti iui investre"
local g4names ""
foreach var of local g4vars {
    local cmd_mean ""
    local cmd_sd ""
    local i = 1
    foreach m of local mlist {
        local col : word `i' of `colorlist'
        local cmd_mean "`cmd_mean' (line `var'_mean iter if m==`m', lwidth(thin) lcolor(`col'))"
        local cmd_sd "`cmd_sd' (line `var'_sd iter if m==`m', lwidth(thin) lcolor(`col'))"
        local i = `i' + 1
    }
    twoway `cmd_mean', title("Mean of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(tm_`var', replace) nodraw
    twoway `cmd_sd', title("Sd of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(ts_`var', replace) nodraw
    local g4names "`g4names' tm_`var' ts_`var'"
    display "✓ `var'"
}
graph combine `g4names', cols(6) rows(2) title("Trace plots of summaries of imputed values from 50 chains", size(small) color(black)) graphregion(fcolor(ltblue%40) color(white)) imargin(small) xsize(20) ysize(7)
graph export "$fig/trace_group4_ps_investre.png", replace width(4000) height(1400)
graph drop `g4names'
display "✓ Group 4 saved"

* Group 5
local g5vars "coper deg ecpc egpc fes eys"
local g5names ""
foreach var of local g5vars {
    local cmd_mean ""
    local cmd_sd ""
    local i = 1
    foreach m of local mlist {
        local col : word `i' of `colorlist'
        local cmd_mean "`cmd_mean' (line `var'_mean iter if m==`m', lwidth(thin) lcolor(`col'))"
        local cmd_sd "`cmd_sd' (line `var'_sd iter if m==`m', lwidth(thin) lcolor(`col'))"
        local i = `i' + 1
    }
    twoway `cmd_mean', title("Mean of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(tm_`var', replace) nodraw
    twoway `cmd_sd', title("Sd of `var'", size(vsmall) color(black)) xtitle("Iteration numbers", size(vsmall)) ytitle("", size(vsmall)) xlabel(0(2)30, labsize(vsmall)) ylabel(, labsize(vsmall) angle(0)) legend(off) graphregion(fcolor(ltblue%40) color(white)) scheme(s1color) name(ts_`var', replace) nodraw
    local g5names "`g5names' tm_`var' ts_`var'"
    display "✓ `var'"
}
graph combine `g5names', cols(6) rows(2) title("Trace plots of summaries of imputed values from 50 chains", size(small) color(black)) graphregion(fcolor(ltblue%40) color(white)) imargin(small) xsize(20) ysize(7)
graph export "$fig/trace_group5_coper_eys.png", replace width(4000) height(1400)
graph drop `g5names'
display "✓ Group 5 saved"

* TEST (3): Relative Efficiency 
* Standard: RE > 98% with m=50 → Very high efficiency

use "$out/mi_dataset.dta", clear
mi extract 0, clear
quietly count
local ntot = r(N)

* Keep result in the CSV file
tempname fh
file open `fh' using "$out/Test3_RelativeEfficiency.csv", write replace
file write `fh' "Variable,N_Missing,Missing_pct,RE_pct,Status" _n

foreach var in nei ict ictg eptdl gcf gdppc rec eninten accrural accurb acccook chees efi empser empin eys iui mcs mscps mys ps rcb stja ti coper deg ecpc egpc fes investre {

    quietly count if missing(`var')
    local nmiss   = r(N)
    local misspct = (`nmiss' / `ntot') * 100
    local fmi     = `misspct' / 100
    local RE      = (1 / (1 + `fmi' / 50)) * 100

    if `RE' >= 98 {
        local status "Pass ✓"
        local flag   "✓"
    }
    else {
        local status "Check ⚠"
        local flag   "⚠"
    }

    display "║  " %-10s "`var'" "  │  " %7.0f `nmiss' "    │  " %6.2f `misspct' "%  │  " %7.4f `RE' "%  │  `flag'       ║"
    file write `fh' "`var',`nmiss'," %6.2f (`misspct') "," %7.4f (`RE') ",`status'" _n
}

file close `fh'

display "✓ Results saved: Test3_RelativeEfficiency.csv"

* TEST (4): Correlation Tables m=0 vs m=25 following (khan, 2022)  

use "$out/mi_dataset.dta", clear
mi extract 0, clear
save "$out/temp_m0.dta", replace
use "$out/mi_dataset.dta", clear
mi extract 25, clear
save "$out/temp_m25.dta", replace

* Energy Security
use "$out/temp_m0.dta", clear
pwcorr nei egpc deg fes eptdl, star(0.05)
matrix C0 = r(C)
use "$out/temp_m25.dta", clear
pwcorr nei egpc deg fes eptdl, star(0.05)
matrix C25 = r(C)

putexcel set "$out/Corr_Word_Tables.xlsx", sheet("ESP1_Security") replace
putexcel A1 = "Table: ESP-1 Energy Security — Before Imputation (m=0)"
putexcel A2 = matrix(C0), names
putexcel A9 = "Table: ESP-1 Energy Security — After Imputation (m=25)"
putexcel A10 = matrix(C25), names

* Energy Equity
use "$out/temp_m0.dta", clear
pwcorr accurb accrural acccook ecpc, star(0.05)
matrix C0 = r(C)
use "$out/temp_m25.dta", clear
pwcorr accurb accrural acccook ecpc, star(0.05)
matrix C25 = r(C)

putexcel set "$out/Corr_Word_Tables.xlsx", sheet("ESP2_Equity") modify
putexcel A1 = "Table: ESP-2 Energy Equity — Before Imputation (m=0)"
putexcel A2 = matrix(C0), names
putexcel A8 = "Table: ESP-2 Energy Equity — After Imputation (m=25)"
putexcel A9 = matrix(C25), names

* Energy Sustainability
use "$out/temp_m0.dta", clear
pwcorr eninten coepc coper chees rec, star(0.05)
matrix C0 = r(C)
use "$out/temp_m25.dta", clear
pwcorr eninten coepc coper chees rec, star(0.05)
matrix C25 = r(C)

putexcel set "$out/Corr_Word_Tables.xlsx", sheet("ESP3_Sustainability") modify
putexcel A1 = "Table: ESP-3 Energy Sustainability — Before Imputation (m=0)"
putexcel A2 = matrix(C0), names
putexcel A9 = "Table: ESP-3 Energy Sustainability — After Imputation (m=25)"
putexcel A10 = matrix(C25), names

* Economic & Regulatory
use "$out/temp_m0.dta", clear
pwcorr gdppc gcf efi ps mscps investre, star(0.05)
matrix C0 = r(C)
use "$out/temp_m25.dta", clear
pwcorr gdppc gcf efi ps mscps investre, star(0.05)
matrix C25 = r(C)

putexcel set "$out/Corr_Word_Tables.xlsx", sheet("ETR1_Economic") modify
putexcel A1 = "Table: ETR-1 Economic & Regulatory — Before Imputation (m=0)"
putexcel A2 = matrix(C0), names
putexcel A10 = "Table: ETR-1 Economic & Regulatory — After Imputation (m=25)"
putexcel A11 = matrix(C25), names

* Infrastructure 
use "$out/temp_m0.dta", clear
pwcorr rcb iui mcs ti, star(0.05)
matrix C0 = r(C)
use "$out/temp_m25.dta", clear
pwcorr rcb iui mcs ti, star(0.05)
matrix C25 = r(C)
putexcel set "$out/Corr_Word_Tables.xlsx", sheet("ETR2_Infrastructure") modify
putexcel A1 = "Table: ETR-2 Infrastructure — Before Imputation (m=0)"
putexcel A2 = matrix(C0), names
putexcel A8 = "Table: ETR-2 Infrastructure — After Imputation (m=25)"
putexcel A9 = matrix(C25), names

* Technological Innovation 
use "$out/temp_m0.dta", clear
pwcorr ict ictg stja, star(0.05)
matrix C0 = r(C)
use "$out/temp_m25.dta", clear
pwcorr ict ictg stja, star(0.05)
matrix C25 = r(C)
putexcel set "$out/Corr_Word_Tables.xlsx", sheet("ETR3_TechInnovation") modify
putexcel A1 = "Table: ETR-3 Technological Innovation — Before Imputation (m=0)"
putexcel A2 = matrix(C0), names
putexcel A7 = "Table: ETR-3 Technological Innovation — After Imputation (m=25)"
putexcel A8 = matrix(C25), names

* Human Capital 
use "$out/temp_m0.dta", clear
pwcorr empser empin mys eys leb, star(0.05)
matrix C0 = r(C)
use "$out/temp_m25.dta", clear
pwcorr empser empin mys eys leb, star(0.05)
matrix C25 = r(C)
putexcel set "$out/Corr_Word_Tables.xlsx", sheet("ETR4_HumanCapital") modify
putexcel A1 = "Table: ETR-4 Human Capital — Before Imputation (m=0)"
putexcel A2 = matrix(C0), names
putexcel A9 = "Table: ETR-4 Human Capital — After Imputation (m=25)"
putexcel A10 = matrix(C25), names

erase "$out/temp_m0.dta"
erase "$out/temp_m25.dta"
di "✓ Done — Corr_Word_Tables.xlsx"

* TEST (5.1): Kernel Density  of the Observed Vs Complete Dataset
foreach var in nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys {
    use "$out/mi_dataset.dta", clear
    mi extract 0, clear
    kdensity `var', gen(x0 d0) nograph
    keep x0 d0
    save "$out/temp0.dta", replace
    use "$out/mi_dataset.dta", clear
    mi extract 25, clear
    kdensity `var', gen(x25 d25) nograph
    keep x25 d25
    save "$out/temp25.dta", replace
    use "$out/temp0.dta", clear
    merge 1:1 _n using "$out/temp25.dta", nogenerate
    twoway (line d0  x0,  lcolor(navy) lwidth(medthick)) (line d25 x25, lcolor(maroon) lwidth(medthick)), legend(order(1 "Observed" 2 "Completed") position(6) rows(1) size(medsmall)) title("Imputation 25", size(large) color(black)) subtitle("`var'", size(medsmall) color(black)) xtitle("") ytitle("Density", size(medsmall)) graphregion(color(white)) scheme(s1mono) name(kd_`var', replace)
    graph export "$fig/kd_`var'.png", replace width(1400) height(1000)
    drop x0 d0 x25 d25
    display "✓ KDE: `var'"
}
erase "$out/temp0.dta"
erase "$out/temp25.dta"
display "✓ Done: 30 KDE plots saved"


* TEST (5.2): Kernel Density for variables at Different Points (2000-2012-2023)
use "$out/mi_dataset.dta", clear
mi extract 25, clear
save "$out/mi_dataset_m25.dta", replace

use "$out/mi_dataset_m25.dta", clear

local allvars "nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys"

foreach var of local allvars {

* 2000
    use "$out/mi_dataset_m25.dta", clear
    keep if year == 2000
    kdensity `var', gen(x00 d00) nograph
    keep x00 d00
    save "$out/figures/temp00.dta", replace

* 2012
    use "$out/mi_dataset_m25.dta", clear
    keep if year == 2012
    kdensity `var', gen(x12 d12) nograph
    keep x12 d12
    save "$out/figures/temp12.dta", replace

* 2023
    use "$out/mi_dataset_m25.dta", clear
    keep if year == 2023
    kdensity `var', gen(x23 d23) nograph
    keep x23 d23
    save "$out/figures/temp23.dta", replace

* Merg and drow
    use "$out/figures/temp00.dta", clear
    merge 1:1 _n using "$out/figures/temp12.dta", nogenerate
    merge 1:1 _n using "$out/figures/temp23.dta", nogenerate

    twoway (line d00 x00, lcolor(navy) lwidth(medthick)) (line d12 x12, lcolor(maroon) lwidth(medthick)) (line d23 x23, lcolor(dkgreen) lwidth(medthick)), legend(order(1 "2000" 2 "2012" 3 "2023") position(1) ring(0) cols(1) size(medsmall) region(lcolor(none))) title("Kernel density estimate", size(medsmall) color(black)) xtitle("`var'", size(small)) ytitle("Density", size(small)) xlabel(, labsize(small)) ylabel(, labsize(small) angle(0)) graphregion(fcolor(ltblue%20) color(white)) plotregion(fcolor(ltblue%20)) scheme(s1color) xsize(8) ysize(6)

    graph export "$out/figures/kd3yr_`var'.png", replace width(1600) height(1200)
    display "✓ `var' saved"

    erase "$out/figures/temp00.dta"
    erase "$out/figures/temp12.dta"
    erase "$out/figures/temp23.dta"
}

*=======================================================================
* PART (2): ETI INDEX Construction - Based on m=25 according (Khan, 2022)
* Steps: Extract → Winsorize → Normalize → Build Index
*=======================================================================
clear all
set more off

* STEP (1): m=25 DATASET
use "$out/mi_dataset.dta", clear
mi extract 25, clear
xtset id year
save "$out/data_m25_raw.dta", replace
display "✓ m=25 dataset extracted"

* STEP (2): Winsorization at 2.5% (Baseline) 
* Following: Shen et al. (2023), Xu et al. (2020)

use "$out/data_m25_raw.dta", clear

local allvars "nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coepc coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys leb"

* Save pre-winsorization copy for comparison
save "$out/data_m25_prewin.dta", replace

* Apply Winsorization at 2.5th and 97.5th percentile across full panel
foreach var of local allvars {
    quietly summarize `var', detail
    local p2  = r(p1)   
    local p98 = r(p99)  
    
    * Use exact 2.5th and 97.5th
    quietly _pctile `var', percentiles(2.5 97.5)
    local p_low  = r(r1)
    local p_high = r(r2)
    
    * Winsorize: cap at lower and upper bounds
    quietly replace `var' = `p_low'  if `var' < `p_low'  & !missing(`var')
    quietly replace `var' = `p_high' if `var' > `p_high' & !missing(`var')
    
    display "✓ Winsorized: `var'  [lower=`p_low', upper=`p_high']"
}

save "$out/data_m25_winsorized.dta", replace
display "✓ PART 2 DONE: Winsorization complete — data_m25_winsorized.dta"

* STEP (3): NORMALIZATION (0–100 Min-Max)

use "$out/data_m25_winsorized.dta", clear

* Positive variables (+): higher = better 
* Equation 1: x' = (x - min) / (max - min) × 100
local pos_vars "egpc deg fes accurb accrural acccook ecpc rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser mys eys leb"

foreach var of local pos_vars {
    quietly _pctile `var', percentiles(2.5 97.5)
    local lb = r(r1)
    local ub = r(r2)
    
    generate `var'_n = (`var' - `lb') / (`ub' - `lb') * 100
    
* Cap: values below lower bound = 0, above upper bound = 100
    quietly replace `var'_n = 0   if `var'_n < 0   & !missing(`var'_n)
    quietly replace `var'_n = 100 if `var'_n > 100  & !missing(`var'_n)
    
    display "✓ Normalized (+): `var'"
}

* Negative variables (-): higher = worse 
* Equation 2: x' = (max - x) / (max - min) × 100
local neg_vars "nei eptdl eninten coper chees empin coepc"

foreach var of local neg_vars {
    quietly _pctile `var', percentiles(2.5 97.5)
    local lb = r(r1)
    local ub = r(r2)
    
    generate `var'_n = (`ub' - `var') / (`ub' - `lb') * 100
    
* Cap
    quietly replace `var'_n = 0   if `var'_n < 0   & !missing(`var'_n)
    quietly replace `var'_n = 100 if `var'_n > 100  & !missing(`var'_n)
    
    display "✓ Normalized (-): `var'"
}

save "$out/data_m25_normalized.dta", replace
* ──────────────────────────────────────────────────────────────────────────────
* STEP (3): PRE-INDEX VALIDATION
* Tests:
*   (1) Correlation Matrex 
*   (2) VIF — Variance Inflation Factor
*   (3) Internal Consistency (Cronbach's Alpha per Dimension)
*   (4) PCA — Dimensionality Validation
* ──────────────────────────────────────────────────────────────────────────────
capture mkdir "$out/results"
capture mkdir "$out/results/preindex"

cd "$out/results/preindex"
pwd

global res "$out/results/preindex"

use "$out/data_m25_normalized.dta", clear

putexcel set "$res/T1_Correlation_Matrices.xlsx", replace
putexcel A1 = "ETI Pre-Index Validation — Pearson Correlation Matrices"

* TEST (1) CORRELATION MATRIX - Pearson |r| > 0.90 between any two vars 
local esp_sec  "nei_n egpc_n deg_n fes_n eptdl_n"
local esp_eq   "accurb_n accrural_n acccook_n ecpc_n"
local esp_sust "eninten_n coepc_n coper_n chees_n rec_n"
local tr_eri   "gdppc_n gcf_n efi_n ps_n mscps_n investre_n"
local tr_inf   "rcb_n iui_n mcs_n ti_n"
local tr_tech  "ict_n ictg_n stja_n"
local tr_hc    "empser_n empin_n mys_n eys_n leb_n"

foreach grp in esp_sec esp_eq esp_sust tr_eri tr_inf tr_tech tr_hc {

    local vars "``grp''"
    quietly correlate `vars'
    matrix C = r(C)

    local sname = subinstr("`grp'", "_", "", .)
    putexcel set "$res/T1_Correlation_Matrices.xlsx", sheet("`sname'") modify
    putexcel A1 = "Pearson Correlation — `grp'"
    putexcel A2 = matrix(C), names

    local nvars : word count `vars'

    forvalues i = 1/`nvars' {
        forvalues j = 1/`nvars' {
            if `j' > `i' {
                local vi : word `i' of `vars'
                local vj : word `j' of `vars'
                local r_ij = C[`i',`j']
                local r_abs = abs(`r_ij')
                if `r_abs' > 0.90 {
                    display "  ⚠ HIGH: `vi' & `vj' r = " %6.3f `r_ij'
                }
                else if `r_abs' > 0.70 {
                    display "  ~ Mod:  `vi' & `vj' r = " %6.3f `r_ij'
                }
                else {
                    display "    OK:   `vi' & `vj' r = " %6.3f `r_ij'
                }
            }
        }
    }
}

* TEST (2): Variance Inflation Factor VIF> 10 = serious, VIF > 5 = moderate
tempname fhv
file open `fhv' using "$res/T2_VIF_Results.csv", write replace
file write `fhv' "Dimension,Variable,VIF,Tolerance,Status" _n

foreach grp in esp_sec esp_eq esp_sust tr_eri tr_inf tr_tech tr_hc {
    
    local vars "``grp''"
    local nvars : word count `vars'
    
* VIF only meaningful with 3+ variables
    if `nvars' < 3 {
        display "  `grp': only `nvars' variables — VIF skipped"
        continue
    }
    
    display "  Dimension: `grp'"
    
    foreach v of local vars {
* Build list of others
        local others ""
        foreach v2 of local vars {
            if "`v2'" != "`v'" {
                local others "`others' `v2'"
            }
        }
        
        quietly regress `v' `others'
        local r2  = e(r2)
        
        if `r2' >= 0.9999 {
            local vif = 9999
        }
        else {
            local vif = 1 / (1 - `r2')
        }
        local tol = 1 / `vif'
        
        if `vif' > 10 {
            local status "SERIOUS ⚠⚠"
        }
        else if `vif' > 5 {
            local status "Moderate ⚠"
        }
        else {
            local status "OK ✓"
        }
        
        display "    `v': VIF = " %7.3f `vif' "  Tol = " %6.4f `tol' "  → `status'"
        file write `fhv' "`grp',`v'," %7.3f (`vif') "," %6.4f (`tol') ",`status'" _n
    }
}

file close `fhv'

* TEST (3): CRONBACH'S ALPHA: Internal Consistency α ≥ 0.70 Acceptable & ≥ 0.80 Good       
tempname fha
file open `fha' using "$res/T3_Cronbach_Alpha.csv", write replace
file write `fha' "Dimension,N_indicators,Cronbach_Alpha,Interpretation" _n

foreach grp in esp_sec esp_eq esp_sust tr_eri tr_inf tr_tech tr_hc {
    
    local vars "``grp''"
    local nvars : word count `vars'
    
* Alpha requires 2+ variables
    if `nvars' < 2 {
        display "  `grp': only 1 variable — Alpha not applicable"
        file write `fha' "`grp',1,N/A,Single indicator" _n
        continue
    }
    
    quietly alpha `vars', item
    local alpha = r(alpha)
    
    if `alpha' >= 0.90 {
        local interp "Excellent"
    }
    else if `alpha' >= 0.80 {
        local interp "Good"
    }
    else if `alpha' >= 0.70 {
        local interp "Acceptable"
    }
    else if `alpha' >= 0.60 {
        local interp "Questionable"
    }
    else {
        local interp "Poor — review"
    }
    
    display "  `grp'  (n=`nvars'): α = " %6.4f `alpha' "  → `interp'"
    file write `fha' "`grp',`nvars'," %6.4f (`alpha') ",`interp'" _n
}

* Also compute for each full Sub-Index
display ""
display "  ── Full Sub-Indexes ──"

local all_esp "nei_n egpc_n deg_n fes_n eptdl_n accurb_n accrural_n acccook_n ecpc_n eninten_n coepc_n coper_n chees_n rec_n"
local all_tr  "gdppc_n gcf_n efi_n ps_n mscps_n investre_n rcb_n iui_n mcs_n ti_n ict_n ictg_n stja_n empser_n empin_n mys_n eys_n leb_n"

quietly alpha `all_esp', item
local alpha_esp = r(alpha)
display "  ESP Sub-Index (n=14): α = " %6.4f `alpha_esp'
file write `fha' "ESP_full,14," %6.4f (`alpha_esp') ",Sub-index level" _n

quietly alpha `all_tr', item
local alpha_tr = r(alpha)
display "  TR Sub-Index  (n=18): α = " %6.4f `alpha_tr'
file write `fha' "TR_full,18," %6.4f (`alpha_tr') ",Sub-index level" _n

local all_vars "nei_n egpc_n deg_n fes_n eptdl_n accurb_n accrural_n acccook_n ecpc_n eninten_n coepc_n coper_n chees_n rec_n gdppc_n gcf_n efi_n ps_n mscps_n investre_n rcb_n iui_n mcs_n ti_n ict_n ictg_n stja_n empser_n empin_n mys_n eys_n leb_n"
quietly alpha `all_vars', item
local alpha_all = r(alpha)
display "  Full ETI      (n=32): α = " %6.4f `alpha_all'
file write `fha' "ETI_full,32," %6.4f (`alpha_all') ",Full index level" _n

file close `fha'

* TEST (4) PCA — Dimensionality Validation

* 4.A: PCA within ESP Sub-Index
local esp_all "nei_n egpc_n deg_n fes_n eptdl_n accurb_n accrural_n acccook_n ecpc_n eninten_n coepc_n coper_n chees_n rec_n"

pca `esp_all', components(5)
matrix ESP_eigen   = e(Ev)
matrix ESP_loadings = e(L)

display ""
display "  ESP Sub-Index PCA — Eigenvalues (first 5 components):"
matrix list ESP_eigen

* Scree plot
screeplot, title("PCA Screeplot — Energy System Performance") graphregion(color(white)) scheme(s1color) name(pca_esp, replace)
graph export "$res/PCA_ESP_Screeplot.png", replace width(1400) height(1000)

* Export loadings
putexcel set "$res/T4_PCA_Results.xlsx", sheet("ESP_loadings") replace
putexcel A1 = "PCA Factor Loadings — ESP Sub-Index"
putexcel A2 = matrix(ESP_loadings), names


* 4.B: PCA within TR Sub-Index
local tr_all "gdppc_n gcf_n efi_n ps_n mscps_n investre_n rcb_n iui_n mcs_n ti_n ict_n ictg_n stja_n empser_n empin_n mys_n eys_n leb_n"

pca `tr_all', components(5)
matrix TR_eigen    = e(Ev)
matrix TR_loadings = e(L)

display ""
display "  TR Sub-Index PCA — Eigenvalues (first 5 components):"
matrix list TR_eigen

screeplot, title("PCA Screeplot — Transition Readiness") graphregion(color(white)) scheme(s1color) name(pca_tr, replace)
graph export "$res/PCA_TR_Screeplot.png", replace width(1400) height(1000)

putexcel set "$res/T4_PCA_Results.xlsx", sheet("TR_loadings") modify
putexcel A1 = "PCA Factor Loadings — TR Sub-Index"
putexcel A2 = matrix(TR_loadings), names

* 4.C: PCA on Full ETI — verify ESP vs TR separation

local all_norm "nei_n egpc_n deg_n fes_n eptdl_n accurb_n accrural_n acccook_n ecpc_n eninten_n coepc_n coper_n chees_n rec_n gdppc_n gcf_n efi_n ps_n mscps_n investre_n rcb_n iui_n mcs_n ti_n ict_n ictg_n stja_n empser_n empin_n mys_n eys_n leb_n"

pca `all_norm', components(7)
matrix ALL_eigen    = e(Ev)
matrix ALL_loadings = e(L)

display ""
display "  Full ETI PCA — Eigenvalues (first 7 components):"
matrix list ALL_eigen

* Explained variance table
display ""
display "  Component   Eigenvalue   Prop.Variance   Cumulative"
local cumvar = 0
forvalues k = 1/7 {
    local eig_k = ALL_eigen[1,`k']
    local propvar = `eig_k' / 32 * 100
    local cumvar = `cumvar' + `propvar'
    display "  PC`k'        " %8.3f `eig_k' "       " %6.2f `propvar' "%       " %6.2f `cumvar' "%"
}

screeplot, title("PCA Screeplot — Full ETI (32 indicators)") graphregion(color(white)) scheme(s1color) name(pca_full, replace)
graph export "$res/PCA_Full_Screeplot.png", replace width(1400) height(1000)

putexcel set "$res/T4_PCA_Results.xlsx", sheet("Full_ETI_loadings") modify
putexcel A1 = "PCA Factor Loadings — Full ETI (32 indicators)"
putexcel A2 = matrix(ALL_loadings), names
 
* Export eigenvalues and variance explained to Excel
putexcel set "$res/T4_PCA_Results.xlsx", sheet("Eigenvalues") modify
putexcel A1 = "Level"
putexcel B1 = "Component"
putexcel C1 = "Eigenvalue"
putexcel D1 = "Proportion %"
putexcel E1 = "Cumulative %"

* ESP
local row = 2
local cumvar = 0
forvalues k = 1/5 {
    local eig_k = ESP_eigen[1,`k']
    local prop  = `eig_k' / 14 * 100
    local cumvar = `cumvar' + `prop'
    putexcel A`row' = "ESP"
    putexcel B`row' = "PC`k'"
    putexcel C`row' = `eig_k'
    putexcel D`row' = `prop'
    putexcel E`row' = `cumvar'
    local row = `row' + 1
}

* TR
local cumvar = 0
forvalues k = 1/5 {
    local eig_k = TR_eigen[1,`k']
    local prop  = `eig_k' / 18 * 100
    local cumvar = `cumvar' + `prop'
    putexcel A`row' = "TR"
    putexcel B`row' = "PC`k'"
    putexcel C`row' = `eig_k'
    putexcel D`row' = `prop'
    putexcel E`row' = `cumvar'
    local row = `row' + 1
}

* Full ETI
local cumvar = 0
forvalues k = 1/7 {
    local eig_k = ALL_eigen[1,`k']
    local prop  = `eig_k' / 32 * 100
    local cumvar = `cumvar' + `prop'
    putexcel A`row' = "Full ETI"
    putexcel B`row' = "PC`k'"
    putexcel C`row' = `eig_k'
    putexcel D`row' = `prop'
    putexcel E`row' = `cumvar'
    local row = `row' + 1
}

display "✓ Eigenvalues exported to T4_PCA_Results.xlsx — sheet: Eigenvalues" 
 
* STEP (4): AGGREGATION — Equal Weights at All Levels (Arithmetic Mean)
* Structure: Indicator → Component → Dimension → Sub-Index → Index
* Following: Shen et al. (2023), 

use "$out/data_m25_normalized.dta", clear

* SUB-INDEX 1: ENERGY SYSTEM PERFORMANCE (ESP)
*  ── DIMENSION 1: Security ─────
gen comp_supply     = (nei_n + egpc_n) / 2
gen comp_resilience = (deg_n + fes_n) / 2
gen comp_reliability = eptdl_n
gen dim_security    = (comp_supply + comp_resilience + comp_reliability) / 3

* ── DIMENSION 2: Equity ──────
gen dim_equity = (accurb_n + accrural_n + acccook_n + ecpc_n) / 4

* ── DIMENSION 3: Sustainability ────
gen comp_efficiency = eninten_n
gen comp_decarb     = (coepc_n + coper_n + chees_n) / 3
gen comp_clean      = rec_n
gen dim_sustainability = (comp_efficiency + comp_decarb + comp_clean) / 3

* ── Sub-Index 1: ESP ────
gen subindex_esp = (dim_security + dim_equity + dim_sustainability) / 3

* SUB-INDEX 2: TRANSITION READINESS (TR)
* ── DIMENSION 1: Economic, Regulatory & Investment ───────
gen comp_econ_dev  = (gdppc_n + gcf_n) / 2
gen comp_regulation = (efi_n + ps_n) / 2
gen comp_finance   = (mscps_n + investre_n) / 2
gen dim_economic   = (comp_econ_dev + comp_regulation + comp_finance) / 3

* ── DIMENSION 2: Infrastructure ───────
gen comp_ren_cap   = rcb_n
gen comp_digital   = (iui_n + mcs_n) / 2
gen comp_transport = ti_n
gen dim_infrastructure = (comp_ren_cap + comp_digital + comp_transport) / 3

* ── DIMENSION 3: Technological Innovation ─────
gen comp_lct           = ict_n
gen comp_digital_ready = ictg_n
gen comp_innovation    = stja_n
gen dim_tech = (comp_lct + comp_digital_ready + comp_innovation) / 3

* ── DIMENSION 4: Human Capital ─────
gen comp_labor     = (empser_n + empin_n) / 2
gen comp_education = (mys_n + eys_n) / 2
gen comp_health    = leb_n
gen dim_humancap   = (comp_labor + comp_education + comp_health) / 3

* ── Sub-Index 2: TR ────
gen subindex_tr = (dim_economic + dim_infrastructure + dim_tech + dim_humancap) / 4

* FINAL ETI
gen eti = (subindex_esp + subindex_tr) / 2

*─────────
* LABELS
*─────────

label variable eti               "Energy Transition Index (0-100)"
label variable subindex_esp      "Energy System Performance Sub-Index"
label variable subindex_tr       "Transition Readiness Sub-Index"
label variable dim_security      "Security Dimension"
label variable dim_equity        "Equity Dimension"
label variable dim_sustainability "Sustainability Dimension"
label variable dim_economic      "Economic, Regulatory & Investment Dimension"
label variable dim_infrastructure "Infrastructure Dimension"
label variable dim_tech          "Technological Innovation Dimension"
label variable dim_humancap      "Human Capital Dimension"

*───────────────────────
* SAVE & QUICK CHECK
*───────────────────────
save "$out/data_m25_index.dta", replace

summarize eti subindex_esp subindex_tr, format

tabstat eti subindex_esp subindex_tr, by(year) stat(mean) format(%6.2f)

*══════════════════════════════════════════════════════════════════
* PART (3): ETI Sensitivity Analysis
* PART A — Sensitivity Analysis (5 tests)
*     SA-1: Alternative Normalization Bounds (1%, 99% and 5%, 95%)
*     SA-2: Leave-One-Out Dimension
*     SA-3: Alternative Aggregation (Geometric Mean)
*     SA-4: Alternative Imputed (m=20), Imputed (m=50), and Imputed Pooled
*     SA-5: Alternative weights (60% ESP + 40% TR)
*══════════════════════════════════════════════════════════════════
global res "$out/results/sensitivity"

capture mkdir "$out/results"
capture mkdir "$res"
capture mkdir "$fig"

use "$out/data_m25_winsorized.dta", clear

*─────────────────────────────────────────────────────────────
* SA-1: Alternative Bounds
* Baseline: 2.5/97.5 | Alt1: 1/99 | Alt2: 5/95
*─────────────────────────────────────────────────────────────
capture program drop norm_alt
program define norm_alt
    args var direction lb_pct ub_pct suffix
    quietly _pctile `var', percentiles(`lb_pct' `ub_pct')
    local lb = r(r1)
    local ub = r(r2)
    if "`direction'" == "pos" {
        quietly generate `var'_`suffix' = (`var' - `lb') / (`ub' - `lb') * 100
    }
    else {
        quietly generate `var'_`suffix' = (`ub' - `var') / (`ub' - `lb') * 100
    }
    quietly replace `var'_`suffix' = 0   if `var'_`suffix' < 0   & !missing(`var'_`suffix')
    quietly replace `var'_`suffix' = 100 if `var'_`suffix' > 100  & !missing(`var'_`suffix')
end

* Re-load winsorized data to apply alternative bounds
use "$out/data_m25_winsorized.dta", clear

* Alt 1: 1/99 percentile
foreach var in egpc deg fes accurb accrural acccook ecpc rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser mys eys leb {
    norm_alt `var' pos 1 99 alt1
}
foreach var in nei eptdl eninten coper chees empin coepc {
    norm_alt `var' neg 1 99 alt1
}

* Alt 2: 5/95 percentile
foreach var in egpc deg fes accurb accrural acccook ecpc rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser mys eys leb {
    norm_alt `var' pos 5 95 alt2
}
foreach var in nei eptdl eninten coper chees empin coepc {
    norm_alt `var' neg 5 95 alt2
}

* Build ETI for alt1 and alt2 (same aggregation structure)
foreach s in alt1 alt2 {
    generate comp_supply_`s'    = (nei_`s' + egpc_`s') / 2
    generate comp_resilience_`s'= (deg_`s' + fes_`s') / 2
    generate comp_reliability_`s'= eptdl_`s'
    generate dim_security_`s'   = (comp_supply_`s' + comp_resilience_`s' + comp_reliability_`s') / 3
    generate dim_equity_`s'     = (accurb_`s' + accrural_`s' + acccook_`s' + ecpc_`s') / 4
    generate comp_efficiency_`s'= eninten_`s'
    generate comp_decarb_`s'    = (coepc_`s' + coper_`s' + chees_`s') / 3
    generate comp_clean_`s'     = rec_`s'
    generate dim_sust_`s'       = (comp_efficiency_`s' + comp_decarb_`s' + comp_clean_`s') / 3
    generate esp_`s'            = (dim_security_`s' + dim_equity_`s' + dim_sust_`s') / 3
    
    generate comp_econ_`s'      = (gdppc_`s' + gcf_`s') / 2
    generate comp_reg_`s'       = (efi_`s' + ps_`s') / 2
    generate comp_fin_`s'       = (mscps_`s' + investre_`s') / 2
    generate dim_econ_`s'       = (comp_econ_`s' + comp_reg_`s' + comp_fin_`s') / 3
    generate dim_infra_`s'      = (rcb_`s' + ((iui_`s' + mcs_`s')/2) + ti_`s') / 3
    generate dim_tech_`s'       = (ict_`s' + ictg_`s' + stja_`s') / 3
    generate comp_labor_`s'     = (empser_`s' + empin_`s') / 2
    generate comp_edu_`s'       = (mys_`s' + eys_`s') / 2
    generate dim_hc_`s'         = (comp_labor_`s' + comp_edu_`s' + leb_`s') / 3
    generate tr_`s'             = (dim_econ_`s' + dim_infra_`s' + dim_tech_`s' + dim_hc_`s') / 4
    generate eti_`s'            = (esp_`s' + tr_`s') / 2
}

* Merge with baseline ETI
merge 1:1 id year using "$out/data_m25_index.dta", keepusing(eti) nogenerate

* Spearman rank correlations — per year
spearman eti eti_alt1
display "  Baseline vs Alt1 (1/99): rho = " r(rho)
spearman eti eti_alt2
display "  Baseline vs Alt2 (5/95): rho = " r(rho)

* Export comparison table
keep id year eti eti_alt1 eti_alt2
save "$out/sensitivity_bounds.dta", replace

* Export Results
spearman eti eti_alt1
local rho_alt1 = r(rho)
spearman eti eti_alt2
local rho_alt2 = r(rho)

use "$out/sensitivity_bounds.dta", clear

putexcel set "$res/SA1_AltBounds.xlsx", replace
putexcel A1 = "Comparison"
putexcel B1 = "Spearman rho"
putexcel C1 = "Target"
putexcel A2 = "Baseline (2.5/97.5) vs Alt-1 (1/99)"
putexcel B2 = `rho_alt1'
putexcel C2 = "> 0.95"
putexcel A3 = "Baseline (2.5/97.5) vs Alt-2 (5/95)"
putexcel B3 = `rho_alt2'
putexcel C3 = "> 0.95"

display "✓ SA1_AltBounds.xlsx saved"
*─────────────────────────────────────────────────────────────
* PART A — Sensitivity Analysis
* SA-2: Leave-One-Out Dimension Exclusion
* Exclude each dimension in turn → recompute ETI → Spearman
* Following: Shen et al. (2023)
*─────────────────────────────────────────────────────────────
use "$out/data_m25_index.dta", clear

local dims "dim_security dim_equity dim_sustainability dim_economic dim_infrastructure dim_tech dim_humancap"
local n_dims = 7

tempname fh
file open `fh' using "$res/sensitivity_leave_one_out.csv", write replace
file write `fh' "Excluded_Dimension,ETI_without_dim_mean,Spearman_rho_with_baseline" _n

foreach d of local dims {
* Build ETI from remaining 6 dimensions
    local remaining ""
    foreach d2 of local dims {
        if "`d2'" != "`d'" {
            local remaining "`remaining' `d2'"
        }
    }
    
    local k : word count `remaining'
    
    generate eti_excl_`d' = 0
    foreach d2 of local remaining {
        quietly replace eti_excl_`d' = eti_excl_`d' + `d2'
    }
    quietly replace eti_excl_`d' = eti_excl_`d' / `k'
    
    quietly summarize eti_excl_`d'
    local mean_excl = r(mean)
    
    spearman eti eti_excl_`d'
    local rho = r(rho)
    
    display "  Excl. `d': mean ETI = " %5.2f `mean_excl' "  |  Spearman rho = " %6.4f `rho'
    file write `fh' "`d'," %5.2f (`mean_excl') "," %6.4f (`rho') _n
    
    drop eti_excl_`d'
}

file close `fh'
display "══════════════════════════════════════════════════════"
display "✓ V-TEST 3 DONE: sensitivity_leave_one_out.csv saved"

*─────────────────────────────────────────────────────────────
* PART (A): Sensitivity Analysis
* SA-3: Alternative Aggregation (Geometric Mean)
* Following: Shen et al. (2023)
*─────────────────────────────────────────────────────────────
use "$out/data_m25_normalized.dta", clear
merge 1:1 id year using "$out/data_m25_index.dta", keepusing(eti subindex_esp subindex_tr dim_security dim_equity dim_sustainability dim_economic dim_infrastructure dim_tech dim_humancap) nogenerate

* Geometric mean of the 7 dimensions
* Note: replace 0 with 0.01 to avoid log(0)
foreach d in dim_security dim_equity dim_sustainability dim_economic dim_infrastructure dim_tech dim_humancap {
    quietly replace `d' = 0.01 if `d' == 0
}

generate eti_geo = (dim_security * dim_equity * dim_sustainability * dim_economic * dim_infrastructure * dim_tech * dim_humancap) ^ (1/7)

spearman eti eti_geo

local rho_geo = r(rho)

putexcel set "$res/SA3_GeoMean.xlsx", replace
putexcel A1 = "Comparison"
putexcel B1 = "Spearman rho"
putexcel C1 = "Target"
putexcel A2 = "Arithmetic Mean (baseline) vs Geometric Mean"
putexcel B2 = `rho_geo'
putexcel C2 = "> 0.95"

display "✓ SA3_GeoMean.xlsx saved"
*─────────────────────────────────────────────────────────────────────
* PART A — Sensitivity Analysis
* SA-4: Alternative Imputed 
* Compare ETI rankings across m=1, m=10, m=40, m=50, Pooled (m=1→50) 
* + pooled mean of all 50 imputations
* Standard: Spearman rho > 0.95 → insensitive to imputation choice
*─────────────────────────────────────────────────────────────────────
* Load baseline ETI (m=25) for merging
use "$out/data_m25_index.dta", clear
keep id year eti
rename eti eti_m25
save "$out/temp_eti_m25.dta", replace

tempname fh2
file open `fh2' using "$res/robustness_imputation.csv", write replace
file write `fh2' "Imputation,Spearman_rho_vs_m25,Mean_ETI,SD_ETI" _n

foreach m in 1 10 40 50 {
    
* Extract imputation m
    use "$out/mi_dataset.dta", clear
    mi extract `m', clear
    
* Winsorize
    local allvars2 "nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys coepc leb"
    foreach var of local allvars2 {
        quietly _pctile `var', percentiles(2.5 97.5)
        local p_low  = r(r1)
        local p_high = r(r2)
        quietly replace `var' = `p_low'  if `var' < `p_low'  & !missing(`var')
        quietly replace `var' = `p_high' if `var' > `p_high' & !missing(`var')
    }
    
* Normalize
    foreach var in egpc deg fes accurb accrural acccook ecpc rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser mys eys leb {
        quietly _pctile `var', percentiles(2.5 97.5)
        local lb = r(r1)
        local ub = r(r2)
        quietly generate `var'_n = (`var' - `lb') / (`ub' - `lb') * 100
        quietly replace `var'_n = 0   if `var'_n < 0   & !missing(`var'_n)
        quietly replace `var'_n = 100 if `var'_n > 100  & !missing(`var'_n)
    }
    foreach var in nei eptdl eninten coper chees empin coepc {
        quietly _pctile `var', percentiles(2.5 97.5)
        local lb = r(r1)
        local ub = r(r2)
        quietly generate `var'_n = (`ub' - `var') / (`ub' - `lb') * 100
        quietly replace `var'_n = 0   if `var'_n < 0   & !missing(`var'_n)
        quietly replace `var'_n = 100 if `var'_n > 100  & !missing(`var'_n)
    }
    
* Aggregate
    generate comp_supply_r    = (nei_n + egpc_n) / 2
    generate comp_resil_r     = (deg_n + fes_n) / 2
    generate dim_sec_r        = (comp_supply_r + comp_resil_r + eptdl_n) / 3
    generate dim_eq_r         = (accurb_n + accrural_n + acccook_n + ecpc_n) / 4
    generate dim_sus_r        = (eninten_n + ((coepc_n + coper_n + chees_n)/3) + rec_n) / 3
    generate esp_r            = (dim_sec_r + dim_eq_r + dim_sus_r) / 3
    generate dim_eco_r        = (((gdppc_n + gcf_n)/2) + ((efi_n + ps_n)/2) + ((mscps_n + investre_n)/2)) / 3
    generate dim_inf_r        = (rcb_n + ((iui_n + mcs_n)/2) + ti_n) / 3
    generate dim_tec_r        = (ict_n + ictg_n + stja_n) / 3
    generate dim_hc_r         = (((empser_n + empin_n)/2) + ((mys_n + eys_n)/2) + leb_n) / 3
    generate tr_r             = (dim_eco_r + dim_inf_r + dim_tec_r + dim_hc_r) / 4
    generate eti_m`m'         = (esp_r + tr_r) / 2
    
* Merge with baseline and compute Spearman
    keep id year eti_m`m'
    merge 1:1 id year using "$out/temp_eti_m25.dta", nogenerate
    
    spearman eti_m25 eti_m`m'
    local rho = r(rho)
    
    quietly summarize eti_m`m'
    local mean_m = r(mean)
    local sd_m   = r(sd)
    
    display "  m=`m' vs m=25: Spearman rho = " %6.4f `rho' "  |  Mean ETI = " %5.2f `mean_m'
    file write `fh2' "m=`m'," %6.4f (`rho') "," %5.2f (`mean_m') "," %5.2f (`sd_m') _n
    
    save "$out/temp_eti_m`m'.dta", replace
}

file close `fh2'

*── Pooled Mean across 50 imputations ──────────────────────
display "  Computing pooled mean ETI across m=1 to m=50..."

local allvars2 "nei egpc deg fes eptdl accurb accrural acccook ecpc eninten coper chees rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser empin mys eys coepc leb"

* ── Make sure temp_eti_m25 exists or create it ──
capture confirm file "$out/temp_eti_m25.dta"
if _rc != 0 {
    use "$out/data_m25_index.dta", clear
    keep id year eti
    rename eti eti_m25
    save "$out/temp_eti_m25.dta", replace
    display "  temp_eti_m25.dta created from data_m25_index.dta"
}

* Step 1: Start with m=1
use "$out/mi_dataset.dta", clear
mi extract 1, clear
foreach var of local allvars2 {
    quietly rename `var' pool_`var'
}
keep id year pool_*
save "$out/temp_pool.dta", replace

* Step 2: Add m=2 to m=50
forvalues m = 2/50 {
    use "$out/mi_dataset.dta", clear
    mi extract `m', clear
    keep id year `allvars2'
    foreach var of local allvars2 {
        quietly rename `var' temp_`var'
    }
    merge 1:1 id year using "$out/temp_pool.dta", nogenerate
    foreach var of local allvars2 {
        quietly replace pool_`var' = pool_`var' + temp_`var'
    }
    drop temp_*
    save "$out/temp_pool.dta", replace
    if mod(`m',10)==0 display "  m=`m' done..."
}

* Step 3: Divide by 50
use "$out/temp_pool.dta", clear
foreach var of local allvars2 {
    quietly replace pool_`var' = pool_`var' / 50
    quietly rename pool_`var' `var'
}

* Step 4: Winsorize
foreach var of local allvars2 {
    quietly _pctile `var', percentiles(2.5 97.5)
    local p_low  = r(r1)
    local p_high = r(r2)
    quietly replace `var' = `p_low'  if `var' < `p_low'  & !missing(`var')
    quietly replace `var' = `p_high' if `var' > `p_high' & !missing(`var')
}

* Step 5: Normalize
foreach var in egpc deg fes accurb accrural acccook ecpc rec gdppc gcf efi ps mscps investre rcb iui mcs ti ict ictg stja empser mys eys leb {
    quietly _pctile `var', percentiles(2.5 97.5)
    local lb = r(r1)
    local ub = r(r2)
    quietly gen `var'_n = (`var' - `lb') / (`ub' - `lb') * 100
    quietly replace `var'_n = 0   if `var'_n < 0
    quietly replace `var'_n = 100 if `var'_n > 100
}
foreach var in nei eptdl eninten coper chees empin coepc {
    quietly _pctile `var', percentiles(2.5 97.5)
    local lb = r(r1)
    local ub = r(r2)
    quietly gen `var'_n = (`ub' - `var') / (`ub' - `lb') * 100
    quietly replace `var'_n = 0   if `var'_n < 0
    quietly replace `var'_n = 100 if `var'_n > 100
}

* Step 6: Aggregate
gen esp_pool = ((((nei_n+egpc_n)/2)+((deg_n+fes_n)/2)+eptdl_n)/3 + (accurb_n+accrural_n+acccook_n+ecpc_n)/4 + (eninten_n+((coepc_n+coper_n+chees_n)/3)+rec_n)/3) / 3
gen tr_pool  = ((((gdppc_n+gcf_n)/2)+((efi_n+ps_n)/2)+((mscps_n+investre_n)/2))/3 + (rcb_n+((iui_n+mcs_n)/2)+ti_n)/3 + (ict_n+ictg_n+stja_n)/3 + (((empser_n+empin_n)/2)+((mys_n+eys_n)/2)+leb_n)/3) / 4
gen eti_pool = (esp_pool + tr_pool) / 2

* Step 7: Merge and correlate
keep id year eti_pool
merge 1:1 id year using "$out/temp_eti_m25.dta", nogenerate

spearman eti_m25 eti_pool
local rho_pool = r(rho)
quietly summarize eti_pool
local mean_pool = r(mean)
local sd_pool   = r(sd)

display "  Pooled (m=1..50) vs m=25: Spearman rho = " %6.4f `rho_pool' "  |  Mean ETI = " %5.2f `mean_pool'

tempname fh_pool
file open `fh_pool' using "$res/robustness_imputation.csv", write append
file write `fh_pool' "pooled_m1_50," %6.4f (`rho_pool') "," %5.2f (`mean_pool') "," %5.2f (`sd_pool') _n
file close `fh_pool'

save "$out/eti_pooled.dta", replace
capture erase "$out/temp_pool.dta"
capture erase "$out/temp_eti_m25.dta"
display "✓ SA-4 Pooled DONE"

*─────────────────────────────────────────────────────────────
* PART A — Sensitivity Analysis — Alternative Sub-Index Weights
* SA-5: Alternative weights (60% ESP + 40% TR)
* Baseline : 50% ESP + 50% TR
* Alt 1    : 60% ESP + 40% TR
* Alt 2    : 40% ESP + 60% TR
* Standard : Spearman ρ > 0.95 → weighting scheme is robust
*─────────────────────────────────────────────────────────────
use "$out/data_m25_index.dta", clear

* Generate alternative weighted ETI
gen eti_w6040 = 0.60 * subindex_esp + 0.40 * subindex_tr
gen eti_w4060 = 0.40 * subindex_esp + 0.60 * subindex_tr

* Rankings per year 
bysort year: egen rank_base  = rank(-eti)
bysort year: egen rank_w6040 = rank(-eti_w6040)
bysort year: egen rank_w4060 = rank(-eti_w4060)

* ── Spearman correlations ──
quietly spearman eti eti_w6040
local rho_6040 = r(rho)

quietly spearman eti eti_w4060
local rho_4060 = r(rho)

display "  Baseline (50/50) vs Alt-1 (60% ESP / 40% TR): ρ = " %6.4f `rho_6040'
display "  Baseline (50/50) vs Alt-2 (40% ESP / 60% TR): ρ = " %6.4f `rho_4060'
display "  Target: ρ > 0.95 → Robust"

* ── Save results ──
keep id Country year eti eti_w6040 eti_w4060 rank_base rank_w6040 rank_w4060 subindex_esp subindex_tr
save "$out/sa5_weights.dta", replace

* ── Results table ──
putexcel set "$res/SA5_AltWeights.xlsx", replace
putexcel A1 = "SA-5: Alternative Sub-Index Weights"
putexcel A2 = "Comparison"
putexcel B2 = "Spearman rho"
putexcel C2 = "Target"
putexcel A3 = "Baseline (50/50) vs Alt-1 (60% ESP / 40% TR)"
putexcel B3 = `rho_6040'
putexcel C3 = "> 0.95"
putexcel A4 = "Baseline (50/50) vs Alt-2 (40% ESP / 60% TR)"
putexcel B4 = `rho_4060'
putexcel C4 = "> 0.95"

use "$out/sa5_weights.dta", clear

* Note: figures for this last SA test are saved in a dedicated subfolder
global fig "$out/results/figures"
capture mkdir "$out/results"
capture mkdir "$fig"

*── Collapse to country means ──
collapse (mean) eti eti_w6040 eti_w4060 rank_base rank_w6040 rank_w4060, by(Country)

*── Sort + country order ──
sort eti
gen country_order = _n

*── Invert ranks (ascending direction) ──
gen rank_base_inv  = (_N + 1) - rank_base
gen rank_w6040_inv = (_N + 1) - rank_w6040
gen rank_w4060_inv = (_N + 1) - rank_w4060

* Fig. 3a: ETI Scores
twoway (scatter eti_w4060 country_order, mcolor("44 160 44"%70) msymbol(smdiamond) msize(small)) (scatter eti_w6040 country_order, mcolor("31 119 180"%70) msymbol(smtriangle) msize(small)) (scatter eti country_order, mcolor("214 39 40") msymbol(circle) msize(small)), title("(a) ETI Scores under Alternative Sub-Index Weights", size(small) color(black)) xtitle("Countries (sorted by baseline ETI score)", size(vsmall)) ytitle("Mean ETI Score (2000–2023)", size(vsmall)) xlabel(none) ylabel(20(10)70, labsize(vsmall) angle(0) grid glcolor(gs14)) yscale(range(20 70)) legend(order(3 "Baseline (50/50)" 2 "Alt-1 (60% ESP / 40% TR)" 1 "Alt-2 (40% ESP / 60% TR)") position(6) rows(1) size(vsmall) region(lcolor(none))) graphregion(color(white)) plotregion(color(white)) scheme(s1color) xsize(14) ysize(6) name(sa_scores, replace)

graph export "$fig/Fig_SA_Scores.png", replace width(3000) height(1300)
display "✓ Fig. 3a saved"

* Fig. 3b: ETI Rankings
twoway (scatter rank_w4060_inv country_order, mcolor("44 160 44"%70) msymbol(smdiamond) msize(small)) (scatter rank_w6040_inv country_order, mcolor("31 119 180"%70) msymbol(smtriangle) msize(small)) (scatter rank_base_inv country_order, mcolor("214 39 40") msymbol(circle) msize(small)), title("(b) ETI Rankings under Alternative Sub-Index Weights", size(small) color(black)) xtitle("Countries (sorted by baseline ETI score)", size(vsmall)) ytitle("Mean Rank (2000–2023)", size(vsmall)) xlabel(none) ylabel(0(20)140, labsize(vsmall) angle(0) grid glcolor(gs14)) yscale(range(0 141)) legend(order(3 "Baseline (50/50)" 2 "Alt-1 (60% ESP / 40% TR)" 1 "Alt-2 (40% ESP / 60% TR)") position(6) rows(1) size(vsmall) region(lcolor(none))) graphregion(color(white)) plotregion(color(white)) scheme(s1color) xsize(14) ysize(6) name(sa_ranks, replace)

graph export "$fig/Fig_SA_Rankings.png", replace width(3000) height(1300)
display "✓ Fig. 3b saved"
