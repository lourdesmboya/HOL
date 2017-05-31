open HolKernel Parse boolLib bossLib
open machine_ieeeLib;

val () = new_theory "machine_ieee";

(* ------------------------------------------------------------------------
   Bit-vector Encodings
   ------------------------------------------------------------------------ *)

local
   val mtch = DB.match [Theory.current_theory()] o Thm.concl
in
   fun get_thm_name thm =
      case mtch thm of
         [((_, name), _)] => (thm, name)
       | _ => raise Feedback.mk_HOL_ERR "machine_ieee" "get_thm_name" ""
end

(*
    | l => (PolyML.prettyPrint
              (print, 80) (PolyML.prettyRepresentation ((thm, l), 80))
            ; raise Feedback.mk_HOL_ERR "machine_ieee" "get_thm_name" "")
*)

(* 16-bit, 32-bit and 64-bit encodings *)

val thms =
   [("fp16", 10, 5, SOME "half"),
    ("fp32", 23, 8, SOME "single"),
    ("fp64", 52, 11, SOME "double")]
   |> List.map machine_ieeeLib.mk_fp_encoding
   |> List.concat
   |> List.map get_thm_name
   |> (fn l =>
         let
            val (thms, names) = ListPair.unzip l
         in
            computeLib.add_persistent_funs names; thms
         end)

val convert_def = Define`
  convert (to_float: 'a word -> ('b, 'c) float)
          (from_float: ('d, 'e) float -> 'f word) from_real (m: rounding) w =
  let f = to_float w in
  case float_value f of
     Float r => from_real m r
   | NaN => from_float (@fp. float_is_nan fp)
   | Infinity => from_float (if f.Sign = 0w then
                               float_plus_infinity (:'d # 'e)
                             else
                               float_minus_infinity (:'d # 'e))`

val fp32_to_fp64_def = Define`
  fp32_to_fp64 =
  convert fp32_to_float float_to_fp64 real_to_fp64 roundTiesToEven`

val fp64_to_fp32_def = Define`
  fp64_to_fp32 = convert fp64_to_float float_to_fp32 real_to_fp32`

(* ------------------------------------------------------------------------ *)

(* Testing:

open binary_ieeeLib machine_ieeeTheory

time EVAL ``fp32_add roundTiesToEven 0x0123456w 0x98765432w``
time EVAL ``fp32_mul roundTiesToEven 0x0123456w 0x98765432w``

Count.apply EVAL
  ``fp32_mul roundTiesToEven (real_to_fp32 roundTiesToEven (1 / 2))
                             (real_to_fp32 roundTiesToEven (1 / 3))
    :> fp32_to_real``

Count.apply EVAL
  ``fp64_mul roundTiesToEven (real_to_fp64 roundTiesToEven (1 / 2))
                             (real_to_fp64 roundTiesToEven (1 / 3))
    :> fp64_to_real``

Count.apply EVAL ``real_to_fp64 roundTiesToEven (1 / 6) :> fp64_to_real``

(* 0.05 v 9.3s *)

Count.apply EVAL
   ``float_add roundTiesToEven
        <|Sign := 0w; Exponent := 15w; Significand := 524288w|>
        <|Sign := 0w; Exponent := 15w; Significand := 262144w|> :
        (23, 8) float``

(* 0.05 v 87.1s *)

Count.apply EVAL
   ``float_add roundTiesToEven
        <|Sign := 0w; Exponent := 251w; Significand := 8388607w|>
        <|Sign := 0w; Exponent := 251w; Significand := 4194303w|> :
        (23, 8) float``

*)

val () = export_theory ()
