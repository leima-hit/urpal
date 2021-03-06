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
 *
 * Original code for parsing a config file.
 * The config file syntax follows Reppy's ML-Doc, but this was
 * written without reference to his source.
 *)

functor ConfigTree (Lex : CONFIG_LEXER) :> CONFIG_TREE =
struct
  type symbol = Atom.atom
  exception ParseError of int

  datatype entry = Entry   of symbol * entry_type
                 | Section of symbol * entry list

       and entry_type = Id     of symbol
                      | Int    of int
                      | Bool   of bool
                      | Color  of string
                      | Real   of real
                      | String of string

  type t = entry list

  fun parse rdr ins = let

      val strm = ref ins
      fun read _ = case rdr (!strm) of
                     NONE            => ""
                   | SOME (s, strm') => s before strm := strm'
      val lexer = Lex.makeLexer read

      fun STRING (Lex.StringEnd) = []
        | STRING (Lex.StringLine s)  = s::STRING (lexer ())
        | STRING _ = raise ParseError (Lex.linenum ())

      fun ASSIGN (nm, Lex.Id v)         = Entry (nm, Id v)
        | ASSIGN (nm, Lex.Int i)        = Entry (nm, Int i)
        | ASSIGN (nm, Lex.Bool b)       = Entry (nm, Bool b)
        | ASSIGN (nm, Lex.Color s)      = Entry (nm, Color s)
        | ASSIGN (nm, Lex.Real r)       = Entry (nm, Real r)
        | ASSIGN (nm, Lex.StringStart)  = Entry (nm, String
                                            (concat (STRING (lexer ()))))
        | ASSIGN (nm, Lex.OpenSection)  = SECTION (nm, lexer ())
        | ASSIGN _ = raise ParseError (Lex.linenum ())

      and SECTION (nm, tok) = Section (nm, ENTRYLIST ([], tok))

      and ENTRY (Lex.Id nm, Lex.Assign)      = ASSIGN (nm, lexer())
        | ENTRY (Lex.Id nm, Lex.OpenSection) = SECTION (nm, lexer())
        | ENTRY _ = raise ParseError (Lex.linenum ())

      and ENTRYLIST (es, Lex.Eof) = rev es
        | ENTRYLIST (es, Lex.CloseSection) = rev es
        | ENTRYLIST (es, tok) = ENTRYLIST (ENTRY (tok, lexer())::es,
                                           lexer())
    in ENTRYLIST ([], lexer()) end

  fun entryToOutputStr (Id id)    = Atom.toString id
    | entryToOutputStr (Int i)    = if i < 0 then "-" ^ Int.toString (~i)
                                             else Int.toString i
    | entryToOutputStr (Bool true)= "true"
    | entryToOutputStr (Bool false)= "false"
    | entryToOutputStr (Color s)  = s
    | entryToOutputStr (Real r)   = if Real.sign r >= 0 then Real.toString r
                                    else "-" ^ Real.toString (Real.abs r)
    | entryToOutputStr (String s) = concat ["\"", s, "\""]

  fun entryToString (String s) = s
    | entryToString e          = entryToOutputStr e

  fun output (outs, t) = let
      fun pr p = TextIO.output (outs, p)

      fun dumpEntry (t, Entry (nm, v))  = (pr t; pr (Atom.toString nm);
                                           pr " = ";
                                           pr (entryToOutputStr v); pr "\n")
        | dumpEntry (t, Section (nm, l))= (pr t; pr (Atom.toString nm);
                                           pr " {\n";
                                           dumpList (t ^ "    ", l);
                                           pr t; pr "}\n")

      and dumpList (t, xs) = app (fn x=> dumpEntry (t, x)) xs

    in dumpList ("", t) end


  local
    fun hasName nm (Entry (nm', v))   = Atom.compare (nm, nm') = EQUAL
      | hasName nm (Section (nm', l)) = Atom.compare (nm, nm') = EQUAL

    fun getName (t, nm)  = List.find (hasName nm) t

    fun getValue (t, nm) = case getName (t, nm) of
                             SOME (Entry (_, v)) => SOME v
                           | _                   => NONE

    fun getSection (t, nm) = case getName (t, nm) of
                               SOME (Section (_, s)) => s
                             | _                     => []

  in

  fun getEntry (t, [])      = NONE
    | getEntry (t, [nm])    = getValue (t, nm)
    | getEntry (t, nm::nms) = getEntry (getSection (t, nm), nms)

  fun getSymbol (t, path) = case getEntry (t, path) of
                              SOME (Id s)     => SOME s
                            | SOME (String s) => SOME (Atom.atom s)
                            | _               => NONE

  fun getString (t, path) = Option.map entryToString (getEntry (t, path))
  
  fun getInt (t, path)    = case getEntry (t, path) of
                              SOME (Int i)   => SOME i
                            | _              => NONE

  fun getReal (t, path)   = case getEntry (t, path) of
                              SOME (Real r)  => SOME r
                            | SOME (Int i)   => SOME (Real.fromInt i)
                            | _              => NONE

  fun getColor (t, path)  = case getEntry (t, path) of
                              SOME (Color c) => SOME c
                            | _              => NONE

  fun getBool (t, path) = let
      fun fromVal (Bool b)         = SOME b
        | fromVal (String "on")    = SOME true
        | fromVal (String "off")   = SOME false
        | fromVal (String "true")  = SOME true
        | fromVal (String "false") = SOME false
        | fromVal (String "yes")   = SOME true
        | fromVal (String "no")    = SOME false
        | fromVal (Int i)          = SOME (i <> 0)
        | fromVal _                = NONE
    in Option.mapPartial fromVal (getEntry (t, path)) end

  end (* local *)
end

