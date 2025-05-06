MODULE MocErrors;
IMPORT Strings, Int;

CONST
  none*          = 0;
  longIdent*     = 1;
  longStr*       = 2;
  unclosedStr*   = 3;
  intOverflow*   = 4;
  manyDigits*    = 5;
  badInt*        = 6;
  badReal*       = 7;
  badChar*       = 8;
  largeExponent* = 9;
  noDigit*       = 30;

TYPE
  Params* = RECORD
    
  END;

PROCEDURE Message*(errno: INTEGER; VAR s: ARRAY OF CHAR);
BEGIN
  IF    errno = longIdent     THEN s := 'Identifier too long'
  ELSIF errno = longStr       THEN s := 'String too long'
  ELSIF errno = unclosedStr   THEN s := 'Unclosed string literal'
  ELSIF errno = intOverflow   THEN s := 'Integer overflow'
  ELSIF errno = manyDigits    THEN s := 'Too many digits'
  ELSIF errno = badInt        THEN s := 'Bad integer literal'
  ELSIF errno = badReal       THEN s := 'Bad real literal'
  ELSIF errno = badChar       THEN s := 'Unexpected input character'
  ELSIF errno = largeExponent THEN s := 'Exponent too large'
  ELSIF errno = noDigit     THEN s := 'Digit expected'
  ELSE
    s := '#ERR'; Int.Append(errno, s)
  END
END Message;

END MocErrors.
