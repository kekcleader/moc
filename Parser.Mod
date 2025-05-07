MODULE Parser;
IMPORT Out, Strings, Table, Tree, Machine, S := Scanner, B := Builder;

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
    ELSIF sym = S.real THEN
      Out.String('real '); Out.Real(S.realVal, 0)
    ELSIF sym = S.ident THEN
      Out.String('ident '); Out.String(S.identVal)
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
    ELSIF sym = S.false     THEN Out.String('false')
    ELSIF sym = S.true      THEN Out.String('true')
    ELSIF sym = S.nil       THEN Out.String('nil')
    ELSIF sym = S.not       THEN Out.String('not')
    ELSIF sym = S.lparen    THEN Out.String('lparen')
    ELSIF sym = S.lbrak     THEN Out.String('lbrak')
    ELSIF sym = S.lbrace    THEN Out.String('lbrace')
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

(** Reports whether sym is the expected symbol. If not, reports an error. *)
PROCEDURE Check(expectedSym: INTEGER): BOOLEAN;
BEGIN
  IF sym # expectedSym THEN
    Machine.ErrorExpected(expectedSym)
  END
RETURN sym = expectedSym END Check;

(** Checks that sym is the expected symbol and skips it, or reports an error. *)
PROCEDURE Skip(expectedSym: INTEGER);
BEGIN
  IF sym = expectedSym THEN
    S.Get(sym)
  ELSE
    Machine.ErrorExpected(expectedSym)
  END
END Skip;

(** If sym is the expected symbol then skips it and returns true,
    otherwise returns false. *)
PROCEDURE Skipped(expectedSym: INTEGER): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  ok := sym = expectedSym;
  IF ok THEN S.Get(sym) END
RETURN ok END Skipped;

(** qualident = [ident "."] ident. *)

(** ConstDeclaration = identdef "=" ConstExpression. *)

(** ConstExpression = expression. *)

(** TypeDeclaration = identdef "=" type. *)

(** type = qualident | ArrayType | RecordType | PointerType | ProcedureType. *)

(** ArrayType = ARRAY length {"," length} OF type.
     length = ConstExpression. *)

(** RecordType = RECORD ["(" BaseType ")"] [FieldListSequence] END.
     BaseType = qualident. *)

(** VariableDeclaration = IdentList ":" type.
     IdentList = identdef {"," identdef}. *)

(** designator = qualident {selector}.
     selector = "." ident | "[" ExpList "]" | "^" | "(" qualident ")". *)

(** expression = SimpleExpression [relation SimpleExpression].
     relation = "=" | "#" | "<" | "<=" | ">" | ">=" | IN | IS. *)

(** SimpleExpression = ["+" | "-"] term {AddOperator term}.
     AddOperator = "+" | "-" | OR. *)

(** term = factor {MulOperator factor}.
     MulOperator = "*" | "/" | DIV | MOD | "&". *)

(** factor = number | string | NIL | TRUE | FALSE |
    set | designator [ActualParameters] | "(" expression ")" | "~" factor. *)

(** ActualParameters = "(" [ExpList] ")" .
     ExpList = expression {"," expression}. *)

(** assignment = designator ":=" expression. *)

(** ProcedureCall = designator [ActualParameters]. *)

(** IfStatement = IF expression THEN StatementSequence
    {ELSIF expression THEN StatementSequence}
    [ELSE StatementSequence] END. *)

(** WhileStatement = WHILE expression DO StatementSequence
    {ELSIF expression DO StatementSequence} END. *)

(** RepeatStatement = REPEAT StatementSequence UNTIL expression. *)

(** StatementSequence = statement {";" statement}.
     statement = [assignment | ProcedureCall | IfStatement | CaseStatement |
    WhileStatement | RepeatStatement | ForStatement]. *)

(** DeclarationSequence = [CONST {ConstDeclaration ";"}]
    [TYPE {TypeDeclaration ";"}] [VAR {VariableDeclaration ";"}]
    {ProcedureDeclaration ";"}. *)

(** FormalParameters = "(" [FPSection {";" FPSection}] ")" [":" qualident].
     FPSection = [VAR] ident {"," ident} ":" FormalType.
     FormalType = {ARRAY OF} qualident. *)

(** ProcedureDeclaration = ProcedureHeading ";" ProcedureBody ident.
     ProcedureHeading = PROCEDURE identdef [FormalParameters].
     ProcedureBody = DeclarationSequence [BEGIN StatementSequence]
    [RETURN expression] END. *)

(** import = ident [":=" ident]. *)
PROCEDURE Import(mod: Table.Object);
VAR name: S.Ident;
BEGIN
  IF Check(S.ident) THEN
    Strings.Copy(S.identVal, name);
    S.Get(sym);
    IF Skipped(S.becomes) THEN
      Table.Import(name, S.identVal, mod.name);
      S.Get(sym)
    ELSE
      Table.Import(name, name, mod.name);
    END
  END
END Import;

(** module = MODULE ident ";" [ImportList] DeclarationSequence
    [BEGIN StatementSequence] END ident "." .
     ImportList = IMPORT import {"," import} ";". *)
PROCEDURE Module(VAR x: Tree.Node);
VAR mod: Table.Object;
BEGIN
  Skip(S.module);
  IF Check(S.ident) THEN
    mod := Table.NewObject();
    mod.scope := Table.topScope;(*TODO*)
    mod.class := Table.Mod;
    mod.constVal := Table.NewConst();
    mod.type := Table.noType;
    Strings.Copy(S.identVal, mod.name);
    S.Get(sym);

    Skip(S.semicolon);
    IF Skipped(S.import) THEN
      Import(mod);
      WHILE Skipped(S.comma) DO
        Import(mod)
      END;
      Skip(S.semicolon)
    END;


    B.Enter(x);
    x.object := mod
  END
END Module;

PROCEDURE Parse*(): Tree.Node;
VAR module: Tree.Node;
BEGIN
  S.Init;
  S.Get(sym);
  Module(module)
RETURN module END Parse;

END Parser.
