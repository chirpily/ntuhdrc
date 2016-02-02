********************************************************
| Data management for nested case-control study             |
| Name: N_CSCN_01_data manage.sas                           |
| Date of first created : 2015-8-18                                   |
| Date of last modified:  2015-2-1                                    |
| Author: Chi-Dan Chen                                                  |
| Description:                                                                 |
|   This program is for data management in nested            |
|   case control study.  The selected dataset is                   |
|   from Dr. K A Chan and Dr. I-Jong Wang. SAS code is |
modified with Dr. Jasmine Pwu, Ling-Ya Huang,            |
Yen-Yun Yang, Yuan-Ting Chang and Chi-Dan Chen.     |
The key points for this program include:                          |
|   1. Manage the CD(outpatients data)                             |
        DD(inpatients data) files first.                                  |
|   2. Choose the ICD-9 code of target diseases in your research. |
|   3. Define the inclusion criteria of diseases.                    |
|       ex:At least three ambulatory claims with a diagnosis,          |
        or at least one inpatient claim as one of the discharge diagnoses   |
        during the specific year period.                                |  
|   4. Sort the data.                                                          |
|   5. Comebine CD DD files for study cohort.                  |
********************************************************;

*=====Project: The effects of antihypertensive drugs, oral hypoglycemic agents, and statin in prevention of retinal vascular occlusion=====
==================================Nested case-control study 2000-2011======================================*;
%let link=E:/H102148/RawData;  
libname CD "&link/CD";
libname DD "&link/DD";
libname DO "&link/DO";
libname DRUG "&link/DRUG";
libname druguse "&link/druguse";
libname GD "&link/GD";
libname GO "&link/GO";
libname HOSB "&link/HOSB";
libname HV "&link/HV";
libname ID "&link/ID";
libname OO "&link/OO";
libname death "&link/death";
libname OUTPUT "E:/H102148/王一中醫師/temp";
run;

*----------------------------------------------------------------*
*  First we define the diseases and study period in CD
*  with macro in order to minimize the processing time.
*  We only choose CD.H_nhi_...._10 &_30 (Traditional Chinese & Western medicine)
*  as CD.H_nhi_...._20 is dental medicine.
*----------------------------------------------------------------*;

*Select group: *Outpatients(門急診, CD file);
dm 'log;clear;output;clear;';
%macro one(year);
%do year = 89 %to 100;

%macro two(month);
	data gp&month;
	set CD.H_nhi_opdte&year.&month._10 (keep=ID FUNC_DATE ICD9CM_1 - ICD9CM_3) 
    	 CD.H_nhi_opdte&year.&month._30 (keep=ID FUNC_DATE ICD9CM_1 - ICD9CM_3);

array ICD ICD9CM_1 - ICD9CM_3;
do over ICD;
if ICD in: ('2720', '2721, ''2722', '2724', '2729') then lipid =1;
end;
%mend;
%two(01) %two(02) %two(03) %two(04) %two(05) %two(06) 
%two(07) %two(08) %two(09) %two(10) %two(11) %two(12)

data gp&year;set gp01 gp02 gp03 gp04 gp05 gp06 gp07 gp08 gp09 gp10 gp11 gp12; 
run;
%end;
%mend;
%one;  

data OUTPUT.GP_CD;set gp89 - gp100;
run;/* Combine the files of your study years*/

*----------------------------------------------------------------*
*  Secondly,  define the diseases and study period in DD
*  with macro in order to minimize the processing time.
*----------------------------------------------------------------*;

*Select group: *Inpatients(住院, DD file);
%macro one(year);
%do year = 89 %to 100;

data gp&year;
set DD.H_nhi_ipdte&year(drop=E_BED_DAY S_BED_DAY);
array ICD ICD9CM_1 - ICD9CM_5;
do over ICD;
if ICD in: ('2720', '2721, ''2722', '2724', '2729') then lipid2 = 1;
end;
%end;
%mend;
%one;

data OUTPUT.GP_DD;set gp89 - gp100;
run;/* Combine the files of your study years*/

*-------------------------------------------------------------*
*  Thirdly, define the inclusion criteria of diseases.
*-------------------------------------------------------------*;

/*Outpatient*/
proc sort data=OUTPUT.GP_CD out=CD1 nodupkey;
by ID Date;run;
proc sort data=OUTPUT.CD1 out=subjects nodupkey;
by ID ;run;
proc sort data=OUTPUT.GP_CD;by ID ;run;
proc univariate data=OUTPUT.GP_CD noprint;var lipid;
by ID;output out=OUTPUT.CD2 sum=lipid;run;
data OUTPUT.CD3;set OUTPUT.CD2;
if lipid>=3 then output;
run;

/*At least three ambulatory claims with diagnosis includes in the corhort*/
PROC SQL;
create table OUTPUT.CD4 as select * from OUTPUT.GP_CD where ID in (select ID from OUTPUT.CD3);
QUIT;

/*Inpatient*/
data OUTPUT.DD1(rename=(in_date=func_date)); set OUTPUT.GP_DD;
	if lipid2=1 then output;
run; 
/*At least one inpatient claim as one of the discharge diagnoses*/
proc sort data=OUTPUT.DD1 out=OUTPUT.DD2 nodupkey;
by ID Date;run;
proc sort data=OUTPUT.DD2 out=OUTPUT.DD3 nodupkey;
by ID;run;


*----------------------------------------------------------------*
*  Fourthly, Comebine CD DD files for study cohort.
*----------------------------------------------------------------*;
data OUTPUT.TEMP;set OUTPUT.CD4 OUTPUT.DD1;run;*Cohort門診檔與住院檔合併，一人有好幾筆資料;
proc sort data= OUTPUT.TEMP out=OUTPUT.cddd2000_2011 nodupkey;by ID Date;run;*人次;
proc sort data=OUTPUT.cddd2000_2011 out=subjects3 nodupkey;by ID;run;*人數;

*-------------------------------------------*
*Arrange files of Death;
*-----------------------------------------*;
data OUTPUT.Death;
set Death.H_ost_death87 - Death.H_ost_death101;
expired = input(D_DATE,yymmdd8.);
run;

/*Finally, CD DD ID DEATH merged and Define Study period*/
PROC SQL;
create table OUTPUT.cddd_final as
select a.*, b.ID, b.expired, c*, d*, e* from OUTPUT.cohort2000_2011 as a /*挑選acde裡面全部的欄位, b裡面的 ID 及 D_Date欄位*/
left join output.Death as b /*先merge一個 b (即output.Death) dataset*/
on a.ID = b.ID
left join id.id_birth as c /*再merge一個 c (即id.id_birth) dataset*/
on a.ID = c.ID
left join id.id_inout as d /*再merge一個 d (即id.id_inout) dataset*/
on a.ID = d.ID
left join id.id_birth as e /*再merge一個 e (即id.id_birth) dataset*/
on a.ID = e.ID
where 20020101<a.func_date<20111231
order by ID; /*對ID作排序*/
QUIT;





