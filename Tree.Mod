MODULE Tree;
IMPORT Out, Scanner, T := Table;

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

PROCEDURE Print*(node: Node; indent: INTEGER);
BEGIN
  Indent(indent);
  Out.String('Node'); Out.Ln
END Print;

PROCEDURE NewConst*(): T.ConstVal;
VAR c: T.ConstVal;
BEGIN
  NEW(c)
RETURN c END NewConst;

PROCEDURE NewNode*(class: INTEGER): Node;
VAR node: Node;
BEGIN
  NEW(node);
  node.class := class
RETURN node END NewNode;

END Tree.
