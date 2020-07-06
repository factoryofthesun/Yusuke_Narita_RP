/*
Date: 
Do file written by:
Last modified on:

In this do file set the inputs and necessary paths  to run the QPS code


There are 2 component do files here - that are part of the main do-file which need not be altered

1. Choosing_delta.do do file calculates the standard deviation for the co-variate variable (x-variable) that you would mention in x-varlist
2. The QPS code calculates different simulations of the outcome variable by running simulations for different values of co-variate vector within the delta ball


* Description of the process:
1. First the code runs through the original dataset to calculate the standard deviation of the covariate variable (Right now, we only have one covariate variable). 
2. Then the code picks the different proportion of the standard deviation as deltas (In the code below I have initialized prop1 prop2 prop2 prop4 prop5 and prop6. However this can be changed as per the user's requirements.)
The above step is carried out in choosing_delta.do do file 
3. The code then moves onto calculating QPS 
	a. The QPS code first starts by generating a standard normal variable for each variable in the covariate vector. Foreach variable in the covariate vector, the code generates a std normal variable = rnormal(0,1). Let's call the vector of standard normal variables u.  
	b. The code then takes the norm of all the standard normal variables that have been generated in the previous step. norm = norm(u)
	c. We then calculate the radius - r to be - ((runiform(0,1))^(1/number of variables in the covariate vector))*delta. We basically scale the radius vector by the predetermined delta
	d. Foreach variable in the covariate vector, we then pick a value lying within the ball centered at x with radius \delta as following. x' = (radius*u/norm) + x
	e. Once we pick values within the ball foreach of the simulations specified, we input the simulated covariate vectors into our ML code. 
	f. Foreach of the simulations, the code runs the MLcode and then calculates the outcome variable.
	g. Once it finishes running the number of simulations specified, it calculates the mean of the outcome variable that has been calculated for each of the simulations.
* For details about how we pick values from a \delta ball around x, please refer to method 20 in http://extremelearning.com.au/how-to-generate-uniformly-random-points-on-n-spheres-and-n-balls/

* Inputs required 
1. ML code <- Here the ML code should contain the algorithm which given a set of covariate vector, recommends a certain decision (e.g. whether an offender should be given parole, the price to be charged to a person ordering an uber in a certain location, at a certain time) 
2. Covariate Vector
3. Number of simulations
4. Outcome variable
5. Input dataset
6. Any extra variables that need to be dropped.
7. Paths wherever required

* Outputs produced
1. Dataset with QPS_LPS calculated for each of the deltas in their sub-folders. 



*/

clear all 

cd "/gpfs/loomis/project/narita/ap2474/MLisNE/simulation_new/do/" // set the main path here

/* If you're running the do file on the cluster and would like to parallelize the do file across years, uncomment line 15

If you would like to run the code for only one year, mention that in line 17 */


global xvarlist = "x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 x29 x30 x31 x32 x33 x34 x35 x36 x37 x38 x39 x40 x41 x42 x43 x44 x45 x46 x47 x48 x49 x50 x51 x52 x53 x54 x55 x56 x57 x58 x59 x60 x61 x62 x63 x64 x65 x66 x67 x68 x69 x70 x71 x72 x73 x74 x75 x76 x77 x78 x79 x80 x81 x82 x83 x84 x85 x86 x87 x88 x89 x90 x91 x92 x93 x94 x95 x96 x97 x98 x99 x100" // <- Mention the X variables here. By x variables we are referring to the variables for which for each observation, we want to draw a delta ball and pick observations
global num_cov = 100 // <- Mention the total number of continuous X variables we have here 
//global aggregate_path =  <- If you have aggregate data where you combine the data for different years then set this to be the path where you have the aggregate data. If you just have an individual file (for a year) then this path would be the same as the input_path
//global agg_file = // <- Similarly, mention here the name of the aggregate dataset for which you want to calculate the deltas. If you just have one file then this file would be the same as input_file	
global delta_dopath = "/gpfs/loomis/project/narita/ap2474/MLisNE/simulation_new/do/" // <- Here set the dopath for where the choosing_delta.do file is saved 








* Preparing data - part 2 - set the deltas for running QPS 
global delta1 = 0.005 
global delta2 = 0.01
global delta3 = 0.025
global delta4 = 0.05
global delta5 = 0.075
global delta6 = 0.10

cd "$delta_dopath"	

foreach delta in $delta1 $delta2 $delta3 $delta4 $delta5 $delta6  {
	//global year =  `year' // <- If you have to run the MLcode for only a certain year, mention that code here. If you have no such year variable, you can also leave this empty
	global delta = `delta'  // <- Mention the delta you would like to do QPS for
	
	
	/* After running the MLcode, we may have some extra variables that we want to drop before next iteration. If there are any such variables, you can uncomment the next line and mention the list of variables you want to drop. Otherwise you can leave it empty */
	
	global extravarlist = "sum sum1"
	global num_simulations =  400 // <- mention the number of simulations that you would like to run this for
	global directory = "/gpfs/loomis/project/narita/ap2474/MLisNE/simulation_new/do/"  // <- Mention the path where the MLcode is saved
	global output = "ML" // <- Mention the main output variable which you would like to average to get QPS
	
	global seed = 8693 // <- Set seed
	
	global input_path = "/gpfs/loomis/project/narita/ap2474/MLisNE/simulation_new/test_data/" // <- Mention the input folder path where the input file is saved
	global output_path = "/gpfs/loomis/project/narita/ap2474/MLisNE/simulation_new/test_data/" // <- Mention the output folder path where you would like to save the output
	
	cd "$output_path"
	
	/* Below we create subfolder delta. I would like to save the output file in the corresponding delta folder. 
	*/
	if `delta' == $delta1 {
		cap mkdir "delta1"
	}
	if `delta' == $delta2 {
		cap mkdir "delta2"
		}
	
	if `delta' == $delta3 {
		cap mkdir "delta3"
		}
		
	if `delta' == $delta4 {
		cap mkdir "delta4"
		}
		
	if `delta' == $delta5 {
		cap mkdir "delta5"
		}
		
	if `delta' == $delta6 {
		cap mkdir "delta6"
		}
	//global path  // <- Here, set any necessary paths for the MLcode. In my ML code, it is required to draw a subfile. I put the subfile in the path directory. If there is no such file, you can comment out line 36
	global do_path  =  "/gpfs/loomis/project/narita/ap2474/MLisNE/simulation_new/do/" // <- Mention the path for where the QPS do file is stored
	global uni_id = "sno" // <- Mention the variable which uniquely identifies rows here. We need this to efficiently and quickly calculate the QPS mean for the data
	//global folder_name = v1  // If you would like the data to be stored in a subfolder within the delta folder, you can mention the folder name here
	global MLcode = "03_ML_code_v2" // Mention the name of the MLcode file here
	global input_file = "test_data_v2" // <- Mention the input file here 
	global output_file = "output_data_v2" // <- Mention the outputfile here
	cd "$do_path"
	//global drop_varlist = "sum sum1 u" // <- Here, mention the variable names that start with the characters mentioned in `output' apart from output1 output2 ...... We want to keep only `output'1, `output'2 --- `output'`num_simulations' in order to calculate the QPS mean
	global QPS_code = "QPS_code_v18.do" // <- Mention the do file for the QPS code here
	global w = 1
	do "$QPS_code"
	}
	
