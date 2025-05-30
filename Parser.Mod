MODULE Parser;
IMPORT Out, Strings, Table, Tree, Machine, S := Scanner, Builder,
  Errors := MocErrors, Kernel;

TYPE
  Ident = S.Ident;

VAR
  sym: INTEGER; (** Read-ahead symbol *)

  modName: Ident;
  dummy: Table.Object;

PROCEDURE DD(n: INTEGER);
BEGIN
  Out.Char(1BX); Out.String('[41m');
  Out.Char(1BX); Out.String('[30m');
  Out.String(' ========================> DEBUG ===> ');
  Out.Char(1BX); Out.String('[97m');
  Out.Int(n, 0); Out.Char(' ');
  Out.Char(1BX); Out.String('[0m'); Out.Ln
END DD;

PROCEDURE TestScanner;
BEGIN
  WHILE sym # S.eot DO
    IF sym = S.string THEN
      Out.String('string [');
      Out.Int(S.strLen, 0); Out.String("] '");
      Out.String(S.strVal); Out.Char("'")
    ELSIF sym = S.int THEN
      Out.String('int ');
      Out.Int(S.intVal, 0)
    ELSIF sym = S.real THEN
      Out.String('real ');
      Out.Real(S.realVal, 0)
    ELSIF sym = S.ident THEN
      Out.String('ident ');
      Out.String(S.name)
    ELSE
      Errors.PrintSymbol(sym)
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
    Machine.ErrorExpected(expectedSym, sym)
  END
RETURN sym = expectedSym END Check;

(** Checks that sym is the expected symbol and skips it, or reports an error. *)
PROCEDURE Skip(expectedSym: INTEGER);
BEGIN
  IF sym = expectedSym THEN
    S.Get(sym)
  ELSE
    Machine.ErrorExpected(expectedSym, sym)
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

PROCEDURE StandardProcedureCall(x: Tree.Node): Tree.Node;
BEGIN
  Machine.NotImplemented('standard procedure call')
RETURN x END StandardProcedureCall;

(** qualident = [ident "."] ident. *)
PROCEDURE Qualident(): Table.Object;
VAR object: Table.Object;
BEGIN
  object := Table.ThisObject(S.name);
  S.Get(sym); (* ident *)
  IF object = NIL THEN
    Machine.Error(Errors.undefinedIdent);
    object := dummy
  END;

  IF (object.class = Table.Mod) & Skipped(S.period) THEN
    IF ~Check(S.ident) THEN
      object := dummy
    ELSE
      object := Table.ThisImport(object, S.name);
      S.Get(sym); (* ident *)
      IF object = NIL THEN
        Machine.Error(Errors.undefinedIdent);
        object := dummy
      END
    END
  END
RETURN object END Qualident;

PROCEDURE ^ Expression(): Tree.Node;

(** designator = qualident {selector}.
     selector = "." ident | "[" ExpList "]" | "^" | "(" qualident ")". *)
PROCEDURE Designator(): Tree.Node;
VAR designator: Tree.Node;
  qualident: Table.Object;
BEGIN
  qualident := Qualident();
  designator := Builder.NewLeaf(qualident);
  IF designator.class # Table.SProc THEN
    (* Selectors *)
    WHILE sym = S.lbrak DO (* Array index *)
      Machine.NotImplemented('array index');
      REPEAT S.Get(sym) UNTIL (sym = S.eot) OR (sym = S.rbrak);
      S.Get(sym) (* rbrak, TODO *)
    ELSIF sym = S.period DO (* Record field *)
      S.Get(sym); (*TODO*)
      Machine.NotImplemented('record field')
    ELSIF sym = S.arrow DO (* Pointer dereference *)
      S.Get(sym); (*TODO*)
      Machine.NotImplemented('pointer dereference')
    ELSIF (sym = S.lparen) & (* Type guard *)
          (designator.type.form IN {Table.Record, Table.Pointer})
    DO
      Machine.NotImplemented('type guard');
      REPEAT S.Get(sym) UNTIL (sym = S.eot) OR (sym = S.rparen);
      Skip(S.rparen) (*TODO*)
    END
  END
RETURN designator END Designator;

(** ActualParameters = "(" [ExpList] ")".
     ExpList = expression {"," expression}.
     Precondition: sym = S.lparen *)
PROCEDURE ActualParameters(procedure: Tree.Node;
  formal: Table.Object): Tree.Node;
VAR actual, list, last: Tree.Node;
  n, paramCount: INTEGER;
BEGIN
  Skip(S.lparen);
  n := 0;
  paramCount := procedure.object.type.paramCount;
  IF sym # S.rparen THEN
    actual := Expression();
    IF formal = NIL THEN
      Machine.Error(Errors.manyArguments);
    ELSE
      Builder.Param(actual, formal);
      list := actual;
      last := list;
      formal := formal.next;
      INC(n);
      WHILE Skipped(S.comma) DO
        actual := Expression();
        IF formal # NIL THEN
          Builder.Param(actual, formal);
          last.link := actual;
          formal := formal.next;
        END;
        INC(n)
      END
    END
  END;
  IF n < paramCount THEN
    Machine.Error(Errors.fewArguments)
  ELSIF n > paramCount THEN
    Machine.Error(Errors.manyArguments)
  END;
  Skip(S.rparen)
RETURN list END ActualParameters;

(** ProcedureCall = designator [ActualParameters].
     Precondition: designator already read. *)
PROCEDURE ProcedureCall(designator: Tree.Node): Tree.Node;
VAR formalParams: Table.Object;
  actualParams, x: Tree.Node;
BEGIN
  IF (designator.class # Tree.NProc) OR
     (designator.object.type.form # Table.Proc) THEN
    Machine.Error(Errors.notProcedure)
  ELSIF designator.object.constVal.intVal > 0 THEN (* Standard procedure *)
    IF designator.object.class = Table.SFunc THEN
      Machine.Error(Errors.procCallFunc)
    ELSE (* class = SProc *)
      x := StandardProcedureCall(designator)
    END
  ELSE (* Non-standard procedure *)
    formalParams := Builder.PrepareCall(designator);
    IF sym = S.lparen THEN
      actualParams := ActualParameters(designator, formalParams)
    END;
    IF designator.type.base.form # Table.NoType THEN
      Machine.Error(Errors.procCallFunc)
    END;
    x := Builder.Call(designator, actualParams, formalParams)
  END
RETURN x END ProcedureCall;

(** factor = number | string | NIL | TRUE | FALSE |
    set | designator [ActualParameters] | "(" expression ")" | "~" factor. *)
PROCEDURE Factor(): Tree.Node;
VAR x, y: Tree.Node;
  op: INTEGER;
  qualident, formalParams: Table.Object;
  actualParams: Tree.Node;
BEGIN
  (* Sync *)
  IF (sym < S.char) OR (sym > S.ident) THEN
    Machine.ErrorExpectedMsg(Errors.noExpression, sym);
    REPEAT S.Get(sym) UNTIL (sym >= S.char) & (sym <= S.for) OR (sym >= S.then)
  END;

  IF sym = S.ident THEN
    x := Designator();
    IF (x.class = Tree.NProc) & (x.object.class = Table.SFunc) THEN
      x := StandardProcedureCall(x)
    ELSIF Skipped(S.lparen) & (x.type.form = Table.Proc) &
          (x.type.base.form # Table.NoType)
    THEN
      formalParams := Builder.PrepareCall(x);
      actualParams := ActualParameters(x, formalParams);
      Skip(S.rparen);
      x := Builder.Call(x, actualParams, formalParams)
    END
  ELSIF sym = S.int THEN
    x := Builder.NewIntConst(S.intVal);
    S.Get(sym)
  ELSIF sym = S.char THEN
    x := Builder.NewIntConst(S.intVal);
    x.type := Table.charType;
    S.Get(sym)
  ELSIF sym = S.real THEN
    x := Builder.NewRealConst(S.realVal);
    S.Get(sym)
  ELSIF Skipped(S.not) THEN
    x := Factor();
    x := Builder.MonadicOperator(S.not, x)
  (*TODO true, false, string, nil, etc.*)
  ELSIF Skipped(S.lparen) THEN (* Subexpression *)
    x := Expression();
    Skip(S.rparen)
  ELSE
    Machine.Error(Errors.noFactor);
    S.Get(sym);
    x := Builder.NewIntConst(0)
  END
RETURN x END Factor;

(** term = factor {MulOperator factor}.
     MulOperator = "*" | "/" | DIV | MOD | "&". *)
PROCEDURE Term(): Tree.Node;
VAR x, y: Tree.Node;
  op: INTEGER;
BEGIN
  x := Factor();
  (* {MulOperator factor} *)
  WHILE (S.times <= sym) & (sym <= S.and) DO
    op := sym;
    S.Get(sym); (* op *)
    y := Factor();
    x := Builder.DyadicOperator(op, x, y)
  END
RETURN x END Term;

(** SimpleExpression = ["+" | "-"] term {AddOperator term}.
     AddOperator = "+" | "-" | OR. *)
PROCEDURE SimpleExpression(): Tree.Node;
VAR x, y: Tree.Node;
  op: INTEGER;
BEGIN
  (* ["+" | "-"] term *)
  IF sym = S.minus THEN
    S.Get(sym);
    x := Term();
    x := Builder.MonadicOperator(S.minus, x)
  ELSE
    IF sym = S.plus THEN S.Get(sym) END;
    x := Term()
  END;
  (* {AddOperator term} *)
  WHILE (S.plus <= sym) & (sym <= S.or) DO
    op := sym;
    S.Get(sym); (* op *)
    y := Term();
    x := Builder.DyadicOperator(op, x, y)
  END
RETURN x END SimpleExpression;

(** expression = SimpleExpression [relation SimpleExpression].
     relation = "=" | "#" | "<" | "<=" | ">" | ">=" | IN | IS. *)
PROCEDURE Expression(): Tree.Node;
VAR x, y: Tree.Node;
  relation: INTEGER;
BEGIN
  x := SimpleExpression();
  IF (S.eql <= sym) & (sym <= S.geq) THEN
    relation := sym;
    S.Get(sym); (* relation *)
    y := SimpleExpression();
    x := Builder.DyadicOperator(relation, x, y)
  ELSIF sym = S.in THEN
    Machine.NotImplemented('operator IN')
  ELSIF sym = S.is THEN
    Machine.NotImplemented('operator IS')
  END
RETURN x END Expression;

(** assignment = designator ":=" expression.
     Precondition: designator and ":=" already read. *)
PROCEDURE Assignment(designator: Tree.Node): Tree.Node;
VAR assign, expr: Tree.Node;
BEGIN
  expr := Expression();
  assign := Tree.NewNode(Tree.NAssign);
  assign.subclass := Tree.assign;
  assign.left := designator;
  assign.right := expr
RETURN assign END Assignment;

(** IfStatement = IF expression THEN StatementSequence
    {ELSIF expression THEN StatementSequence}
    [ELSE StatementSequence] END. *)
PROCEDURE IfStatement(): Tree.Node;
VAR if: Tree.Node;
BEGIN

RETURN if END IfStatement;

(** WhileStatement = WHILE expression DO StatementSequence
    {ELSIF expression DO StatementSequence} END. *)
PROCEDURE WhileStatement(): Tree.Node;
VAR while: Tree.Node;
BEGIN

RETURN while END WhileStatement;

(** RepeatStatement = REPEAT StatementSequence UNTIL expression. *)
PROCEDURE RepeatStatement(): Tree.Node;
VAR repeat: Tree.Node;
BEGIN

RETURN repeat END RepeatStatement;

(** statement = [assignment | ProcedureCall | IfStatement | CaseStatement |
    WhileStatement | RepeatStatement | ForStatement]. *)
PROCEDURE Statement(): Tree.Node;
VAR statement, designator: Tree.Node;
BEGIN
  IF sym = S.ident THEN (* Assignment or procedure call *)
    designator := Designator();
    IF Skipped(S.becomes) THEN
      statement := Assignment(designator)
    ELSE
      statement := ProcedureCall(designator)
    END
  ELSIF Skipped(S.if) THEN
    statement := IfStatement()
  ELSIF Skipped(S.while) THEN
    statement := WhileStatement()
  ELSIF sym = S.case THEN
    Machine.NotImplemented('case statement')
  ELSIF sym = S.repeat THEN
    Machine.NotImplemented('repeat statement')
  ELSIF sym = S.for THEN
    Machine.NotImplemented('for statement')
  END
RETURN statement END Statement;

(** StatementSequence = statement {";" statement}. *)
PROCEDURE StatementSequence(): Tree.Node;
VAR first, prev, statement: Tree.Node;
BEGIN
  (* Sync *)
  IF ~((sym >= S.ident) & (sym <= S.for) OR (sym >= S.semicolon)) THEN
    Machine.Error(Errors.noStatement);
    REPEAT S.Get(sym) UNTIL (sym >= S.ident)
  END;

  WHILE sym = S.semicolon DO S.Get(sym) END;
  first := Statement();
  prev := first;
  WHILE Skipped(S.semicolon) DO
    WHILE sym = S.semicolon DO S.Get(sym) END;
    statement := Statement();
    prev.link := statement;
    prev := statement
  END
RETURN first END StatementSequence;

(** ConstExpression = expression. *)
PROCEDURE ConstExpression(): Tree.Node;
VAR const: Tree.Node;
BEGIN
  const := Expression();
  IF const.class # Tree.NConst THEN
    Machine.Error(Errors.notConstant);
    const := Builder.NewIntConst(0)
  END
RETURN const END ConstExpression;

(** ConstDeclaration = identdef "=" ConstExpression.
     identdef = ident. *)
PROCEDURE ConstDeclaration;
VAR expr: Tree.Node;
  obj: Table.Object;
BEGIN
  obj := Table.NewObject(S.name, Table.Const);
  S.Get(sym); (* ident *)
  IF Skipped(S.eql) THEN
    expr := ConstExpression();
    IF expr.class # Tree.NConst THEN
      Machine.Error(Errors.notConstant)
    ELSE
      obj.type := expr.type;
      obj.constVal := expr.constVal
    END
  END
END ConstDeclaration;

(** type = qualident | ArrayType | RecordType | PointerType | ProcedureType.
     ArrayType = ARRAY length {"," length} OF type.
     length = ConstExpression.
     RecordType = RECORD ["(" BaseType ")"] [FieldListSequence] END.
     BaseType = qualident. *)
PROCEDURE Type(): Table.Type;
VAR obj: Table.Object;
  type: Table.Type;
BEGIN
  IF sym = S.ident THEN
    obj := Qualident();
    IF obj.class # Table.Typ THEN
      Machine.Error(Errors.notType)
    ELSIF (obj.type = NIL) OR (obj.type.form = Table.NoType) THEN
      Machine.Error(Errors.undefinedType)
    ELSE
      type := obj.type
    END
  ELSIF sym = S.array THEN
    Machine.NotImplemented('type array')
  ELSIF sym = S.record THEN
    Machine.NotImplemented('type record')
  ELSIF sym = S.pointer THEN
    Machine.NotImplemented('type pointer')
  ELSIF sym = S.procedure THEN
    Machine.NotImplemented('procedure type')
  ELSE
    Machine.Error(Errors.noType)
  END
RETURN type END Type;

(** TypeDeclaration = identdef "=" type. *)
PROCEDURE TypeDeclaration;
BEGIN
  Machine.NotImplemented('type declaration');
  (* Sync to VAR, BEGIN, RETURN or END *)
  REPEAT
    S.Get(sym)
  UNTIL (sym = S.var) OR (sym = S.begin) OR (sym = S.return) OR (sym = S.end)
END TypeDeclaration;

(** Reads a comma-spearated identifier list, adds an object of the given
    class for each identifier and returns the first created object.
     IdentList = identdef {"," identdef}.
     identdef = ident. *)
PROCEDURE IdentList(class: INTEGER): Table.Object;
VAR first, obj: Table.Object;
BEGIN
  first := Table.NewObject(S.name, class);
  S.Get(sym); (* ident *)
  WHILE sym = S.comma DO
    S.Get(sym); (* comma *)
    obj := Table.NewObject(S.name, class);
    S.Get(sym) (* ident *)
  END
RETURN first END IdentList;

(** VariableDeclaration = IdentList ":" type. *)
PROCEDURE VariableDeclaration;
VAR first: Table.Object;
  type: Table.Type;
BEGIN
  first := IdentList(Table.Var);
  Skip(S.colon);
  type := Type();
  WHILE first # NIL DO
    first.type := type;
    first := first.next
  END
END VariableDeclaration;

(** DeclarationSequence = [CONST {ConstDeclaration ";"}]
    [TYPE {TypeDeclaration ";"}] [VAR {VariableDeclaration ";"}]
    {ProcedureDeclaration ";"}. *)
PROCEDURE DeclarationSequence(): Tree.Node;
VAR procedures: Tree.Node;
BEGIN
  (* Sync *)
  IF (sym < S.const) & (sym # S.end) & (sym # S.return) THEN
    Machine.Error(Errors.noDeclaration);
    REPEAT
      S.Get(sym)
    UNTIL (sym >= S.const) OR (sym = S.end) OR (sym = S.return)
  END;

  IF Skipped(S.const) THEN
    WHILE sym = S.ident DO
      ConstDeclaration();
      Skip(S.semicolon)
    END
  END;

  IF Skipped(S.type) THEN
    WHILE sym = S.ident DO
      TypeDeclaration();
      Skip(S.semicolon)
    END
  END;

  IF Skipped(S.var) THEN
    WHILE sym = S.ident DO
      VariableDeclaration();
      Skip(S.semicolon)
    END
  END
RETURN procedures END DeclarationSequence;

(** FormalParameters = "(" [FPSection {";" FPSection}] ")" [":" qualident].
     FPSection = [VAR] ident {"," ident} ":" FormalType.
     FormalType = {ARRAY OF} qualident. *)

(** ProcedureDeclaration = ProcedureHeading ";" ProcedureBody ident.
     ProcedureHeading = PROCEDURE identdef [FormalParameters].
     ProcedureBody = DeclarationSequence [BEGIN StatementSequence]
    [RETURN expression] END.
     identdef = ident. *)

(** import = ident [":=" ident]. *)
PROCEDURE Import;
VAR name: Ident;
BEGIN
  IF Check(S.ident) THEN
    Strings.Copy(S.name, name);
    S.Get(sym);
    IF Skipped(S.becomes) THEN
      Table.Import(name, S.name, modName);
      S.Get(sym)
    ELSE
      Table.Import(name, name, modName)
    END
  END
END Import;

(** module = MODULE ident ";" [ImportList]
    DeclarationSequence [BEGIN StatementSequence] END ident ".".
     ImportList = IMPORT import {"," import} ";". *)
PROCEDURE Module(): Tree.Node;
VAR module: Tree.Node;
  name: Ident;
  procedures, statementSequence: Tree.Node;
BEGIN
  Skip(S.module);
  IF Check(S.ident) THEN
    Strings.Copy(S.name, modName);
    S.Get(sym); (* ident *)

    (* IMPORT *)
    Skip(S.semicolon);
    IF Skipped(S.import) THEN
      Import;
      WHILE Skipped(S.comma) DO
        Import
      END;
      Skip(S.semicolon)
    END;

    (* CONST, TYPE, VAR and BEGIN *)
    procedures := DeclarationSequence();
    IF Skipped(S.begin) THEN
      statementSequence := StatementSequence()
    END;

    module := Builder.Enter(procedures, statementSequence, NIL);
    Skip(S.end);
    IF Check(S.ident) THEN
      IF S.name # modName THEN
        Machine.Error(Errors.modNameMismatch)
      ELSE
        S.Get(sym); (* ident *)
        Skip(S.period)
      END
    END
  END
RETURN module END Module;

PROCEDURE Parse*(): Tree.Node;
VAR module: Tree.Node;
BEGIN
  S.Init;
  S.Get(sym);
  Table.Init;
  module := Module()
RETURN module END Parse;

BEGIN
  NEW(dummy);
  dummy.class := Table.Var;
  dummy.type := Table.intType
END Parser.
