MODULE Parser;
IMPORT Out, T := Table, Machine, S := Scanner;

CONST

TYPE

VAR
  sym: INTEGER; (** Read-ahead symbol *)

PROCEDURE TestScanner;
BEGIN
  WHILE sym # S.eot DO
    IF sym = S.string THEN
      Out.String('string ['); Out.Int(S.strLen, 0);
      Out.String("] '"); Out.String(S.strVal); Out.Char("'")
    ELSIF sym = S.int THEN
      Out.String('int '); Out.Int(S.intVal, 0)
    ELSIF sym = S.times     THEN Out.String('times')
    ELSIF sym = S.rdiv      THEN Out.String('rdiv')
    ELSIF sym = S.div       THEN Out.String('div')
    ELSIF sym = S.mod       THEN Out.String('mod')
    ELSIF sym = S.and       THEN Out.String('and')
    ELSIF sym = S.plus      THEN Out.String('plus')
    ELSIF sym = S.minus     THEN Out.String('minus')
    ELSIF sym = S.or        THEN Out.String('or')
    ELSIF sym = S.eql       THEN Out.String('eql')
    ELSIF sym = S.neq       THEN Out.String('neq')
    ELSIF sym = S.lss       THEN Out.String('lss')
    ELSIF sym = S.leq       THEN Out.String('leq')
    ELSIF sym = S.gtr       THEN Out.String('gtr')
    ELSIF sym = S.geq       THEN Out.String('geq')
    ELSIF sym = S.in        THEN Out.String('in')
    ELSIF sym = S.is        THEN Out.String('is')
    ELSIF sym = S.arrow     THEN Out.String('arrow')
    ELSIF sym = S.period    THEN Out.String('period')
    ELSIF sym = S.char      THEN Out.String('char')
    ELSIF sym = S.int       THEN Out.String('int')
    ELSIF sym = S.real      THEN Out.String('real')
    ELSIF sym = S.false     THEN Out.String('false')
    ELSIF sym = S.true      THEN Out.String('true')
    ELSIF sym = S.nil       THEN Out.String('nil')
    ELSIF sym = S.string    THEN Out.String('string')
    ELSIF sym = S.not       THEN Out.String('not')
    ELSIF sym = S.lparen    THEN Out.String('lparen')
    ELSIF sym = S.lbrak     THEN Out.String('lbrak')
    ELSIF sym = S.lbrace    THEN Out.String('lbrace')
    ELSIF sym = S.ident     THEN Out.String('ident')
    ELSIF sym = S.if        THEN Out.String('if')
    ELSIF sym = S.while     THEN Out.String('while')
    ELSIF sym = S.repeat    THEN Out.String('repeat')
    ELSIF sym = S.case      THEN Out.String('case')
    ELSIF sym = S.for       THEN Out.String('for')
    ELSIF sym = S.comma     THEN Out.String('comma')
    ELSIF sym = S.colon     THEN Out.String('colon')
    ELSIF sym = S.becomes   THEN Out.String('becomes')
    ELSIF sym = S.upto      THEN Out.String('upto')
    ELSIF sym = S.rparen    THEN Out.String('rparen')
    ELSIF sym = S.rbrak     THEN Out.String('rbrak')
    ELSIF sym = S.rbrace    THEN Out.String('rbrace')
    ELSIF sym = S.then      THEN Out.String('then')
    ELSIF sym = S.of        THEN Out.String('of')
    ELSIF sym = S.do        THEN Out.String('do')
    ELSIF sym = S.to        THEN Out.String('to')
    ELSIF sym = S.by        THEN Out.String('by')
    ELSIF sym = S.semicolon THEN Out.String('semicolon')
    ELSIF sym = S.end       THEN Out.String('end')
    ELSIF sym = S.bar       THEN Out.String('bar')
    ELSIF sym = S.else      THEN Out.String('else')
    ELSIF sym = S.elsif     THEN Out.String('elsif')
    ELSIF sym = S.until     THEN Out.String('until')
    ELSIF sym = S.return    THEN Out.String('return')
    ELSIF sym = S.array     THEN Out.String('array')
    ELSIF sym = S.record    THEN Out.String('record')
    ELSIF sym = S.pointer   THEN Out.String('pointer')
    ELSIF sym = S.const     THEN Out.String('const')
    ELSIF sym = S.type      THEN Out.String('type')
    ELSIF sym = S.var       THEN Out.String('var')
    ELSIF sym = S.procedure THEN Out.String('procedure')
    ELSIF sym = S.begin     THEN Out.String('begin')
    ELSIF sym = S.import    THEN Out.String('import')
    ELSIF sym = S.module    THEN Out.String('module')
    ELSIF sym = S.eot       THEN Out.String('eot')
    ELSE
      Out.Int(sym, 4)
    END;
    S.Get(sym);
    Out.Ln
  END;
  Out.String('eot'); Out.Ln
END TestScanner;

PROCEDURE Module*(): T.Module;
VAR m: T.Module;
BEGIN
  S.Init;
  S.Get(sym);
  TestScanner;

  NEW(m);
  m.name := 'TestModule';
  RETURN m
END Module;

END Parser.
