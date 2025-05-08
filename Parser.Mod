MODULE Parser;
IMPORT Out, Strings, Table, Tree, Machine, S := Scanner, B := Builder,
  Errors := MocErrors;

CONST

TYPE

VAR
  sym: INTEGER; (** Read-ahead symbol *)

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
PROCEDURE StatementSequence(VAR x: Tree.Node);
BEGIN
  S.Get(sym)
END StatementSequence;

(** DeclarationSequence = [CONST {ConstDeclaration ";"}]
    [TYPE {TypeDeclaration ";"}] [VAR {VariableDeclaration ";"}]
    {ProcedureDeclaration ";"}. *)
PROCEDURE DeclarationSequence(VAR x: Tree.Node);
BEGIN
  S.Get(sym)
END DeclarationSequence;

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

(** block = DeclarationSequence [BEGIN StatementSequence]. *)
PROCEDURE Block(VAR procedures, statementSequence: Tree.Node);
BEGIN
  DeclarationSequence(procedures);
  IF Skipped(S.begin) THEN
    StatementSequence(statementSequence)
  END
END Block;

(** module = MODULE ident ";" [ImportList] block END ident "." .
     ImportList = IMPORT import {"," import} ";". *)
PROCEDURE Module(VAR x: Tree.Node);
VAR mod: Table.Object;
    procedures, statementSequence: Tree.Node;
BEGIN
  Skip(S.module);
  IF Check(S.ident) THEN
    mod := Table.NewObject();
    mod.scope := Table.topScope;(*TODO*)
    mod.class := Table.Mod;
    mod.constVal := Table.NewConst();
    mod.type := Table.noType;
    Strings.Copy(S.identVal, mod.name);
    S.Get(sym); (* ident *)

    (*TODO add mod to symbol table*)

    (* IMPORT *)
    Skip(S.semicolon);
    IF Skipped(S.import) THEN
      Import(mod);
      WHILE Skipped(S.comma) DO
        Import(mod)
      END;
      Skip(S.semicolon)
    END;

    (* CONST, TYPE, VAR and BEGIN *)
    Block(procedures, statementSequence);
    x := B.Enter(procedures, statementSequence, NIL);
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
END Module;

PROCEDURE Parse*(): Tree.Node;
VAR module: Tree.Node;
BEGIN
  S.Init;
  S.Get(sym);
  Module(module)
RETURN module END Parse;

END Parser.
