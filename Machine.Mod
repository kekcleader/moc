MODULE Machine;
IMPORT Out;

CONST

TYPE

VAR
  debug: BOOLEAN;

PROCEDURE Do*;
BEGIN
END Do;

PROCEDURE OpenSourceFile*(fname: ARRAY OF CHAR): BOOLEAN;
BEGIN
  RETURN TRUE
END OpenSourceFile;

PROCEDURE SetDebug*(value: BOOLEAN);
BEGIN
  debug := value
END SetDebug;

BEGIN
  debug := FALSE
END Machine.
