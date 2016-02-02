********************************************************
| Control selection for nested case-control study      |
| Name: htuhdrc_02_control match.sas                                  |
| Date of first created : 2000-7-9                     |
| Date of last modified:  2000-7-10                    |
| Author: Jasmine Pwu                                  |
| Description:                                         |
|   This program is for control selection in nested    |
|   case control study.  The selected dataset is       |
|   from Dr. K A Chan.  The key points for this        |
|   program include:                                   |
|   1. For each "Case"(pub=1) from the original        |
|      dataset, we must find her candidate controls.   |
|   2. The control criteria: same "HMO" and age +/- 2  |
|   3. Controls should be at risk when Case disease    |
|      occurs. - enddate(cn)>enddate(cs) &             |
|                startdate(cn) <enddate(cs)            |       
|   4. The number of controls : 10                     |
|   5. The way of selecting controls: Randomly         |
********************************************************;

libname nest 'c:\work\nested';
option nodate;

*----------------------------------------------------*
*  First we pick out the Cases and assign a pair
*   number (1001, 1002, ...) for each of them.
*  For cases also have the possibility to be served as
*   other cases' controls, a new identifier should be
*   created.
*----------------------------------------------------*;

data pub_cs;
  set nest.pub_cscn;
  if pub=1;

data pub_cs;
  set pub_cs;
  if _n_<10 then
   pair = '100'||left(put(_n_,3.));
  else if _n_<100 then
   pair = '10'||left(put(_n_,3.));
  else pair = '1'||left(put(_n_,3.));
  cscn=1;                               /* Assign new case/control status */

        *----------------------------------------------------*
        *  For validation
        *----------------------------------------------------*;
proc print data=pub_cs noobs split='*';
  var pair sdyid mbdob hmo startd endd;
  format mbdob year. startd endd yymmdd10. ;
  label pair     = 'Pair    *_________'
        sdyid    = 'ID      *_________'
        MBDOB    = 'Year of *Birth   *_________'
        HMO      = 'HMO     *_________'
        STARTD   = 'Start   *Date    *_________'
        ENDD     = 'End     *Date    *_________'
        ;
title 'Case list ';
title2 'First method - randomly selection';
run;


%macro PICK;

      *----------------------------------------------------*
      *  First, Macro PICK will extract information from
      *  PUB_CS one record a time, to pass to next DATA
      *  procedure in order to choose eligible controls
      *  from PUB_CSCN
      *----------------------------------------------------*;
data _null_;
  set pub_cs end=eof;

  length hmoname dobname idname noname $8;
  retain ctr 0;
  ctr+1;
  hmoname ='HMO'||left(put(ctr,3.));      /* Build macro variable name of the form HMOn. */
  dobname ='DOB'||left(put(ctr,3.));
  doename ='DOE'||left(put(ctr,3.));
  dosname ='DOS'||left(put(ctr,3.));
  idname  ='ID' ||left(put(ctr,3.));
  noname  ='NO' ||left(put(ctr,3.));
  pairname='PAIR'||left(put(ctr,3.));

  call symput(hmoname, HMO);              /* Put HMO into macro var HMONAME */
  call symput(dobname, MBDOB);
  call symput(doename, ENDD);
  call symput(dosname, STARTD);    
  call symput(idname, SDYID);
  call symput(pairname, PAIR);

  if eof then call symput("totalcs", left(put(ctr,3.)));  /* Get total # of cases */

run;

      *----------------------------------------------------*
      *  Second, Macro PICK will use the above macro var
      *  to determine which records to be the eligible
      *  controls.  Then every eligible control would be
      *  assigned a uniform-distrbuted random number
      *  (between 0-1).  To pick out 10 of them, we sort
      *  the data by random number and keep first 10.
      *----------------------------------------------------*;


%do ctr = 1 %to &totalcs;               /* Do # times */
  data no&ctr.;                         /* Data no1, no2, ... */
    set nest.pub_cscn;

    if  HMO="&&HMO&ctr.."  			     /* Matich HMO */
        & (ENDD >&&DOE&ctr.. & STARTD <&&DOE&ctr..)  /* Must be at risk in Effective period */
        & abs(YEAR(MBDOB)-YEAR(&&dob&ctr..))<=2;     /* Matching age */

    PAIR = "&&pair&ctr..";                              /* Get the corresponding pair number */

    CSCN = 0;                                   /* Assign new case/control status */

    fate=ranuni(0);                                     /* Assign random number */
  run;

  proc sort data=no&ctr.; by fate;      /* Sort by random number */

  data no&ctr.;                         /* Only the luckiest 10 stay */
    set no&ctr.;
    if _n_<=10;
  run;
%end;

      *----------------------------------------------------*
      *  Third, Macro PICK set all the controls for all
      *  the cases together.
      *----------------------------------------------------*;
data pub_cn;                    /* We have to generate a dataset with no records first in order to add all the cn datasets*/
run;                            /* This would result in a record with missing values*/

%do ctr = 1 %to &totalcs;       /* Add all the datasets */
  data  pub_cn;
    set pub_cn no&ctr.;
%end;
  data pub_cn;
    set pub_cn;
    if _n_=1 then delete;       /* Delete the first record with missing value */
  run;


      *----------------------------------------------------*
      *  Finally, Macro PICK set the controls and the cases,
      *  and sort by the pair numbers and studyid.
      *----------------------------------------------------*;
  data  nest.cscn;
    set pub_cs pub_cn;

  proc sort data=nest.cscn; by pair descending cscn sdyid;
  run;

%mend;


%PICK;          /* Execute the Macro PICK */



        *----------------------------------------------------*
        *  For validation
        *----------------------------------------------------*;

proc format;
  value cscn    1='Case'
                0='Control'
                ;

proc print data=nest.cscn noobs split='*';
  var pair cscn pub sdyid mbdob hmo startd endd;
  format cscn pub cscn. mbdob year. startd endd yymmdd10. ;
  label pair     = 'Pair #  *_________'
        cscn     = 'CS/CN   *_________'
        pub      = 'original*CS/CN   *_________'
        sdyid    = 'ID      *_________'
        MBDOB    = 'Year of *Birth   *_________'
        HMO      = 'HMO     *_________'
        STARTD   = 'Start   *Date    *_________'
        ENDD     = 'End     *Date    *_________'
        ;
title 'Case-control list ';
title2 'First method - randomly selection';
run;
