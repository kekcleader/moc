MODULE Example;
IMPORT Out;
CONST
  N = 5;
  M = N * 10 - 14;
VAR
  a, b: INTEGER;
BEGIN
  a := M + 1;
  b := 4096 + 65;
  Out.Int(b, 0);
  Out.Ln
END Example.
