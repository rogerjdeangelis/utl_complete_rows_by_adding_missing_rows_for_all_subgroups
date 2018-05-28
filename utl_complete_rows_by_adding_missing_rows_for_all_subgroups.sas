Complete rows by adding missing rows for all subgroups

This is a classic problem

github (doo not copy paste using readme use the WPS/SAS file)
https://tinyurl.com/y9dxx3ll
https://github.com/rogerjdeangelis/utl_complete_rows_by_adding_missing_rows_for_all_subgroups

SAS Forum
https://tinyurl.com/ybvl95qs
https://communities.sas.com/t5/Base-SAS-Programming/Add-missing-rows-for-several-subgroups/m-p/465195

Reeza profile (proc freq solution - minimal code)
https://communities.sas.com/t5/user/viewprofilepage/user-id/13879

SiyaKiran profile (SQL solution)
https://communities.sas.com/t5/user/viewprofilepage/user-id/83078


  WPS agreed with SAS on all 6 solutions

  Six solutions

      1. Proc freq sparserows
      2. Proc report completerows and preloadfmt (also summary,means and tabulate?)
         Appears to be a bug with 'order=formatted' does not order the output.
         Advantages: Can do summarization and should be able to order data
      3. Double transpose
      4. Proc corresp and proc transpose (some advantage with summarization)
      5. Proc sql  (order by does not support sort options like linguistic)
      6. HASH

  Could not compose a datastep centered solution?
  
  see additional datastep solution by on the end
  Paul Dorfman


INPUT
=====

 WORK.HAVE total obs=10               |              RULES
                                      |              =====
                         NUMBER_      |                         NUMBER_
   DIAGNOSIS     AGE     PATIENTS     |  DIAGNOSIS     AGE     PATIENTS
                                      |
       A        0-4          3        |   A is ok because it has all age ranges
       A        5-9         15        |
       A        10-15        2        |
       A        16-20        8        |
                                      |   Add missing ranges
       B        16-20        1        |   B        0-4          .   Bug oder=fromatted fails
                                          B        10-15        .
                                          B        16-20        1
                                          B        5-9          .
                                      |  ...
       C        5-9          1        |
                                      |
       D        0-4          1        |
       D        16-20        6        |
       D        5-9          2        |
                                      |
       E        0-4          1        |


 EXAMPLE OUTPUT

                          NUMBER_
  O DIAGNOSIS     AGE     PATIENTS

        A        0-4          3
        A        10-15        2
        A        16-20        8
        A        5-9         15

        B        0-4          .
        B        10-15        .
        B        16-20        1
        B        5-9          .

        C        0-4          .
        C        10-15        .
        C        16-20        .
        C        5-9          1
     ...


PROCESSES
=========

 1. Proc freq (Reeza)

     * output has 0s instead of missings;
     proc freq data=have noprint;
        table diagnosis*age/ out=wantFrq sparse list;
        weight number_patients;
     run;quit;

 2.  Proc report;

     proc format;
      value $age2rng
        '0-4'    = '0-4'
        '5-9'    = '5-9'
        '10-15'  = '10-15'
        '16-20'  = '16-20'
     ;
     run;quit;

     * BUG? order=formatted does not work;
     proc report data=have nowd missing completerows list out=wantRpt (drop=_break_);
     cols diagnosis age number_patients;
     define  diagnosis      /  group  ;
     define  age             / group preloadfmt order=formatted  format= $age2rng.;
     define  number_patients / sum ;
     run;quit;


 3.  Double transpose

     options validvarname=any;
     proc transpose data=have out=havXpo(drop=_name_);
      by diagnosis;
      id age;
      var number_patients;
     run;quit;

     proc transpose data=havXpo out=wantXpo;
     by diagnosis;
     var _numeric_;
     run;quit;
     Options validvarname=upcase;

 4.  Proc corresp

     options validvarname=any;
     ods exclude all;
     ods output observed=havCor(rename=label=diagnosis);
     proc corresp data=have dim=1 observed;
     tables diagnosis,age;
     weight number_patients;
     run;quit;
     ods select all;

     proc transpose data=havCor out=wantCor;
     by diagnosis;
     var _numeric_;
     run;quit;
     Options validvarname=upcase;

 5.  Proc SQL

     proc sql;
     create
         table wantSql as
      select
         a.*
        ,b.number_patients
     from
        (select
            * from
            (select
                distinct diagnosis
             from
                have),
            (select
               distinct age
            from
               have)
        ) as a
        left join have b
      on
          a.diagnosis=b.diagnosis
          and a.age=b.age
      order
          by diagnosis, age /* liguistic not suppporttes */
     ;quit;

  6. HASH

     data wantHsh;
     if _n_=1 then do;
     if 0 then set have;
       dcl hash H (dataset:'have') ;
        h.definekey  ("age") ;
        h.definedata ("age") ;
        h.definedone () ;
        declare hiter iter('h');
      dcl hash H1 () ;
        h1.definekey  ("age") ;
        h1.definedone () ;
      end;
     h1.clear();
     do until(last.diagnosis);
           set have;
           by diagnosis;
           if h.check()=0 and h1.num_items ne h.num_items then do; h1.add();output;end;
           if last.diagnosis then do;
           rc = iter.first();
           do while (rc = 0);
             if h1.check() ne 0 then do;call missing(number_patients); output;end;
             rc = iter.next();
           end;
           end;
     end;
     drop rc;
     run;

OUTPUT
======

  1. FREQ

     WORK.WANTFRQ total obs=20

      DIAGNOSIS     AGE     COUNT    PERCENT

          A        0-4         3        7.5
          A        10-15       2        5.0
          A        16-20       8       20.0
          A        5-9        15       37.5
          B        0-4         0        0.0
          B        10-15       0        0.0
          B        16-20       1        2.5
          B        5-9         0        0.0
          C        0-4         0        0.0
          C        10-15       0        0.0
          C        16-20       0        0.0
          C        5-9         1        2.5
          D        0-4         1        2.5
          D        10-15       0        0.0
          D        16-20       6       15.0
          D        5-9         2        5.0
          E        0-4         1        2.5
          E        10-15       0        0.0
          E        16-20       0        0.0
          E        5-9         0        0.0


   4. Corresp

      p to 40 obs from wantCor total obs=30

      bs    DIAGNOSIS    _NAME_    COL1

       1       A         0-4         3
       2       A         10-15       2
       3       A         16-20       8
       4       A         5-9        15
       5       A         Sum        28   ** nice?
       6       B         0-4         0
       7       B         10-15       0
       8       B         16-20       1
       9       B         5-9         0
      10       B         Sum         1   ** nice
      11       C         0-4         0
      12       C         10-15       0
      13       C         16-20       0
      14       C         5-9         1
      15       C         Sum         1   ** nice
      16       D         0-4         1
      17       D         10-15       0
      18       D         16-20       6
      19       D         5-9         2
      20       D         Sum         9   ** nice
      21       E         0-4         1
      22       E         10-15       0
      23       E         16-20       0
      24       E         5-9         0
      25       E         Sum         1   ** nice

      26       Sum       0-4         5   ** nice
      27       Sum       10-15       2
      28       Sum       16-20      15
      29       Sum       5-9        18
      30       Sum       Sum        40
*                _               _       _
 _ __ ___   __ _| | _____     __| | __ _| |_ __ _
| '_ ` _ \ / _` | |/ / _ \   / _` |/ _` | __/ _` |
| | | | | | (_| |   <  __/  | (_| | (_| | || (_| |
|_| |_| |_|\__,_|_|\_\___|   \__,_|\__,_|\__\__,_|

;


data have;
  input diagnosis $ age $ number_patients;
cards4;
A 0-4 3
A 5-9 15
A 10-15 2
A 16-20 8
B 16-20 1
C 5-9 1
D 0-4 1
D 16-20 6
D 5-9 2
E 0-4 1
;;;;
run;quit;

*          _       _   _
 ___  ___ | |_   _| |_(_) ___  _ __  ___
/ __|/ _ \| | | | | __| |/ _ \| '_ \/ __|
\__ \ (_) | | |_| | |_| | (_) | | | \__ \
|___/\___/|_|\__,_|\__|_|\___/|_| |_|___/

;

SAS - see process

*
__      ___ __  ___
\ \ /\ / / '_ \/ __|
 \ V  V /| |_) \__ \
  \_/\_/ | .__/|___/
         |_|
;

* FREQ
%utl_submit_wps64('
libname wrk sas7bdat "%sysfunc(pathname(work))";
proc freq data=wrk.have noprint;
   table diagnosis*age/ out=wantFrq sparse list;
   weight number_patients;
run;quit;
proc print;
run;quit;
');

* report;
%utl_submit_wps64('
libname wrk sas7bdat "%sysfunc(pathname(work))";
proc format;
 value $age2rng
   "0-4"    = "0-4"
   "5-9"    = "5-9"
   "10-15"  = "10-15"
   "16-20"  = "16-20"
;
run;quit;
proc report data=wrk.have nowd missing completerows list out=wantRpt (drop=_break_);
cols diagnosis age number_patients;
define  diagnosis      /  group  ;
define  age             / group preloadfmt order=formatted  format= $age2rng.;
define  number_patients / sum ;
run;quit;
proc print;
run;quit;
');

* Double transpose;
%utl_submit_wps64('
libname wrk sas7bdat "%sysfunc(pathname(work))";
options validvarname=any;
proc transpose data=wrk.have out=havXpo(drop=_name_);
 by diagnosis;
 id age;
 var number_patients;
run;quit;

proc transpose data=havXpo out=wantXpo;
by diagnosis;
var _numeric_;
run;quit;
Options validvarname=upcase;

proc print;
run;quit;
');

*Proc corresp
%utl_submit_wps64('
libname wrk sas7bdat "%sysfunc(pathname(work))";
options validvarname=any;
ods exclude all;
ods output observed=havCor(rename=label=diagnosis);
proc corresp data=wrk.have dim=1 observed;
tables diagnosis,age;
weight number_patients;
run;quit;
ods select all;

proc transpose data=havCor out=wantCor;
by diagnosis;
var _numeric_;
run;quit;
Options validvarname=upcase;
');

%utl_submit_wps64('
   libname wrk sas7bdat "%sysfunc(pathname(work))";
   proc sql;
     create
         table wantSql as
      select
         a.*
        ,b.number_patients
     from
        (select
            * from
            (select
                distinct diagnosis
             from
                wrk.have),
            (select
               distinct age
            from
               wrk.have)
        ) as a
        left join wrk.have b
      on
          a.diagnosis=b.diagnosis
          and a.age=b.age
      order
          by diagnosis, age
     ;quit;
proc print;
run;quit;
')'


%utl_submit_wps64('
     libname wrk  "%sysfunc(pathname(work))";
     data wantHsh;
     if _n_=1 then do;
     if 0 then set wrk.have;
       dcl hash H (dataset:"wrk.have") ;
        h.definekey  ("age") ;
        h.definedata ("age") ;
        h.definedone () ;
        declare hiter iter("h");
      dcl hash H1 () ;
        h1.definekey  ("age") ;
        h1.definedone () ;
      end;
     h1.clear();
     do until(last.diagnosis);
           set wrk.have;
           by diagnosis;
           if h.check()=0 and h1.num_items ne h.num_items then do; h1.add();output;end;
           if last.diagnosis then do;
           rc = iter.first();
           do while (rc = 0);
             if h1.check() ne 0 then do;call missing(number_patients); output;end;
             rc = iter.next();
           end;
           end;
     end;
     drop rc;
     run;quit;
     proc print;
     run;quit;
');


Paul Dorfman

data want (drop = _:) ;
  array h [99] $ 8 _temporary_ ;
  array f [99]   8 _temporary_ ;
  if _n_ = 1 then do until (z) ;
    set have end = z ;
    if whichC (age, of h[*]) then continue ; *check for dupes;
    _n + 1 ;
    h[_n] = age ;
  end ;
  do until (last.diagnosis) ;
    set have ;
    by diagnosis ;
    output ;
    _x = whichC (age, of h[*]); *mark those already present in current by-group;
    if _x then f[_x] = 1 ;
  end ;
  call missing (number_patients) ;
  do _x = 1 to _n ;
    if not f[_x] then do ; *output those not present in current by-group;
      age = h[_x] ;
      output ;
    end ;
    else f[_x] = 0 ; *reset flags for next by-group;
  end ;
run ;



