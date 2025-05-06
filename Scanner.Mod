MODULE Scanner;
IMPORT Out, Machine, Errors := MocErrors;

CONST
  identLen = 256;
  stringSize = 1024;

  (** Lexical symbols **)
  null = 0; times* = 1; rdiv* = 2; div* = 3; mod* = 4;
  and* = 5; plus* = 6; minus* = 7; or* = 8; eql* = 9;
  neq* = 10; lss* = 11; leq* = 12; gtr* = 13; geq* = 14;
  in* = 15; is* = 16; arrow* = 17; period* = 18;
  char* = 20; int* = 21; real* = 22; false* = 23; true* = 24;
  nil* = 25; string* = 26; not* = 27; lparen* = 28; lbrak* = 29;
  lbrace* = 30; ident* = 31;
  if* = 32; while* = 34; repeat* = 35; case* = 36; for* = 37;
  comma* = 40; colon* = 41; becomes* = 42; upto* = 43; rparen* = 44;
  rbrak* = 45; rbrace* = 46; then* = 47; of* = 48; do* = 49;
  to* = 50; by* = 51; semicolon* = 52; end* = 53; bar* = 54;
  else* = 55; elsif* = 56; until* = 57; return* = 58;
  array* = 60; record* = 61; pointer* = 62; const* = 63; type* = 64;
  var* = 65; procedure* = 66; begin* = 67; import* = 68; module* = 69; eot* = 70;

TYPE
  Ident* = ARRAY identLen OF CHAR;

VAR
  (** Results of Get **)
  identVal*: Ident;
  intVal*: INTEGER;
  realVal*: REAL;
  strVal*: ARRAY stringSize OF CHAR;
  strLen*: INTEGER;

  (** - **)
  ch: CHAR; (** Read-ahead character *)

(** Reports whether ch is a letter. *)
PROCEDURE IsDigit(): BOOLEAN;
RETURN ('0' <= ch) & (ch <= '9')
END IsDigit;

(** Reports whether ch is a letter. *)
PROCEDURE IsAlpha(): BOOLEAN;
RETURN ('A' <= ch) & (ch <= 'Z') OR
       ('a' <= ch) & (ch <= 'z') OR
       (ch = '_')
END IsAlpha;

(** Reports whether ch is a letter or a number. *)
PROCEDURE IsAlphaNum(): BOOLEAN;
RETURN IsAlpha() OR IsDigit()
END IsAlphaNum;

(** Examines identVal and returns one of keyword lexical symbol constants,
    or ident if identVal is not a keyword. Uses the passed in actual length
    of identVal for speed. *)
PROCEDURE IdentifyKeyWord(len: INTEGER): INTEGER;
VAR sym: INTEGER;
BEGIN
  sym := ident;
  IF len = 2 THEN
    IF    identVal = "OR" THEN sym := or
    ELSIF identVal = "IN" THEN sym := in
    ELSIF identVal = "IS" THEN sym := is
    ELSIF identVal = "IF" THEN sym := if
    ELSIF identVal = "OF" THEN sym := of
    ELSIF identVal = "DO" THEN sym := do
    ELSIF identVal = "TO" THEN sym := to
    ELSIF identVal = "BY" THEN sym := by
    END
  ELSIF len = 3 THEN
    IF    identVal = "INT" THEN sym := int
    ELSIF identVal = "NIL" THEN sym := nil
    ELSIF identVal = "FOR" THEN sym := for
    ELSIF identVal = "END" THEN sym := end
    ELSIF identVal = "VAR" THEN sym := var
    END
  ELSIF len = 4 THEN
    IF    identVal = "TYPE" THEN sym := type
    ELSIF identVal = "CHAR" THEN sym := char
    ELSIF identVal = "REAL" THEN sym := real
    ELSIF identVal = "TRUE" THEN sym := true
    ELSIF identVal = "CASE" THEN sym := case
    ELSIF identVal = "THEN" THEN sym := then
    ELSIF identVal = "ELSE" THEN sym := else
    END
  ELSIF len = 5 THEN
    IF    identVal = "ELSIF" THEN sym := elsif
    ELSIF identVal = "CONST" THEN sym := const
    ELSIF identVal = "UNTIL" THEN sym := until
    ELSIF identVal = "FALSE" THEN sym := false
    ELSIF identVal = "WHILE" THEN sym := while
    ELSIF identVal = "ARRAY" THEN sym := array
    ELSIF identVal = "BEGIN" THEN sym := begin
    END
  ELSIF len = 6 THEN
    IF    identVal = "REPEAT" THEN sym := repeat
    ELSIF identVal = "RETURN" THEN sym := return
    ELSIF identVal = "RECORD" THEN sym := record
    ELSIF identVal = "IMPORT" THEN sym := import
    ELSIF identVal = "MODULE" THEN sym := module
    END
  ELSIF (len = 7) & (identVal = "POINTER")   THEN sym := pointer
  ELSIF (len = 9) & (identVal = "PROCEDURE") THEN sym := procedure
  END
RETURN sym END IdentifyKeyWord;

PROCEDURE Get*(VAR sym: INTEGER);
VAR i: INTEGER;
  closeCh: CHAR;
  ok: BOOLEAN;
BEGIN
  WHILE (ch # 0X) & (ch <= ' ') DO Machine.Read(ch) END;
  IF ch = 0X THEN
    sym := eot
  ELSIF IsAlpha() THEN
    identVal[0] := ch;
    Machine.Read(ch);
    ok := TRUE;
    i := 1;
    WHILE IsAlphaNum() DO
      IF i = LEN(identVal) - 1 THEN
        ok := FALSE
      ELSE
        identVal[i] := ch;
        INC(i)
      END;
      Machine.Read(ch)
    END;
    identVal[i] := 0X;
    IF ~ok THEN
      Machine.Error(Errors.longIdent);
      identVal := ''
    END;
    sym := IdentifyKeyWord(i)
  ELSIF IsDigit() THEN
    intVal := ORD(ch) - ORD('0');
    ok := TRUE;
    Machine.Read(ch);
    WHILE IsDigit() DO
      (* Overflow check *)
      IF intVal <= (Machine.maxInt - ORD(ch) + ORD('0')) DIV 10 THEN
        intVal := intVal * 10 + ORD(ch) - ORD('0')
      ELSE
        ok := FALSE
      END;
      Machine.Read(ch)
    END;
    IF ~ok THEN
      Machine.Error(Errors.intOverflow);
      intVal := 0
    END;
    sym := int
  ELSIF (ch = '"') OR (ch = "'") THEN
    closeCh := ch;
    Machine.Read(ch);
    ok := TRUE;
    strLen := 0;
    WHILE (ch >= ' ') & (ch # closeCh) DO
      IF strLen = LEN(strVal) - 1 THEN
        ok := FALSE
      ELSE
        strVal[strLen] := ch;
        INC(strLen)
      END;
      Machine.Read(ch)
    END;
    strVal[strLen] := 0X;
    IF ch < ' ' THEN
      Machine.Error(Errors.unclosedStr);
      strVal := '';
      strLen := 0
    ELSE
      Machine.Read(ch);
      IF ~ok THEN
        Machine.Error(Errors.longStr);
        strVal := '';
        strLen := 0
      END
    END;
    sym := string
  ELSE
    strVal[0] := ch;
    strVal[1] := 0X;
    strLen := 1;
    sym := string;
    Machine.Read(ch)
  END;
END Get;

PROCEDURE Init*;
BEGIN
  Machine.Read(ch)
END Init;

END Scanner.
