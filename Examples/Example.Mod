MODULE Example;
IMPORT Out;
CONST
  trees = 5;
  apple = 2 + 4 * trees - 1;
VAR
  x, y: INTEGER;
  ch: CHAR;
  a, b, c: BOOLEAN;
BEGIN
;;;;
  x := x * x * x + x;
  y := 11 + trees * apple;
  x := (-x + y * 2 + x * x) MOD (y - x);
  x := x DIV y;
  ch := 51X;
  Out.Int(x, 10);
  Out.Int(y, 10);
  Out.Ln
END Example.
