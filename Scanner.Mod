MODULE Scanner;
IMPORT Out, Machine, Errors := MocErrors;

CONST
  identSize = 256;
  stringSize = 1024;

  uptoChar = 7FX; (** Used as a fix for double dot right after a digit *)

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
  Ident* = ARRAY identSize OF CHAR;
  StrVal* = ARRAY stringSize OF CHAR;

VAR
  (** Results of Get **)
  identVal*: Ident;
  intVal*: INTEGER;
  realVal*: REAL;
  strVal*: StrVal;
  strLen*: INTEGER;

  (** - **)
  ch: CHAR; (** Read-ahead character *)

(** Converts an uppercase hexadecimal digit to an integer. *)
PROCEDURE HexToInt(c: CHAR): INTEGER;
VAR n: INTEGER;
BEGIN
  IF ('0' <= c) & (c <= '9') THEN
    n := ORD(c) - ORD('0')
  ELSIF ('A' <= c) & (c <= 'F') THEN
    n := ORD(c) - (ORD('A') + 10)
  ELSE
    ASSERT(FALSE)
  END
RETURN n END HexToInt;

(** Reports whether ch is a decimal digit. *)
PROCEDURE IsDigit(): BOOLEAN;
RETURN ('0' <= ch) & (ch <= '9')
END IsDigit;

(** Reports whether ch is an uppercase hexadecimal digit (0..F). *)
PROCEDURE IsHex(): BOOLEAN;
RETURN IsDigit() OR ('A' <= ch) & (ch <= 'F')
END IsHex;

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
PROCEDURE IdentifyKeyword(len: INTEGER): INTEGER;
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
    IF    identVal = "END" THEN sym := end
    ELSIF identVal = "VAR" THEN sym := var
    ELSIF identVal = "NIL" THEN sym := nil
    ELSIF identVal = "DIV" THEN sym := div
    ELSIF identVal = "FOR" THEN sym := for
    END
  ELSIF len = 4 THEN
    IF    identVal = "THEN" THEN sym := then
    ELSIF identVal = "ELSE" THEN sym := else
    ELSIF identVal = "TRUE" THEN sym := true
    ELSIF identVal = "TYPE" THEN sym := type
    ELSIF identVal = "CHAR" THEN sym := char
    ELSIF identVal = "REAL" THEN sym := real
    ELSIF identVal = "CASE" THEN sym := case
    END
  ELSIF len = 5 THEN
    IF    identVal = "ELSIF" THEN sym := elsif
    ELSIF identVal = "FALSE" THEN sym := false
    ELSIF identVal = "CONST" THEN sym := const
    ELSIF identVal = "WHILE" THEN sym := while
    ELSIF identVal = "ARRAY" THEN sym := array
    ELSIF identVal = "BEGIN" THEN sym := begin
    ELSIF identVal = "UNTIL" THEN sym := until
    END
  ELSIF len = 6 THEN
    IF    identVal = "RETURN" THEN sym := return
    ELSIF identVal = "RECORD" THEN sym := record
    ELSIF identVal = "REPEAT" THEN sym := repeat
    ELSIF identVal = "IMPORT" THEN sym := import
    ELSIF identVal = "MODULE" THEN sym := module
    END
  ELSIF (len = 7) & (identVal = "POINTER")   THEN sym := pointer
  ELSIF (len = 9) & (identVal = "PROCEDURE") THEN sym := procedure
  END
RETURN sym END IdentifyKeyword;

(** Skips a possibly nested comment. Precondition: ch = '*'. *)
PROCEDURE SkipComment;
VAR prevCh: CHAR;
BEGIN
  prevCh := 0X;
  Machine.Read(ch);
  WHILE (ch # 0X) & ~((prevCh = '*') & (ch = ')')) DO
    prevCh := ch;
    Machine.Read(ch);
    IF (prevCh = '(') & (ch = '*') THEN (* Nested comment *)
      SkipComment
    END
  END;
  IF ch # 0X THEN Machine.Read(ch) END
END SkipComment;

PROCEDURE ReadNumber(VAR sym: INTEGER);
VAR i, len: INTEGER;
  ok: BOOLEAN;
  err: INTEGER;
  digits: ARRAY 16 OF INTEGER;

  PROCEDURE DecimalToInt(digits: ARRAY OF INTEGER; len: INTEGER);
  VAR i: INTEGER;
    err: INTEGER;
  BEGIN
    err := Errors.none;
    intVal := 0;
    i := 0;
    REPEAT
      IF digits[i] >= 10 THEN
        err := Errors.badInt
      ELSE
        (* Overflow check *)
        IF intVal > (Machine.maxInt - digits[i]) DIV 10 THEN
          err := Errors.intOverflow
        ELSE
          intVal := intVal * 10 + digits[i]
        END
      END;
      INC(i)
    UNTIL i = len;
    IF err # Errors.none THEN
      intVal := 0;
      Machine.Error(err)
    END
  END DecimalToInt;

  (** Returns 10 in the power of e. *)
  PROCEDURE Ten(e: INTEGER): REAL;
  VAR x, t: REAL;
  BEGIN
    x := 1.0;
    t := 10.0;
    WHILE e > 0 DO
      IF ODD(e) THEN x := t * x END;
      t := t * t;
      e := e DIV 2
    END
  RETURN x END Ten;

  PROCEDURE ReadReal(digits: ARRAY OF INTEGER; len: INTEGER);
  VAR i, exponent, scale: INTEGER;
    negE: BOOLEAN;
    ok: BOOLEAN;
  BEGIN
    ok := TRUE;
    realVal := 0.0;
    exponent := 0;
    (* Integer part *)
    i := 0;
    REPEAT
      IF digits[i] >= 10 THEN
        ok := FALSE
      ELSE
        realVal := realVal * 10.0 + FLT(digits[i])
      END;
      INC(i)
    UNTIL i = len;
    IF ~ok THEN
      realVal := 0.0;
      Machine.Error(Errors.badReal)
    END;
    (* Fraction part *)
    WHILE IsDigit() DO
      realVal := realVal * 10.0 + FLT(ORD(ch) - ORD('0'));
      DEC(exponent);
      Machine.Read(ch)
    END;
    (* Scale factor *)
    IF (ch = 'E') OR (ch = 'D') THEN
      Machine.Read(ch);
      scale := 0; 
      IF ch = '-' THEN
        Machine.Read(ch);
        negE := TRUE
      ELSE
        negE := FALSE;
        IF ch = '+' THEN Machine.Read(ch) END
      END;
      IF ~IsDigit() THEN
        Machine.Error(Errors.noDigit)
      ELSE
        REPEAT
          scale := scale * 10 + ORD(ch) - ORD('0');
          Machine.Read(ch)
        UNTIL ~IsDigit();
        IF negE THEN DEC(exponent, scale) ELSE INC(exponent, scale) END
      END
    END;
    IF exponent < 0 THEN
      IF exponent >= -Machine.maxExp THEN
        realVal := realVal / Ten(-exponent)
      ELSE
        realVal := 0.0
      END
    ELSIF exponent > 0 THEN
      IF exponent <= Machine.maxExp THEN
        realVal := Ten(exponent) * realVal
      ELSE
        Machine.Error(Errors.largeExponent);
        realVal := 0.0
      END
    END
  END ReadReal;

BEGIN
  ok := TRUE;
  len := 0;
  REPEAT
    IF len # LEN(digits) THEN
      digits[len] := HexToInt(ch);
      INC(len)
    ELSE
      ok := FALSE
    END;
    Machine.Read(ch)
  UNTIL ~IsHex();
  IF ~ok THEN
    Machine.Error(Errors.manyDigits)
  END;
  IF (ch = 'H') OR (ch = 'X') THEN (* Hexadecimal integer or char *)
    ok := TRUE;
    intVal := 0;
    i := 0;
    REPEAT (* TODO Allow negative two's compliment HEX constants *)
      (* Overflow check *)
      IF intVal > (Machine.maxInt - digits[i]) DIV 16 THEN
        ok := FALSE
      ELSE
        intVal := intVal * 16 + digits[i]
      END;
      INC(i)
    UNTIL i = len;
    IF ~ok THEN
      intVal := 0;
      Machine.Error(Errors.intOverflow)
    END;
    IF ch = 'X' THEN sym := char ELSE sym := int END;
    Machine.Read(ch)
  ELSIF ch = '.' THEN (* Real number *)
    Machine.Read(ch);
    IF ch = '.' THEN (* Upto (..) right after a digit *)
      ch := uptoChar; (* Fix for Get to read upto symbol instead of period *)
      DecimalToInt(digits, len);
      sym := int
    ELSE
      ReadReal(digits, len);
      sym := real
    END
  ELSE (* Decimal integer *)
    DecimalToInt(digits, len);
    sym := int
  END
END ReadNumber;

PROCEDURE Get*(VAR sym: INTEGER);
VAR i: INTEGER;
  closeCh: CHAR;
  ok, comment: BOOLEAN;
BEGIN
  REPEAT
    sym := null;
    comment := FALSE;
    WHILE (ch # 0X) & (ch <= ' ') DO Machine.Read(ch) END;
    IF ch = 0X THEN
      sym := eot
    ELSIF IsAlpha() THEN (* Also '_' *)
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
      sym := IdentifyKeyword(i)
    ELSIF IsDigit() THEN
      ReadNumber(sym)
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
    ELSIF ch < '0' THEN (* '!'..'/' *)
      IF    ch = '#' THEN Machine.Read(ch); sym := neq
      ELSIF ch = '&' THEN Machine.Read(ch); sym := and
      ELSIF ch = '(' THEN
        Machine.Read(ch);
        IF ch = '*' THEN
          SkipComment;
          comment := TRUE
        ELSE
          sym := lparen
        END
      ELSIF ch = ')' THEN Machine.Read(ch); sym := rparen
      ELSIF ch = '*' THEN Machine.Read(ch); sym := times
      ELSIF ch = '+' THEN Machine.Read(ch); sym := plus
      ELSIF ch = ',' THEN Machine.Read(ch); sym := comma
      ELSIF ch = '-' THEN Machine.Read(ch); sym := minus
      ELSIF ch = '.' THEN
        Machine.Read(ch);
        IF ch = '.' THEN Machine.Read(ch); sym := upto ELSE sym := period END
      ELSIF ch = '/' THEN Machine.Read(ch); sym := rdiv
      END (* ELSE ! $ % *)
    ELSIF ch < 'A' THEN (* ':'..'@' *)
      IF ch = ':' THEN
        Machine.Read(ch);
        IF ch = '=' THEN Machine.Read(ch); sym := becomes ELSE sym := lparen END
      ELSIF ch = ';' THEN Machine.Read(ch); sym := semicolon
      ELSIF ch = '<' THEN
        Machine.Read(ch);
        IF ch = '=' THEN Machine.Read(ch); sym := leq ELSE sym := lss END
      ELSIF ch = '=' THEN Machine.Read(ch); sym := eql
      ELSIF ch = '>' THEN
        Machine.Read(ch);
        IF ch = '=' THEN Machine.Read(ch); sym := geq ELSE sym := gtr END
      END (* ELSE ? @ *)
    ELSIF ch < 'a' THEN (* '['..'`' *)
      IF    ch = '[' THEN Machine.Read(ch); sym := lbrak
      ELSIF ch = ']' THEN Machine.Read(ch); sym := rbrak
      ELSIF ch = '^' THEN Machine.Read(ch); sym := arrow
      END (* ELSE \ ` *)
    ELSIF ch = '{' THEN Machine.Read(ch); sym := lbrace
    ELSIF ch = '|' THEN Machine.Read(ch); sym := bar
    ELSIF ch = '}' THEN Machine.Read(ch); sym := rbrace
    ELSIF ch = '~' THEN Machine.Read(ch); sym := not
    ELSIF ch = uptoChar THEN Machine.Read(ch); sym := upto
    END;
    IF ~comment & (sym = null) THEN
      Machine.Read(ch);
      Machine.Error(Errors.badChar)
    END
  UNTIL sym # null (* Comment *)
END Get;

PROCEDURE Init*;
BEGIN
  Machine.Read(ch)
END Init;

END Scanner.
