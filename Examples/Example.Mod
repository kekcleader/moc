MODULE Example;
IMPORT Out;
CONST
  trees = 5;
VAR
  x, y: INTEGER;
  ch: CHAR;
  a, b, c: BOOLEAN;
BEGIN
;;;;
  x := x * x * x + x;
  y := 11;
  x := (-x + y * 2 + x * x) MOD (y - x);
  x := x DIV y;
  ch := 51X;
END Example.
