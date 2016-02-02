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

*Select lipid population: *Outpatients(門急診);
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
proc sort data=output.Death out=output.Death1 (keep=ID D_DATE) nodupkey;by ID;run;
proc sort data=id.id_birth;by ID  ;
run;
proc sort data=id.id_inout;by ID ;
run;
proc sort data=id.id_sex;by ID ;
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
data t;set rd_case; if sex=. then output;run;
data rd_case1; set rd_case; if sex=. then delete;run;*631;
data output.rd_case1(keep=id age sex match_year1 rd); set rd_case1; 
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
data t;set rd_control; if sex=. then output;run;*10410 cases no sex info;
data rd_control1; set rd_control; if sex=. then delete;run;*2532004;
data output.rd_control1(keep=id age sex match_year1 rd); set rd_control1; 
match_year1=match_year+0; run; 

data output.match; set output.rd_control1 output.rd_case1;run;
data output.match_p;set output.match;run;

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
%LET STUDY=output.rd_case1;
%LET CONTROL=output.rd_control1;
%LET N1=MAX;
%LET N2=MAX;
%LET NN=20;
%LET OUTDATA=output.match_ID;
%LET IDVA=ID;
%LET MVARS=age sex match_year1;
%LET DMAK=2 0 0;
%LET N=20;
%LET INDEX=rd;
%LET FINAL=output.FINAL_ID;
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

*case;
data rd_match_1; set output.match_id; mark=1; run;
proc sort data=rd_match_1(rename=(study_id=id)); by id;
proc sort data=rd_match_1(keep=id mark); by id;
proc sort data=rd_case1; by id;
data match_case1; merge rd_case1(in=k) rd_match_1; by id; if k=1 then output;run;
data match_case11(drop=mark);set match_case1; if mark=1 then output;run;
proc sort data=match_case11; by id;
data match_case111; set match_case11;by id;if first.id then output;run;


*control;
data rd_match_2; set output.match_id; mark=1; run;
proc sort data=rd_match_2(rename=(control_id=id)); by id;
proc sort data=rd_match_2(keep=id mark); by id;
proc sort data=rd_control1; by id;
data match_control1; merge rd_control1(in=k) rd_match_2; by id; if k=1 then output;run;
data match_control11(drop=mark);set match_control1; if mark=1 then output;run;
proc sort data=match_control11; by id;
data match_control111; set match_control11;by id;if first.id then output;run;

data output.match_rd_final;set match_case111 match_control111; run;

*CCI;

/*CCI分析程式*/
data a1(keep= id icd); set OUTPUT.cddd_final(rename=(icd9cm_1=icd));
data a2(keep= id icd); set OUTPUT.cddd_final(rename=(icd9cm_2=icd));
data a3(keep= id icd); set OUTPUT.cddd_final(rename=(icd9cm_3=icd));
data a4(keep= id icd); set OUTPUT.cddd_final(rename=(icd9cm_4=icd));
data a5(keep= id icd); set OUTPUT.cddd_final(rename=(icd9cm_5=icd));
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
data output.CCI;set C_CCI(keep=id cci); run; 

/*把 cci mark回id主檔案*/
proc sort data=output.match_rd_final; by id;
proc sort data=output.CCI; by id ;
data output.match_rd_cci; merge output.match_rd_final(in=k) 
output.CCI(keep=id cci); by id;
if cci=' ' then cci=0;
if k=1 then output; run; 

proc print data=OO8901(obs=100);run;

*OO DO GO;
*OO;
*Hyperlipidemia drug;
dm 'log;clear;output;clear;';
%macro alpha(year);
%do year = 89 %to 100;

%macro beta(month,month1);
PROC SQL; 
create table CD as select * from CD.H_nhi_opdte&year.&month._10 where ID in (select ID from output.match_rd_cci);
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

data OO.lipidDrugOO&year;set gp1 - gp12;run;
%end;
%mend;
option mprint;
%alpha;
data OO.lipidDrugOO100;set gp1 - gp12;run;

data output.lipidDrugOO;set oo.lipidDrugOO89 - oo.lipidDrugOO100;run;
data t; set oo.lipidDrugOO100;
drug_use1=substr(drug_use, 1,6);
run;
proc sort data=t(drop=drug_use);by id; run;
data oo.lipidDrugOO100;set t;
rename drug_use1=drug_use;
run;

*DO;
*Hyperlipidemia drug;
dm 'log;clear;output;clear;';
%macro spring(year);
%do year = 89 %to 100;
PROC SQL;
create table DD as select * from DD.H_nhi_ipdte&year where ID in (select ID from output.match_rd_cci);
QUIT;

%macro summer(month,month1);
PROC SQL;
create table one&month1 as
select a.ID,a.FEE_YM,a.APPL_TYPE,a.HOSP_ID,a.APPL_DATE,a.CASE_TYPE,a.SEQ_NO,a.IN_DATE,a.OUT_DATE,
         a.APPL_BEG_DATE,a.APPL_END_DATE,
         b.ORDER_CODE as DRUG_NO,b.ORDER_Q as TOTAL_Q
from DD as a,DO.H_nhi_ipdto&year.&month as b
where a.FEE_YM=b.FEE_YM
         and a.APPL_TYPE=b.APPL_TYPE
         and a.HOSP_ID=b.HOSP_ID
         and a.APPL_DATE=b.APPL_DATE
         and a.CASE_TYPE=b.CASE_TYPE
         and a.SEQ_NO=b.SEQ_NO
         and DRUG_NO in (select DRUG_NO from Druguse.lipiddruglist);
QUIT;
%mend;
%summer(01,1) %summer(02,2) %summer(03,3) %summer(04,4) %summer(05,5) %summer(06,6)
%summer(07,7) %summer(08,8) %summer(09,9) %summer(10,10) %summer(11,11) %summer(12,12)

data DO.lipidDrugDO&year;set one1 - one12;run; 
%end;
%mend;
option mprint;
%spring;

proc sort data=do.lipidDrugDO89 (drop=E_BED DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO90 (drop=E_BED DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO91 (drop=E_BED DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO92 (drop=E_BED DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO93 (drop=E_BED_DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO94 (drop=E_BED_DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO95 (drop=E_BED_DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO96 (drop=E_BED_DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO97 (drop=E_BED_DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO98 (drop=E_BED_DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO99 (drop=E_BED_DAY S_BED_DAY);by id;
proc sort data=do.lipidDrugDO100 (drop=E_BED_DAY S_BED_DAY);by id;
data output.lipidDrugDO;set do.lipidDrugDO89 - do.lipidDrugDO100;run;

*GO;
*lipid drug;
%macro spring(year);
%do year = 89 %to 100;

%macro summer(month,month1);
PROC SQL;
create table GD as select * from GD.H_nhi_druge&year.&month where ID in (select ID from output.match_rd_cci);
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
         and b.DRUG_NO in (select DRUG_NO from Druguse.lipiddruglist);
QUIT;
%mend;
%summer(01,1) %summer(02,2) %summer(03,3) %summer(04,4) %summer(05,5) %summer(06,6)
%summer(07,7) %summer(08,8) %summer(09,9) %summer(10,10) %summer(11,11) %summer(12,12)

data GO.lipidDrugGO&year;set one1 - one12;run;
%end;
%mend;
option mprint;
%spring;

data output.lipidDrugGO;set go.lipidDrugGO89 - go.lipidDrugGO100;run;

data output.medication; set output.lipidDrugGO output.lipidDrugOO output.lipidDrugDO;run;
proc sort data=output.match_rd_cci;by id;
proc sort data=output.medication;by id;

data output.match_rd_cci_m; 
merge output.match_rd_cci(in=k) output.medication; 
by id; if k=1 then output;run;
proc sort data=output.match_rd_cci_m(drop=E_BED_DAY S_BED_DAY);by id;run;

proc sort data=id.id_city89;by ID;
proc sort data=id.id_city91;by ID;
proc sort data=id.id_city92;by ID;
proc sort data=id.id_city93;by ID;
proc sort data=id.id_city94;by ID;
proc sort data=id.id_city95;by ID;
proc sort data=id.id_city96;by ID;
proc sort data=id.id_city97;by ID;
proc sort data=id.id_city98;by ID;
proc sort data=id.id_city99;by ID;
proc sort data=id.id_city100;by ID;run;

data id.id_city_all; 
set id.id_city89-id.id_city100;
run;

proc sort data=id.id_city_all;by ID;run;
data  OUTPUT.cohort_analyze;
        merge output.match_rd_cci_m(in=k)
		           id.id_city_all;
		by ID ;if k=1;
		run;
proc sort data=OUTPUT.cohort_analyze;by rd;run;
data t; set OUTPUT.cohort_analyze;by rd; run;

/*Table1*/
DATA cohort_analyze; SET OUTPUT.cohort_analyze;
IF age <45 THEN age_1=1; else
IF 45<=age<65 THEN age_1=2; else
IF age>=65 THEN age_1=3;

if id_s=2 THEN sex1=0; else
if id_s=1 THEN sex1=1;

IF ID1_CITY in ('0101','0117','0102','0110','0118','0109','0119', '0120',
'0112','0111','0100','0115','0116','1101','1104','1106','1107', '1102','1103','1105', '1100',
'1201','1204','1205','1200','3100','3101','3102','3103','3104','3106','3114','3105','3110',
'3111','3118','3107','3108','3109','3112','3113','3115','3116','3117','3119','3120','3121',
'3122','3123','3124','3125','3126','3127','3128','3129','3200','3201','3202','3208','3210', 
'3203','3204','3205','3206','3207','3209','3211','3212','3213','3300','3303','3305','3306',
'3308','3301','3302','3307','3309','3310','3311','3312','3313','3314','3400','3401','3402',
'3403','3404','3405','3406','3407','3408','3409','3410','3411','3412') THEN region=1;
ELSE IF ID1_CITY in ('105', '106', '103', '104', '114', '115', '111', '112', '110', '100', 
'108', '116', '202', '206', '205', '200', '203', '204', '201', '300', '220', '241', '234', '235', 
'231', '242', '238', '239', '237', '251', '221', '224', '236', '247', '248', '243', '244', '222', 
'223','232', '252', '253', '249', '226', '227', '228', '208', '207', '233', '330', '320', '335', 
'326','338', '337', '333', '334', '325', '324', '327', '328', '336', '306', '305', '310', '302', 
'303', '312', '304', '307', '308', '314', '315', '313', '311', '260', '265', '270', '261', '262', 
'263', '264', '269', '268', '266', '267', '272') THEN region=1;
ELSE IF ID1_CITY in ('3500','3501','3504','3505','3502','3503','3506','3509','3510','3512',
'3513','3515','3507','3508','3511','3514','3516','3517','3518','1700','1701','1703','1704',
'1705','1702','1706','1707','1708','3600','3601','3619','3620','3603','3604','3605','3606',
'3608','3609','3610','3612','3615','3616','3617','3618','3602','3607','3611','3613','3614',
'3621','3700','3701','3702','3703','3704','3710','3713','3715','3705','3706','3707','3709',
'3711','3712','3714','3717','3719','3708','3716','3718','3720','3721','3722','3723','3724',
'3725','3726','3800','3802','3803','3804','3805','3806','3807','3808','3809','3810','3811',
'3812','3813','3801','3900','3901','3902','3903','3904','3906','3905','3907','3908','3909',
'3910','3911','3912','3913','3914','3915','3916','3917','3918','3919','3920') THEN region=2;
ELSE IF ID1_CITY in ('360', '358', '357', '350', '351', '356', '369', '364', '363', '366',
'353', '362', '367', '368', '361', '352', '354', '365', '400', '401', '403', '402', '404', '407',
'408', '406', '420', '423', '437', '436', '433', '435', '421', '429', '427', '428', '426', '422', 
'438', '439', '414', '432', '434', '413', '411', '412', '424', '500', '505', '508', '521', '510', 
'514', '520', '526', '507', '509', '506', '504', '503', '502', '515', '516', '513', '512', '511',
'530', '522', '523', '528', '527', '525', '524', '540', '545', '542', '557', '552', '551', '558', 
'541', '555', '544', '553', '556', '546', '640', '630', '632', '648', '633', '651', '646', '631', 
'647', '643', '649', '637', '638', '635', '634', '636', '655', '654', '653', '652') THEN region=2;
ELSE IF ID1_CITY in ('4500','4501','4502','4503','4504','4505','4506','4507','4508','4509',
'4510','4511','4512','4513','4600','4601','4602','4603','4604','4605','4606','4607','4608',
'4609','4610','4611','4612','4613','4614','4615','4616','9000','9001','9002','9003','9004',
'9005','9006','9100','9101','9102','9103','9104') THEN region=4;
ELSE IF ID1_CITY in ('970', '975', '981', '971', '973', '974', '976', '977', '978', '983', 
'972', '979', '982', '950', '961', '956', '954', '965', '963', '959', '962', '955', '958', '951', 
'953', '957', '966', '964', '952', '893', '890', '891', '892', '894', '896', '209', '210', '211',
'212' ) THEN region=4;
ELSE region=3; 

IF ID1_CITY in ('0101','0117','0102','0110','0118','0109','0119','1101','1104','1106',
'1107','3101','3102','3103','3104','3106','3114','3201','3202','3208','3210','3303','3305',
'3306','3308','1201','1204','1205','3401','3402','3501','3504','3505','1701','1703','1704','
1705','3601','3619','3620','3701','3702','3703','3704','3710','3713','3715','3801','3802',
'3803','2101','2103','2104','2105','2108','2201','2202','3901','3902','3903','3904','3906',
'4001','4003','4004','4011','4012','4101','4120','4127','4128','4131','0201','0205','0206',
'0207','0208','4201','4301','4401','4501','4601') THEN areagp=1;
ELSE IF ID1_CITY in ('105', '110', '106', '104', '100', '103', '108', '202', '200', '204', 
'201', '220', '241', '234', '235', '242', '247', '330', '320', '334', '324', '310', '302', '303', 
'304', '300', '260', '265', '360', '350', '351', '400', '403', '402', '404', '420', '411', '412', 
'500', '505', '508', '521', '509', '503', '515', '540', '545', '542', '701', '704', '700', '600', 
'640', '630', '632', '648', '651', '613', '622', '621', '612', '608', '730', '744', '717', '711', 
'710', '803', '807', '800', '801', '802', '830', '900', '880', '970', '950') THEN areagp=1;
ELSE IF ID1_CITY in ('0120','0112','0111','0115','0116','1102','1103','1105','3105',
'3110','3111','3118','3203','3204','3205','3206','3207','3209','3211','3212','3213','3301',
'3302','3307','3309','3310','3311','3312','3313','3314','3403','3404','3405','3406','3407',
'3408','3409','3410','3411','3412','3502','3503','3506','3509','3510','3512','3513','3515',
'1702','1706','1707','1708','3603','3604','3605','3606','3608','3609','3610','3612','3615',
'3616','3617','3618','3705','3706','3707','3709','3711','3712','3714','3717','3719','3804',
'3805','3806','3807','3808','3809','3810','3811','3812','3813','2102','2106','2107','3905',
'3907','3908','3909','3910','3911','3912','3913','3914','3915','3916','3917','3918','3919',
'3920','4002','4005','4006','4007','4008','4009','4010','4013','4014','4015','4016','4017',
'4018','4102','4104','4105','4106','4107','4108','4109','4113','4114','4116','4121','4129',
'0202','0203','0204','0209','0210','0211','4202','4205','4206','4207','4208','4209','4210',
'4211','4215','4216','4217','4219','4220','4302','4303','4304','4307','4309','4311','4313',
'4315','4321','4323','4324','4327','4332','4333','4402','4403','4404','4405','4406','4502',
'4503','4504','4505','4506','4507','4508','4509','4510','4511','4512','4513','4602','4603',
'4604','4605','4606','4607','4608','4609','4610','4611','4612','4613','4614','4615','4616') 
THEN areagp=2;
ELSE IF ID1_CITY in ('116', '115', '114', '111', '112', '206', '205', '203', '231', '251', 
'221', '222', '335', '326', '338', '337', '333', '325', '327', '328', '336', '306', '305', '312', 
'307', '308', '314', '315', '313', '311', '270', '261', '262', '263', '264', '266', '267', '268', 
'269', '272', '358', '357', '356', '363', '366', '362', '367', '361', '401', '407', '408', '406', 
'437', '436', '433', '435', '429', '427', '428', '422', '414', '432', '434', '413', '510', '514', 
'520', '507', '506', '504', '502', '513', '511', '557', '552', '551', '558', '541', '555', '544', 
'553', '556', '546', '702', '709', '708', '633', '646', '631', '647', '643', '649', '637', '638', 
'635', '634', '636', '655', '654', '653', '652', '625', '623', '616', '615', '614', '624', '611', 
'606', '604', '603', '602', '607', '605', '737', '721', '722', '712', '741', '726', '736', '734', 
'720', '723', '745', '718', '804', '813', '811', '806', '805', '812', '820', '832', '831', '840', 
'814', '815', '833','825', '821', '829', '852', '827', '826', '920', '928', '946', '909', '905', 
'906', '912', '925', '931', '944', '947', '902', '943', '945', '885', '884', '881', '882', '883', 
'975', '981', '971', '973', '974', '976', '977', '978', '983', '972', '979', '982', '961', '963', 
'954', '965', '956', '959', '962', '955', '958', '951', '953', '957', '966', '964', '952') 
THEN areagp=2;
ELSE areagp=3; 
If cci<3 then cci_1=0;
else cci_1=1; run;*145582;
proc sort data=cohort_analyze; by id;
data cohort_analyze_final; set cohort_analyze;by id; if first.id then output;run;


proc freq data=cohort_analyze_final; tables age_1*rd/chisq;run;
proc freq data=cohort_analyze_final; tables sex1*rd/chisq;run;
proc freq data=cohort_analyze_final; tables region*rd/chisq;run;
proc freq data=cohort_analyze_final; tables areagp*rd/chisq;run;
proc freq data=cohort_analyze_final; tables cci_1*rd/chisq;run;
proc freq data=cohort_analyze_final; tables drug_no*rd/chisq;run;
proc freq data=cohort_analyze_final; tables rd*raod rd*rvod rd*raod2 rd*rvod2/chisq;run;

*Table A;
data t1;set cohort_analyze_final;
if rd=1 then output;
run;
proc freq data=t1; tables age_1*sex1/chisq;run;

data a; set cohort_analyze_final;
if drug_no in ("A006865100", "A027035100", "A027676100","A030590100","A031807100",
"A031954100","A033733100", "A042585100", "AC32833100", "AC37685100", "AC41837100",
"AC42244100") then type=1;
else if drug_no in ("A015354343", "A017711212", "A024519343", "A024620212", "A024620221",
"A028315500", "A033520329") then type=2;
else if drug_no in ("A019102100", "A019636100", "A035154100", "A035154100") then type=3;
else if drug_no in ("A042389100", "A043887100", "A046022100", "A048608100", "AB49143100",
"AB49503100", "AC39403100", "AC44998100", "AC47775100", "AC47924100", "AC47928100",
"AC48684100", "AC49190100", "AC50086100", "AC51598100", "AC55952100") then type=4;
run;
proc freq data=a; tables rd*type*age_1/chisq;run;
proc freq data=a; tables rd*marriage/chisq;run;

data a1 ;set a;
marriage1=marriage*1;run;

proc logistic data=a1;
model rd=cci_1 age_1 type sex1 region areagp;
run;

proc contents data=a; run;

data b; set a1;
if age_1=1 then output;run;
proc freq data=b; tables rd*type/chisq;run;

*2016/1/22 Table 3;
*C10AB. Fibrates;
data a1; set a;
if type=2 or type=3 or type=4 then type=0;run;

proc logistic data=a1;
model rd=type;
run;

proc logistic data=a1;
model rd=cci_1 age_1 type sex1 region areagp;
run;

*VitE;
data a2; set a;
if type=1 or type=3 or type=4 then type=0;run;

proc logistic data=a2;
model rd=type;
run;

proc logistic data=a2;
model rd=cci_1 age_1 type sex1 region areagp;
run;

*Nicotinic acid and derivatives;
data a3; set a;
if type=2 or type=1 or type=4 then type=0;run;

proc logistic data=a3;
model rd=type;
run;

proc logistic data=a3;
model rd=cci_1 age_1 type sex1 region areagp;
run;

*HMG-CoA Reducatase Inhibitors;
data a4; set a;
if type=2 or type=3 or type=1 then type=0;run;

proc logistic data=a4;
model rd=type;
run;

proc logistic data=a4;
model rd=cci_1 age_1 type sex1 region areagp;
run;

*Table 5;
data aa; set a;
if age_1=3 then output;run;

*C10AB. Fibrates;
data a1; set aa;
if type=2 or type=3 or type=4 then type=0;run;

proc logistic data=a1;
model rd=type;
run;

proc logistic data=a1;
model rd=cci_1 age_1 type sex1 region areagp;
run;

*VitE;
data a2; set aa;
if type=1 or type=3 or type=4 then type=0;run;

proc logistic data=a2;
model rd=type;
run;

proc logistic data=a2;
model rd=cci_1 age_1 type sex1 region areagp;
run;

*Nicotinic acid and derivatives;
data a3; set aa;
if type=2 or type=1 or type=4 then type=0;run;

proc logistic data=a3;
model rd=type;
run;

proc logistic data=a3;
model rd=cci_1 age_1 type sex1 region areagp;
run;

*HMG-CoA Reducatase Inhibitors;
data a4; set aa;
if type=2 or type=3 or type=1 then type=0;run;

proc logistic data=a4;
model rd=type;
run;

proc logistic data=a4;
model rd=cci_1 age_1 type sex1 region areagp;
run;


*Table 4 DDD;
