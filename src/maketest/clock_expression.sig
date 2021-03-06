(* $Id$
 *
 * Copyright (c) 2008 Timothy Bourke (University of NSW and NICTA)
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the "BSD License" which is distributed with the
 * software in the file LICENSE.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the BSD
 * License for more details.
 *)

(* TODO:
 *    * It might be useful to define a type that carries around both a
 *      ClockExpression and its forall bindings (i.e. prenex form), the
 *      functions should be updated to handle this type properly.
 *)

signature CLOCK_EXPRESSION = sig

  exception NonClockTerm

  type symbol    = Atom.atom
   and symbolset = AtomSet.set

  datatype clockrel = Lt | Leq | Eq | Geq | Gt

  datatype clockval = Simple  of int
                    | Complex of Expression.expr

  datatype clockterm = NonClock of Expression.expr
                     | CRel     of Expression.var * clockrel * clockval
                     | CDiff    of Expression.var * Expression.var
                                   * clockrel * clockval

  datatype t = Term of clockterm
             | And  of t * t
             | Or   of t * t

  val trueExpr       : t
  val falseExpr      : t

  val isConstant     : t -> bool option

  val negate         : t -> t
  val getFree        : t -> symbolset

  val fromExpr       : symbolset * Environment.env * Expression.expr
                       -> t * (symbol * Expression.ty) list * symbolset
                       (* raises NonClockTerm *)
  (* usednames * environment * expression to convert
   *    -> result * forall bindings * usednames' -- now in prenex form *)

  val toExpr         : t * (symbol * Expression.ty) list -> Expression.expr

  val rename         : {old: symbol, new: symbol} * t -> t
  val conflictExists : symbolset * symbolset * clockterm list list -> bool 

  val ensureNoBindingConflict : (symbol * Expression.ty) list * t
                                -> (symbol * Expression.ty) list * t
                                -> (symbol * Expression.ty) list * t
  (* (l', e') = ensureNoBindingConflict (rl, re) (l, e)
   * Renames bound variables (l => l') in (e => e') to ensure that combination
   * with the reference expression will not capture names improperly.
   * 
   * e.g. it would then be safe to and the reference and result expressions:
   *          (al, ae) = (rl @ l', andexpr (re, e'))
   * *)

  val toDNF            : t -> clockterm list list
  val fromDNF          : clockterm list list -> t
  val clusterNonClocks : clockterm list list -> clockterm list list
  val andexpr          : t * t -> t

  val toString         : t -> string

end

