(*---------------------------------------------------------------------------*
 * Defining functions.                                                       *
 *---------------------------------------------------------------------------*)

structure Defn :> Defn =
struct

open HolKernel Parse basicHol90Lib;
infixr 3 -->;
infix ## |-> THEN THENL THENC ORELSE ORELSEC THEN_TCL ORELSE_TCL;

   type hol_type = Type.hol_type
   type term = Term.term
   type thm = Thm.thm
   type conv = Abbrev.conv
   type tactic = Abbrev.tactic

fun ERR func mesg = 
  HOL_ERR
    {origin_structure="Defn",
     origin_function=func,
     message = mesg};

val monitoring = ref true;

datatype defn 
   = NONREC  of thm
   | PRIMREC of {eqs:thm, ind:thm}
   | STDREC  of {eqs:thm, ind:thm, R:term, SV:term list}
   | NESTREC of {eqs:thm, ind:thm, R:term, SV:term list,aux:defn}
   | MUTREC  of {eqs:thm, ind:thm, R:term, SV:term list,union:defn};

fun nonrec  (NONREC _)  = true | nonrec _  = false;
fun primrec (PRIMREC _) = true | primrec _ = false;
fun nestrec (NESTREC _) = true | nestrec _ = false;
fun mutrec  (MUTREC _)  = true | mutrec _  = false;

 
(*---------------------------------------------------------------------------
                  Miscellaneous support.
 ---------------------------------------------------------------------------*)

fun drop [] x = x
  | drop (_::t) (_::rst) = drop t rst
  | drop _ _ = raise ERR "drop" "";

fun unzip3 [] = ([],[],[])
  | unzip3 ((x,y,z)::rst) = 
      let val (l1,l2,l3) = unzip3 rst
      in (x::l1, y::l2, z::l3)
      end;

fun func_of_cond_eqn tm =
    #1(strip_comb(#lhs(dest_eq
       (#2 (strip_forall(#2(strip_imp tm)))))));

val prod_tyl =
  end_itlist(fn ty1 => fn ty2 => mk_type{Tyop="prod",Args=[ty1,ty2]});

fun variants FV vlist = 
  fst
    (itlist 
       (fn v => fn (V,W) => 
           let val v' = variant W v
           in (v'::V, v'::W)
           end) vlist ([],FV));

fun dest_atom a = (dest_var a handle HOL_ERR _ => dest_const a);


(*---------------------------------------------------------------------------
         The purpose of pairf is to translate a prospective definition 
         into a completely tupled format. On entry to pairf, we know
         that f is curried, i.e., of type               
 
              f : ty1 -> ... -> tyn -> rangety

 *---------------------------------------------------------------------------*)

fun pairf (false,f,_,args,eqs0) = (eqs0, f, I)
  | pairf (true,f,stem,args,eqs0) =
     let val argtys    = map type_of args
         val unc_argty = prod_tyl argtys
         val range_ty  = type_of (list_mk_comb (f,args))
         val fname = #Name (dest_atom f)
         val f' = mk_var {Name="tupled_"^stem, Ty = unc_argty --> range_ty}
     fun rebuild tm =
      case dest_term tm
       of COMB _ =>
         let val (g,args) = strip_comb tm
             val args' = map rebuild args
         in if (g=f)
            then if (length args < length argtys)  (* partial application *)
                 then let val newvars = map (fn ty => mk_var{Name="a", Ty=ty})
                                            (drop args argtys)
                          val newvars' = variants (free_varsl args') newvars
                      in list_mk_abs(newvars',
                          mk_comb{Rator=f',Rand=list_mk_pair(args' @newvars')})
                      end
                 else mk_comb{Rator=f', Rand=list_mk_pair args'}
            else list_mk_comb(g,args')
         end
       | LAMB{Bvar,Body} => mk_abs{Bvar=Bvar, Body=rebuild Body}
       | _ => tm

     val defvars = 
       Lib.with_flag (Globals.priming, SOME"")
          (variants [f]) 
          (map (fn ty => mk_var{Name="x", Ty=ty}) argtys)

     fun unpair (rules,ind) = 
      let val eq1 = concl(CONJUNCT1 rules handle HOL_ERR _ => rules)
          val fconst = func_of_cond_eqn eq1
          val def = new_definition (stem,
                      mk_eq{lhs=list_mk_comb(f, defvars),
                          rhs=list_mk_comb(fconst, [list_mk_pair defvars])})
          val rules' = Rewrite.PURE_REWRITE_RULE[GSYM def] rules
          val ind' = 
            case ind 
             of NONE => NONE
              | SOME induction =>
                let val P = #Bvar(dest_forall(concl induction))
                    val Qty = itlist (curry Type.-->) argtys Type.bool
                    val Q = mk_primed_var{Name = "P", Ty = Qty}
                    val tm = mk_pabs{varstruct=list_mk_pair defvars,
                               body=list_mk_comb(Q,defvars)}
                    val ind1 = SPEC tm
                         (Rewrite.PURE_REWRITE_RULE [GSYM def] induction)
                in
                 SOME (CONV_RULE(DEPTH_CONV Let_conv.GEN_BETA_CONV) ind1)
                end
      in 
         (rules', ind')
      end
   in
     (rebuild eqs0, f', unpair)
   end;


(*---------------------------------------------------------------------------

     Attempt to define a function, given some input equations. 
     The following cases are handled:

       1. Non-recursive definition, varstructs allowed on lhs.
             -- use standard abbreviation mechanism

       2. Primitive recursive (or non-recursive) over known datatype.
             -- use new_recursive_definition with datatype axiom
                from theTypeBase().

       3. Non-recursive definition, over more complex patterns than 
          allowed in 1 or 2.
             -- use TFL, and automatically eliminate the vacuous
                wellfoundedness requirement.

       4. Recursions (not mutual or nested) that aren't handled by 2. 
             -- use TFL.

       5. Nested recursions.
             -- use TFL. Auxiliary function defined (with TFL), in
                order to allow the termination relation to be deferred.

       6. Mutual recursions.
             -- use TFL. Auxiliary `union' function defined (with
                TFL), from which the specified functions are derived. 
                If the union function is nested, then 5 is called. 

       7. Schematic definitions (must be recursive).
             -- use TFL. Mutual and nested recursions are accepted.

     For 3-7, induction theorems are derived. Also, TFL internally
     processes functions over a single tupled argument, but it is
     convenient for users to give curried definitions, so for 3-7, 
     there is an automatic translation from curried recursion equations 
     into (and back out of) the tupled form.

     A number of primitive definitions may be made in the course of
     defining the specified function. Since these must be stored in
     the current theory, names for the ML bindings of these will be
     invented by "define". Such names will be derived from the name
     of the constant. In the case that the specified function is 
     non-recursive or primitive recursive, the specified equation(s)
     will be added to the current theory under the name of the constant.
     Otherwise, the specified equation(s) will not be stored in the 
     current theory (although underlying definitions used to derive 
     the equations will be). The reasoning behind this is that the user
     will typically want to eliminate termination conditions before 
     storing the equations (and associated induction theorem) in the 
     current theory.

     Of course, schemes are a counter-example to this. For the sake of
     consistency, a scheme definition and its associated induction theorem
     are not stored in the current theory by "define".

 ---------------------------------------------------------------------------*)


local fun is_constructor tm = not (is_var tm orelse is_pair tm);
      fun basic_defn (fname,tm) = new_definition(fname, tm)
      fun dest_atom ac = dest_const ac handle _ => dest_var ac
      fun occurs f = can (find_term (aconv f))
in
fun define stem eqs0 =
 let val _ = if Lexis.ok_identifier stem then () 
             else raise ERR "define" 
                   (String.concat[Lib.quote stem," is not alphanumeric"])
     val eql = map (#2 o strip_forall) (strip_conj eqs0)
     val (lhsl,rhsl) = unzip (map Psyntax.dest_eq eql)
     val (f,args)  = strip_comb (hd lhsl)
     val fname     = #Name(dest_atom f)
     val curried   = not(length args = 1)
     val recursive = exists (occurs f) rhsl
     val fns       = op_mk_set aconv (map (fst o strip_comb) lhsl)
     val mutual    = 1<length fns
     val facts     = TypeBase.theTypeBase()
  
 in
  if mutual 
  then let val {rules, ind, SV, R, union as {rules=r,ind=i,aux,...},...}
              = Tfl.mutual_function facts stem eqs0
       in
        MUTREC {eqs=rules, ind=ind, R=R, SV=SV, 
          union =
             case aux
              of NONE => STDREC{eqs=r,ind=i,R=R,SV=SV}
               | SOME{rules=raux,ind=iaux} =>
                    NESTREC{eqs=r,ind=i,R=R,SV=SV,
                        aux=STDREC{eqs=raux,ind=iaux,R=R,SV=SV}}
          }
       end
  else
   (NONREC (basic_defn (stem,eqs0))  (* try an abbreviation *)
     handle HOL_ERR _ 
     =>
     if Lib.exists is_constructor args
     then case TypeBase.read (#Tyop(Type.dest_type
                  (type_of(first is_constructor args))))
           of NONE => raise ERR "define" "unexpected lhs in definition"
            | SOME tyinfo => 
               let val def = new_recursive_definition
                                {name=stem,def=eqs0,fixity=Parse.Prefix,
                                 rec_axiom=TypeBase.axiom_of tyinfo}
                   val ind = TypeBase.induction_of tyinfo
               in
                 PRIMREC{eqs=def, ind=ind}
               end
     else raise ERR "define" ""
   )
  handle HOL_ERR _  (* not mutual or prim. rec. or simple abbreviation *)
   => 
  let val (unc_eqs,f',inverses) = pairf(curried,f,stem,args,eqs0)
      val fname' = #Name(dest_atom f')
      val (wfrec_res as {WFR,SV,proto_def,extracta,pats})
          = Tfl.wfrec_eqns facts unc_eqs handle e as HOL_ERR _ 
              => (Lib.say"Definition failed.\n"; raise e)
      val (_,_,nestedl) = unzip3 (#extracta wfrec_res)
  in
     if exists (fn x => (x=true)) nestedl  (* nested *)
     then let val {rules,ind,SV, R, aux_rules, aux_ind,...}
                   = Tfl.nested_function facts fname' wfrec_res
          in 
            case inverses (rules, SOME ind)
             of (rules', SOME ind') =>
                  NESTREC {eqs=rules',ind=ind',R=R,SV=SV,
                           aux=STDREC{eqs=aux_rules,ind=aux_ind,
                                      R=R,SV=SV}}
              | _ => raise ERR"define" "bad inverses in nested case"
          end
     else 
     let val {rules,R,SV,full_pats_TCs,...}
               = Tfl.lazyR_def facts fname' wfrec_res
     in
     case hyp rules
      of []     => raise ERR "define" "Empty hyp. after use of TFL"
       | [WF_R] =>   (* non-recursive defn via complex patterns *)
          (let val {Rator=WF,Rand=R} = dest_comb WF_R
               val Rty   = type_of R
               val theta = [Type.alpha |-> hd(#Args(dest_type Rty))]
               val Empty_thm = INST_TYPE theta relationTheory.WF_Empty
               val rules' = #1 (inverses (rules,NONE))
           in 
              NONREC (MATCH_MP (DISCH_ALL rules') Empty_thm)
           end handle HOL_ERR _ => raise ERR"define" "non-rec. TFL call failed")
       | _  => (* recursive, not prim.rec., not mutual, not nested *)
          let val ind = Tfl.mk_induction facts 
                          {fconst=f, R=R, SV=SV,pat_TCs_list=full_pats_TCs}
          in 
            case inverses(rules, SOME ind)
             of (rules', SOME ind') => 
                   STDREC {eqs=rules',ind=ind', R=R, SV=SV}
              | _ => raise ERR "define" "bad inverses in std. case"
          end
     end
  end
 end
end;


fun eqns_of (NONREC th)          = th
  | eqns_of (PRIMREC {eqs, ...}) = eqs
  | eqns_of (STDREC  {eqs, ...}) = eqs
  | eqns_of (NESTREC {eqs, ...}) = eqs
  | eqns_of (MUTREC  {eqs, ...}) = eqs;

fun eqnl_of d = CONJUNCTS (eqns_of d)

fun aux_defn (NESTREC {aux, ...}) = SOME aux
  | aux_defn     _  = NONE;

fun union_defn (MUTREC {union, ...}) = SOME union
  | union_defn     _  = NONE;

fun ind_of (NONREC th)          = NONE
  | ind_of (PRIMREC {ind, ...}) = SOME ind
  | ind_of (STDREC  {ind, ...}) = SOME ind
  | ind_of (NESTREC {ind, ...}) = SOME ind
  | ind_of (MUTREC  {ind, ...}) = SOME ind;


fun parameters (NONREC _)  = []
  | parameters (PRIMREC _) = []
  | parameters (STDREC  {SV, ...}) = SV
  | parameters (NESTREC {SV, ...}) = SV
  | parameters (MUTREC  {SV, ...}) = SV;

fun schematic defn = not(List.null (parameters defn));

fun nUNDISCH n th = if n<1 then th else nUNDISCH (n-1) (UNDISCH th)
 
fun INST_THM theta th =
  let val asl = hyp th
      val th1 = rev_itlist DISCH asl th
      val th2 = INST_TY_TERM theta th1
  in 
   nUNDISCH (length asl) th2
  end;


fun isubst (tmtheta,tytheta) tm = subst tmtheta (inst tytheta tm);

(*
fun name_assoc s [] = NONE
  | name_assoc s (sv::rst) =
     if ((#Name(dest_var sv) = s) handle HOL_ERR _ => false)
     then SOME sv
     else name_assoc s rst;

fun lineup [] SV = []
  | lineup ({redex,residue}::rst) SV =
     let val name = #Name(dest_var redex)
     in
       case name_assoc name SV
        of NONE => raise ERR "inst_params.lineup" 
                       ("missing schematic variable: "^name)
         | SOME sv => (sv,redex)::lineup rst SV
     end;

fun mk_tytheta SV theta =
  let val pairs = lineup theta SV
      val (SV',dom_theta) = unzip pairs
      val pat = list_mk_pair SV'
      val obj = list_mk_pair dom_theta
  in
    match_type (type_of pat) (type_of obj)
  end;

fun inst_params (STDREC{eqs,ind,R,SV}) theta = 
      let val tytheta = mk_tytheta SV theta
          val fulltheta = (theta,tytheta)
      in STDREC
           {eqs=INST_THM fulltheta eqs,
            ind=INST_THM fulltheta ind,
            R=inst tytheta R,
            SV=map (subst theta o inst tytheta) SV}
      end
  | inst_params (NESTREC{eqs,ind,R,SV,aux}) theta = 
      let val tytheta = mk_tytheta SV theta
          val fulltheta = (theta,tytheta)
      in NESTREC
           {eqs=INST_THM fulltheta eqs,
            ind=INST_THM fulltheta ind,
            R=inst tytheta R,
            SV=map (subst theta o inst tytheta) SV,
            aux=inst_params aux theta}
      end
  | inst_params (MUTREC{eqs,ind,R,SV,union}) theta = 
      let val tytheta = mk_tytheta SV theta
          val fulltheta = (theta,tytheta)
      in MUTREC
           {eqs=INST_THM fulltheta eqs,
            ind=INST_THM fulltheta ind,
            R=inst tytheta R,
            SV=map (subst theta o inst tytheta) SV,
            union=inst_params union theta}
      end
  | inst_params x theta = x;
*)

fun inst_defn (STDREC{eqs,ind,R,SV}) theta = 
      STDREC {eqs=INST_THM theta eqs,
              ind=INST_THM theta ind,
              R=isubst theta R,
              SV=map (isubst theta) SV}
  | inst_defn (NESTREC{eqs,ind,R,SV,aux}) theta = 
      NESTREC {eqs=INST_THM theta eqs,
               ind=INST_THM theta ind,
               R=isubst theta R,
               SV=map (isubst theta) SV,
               aux=inst_defn aux theta}
  | inst_defn (MUTREC{eqs,ind,R,SV,union}) theta = 
      MUTREC {eqs=INST_THM theta eqs,
                 ind=INST_THM theta ind,
                 R=isubst theta R,
                 SV=map (isubst theta) SV,
                 union=inst_defn union theta}
  | inst_defn (PRIMREC{eqs,ind}) theta = 
      PRIMREC{eqs=INST_THM theta eqs, 
              ind=INST_THM theta ind}
  | inst_defn (NONREC eq) theta = NONREC (INST_THM theta eq)


(* 
fun total f x = SOME (f x) handle Interrupt => raise Interrupt 
                                |     _     => NONE;
val isWFR = USyntax.is_WFR;

fun tcs_of (NONREC _)  = NONE
  | tcs_of (PRIMREC _) = NONE
  | tcs_of (STDREC  {ind, ...}) = total (Lib.pluck isWFR) (hyp ind)
  | tcs_of (NESTREC {ind, ...}) = total (Lib.pluck isWFR) (hyp ind)
  | tcs_of (MUTREC  {ind, ...}) = total (Lib.pluck isWFR) (hyp ind);
*)

fun tcs_of (NONREC _)  = []
  | tcs_of (PRIMREC _) = []
  | tcs_of (STDREC  {ind, ...}) = hyp ind
  | tcs_of (NESTREC {ind, ...}) = hyp ind
  | tcs_of (MUTREC  {ind, ...}) = hyp ind;


fun reln_of (NONREC _)  = NONE
  | reln_of (PRIMREC _) = NONE
  | reln_of (STDREC  {R, ...}) = SOME R
  | reln_of (NESTREC {R, ...}) = SOME R
  | reln_of (MUTREC  {R, ...}) = SOME R;

fun set_reln (STDREC {eqs, ind, R, SV}) R1 = 
     let val (theta as (_,tytheta)) = match_term R R1
         val subs = INST_THM theta
     in 
       STDREC{R=R1, SV=map (inst tytheta) SV,
              eqs=subs eqs, 
              ind=subs ind}
     end
  | set_reln (NESTREC {eqs, ind, R, SV, aux}) R1 = 
     let val (theta as (_,tytheta)) = match_term R R1
         val subs = INST_THM theta
     in 
       NESTREC{R=R1, SV=map (inst tytheta) SV,
               eqs=subs eqs, 
               ind=subs ind,
               aux=set_reln aux R1}
     end
  | set_reln (MUTREC {eqs, ind, R, SV, union}) R1 = 
     let val (theta as (_,tytheta)) = match_term R R1
         val subs = INST_THM theta
     in 
       MUTREC{R=R1, SV=map (inst tytheta) SV,
              eqs=subs eqs, 
              ind=subs ind,
              union=set_reln union R1}
     end
  | set_reln x _ = x;


(* Should perhaps be extended to existential theorems. *)
val PROVE_HYPL = itlist PROVE_HYP;

fun elim_tcs (STDREC {eqs, ind, R, SV}) thms = 
     STDREC{R=R, SV=SV, 
            eqs=PROVE_HYPL thms eqs, 
            ind=PROVE_HYPL thms ind}
  | elim_tcs (NESTREC {eqs, ind, R,  SV, aux}) thms = 
     NESTREC{R=R, SV=SV,
            eqs=PROVE_HYPL thms eqs, 
            ind=PROVE_HYPL thms ind,
            aux=elim_tcs aux thms}
  | elim_tcs (MUTREC {eqs, ind, R, SV, union}) thms = 
     MUTREC{R=R, SV=SV,
            eqs=PROVE_HYPL thms eqs, 
            ind=PROVE_HYPL thms ind,
            union=elim_tcs union thms}
  | elim_tcs x _ = x;


local fun isT M = (#Name(dest_const M) = "T") handle HOL_ERR _ => false
      val lem = prove(Parse.Term`(M = M1) ==> (M ==> P) ==> M1 ==> P`,
                  DISCH_THEN SUBST_ALL_TAC THEN DISCH_THEN ACCEPT_TAC)
in
fun simp_assum conv tm th =
  let val th' = DISCH tm th
      val tmeq = conv tm
      val tm' = rhs(concl tmeq)
  in
    if isT tm' then MP th' (EQT_ELIM tmeq)
    else UNDISCH(MATCH_MP (MATCH_MP lem tmeq) th')
  end
end;

fun SIMP_HYPL conv th = itlist (simp_assum conv) (hyp th) th;

fun simp_tcs (STDREC {eqs, ind, R, SV}) conv = 
     STDREC{R=rhs(concl(conv R)), SV=SV, 
            eqs=SIMP_HYPL conv eqs, 
            ind=SIMP_HYPL conv ind}
  | simp_tcs (NESTREC {eqs, ind, R,  SV, aux}) conv = 
     NESTREC{R=rhs(concl(conv R)), SV=SV,
            eqs=SIMP_HYPL conv eqs, 
            ind=SIMP_HYPL conv ind,
            aux=simp_tcs aux conv}
  | simp_tcs (MUTREC {eqs, ind, R, SV, union}) conv = 
     MUTREC{R=rhs(concl(conv R)), SV=SV,
            eqs=SIMP_HYPL conv eqs, 
            ind=SIMP_HYPL conv ind,
            union=simp_tcs union conv}
  | simp_tcs x _ = x;


fun TAC_HYPL tac th = 
   PROVE_HYPL (mapfilter (C (curry prove) tac) (hyp th)) th;

fun prove_tcs (STDREC {eqs, ind, R, SV}) tac = 
     STDREC{R=R, SV=SV, 
            eqs=TAC_HYPL tac eqs, 
            ind=TAC_HYPL tac ind}
  | prove_tcs (NESTREC {eqs, ind, R,  SV, aux}) tac = 
     NESTREC{R=R, SV=SV,
            eqs=TAC_HYPL tac eqs, 
            ind=TAC_HYPL tac ind,
            aux=prove_tcs aux tac}
  | prove_tcs (MUTREC {eqs, ind, R, SV, union}) tac = 
     MUTREC{R=R, SV=SV,
            eqs=TAC_HYPL tac eqs, 
            ind=TAC_HYPL tac ind,
            union=prove_tcs union tac}
  | prove_tcs x _ = x;



(*
fun gstack_of defn =
   case tcl_of defn
    of NONE => raise ERR "gstack_of" "no termination conditions"
     | SOME (WFR,tcs) =>
        let val R = rand WFR
            val M = mk_exists{Bvar=R, Body = list_mk_conj (WFR::tcs)}
        in
          GoalstackPure.set_goal ([], M)
        end;

val g = goalstackLib.add  o gstack_of;

*)


end;
