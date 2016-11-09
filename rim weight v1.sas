/* Put your schema details in here*/
%let user=eshindler;
%let password=sweet123!;
libname emma oracle user=&user password="&password." schema=eshindler;

libname mcrolib '/sas_share/USER_NI/SAS_macro_library';
options mstored sasmstore=mcrolib;


/* Step 1: PREPARE THE DATA FOR WEIGHTING*/

data sample; 
set emma.BEN_VAL_FOR_RIM2; 
where cust_group='EXISTING' AND Q1_2015=1 AND Q2_2015=1 AND Q3_2015=1 AND Q4_2015=1;
run; 


/* Step 2: GET OVERALL COUNT AND COUNT OF EACH LEVEL IN EACH WEIGHTING VARIABLE */

proc univariate data=sample
	(keep=spend_year_1 TARGET where=(spend_year_1 ne 0 AND TARGET="TEST")) noprint;
	var spend_year_1 ;
	output out=decile pctlpre=P__ pctlpts=10 20 30 40 50 60 70 80 90 ;
run ;

data sample ;
	set sample ;
	* merge with the deciles;
	if _n_=1 then set decile;
	spend_group=(spend_year_1>=P__10)+(spend_year_1>=P__20)+(spend_year_1>=P__30)+(spend_year_1>=P__40)
		+(spend_year_1>=P__50)+(spend_year_1>=P__60)+(spend_year_1>=P__70)+(spend_year_1>=P__80)
		+(spend_year_1>=P__90)+1 ;
	drop P__: ;
run ; 


data Control Test; 
set sample; 
if Target = "CONTROL" then output Control; 
if Target = "TEST" then output Test; 
run; 


proc means data=Test n; 
var account_number; 
output out=SizeOfGroupToMatch n=SizeOfGroupToMatch; 
run; 

proc freq data=Test; 
table acorn / out=acorn(drop=count); 
run; 

proc freq data=Test; 
table SPEND_GROUP / out=SPEND_GROUP(drop=count); 
run; 

proc freq data=Test; 
table loyalty_yr1 / out=loyalty_yr1(drop=count); 
run; 

proc freq data=Test; 
table AGE_BAND2 / out=AGE_BAND2(drop=count); 
run; 

/* Step 3: WEIGH THE DATA RUNNING THE MACRO */
%Weigh_My_Variables 
(inds=Control, 
outds=Control_out, 
inwt=1, 
freqlist=, 
outwt=out_wgt, 
byvar=, 
varlist=age_band2 /*loyalty_yr1 acorn loyalty_yr1 spend_group*/,
numvar=1, 
cntotal=715325, 
trmprec=0.1, 
numiter=100); 


data sample; 
set Control_out Test(in=b); 
if b then out_wgt=1; 
run; 


/* Step 4: CHECK THE DATA ARE BALANCED */
proc freq data=sample; 
by Target; 
table age_band2 ; 
run; 

proc freq data=sample;
  by Target;
  table age_band2 ;
  weight out_wgt;
run;       /* desired sample size or proportion*/ 

* CHECK RIM WEIGHTING ;
PROC SQL ;
	SELECT TARGET , COUNT(*) , SUM(OUT_WGT) FROM SAMPLE GROUP BY 1  ; QUIT ;

* output if lift ;
proc sql ;
create table results_lift as 
	select age_band2, target,
sum(OUT_WGT), sum(spend_year_1*OUT_WGT) as spend2014, sum(spend_year_2*OUT_WGT) as spend2015
, sum(spend_year_1) as spend2014_noweight, sum(spend_year_2) as spend2015_noweight
from  sample
WHERE (Q1_2014+Q2_2014+Q3_2014+Q4_2014)+(Q1_2015+Q2_2015+Q3_2015+Q4_2015)=8
group by age_band2, target
ORDER BY age_band2, target

; quit ;


/* RETENTION */

data sample_RET; 
set emma.BEN_VAL_FOR_RIM2; 
where cust_group='EXISTING';
run; 

/* Step 2: GET OVERALL COUNT AND COUNT OF EACH LEVEL IN EACH WEIGHTING VARIABLE */

proc univariate data=sample_RET
	(keep=spend_year_1 TARGET where=(spend_year_1 ne 0 AND TARGET="TEST")) noprint;
	var spend_year_1 ;
	output out=decile pctlpre=P__ pctlpts=10 20 30 40 50 60 70 80 90 ;
run ;

data sample_RET ;
	set sample_RET ;
	* merge with the deciles;
	if _n_=1 then set decile;
	spend_group=(spend_year_1>=P__10)+(spend_year_1>=P__20)+(spend_year_1>=P__30)+(spend_year_1>=P__40)
		+(spend_year_1>=P__50)+(spend_year_1>=P__60)+(spend_year_1>=P__70)+(spend_year_1>=P__80)
		+(spend_year_1>=P__90)+1 ;
	drop P__: ;
run ; 


data Control_RET Test_RET; 
set sample_RET; 
if Target = "CONTROL" then output Control_RET; 
if Target = "TEST" then output Test_RET; 
run; 

proc means data=Test_RET n; 
var account_number; 
output out=SizeOfGroupToMatch n=SizeOfGroupToMatch; 
run; 

proc freq data=Test_RET; 
table acorn / out=acorn(drop=count); 
run; 

proc freq data=Test_RET; 
table SPEND_GROUP / out=SPEND_GROUP(drop=count); 
run; 

proc freq data=Test_RET; 
table loyalty_yr1 / out=loyalty_yr1(drop=count); 
run; 

/* Step 3: WEIGH THE DATA RUNNING THE MACRO */
%Weigh_My_Variables 
(inds=Control_RET, 
outds=Control_out_RET, 
inwt=1, 
freqlist=, 
outwt=out_wgt, 
byvar=, 
varlist=acorn loyalty_yr1 spend_group,
numvar=3, 
cntotal=829267, 
trmprec=1, 
numiter=100); 


data sample_RET; 
set Control_out_RET Test_RET(in=b); 
if b then out_wgt=1; 
run; 


/* Step 4: CHECK THE DATA ARE BALANCED */
proc freq data=sample_RET; 
by Target; 
table acorn loyalty_yr1 spend_group; 
run; 

proc freq data=sample_RET;
  by Target;
  table acorn loyalty_yr1 spend_group;
  weight out_wgt;
run;       /* desired sample size or proportion*/ 

/*output resuLts for nes=7 */
* CHECK RIM WEIGHTING ;
PROC SQL ;
	SELECT TARGET , COUNT(*) , SUM(OUT_WGT) FROM SAMPLE_RET GROUP BY 1  ; QUIT ;


* output if retention ;

proc sql ;
	create table results_retention as 
	select LOYALTY_yr1, target
	, sum(case when spend_year_1>0 then OUT_WGT else 0 end) as active_2014
	, sum(case when spend_year_2>0 then OUT_WGT else 0 end) as active_2015
	, count(case when spend_year_1>0 then account_number end) as active_2014_nw
	, count(case when spend_year_2>0 then account_number end) as active_2015_nw
	, sum(spend_year_1*OUT_WGT) as spend2014, sum(spend_year_2*OUT_WGT) as spend2015
	, sum(spend_year_1) as spend2014_noweight, sum(spend_year_2) as spend2015_noweight
from sample_RET
group by LOYALTY_yr1, target 
ORDER BY LOYALTY_yr1, target

; quit ;

