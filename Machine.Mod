MODULE Machine;
IMPORT Out, Errors := MocErrors, Files;

CONST
  maxInt* = 2147483647; (** Maximum integer value, 32-bit *)
  maxExp* = 38; (** Maximum exponent of a real value *)

TYPE
  Pos* = RECORD
    line*, col*: INTEGER
  END;

VAR
  debug: BOOLEAN;

  fname: ARRAY 256 OF CHAR;
  r: Files.Rider;
  prevChar: CHAR;
  pos*: Pos; (** Current position in the source file being read *)
  errorPos*: Pos; (** Position of the last error. If no errors, line = -1 *)
  wasError*: BOOLEAN; (** TRUE after a call to Error *)

(** Begins output of an error if its position is different from the last one.
    Returns true on success and false if the position is the same. *)
PROCEDURE BeginError(): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  IF (pos.line # errorPos.line) OR (pos.col # errorPos.col) THEN
    Out.String(fname); Out.Char(':');
    Out.Int(pos.line, 0); Out.Char(':');
    Out.Int(pos.col, 0); Out.String(': ошибка: '); (*FIXME*)
    errorPos := pos;
    ok := TRUE
  ELSE
    ok := FALSE
  END
RETURN ok END BeginError;

PROCEDURE Error*(n: INTEGER);
VAR s: ARRAY 1024 OF CHAR;
BEGIN
  IF BeginError() THEN
    Errors.Message(n, s);
    Out.String(s); Out.Ln
  END
END Error;

PROCEDURE ErrorExpected*(symExpected, symFound: INTEGER);
BEGIN
  IF BeginError() THEN
    Errors.PrintSymbol(symExpected);
    Out.String(' expected, but ');
    Errors.PrintSymbol(symFound);
    Out.String(' found');
    Out.Ln
  END
END ErrorExpected;

(** Returns next character from the file opened. On end of file return 0X.
    Keeps track of the current position in the file in terms of line:column. *)
PROCEDURE Read*(VAR ch: CHAR);
BEGIN
  IF r.eof THEN
    ch := 0X
  ELSE
    IF prevChar = 0AX THEN
      INC(pos.line);
      pos.col := 1
    ELSE
      INC(pos.col)
    END;
    Files.ReadChar(r, prevChar);
    ch := prevChar
  END
END Read;

PROCEDURE OpenSourceFile*(filename: ARRAY OF CHAR): BOOLEAN;
VAR F: Files.File;
BEGIN
  F := Files.Old(filename);
  IF F = NIL THEN
    fname := ''
  ELSE
    fname := filename;
    Files.Set(r, F, 0);
    prevChar := 0X
  END;
  pos.line := 1;
  pos.col := 1;
  errorPos.line := -1;
  wasError := F = NIL
RETURN ~wasError END OpenSourceFile;

PROCEDURE SetDebug*(value: BOOLEAN);
BEGIN
  debug := value
END SetDebug;

BEGIN
  debug := FALSE
END Machine.
