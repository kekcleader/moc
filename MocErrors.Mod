MODULE MocErrors;
IMPORT Out, Strings, Int;

CONST
  (** Errors **)
  none*              = 0;
  longIdent*         = 1;
  longStr*           = 2;
  unclosedStr*       = 3;
  intOverflow*       = 4;
  manyDigits*        = 5;
  badInt*            = 6;
  badReal*           = 7;
  badChar*           = 8;
  largeExponent*     = 9;
  modNameMismatch*   = 10;
  multipleImport*    = 11;
  multipleDefs*      = 12;
  aliasTaken*        = 13;
  notConstant*       = 14;
  notType*           = 15;
  notProcedure*      = 16;
  procCallFunc*      = 17;
  undefinedType*     = 18;
  undefinedIdent*    = 19;
  incompatibleTypes* = 20;
  badMonadicOperand* = 21;
  badDyadicOperands* = 22;
  notImplemented*    = 23;
  fewArguments*      = 24;
  manyArguments*     = 25;

  noDigit*           = 70;
  noDeclaration*     = 71;
  noStatement*       = 72;
  noExpression*      = 73;
  noFactor*          = 74;
  noType*            = 75;

  (** General errors **)
  outputFile*        = 101;
  outOfMemory*       = 102;
  chmodFailed*       = 103;
  signFailed*        = 104;

  (** Lexical symbols **)
  null = 0; times = 1; rdiv = 2; div = 3; mod = 4;
  and = 5; plus = 6; minus = 7; or = 8; eql = 9;
  neq = 10; lss = 11; leq = 12; gtr = 13; geq = 14;
  in = 15; is = 16; arrow = 17; period = 18;
  char = 20; int = 21; real = 22; false = 23; true = 24;
  nil = 25; string = 26; not = 27; lparen = 28; lbrak = 29;
  lbrace = 30; ident = 31;
  if = 32; while = 34; repeat = 35; case = 36; for = 37;
  comma = 40; colon = 41; becomes = 42; upto = 43; rparen = 44;
  rbrak = 45; rbrace = 46; then = 47; of = 48; do = 49;
  to = 50; by = 51; semicolon = 52; end = 53; bar = 54;
  else = 55; elsif = 56; until = 57; return = 58;
  array = 60; record = 61; pointer = 62; const = 63; type = 64;
  var = 65; procedure = 66; begin = 67; import = 68; module = 69; eot = 70;

PROCEDURE PrintSymbol*(sym: INTEGER);
BEGIN
  IF    sym = string    THEN Out.String('String')
  ELSIF sym = int       THEN Out.String('Integer')
  ELSIF sym = real      THEN Out.String('Real')
  ELSIF sym = ident     THEN Out.String('Identifier')
  ELSIF sym = times     THEN Out.String('Times')
  ELSIF sym = rdiv      THEN Out.String('Rdiv')
  ELSIF sym = div       THEN Out.String('Div')
  ELSIF sym = mod       THEN Out.String('Mod')
  ELSIF sym = and       THEN Out.String('And')
  ELSIF sym = plus      THEN Out.String('Plus')
  ELSIF sym = minus     THEN Out.String('Minus')
  ELSIF sym = or        THEN Out.String('OR')
  ELSIF sym = eql       THEN Out.String('=')
  ELSIF sym = neq       THEN Out.String('#')
  ELSIF sym = lss       THEN Out.String('<')
  ELSIF sym = leq       THEN Out.String('<=')
  ELSIF sym = gtr       THEN Out.String('>')
  ELSIF sym = geq       THEN Out.String('>=')
  ELSIF sym = in        THEN Out.String('IN')
  ELSIF sym = is        THEN Out.String('IS')
  ELSIF sym = arrow     THEN Out.String('^')
  ELSIF sym = period    THEN Out.String('.')
  ELSIF sym = char      THEN Out.String('CHAR')
  ELSIF sym = false     THEN Out.String('FALSE')
  ELSIF sym = true      THEN Out.String('TRUE')
  ELSIF sym = nil       THEN Out.String('NIL')
  ELSIF sym = not       THEN Out.String('~')
  ELSIF sym = lparen    THEN Out.String('(')
  ELSIF sym = lbrak     THEN Out.String('[')
  ELSIF sym = lbrace    THEN Out.String('{')
  ELSIF sym = if        THEN Out.String('IF')
  ELSIF sym = while     THEN Out.String('WHILE')
  ELSIF sym = repeat    THEN Out.String('REPEAT')
  ELSIF sym = case      THEN Out.String('CASE')
  ELSIF sym = for       THEN Out.String('FOR')
  ELSIF sym = comma     THEN Out.String(',')
  ELSIF sym = colon     THEN Out.String(':')
  ELSIF sym = becomes   THEN Out.String(':=')
  ELSIF sym = upto      THEN Out.String('..')
  ELSIF sym = rparen    THEN Out.String(')')
  ELSIF sym = rbrak     THEN Out.String(']')
  ELSIF sym = rbrace    THEN Out.String('}')
  ELSIF sym = then      THEN Out.String('THEN')
  ELSIF sym = of        THEN Out.String('OF')
  ELSIF sym = do        THEN Out.String('DD')
  ELSIF sym = to        THEN Out.String('TO')
  ELSIF sym = by        THEN Out.String('BY')
  ELSIF sym = semicolon THEN Out.String(';')
  ELSIF sym = end       THEN Out.String('END')
  ELSIF sym = bar       THEN Out.String('|')
  ELSIF sym = else      THEN Out.String('ELSE')
  ELSIF sym = elsif     THEN Out.String('ELSIF')
  ELSIF sym = until     THEN Out.String('UNTIL')
  ELSIF sym = return    THEN Out.String('RETURN')
  ELSIF sym = array     THEN Out.String('ARRAY')
  ELSIF sym = record    THEN Out.String('RECORD')
  ELSIF sym = pointer   THEN Out.String('POINTER')
  ELSIF sym = const     THEN Out.String('CONST')
  ELSIF sym = type      THEN Out.String('TYPE')
  ELSIF sym = var       THEN Out.String('VAR')
  ELSIF sym = procedure THEN Out.String('PROCEDURE')
  ELSIF sym = begin     THEN Out.String('BEGIN')
  ELSIF sym = import    THEN Out.String('IMPORT')
  ELSIF sym = module    THEN Out.String('MODULE')
  ELSIF sym = eot       THEN Out.String('eot')
  ELSE Out.String('symbol #'); Out.Int(sym, 0)
  END
END PrintSymbol;

PROCEDURE Message*(errno: INTEGER; VAR s: ARRAY OF CHAR);
BEGIN
  IF    errno = longIdent         THEN s := 'Identifier too long'
  ELSIF errno = longStr           THEN s := 'String too long'
  ELSIF errno = unclosedStr       THEN s := 'Unclosed string literal'
  ELSIF errno = intOverflow       THEN s := 'Integer overflow'
  ELSIF errno = manyDigits        THEN s := 'Too many digits'
  ELSIF errno = badInt            THEN s := 'Bad integer literal'
  ELSIF errno = badReal           THEN s := 'Bad real literal'
  ELSIF errno = badChar           THEN s := 'Unexpected input character'
  ELSIF errno = largeExponent     THEN s := 'Exponent too large'
  ELSIF errno = modNameMismatch   THEN s := 'Module name does not match'
  ELSIF errno = multipleImport    THEN s := 'Module already imported'
  ELSIF errno = multipleDefs      THEN s := 'Object already defined'
  ELSIF errno = aliasTaken        THEN s := 'Module alias already taken'
  ELSIF errno = notConstant       THEN s := 'Expression must be constant'
  ELSIF errno = notType           THEN s := 'This is not a type'
  ELSIF errno = notProcedure      THEN s := 'This is not a procedure'
  ELSIF errno = procCallFunc      THEN s := 'Procedure call of a function'
  ELSIF errno = undefinedType     THEN s := 'This type is undefined'
  ELSIF errno = undefinedIdent    THEN s := 'Undefined identifier'
  ELSIF errno = incompatibleTypes THEN s := 'Incompatible types'
  ELSIF errno = badMonadicOperand THEN
    s := 'Operation not applicable to this type'
  ELSIF errno = badDyadicOperands THEN
    s := 'Operation not applicable to these types'
  ELSIF errno = notImplemented    THEN s := 'Feature not implemented'
  ELSIF errno = fewArguments      THEN s := 'Too few arguments to procedure'
  ELSIF errno = manyArguments     THEN s := 'Too many arguments to procedure'
  ELSIF errno = noDigit           THEN s := 'Digit expected'
  ELSIF errno = noDeclaration     THEN
    s := 'CONST, TYPE, VAR, BEGIN, RETURN or END expected'
  ELSIF errno = noStatement  THEN s := 'Statement expected'
  ELSIF errno = noExpression THEN s := 'Expression expected'
  ELSIF errno = noFactor     THEN s := 'Factor expected'
  ELSIF errno = noType       THEN
    s := 'ARRAY, RECORD, POINTER, PROCEDURE or identifier expected'
  ELSIF errno = outputFile   THEN s := 'Could not open output file'
  ELSIF errno = outOfMemory  THEN s := 'Out of code memory'
  ELSIF errno = chmodFailed  THEN s := 'ChMod command failed'
  ELSIF errno = signFailed   THEN s := 'CodeSign command failed'
  ELSE
    s := '#ERR'; Int.Append(errno, s)
  END
END Message;

END MocErrors.
