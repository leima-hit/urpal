(* $Id$ *)

signature TRANSITION_FLIPPER =
sig
  exception FlipFailed of string

  type t = {selectids:  Expression.boundid list,
            actionsubs: Expression.expr list,
            guard:      Expression.expr}

  val negateTransitions : Environment.env
                          -> Expression.ty list * t list * Expression.expr
                          -> t list
  (* needs type environment to identify clock variables
     (making CRel and CDiff) from the others (making NonClock)
     Fairly careful with clocks but no general type or side-effect checking

     The last expression is the invariant for the source location.
     
     The ids from sellist are added to env internally.
   *)
   (* TODO: Given an empty guard list, it should return a transition with true guard,
            may need to select over action subscripts. *)

  val negateInvariant   : Environment.env -> Expression.expr -> t list
  (* Negate the given invariant expression, returning a list of transitions. *)

  val andexpr  : Environment.env
                 -> Expression.boundid list * Expression.expr * Expression.expr
                 -> Expression.expr
    (* Form the conjunct of both expressions, and try to simplify the result.
     * Any variables in the second expression whose names appear in the list of
     * bindings are renamed; this list can be used to avoid bad name capture.
     * TODO: The binding list feature should be generalised and made less of
     *       a hack
     *)

  val toString : t -> string

  val chanToSubRanges : (Environment.env * Environment.symbol)
                        -> Expression.ty list option

end

