open HolKernel Parse boolLib

open bossLib
open BasicProvers

open chap3Theory chap2Theory ncTheory ncLib

local open pred_setLib in end

val _ = new_theory "labelledTerms";


val (labelled_term_rules, labelled_term_ind, labelled_term_cases) =
    Hol_reln`(!s. labelled_term (VAR s)) /\
             (!k. labelled_term (CON (INR k))) /\
             (!t u.
                  labelled_term t /\ labelled_term u ==>
                  labelled_term (t @@ u)) /\
             (!v t.
                  labelled_term t ==> labelled_term (LAM v t)) /\
             (!v (n:num) t u.
                  labelled_term t /\ labelled_term u ==>
                  labelled_term (CON (INL n) @@ (LAM v t) @@ u))`;

val labelled_renaming = prove(
  ``!t. labelled_term t ==> !R. RENAMING R ==> labelled_term (t ISUB R)``,
  HO_MATCH_MP_TAC labelled_term_ind THEN
  SIMP_TAC (srw_ss()) [ISUB_APP, ISUB_VAR_RENAME, ISUB_CON] THEN
  REPEAT STRIP_TAC THENL [
    PROVE_TAC [labelled_term_rules],
    PROVE_TAC [labelled_term_rules],
    PROVE_TAC [labelled_term_rules],
    Q_TAC (NEW_TAC "z") `v INSERT FV t UNION FVS R UNION DOM R` THEN
    `LAM v t = LAM z ([VAR z/v] t)` by SRW_TAC [][SIMPLE_ALPHA] THEN
    ASM_SIMP_TAC (srw_ss()) [ISUB_LAM, SUB_ISUB_SINGLETON,
                             ISUB_APPEND] THEN
    PROVE_TAC [RENAMING_THM, labelled_term_rules],
    Q_TAC (NEW_TAC "z") `v INSERT FV t UNION FVS R UNION DOM R` THEN
    `LAM v t = LAM z ([VAR z/v] t)` by SRW_TAC [][SIMPLE_ALPHA] THEN
    ASM_SIMP_TAC (srw_ss()) [ISUB_LAM, SUB_ISUB_SINGLETON,
                             ISUB_APPEND] THEN
    PROVE_TAC [RENAMING_THM, labelled_term_rules]
  ]);

val labelled_vsubst = prove(
  ``!t v u. labelled_term t ==> labelled_term ([VAR v/u] t)``,
  SRW_TAC [][SUB_ISUB_SINGLETON, labelled_renaming, RENAMING_THM])

val barendregt_subst_lemma =
    GEN_ALL
      (REWRITE_RULE [lemma14a]
                    (Q.INST [`M` |-> `VAR u`]  (SPEC_ALL GENERAL_SUB_COMMUTE)))

val strong_labt_ind =
    IndDefRules.derive_strong_induction (CONJUNCTS labelled_term_rules,
                                         labelled_term_ind)

val labelled_app = prove(
  ``!t u.
        labelled_term (t @@ u) =
        labelled_term t /\ labelled_term u \/
        ?v body n. (t = CON (INL n) @@ LAM v body) /\ labelled_term body /\
                   labelled_term u``,
  REPEAT GEN_TAC THEN
  CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [labelled_term_cases])) THEN
  SIMP_TAC (srw_ss()) [] THEN PROVE_TAC []);

val labelled_lam = prove(
  ``!v t. labelled_term (LAM v t) = labelled_term t``,
  REPEAT GEN_TAC THEN
  CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [labelled_term_cases])) THEN
  SIMP_TAC (srw_ss()) [] THEN PROVE_TAC [labelled_vsubst, INJECTIVITY_LEMMA1]);



val labelled_sub = store_thm(
  "labelled_sub",
  ``!t u v. labelled_term t /\ labelled_term u ==>
            labelled_term ([u/v] t)``,
  GEN_TAC THEN
  completeInduct_on `size t` THEN GEN_TAC THEN
  Q.ISPEC_THEN `t` STRUCT_CASES_TAC nc_CASES THENL [
    SRW_TAC [][SUB_THM],
    SIMP_TAC (srw_ss() ++ boolSimps.COND_elim_ss) [SUB_VAR],
    POP_ASSUM MP_TAC THEN
    Q_TAC SUFF_TAC
          `!(f:(num + 'a) nc) x w y.
               (!(t:(num + 'a) nc) u v.
                        size t < size (f @@ x) /\ labelled_term t /\
                        labelled_term u ==> labelled_term ([u/v]t)) /\
               labelled_term (f @@ x) /\ labelled_term w ==>
               labelled_term ([w/y] (f @@ x))` THEN1 PROVE_TAC [] THEN
    SRW_TAC [][SUB_THM, size_thm] THEN
    `labelled_term f /\ labelled_term x \/
     ?v body n. (f = CON (INL n) @@ LAM v body) /\ labelled_term body /\
                labelled_term x` by PROVE_TAC [labelled_app] THEN
    `size f < size f + size x + 1 /\ size x < size f + size x + 1` by
       SRW_TAC [numSimps.ARITH_ss][]
    THENL [
      PROVE_TAC [labelled_term_rules],
      Q_TAC SUFF_TAC `?var M. ([w/y] (LAM v body) = LAM var M) /\
                              labelled_term M` THEN1
        (ASM_SIMP_TAC (srw_ss()) [labelled_app, SUB_THM] THEN
         PROVE_TAC []) THEN
      Q_TAC (NEW_TAC "z") `{v;y} UNION FV w UNION FV body` THEN
      `LAM v body = LAM z ([VAR z/v] body)` by SRW_TAC [][SIMPLE_ALPHA] THEN
      Q_TAC SUFF_TAC
            `labelled_term ([w/y] ([VAR z/v] body))` THEN1
            (ASM_SIMP_TAC (srw_ss()) [SUB_THM] THEN PROVE_TAC []) THEN
      FIRST_ASSUM MATCH_MP_TAC THEN
      SRW_TAC [numSimps.ARITH_ss][size_thm] THEN
      FIRST_ASSUM MATCH_MP_TAC THEN
      SRW_TAC [numSimps.ARITH_ss][size_thm, labelled_term_rules]
    ],

    FULL_SIMP_TAC (srw_ss()) [GSYM RIGHT_FORALL_IMP_THM, size_thm,
                              AND_IMP_INTRO, labelled_lam, SUB_LAM_RWT] THEN
    REPEAT STRIP_TAC THEN FIRST_ASSUM MATCH_MP_TAC THEN
    ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss) [] THEN
    FIRST_ASSUM MATCH_MP_TAC THEN
    ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss) [labelled_term_rules]
  ]);

val (lam_case0, _) = define_recursive_term_function
  `(lam_case0 (VAR s) = \v c a f. v s) /\
   (lam_case0 (CON k) = \v c a f. c k) /\
   (lam_case0 (t @@ u) = \v c a f. a t u) /\
   (lam_case0 (LAM v t) = \v' c a f. f v t)`;

val lam_case_def =
    Define`lam_case v c a f t = lam_case0 t v c a f`;

val lam_case_thm = store_thm(
  "lam_case_thm",
  ``(!v c a f s. lam_case v c a f (VAR s) = v s) /\
    (!v c a f k. lam_case v c a f (CON k) = c k) /\
    (!v c a f t u. lam_case v c a f (t @@ u) = a t u) /\
    (!v c a f w t. lam_case v c a f (LAM w t) =
                     let x = NEW (FV (LAM w t)) in
                       f x ([VAR x/w] t))``,
  SRW_TAC [][lam_case_def, lam_case0]);

val lam_case_cong = store_thm(
  "lam_case_cong",
  ``!M M' v c a f.
       (M = M') /\
       (!s. (M' = VAR s) ==> (v s = v' s)) /\
       (!k. (M' = CON k) ==> (c k = c' k)) /\
       (!t u. (M' = t @@ u) ==> (a t u = a' t u)) /\
       (!v t. (M' = LAM v t) ==> (f v t = f' v t)) ==>
       (lam_case v c a f M = lam_case v' c' a' f' M')``,
  SRW_TAC [][] THEN
  Q.SPEC_THEN `M` STRIP_ASSUME_TAC nc_CASES THEN
  FULL_SIMP_TAC (srw_ss())[lam_case_thm] THEN
  NEW_ELIM_TAC THEN SRW_TAC [][] THEN
  FIRST_ASSUM MATCH_MP_TAC THEN
  SRW_TAC [][ALPHA]);

val nctyinfo = let
  open TypeBasePure
in
  mk_tyinfo {ax = COPY("ncTheory.nc_RECURSION_WEAK",
                       ncTheory.nc_RECURSION_WEAK),
             induction = COPY("ncTheory.nc_INDUCTION", ncTheory.nc_INDUCTION),
             case_def = lam_case_thm,
             case_cong = lam_case_cong,
             nchotomy = nc_CASES,
             size = SOME (``size : 'a nc -> num``,
                          COPY ("chap2Theory.size_thm", chap2Theory.size_thm)),
             lift = NONE, encode = NONE,
             one_one = SOME nc_INJECTIVITY,
             distinct = SOME nc_DISTINCT}
end;

val _ = TypeBase.write [nctyinfo]

val M = ``\f. lam_case (\s. VAR s : 'b nc) (\k. CON (OUTR k))
                       (\u v. if is_comb u /\ is_const (rator u) /\
                                 ISL (dest_const (rator u))
                              then
                                f (rand u) @@ f v
                              else
                                f u @@ f v)
                       (\v t. LAM v (f t))``

val strip_lab_uexists =
    SPEC M (SIMP_RULE bool_ss [prim_recTheory.WF_measure]
                      (SPEC ``measure (size :('a + 'b) nc -> num)``
                            (INST_TYPE [alpha |-> ``:('a + 'b) nc``,
                                        beta |-> ``:'b nc``]
                                       relationTheory.WF_RECURSION_THM)))

val strip_lab_exists =
    SIMP_RULE bool_ss []
              (CONJUNCT1 (CONV_RULE EXISTS_UNIQUE_CONV strip_lab_uexists))

val strip_lab_def =
    new_specification ("strip_lab_def", ["strip_lab"], strip_lab_exists);

val strip_lab_var = prove(
  ``strip_lab (VAR s) = (VAR s)``,
  SRW_TAC [][strip_lab_def, lam_case_thm]);
val strip_lab_con = prove(
  ``strip_lab (CON (INR k)) = CON k``,
  SRW_TAC [][strip_lab_def, lam_case_thm]);
val strip_lab_app = prove(
  ``strip_lab (t @@ u) =
      if is_comb t /\ is_const (rator t) /\ ISL (dest_const (rator t)) then
        strip_lab (rand t) @@ strip_lab u
      else
        strip_lab t @@ strip_lab u``,
  CONV_TAC (LAND_CONV (REWR_CONV strip_lab_def)) THEN
  SRW_TAC [][lam_case_thm] THEN
  MATCH_MP_TAC relationTheory.RESTRICT_LEMMA THEN
  SRW_TAC [numSimps.ARITH_ss][prim_recTheory.measure_thm,
                              chap2Theory.size_thm] THEN
  FULL_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)
                [is_comb_APP_EXISTS, chap2Theory.size_thm]);

val strip_lab_lam = prove(
  ``strip_lab (LAM v t) = let u = NEW (FV (LAM v t)) in
                            LAM u (strip_lab ([VAR u/v] t))``,
  CONV_TAC (LAND_CONV (REWR_CONV strip_lab_def)) THEN
  SRW_TAC [][lam_case_thm] THEN
  MATCH_MP_TAC relationTheory.RESTRICT_LEMMA THEN
  SRW_TAC [numSimps.ARITH_ss][prim_recTheory.measure_thm,
                              chap2Theory.size_thm]);


val lterm_ax = new_type_definition (
  "lterm",
  prove(``?t. labelled_term t``,
        Q.EXISTS_TAC `VAR s` THEN SRW_TAC [][labelled_term_rules]));

val term_labelled_term =
    define_new_type_bijections { name = "term_labelled_term",
                                 ABS  = "tolabelled",
                                 REP  = "fromlabelled",
                                 tyax = lterm_ax };

val CON_def = Define`CON k = tolabelled (nc$CON (INR k))`;
val VAR_def = Define`VAR s = tolabelled (nc$VAR s)`;
val APP_def =
    xDefine "APP"
            `t @@ u = tolabelled (nc$@@ (fromlabelled t) (fromlabelled u))`;
val LAM_def =
    Define`LAM v t = tolabelled (nc$LAM v (fromlabelled t))`;

val LAMi_def =
    Define`LAMi n v M N =
    tolabelled (CON (INL n) @@ LAM v (fromlabelled M) @@ fromlabelled N)`;


val tofrom_inverse = store_thm(
  "tofrom_inverse",
  ``!t. tolabelled (fromlabelled t) = t``,
  SRW_TAC [][term_labelled_term]);
val fromto_inverse = store_thm(
  "fromto_inverse",
  ``!t. labelled_term t ==> (fromlabelled (tolabelled t) = t)``,
  PROVE_TAC [term_labelled_term]);
val from_ok = store_thm(
  "from_ok",
  ``!t. labelled_term (fromlabelled t)``,
  PROVE_TAC [term_labelled_term]);

val fromlabelled_11 = store_thm(
  "fromlabelled_11",
  ``!t1 t2. (fromlabelled t1 = fromlabelled t2) = (t1 = t2)``,
  SIMP_TAC (srw_ss()) [EQ_IMP_THM] THEN REPEAT GEN_TAC THEN
  DISCH_THEN (MP_TAC o Q.AP_TERM `tolabelled`) THEN
  SIMP_TAC bool_ss [tofrom_inverse]);

val _ = augment_srw_ss [rewrites [tofrom_inverse, fromto_inverse, from_ok]]

val SUB_def =
    Define`[t/v] u = tolabelled (nc$SUB (fromlabelled t) v (fromlabelled u))`;

val fromlabelled_subst = store_thm(
  "fromlabelled_subst",
  ``!t u v. fromlabelled ([u/v] t) = [fromlabelled u/v] (fromlabelled t)``,
  SRW_TAC [][SUB_def, from_ok, labelled_sub]);

val lterm_INJECTIVITY = store_thm(
  "lterm_INJECTIVITY",
  ``(!s t. (VAR s = VAR t : 'a lterm) = (s = t)) /\
    (!k m. (CON k = CON m : 'a lterm) = (k = m)) /\
    (!t1 t2 u1 u2. (t1 @@ u1 = t2 @@ u2 : 'a lterm) =
                        (t1 = t2) /\ (u1 = u2)) /\
    (!v1 t1 v2 t2. (LAM v1 t1 = LAM v2 t2 : 'a lterm) ==>
                    !z. [VAR z/v1] t1 = [VAR z/v2] t2) /\
    (!n1 n2 v1 v2 t1 t2 u1 u2.
           (LAMi n1 v1 t1 u1 = LAMi n2 v2 t2 u2 : 'a lterm) ==>
                   (n1 = n2) /\ (u1 = u2) /\
                   !z. [VAR z/v1]t1 = [VAR z/v2]t2)``,
  SIMP_TAC (srw_ss()) [VAR_def, CON_def, APP_def, EQ_IMP_THM, LAM_def,
                       LAMi_def] THEN
  REPEAT STRIP_TAC THEN
  POP_ASSUM (MP_TAC o Q.AP_TERM `fromlabelled`) THEN
  SIMP_TAC (srw_ss()) [labelled_term_rules] THEN
  TRY (DISCH_THEN (REPEAT_TCL STRIP_THM_THEN
                              (MP_TAC o Q.AP_TERM `tolabelled`)) THEN
       SIMP_TAC (srw_ss()) [] THEN NO_TAC) THEN
  SIMP_TAC (srw_ss()) [fromlabelled_11] THEN REPEAT STRIP_TAC THEN
  IMP_RES_TAC INJECTIVITY_LEMMA1 THEN
  POP_ASSUM (MP_TAC o Q.AP_TERM `tolabelled`) THEN
  SIMP_TAC (srw_ss()) [] THEN
  `!s. VAR s = fromlabelled (VAR s)` by
       SRW_TAC [][VAR_def, labelled_term_rules] THEN
  ASM_SIMP_TAC (srw_ss()) [GSYM SUB_def] THEN
  POP_ASSUM (ASSUME_TAC o GSYM) THEN
  ASM_SIMP_TAC (srw_ss()) [SUB_def, labelled_sub, labelled_term_rules] THEN
  DISCH_THEN (K ALL_TAC) THEN AP_TERM_TAC THEN
  Cases_on `v1 = v2` THEN SRW_TAC [][lemma14a] THEN
  PROVE_TAC [LAM_INJ_ALPHA_FV, lemma15a]);

val lterm_usable_INJECTIVITY = save_thm(
  "lterm_usable_INJECTIVITY",
  LIST_CONJ (List.take(CONJUNCTS lterm_INJECTIVITY, 3)));

val _ = export_rewrites ["lterm_usable_INJECTIVITY"]

val FV_def = Define`FV t = nc$FV (fromlabelled t)`;

val lFV_THM = store_thm(
  "lFV_THM",
  ``(!s. FV (VAR s) = {s}) /\
    (!k. FV (CON k) = {}) /\
    (!t u. FV (t @@ u) = FV t UNION FV u) /\
    (!v t. FV (LAM v t) = FV t DELETE v) /\
    (!v n t u. FV (LAMi n v t u) = (FV t DELETE v) UNION FV u)``,
  SRW_TAC [][VAR_def, CON_def, APP_def, FV_THM, labelled_term_rules,
             LAM_def, LAMi_def, FV_def]);

val _ = augment_srw_ss [rewrites [lFV_THM]];

val lSUB_THM = store_thm(
  "lSUB_THM",
  ``(!t v u. [t/v](VAR u) = if v = u then t else VAR u) /\
    (!t v k. [t/v](CON k) = CON k) /\
    (!t v u w. [t/v](u @@ w) = [t/v]u @@ [t/v]w) /\
    (!t v w. [t/v](LAM v w) = LAM v w) /\
    (!M N u v. ~(v = u) /\ ~(u IN FV M) ==>
               ([M/v](LAM u N) = LAM u ([M/v] N))) /\
    (!M N P n u. [P/v](LAMi n v M N) = LAMi n v M ([P/v]N)) /\
    (!M N P n u v. ~(v = u) /\ ~(u IN FV P) ==>
                   ([P/v](LAMi n u M N) = LAMi n u ([P/v]M) ([P/v]N)))``,
  SRW_TAC [][VAR_def, CON_def, APP_def, SUB_def, labelled_term_rules,
             SUB_THM, labelled_sub, LAM_def, GSYM FV_def, LAMi_def]);

val beta0_def =
    Define`beta0 M N = ?n v t u. (M = LAMi n v t u) /\ (N = [u/v]t)`;

val beta1_def =
    Define`beta1 (M:'a lterm) N =
              ?v t u. (M = (LAM v t) @@ u) /\ (N = [u/v]t)`;

val fromlabelled_thm = store_thm(
  "fromlabelled_thm",
  ``(fromlabelled (VAR s) = VAR s) /\
    (fromlabelled (CON k) = CON (INR k)) /\
    (fromlabelled (t @@ u) = fromlabelled t @@ fromlabelled u) /\
    (fromlabelled (LAM v t) = LAM v (fromlabelled t)) /\
    (fromlabelled (LAMi n v t u) =
       CON (INL n) @@ LAM v (fromlabelled t) @@ fromlabelled u)``,
  SRW_TAC [][VAR_def, CON_def, APP_def, LAM_def, LAMi_def,
             labelled_term_rules]);

val strip_label_def =
    Define`strip_label lt = strip_lab (fromlabelled lt)`;


val strip_lab_con0 = prove(
  ``strip_lab (CON k) = CON (OUTR k)``,
  SRW_TAC [][strip_lab_def, lam_case_thm]);

val FV_strip_lab = prove(
  ``!t. FV (strip_lab t) = FV t``,
  GEN_TAC THEN completeInduct_on `size t` THEN
  FULL_SIMP_TAC (srw_ss()) [GSYM RIGHT_FORALL_IMP_THM] THEN
  SRW_TAC [][] THEN
  Cases_on `t` THEN
  FULL_SIMP_TAC (srw_ss()) [size_thm, strip_lab_con0, strip_lab_var,
                            strip_lab_app, strip_lab_lam]
  THENL [
    REVERSE (Cases_on `is_comb t'`) THEN1
      ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss) [] THEN
    REVERSE (Cases_on `is_const (rator t')`) THEN1
      ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss) [] THEN
    REVERSE (Cases_on `ISL (dest_const (rator t'))`) THEN1
      ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss) [] THEN
    FULL_SIMP_TAC (srw_ss()) [is_comb_APP_EXISTS] THEN SRW_TAC [][] THEN
    FULL_SIMP_TAC (srw_ss()) [size_thm] THEN
    `?k. u' = CON k` by PROVE_TAC [nc_CASES, is_const_thm] THEN
    SRW_TAC [numSimps.ARITH_ss][],
    NEW_ELIM_TAC THEN
    ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss) [FV_SUB] THEN
    SRW_TAC [][pred_setTheory.EXTENSION] THEN PROVE_TAC []
  ]);

val ALPHA_ERASE = prove(
  ``!X u:'a nc.
      (X = FV u) ==>
      (LAM (NEW (X DELETE x)) ([VAR (NEW (X DELETE x))/x] u) =
       LAM x u)``,
  SRW_TAC [][] THEN NEW_ELIM_TAC THEN SRW_TAC [][] THEN
  PROVE_TAC [SIMPLE_ALPHA, lemma14a]);

val bRENAME_def = Define`bRENAME (x:string) y z = if z = y then x else z`
val blRENAME_def =
    Define`(blRENAME [] s = s) /\
           (blRENAME (h::t) s = blRENAME t (bRENAME (FST h) (SND h) s))`;

val FV_SUB_IMAGE = prove(
  ``!t:'a nc.
      FV ([VAR v/x] t) = IMAGE (RENAME [(VAR v:'a nc,x)]) (FV t)``,
  SIMP_TAC (srw_ss()) [SUB_ISUB_SINGLETON, RENAMING_THM, FV_RENAMING]);

val RENAME_blRENAME = prove(
  ``!l. RENAME l = blRENAME (MAP (\p. (VNAME (FST p), SND p)) l)``,
  SIMP_TAC (srw_ss()) [FUN_EQ_THM] THEN Induct THEN
  ASM_SIMP_TAC (srw_ss()) [RENAME_def, blRENAME_def, pairTheory.FORALL_PROD,
                           bRENAME_def]);

val blRENAME_COMPOSE = prove(
  ``!l1 l2.
       blRENAME l1 o blRENAME l2 = blRENAME (APPEND l2 l1)``,
  CONV_TAC SWAP_VARS_CONV THEN
  SIMP_TAC (srw_ss()) [FUN_EQ_THM, combinTheory.o_THM] THEN
  Induct THEN ASM_SIMP_TAC (srw_ss()) [blRENAME_def]);


fun FORCE_COND_RWT th (asl, w) = let
  val revised_th = REWRITE_RULE [AND_IMP_INTRO] th
  val (cond, eqn) = dest_imp (#2 (strip_forall (concl revised_th)))
  val match = find_term (can (match_term (lhs eqn))) w
  val new_th = PART_MATCH (lhs o #2 o strip_imp) th match
  val (new_cond, new_eqn) = dest_imp (#2 (strip_forall (concl new_th)))
in
  ([(asl, mk_conj(Term.subst [match |-> rhs new_eqn] w,
                  new_cond))],
   (fn l => let val (c1, c2) = CONJ_PAIR (hd l)
            in
              CONV_RULE (REWRITE_CONV [GSYM (MATCH_MP revised_th c2)]) c1
            end))
end

val strip_lab_commutes = prove(
  ``!t v u. [VAR v/u] (strip_lab t) = strip_lab ([VAR v/u] t)``,
  GEN_TAC THEN completeInduct_on `size t` THEN
  FULL_SIMP_TAC (srw_ss()) [GSYM RIGHT_FORALL_IMP_THM] THEN
  GEN_TAC THEN Cases_on `t` THEN SRW_TAC [][size_thm] THEN
  FULL_SIMP_TAC (srw_ss())
                [strip_lab_var, strip_lab_app, SUB_THM, strip_lab_con0]
  THENL [
    SRW_TAC [][SUB_VAR, strip_lab_var],
    REVERSE (Cases_on `is_comb t'`) THEN1
      ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss) [SUB_THM] THEN
    ASM_REWRITE_TAC [] THEN
    REVERSE (Cases_on `is_const (rator t')`) THEN1
      ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)
                   [SUB_THM, GSYM rator_subst_commutes] THEN
    ASM_SIMP_TAC (srw_ss()) [GSYM rator_subst_commutes] THEN
    Cases_on `ISL (dest_const (rator t'))` THENL [
      ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)
                   [SUB_THM, GSYM rand_subst_commutes] THEN
      FULL_SIMP_TAC (srw_ss()) [is_comb_APP_EXISTS] THEN
      FULL_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss) [size_thm],
      ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss) [SUB_THM]
    ],
    Q_TAC (NEW_TAC "z") `{v';u';x} UNION FV u` THEN
    `LAM x u = LAM z ([VAR z/x] u)` by SRW_TAC [][SIMPLE_ALPHA] THEN
    FIRST_X_ASSUM (ASSUME_TAC o GSYM o assert (is_forall o concl)) THEN
    ASM_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)
                   [FV_strip_lab, SUB_THM, strip_lab_lam,
                    ALPHA_ERASE, FV_SUB_IMAGE,
                    GSYM pred_setTheory.IMAGE_COMPOSE,
                    blRENAME_COMPOSE, RENAME_blRENAME, VNAME_DEF] THEN
    `LAM x (strip_lab u) = LAM z ([VAR z/x] (strip_lab u))` by
        SRW_TAC [][SIMPLE_ALPHA, FV_strip_lab] THEN
    SRW_TAC [][SUB_THM]
  ]);


val strip_label_thm = store_thm(
  "strip_label_thm",
  ``(strip_label (VAR s) = VAR s) /\
    (strip_label (CON k) = CON k) /\
    (strip_label (t @@ u) = strip_label t @@ strip_label u) /\
    (strip_label (LAM v t) = LAM v (strip_label t)) /\
    (strip_label (LAMi n v M N) = LAM v (strip_label M) @@ strip_label N)``,
  SRW_TAC [][strip_label_def, fromlabelled_thm,
             strip_lab_var, strip_lab_con, strip_lab_app,
             strip_lab_lam]
  THENL [
    `labelled_term (fromlabelled t)` by PROVE_TAC [from_ok] THEN
    Q.ABBREV_TAC `ft = fromlabelled t` THEN POP_ASSUM (K ALL_TAC) THEN
    FULL_SIMP_TAC (srw_ss()) [is_comb_APP_EXISTS] THEN
    SRW_TAC [][] THEN
    FULL_SIMP_TAC (srw_ss()) [rator_thm] THEN
    `?k. u = CON k` by PROVE_TAC [nc_CASES, is_const_thm] THEN
    POP_ASSUM SUBST_ALL_TAC THEN
    FULL_SIMP_TAC (srw_ss()) [dest_const_thm] THEN
    `?j. k = INL j` by PROVE_TAC [sumTheory.sum_CASES, sumTheory.ISL] THEN
    POP_ASSUM SUBST_ALL_TAC THEN
    POP_ASSUM MP_TAC THEN
    ONCE_REWRITE_TAC [labelled_term_cases] THEN
    SIMP_TAC (srw_ss()) [] THEN
    ONCE_REWRITE_TAC [labelled_term_cases] THEN SIMP_TAC (srw_ss()) [],

    SIMP_TAC (srw_ss()) [GSYM strip_lab_commutes, ALPHA_ERASE,
                         FV_strip_lab],

    SIMP_TAC (srw_ss()) [GSYM strip_lab_commutes, ALPHA_ERASE,
                         FV_strip_lab],

    FULL_SIMP_TAC (srw_ss()) [is_const_thm, dest_const_thm]
  ]);


val strip_label_vsubst_commutes = store_thm(
  "strip_label_vsubst_commutes",
  ``!t u v. [VAR u/v] (strip_label t) = strip_label ([VAR u/v] t)``,
  SRW_TAC [][strip_label_def, strip_lab_commutes, fromlabelled_subst,
             fromlabelled_thm]);

val induction_lemma = prove(
  ``!P. (!t. labelled_term t ==> P (tolabelled t)) = (!t. P t)``,
  PROVE_TAC [tofrom_inverse, from_ok]);

val labelled_term_strong_ind =
    IndDefRules.derive_strong_induction (CONJUNCTS labelled_term_rules,
                                         labelled_term_ind);



val labelled_term_con = prove(
  ``labelled_term (CON k) = ?j. k = INR j``,
  ONCE_REWRITE_TAC [labelled_term_cases] THEN SRW_TAC [][]);

val lterm_INDUCTION = store_thm(
  "lterm_INDUCTION",
  ``!P.
      (!s. P (VAR s)) /\ (!k. P (CON k)) /\
      (!t u. P t /\ P u ==> P(t @@ u)) /\
      (!v t. (!y. P ([VAR y/v] t)) ==> P (LAM v t)) /\
      (!v i M N. (!y. P ([VAR y/v] M)) /\ P N ==>
                 P (LAMi i v M N)) ==>
      !t. P t``,
  GEN_TAC THEN STRIP_TAC THEN REWRITE_TAC [GSYM induction_lemma] THEN
  GEN_TAC THEN completeInduct_on `size t` THEN
  FULL_SIMP_TAC (srw_ss()) [GSYM RIGHT_FORALL_IMP_THM, AND_IMP_INTRO] THEN
  SRW_TAC [][] THEN Cases_on `t` THENL [
    FULL_SIMP_TAC (srw_ss()) [labelled_term_con, GSYM CON_def],
    FULL_SIMP_TAC (srw_ss()) [GSYM VAR_def],
    FULL_SIMP_TAC (srw_ss()) [labelled_app, size_thm] THENL [
      `t' = fromlabelled (tolabelled t')` by PROVE_TAC [fromto_inverse] THEN
      POP_ASSUM SUBST1_TAC THEN
      `u = fromlabelled (tolabelled u)` by PROVE_TAC [fromto_inverse] THEN
      POP_ASSUM SUBST1_TAC THEN
      REWRITE_TAC [GSYM APP_def] THEN SRW_TAC [numSimps.ARITH_ss][],
      `body = fromlabelled (tolabelled body)`
         by PROVE_TAC [fromto_inverse] THEN
      POP_ASSUM SUBST1_TAC THEN
      `u = fromlabelled (tolabelled u)` by PROVE_TAC [fromto_inverse] THEN
      POP_ASSUM SUBST1_TAC THEN
      REWRITE_TAC [GSYM LAMi_def] THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
      SRW_TAC [numSimps.ARITH_ss][SUB_def, fromlabelled_thm,
                                  size_thm, labelled_term_rules,
                                  labelled_sub]
    ],

    `labelled_term u` by PROVE_TAC [labelled_lam] THEN
    `u = fromlabelled (tolabelled u)` by PROVE_TAC [fromto_inverse] THEN
    POP_ASSUM SUBST1_TAC THEN REWRITE_TAC [GSYM LAM_def] THEN
    FIRST_X_ASSUM MATCH_MP_TAC THEN
    SRW_TAC [numSimps.ARITH_ss][SUB_def, fromlabelled_thm,
                                size_thm, labelled_term_rules, labelled_sub]
  ]);

val lSIMPLE_ALPHA = store_thm(
  "lSIMPLE_ALPHA",
  ``!(t:'a lterm) v u. ~(u IN FV t) ==> (LAM v t = LAM u ([VAR u/v] t))``,
  SIMP_TAC (srw_ss()) [LAM_def, fromlabelled_subst, fromlabelled_thm,
                       GSYM FV_def, GSYM SIMPLE_ALPHA]);

val lSIMPLE_ALPHAi = store_thm(
  "lSIMPLE_ALPHAi",
  ``!(t:'a lterm) n v u w. ~(u IN FV t) ==>
                           (LAMi n v t w = LAMi n u ([VAR u/v] t) w)``,
  SIMP_TAC (srw_ss()) [LAMi_def, fromlabelled_subst, fromlabelled_thm,
                       GSYM FV_def, GSYM SIMPLE_ALPHA]);


val (null_labelling_def, _) =
    define_recursive_term_function
    `(null_labelling (VAR s : 'a nc) = (VAR s: 'a lterm)) /\
     (null_labelling (CON k) = CON k) /\
     (null_labelling (t @@ u) = null_labelling t @@ null_labelling u) /\
     (null_labelling (LAM v t) = LAM v (null_labelling t))`

val FV_null_labelling = store_thm(
  "FV_null_labelling",
  ``!t. FV (null_labelling t) = FV t``,
  HO_MATCH_MP_TAC nc_INDUCTION THEN
  SRW_TAC [][null_labelling_def, lFV_THM] THEN
  NEW_ELIM_TAC THEN
  SRW_TAC [][pred_setTheory.EXTENSION, FV_SUB] THEN PROVE_TAC []);

val FV_strip_label = store_thm(
  "FV_strip_label",
  ``!t. FV (strip_label t) = FV t``,
  SIMP_TAC (srw_ss()) [strip_label_def, FV_def, FV_strip_lab]);

val lFINITE_FV = store_thm(
  "lFINITE_FV",
  ``!t:'a lterm. FINITE (FV t)``,
  PROVE_TAC [FINITE_FV, FV_strip_label]);

val _ = augment_srw_ss [rewrites [lFINITE_FV]];

val l14a = store_thm(  (* use native induction principle *)
  "l14a",
  ``!(t:'a lterm) v. [VAR v/v] t = t``,
  HO_MATCH_MP_TAC lterm_INDUCTION THEN SRW_TAC [][lSUB_THM] THENL [
    Q_TAC (NEW_TAC "z") `{v';v} UNION FV t` THEN
    `LAM v t = LAM z ([VAR z/v] t)` by SRW_TAC [][lSIMPLE_ALPHA] THEN
    SRW_TAC [][lSUB_THM],
    Q_TAC (NEW_TAC "z") `{v';v} UNION FV M` THEN
    `LAMi i v M t = LAMi i z ([VAR z/v] M) t` by
       SRW_TAC [][lSIMPLE_ALPHAi] THEN
    SRW_TAC [][lSUB_THM]
  ]);

val l14b = store_thm( (* translate from nc type *)
  "l14b",
  ``!(t:'a lterm) u v. ~(v IN FV t) ==> ([u/v] t = t)``,
  SRW_TAC [][SUB_def, FV_def, lemma14b]);

val lALPHA_ERASE = prove(
  ``!X x (t:'a lterm).
       (X = FV t) ==>
       (LAM (NEW (X DELETE x)) ([VAR (NEW (X DELETE x))/x] t) =
        LAM x t)``,
  REPEAT STRIP_TAC THEN NEW_ELIM_TAC THEN
  ASM_SIMP_TAC (srw_ss()) [lFINITE_FV, GSYM lSIMPLE_ALPHA, l14a,
                           DISJ_IMP_THM, FORALL_AND_THM]);

val lFV_SUB_IMAGE = prove(
  ``!(t:'a lterm) v u. FV ([VAR v/u] t) = IMAGE (blRENAME [(v,u)]) (FV t)``,
  SRW_TAC [][FV_def, SUB_def, fromlabelled_thm, labelled_sub,
             labelled_term_rules, FV_SUB_IMAGE, RENAME_blRENAME,
             VNAME_DEF]);

val lFV_SUB = store_thm(
  "lFV_SUB",
  ``!(t:'a lterm) u v.
         FV ([u/v] t) = if v IN FV t then FV u UNION (FV t DELETE v)
                        else FV t``,
  SRW_TAC [][FV_def, SUB_def, labelled_sub, labelled_term_rules, FV_SUB]);

val null_labelling_vsubst = prove(
  ``!t u v. null_labelling ([VAR u/v] t) = [VAR u/v] (null_labelling t)``,
  GEN_TAC THEN completeInduct_on `size t` THEN
  FULL_SIMP_TAC (srw_ss()) [GSYM RIGHT_FORALL_IMP_THM] THEN
  GEN_TAC THEN Cases_on `t` THEN
  FULL_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)
                [SUB_THM, lSUB_THM, null_labelling_def, size_thm] THEN
  SRW_TAC [][SUB_THM, null_labelling_def, lALPHA_ERASE,
             FV_null_labelling] THEN
  Q_TAC (NEW_TAC "z") `FV u UNION {u'; v'; x}` THEN
  `LAM x u = LAM z ([VAR z/x] u)` by SRW_TAC [][SIMPLE_ALPHA] THEN
  `LAM x (null_labelling u) =
     LAM z ([VAR z/x] (null_labelling u))` by
       SRW_TAC [][lSIMPLE_ALPHA, FV_null_labelling] THEN
  SRW_TAC [numSimps.ARITH_ss]
          [SUB_THM, lSUB_THM, FV_null_labelling, null_labelling_def,
           lALPHA_ERASE, FV_SUB_IMAGE, RENAME_blRENAME, blRENAME_COMPOSE,
           GSYM pred_setTheory.IMAGE_COMPOSE, VNAME_DEF, lFV_SUB_IMAGE,
           FV_null_labelling]);

val null_labelling_subst = store_thm(
  "null_labelling_subst",
  ``!t u v. null_labelling ([u/v] t) =
              [null_labelling u/v] (null_labelling t)``,
  GEN_TAC THEN completeInduct_on `size t` THEN
  FULL_SIMP_TAC (srw_ss()) [GSYM RIGHT_FORALL_IMP_THM] THEN
  GEN_TAC THEN Cases_on `t` THEN
  FULL_SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)
                [SUB_THM, lSUB_THM, null_labelling_def, size_thm] THEN
  SRW_TAC [][SUB_THM, null_labelling_def, lALPHA_ERASE,
             FV_null_labelling] THEN
  Q_TAC (NEW_TAC "z") `FV u UNION FV u' UNION {v'; x}` THEN
  `LAM x u = LAM z ([VAR z/x] u)` by SRW_TAC [][SIMPLE_ALPHA] THEN
  `LAM x (null_labelling u) =
     LAM z ([VAR z/x] (null_labelling u))` by
       SRW_TAC [][lSIMPLE_ALPHA, FV_null_labelling] THEN
  SRW_TAC [numSimps.ARITH_ss]
          [SUB_THM, lSUB_THM, FV_null_labelling, null_labelling_def,
           null_labelling_vsubst] THEN
  MATCH_MP_TAC lALPHA_ERASE THEN
  SRW_TAC [][FV_SUB, lFV_SUB, FV_null_labelling]);

val null_labelling_thm = save_thm(
  "null_labelling_thm",
  SIMP_RULE (srw_ss()) [null_labelling_vsubst, lALPHA_ERASE,
                        FV_null_labelling] null_labelling_def);

val label_free_def =
    Define`label_free t = (null_labelling (strip_label t) = t)`;

val strip_null_labelling = store_thm(
  "strip_null_labelling",
  ``!t. strip_label (null_labelling t) = t``,
  HO_MATCH_MP_TAC nc_INDUCTION THEN
  SRW_TAC [][null_labelling_thm, strip_label_thm] THEN
  PROVE_TAC [lemma14a]);

val base_recursion =
    MATCH_MP relationTheory.WF_RECURSION_THM
             (ISPEC ``size : (num + 'a) nc -> num`` prim_recTheory.WF_measure)
val genM =
  ``\f:(num + 'a) nc -> 'b.
        lam_case (var:string -> 'b) (con o OUTR)
                 (\t u. if is_comb t /\ is_const (rator t) /\
                           ISL (dest_const (rator t))
                        then
                          lami (OUTL (dest_const (rator t)))
                               (\s. tolabelled (lam_case ARB ARB ARB
                                    (\v t. [VAR s/v] t) (rand t)))
                               (tolabelled u)
                               (\s. lam_case ARB ARB ARB
                                      (\v t. f ([VAR s/v] t)) (rand t))
                               (f u)
                        else
                          app (tolabelled t) (tolabelled u)
                              (f t) (f u))
                 (\v t. lam (\s. tolabelled ([VAR s/v] t))
                            (\s. f ([VAR s/v] t)))``

val candidate_th =
    BETA_RULE
    (CONJUNCT1 (CONV_RULE EXISTS_UNIQUE_CONV (SPEC genM base_recursion)))

val isl_labelled_consts_impossible = prove(
  ``!P. ~(labelled_term P /\ is_const P /\ ISL (dest_const P))``,
  REPEAT STRIP_TAC THEN
  `?k. P = CON k` by PROVE_TAC [nc_CASES, is_const_thm] THEN
  POP_ASSUM SUBST_ALL_TAC THEN
  FULL_SIMP_TAC (srw_ss()) [labelled_term_con] THEN
  FIRST_X_ASSUM SUBST_ALL_TAC THEN
  FULL_SIMP_TAC (srw_ss()) [dest_const_thm]);

val from_subst_var = prove(
  ``!v x t. [VAR v/x] (fromlabelled t) = fromlabelled ([VAR v/x] t)``,
  SIMP_TAC (srw_ss()) [fromlabelled_subst, fromlabelled_thm]);

val MK_COMB_TAC =
    MATCH_MP_TAC (PROVE []``(x = y) /\ (f = g) ==> (f x = g y)``)

val lterm_RECURSION_WEAK = store_thm(
  "lterm_RECURSION_WEAK",
  ``!con var app lam lami.
       ?hom : 'a lterm -> 'b.
         (!k. hom (CON k) = con k) /\
         (!s. hom (VAR s) = var s) /\
         (!M N. hom (M @@ N) = app M N (hom M) (hom N)) /\
         (!v M. hom (LAM v M) =
                lam (\y. [VAR y/v] M) (\y. hom ([VAR y/v] M))) /\
         (!n v M N.
                hom (LAMi n v M N) =
                lami n (\y. [VAR y/v] M) N (\y. hom ([VAR y/v] M)) (hom N))``,
  SRW_TAC [][LAMi_def, LAM_def, APP_def, CON_def, VAR_def] THEN
  STRIP_ASSUME_TAC candidate_th THEN
  Q.EXISTS_TAC `\x. f (fromlabelled x)` THEN BETA_TAC THEN
  SIMP_TAC (srw_ss()) [labelled_term_rules] THEN
  POP_ASSUM (CONV_TAC o EVERY_CONJ_CONV o STRIP_QUANT_CONV o LHS_CONV o
             REWR_CONV) THEN
  SRW_TAC [][lam_case_thm, combinTheory.o_THM] THENL [
    `labelled_term (fromlabelled M)` by PROVE_TAC [from_ok] THEN
    `?P Q. fromlabelled M = P @@ Q` by PROVE_TAC [is_comb_APP_EXISTS] THEN
    POP_ASSUM SUBST_ALL_TAC THEN
    FULL_SIMP_TAC (srw_ss()) [rator_thm, labelled_app] THEN
    PROVE_TAC [isl_labelled_consts_impossible, is_const_thm],

    SRW_TAC [numSimps.ARITH_ss][relationTheory.RESTRICT_LEMMA, size_thm,
                                prim_recTheory.measure_thm],

    MK_COMB_TAC THEN CONJ_TAC THENL [
      NEW_ELIM_TAC THEN
      SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)
               [DISJ_IMP_THM, lemma14a, FORALL_AND_THM,
                GSYM VAR_def, SUB_MERGE, prim_recTheory.measure_thm,
                relationTheory.RESTRICT_LEMMA, size_thm, fromlabelled_subst,
                fromlabelled_thm],
      AP_TERM_TAC THEN NEW_ELIM_TAC THEN
      SIMP_TAC (srw_ss()) [DISJ_IMP_THM, lemma14a, FORALL_AND_THM,
                           SUB_MERGE, from_subst_var, l14a, GSYM VAR_def]
    ],

    MK_COMB_TAC THEN
    SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)
             [prim_recTheory.measure_thm, relationTheory.RESTRICT_LEMMA,
              size_thm, dest_const_thm] THEN
    NEW_ELIM_TAC THEN
    SIMP_TAC (srw_ss()) [DISJ_IMP_THM, FORALL_AND_THM, lemma14a, l14a,
                         from_subst_var, GSYM VAR_def, SUB_MERGE],

    FULL_SIMP_TAC (srw_ss()) [dest_const_thm, is_const_thm]
  ]);

val lABS_def = Define`lABS (f: string -> 'a lterm) =
                        tolabelled (ABS (fromlabelled o f))`;

val lABS_THM = store_thm(
  "lABS_THM",
  ``!v t. lABS (\u. [VAR u/v] t) = LAM v t``,
  SRW_TAC [][SUB_def, LAM_def, lABS_def, combinTheory.o_DEF,
             fromlabelled_thm, labelled_sub, labelled_term_rules,
             ABS_DEF]);

val lABSi_def =
    Define`lABSi n f M =
             tolabelled (CON (INL n) @@ ABS (fromlabelled o f) @@
                         fromlabelled M)`;

val lABSi_THM = store_thm(
  "lABSi_THM",
  ``!n v M N. lABSi n (\u. [VAR u/v] M) N = LAMi n v M N``,
  SRW_TAC [][SUB_def, LAMi_def, lABSi_def, combinTheory.o_DEF,
             fromlabelled_thm, labelled_sub, labelled_term_rules,
             ABS_DEF]);

val phi_var_t = ``\s:string. VAR s : 'a nc``
val phi_con_t = ``\k:'a. CON k : 'a nc``
val phi_app_t = ``\(t:'a lterm) (u:'a lterm) (rt:'a nc) ru. rt @@ ru``
val phi_lam_t = ``\(tf:string -> 'a lterm) (rf:string -> 'a nc).
                      let v = NEW (FV (lABS tf))
                      in LAM v (rf v)``
val phi_lami_t = ``\n Mf (N:'a lterm) Mrf (Nr: 'a nc).
                      let v = NEW (FV (lABSi n Mf N))
                      in
                        [Nr/v] (Mrf v)``;

val phi_exists  =
    SIMP_RULE (srw_ss()) [lABS_THM, lABSi_THM]
              (BETA_RULE
                 (SPECL [phi_con_t, phi_var_t, phi_app_t, phi_lam_t,
                         phi_lami_t]
                        (INST_TYPE [beta |-> ``:'a nc``]
                                   lterm_RECURSION_WEAK)))

val phi_def = new_specification ("phi_def", ["phi"], phi_exists);

val lsize_def = Define`size t = chap2$size (strip_label t)`;

val lsize_thm = store_thm(
  "lsize_thm",
  ``(!s. size (VAR s : 'a lterm) = 1) /\
    (!k. size (CON k : 'a lterm) = 1) /\
    (!t u. size (t @@ u : 'a lterm) = 1 + size t + size u) /\
    (!v t. size (LAM v t: 'a lterm) = 1 + size t) /\
    (!n v t u. size (LAMi n v t u:'a lterm) = 2 + size t + size u)``,
  SRW_TAC [numSimps.ARITH_ss][lsize_def, strip_label_thm, size_thm]);

val lRENAME_def =
    Define`(lRENAME [] (M:'a lterm) = M) /\
           (lRENAME (h::t) M = lRENAME t ([VAR (FST h)/SND h] M))`;

val lRENAME_var = store_thm(
  "lRENAME_var",
  ``!R s. lRENAME R (VAR s) = VAR (blRENAME R s)``,
  Induct THEN SRW_TAC [][blRENAME_def, lRENAME_def, lSUB_THM, bRENAME_def]);

val lRENAME_con = store_thm(
  "lRENAME_con",
  ``!R k. lRENAME R (CON k) = CON k``,
  Induct THEN SRW_TAC [][blRENAME_def, lRENAME_def, lSUB_THM]);

val lRENAME_app = store_thm(
  "lRENAME_app",
  ``!R t u. lRENAME R (t @@ u) = lRENAME R t @@ lRENAME R u``,
  Induct THEN SRW_TAC [][blRENAME_def, lRENAME_def, lSUB_THM]);

val lRENAME_VARS_def =
    Define`lRENAME_VARS R = { x | MEM x (MAP FST R) } UNION
                            { x | MEM x (MAP SND R) }`

val GSPEC_OR = prove(
  ``{ x | P x \/ Q x } = {x | P x } UNION {x | Q x}``,
  SRW_TAC [][pred_setTheory.EXTENSION]);

val GSPEC_F = prove(
  ``{x | F} = {}``,
  SRW_TAC [][pred_setTheory.EXTENSION]);

val GSPEC_EQ = prove(
  ``{x | x = y} = {y}``,
  SRW_TAC [][pred_setTheory.EXTENSION]);


val FINITE_lRENAME_VARS = store_thm(
  "FINITE_lRENAME_VARS",
  ``!R. FINITE (lRENAME_VARS R)``,
  SIMP_TAC (srw_ss())[lRENAME_VARS_def] THEN Induct THEN
  SRW_TAC [][GSPEC_OR, GSPEC_F, GSPEC_EQ]);

val _ = augment_srw_ss [rewrites [FINITE_lRENAME_VARS]]

val lRENAME_lam = store_thm(
  "lRENAME_lam",
  ``!R v t. ~(v IN lRENAME_VARS R) ==>
            (lRENAME R (LAM v t) = LAM v (lRENAME R t))``,
  Induct THEN SRW_TAC [][lRENAME_def, lSUB_THM, lRENAME_VARS_def]);

val lRENAME_lami = store_thm(
  "lRENAME_lami",
  ``!R n v t u.  ~(v IN lRENAME_VARS R) ==>
                (lRENAME R (LAMi n v t u) =
                 LAMi n v (lRENAME R t) (lRENAME R u))``,
  Induct THEN SRW_TAC [][lRENAME_def, lSUB_THM, lRENAME_VARS_def]);

val vsub_lRENAME = store_thm(
  "vsub_lRENAME",
  ``!t u v. [VAR u/v] t = lRENAME [(u,v)] t``,
  SRW_TAC [][lRENAME_def]);

val lRENAME_lRENAME = store_thm(
  "lRENAME_lRENAME",
  ``!R1 R2 t. lRENAME R1 (lRENAME R2 t) = lRENAME (APPEND R2 R1) t``,
  CONV_TAC SWAP_VARS_CONV THEN Induct THEN
  SRW_TAC [][lRENAME_def]);

val lsize_ignores_renamings = store_thm(
  "lsize_ignores_renamings",
  ``!t R. size (lRENAME R t) = size t``,
  HO_MATCH_MP_TAC lterm_INDUCTION THEN
  SIMP_TAC (srw_ss()) [lRENAME_var, lRENAME_con, lRENAME_app,
                       lsize_thm] THEN CONJ_TAC
  THENL [
    MAP_EVERY Q.X_GEN_TAC [`v`,`t`] THEN REPEAT STRIP_TAC THEN
    Q_TAC (NEW_TAC "z") `v INSERT lRENAME_VARS R UNION FV t` THEN
    `LAM v t = LAM z ([VAR z/v] t)` by SRW_TAC [][lSIMPLE_ALPHA] THEN
    FIRST_X_ASSUM (Q.SPEC_THEN `v` MP_TAC) THEN
    SRW_TAC [][lRENAME_lam, lsize_thm, l14a, vsub_lRENAME,
               lRENAME_lRENAME],
    MAP_EVERY Q.X_GEN_TAC [`v`,`i`,`M`,`N`] THEN REPEAT STRIP_TAC THEN
    Q_TAC (NEW_TAC "z") `v INSERT lRENAME_VARS R UNION FV M` THEN
    `LAMi i v M N = LAMi i z ([VAR z/v] M) N` by
       SRW_TAC [][lSIMPLE_ALPHAi] THEN
    FIRST_X_ASSUM (MP_TAC o SPEC ``v:string``) THEN
    SRW_TAC [][lRENAME_lami, lsize_thm, l14a, vsub_lRENAME,
               lRENAME_lRENAME]
  ]);

val lsize_ignores_vsubsts = store_thm(
  "lsize_ignores_vsubsts",
  ``!t u v. size ([VAR u/v] t) = size (t:'a lterm)``,
  SRW_TAC [][lsize_ignores_renamings, vsub_lRENAME]);

val _ = augment_srw_ss [rewrites [lsize_ignores_vsubsts]]

val lterm_CASES = store_thm(
  "lterm_CASES",
  ``!t. (?s. t = VAR s) \/ (?k. t = CON k) \/
        (?M N. t = M @@ N) \/ (?v M. t = LAM v M) \/
        (?i v M N. t = LAMi i v M N)``,
  HO_MATCH_MP_TAC lterm_INDUCTION THEN
  REPEAT STRIP_TAC THEN REPEAT (POP_ASSUM (K ALL_TAC)) THEN
  PROVE_TAC []);

val FV_phi = store_thm(
  "FV_phi",
  ``!t v. v IN FV (phi t) ==> v IN FV t``,
  HO_MATCH_MP_TAC lterm_INDUCTION THEN
  SRW_TAC [][phi_def] THEN SRW_TAC [][] THENL [
    RES_TAC THEN
    FULL_SIMP_TAC (srw_ss() ++ boolSimps.COND_elim_ss) [lFV_SUB] THEN
    RES_TAC,
    RES_TAC THEN
    FULL_SIMP_TAC (srw_ss() ++ boolSimps.COND_elim_ss) [lFV_SUB] THEN
    PROVE_TAC [],
    FULL_SIMP_TAC (srw_ss() ++ boolSimps.COND_elim_ss) [FV_SUB] THENL [
      PROVE_TAC [],
      RES_TAC THEN
      FULL_SIMP_TAC (srw_ss() ++ boolSimps.COND_elim_ss) [lFV_SUB] THEN
      PROVE_TAC [],
      RES_TAC THEN
      FULL_SIMP_TAC (srw_ss() ++ boolSimps.COND_elim_ss) [lFV_SUB] THEN
      PROVE_TAC [],
      RES_TAC THEN
      FULL_SIMP_TAC (srw_ss() ++ boolSimps.COND_elim_ss) [lFV_SUB] THEN
      PROVE_TAC []
    ]
  ]);

val erase_alpha = prove(
  ``!X v (u:'a nc).
       (!x. x IN FV u ==> x IN X) /\ FINITE X ==>
       (LAM (NEW (X DELETE v)) ([VAR (NEW (X DELETE v))/v] u) = LAM v u)``,
  REPEAT STRIP_TAC THEN NEW_ELIM_TAC THEN
  ASM_SIMP_TAC (srw_ss()) [DISJ_IMP_THM, FORALL_AND_THM, lemma14a] THEN
  PROVE_TAC [SIMPLE_ALPHA]);

val phi_vsubst_commutes = store_thm(
  "phi_vsubst_commutes",
  ``!t v w. phi ([VAR v/w] t) = [VAR v/w] (phi t)``,
  GEN_TAC THEN
  completeInduct_on `size t` THEN
  FULL_SIMP_TAC (srw_ss()) [AND_IMP_INTRO, GSYM RIGHT_FORALL_IMP_THM] THEN
  Q_TAC SUFF_TAC
        `!t u w. (v = size t) ==> (phi ([VAR u/w] t) = [VAR u/w] (phi t))`
        THEN1 PROVE_TAC [] THEN
  SRW_TAC [][] THEN
  Q.SPEC_THEN `t` (REPEAT_TCL STRIP_THM_THEN SUBST_ALL_TAC) lterm_CASES THEN
  SRW_TAC [numSimps.ARITH_ss] [SUB_THM, lSUB_THM, phi_def, lsize_thm] THENL [
    SIMP_TAC (srw_ss()) [erase_alpha, FV_phi] THEN
    Q_TAC (NEW_TAC "z") `FV M UNION {u;w;v}` THEN
    `LAM v M = LAM z ([VAR z/v] M)` by SRW_TAC [][lSIMPLE_ALPHA] THEN
    `LAM v (phi M) = LAM z ([VAR z/v] (phi M))` by
       PROVE_TAC [SIMPLE_ALPHA, FV_phi] THEN
    SRW_TAC [numSimps.ARITH_ss][SUB_THM, lSUB_THM, phi_def, lsize_thm] THEN
    MATCH_MP_TAC (GSYM ALPHA) THEN
    NEW_ELIM_TAC THEN
    SIMP_TAC (srw_ss()) [lemma14a, DISJ_IMP_THM, FORALL_AND_THM,
                         lFV_SUB_IMAGE, RENAME_blRENAME, FV_SUB_IMAGE,
                         VNAME_DEF] THEN
    PROVE_TAC [FV_phi],

    `[phi N / NEW (FV M DELETE v UNION FV N)]
       ([VAR (NEW (FV M DELETE v UNION FV N))/v] (phi M)) =
     [phi N/v] (phi M)` by
       (NEW_ELIM_TAC THEN
        SIMP_TAC (srw_ss()) [DISJ_IMP_THM, FORALL_AND_THM, lemma14a,
                             RIGHT_AND_OVER_OR] THEN
        PROVE_TAC [lemma15a, FV_phi]) THEN
    POP_ASSUM SUBST_ALL_TAC THEN
    Q_TAC (NEW_TAC "z") `{u;v;w} UNION FV M` THEN
    `LAMi i v M N = LAMi i z ([VAR z/v] M) N` by
       SRW_TAC [][lSIMPLE_ALPHAi] THEN
    SRW_TAC [numSimps.ARITH_ss][lSUB_THM, phi_def, lsize_thm] THEN
    NEW_ELIM_TAC THEN
    SIMP_TAC (srw_ss()) [DISJ_IMP_THM, FORALL_AND_THM, lemma14a,
                         RIGHT_AND_OVER_OR] THEN
    CONJ_TAC THENL [
      REPEAT STRIP_TAC THEN
      `~(v' IN FV ([VAR u/w] ([VAR z/v] (phi M))))` by
          (FULL_SIMP_TAC (srw_ss()) [lFV_SUB_IMAGE, RENAME_blRENAME,
                                     FV_SUB_IMAGE, VNAME_DEF] THEN
           PROVE_TAC [FV_phi]) THEN
      ASM_SIMP_TAC (srw_ss()) [lemma15a] THEN
      MATCH_MP_TAC (GSYM GENERAL_SUB_COMMUTE) THEN
      SIMP_TAC (srw_ss()) [] THEN PROVE_TAC [FV_phi],
      REPEAT STRIP_TAC THEN MATCH_MP_TAC (GSYM GENERAL_SUB_COMMUTE) THEN
      SIMP_TAC (srw_ss()) [] THEN PROVE_TAC [FV_phi]
    ]
  ]);

val lami_case = prove(
  ``[phi N/NEW (FV M DELETE v UNION FV N)]
       ([VAR (NEW (FV M DELETE v UNION FV N))/v] (phi M)) =
    [phi N/v] (phi M)``,
  NEW_ELIM_TAC THEN
  SIMP_TAC (srw_ss()) [DISJ_IMP_THM, FORALL_AND_THM, lemma14a,
                       RIGHT_AND_OVER_OR] THEN
  PROVE_TAC [lemma15a, FV_phi]);

val phi_thm = save_thm(
  "phi_thm",
  SIMP_RULE (srw_ss()) [erase_alpha, phi_vsubst_commutes, FV_phi,
                        lami_case] phi_def);

val (lcompat_closure_rules, lcompat_closure_ind, lcompat_closure_cases) =
    Hol_reln`(!x y. R x y ==> lcompat_closure R x y) /\
             (!z x y. lcompat_closure R x y ==>
                      lcompat_closure R (z @@ x) (z @@ y)) /\
             (!z x y. lcompat_closure R x y ==>
                      lcompat_closure R (x @@ z) (y @@ z)) /\
             (!v x y. lcompat_closure R x y ==>
                      lcompat_closure R (LAM v x) (LAM v y)) /\
             (!v n z x y.
                      lcompat_closure R x y ==>
                      lcompat_closure R (LAMi n v x z) (LAMi n v y z)) /\
             (!v n z x y.
                      lcompat_closure R x y ==>
                      lcompat_closure R (LAMi n v z x) (LAMi n v z y))`;

val lterm_DISTINCT = store_thm(
  "lterm_DISTINCT",
  ``(!s k. ~(VAR s = CON k : 'a lterm)) /\
    (!s x y. ~(VAR s = x @@ y : 'a lterm)) /\
    (!s v t. ~(VAR s = LAM v t : 'a lterm)) /\
    (!s v n t u. ~(VAR s = LAMi n v t u : 'a lterm)) /\
    (!k x y. ~(CON k = x @@ y : 'a lterm)) /\
    (!k v t. ~(CON k = LAM v t : 'a lterm)) /\
    (!k v n t u. ~(CON k = LAMi n v t u : 'a lterm)) /\
    (!x y v t. ~(x @@ y = LAM v t : 'a lterm)) /\
    (!x y v n t u. ~(x @@ y = LAMi n v t u : 'a lterm)) /\
    (!v t v' n t' u. ~(LAM v t = LAMi n v' t' u' : 'a lterm))``,
  SRW_TAC [][VAR_def, CON_def, APP_def, LAM_def, LAMi_def] THEN
  REPEAT STRIP_TAC THEN POP_ASSUM (ASSUME_TAC o AP_TERM ``fromlabelled``) THEN
  FULL_SIMP_TAC (srw_ss()) [labelled_term_rules] THEN
  `labelled_term (CON (INL n) @@ LAM v (fromlabelled t))` by
     PROVE_TAC [from_ok] THEN
  FULL_SIMP_TAC (srw_ss()) [labelled_app, labelled_term_con]);

val _ = augment_srw_ss [rewrites [lterm_DISTINCT]]

val lterm_INJECTIVITY_LEMMA1 = store_thm(
  "lterm_INJECTIVITY_LEMMA1",
  ``!v1 v2 t1 (t2:'a lterm).
        (LAM v1 t1 = LAM v2 t2) ==> (t2 = [VAR v2/v1] t1)``,
  PROVE_TAC [lterm_INJECTIVITY, l14a]);

val lterm_INJECTIVITY_LEMMA1i = store_thm(
  "lterm_INJECTIVITY_LEMMA1i",
  ``!v1 v2 n1 n2 t1 t2 u1 u2.
        (LAMi n1 v1 t1 u1 = LAMi n2 v2 t2 u2) ==>
        (u1 = u2) /\ (n1 = n2) /\ (t2 = [VAR v2/v1]t1)``,
  PROVE_TAC [lterm_INJECTIVITY, l14a]);

val lterm_LAM_VAR_INJECTIVE = store_thm(
  "lterm_LAM_VAR_INJECTIVE",
  ``!v t1 t2:'a lterm. (LAM v t1 = LAM v t2) = (t1 = t2)``,
  SRW_TAC [][EQ_IMP_THM] THEN
  IMP_RES_TAC lterm_INJECTIVITY_LEMMA1 THEN
  SRW_TAC [][l14a]);

val _ = augment_srw_ss [rewrites [lterm_LAM_VAR_INJECTIVE]]


val lterm_LAM_INJ_ALPHA_FV = store_thm(
  "lterm_LAM_INJ_ALPHA_FV",
  ``!v1 v2 t1 (t2:'a lterm).
        (LAM v1 t1 = LAM v2 t2) /\ ~(v1 = v2) ==>
        ~(v1 IN FV t2) /\ ~(v2 IN FV t1)``,
  REPEAT STRIP_TAC THEN
  FIRST_ASSUM (ASSUME_TAC o Q.AP_TERM `FV`) THEN
  FULL_SIMP_TAC (srw_ss()) [pred_setTheory.EXTENSION] THEN PROVE_TAC []);

val lterm_LAM_INJ_ALPHA_FVi = store_thm(
  "lterm_LAM_INJ_ALPHA_FVi",
  ``!n1 n2 v1 v2 t1 t2 u1 u2.
        (LAMi n1 v1 t1 u1 = LAMi n2 v2 t2 u2) /\ ~(v1 = v2) ==>
        ~(v1 IN FV t2) /\ ~(v2 IN FV t1)``,
  REPEAT STRIP_TAC THEN
  `!z. FV ([VAR z/v1]t1) = FV ([VAR z/v2]t2)`
     by PROVE_TAC [lterm_INJECTIVITY] THEN POP_ASSUM MP_TAC THEN
  ASM_SIMP_TAC (srw_ss() ++ boolSimps.COND_elim_ss)
               [pred_setTheory.EXTENSION, lFV_SUB] THEN PROVE_TAC []);

val strip_label_eq = store_thm(
  "strip_label_eq",
  ``!M. (!x y. (strip_label M = x @@ y) =
                   (?x' y'. (M = x' @@ y') /\ (strip_label x' = x) /\
                            (strip_label y' = y)) \/
                   (?v n t u. (M = LAMi n v t u) /\
                              (LAM v (strip_label t) = x) /\
                              (strip_label u = y))) /\
        (!s. (strip_label M = VAR s) = (M = VAR s)) /\
        (!k. (strip_label M = CON k) = (M = CON k)) /\
        (!v t. (strip_label M = LAM v t) = ?t'. (M = LAM v t') /\
                                                (strip_label t' = t))``,
  GEN_TAC THEN
  Q.SPEC_THEN `M` STRUCT_CASES_TAC lterm_CASES THEN
  SRW_TAC [][strip_label_thm, EQ_IMP_THM] THENL [
    Q.EXISTS_TAC `[VAR v'/v] M'` THEN CONJ_TAC THENL [
      Cases_on `v = v'` THEN1 PROVE_TAC [l14a] THEN
      PROVE_TAC [LAM_INJ_ALPHA_FV, FV_strip_label, lSIMPLE_ALPHA],
      PROVE_TAC [INJECTIVITY_LEMMA1, strip_label_vsubst_commutes]
    ],
    IMP_RES_TAC lterm_INJECTIVITY_LEMMA1 THEN
    ASM_SIMP_TAC (srw_ss()) [GSYM strip_label_vsubst_commutes] THEN
    MATCH_MP_TAC ALPHA THEN SRW_TAC [][FV_strip_label] THEN
    PROVE_TAC [lterm_LAM_INJ_ALPHA_FV],
    PROVE_TAC [],
    IMP_RES_TAC lterm_INJECTIVITY_LEMMA1i THEN
    ASM_SIMP_TAC (srw_ss()) [GSYM strip_label_vsubst_commutes] THEN
    MATCH_MP_TAC ALPHA THEN SRW_TAC [][FV_strip_label] THEN
    PROVE_TAC [lterm_LAM_INJ_ALPHA_FVi],
    PROVE_TAC [lterm_INJECTIVITY_LEMMA1i]
  ]);

val strip_label_subst = store_thm(
  "strip_label_subst",
  ``!t u v. strip_label ([u/v] t) = [strip_label u/v] (strip_label t)``,
  HO_MATCH_MP_TAC lterm_INDUCTION THEN
  SIMP_TAC (srw_ss()) [lSUB_THM, strip_label_thm, SUB_THM] THEN
  REPEAT CONJ_TAC THENL [
    SRW_TAC [][lSUB_THM, SUB_THM, strip_label_thm],
    MAP_EVERY Q.X_GEN_TAC [`v`, `t`] THEN STRIP_TAC THEN
    MAP_EVERY Q.X_GEN_TAC [`u`, `x`] THEN
    Q_TAC (NEW_TAC "z") `{v;x} UNION FV t UNION FV u` THEN
    `LAM v t = LAM z ([VAR z/v] t)` by SRW_TAC [][lSIMPLE_ALPHA] THEN
    `LAM v (strip_label t) = LAM z ([VAR z/v] (strip_label t))` by
       SRW_TAC [][SIMPLE_ALPHA, FV_strip_label] THEN
    ASM_SIMP_TAC (srw_ss()) [SUB_THM, lSUB_THM, strip_label_thm,
                             FV_strip_label, strip_label_vsubst_commutes],
    MAP_EVERY Q.X_GEN_TAC [`v`,`i`,`M`,`N`] THEN STRIP_TAC THEN
    MAP_EVERY Q.X_GEN_TAC [`u`,`x`] THEN
    Q_TAC (NEW_TAC "z") `{v;x} UNION FV M UNION FV u` THEN
    `LAMi i v M N = LAMi i z ([VAR z/v] M) N` by
       SRW_TAC [][lSIMPLE_ALPHAi] THEN
    `LAM v (strip_label M) = LAM z ([VAR z/v] (strip_label M))` by
       SRW_TAC [][SIMPLE_ALPHA, FV_strip_label] THEN
    ASM_SIMP_TAC (srw_ss()) [SUB_THM, lSUB_THM, strip_label_thm,
                             FV_strip_label, strip_label_vsubst_commutes]
  ]);

val beta_matched = store_thm(
  "beta_matched",
  ``!M' N. beta (strip_label M') N ==>
           ?N'. (beta0 RUNION beta1) M' N' /\ (N = strip_label N')``,
  REPEAT STRIP_TAC THEN
  `?v Mbody Marg. (strip_label M' = LAM v Mbody @@ Marg) /\
                  (N = [Marg/v]Mbody)` by PROVE_TAC [beta_def] THEN
  `(?lamM' Marg'. (M' = lamM' @@ Marg') /\ (strip_label lamM' = LAM v Mbody) /\
                  (strip_label Marg' = Marg)) \/
   (?n Mbody' Marg'. (M' = LAMi n v Mbody' Marg') /\
                     (strip_label Mbody' = Mbody) /\
                     (strip_label Marg' = Marg))` by
     (FULL_SIMP_TAC (srw_ss()) [strip_label_eq] THEN
      `Mbody = [VAR v/v'] (strip_label t)` by
         PROVE_TAC [INJECTIVITY_LEMMA1] THEN
      MAP_EVERY Q.EXISTS_TAC [`n`, `[VAR v/v'] t`, `u`] THEN
      ASM_SIMP_TAC (srw_ss()) [strip_label_vsubst_commutes] THEN
      Cases_on `v = v'` THEN1 SRW_TAC [][l14a] THEN
      MATCH_MP_TAC lSIMPLE_ALPHAi THEN
      PROVE_TAC [LAM_INJ_ALPHA_FV, FV_strip_label])
   THENL [
     `?Mbody'. (lamM' = LAM v Mbody') /\ (strip_label Mbody' = Mbody)` by
         PROVE_TAC [strip_label_eq] THEN
     Q.EXISTS_TAC `[Marg'/v]Mbody'` THEN
     SRW_TAC [][relationTheory.RUNION, beta0_def, beta1_def, strip_label_subst] THEN
     PROVE_TAC [],

     Q.EXISTS_TAC `[Marg'/v]Mbody'` THEN
     SRW_TAC [][relationTheory.RUNION, beta0_def, beta1_def, strip_label_subst] THEN
     PROVE_TAC []
   ]);

val lcc_beta_FV = store_thm(
  "lcc_beta_FV",
  ``!M N. lcompat_closure (beta0 RUNION beta1) M N ==>
          !x. x IN FV N ==> x IN FV M``,
  HO_MATCH_MP_TAC lcompat_closure_ind THEN
  SRW_TAC [][relationTheory.RUNION, beta0_def, beta1_def] THEN
  TRY (PROVE_TAC []) THEN
  FULL_SIMP_TAC (srw_ss() ++ boolSimps.COND_elim_ss) [lFV_SUB] THEN
  PROVE_TAC []);

val lGENERAL_SUB_COMMUTE = store_thm(
  "lGENERAL_SUB_COMMUTE",
  ``!(t:'a lterm) M N u v w.
        ~(w = u) /\ ~(w IN FV t) /\ ~(w IN FV M) ==>
         ([M/u] ([N/v] t) = [[M/u] N/w] ([M/u] ([VAR w/v] t)))``,
  SRW_TAC [][SUB_def, fromlabelled_thm, labelled_sub, labelled_term_rules] THEN
  AP_TERM_TAC THEN MATCH_MP_TAC GENERAL_SUB_COMMUTE THEN
  ASM_SIMP_TAC (srw_ss()) [GSYM FV_def]);

val lSUBSTITUTION_LEMMA = store_thm(
  "lSUBSTITUTION_LEMMA",
  ``!t u v M N:'a lterm.
            ~(v = u)  /\ ~(v IN FV M) ==>
            ([M/u] ([N/v] t) = [[M/u]N/v] ([M/u] t))``,
  SRW_TAC [][SUB_def, fromlabelled_thm, labelled_sub, labelled_term_rules,
             FV_def] THEN AP_TERM_TAC THEN
  ASM_SIMP_TAC (srw_ss()) [lemma2_11]);

val lSUB_TWICE_ONE_VAR = store_thm(
  "lSUB_TWICE_ONE_VAR",
  ``!(body:'a lterm) x y v. [x/v] ([y/v] body) = [[x/v] y/v] body``,
  SRW_TAC [][SUB_def, fromlabelled_thm, labelled_sub, labelled_term_rules,
             FV_def] THEN AP_TERM_TAC THEN
  ASM_SIMP_TAC (srw_ss()) [SUB_TWICE_ONE_VAR]);

val lcc_beta_lemma = prove(
  ``!N. (!s. lcompat_closure (beta0 RUNION beta1) (VAR s) N = F) /\
        (!k. lcompat_closure (beta0 RUNION beta1) (CON k) N = F)``,
  PURE_ONCE_REWRITE_TAC [lcompat_closure_cases] THEN
  SRW_TAC [][beta0_def, beta1_def, relationTheory.RUNION]);


val lISUB_def = Define`(M ISUB [] = (M:'a lterm)) /\
                      (M ISUB (h::t) = ([FST h/SND h] M) ISUB t)`;

val lFVS_def = Define`(FVS [] = {}) /\
                      (FVS (h::t) = FV (FST h : 'a lterm) UNION FVS t)`;

val _ = type_abbrev("lterm_isub", ``:('a lterm # string) list``);

val lFINITE_FVS = store_thm(
  "lFINITE_FVS",
  ``!R:'a lterm_isub. FINITE (FVS R)``,
  Induct THEN SRW_TAC [][lFVS_def]);

val _ = augment_srw_ss [rewrites [lFINITE_FVS]]

val DOM_thm = store_thm(
  "DOM_thm",
  ``!h t. (DOM [] = {}) /\ (DOM (h::t) = SND h INSERT DOM t)``,
  SIMP_TAC (srw_ss()) [pairTheory.FORALL_PROD, DOM_def,
                       pred_setTheory.EXTENSION]);

val ISUB_thm = store_thm(
  "ISUB_thm",
  ``!M:'a nc. (M ISUB [] = M) /\
              (!h t. M ISUB (h::t) = [FST h/SND h]M ISUB t)``,
  SIMP_TAC (srw_ss()) [pairTheory.FORALL_PROD, ISUB_def]);

val lISUB_THM = store_thm(
  "lISUB_THM",
  ``!R: 'a lterm_isub.
          (!k. CON k ISUB R = CON k) /\
          (!M N. (M @@ N) ISUB R = (M ISUB R) @@ (N ISUB R)) /\
          (!v M. ~(v IN DOM R) /\ ~(v IN FVS R) ==>
                 (LAM v M ISUB R = LAM v (M ISUB R))) /\
          (!n v M N.
                 ~(v IN DOM R) /\ ~(v IN FVS R) ==>
                 (LAMi n v M N ISUB R = LAMi n v (M ISUB R) (N ISUB R)))``,
  Induct THEN
  SRW_TAC [][lISUB_def, DOM_thm, lFVS_def, lSUB_THM]);

val labelled_ISUB_nc_ISUB = store_thm(
  "labelled_ISUB_nc_ISUB",
  ``!(R:'a lterm_isub) M.
       M ISUB R = tolabelled (fromlabelled M ISUB
                              (MAP (fromlabelled ## I) R))``,
  Induct THEN
  ASM_SIMP_TAC (srw_ss())[lISUB_def, ISUB_thm, pairTheory.FORALL_PROD,
                          combinTheory.I_THM, fromlabelled_subst]);

val labelled_isub = prove(
  ``!R M.
       EVERY (\p. labelled_term (FST p)) R /\ labelled_term M ==>
       labelled_term (M ISUB R)``,
  Induct THEN SRW_TAC [][ISUB_def, ISUB_thm, labelled_sub]);

val DOM_lemma = prove(
  ``!R f. DOM (MAP (f ## I) R) = DOM R``,
  Induct THEN SRW_TAC [][DOM_thm, combinTheory.I_THM, pairTheory.PAIR_MAP]);

val FVS_lemma = prove(
  ``!R f. FVS (MAP (fromlabelled ## f) R) = FVS R``,
  Induct THEN
  ASM_SIMP_TAC (srw_ss())[FVS_def, pairTheory.FORALL_PROD, lFVS_def, FV_def]);

val lISUB_SUB_COMMUTE = store_thm(
  "lISUB_SUB_COMMUTE",
  ``!(R:'a lterm_isub) M N x v.
       ~(v IN FV M) /\ ~(v IN FV N) /\ ~(v IN DOM R) /\ ~(v IN FVS R) ==>
       ([N ISUB R/v] ([VAR v/x] M ISUB R) = [N/x] M ISUB R)``,
  SRW_TAC [][labelled_ISUB_nc_ISUB, SUB_def, fromlabelled_thm,
             labelled_term_rules, labelled_sub, labelled_isub,
             listTheory.EVERY_MAP, FV_def] THEN
  AP_TERM_TAC THEN MATCH_MP_TAC ISUB_SUB_COMMUTE THEN
  SRW_TAC [][DOM_lemma, FVS_lemma]);

val lSUB_ISUB_SINGLETON = store_thm(
  "lSUB_ISUB_SINGLETON",
  ``!(t:'a lterm) u v. [u/v] t = t ISUB [(u,v)]``,
  SRW_TAC [][lISUB_def]);

val lISUB_APPEND = store_thm(
  "lISUB_APPEND",
  ``!R1 (R2:'a lterm_isub) t. (t ISUB R1) ISUB R2 = t ISUB APPEND R1 R2``,
  Induct THEN SRW_TAC [][lISUB_def]);

val lbeta_isub = store_thm(
  "lbeta_isub",
  ``!M N. (beta0 RUNION beta1) M N ==>
          !R. (beta0 RUNION beta1) (M ISUB R) (N ISUB R)``,
  SRW_TAC [][beta0_def, beta1_def, relationTheory.RUNION] THENL [
    DISJ1_TAC THEN
    Q_TAC (NEW_TAC "z")
      `{v} UNION FVS R UNION DOM R UNION FV t UNION FV u` THEN
    `LAMi n v t u = LAMi n z ([VAR z/v]t) u` by
       SRW_TAC [][lSIMPLE_ALPHAi] THEN
    SRW_TAC [][lISUB_THM] THEN
    MAP_EVERY Q.EXISTS_TAC [`n`, `z`, `[VAR z/v] t ISUB R`, `u ISUB R`] THEN
    ASM_SIMP_TAC (srw_ss()) [] THEN
    MATCH_MP_TAC (GSYM lISUB_SUB_COMMUTE) THEN ASM_REWRITE_TAC [],
    DISJ2_TAC THEN
    Q_TAC (NEW_TAC "z")
       `{v} UNION FV t UNION FV u UNION DOM R UNION FVS R` THEN
    `LAM v t = LAM z ([VAR z/v] t)` by SRW_TAC [][lSIMPLE_ALPHA] THEN
    SRW_TAC [][lISUB_THM] THEN
    MAP_EVERY Q.EXISTS_TAC [`z`, `[VAR z/v] t ISUB R`] THEN
    ASM_SIMP_TAC (srw_ss()) [] THEN
    MATCH_MP_TAC (GSYM lISUB_SUB_COMMUTE) THEN ASM_REWRITE_TAC []
  ]);

val lcc_beta_isub = store_thm(
  "lcc_beta_isub",
  ``!M N. lcompat_closure (beta0 RUNION beta1) M N ==>
          !R. lcompat_closure (beta0 RUNION beta1) (M ISUB R) (N ISUB R)``,
  HO_MATCH_MP_TAC lcompat_closure_ind THEN SRW_TAC [][lISUB_THM] THENL [
    PROVE_TAC [lcompat_closure_rules, lbeta_isub],
    PROVE_TAC [lcompat_closure_rules],
    PROVE_TAC [lcompat_closure_rules],

    Q_TAC (NEW_TAC "z")
       `{v} UNION FV M UNION FV N UNION FVS R UNION DOM R` THEN
    `(LAM v M = LAM z ([VAR z/v] M)) /\ (LAM v N = LAM z ([VAR z/v] N))` by
        SRW_TAC [][lSIMPLE_ALPHA] THEN
    SRW_TAC [][lISUB_THM] THEN
    REWRITE_TAC [lSUB_ISUB_SINGLETON, lISUB_APPEND] THEN
    PROVE_TAC [lcompat_closure_rules],

    Q_TAC (NEW_TAC "var")
       `v INSERT FV M UNION FV N UNION FV z UNION FVS R UNION DOM R` THEN
    `(LAMi n v M z = LAMi n var ([VAR var/v]M) z) /\
     (LAMi n v N z = LAMi n var ([VAR var/v]N) z)` by
       SRW_TAC [][lSIMPLE_ALPHAi] THEN
    SRW_TAC [][lISUB_THM] THEN
    REWRITE_TAC [lSUB_ISUB_SINGLETON, lISUB_APPEND] THEN
    PROVE_TAC [lcompat_closure_rules],

    Q_TAC (NEW_TAC "var")
       `v INSERT FV M UNION FV N UNION FV z UNION FVS R UNION DOM R` THEN
    `(LAMi n v z M = LAMi n var ([VAR var/v]z) M) /\
     (LAMi n v z N = LAMi n var ([VAR var/v]z) N)` by
       SRW_TAC [][lSIMPLE_ALPHAi] THEN
    SRW_TAC [][lISUB_THM] THEN
    PROVE_TAC [lcompat_closure_rules]
  ]);

val lcc_beta_subst = store_thm(
  "lcc_beta_subst",
  ``!M N P v. lcompat_closure (beta0 RUNION beta1) M N ==>
              lcompat_closure (beta0 RUNION beta1) ([P/v]M) ([P/v]N)``,
  PROVE_TAC [lcc_beta_isub, lSUB_ISUB_SINGLETON]);

val lcc_beta_LAM = store_thm(
  "lcc_beta_LAM",
  ``!v t N. lcompat_closure (beta0 RUNION beta1) (LAM v t) N =
            ?N0. (N = LAM v N0) /\
                 lcompat_closure (beta0 RUNION beta1) t N0``,
  REPEAT GEN_TAC THEN
  CONV_TAC (LAND_CONV (REWR_CONV lcompat_closure_cases)) THEN
  SRW_TAC [][beta0_def, beta1_def, relationTheory.RUNION] THEN EQ_TAC THEN
  STRIP_TAC THENL [
    ASM_SIMP_TAC (srw_ss()) [] THEN
    Q.EXISTS_TAC `[VAR v/v'] y` THEN
    `t = [VAR v/v'] x` by PROVE_TAC [lterm_INJECTIVITY_LEMMA1] THEN
    CONJ_TAC THENL [
      Cases_on `v = v'` THEN1 SRW_TAC [][l14a] THEN
      MATCH_MP_TAC lSIMPLE_ALPHA THEN
      `~(v IN FV x)` by PROVE_TAC [lterm_LAM_INJ_ALPHA_FV] THEN
      PROVE_TAC [lcc_beta_FV],
      PROVE_TAC [lcc_beta_subst]
    ],
    PROVE_TAC []
  ]);

val cc_beta_matched = store_thm(
  "cc_beta_matched",
  ``!M N. compat_closure beta M N ==>
          !M'. (M = strip_label M') ==>
               ?N'. lcompat_closure (beta0 RUNION beta1) M' N' /\
                    (N = strip_label N')``,
  HO_MATCH_MP_TAC compat_closure_ind THEN REPEAT CONJ_TAC THENL [
    MAP_EVERY Q.X_GEN_TAC [`M`,`N`] THEN STRIP_TAC THEN
    Q.X_GEN_TAC `M'` THEN STRIP_TAC THEN
    `?N'. (beta0 RUNION beta1) M' N' /\ (N = strip_label N')` by
       PROVE_TAC [beta_matched] THEN
    PROVE_TAC [lcompat_closure_rules],

    MAP_EVERY Q.X_GEN_TAC [`x`, `y`, `f`] THEN STRIP_TAC THEN
    Q.X_GEN_TAC `fx'` THEN STRIP_TAC THEN
    POP_ASSUM (MP_TAC o SYM) THEN
    CONV_TAC (LAND_CONV (SIMP_CONV (srw_ss()) [strip_label_eq])) THEN
    STRIP_TAC THENL [
      `?N0. lcompat_closure (beta0 RUNION beta1) y' N0 /\
            (y = strip_label N0)` by PROVE_TAC [] THEN
      Q.EXISTS_TAC `x' @@ N0` THEN
      ASM_SIMP_TAC (srw_ss()) [lcompat_closure_rules, strip_label_thm],

      `?N0. lcompat_closure (beta0 RUNION beta1) u N0 /\
            (y = strip_label N0)` by PROVE_TAC [] THEN
      Q.EXISTS_TAC `LAMi n v t N0` THEN
      ASM_SIMP_TAC (srw_ss()) [lcompat_closure_rules, strip_label_thm]
    ],

    MAP_EVERY Q.X_GEN_TAC [`f`, `g`, `x`] THEN STRIP_TAC THEN
    Q.X_GEN_TAC `fx'` THEN DISCH_THEN (MP_TAC o SYM) THEN
    CONV_TAC (LAND_CONV (SIMP_CONV (srw_ss()) [strip_label_eq])) THEN
    STRIP_TAC THENL [
      `?N0. lcompat_closure (beta0 RUNION beta1) x' N0 /\
            (g = strip_label N0)` by PROVE_TAC [] THEN
      Q.EXISTS_TAC `N0 @@ y'` THEN
      ASM_SIMP_TAC (srw_ss()) [lcompat_closure_rules, strip_label_thm],

      `f = strip_label (LAM v t)` by SRW_TAC [][strip_label_thm] THEN
      `?N0. lcompat_closure (beta0 RUNION beta1) (LAM v t) N0 /\
            (g = strip_label N0)` by PROVE_TAC [] THEN
      `?N1. (N0 = LAM v N1) /\ lcompat_closure (beta0 RUNION beta1) t N1` by
         PROVE_TAC [lcc_beta_LAM] THEN
      Q.EXISTS_TAC `LAMi n v N1 u` THEN
      ASM_SIMP_TAC (srw_ss()) [strip_label_thm, lcompat_closure_rules]
    ],

    MAP_EVERY Q.X_GEN_TAC [`M`, `N`, `v`] THEN STRIP_TAC THEN
    Q.X_GEN_TAC `M'` THEN DISCH_THEN  (MP_TAC o SYM) THEN
    SIMP_TAC (srw_ss()) [strip_label_eq] THEN STRIP_TAC THEN
    `?N0. lcompat_closure (beta0 RUNION beta1) t' N0 /\
          (N = strip_label N0)` by PROVE_TAC [] THEN
    Q.EXISTS_TAC `LAM v N0` THEN
    ASM_SIMP_TAC (srw_ss()) [strip_label_thm, lcompat_closure_rules]
  ]);

val lemma11_1_6i = store_thm(
  "lemma11_1_6i",
  ``!M' N. reduction beta (strip_label M') N ==>
           ?N'. RTC (lcompat_closure (beta0 RUNION beta1)) M' N' /\
                (N = strip_label N')``,
  SIMP_TAC (srw_ss()) [reduction_def] THEN
  Q_TAC SUFF_TAC
        `!M N. RTC (compat_closure beta) M N ==>
               !M'. (M = strip_label M') ==>
                    ?N'. RTC (lcompat_closure (beta0 RUNION beta1)) M' N' /\
                         (N = strip_label N')` THEN1 PROVE_TAC [] THEN
  HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THEN CONJ_TAC THEN
  PROVE_TAC [relationTheory.RTC_RULES, cc_beta_matched]);

val lcc_beta_matching_beta = store_thm(
  "lcc_beta_matching_beta",
  ``!M' N'. lcompat_closure (beta0 RUNION beta1) M' N' ==>
            compat_closure beta (strip_label M') (strip_label N')``,
  HO_MATCH_MP_TAC lcompat_closure_ind THEN
  SRW_TAC [][strip_label_thm] THEN1
    (Q_TAC SUFF_TAC `beta (strip_label M') (strip_label N')` THEN1
        PROVE_TAC [compat_closure_rules] THEN
     FULL_SIMP_TAC (srw_ss()) [beta0_def, beta1_def, relationTheory.RUNION,
                               strip_label_thm, beta_def,
                               strip_label_subst] THEN PROVE_TAC []) THEN
  PROVE_TAC [compat_closure_rules]);

val lemma11_1_6ii = store_thm(
  "lemma11_1_6ii",
  ``!M' N'.
      RTC (lcompat_closure (beta0 RUNION beta1)) M' N' ==>
      reduction beta (strip_label M') (strip_label N')``,
  HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THEN
  PROVE_TAC [reduction_rules, lcc_beta_matching_beta]);

val lemma11_1_7i = store_thm(
  "lemma11_1_7i",
  ``!M N. phi ([N/x] M) = [phi N/x](phi M)``,
  HO_MATCH_MP_TAC lterm_INDUCTION THEN
  SIMP_TAC (srw_ss()) [phi_thm, lSUB_THM, SUB_THM] THEN REPEAT CONJ_TAC THENL [
    SRW_TAC [][phi_thm, lSUB_THM, SUB_THM],
    MAP_EVERY Q.X_GEN_TAC [`v`,`M`] THEN STRIP_TAC THEN Q.X_GEN_TAC `N` THEN
    Q_TAC (NEW_TAC "z") `{v;x} UNION FV M UNION FV N` THEN
    `~(z IN FV (phi M)) /\ ~(z IN FV (phi N))` by PROVE_TAC [FV_phi] THEN
    `LAM v M = LAM z ([VAR z/v] M)` by SRW_TAC [][lSIMPLE_ALPHA] THEN
    `LAM v (phi M) = LAM z ([VAR z/v] (phi M))` by
       SRW_TAC [][SIMPLE_ALPHA] THEN
    SRW_TAC [][SUB_THM, lSUB_THM, phi_thm, phi_vsubst_commutes],

    MAP_EVERY Q.X_GEN_TAC [`v`,`i`,`M`,`M'`] THEN STRIP_TAC THEN
    Q.X_GEN_TAC `N` THEN
    Q_TAC (NEW_TAC "z") `{v;x} UNION FV M UNION FV M' UNION FV N` THEN
    `~(z IN FV (phi M)) /\ ~(z IN FV (phi M')) /\ ~(z IN FV (phi N))` by
       PROVE_TAC [FV_phi] THEN
    `LAMi i v M M' = LAMi i z ([VAR z/v] M) M'` by
       SRW_TAC [][lSIMPLE_ALPHAi] THEN
    SRW_TAC [][phi_thm, lSUB_THM, phi_vsubst_commutes] THEN
    MATCH_MP_TAC (GSYM GENERAL_SUB_COMMUTE) THEN
    ASM_SIMP_TAC (srw_ss()) []
  ]);

val lcc_beta_phi_matched = store_thm(
  "lcc_beta_phi_matched",
  ``!M N. lcompat_closure (beta0 RUNION beta1) M N ==>
          reduction beta (phi M) (phi N)``,
  HO_MATCH_MP_TAC lcompat_closure_ind THEN
  SRW_TAC [][phi_thm] THENL [
    FULL_SIMP_TAC (srw_ss()) [beta0_def, beta1_def,
                              relationTheory.RUNION]
    THENL [
      SRW_TAC [][phi_thm, lemma11_1_7i, reduction_rules],
      Q_TAC SUFF_TAC `beta (phi (LAM v t @@ u)) (phi ([u/v] t))` THEN1
        PROVE_TAC [reduction_rules] THEN
      SRW_TAC [][phi_thm, lemma11_1_7i, beta_def] THEN PROVE_TAC []
    ],

    PROVE_TAC [reduction_rules],
    PROVE_TAC [reduction_rules],
    PROVE_TAC [reduction_rules],
    PROVE_TAC [reduction_beta_subst],
    PROVE_TAC [lemma3_8]
  ]);

val lemma11_1_7ii = store_thm(
  "lemma11_1_7ii",
  ``!M N. RTC (lcompat_closure (beta0 RUNION beta1)) M N ==>
          reduction beta (phi M) (phi N)``,
  HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THEN
  PROVE_TAC [reduction_rules, lcc_beta_phi_matched]);

val lemma11_1_8 = store_thm(
  "lemma11_1_8",
  ``!M. reduction beta (strip_label M) (phi M)``,
  HO_MATCH_MP_TAC lterm_INDUCTION THEN
  SRW_TAC [][phi_thm, strip_label_thm, reduction_rules] THENL [
    PROVE_TAC [reduction_rules],
    PROVE_TAC [reduction_rules, l14a],
    `beta (LAM v (strip_label M) @@ strip_label M')
          ([strip_label M'/v] (strip_label M))` by PROVE_TAC [beta_def] THEN
    `reduction beta ([strip_label M'/v] (strip_label M))
                    ([phi M'/v] (strip_label M))` by PROVE_TAC [lemma3_8] THEN
    `reduction beta ([phi M'/v] (strip_label M))
                    ([phi M'/v] (phi M))` by
        PROVE_TAC [reduction_beta_subst, l14a] THEN
    PROVE_TAC [reduction_rules]
  ]);

val phi_null_labelling = store_thm(
  "phi_null_labelling",
  ``!M. phi (null_labelling M) = M``,
  HO_MATCH_MP_TAC nc_INDUCTION THEN
  SRW_TAC [][null_labelling_thm, phi_thm] THEN
  PROVE_TAC [lemma14a]);

val can_index_redex = store_thm(
  "can_index_redex",
  ``!M N. compat_closure beta M N ==>
          ?M'. (strip_label M' = M) /\ (phi M' = N)``,
  HO_MATCH_MP_TAC compat_closure_ind THEN REPEAT CONJ_TAC THENL [
    MAP_EVERY Q.X_GEN_TAC [`M`,`N`] THEN
    SIMP_TAC (srw_ss()) [beta_def, GSYM LEFT_FORALL_IMP_THM] THEN
    MAP_EVERY Q.X_GEN_TAC [`x`,`body`,`arg`] THEN SRW_TAC [][] THEN
    Q.EXISTS_TAC `LAMi 0 x (null_labelling body) (null_labelling arg)` THEN
    SIMP_TAC (srw_ss()) [strip_label_thm, phi_thm, strip_null_labelling,
                         phi_null_labelling],
    MAP_EVERY Q.X_GEN_TAC [`M`,`N`,`z`] THEN SRW_TAC [][] THEN
    Q.EXISTS_TAC `null_labelling z @@ M'` THEN
    ASM_SIMP_TAC (srw_ss()) [strip_label_thm, phi_thm,
                             strip_null_labelling, phi_null_labelling],
    MAP_EVERY Q.X_GEN_TAC [`M`,`N`,`z`] THEN SRW_TAC [][] THEN
    Q.EXISTS_TAC `M' @@ null_labelling z` THEN
    ASM_SIMP_TAC (srw_ss()) [strip_label_thm, phi_thm,
                             strip_null_labelling, phi_null_labelling],
    MAP_EVERY Q.X_GEN_TAC [`M`,`N`,`v`] THEN SRW_TAC [][] THEN
    Q.EXISTS_TAC `LAM v M'` THEN
    ASM_SIMP_TAC (srw_ss()) [strip_label_thm, phi_thm,
                             strip_null_labelling, phi_null_labelling]
  ]);

val strip_lemma = store_thm(
  "strip_lemma",
  ``!M M' N. compat_closure beta M M' /\
             reduction beta M N ==>
             ?N'. reduction beta M' N' /\ reduction beta N N'``,
  REPEAT STRIP_TAC THEN
  `?Mtilde. (strip_label Mtilde = M) /\ (phi Mtilde = M')` by
     PROVE_TAC [can_index_redex] THEN
  `?Ntilde. (N = strip_label Ntilde) /\
            RTC (lcompat_closure (beta0 RUNION beta1)) Mtilde Ntilde` by
     PROVE_TAC [lemma11_1_6i] THEN
  `reduction beta M' (phi Ntilde)` by PROVE_TAC [lemma11_1_7ii] THEN
  `reduction beta N (phi Ntilde)` by PROVE_TAC [lemma11_1_8] THEN
  PROVE_TAC []);

val beta_CR_2 = store_thm(
  "beta_CR_2",
  ``CR beta``,
  SIMP_TAC (srw_ss())[CR_def, diamond_property_def] THEN
  Q_TAC SUFF_TAC
        `!M M1. RTC (compat_closure beta) M M1 ==>
                !M2. reduction beta M M2 ==>
                     ?M3. reduction beta M1 M3 /\ reduction beta M2 M3`
        THEN1 PROVE_TAC [reduction_def] THEN
  HO_MATCH_MP_TAC relationTheory.RTC_INDUCT THEN
  PROVE_TAC [reduction_rules, strip_lemma]);

val _ = export_rewrites ["tofrom_inverse", "fromto_inverse", "from_ok",
                         "lFV_THM", "lFINITE_FV", "FINITE_lRENAME_VARS",
                         "lsize_ignores_vsubsts",
                         "lterm_DISTINCT", "lterm_LAM_VAR_INJECTIVE",
                         "lFINITE_FVS"];

val _ = export_theory ();

