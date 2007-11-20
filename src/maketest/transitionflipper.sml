(* $Id$ *)

(*TODO:
  * Check whether duplicate selectids can muck things up.
  * Remove unused select ids from final transitions (or initial transitions?).
    fun removeEarlierDuplicates l = let (* there can be only one *)
        fun p s (s', _) = not (s =:= s')
        fun f []                  = []
          | f ((x as (s, _))::xs) = x :: f (List.filter (p s) xs)
      in rev (f (rev l)) end

    fun unusedId used (E.BoundId (s, ty, _)) = if s <- used
                                               then SOME (s, ty) else NONE

    val sellist = removeEarlierDuplicates
                    (List.mapPartial (unusedId (!usednames)) presellist)

  * What happens if we call negate(negate tr)?
    Should this be forbidden by using types?

  * Should check whether any actselect indices are used in guard terms in a way
    that will create problems (restrict how actions are selected?).
      e.g. select i . (i > 4) / a[i]
                  ||negate
                  \/
           select i . (i <= r) / a[i]
     But how would this combine with other transitions? Does it work?
     This must first be understood properly.

  * What about action selectids with non-zero lower bounds?
        chan c[6];
        select i : int[2,5] . true / c[i]

    Either forbid, or the negation set has to include:
        select i : int [0,1] . true / c[i]

  * Need a mapping back from scalar sets to their typedef-ed names (possibly via
    uniqueid lookup?, or don't expand to begin with (would this break anything
    else?). See tests/testflip13, the selectid should come from 'S', not
    scalar[5].

 *)

structure TransitionFlipper :> TRANSITION_FLIPPER = let
  structure E       = Expression
        and Env     = Environment
        and ECVT    = ExpressionCvt
        and ATrans  = ActionTrans
        and ClkE    = ClockExpression
        and CETrans = ClkExprTrans
in struct
  exception FlipFailed of string

  (* shortcuts over Atom and AtomSet *)
  infix <+ <- ++ <\ \ =:= ; open Symbol

  type t = {selectids:  E.boundid list,
            actionsubs: E.expr list,
            guard:      E.expr}

  fun toString {selectids, actionsubs, guard} = let
      fun showActions []      = ""
        | showActions (e::es) = "[" ^ ECVT.Expr.toString e ^"]"^ showActions es

      fun boundToStr (E.BoundId (s, ty, _)) = Atom.toString s ^
                                              " : " ^ ECVT.Ty.toString ty
      val bindingList = (ListFormat.fmt {init="(", sep=", ",
                                         final=")", fmt=boundToStr})
    in
      "{select "  ^ bindingList selectids    ^ "\n"  ^
      " action: " ^ showActions actionsubs   ^ "\n " ^
                    ECVT.Expr.toString guard ^ " }"  ^ "\n"
    end

  fun andexpr env (e1, e2) = let
      val (ce1, ce1fa, used) = ClkE.fromExpr (emptyset, env, e1)
      val (ce2, ce2fa, used) = ClkE.fromExpr (used, env, e2)
    in
      ClkE.toExpr (ClkE.andexpr (ce1, ce2), ce1fa @ ce2fa)
    end

  fun negateTransitions env (subtypes, trans : t list, invariant) = let
      val _ = Util.debugSect (Settings.Outline, fn ()=>"negateTransitions:\n"
                                                       ::map toString trans)

      (* 1. Group like subscripts; rename subSelectIds; make others unique. *)
      val atrans = ATrans.ensureConsistency
                     (map (ATrans.fromTrans subtypes) trans)
      val otherATrans = ATrans.coverMissingChannels (subtypes, atrans,
                                                     invariant)
      val cetrans = map (CETrans.fromATrans env) atrans
      
      val _ = Util.debugSubsect (Settings.Outline,
                        fn ()=>"cover missing channels:\n"
                               ::map ATrans.toString otherATrans)

      (* 2. Paritition remaining transitions. *)
      val partitions = Partitions.makeList cetrans

      (* 3. Form partition expressions: just over freeSubscripts
            Grouping back into a single list of transitions. *)
      val cetrans = List.concat (List.map CETrans.formPartitionReps partitions)

      val _ = Util.debugSubsect (Settings.Detailed,
                fn ()=>"with partition reps:\n"::map CETrans.toString cetrans)

      (* 4. Convert the location invariant into a clock expression
       *    (this piece was hacked in later and could be tightened up. *)
      val (cinv, cinv_fall, _) = ClkE.fromExpr (CETrans.unionNames cetrans,
                                                env, invariant)
      val cetrans = if null cinv_fall then cetrans
                    else List.map (CETrans.addDisjointForalls cinv_fall)
                                  cetrans

      (* 5. Negate each, concatenating results. *)
      val ncetrans = List.concat (List.map (CETrans.negate cinv) cetrans)

      val _ = Util.debugSubsect (Settings.Detailed, fn ()=>"after negation:\n"
                                              ::map CETrans.toString ncetrans)

    in map ATrans.toTrans otherATrans @ map CETrans.toTrans ncetrans end
      handle CETrans.SelectIdConflictsWithForAll (sel, forall) => let
                fun showSym n = ListFormat.fmt {init=n ^ "(", final=")",
                                                sep=", ", fmt=Atom.toString}
              in
               raise FlipFailed ("select/forall conflict, " ^
                                 showSym "select" sel       ^
                                 showSym "forall" forall    )
              end

           | ClkE.NonClockTerm => raise FlipFailed "bad clock terms in guard"

           | ATrans.ActSubWithNonSimpleSelect e      => raise FlipFailed (
                  "channel subscript contains non-simple bound variable (" ^
                  ExpressionCvt.Expr.toString e ^ ")")

           | ATrans.ActSubWithBadType {expr, badty, goodty} => raise FlipFailed
                ("channel subscript select variable " ^
                 ExpressionCvt.Expr.toString expr  ^ " has type " ^
                   ExpressionCvt.Ty.toString badty ^ ", not "     ^
                   ExpressionCvt.Ty.toString goodty)
                  
           | ATrans.ActionSubWithDuplicate s         => raise FlipFailed
                ("select variable, " ^ Atom.toString s ^
                 ", used twice as channel subscript (please rewrite)")

           | ATrans.BadSubscriptCount                =>
                raise FlipFailed ("wrong number of channel subscripts")

           | ATrans.MixedSubscriptTypes (e1, e2) => raise FlipFailed
                ("non-consistent channel subscript dimensions (" ^
                 ExpressionCvt.Expr.toString e1 ^ ", " ^
                 ExpressionCvt.Expr.toString e2 ^ ")")

  fun chanToSubRanges (env, s) = let
      fun arrToList (E.CHANNEL _, r)              = SOME r
        | arrToList (E.ARRAY (ty, E.Type sub), r) = arrToList (ty, sub::r)
        | arrToList _                             = NONE
    in
      Option.composePartial (fn ty=> arrToList (ty, []), Env.findValType env) s
    end

end
end
