MODULE MocErrors;
IMPORT Strings, Int;

CONST
  longIdent*   = 1;
  longStr*     = 2;
  unclosedStr* = 3;
  intOverflow* = 4;

TYPE
  Params* = RECORD
    
  END;

PROCEDURE Message*(errno: INTEGER; VAR s: ARRAY OF CHAR);
BEGIN
  IF    errno = longIdent   THEN s := 'Identifier too long'
  ELSIF errno = longStr     THEN s := 'String too long'
  ELSIF errno = unclosedStr THEN s := 'Unclosed string literal'
  ELSIF errno = intOverflow THEN s := 'Integer overflow'
  ELSE
    s := '#ERR'; Int.Append(errno, s)
  END
END Message;

END MocErrors.
