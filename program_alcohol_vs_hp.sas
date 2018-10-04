/* Amin Yakubu & Eric D. Morris*/

/*We want to assess the relationship between alcohol consumption and high blood pressure. We will also assess how 
age, race, smoking and gender affects the relationship between our exposure and outcome*/

/* PART I - IN THIS SECTION WE IMPORT ALL NECESSARY DATA SETS FROM NHANES 2009-2010:
ALQ_F: ALCOHOL USE QUESTIONNAIRE 
BPX_F: BLOOD PRESSURE EXAMINATION 
DEMO_F: DEMOGRAPHICS 
SMQ_F: SMOKING QUESTIONNAIRE 
BPQ_F: BLOOD PRESURE QUESTIONNAIRE 

WE WILL USE MACROS TO IMPORT ALL DATA SETS INTO SAS ON DEMAND */

%macro macro_import(file, /*file is the name of the data we are importing*/
					saved /*Saved is the name of the imported dataset*/);

libname sasfinal xport "/home/ay24161/sasuser.v94/project/&file";
	data &saved; set sasfinal.&saved;
run;

%mend macro_import;

%macro_import (ALQ_F.xpt, ALQ_F);
%macro_import (BPX_F.xpt, BPX_F);
%macro_import (DEMO_F.xpt, DEMO_F);
%macro_import (SMQ_F.xpt, SMQ_F);
%macro_import (BPQ_F.xpt, BPQ_F);

/*PART II - DATA CLEANING. 

Here, we examine the data by looking at unusual observations, dealing with missing variables, restricting observations and organizing variables.

SORTING OUR DATA SETS BY SEQN (RESPONDENT ID #) VIA MACROS*/

%macro macro_sort (lib, /*DIRECTORY WHERE DATA SET IS */
				   name_s, /*NAME OF DATA SET */
				   new); /* SORTED DATA SET */				

proc sort data=&lib..&name_s out=&new;
	by SEQN;
run;

%mend macro_sort;

%macro_sort (work, ALQ_F, ALQ_F);
%macro_sort (work, BPX_F, BPX_F);
%macro_sort (work, DEMO_F, DEMO_F);
%macro_sort (work, SMQ_F, SMQ_F);
%macro_sort (work, BPQ_F, BPQ_F);

/*Smoking, eating, alcohol and coffee consumptions within 30min of blood preasure measurements can affect/bias readings.
We decided to exclude those who ate (BPQ150A, 1863 observations), drank alcohol (BPQ150B, 6 observations), drank coffee (BPQ150C, 58 observations) and smoked (BPQ150D, 96 observations)
in the 30min prior to measurements. We also removed missing observations to ensure validity. */  

data bpx_f; set bpx_f;
	array myList(4) BPQ150A BPQ150B BPQ150C BPQ150D; 
		n_miss=cmiss(of myList(4));
			if n_miss >0 then delete;
			if BPQ150A=1 or BPQ150B=1 or BPQ150C=1 or BPQ150D=1 then delete;
			
/* Here we remove subjects who had missing values for all three systolic and diastolic BP measurements (BPXSY and BPXDI).
Those with at least one measurement were kept and an average was calculated if the subject had more than 1 measurement available */			
			
			if sum(BPXSY1,BPXSY2,BPXSY3)=. then delete;
			if sum(BPXDI1,BPXDI2,BPXDI3)=. then delete;
			sbp_mean=mean(BPXSY1,BPXSY2,BPXSY3);
			dbp_mean=mean(BPXDI1,BPXDI2,BPXDI3); 
			KEEP SEQN BPXSY1 BPXSY2 BPXSY3 sbp_mean BPXDI1 BPXDI2 BPXDI3 dbp_mean;
run;

/* Below we want to examine extreme systolic and diastolic measurements, 
we examined the mean distribution the measurements.*/

proc univariate data=bpx_f nextrobs=20;
var sbp_mean dbp_mean;
histogram/normal;
run;

/* The sbp_mean and dbp_mean are approximately normally distributed. There are unusual values like less than 40 for dbp_mean 
and greater than 200 for sbp_mean.*/

/* We decided to remove observations with a mean_sbp >200 and mean_dbp <40 as these values were extreme. mean_dbp values as low as
0 or 10 are not plausible and may have been due to data entry errors. Also mean_sbp for 230 are also unusual */

data bpx_final; set bpx_f;
if sbp_mean>200 then delete;
if dbp_mean<40 then delete;
run;

/*Examining demographics data for unusual observations. Even though Gender and Ethnicity are categorical, proc means with min and max 
shows us if the codes were used correctly and that there are no mistakes or missing values.*/

proc means n nmiss min max mean stddev maxdec=1 data=demo_f;
var RIDAGEYR RIAGENDR RIDRETH1;
run;

/*There are no missing values for age, gender and ethnicity. There are no unusual observations (age ranges to a max of 80 years)*/

/* We decided to create a categorical variable for alcohol use */

/* First, we are deleting refused to answer (777), don't know (999) and missing observations */

data alq_f; set alq_f;
	if alq120q in (777,999,.) then delete;
run;

/* Standardizing alcohol use to drinks per year. Data was collected as
when ALQ120U=1 then it means number drinks per week, when ALQ120U=2 then it means drinks per month and when ALQ120U=3 
then it means number of drinks per year.Those with missing ALQ120U observations were non-drinkers as reported in ALQ120Q (0 drinks) */

data alq_f; set alq_f;
	if alq120u=1 then drinks_year=alq120q*52;
	if alq120u=2 then drinks_year=alq120q*12;
	if alq120u=3 then drinks_year=alq120q;
	if alq120u=. then drinks_year=0;
run;


/* Making our exposure variable (Drinking) a binary categorical variable:  
0-12 drinks a year = non/light drinkers
12+ drinks a year = moderate/regular drinkers */

data alq_f; set alq_f;
if drinks_year<=12 then drinks_bin=0; 
else drinks_bin=1;
run;

/* We hypothesized smoking to be a confounder in the blood pressure/alcohol relationship. 
Previous Smoking status determined via SMQ020: Smoked at least 100 cigarettes in life (1= YES, 2=NO)
Removing 7 (refused), 9 (don't know), and . (missing) observations */

data SMQ_F; set SMQ_F;
	if SMQ020 in (7,9,.) then delete;
run;

/*Merging the datasets and restricting it to observations that can be found in all the datasets and keeping our variables of interest*/

 data final; merge alq_f (in=a) bpx_f (in=b) demo_f (in=c) smq_f (in=d) bpq_f (in=e);
	by SEQN;
	if a and b and c and d and e;
	keep SEQN RIAGENDR RIDAGEYR RIDRETH1 SMQ020 BPQ050A sbp_mean DBP_mean drinks_year drinks_bin; 
run; 

/* Creating our outcome variable of high blood pressure (HBP):
We decided to use currently taking HBP medication as a proxy. However, we used examination measurements (sbp_mean and dbp_mean) to 
determine blood pressure status if the HBP medication variable was anything (missing or not taking medication) other than 1 
(1=currently taking medication).
Subjects with missing HBP medication variable was classied as having high blood pressure (HBP=1) if 
mean_sbp > 140, or mean_dbp > 90  (HBP as defined by the American Heart Association) */

data final1; set final;
	if bpq050a=1 or sbp_mean >140 or dbp_mean >90 then HBP=1;
	else HBP=0; 
run;

/* We want to restrict the age to those who are 35 years or older. 
American Heart Association states that those with HBP and <35 probably have the condition due to an extraneous factor 
(unreleated to our exposure of interest of alcohol use)*/

data final2; set final1;
	if RIDAGEYR <35 then delete;
run;
	
/*Creating formats to make output easily understandable*/
proc format; 
	value Genderf 1 = "Male" 2 = "Female";
	value Racef 1='Mexican American'
				2='Other Hispanic'
				3='Non-Hispanic White' 
				4='Non-Hispanic Black'
				5='Other race - Incl. Multi-racial';
	value Smokerf 1='Has Smoked'
				  2='Never Smoked';
	value Drinkerf 0='Non to light drinker'
				   1='Moderate to regular drinker';
	value HBPf	1 = 'HBP'
				0 = 'Normal BP';
run; 

/*Applying formats to our dataset*/

data final2; set final2;
	format RIAGENDR Genderf. RIDRETH1 Racef. SMQ020 Smokerf. drinks_bin Drinkerf. HBP HBPf.;
run;			
				
/*PART III - Exploratory Data Analysis. Here, we determine which variables should be included in our final model for analysis.
We explore how the variables act together and how they behave independently*/

/*We begin by looking for confounding. We set alpha of 5% for all the plausible confounder variables*/

/* According to previous research gender can be associated with HBP.
Here, we want to see if gender is associated with high blood pressure (outcome) in our data */
proc logistic data=final2;
	class RIAGENDR (ref="Female")/param=ref;
	model HBP=RIAGENDR / cl;
run; 

/*Wald Chi squared=0.1375	p value=0.7107*/ 
/*At 5% level of significance, we have sufficient evidence to conclude that gender and HBP are not associated. 
Therefore, Gender will not be included in the final model to check for confounding since it's not associated with the outcome*/
	
/*We want to see if ethnicity is associated with the outcome (HBP)*/
proc logistic data=final2;
	class RIDRETH1 (ref='Mexican American')/param=ref;
	model HBP=RIDRETH1 / cl;
run; 

/*Wald chi squared=55.0693 p value <.0001 */ 
/* At 5% level of significance, we have sufficient evidence to conclude that Race/Ethnicity and HBP are associated */

/* We want to see if ethnicity is associated with the exposure (drinking)*/
proc logistic data=final2; 
	class  RIDRETH1 (ref='Mexican American')/param=ref;
	model drinks_bin=RIDRETH1 / cl;
run; 

/*Wald chi squared=46.5722 p value<.0001*/ 
/* At 5% level of significance, we have sufficient evidence to conclude that Race/Ethnicity and drinks_bin are associated */
/*Since Race/Ethinicity is associated with both the exposure and outcome and not on the causal pathway, we will include it in the final model to examine if there's
confounding*/

/*Assessing if smoking is a confounder of the relationship between HBP and drinking */

/*Assessing if smoking and HBP are associated*/
proc logistic data=final2;
class SMQ020 (ref='Never Smoked')/param=ref;
model HBP=SMQ020/cl; 
run;

/*Wald chi squared=4.2209 p value=0.0399*/
/* At 5% level of significance, we have sufficient evidence to conclude that smoking and HBP are associated */

/*Assessing if smoking and drinking are associated*/
proc logistic data=final2;
class SMQ020 (ref='Never Smoked')/param=ref;
model drinks_bin=SMQ020/cl;
run;

/*Wald chi squared =1.4883 p value=0.2225*/
/* At 5% level of significance, we have insufficient evidence to conclude that smoking and drinking are associated */

/*Since smoking is not associated with both exposure and outcome, we won't assess it for confounding*/

/*We are checking if there's effect modification. Again, we will use alpha of 5%*/

Title ' Checking Effect Measure Modification';
Title2 'Effect measure modification with smoking';
proc logistic data=final2; 
class drinks_bin (ref='Non to light drinker') SMQ020 (ref='Never Smoked')/param=ref;
model HBP=drinks_bin | SMQ020/cl; 
run;

/* Wald chi squared=0.2148 and p value = 0.6430 for interaction term (beta) drinks_bin*SMQ020. 
Since p value is greater than alpha of 5%, we conclude that there's no effect modification */

Title2 'Effect measure modification with race';
proc logistic data=final2;
class drinks_bin (ref='Non to light drinker') RIDRETH1(ref='Mexican American')/param=ref;
model HBP=drinks_bin | RIDRETH1/cl;  
run;

/*Wald chi square=4.7365 p value=0.3154 for interaction term (drinks_bin*RIDRETH1).
Since p value is greater than alpha of 5%, we conclude that there's no effect modification*/

Title2 'Effect measure modification with Gender';
proc logistic data=final2;
class drinks_bin (ref='Non to light drinker') RIAGENDR (ref='Female')/param=ref;
model HBP=drinks_bin | RIAGENDR /cl;  
run;

/* Chi square=11.3323 p value=0.0008. 
Since p value is less than alpha of 5%, we conclude that there's effect modification*/

/*PART IV - Confirmatory Data Analysis*/

/* No parameters of interest. 
H0: There is no association between drinking and high blood pressure
H1: There is an association between drinking and high blood pressure

set alpha=0.05 */

title 'Crude Logistic Model';
proc logistic data=final2; 
class drinks_bin (ref='Non to light drinker')/param=ref;
model HBP=drinks_bin/cl; 
run;

/*Wald chi squared=16.9012 and p value=<.0001 
Since the p value is less than alpha 0.05, we reject the null hypothesis.

At a 5% level of significance, we have sufficient evidence to conclude that there is an association between drinking and high blood
pressure. 

The odds of high blood pressure for regular drinkers is 0.723 times the odds of high blood pressure for non to light drinkers. 
(95% CI 0.619, 0.844). */

/*Checking if Race/Ethinicity is a confounder*/
title 'Adjusted Logistic Model with Race/Ethnicity Confounder';
proc logistic data=final2;
class drinks_bin (ref='Non to light drinker') RIDRETH1 (ref='Mexican American')/param=ref;
model HBP=drinks_bin RIDRETH1/cl;  
run; 

/*Since the percent change of the beta coefficient (log odds) for drinks_bin is greater than 10%, we found evidence of confounding in our data ((0.3247-0.3779)/0.3779=14.1%)*/

 
/*Effect modification with gender with alpha of 0.05*/
proc logistic data=final2;
class drinks_bin (ref='Non to light drinker') RIAGENDR (ref='Female')/param=ref;
model HBP=drinks_bin |RIAGENDR /cl; 
oddsratio drinks_bin/DIFF=ref; 
run;

/*drinks_bin*RIAGENDR	wald chi squared=11.3323	p=0.0008
Since the p value is less than alpha of 0.05, we can conclude that there's effect modification by gender*/

/*Final Model with our exposure of interest (drinks_bin), our confounding variable (RIDRETH1) and our effect modifier (RIAGENDR)*/

/*Results presented in TABLE 2 AND in the 'findings' section of abstract*/
proc logistic data=final2;
class drinks_bin (ref='Non to light drinker') RIAGENDR (ref='Female') RIDRETH1 (ref='Mexican American')/param=ref;
model HBP=drinks_bin RIDRETH1 drinks_bin*RIAGENDR  /cl; 
oddsratio drinks_bin/ diff=REF ;
run;

/*Interaction term drinks_bin*RIAGENDR Wald chi squared=12.0758	p-value=0.0005. TABLE 2

At the 5% level of significance, we have sufficient evidence to conclude Gender 
modifies the relationship between drinking and HBP, adjusting for ethnicity */

/*These results are summarised and presented in the "FINDINGS" section of the abstract*/

/* Among females, the odd of HBP for "moderate to regular" drinkers is 0.523 times the 
odds of HBP for "non to light"  drinkers, adjusting for race/ethnicity. 95% CI (0.419, 0.653)

Among males, the odds of HBP for "moderate to regular" drinkers is 0.801 times the odds of 
HBP for "non to light"  drinkers, adjusting for race/ethnicity. 95% CI (0.669, 0.960) */

/*PART V - This section is the analysis of the results from our tables */

/*This program gives the number of people number we have in each category*/
/*Provides the total number of people in group and the marginal percentages as show in TABLE 1 (the Total colunm)*/

proc freq data=final2;
	table RIAGENDR HBP RIDRETH1 drinks_bin SMQ020;
run;

/*For our exposure variable (drinking) 53.09 were "non to light" drinkers whereas 46.91% were "moderate to regular" drinkers.
There are 53.55% Male and 46.45% Female. Among males Our data is somehow well distributed between male and females

For the race outcome, Non-Hispanic White, Mexican American, Non-Hispanic Black, Other Hispanic, Other/Multi-Racial made up
53.28%, 17.30%, 17.03%, 8.98% and 3.41%  respectively. The data is not equally distributed among groups */
 

/*We need to sort our data by HBP so that we can table by HBP for different variables*/
proc sort data=final2 out=final3;
	by HBP;
run;

/*Provides the Normal BP and HPB for males and females. Results are shown in TABLE 1 ROW 2 (GENDER)*/
proc freq data=final3; 
	table RIAGENDR;
	by HBP;
run;

/*Table 1 ROW 2 (Gender) shows that men had a slight higher probability of HBP compared to women. Men has a 47.13%
probability of HBP whereas women had 46.41%. */

/*Provides the Normal BP and HPB for different ethnicities*/
proc freq data=final3;
	table RIDRETH1;
	by HBP;
run;

/*Probability of HBP was higher in Non-hispanic Black (60.59%), followed by Non-Hispanic White (47.01)) and 
Other Hispanic(41.03)%) */

/*We want to see the average age of those who had the outcome and those who did not*/
proc means mean std maxdec=1 data=final2; 
	var RIDAGEYR;
	class HBP;
run;

/*We realized that the average of those who had normal blood pressure (63.4 years)  was higher than 
those with high blood pressure (51.2 years). This is shown in the first row of TABLE 1*/

/*Number of people who are drink by HBP*/ 
proc freq data=final3;
	table drinks_bin;
	by HBP;
run;

/*Those who drink had a lower probability of HBP [freqency=520]((probability=42.52%) which was also supported by our hypothesis testing.
 Table 1 ROW 4 */
	
/*Number of people who smoke by HBP*/

proc freq data=final3;
	table SMQ020;
	by HBP;
run;
/*53.43%  and 46.57% of our participants were smokers and non-smokers respectively. We showed in our hypothesis that smoking
did not confound the relationship between drinking and HBP in our sample */








