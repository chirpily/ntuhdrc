%let ratio=4;  /*case:control=1:ratio*/
%let seed=123456; 


v,dnv nmv a, c., ascj.abkj.av.as v.a 

/*case*/
data case(keep=ID ID_S  id_birth_ym case mentalg assaultdate); 
set mydata.case_control_id;
if assault=1;
case=1;
run;

/*control*/
data control(keep=ID ID_S  id_birth_ym mentalg);
set mydata.case_control_id;
if assault=0;
run;




vsjnvsanvzaknvs.anv.anvlnva/
proc means data=case nway noprint;
class ID_S  id_birth_ym mentalg assaultdate;
var case;
output out=casecnt(drop=_type_ _freq_) sum=ncase;
run;

data casecnt; set casecnt;
retain num 0; num+1;
run;

proc sql;
create table controlcnt as
select a.num, a.ncase, a.assaultdate, b.id, b.id_s, b.mentalg, ranuni(&seed) as rn /*¥[¤W¶Ã¼Æ*/
from casecnt as a join control as b
on a.id_s=b.id_s and a.id_birth_ym=b.id_birth_ym and  a.mentalg=b.mentalg
order by num, rn;
quit;

data samp; 
set controlcnt(drop=rn); 
by num;
if first.num then nd=0; nd+1;
if nd<=&ratio*ncase;
run;

proc sql;
create table samp_control as
select a.id, a.id_s, a.assaultdate, a.mentalg, b.id_birth_ym, 0 as case
from samp as a , mydata.case_control_id as b
where a.id=b.id;
quit;

data mydata.case_control;
set case samp_control;
proc freq;
table mentalg*case /nopercent nocol norow;
run;
