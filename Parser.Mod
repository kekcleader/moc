MODULE Parser;
IMPORT Out, T := Table;

CONST

TYPE

PROCEDURE Module*(): T.Module;
VAR m: T.Module;
BEGIN
  NEW(m);
  m.name := 'TestModule';
  RETURN m
END Module;

END Parser.
