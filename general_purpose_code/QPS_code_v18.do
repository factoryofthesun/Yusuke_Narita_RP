qui {
* Set the necessary locals and globals here
loc output "$output"
loc num_simulations $num_simulations
loc delta $delta
loc seed $seed 
loc xvarlist "$xvarlist"
loc extravarlist "$extravarlist"
loc uni_id "$uni_id"
loc drop_varlist "$drop_varlist"



loc begin = "$S_TIME"

* Inputting the input file here
cd "$input_path"
use "$input_file", clear 

set rmsg on 

* Preparing data - part 1  - normalize the covariate vector
foreach varname in `xvarlist' {
	su `varname'
	replace `varname' = (`varname' -`r(mean)')/`r(sd)'
	gen `varname'_orig = `varname'

}



* We set seed here. 
set seed $seed



noi : count


loc noobs = `r(N)'




* Here foreach of the variables mentioned in the xvarlist, we set the maximum and minimum bounds from which we want to draw our pick. For the maximum bound, we calculate varname_max = varname + delta. For the minimum bound, we calculate varname_min = varname - delta. We then pick a value for simulation number j by picking a value between varname + delta and varname - delta 

cap drop `output'	

forval j = 1/`num_simulations' {
g total_`j' = 0 
	
	
	foreach varname in `xvarlist' {
		loc seedx = $seed + `j'
		set seed `seedx'
		sort $uni_id, stable
		
		cap drop `varname'_stdnorm`j'
		gen `varname'_stdnorm`j' = rnormal(0,1)
		replace total_`j' = total_`j' + (`varname'_stdnorm`j'*`varname'_stdnorm`j')
	}
	cap drop norm_`j'
	g norm_`j'= (total_`j')^0.5
	
	cap drop r_`j'
	g r_`j' = (runiform(0,1))^(1/$num_cov)
	replace r_`j' = r_`j'*`delta'
	
	foreach varname in `xvarlist' {
		g `varname'_`j' = ((r_`j'*(`varname'_stdnorm`j'))/norm_`j') + `varname'_orig
		cap drop `varname'_stdnorm`j'
		}
	cap drop total_`j'
	cap drop r_`j'
	cap drop norm_`j'





		
	foreach varname in "`extravarlist'" {
		cap drop `varname'
	}
	foreach varname in `xvarlist' {
		cd "$directory"
		cap drop `varname'
		ren `varname'_`j' `varname'
		}
		
		
		
		do "$MLcode"
		
				
		
		ren `output' `output'_`j'
	foreach varname in `xvarlist'  {
		ren `varname' `varname'_`j'
		cap drop `varname'_`j'
}
}







cap drop QPS_mean 
preserve 
keep `uni_id' `output'*

foreach varname in `drop_varlist' {
	cap drop `varname'
}

order `uni_id' `output'_1


egen QPS_mean = rowmean(`output'_1-`output'_`num_simulations')
keep QPS_mean `uni_id' 
tempfile 1
save `1', replace
restore 
merge 1:1 `uni_id' using `1', assert(match) nogen



cd "$path"
cap erase "k_eltemp`yr'_$delta"
cd "$output_path"
if `delta' == $delta1 {
		cd "./delta1"
	}
	if `delta' == $delta2 {
		cd "./delta2"
		}
	
	if `delta' == $delta3 {
		cd "./delta3"
		}
		
	if `delta' == $delta4 {
		cd "./delta4"
		}
		
	if `delta' == $delta5 {
		cd "./delta5"
		}
		
	if `delta' == $delta6 {
		cd "./delta6"
		}
cap mkdir "$folder_name"
cd "./$folder_name"

save "$output_file", replace

}
