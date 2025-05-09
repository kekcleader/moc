MODULE Parser;
IMPORT Out, Strings, Table, Tree, Machine, S := Scanner, Builder,
  Errors := MocErrors, Kernel;

CONST

TYPE
  Ident = S.Ident;

VAR
  sym: INTEGER; (** Read-ahead symbol *)

  modName: Ident;
  dummy: Table.Object;

PROCEDURE DD(n: INTEGER);
BEGIN
  Out.String('---DEBUG---'); Out.Int(n, 2); Out.String(' ---'); Out.Ln
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
      Out.String(S.identVal)
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

PROCEDURE StandardFunc(x: Tree.Node): Tree.Node;
BEGIN
  Machine.Error(Errors.notImplemented)
RETURN x END StandardFunc;

(** qualident = [ident "."] ident. *)
PROCEDURE Qualident(): Table.Object;
VAR object: Table.Object;
BEGIN
  object := Table.ThisObject(S.identVal);
  S.Get(sym);(* ident *)
  IF object = NIL THEN
    Machine.Error(Errors.undefinedIdent);
    object := dummy
  END;

  IF (object.class = Table.Mod) & Skipped(S.period) THEN
    S.Get(sym); (* . *)
    IF ~Check(S.ident) THEN
      object := dummy
    ELSE
      object := Table.ThisImport(object, S.identVal);
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
      Machine.Error(Errors.notImplemented);
      REPEAT S.Get(sym) UNTIL (sym = S.eot) OR (sym = S.rbrak);
      S.Get(sym) (* rbrak, TODO *)
    ELSIF sym = S.period DO (* Record field *)
      Machine.Error(Errors.notImplemented)
    ELSIF sym = S.arrow DO (* Pointer dereference *)
      Machine.Error(Errors.notImplemented)
    ELSIF (sym = S.lparen) & (* Type guard *)
          (designator.type.form IN {Table.Record, Table.Pointer})
    DO
      Machine.Error(Errors.notImplemented);
      REPEAT S.Get(sym) UNTIL (sym = S.eot) OR (sym = S.rparen);
      S.Get(sym) (* rparen, TODO *)
    END
  END
RETURN designator END Designator;

(** ActualParameters = "(" [ExpList] ")".
     ExpList = expression {"," expression}. *)
PROCEDURE ActualParameters(formal: Table.Object): Tree.Node;
VAR actual, list, last: Tree.Node;
  n: INTEGER;
BEGIN
  Skip(S.lparen);
  IF sym # S.rparen THEN
    actual := Expression();
    IF formal # NIL THEN
      Builder.Param(actual, formal);
      list := actual;
      last := list;
      formal := formal.next;
      n := 1;
      WHILE Skipped(S.comma) DO
        actual := Expression();
        IF formal # NIL THEN
          Builder.Param(actual, formal);
          last.link := actual;
          formal := formal.next;
          INC(n)
        END
      END
    END
  END;
  Skip(S.rparen)
RETURN list END ActualParameters;

(** ProcedureCall = designator [ActualParameters]. *)
PROCEDURE ProcedureCall(designator: Tree.Node): Tree.Node;
VAR assign, expr: Tree.Node;
BEGIN
  Machine.Error(Errors.notImplemented)
RETURN assign END ProcedureCall;

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
    IF x.class = Table.SFunc THEN
      x := StandardFunc(x)
    ELSE
      IF Skipped(S.lparen) & (x.type.form = Table.Proc) &
         (x.type.base.form # Table.NoTyp)
      THEN
        formalParams := Builder.PrepareCall(x);
        actualParams := ActualParameters(formalParams);
        x := Builder.Call(x, actualParams, formalParams);
        Skip(S.rparen)
      END
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
  (*TODO true, false, string, nil, etc.*)
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
  (* {AddOperator term} *)
  IF (S.times <= sym) & (sym <= S.and) THEN
    op := sym;
    S.Get(sym); (* op *)
    y := Factor();
    x := Builder.NewDyadicOperator(op, x, y)
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
    x := Builder.NewMonadicOperator(op, x)
  ELSIF sym = S.plus THEN
    S.Get(sym);
    x := Term()
  ELSE
    x := Term()
  END;
  (* {AddOperator term} *)
  IF (S.plus <= sym) & (sym <= S.or) THEN
    op := sym;
    S.Get(sym); (* op *)
    y := Term();
    x := Builder.NewDyadicOperator(op, x, y)
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
    x := Builder.NewDyadicOperator(relation, x, y)
  ELSIF sym = S.in THEN
    Machine.Error(Errors.notImplemented)
  ELSIF sym = S.is THEN
    Machine.Error(Errors.notImplemented)
  END
RETURN x END Expression;

(** assignment = designator ":=" expression. *)
PROCEDURE Assignment(designator: Tree.Node): Tree.Node;
VAR assign, expr: Tree.Node;
BEGIN
  expr := Expression();
  assign := Tree.NewNode(Tree.NAssign);
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
  ELSIF (sym = S.case) OR (sym = S.repeat) OR (sym = S.for) THEN
    Machine.Error(Errors.notImplemented)
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

  first := Statement();
  prev := first;
  WHILE Skipped(S.semicolon) DO
    statement := Statement();
    prev.link := statement
  END
RETURN first END StatementSequence;

(** ConstExpression = expression. *)
PROCEDURE ConstExpression(): Tree.Node;
VAR const: Tree.Node;
BEGIN
  S.Get(sym); (*FIXME*)
  const := Tree.NewNode(Tree.NConst);
  const.type := Table.intType;
  const.constVal := Table.NewConst();
  const.constVal.intVal := 25
RETURN const END ConstExpression;

(** ConstDeclaration = identdef "=" ConstExpression.
     identdef = ident. *)
PROCEDURE ConstDeclaration;
VAR expr: Tree.Node;
  obj: Table.Object;
BEGIN
  obj := Table.NewObject(S.identVal, Table.Const);
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
    ELSIF (obj.type = NIL) OR (obj.type.form = Table.NoTyp) THEN
      Machine.Error(Errors.undefinedType)
    ELSE
      type := obj.type
    END
  ELSIF (sym = S.array) OR (sym = S.record) OR (sym = S.pointer) OR
        (sym = S.procedure) THEN
    Machine.Error(Errors.notImplemented)
  ELSE
    Machine.Error(Errors.noType)
  END
RETURN type END Type;

(** TypeDeclaration = identdef "=" type. *)
PROCEDURE TypeDeclaration;
BEGIN
  Machine.Error(Errors.notImplemented); (*TODO*)
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
  first := Table.NewObject(S.identVal, class);
  S.Get(sym); (* ident *)
  WHILE sym = S.comma DO
    S.Get(sym); (* comma *)
    obj := Table.NewObject(S.identVal, class);
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
    Strings.Copy(S.identVal, name);
    S.Get(sym);
    IF Skipped(S.becomes) THEN
      Table.Import(name, S.identVal, modName);
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
  mod: Table.Object;
  name: Ident;
  procedures, statementSequence: Tree.Node;
BEGIN
  Skip(S.module);
  IF Check(S.ident) THEN
    Strings.Copy(S.identVal, modName);
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
      IF S.identVal # mod.name THEN
        Machine.Error(Errors.modNameMismatch)
      ELSE
        S.Get(sym); (* ident *)
        Skip(S.semicolon)
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
