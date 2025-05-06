MODULE Machine;
IMPORT Out, MocErrors, Files;

CONST
  maxInt* = 2147483647;

TYPE
  Pos* = RECORD
    line*, col*: INTEGER
  END;

VAR
  debug: BOOLEAN;

  fname: ARRAY 256 OF CHAR;
  r: Files.Rider;
  prevChar: CHAR;
  pos*: Pos;
  wasError*: BOOLEAN; (** TRUE after a call to Error *)

PROCEDURE Error*(n: INTEGER);
VAR s: ARRAY 1024 OF CHAR;
BEGIN
  Out.String(fname); Out.Char(':');
  Out.Int(pos.line, 0); Out.Char(':');
  Out.Int(pos.col, 0); Out.String(': error: ');
  MocErrors.Message(n, s); Out.String(s); Out.Ln
END Error;

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
  wasError := F = NIL
RETURN ~wasError END OpenSourceFile;

PROCEDURE SetDebug*(value: BOOLEAN);
BEGIN
  debug := value
END SetDebug;

BEGIN
  debug := FALSE
END Machine.
