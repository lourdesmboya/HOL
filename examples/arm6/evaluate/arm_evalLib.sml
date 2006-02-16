(* ========================================================================= *)
(* FILE          : arm_evalLib.sml                                           *)
(* DESCRIPTION   : Code for evaluating the I/O free ARM specification        *)
(*                                                                           *)
(* AUTHOR        : (c) Anthony Fox, University of Cambridge                  *)
(* DATE          : 2005                                                      *)
(* ========================================================================= *)

structure arm_evalLib :> arm_evalLib =
struct

(* interactive use:
  app load ["computeLib", "onestepTheory", "modelsLib", "arm_evalTheory",
            "instructionTheory", "instructionSyntax"];
*)

open HolKernel boolLib bossLib;
open Parse Q computeLib wordsSyntax rich_listTheory;
open armTheory arm_evalTheory bsubstTheory instructionSyntax;

(* ------------------------------------------------------------------------- *)
(* Some conversions *)

val SUC2NUM = CONV_RULE numLib.SUC_TO_NUMERAL_DEFN_CONV;

fun add_rws f rws =
let val cmp_set = f()
    val _ = add_thms rws cmp_set
in cmp_set end;

fun arm_eval_compset () = let open simTheory in
  add_rws modelsLib.arm_compset 
    [state_arme_accessors, state_arme_updates_eq_literal,
     state_arme_accfupds, state_arme_fupdfupds, state_arme_literal_11,
     state_arme_fupdfupds_comp, state_arme_fupdcanon,state_arme_fupdcanon_comp,
     ADDR30_def,SET_BYTE_def,BSUBST_EVAL,dimindex_30,finite_30,memop_case_def,
     MEM_WRITE_BYTE_def,MEM_WRITE_WORD_def,MEM_WRITE_def,TRANSFERS_def,
     SIMP_RULE (bool_ss++pred_setSimps.PRED_SET_ss) [] NEXT_ARMe_def]
end;

val ARMe_CONV = CBV_CONV (arm_eval_compset());
val ARMe_RULE = CONV_RULE ARMe_CONV;

val SORT_SUBST_CONV = let open simTheory
  val compset = add_rws reduceLib.num_compset
        [register_EQ_register,register2num_thm,psrs_EQ_psrs,psrs2num_thm,
         SYM Sa_def,Sab_EQ,Sa_RULE4,Sb_RULE4,Sa_RULE_PSR,Sb_RULE_PSR,
         combinTheory.o_THM]
in
  computeLib.CBV_CONV compset THENC PURE_REWRITE_CONV [Sa_def,Sb_def]
    THENC SIMP_CONV (srw_ss()) [SUBST_EQ2,simTheory.SUBST_EVAL]
end;

val SORT_BSUBST_CONV = let open simTheory
  val compset = add_rws wordsLib.words_compset
        [dimindex_30,finite_30,LENGTH,SUC2NUM JOIN,SUC2NUM BUTFIRSTN,
         APPEND,SUBST_BSUBST,BSa_RULE,BSb_RULE,GSYM BSa_def,combinTheory.o_THM]
in
  computeLib.CBV_CONV compset THENC PURE_REWRITE_CONV [BSa_def,BSb_def]
end;

val FOLD_SUBST_CONV = let open simTheory
  val compset = add_rws wordsLib.words_compset
      [SET_IFMODE_def,SET_NZCV_def,FOLDL,SUBST_EVAL,mode_num_def,mode_case_def,
       register_EQ_register,register2num_thm,psrs_EQ_psrs,psrs2num_thm]
in
  computeLib.CBV_CONV compset THENC SORT_SUBST_CONV
end;

val ARM_ASSEMBLE_CONV = let open instructionTheory
  val compset = add_rws wordsLib.words_compset
       [transfer_options_accessors,transfer_options_updates_eq_literal,
        transfer_options_accfupds,transfer_options_fupdfupds,
        transfer_options_literal_11,transfer_options_fupdfupds_comp,
        transfer_options_fupdcanon,transfer_options_fupdcanon_comp,
        condition2num_thm,arm_instruction_case_def,addr_mode1_case_def,
        addr_mode2_case_def,msr_mode_case_def,condition_encode_def,
        shift_encode_def,addr_mode1_encode_def,addr_mode2_encode_def,
        msr_mode_encode_def,msr_psr_encode_def,options_encode_def,
        instruction_encode_def,combinTheory.K_THM,
        SET_NZCV_def,SET_IFMODE_def,mode_num_def,mode_case_def]
in
  computeLib.CBV_CONV compset
end;

val rhsc = rhs o concl;

fun printn s = print (s ^ "\n");

(* ------------------------------------------------------------------------- *)
(* Syntax *)

val _ = overload_on("enc", ``instruction_encode``);

fun mk_enc t = mk_comb(``enc``,t);

fun mk_word30 n = mk_n2w(numSyntax.mk_numeral n,``:i30``);
fun mk_word32 n = mk_n2w(numSyntax.mk_numeral n,``:i32``);

fun eval_word t = (numSyntax.dest_numeral o rhsc o FOLD_SUBST_CONV o mk_w2n) t;

val subst_tm  = prim_mk_const{Name = ":-",  Thy = "arm"};
val bsubst_tm = prim_mk_const{Name = "::-", Thy = "bsubst"};

fun mk_subst (a,b,m) =
   list_mk_comb(inst[alpha |-> type_of a,beta |-> type_of b] subst_tm,[a,b,m])
   handle HOL_ERR _ => raise ERR "mk_subst" "";

fun mk_bsubst (a,b,m) =
   list_mk_comb(inst[alpha |-> dim_of a,beta |-> listSyntax.eltype b]
     bsubst_tm,[a,b,m])
   handle HOL_ERR _ => raise ERR "mk_subst" "";

val dest_subst  = dest_triop subst_tm  (ERR "dest_word_slice" "");
val dest_bsubst = dest_triop bsubst_tm (ERR "dest_word_slice" "");

fun dest_arm_eval t =
  case TypeBase.dest_record t of
     [("registers", reg), ("psrs", psrs),
      ("memory", mem), ("undefined", undef)] =>
         {mem = mem, reg = reg, psrs = psrs, undef = undef}
  | _ => raise ERR "dest_arm_eval" "";

(* ------------------------------------------------------------------------- *)

fun hol_assemble m a l = let
  val code = map (rhsc o ARM_ASSEMBLE_CONV o
                  (curry mk_comb ``instruction_encode``) o Term) l
  val block = listSyntax.mk_list(code,``:word32``)
in
  rhsc (SORT_BSUBST_CONV (mk_bsubst(mk_word30 a,block,m)))
end;

fun hol_assemble1 m a t = hol_assemble m a [t];

fun assemble m a l = let
  val code = map ((fn t => if type_of t = ``:word32`` then t else mk_enc t) o
                  mk_instruction) l
  val block = listSyntax.mk_list(code,``:word32``)
in
  rhsc (SORT_BSUBST_CONV (mk_bsubst(mk_word30 a,block,m)))
end;

fun assemble1 m a t = assemble m a [t];

(* ------------------------------------------------------------------------- *)
(* Funtions for memory loading and saving *)

local
  fun bytes2num (b0,b1,b2,b3) =
    let open Arbnum
        val byte2num = fromInt o Char.ord o Byte.byteToChar
    in
      (byte2num b0) * (fromInt 16777216) + (byte2num b1) * (fromInt 65536) +
      (byte2num b2) * (fromInt 256) + byte2num b3
    end

  fun read_word (v,i) =
    let val l = Word8Vector.length v
        fun f i = if i < l then Word8Vector.sub(v,i) else 0wx0
    in
      mk_word32 (bytes2num (f i, f (i + 1), f (i + 2), f (i + 3)))
      (* could change order to do little-endian *)
    end
in
  fun load_mem fname skip top_addr m =
    let open BinIO
        val istr = openIn fname
        val data = inputAll istr
        val _ = closeIn istr
        val lines = (Word8Vector.length data - skip) div 4
        val l = List.tabulate(lines, fn i => read_word (data,4 * i + skip))
        val lterm = listSyntax.mk_list(l,``:word32``)
    in
      rhsc (SORT_BSUBST_CONV (mk_bsubst(mk_word30 top_addr,lterm,m)))
    end
end;

fun mem_read m a = (eval_word o rhsc o ARMe_CONV) (mk_comb(m,mk_word30 a));

fun save_mem fname start finish le m = let open BinIO Arbnum
    fun bits  h l n = (n mod pow(two,plus1 h)) div (pow(two,l))
    val ostr = openOut fname
    val num2byte = Word8.fromInt o Arbnum.toInt;
    fun num2bytes w =
          map (fn (i,j) => num2byte (bits (fromInt i) (fromInt j) w))
              ((if le then rev else I) [(31,24),(23,16),(15,8),(7,0)])
    fun save_word i = map (fn b => output1(ostr,b)) (num2bytes (mem_read m i))
    fun recurse i =
          if Arbnum.<=(i,finish) then recurse (save_word i; Arbnum.plus1 i)
          else closeOut ostr
in
  recurse start
end;

(* ------------------------------------------------------------------------- *)
(* Set the general purpose and program status registers *)

val foldl_tm =
  ``FOLDL (\m (r:'a,v:'b). if v = m r then m else (r :- v) m) x y``;

fun set_registers reg rvs  =
 (rhsc o FOLD_SUBST_CONV o
  subst [``x:reg`` |-> reg, ``y:(register # word32) list`` |-> rvs] o
  inst [alpha |-> ``:register``, beta |-> ``:word32``]) foldl_tm;

fun set_status_registers psr rvs  = (rhsc o 
  (FOLD_SUBST_CONV
     THENC PURE_ONCE_REWRITE_CONV [SPEC `n2w n` simTheory.PSR_CONS]
     THENC ARMe_CONV) o
  subst [``x:psr`` |-> psr, ``y:(psrs # word32) list`` |-> rvs] o
  inst [alpha |-> ``:psrs``, beta |-> ``:word32``]) foldl_tm;

(* ------------------------------------------------------------------------- *)
(* Running the model *)

fun init m r s =
   (PURE_ONCE_REWRITE_CONV [CONJUNCT1 STATE_ARMe_def] o
    subst [``mem:mem`` |-> m, ``reg:reg`` |-> r, ``psr:psr`` |-> s])
   ``STATE_ARMe 0 <| registers := reg; psrs :=  psr;
                     memory := mem; undefined := F |>``;

val STATE_ARMe_NEXT = MATCH_MP onestepTheory.IMAP_NEXT STATE_ARMe_THM;

fun next t =
let val t1 = rhsc t
    val t2 = ((ARMe_CONV THENC
                 ONCE_DEPTH_CONV (RAND_CONV (RAND_CONV SORT_BSUBST_CONV)) THENC
                 ONCE_DEPTH_CONV (RATOR_CONV SORT_SUBST_CONV) THENC
                 ONCE_DEPTH_CONV (RATOR_CONV (RAND_CONV SORT_SUBST_CONV)) THENC
                 RATOR_CONV ARM_ASSEMBLE_CONV) o
                 subst [``s:state_arme`` |-> t1]) ``NEXT_ARMe s``
  in
     numLib.REDUCE_RULE (MATCH_MP STATE_ARMe_NEXT (CONJ t t2))
  end;

fun done t = term_eq T (#undef (dest_arm_eval (rhsc t)));

fun state n [] = []
  | state n (l as (t::ts)) =
      if n = 0 then l
      else let val nl = (time next t) :: l in
        if done t then nl else state (n - 1) nl
      end;

fun eval n m r s = state n [init m r s];
fun evaluate n m r s = hd (eval n m r s);

(* ------------------------------------------------------------------------- *)

end
