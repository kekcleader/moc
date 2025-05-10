MODULE Tree;
IMPORT Out, Scanner, T := Table, Errors := MocErrors;

CONST
  (** Node.class values **)
  NVar*    =  0; NVarPar*   =  1; NField*  =  2; NDeref*  =  3; NIndex*  =  4;
  NGuard*  =  5; NExpGuard* =  6; NConst*  =  7; NType*   =  8; NProc*   =  9;
  NUpTo*   = 10; NMonadic*  = 11; NDyadic* = 12; NCall*   = 13; NInitTD* = 14;
  NIf*     = 15; NCaseElse* = 16; NCaseDo* = 17; NEnter*  = 18; NAssign* = 19;
  NIfElse* = 20; NCase*     = 21; NWhile*  = 22; NRepeat* = 23; NTrap*   = 28;
  NFixup*  = 31;

TYPE
  Ident = Scanner.Ident;

  Node* = POINTER TO NodeDesc;
  NodeDesc* = RECORD
    left*, right*, link*: Node;
    class*: INTEGER; (** See Node.class constants *)
    subclass*: INTEGER;
    type*: T.Type;
    object*: T.Object;
    constVal*: T.ConstVal
  END;

(** Outputs 2n spaces. *)
PROCEDURE Indent(n: INTEGER);
BEGIN
  WHILE n # 0 DO
    Out.String('  ');
    DEC(n)
  END
END Indent;

PROCEDURE PrintNodeName(node: Node);
BEGIN
  IF node.class = NVar THEN Out.String('NVar')
  ELSIF node.class = NVarPar   THEN Out.String('NVarPar')
  ELSIF node.class = NField    THEN Out.String('NField')
  ELSIF node.class = NDeref    THEN Out.String('NDeref')
  ELSIF node.class = NIndex    THEN Out.String('NIndex')
  ELSIF node.class = NGuard    THEN Out.String('NGuard')
  ELSIF node.class = NExpGuard THEN Out.String('NExpGuard')
  ELSIF node.class = NConst    THEN Out.String('NConst')
  ELSIF node.class = NType     THEN Out.String('NType')
  ELSIF node.class = NProc     THEN Out.String('NProc')
  ELSIF node.class = NUpTo     THEN Out.String('NUpTo')
  ELSIF node.class = NMonadic  THEN Out.String('NMonadic')
  ELSIF node.class = NDyadic   THEN Out.String('NDyadic')
  ELSIF node.class = NCall     THEN Out.String('NCall')
  ELSIF node.class = NInitTD   THEN Out.String('NInitTD')
  ELSIF node.class = NIf       THEN Out.String('NIf')
  ELSIF node.class = NCaseElse THEN Out.String('NCaseElse')
  ELSIF node.class = NCaseDo   THEN Out.String('NCaseDo')
  ELSIF node.class = NEnter    THEN Out.String('NEnter')
  ELSIF node.class = NAssign   THEN Out.String('NAssign')
  ELSIF node.class = NIfElse   THEN Out.String('NIfElse')
  ELSIF node.class = NCase     THEN Out.String('NCase')
  ELSIF node.class = NWhile    THEN Out.String('NWhile')
  ELSIF node.class = NRepeat   THEN Out.String('NRepeat')
  ELSIF node.class = NTrap     THEN Out.String('NTrap')
  ELSIF node.class = NFixup    THEN Out.String('NFixup')
  ELSE Out.String('UNKNOWN')
  END
END PrintNodeName;

PROCEDURE Print*(node: Node; indent: INTEGER);
BEGIN
  IF node # NIL THEN
    Indent(indent); PrintNodeName(node);
    IF (node.class = NDyadic) OR (node.class = NMonadic) THEN
      Out.Char(' ');
      Errors.PrintSymbol(node.subclass)
    END;
    IF node.object # NIL THEN
      Out.String(' (Object: ');
      T.PrintObject(node.object, 0);
      Out.Char(')')
    END;
    IF node.constVal # NIL THEN
      Out.String(' (Const: ');
      Out.Int(node.constVal.intVal, 0);
      Out.Char(')')
    END;
    Out.Ln;
    IF node.left # NIL THEN
      Indent(indent); Out.String('Left:'); Out.Ln;
      Print(node.left, indent + 1);
    END;
    IF node.right # NIL THEN
      Indent(indent); Out.String('Right:'); Out.Ln;
      Print(node.right, indent + 1);
    END;
    IF node.link # NIL THEN
      Indent(indent); Out.String('~ Link ~'); Out.Ln;
      Print(node.link, indent)
    END
  END
END Print;

PROCEDURE NewNode*(class: INTEGER): Node;
VAR node: Node;
BEGIN
  NEW(node);
  node.class := class;
  node.subclass := 0
RETURN node END NewNode;

END Tree.
