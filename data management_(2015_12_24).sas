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

*Select lipid group: *Outpatients(門急診);
dm 'log;clear;output;clear;';
%macro one(year);
%do year = 89 %to 100;

%macro two(month);
data gp&month;
set CD.H_nhi_opdte&year.&month._10 (keep=ID FUNC_DATE ICD9CM_1 - ICD9CM_3) 
     CD.H_nhi_opdte&year.&month._30 (keep=ID FUNC_DATE ICD9CM_1 - ICD9CM_3);
Date = input(FUNC_DATE,yymmdd8.);
array ICD ICD9CM_1 - ICD9CM_3;
do over ICD;
if ICD in: ('2720', '2721, ''2722', '2724', '2729') then lipid = 1;
end;
%mend;
%two(01) %two(02) %two(03) %two(04) %two(05) %two(06) 
%two(07) %two(08) %two(09) %two(10) %two(11) %two(12)

data gp&year;set gp01 gp02 gp03 gp04 gp05 gp06 gp07 gp08 gp09 gp10 gp11 gp12; 
run;
%end;
%mend;
%one;

data OUTPUT.LGP_CD(rename=(func_date=lp_func_date));
set gp89 - gp100;
run;

*Select lipid group: *Inpatients(住院);
%macro one(year);
%do year = 89 %to 100;

data gp&year;
set DD.H_nhi_ipdte&year(drop=E_BED_DAY S_BED_DAY);
Date = input(IN_DATE,yymmdd8.);
array ICD ICD9CM_1 - ICD9CM_5;
do over ICD;
if ICD in: ('2720', '2721, ''2722', '2724', '2729') then lipid2 = 1;
end;
%end;
%mend;
%one;

data OUTPUT.LGP_DD(rename=(in_date=lp_func_date));
set gp89 - gp100;
run;


dm 'log;clear;output;clear;';
/*Outpatient*/
proc sort data=OUTPUT.LGP_CD out=OUTPUT.LGP_CD1 nodupkey;by ID Date;run;*First data;
proc sort data=OUTPUT.LGP_CD1 out=OUTPUT.LGP_CDsubject nodupkey;by ID ;run;*人數;
proc sort data=OUTPUT.LGP_CD;by ID ;run;
proc univariate data=OUTPUT.LGP_CD noprint;var lipid;by ID;output out=OUTPUT.LGP_CD2 sum=lipid;run;
data OUTPUT.LGP_CD3;set OUTPUT.LGP_CD2;
	if lipid>=3 then output;*門診次數3次以上的才納入lipid cohort;
	run;
PROC SQL;
	create table OUTPUT.LGP_CD4 as select * from OUTPUT.LGP_CD where ID in (select ID from OUTPUT.LGP_CD3);
	QUIT;

/*Inpatient*/
data OUTPUT.LGP_DD1; set OUTPUT.LGP_DD;
	if lipid2=1 then output;
	run;*住院次數1次即可納入lipid cohort;
proc sort data=OUTPUT.LGP_DD1 out=OUTPUT.LGP_DD2 nodupkey;by ID Date;run;*First data;
proc sort data=OUTPUT.LGP_DD2 out=OUTPUT.LGP_DDsubject nodupkey;by ID;run;*人數;

/*Combine data*/
data output.temp1;set OUTPUT.LGP_CD4 OUTPUT.LGP_DD1;run;*lipid cohort門診檔與住院檔合併，一人有好幾筆資料;
proc sort data=output.temp1 out=OUTPUT.cohort2000_2011 nodupkey;by ID Date;run;*人次;
proc sort data=OUTPUT.cohort2000_2011 out=OUTPUT.cohort_subject nodupkey;by ID;run;*人數;


*整理死亡檔;
proc sort data=output.Death out=output.Death_1 (keep=ID D_DATE) nodupkey;by ID;run;
proc sort data=id.id_birth;by ID  ;
run;
proc sort data=id.id_inout out=id_inout;by ID ;
run;
proc sort data=id.id_sex out=id_sex;by ID ;
run;
/*CD DD ID DEATH merged*/
data  OUTPUT.cddd_final;
        merge OUTPUT.cohort2000_2011(in=k)
		           output.Death1
				   id.id_birth
				   id.id_inout
                   id.id_sex;
		by ID ;if k=1;
		run;
		*cdchen用SQL的語法會比較快;

*Final cohort;
data output.cohort_final;set OUTPUT.cddd_final; run;

*2015/12/24;
/**找2002_2011每個人的first_date**/
data cohort1; set output.cddd_final; if func_date<20020101 then delete; run;
data cohort2; set cohort1; if func_date>20111231 then delete; run;

data cohort3; set cohort2; 
lp_func_year=substr(func_date,1,4);
proc sort data=cohort3(rename=(func_date=lp_func_date)); by id lp_func_year lp_func_date;
data cohort4(rename=(lp_func_date=lp_first_date)); 
set cohort3; by id lp_func_year lp_func_date;
if (first.id=1 and first.lp_func_year=1) or (first.id=0 and first.lp_func_year=1) then output; run;

/*把first_date歸人*/
data cohort5; set cohort4; run;
proc sort data=cohort5; by id;
data output.cohort6;set cohort5; by id;
if first.id then output; run;

/*把last_date mark歸人*/
data last_date; set output.cddd_final;run;
proc sort data=last_date; by id;
data output.last_date1(rename=(func_date=lp_last_date)); set last_date; by id;
if last.id then output; run;


/*判斷RVO RAO*/
data output.rd; set output.cddd_final;
rd=1;
rd_year=year(INPUT(func_date, yymmdd8.));
if substr(icd9cm_1,1,5) in ('36235','36236','36237','36231', '36232', '36233', '36234','36230') or
substr(icd9cm_2,1,5) in ('36235','36236','36237','36231', '36232', '36233', '36234','36230') or
substr(icd9cm_3,1,5) in ('36235','36236','36237','36231', '36232', '36233', '36234','36230') or
substr(icd9cm_4,1,5) in ('36235','36236','36237','36231', '36232', '36233', '36234','36230') or
substr( icd9cm_5,1,5) in ('36235','36236','36237','36231', '36232', '36233', '36234','36230') 
then output; 
run;*2983;


/*歸人*/
proc sort data=output.rd; by id func_date;
data output.rd_first (rename=(func_date=rd_first_date)); set output.rd; by id func_date;
if first.id then output; run; *635;


/*黏回主檔案*/
proc sort data=output.cddd_final; by id;*42346023;
proc sort data=output.cohort6(keep=id lp_first_date); by id;*2472545;
proc sort data=output.rd(keep=id rd); by id;*2938;
proc sort data=output.rd_first(keep=id rd_first_date); by id;*635;
proc sort data=output.last_date1(keep=id lp_last_date); by id;run;*2552680;

data output.cohort_rd; merge output.cddd_final(in=k) 
output.cohort6 output.rd output.rd_first output.last_date1; by id;
if rd=' ' then rd=0;
if lipid=' ' then lipid=0;
if lipid2=' ' then lipid2=0;if k=1 then output; run;

/*Case*/
data case; set output.cohort_rd;
if rd=1 then output; run;*and func_type='10'/58;*3977;
data case1; set case; by id;if first.id then output;run;*635;
data rd_case; set case1;
match_year=substr(rd_first_date,1,4);
enddate='20111231';
BIR=substr(ID_BIRTH_YM,1,4);
END=substr(ENDDATE, 1,4);
AGE=END-bir;
if age< 20 then delete; 
if id_s=2 then sex=0;
if id_s=1 then sex=1; run;
data output.rd_case1(keep=id age sex match_year1 rd); set rd_case; 
match_year1=match_year+0; run; 

/*Control*/
data output.cohort_rd1; set output.cohort_rd; by id;if first.id then output;run;
data control; set output.cohort_rd1;
if rd=0 then output;run;
data rd_control; set control;
match_year=substr(lp_last_date,1,4);
enddate='20111231';
BIR=substr(ID_BIRTH_YM,1,4);
END=substr(ENDDATE, 1,4);
AGE=END-bir;
if age< 20 then delete; 
if id_s=2 then sex=0;
if id_s=1 then sex=1; run;
data output.rd_control1(keep=id age sex match_year rd); set rd_control; 
match_year1=match_year+0; run; 

data output.match; set output.rd_control1 output.rd_case1;run;


/*****************根據SQL過程進行配對**********************
STUDY:欲配對的實驗組
CONTROL:欲配對的對照組
N1:取實驗組前N1筆資料,要取全部資料則用MAX
N2:取對照組前N2筆資料,要取全部資料則用MAX
NN:重複配對的循環次數,任意選個夠大的整數即可
OUTDATA:配對後的資料
IDVA:配對根據的變數 ex:ID
MVARS:配對條件,須皆為屬量變數 ex:AGE GENDER BRANCH_ID
DMAK:每個配對條件的上下界 ex:1 0 0,表示 AGE+/-1 GENDER+/-0 BRANCH_ID+/-0
N:配對比例 ex:N=2,表示1:2的配對比例
INDEX:區分配對後實驗組和對照組的指標
FINAL:整理過後最後的資料
***************************************************************/
%LET STUDY=TEST.ACUTE_IP_ID;
%LET CONTROL=TEST.ACUTE_IPCON_ID;
%LET N1=MAX;
%LET N2=MAX;
%LET NN=20;
%LET OUTDATA=MATCH_ID;
%LET IDVA=ID;
%LET MVARS=AGE GENDER BRANCH_ID;
%LET DMAK=1 0 0;
%LET N=2;
%LET INDEX=INDEX;
%LET FINAL=FINAL_ID;
%GLOBAL NVAR;
%MACRO M;
DATA STUDY;SET &STUDY.(OBS=&N1.);RAND_NUM=uniform(0);
DATA CONTROL;SET &CONTROL.(OBS=&N2.);RAND_NUM=uniform(0);
RUN;
DATA &OUTDATA.;SET _NULL_;
%DO J= 1 %TO &NN.;
%LET NVAR=0;
%DO %UNTIL(%SCAN(&MVARS.,&NVAR.+1,' ')= );
%LET NVAR=%EVAL(&NVAR.+1);
%END;
DATA CONTROL;SET CONTROL;
%DO I=1 %TO &NVAR.;
%LET V&I.=%SCAN(&MVARS.,&I.,' ');
%END;
%DO I=1 %TO &NVAR.;
%LET W&I.=%SCAN(&DMAK.,&I.,' ');
%END;
%DO I=1 %TO &NVAR.;
H&I.=&&V&I.+&&W&I.;
L&I.=&&V&I.-&&W&I.;
%END;
RUN;
PROC SQL;
CREATE TABLE CONTROL_ID AS SELECT
one.ID AS STUDY_&IDVA., two.ID AS CONTROL_&IDVA.,
%DO I=1 %TO &NVAR.;
%LET V&I.=%SCAN(&MVARS.,&I.,' ');
%END;
%DO I=1 %TO &NVAR.;
one.&&V&I. AS STUDY_&&V&I., two.&&V&I. AS CONTROL_&&V&I.,
%END;
two.RAND_NUM AS RAND_NUM from STUDY one, CONTROL two
WHERE
%DO I=1 %TO %EVAL(&NVAR.-1);
one.&&V&I. BETWEEN two.H&I. AND two.L&I. AND
%END;
%DO I=&NVAR. %TO &NVAR.;
one.&&V&I. BETWEEN two.H&I. AND two.L&I.;
%END;
/*count the number of control subjects for each case subject*/
PROC SORT DATA=CONTROL_ID;BY STUDY_&IDVA.;RUN;
DATA N_CONTROL(KEEP=STUDY_&IDVA. NUM_CONTROLS);SET CONTROL_&IDVA.;BY STUDY_&IDVA.;RETAIN NUM_CONTROLS;
IF FIRST.STUDY_&IDVA. THEN NUM_CONTROLS=1;ELSE NUM_CONTROLS=NUM_CONTROLS+1;IF LAST.STUDY_&IDVA. THEN OUTPUT;RUN;
/*now merge the counts back into the dataset*/
DATA CONTROL_ID;MERGE CONTROL_ID N_CONTROL;BY STUDY_&IDVA.;RUN;
/*now order the rows to select the first matching control*/
PROC SORT DATA=CONTROL_ID;BY CONTROL_&IDVA. NUM_CONTROLS RAND_NUM;RUN;
DATA CONTROL_ID;SET CONTROL_ID;BY CONTROL_&IDVA.;IF FIRST.CONTROL_&IDVA.;RUN;
/*select size = &n control samples*/
PROC SORT DATA=CONTROL_ID;BY STUDY_&IDVA. RAND_NUM;RUN;
DATA CONTROL_ID2 NOT_ENOUGH&J.;SET CONTROL_ID;BY STUDY_&IDVA.;RETAIN NUM;
IF FIRST.STUDY_&IDVA. THEN NUM=1;IF NUM LE &N. THEN DO;OUTPUT CONTROL_ID2;NUM=NUM+1;END;
IF LAST.STUDY_&IDVA. THEN DO;IF NUM LE &N. THEN OUTPUT NOT_ENOUGH&J.;END;RUN;
DATA MATCH_ID&J.;MERGE CONTROL_ID2 NOT_ENOUGH&J.(IN=A);BY STUDY_&IDVA.;IF A THEN DELETE;RUN;

DATA TEMP_S;SET MATCH_ID&J.;
PROC SORT DATA=TEMP_S NODUPKEY;BY STUDY_&IDVA.;RUN;
PROC SORT DATA=STUDY ;BY &IDVA.;
DATA STUDY;MERGE STUDY TEMP_S(IN=A RENAME=(STUDY_&IDVA.=&IDVA.));BY &IDVA.;IF NOT A;RUN;
DATA TEMP_C;SET MATCH_ID&J.;
PROC SORT DATA=TEMP_C NODUPKEY;BY CONTROL_&IDVA.;RUN;
PROC SORT DATA=CONTROL; BY &IDVA.;
DATA CONTROL;MERGE CONTROL TEMP_C(IN=A RENAME=(CONTROL_&IDVA.=&IDVA.));BY &IDVA.;IF NOT A;RUN;

PROC CONTENTS DATA=MATCH_ID&J. OUT=N_LEFT(KEEP=NOBS) NOPRINT;RUN;
DATA N_LEFT;SET N_LEFT(OBS=1); CALL SYMPUT('M',NOBS); RUN;
DATA &OUTDATA.;SET &OUTDATA. MATCH_ID&J.;RUN;
%IF &M. =0 %THEN %RETURN;
%END;
%MEND;
%M;
/**********************整理配對後的資料***************************/
%MACRO TREAT;
%DO I=1 %TO &NVAR.;
%LET V&I.=%SCAN(&MVARS.,&I.,' ');
%END;
*整理配對後實驗組資料;
DATA S;SET &OUTDATA.;KEEP STUDY_&IDVA.
%DO I=1 %TO &NVAR.;
STUDY_&&V&I.
%END;&INDEX.;&INDEX.=1;
PROC SORT DATA=S NODUPKEY;BY STUDY_&IDVA.;RUN;
DATA S;SET S ;RENAME STUDY_&IDVA.=&IDVA.
%DO I=1 %TO &NVAR.;
STUDY_&&V&I. =&&V&I.
%END;;
*整理配對後對照組資料;
DATA C;SET &OUTDATA.;KEEP CONTROL_&IDVA.
%DO I=1 %TO &NVAR.;
CONTROL_&&V&I.
%END;&INDEX.;&INDEX.=0;
PROC SORT DATA=C NODUPKEY;BY CONTROL_&IDVA.;RUN;
DATA C;SET C ;RENAME CONTROL_&IDVA.=&IDVA.
%DO I=1 %TO &NVAR.;
CONTROL_&&V&I. =&&V&I.
%END;;
*合併整理後的實驗對照組資料;
DATA &FINAL.;SET S C;RUN;
%MEND;
%TREAT;


/*CCI分析程式*/
data a1(keep= id icd); set mylib.cddd2000_2011(rename=(icd9cm_1=icd));
data a2(keep= id icd); set mylib.cddd2000_2011(rename=(icd9cm_2=icd));
data a3(keep= id icd); set mylib.cddd2000_2011(rename=(icd9cm_3=icd));
data a4(keep= id icd); set mylib.cddd2000_2011(rename=(icd9cm_4=icd));
data a5(keep= id icd); set mylib.cddd2000_2011(rename=(icd9cm_5=icd));
data a6; set a1 a2 a3 a4 a5; run; 
data a7; set a6;
if substr(icd,1,3) in ('140','141','142','143','144','145','146','147','148','149','150','151','152','153','154','155','156','157','158','159','160','161','162','163','164','165',
'166','167','168','169','170','171','172','173','174','175','176','177','178','179','180','181','182','183','184','185','186','187','188','189','190','191','192','193','194','195','196','197',
'198','199','200','201','202','203','204','205','206','207','208') then delete; 
if substr(icd,1,5) in ('32723','78051','78053','78057',
'30746','30747','30748','30749','30741','30742','78052') then delete; 
RUN; 
data bb;
         set a7;
               if substr(icd,1,3) in ('410','412') then do;grp=1;score=1;end;/*心肌梗塞*/
               if substr(icd,1,3) in ('428') then do;grp=2;score=1;end;/*鬱血性心衰*/
               if substr(icd,1,3) in ('441') then do;grp=3;score=1;end;/*周邊血管疾病*/
               if substr(icd,1,4) in ('4439','7854','V434','3848') then do;grp=3;score=1;end;
               if substr(icd,1,3) in ('430','431','432','433','434','435','436','437','438') then do;grp=4;score=1;end;/*腦血管疾病*/
               if substr(icd,1,3) in ('290') then do;grp=5;score=1;end;/*失智症*/
               if substr(icd,1,3) in ('490','491','492','493','494','495','496','500','501','502','503','504','505') then do; grp=6;score=1;end;/*失智症*/
               if substr(icd,1,4) in ('5064') then do;grp=6;score=1;end;
               if substr(icd,1,3) in ('725') then do;grp=7;score=1;end;/*風濕病*/
               if substr(icd,1,4) in ('7100','7101','7104','7140','7141','7142') then do;grp=7;score=1;end;
               if substr(icd,1,5) in ('71481') then do;grp=7;score=1;end;
               if substr(icd,1,3) in ('531','532','533','534') then do;grp=8;score=1;end;/*消化道潰瘍*/
               if substr(icd,1,4) in ('5712','5714','5715','5716') then do;grp=9;score=1;end;/*輕微肝臟疾病*/
               if substr(icd,1,4) in ('2500','2503','2507') then do; grp=10;score=1;end;/*糖尿病*/
               if substr(icd,1,4) in ('2504','2505','2506') then do;grp=11;score=2;end;/*伴隨慢性病發症之糖尿病*/
               if substr(icd,1,3) in ('342') then do;grp=12;score=2;end;/*半身或下半身麻痺*/
               if substr(icd,1,4) in ('3441') then do;grp=12;score=2;end;
               if substr(icd,1,3) in ('582','585','586','588') then do;grp=13;score=2;end;/*腎臟疾病*/
               if substr(icd,1,4) in ('5830','5831','5832','5833','5834','5835','5836','5837') then do;grp=13;score=2;end;
               if substr(icd,1,3) in ('140','141','142','143','144','145','146','147','148','149','150','151','152','153','154','155','156','157','158','159',
                                                '160','161','162','163','164','165','166','167','168','169','170','171','172','174','175','176','177','178','179',
                                                '180','181','182','183','184','185','186','187','188','189','190','191','192','193','194','195','200','201','202',
                                                '203','204','205','206','207','208') then do;grp=14;score=2;end;
               if substr(icd,1,4) in ('A08','a08','A090','a090','A091','a091','A092','a092','A093','a093','A094','a094','A095','a095','A096','a096',
                                             'A100','a100','A101','a101','A110','a110','A111','a111','A112','a112','A113','a113','A120','a120',
                                             'A121','a121','A122','a122','A123','a123','A124','a124','A125','a125','A126','a126','A130','a130',
                                             'A140','a140','A141','a141') then do;grp=14;score=2;end;
            /*惡性腫瘤含白血病及淋巴癌*/
               if substr(icd,1,4) in ('5722','5723','5724','5728') then do;grp=15;score=3;end;/*中度或重度肝臟疾病*/
              /* if substr(icd,1,3) in ('196','197','198','199') then do;grp=16;score=6;end;/*轉移性腫瘤*/
               if substr(icd,1,3) in ('042','043','044') then do;grp=16;score=6;end;/*愛滋病*/
      if grp=. then delete;
proc freq data=bb;
               tables score grp;
run; 
proc sort data=bb;
         by id grp;
data bb1;
         set bb;
               by id grp;
if (first.id=1 and  first.grp=1) or  (first.id=0 and first.grp=1);
    x=1;
run;
proc sort data =bb1;
          by id grp score;
proc transpose data=bb1 out=bb2;
         var score;
   by id ;
   id grp;
run; 
data C_CCI(drop=_name_);
         retain id _1-_16;
         set bb2;
        if _9 ne . and _15 ne . then do;_9=.;end; /*肝病取較嚴重的*/
     if _10 ne . and _11 ne . then do; _10=.;end;/*糖尿病取較嚴重的*/ 
/* if _14 ne . and _16 ne . then do; _14=.;end;/*惡性腫癌取較嚴重的*/
        cci=sum(of _1-_16);
         run;
data mylib.CCI_3sleep; set C_CCI(keep=id cci); run; 

*merge cci 

*OO DO GO;
dm 'log;clear;output;clear;';
%macro alpha(year);
%do year = 89 %to 100;

%macro beta(month,month1);
PROC SQL; 
create table CD as select * from CD.H_nhi_opdte&year.&month._10 where ID in (select ID from output.cddd_final);
QUIT;

PROC SQL;
create table gp&month1 as
select a.ID,a.FEE_YM,a.APPL_TYPE,a.HOSP_ID,a.APPL_DATE,a.CASE_TYPE,a.SEQ_NO,a.FUNC_DATE,
         input(FUNC_DATE,yymmdd8.) as DrugDate,a.DRUG_DAY,b.DRUG_NO,b.DRUG_USE,b.TOTAL_Q
from CD as a,OO.H_nhi_opdto&year.&month._10 as b
where a.FEE_YM=b.FEE_YM
         and a.APPL_TYPE=b.APPL_TYPE
         and a.HOSP_ID=b.HOSP_ID
         and a.APPL_DATE=b.APPL_DATE
         and a.CASE_TYPE=b.CASE_TYPE
         and a.SEQ_NO=b.SEQ_NO
         and b.DRUG_NO in (select DRUG_NO from Druguse.lipiddruglist);
QUIT;
%mend;
%beta(01,1) %beta(02,2) %beta(03,3) %beta(04,4) %beta(05,5) %beta(06,6)
%beta(07,7) %beta(08,8) %beta(09,9) %beta(10,10) %beta(11,11) %beta(12,12)

data OO.lipidDrugOO&year;set alpha1 - alpha12;run;
%end;
%mend;
option mprint;
%alpha;


data lipidDrugOO;set lipidDrugOO89 - lipidDrugOO100;run;

*DO;
dm 'log;clear;output;clear;';
%macro spring(year);
%do year = 89 %to 100;
PROC SQL;
create table DD as select * from DD.H_nhi_ipdte&year where ID in (select ID from output.cddd_final);
QUIT;

%macro summer(month,month1);
PROC SQL;
create table one&month1 as
select a.ID,a.FEE_YM,a.APPL_TYPE,a.HOSP_ID,a.APPL_DATE,a.CASE_TYPE,a.SEQ_NO,a.IN_DATE,a.OUT_DATE,
         a.APPL_BEG_DATE,a.APPL_END_DATE,a.E_BED_DAY,a.S_BED_DAY,
         b.ORDER_CODE as DRUG_NO,b.ORDER_Q as TOTAL_Q
from DD as a,DO.H_nhi_ipdto&year.&month as b
where a.FEE_YM=b.FEE_YM
         and a.APPL_TYPE=b.APPL_TYPE
         and a.HOSP_ID=b.HOSP_ID
         and a.APPL_DATE=b.APPL_DATE
         and a.CASE_TYPE=b.CASE_TYPE
         and a.SEQ_NO=b.SEQ_NO
         and DRUG_NO in (select DRUG_NO from Druglist.lipiddruglist);
QUIT;
%mend;
%summer(01,1) %summer(02,2) %summer(03,3) %summer(04,4) %summer(05,5) %summer(06,6)
%summer(07,7) %summer(08,8) %summer(09,9) %summer(10,10) %summer(11,11) %summer(12,12)

data Order.lipidDrugDO&year;set one1 - one12;run; 
%end;
%mend;
option mprint;
%spring;

*GO;
%macro spring(year);
%do year = 89 %to 100;

%macro summer(month,month1);
PROC SQL;
create table GD as select * from GD.H_nhi_druge&year.&month where ID in (select ID from output.cddd_final);
QUIT;

PROC SQL;
create table one&month1 as
select a.ID,a.FEE_YM,a.APPL_TYPE,a.HOSP_ID,a.APPL_DATE,a.CASE_TYPE,a.SEQ_NO,a.DRUG_DATE,
         input(DRUG_DATE,yymmdd8.) as DrugDate,a.DRUG_DAY,b.DRUG_NO,b.DRUG_USE,b.TOTAL_Q
from GD as a,GO.H_nhi_drugo&year.&month as b
where a.FEE_YM=b.FEE_YM
         and a.APPL_TYPE=b.APPL_TYPE
         and a.HOSP_ID=b.HOSP_ID
         and a.APPL_DATE=b.APPL_DATE
         and a.CASE_TYPE=b.CASE_TYPE
         and a.SEQ_NO=b.SEQ_NO
         and b.DRUG_NO in (select DRUG_NO from Druglist.lipiddruglist);
QUIT;
%mend;
%summer(01,1) %summer(02,2) %summer(03,3) %summer(04,4) %summer(05,5) %summer(06,6)
%summer(07,7) %summer(08,8) %summer(09,9) %summer(10,10) %summer(11,11) %summer(12,12)

data Order.lipidDrugGO&year;set one1 - one12;run;
%end;
%mend;
option mprint;
%spring;

data lipidDrugGO;set lipidDrugGO89 - lipidDrugGO100;run;

data output.lipid_medication; set lipidDrugOO lipidDrugDO lipidDrugGO;run;

proc sort data=id.id_city_all;by id;
data output.cohort_analyze; merge
