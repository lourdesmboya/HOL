structure rich_listSimps :> rich_listSimps =
struct

open Lib simpLib rich_listTheory;

val LIST_ss = merge_ss [listSimps.list_ss,
 rewrites
  [SNOC, BUTLAST, BUTLAST_CONS, LAST, LAST_CONS, REVERSE, MAP_FLAT,
   MAP_FILTER, MAP_SNOC, FLAT_REVERSE, FLAT_APPEND, FILTER,
   SUM, FOLDR, FOLDL, ELL,  ALL_EL, SOME_EL, IS_EL,
   IS_PREFIX, IS_SUFFIX, REPLICATE, SEG, SEG_REVERSE, SEG_SNOC,
   FIRSTN, LASTN, BUTFIRSTN, BUTLASTN, NOT_NIL_SNOC,
   NOT_SNOC_NIL, SNOC_11, ALL_EL_APPEND]];

end;
