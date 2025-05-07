MODULE Tree;
IMPORT Out, Scanner, T := Table;

CONST

TYPE
  Ident = Scanner.Ident;

  Node* = POINTER TO NodeDesc;
  NodeDesc* = RECORD
    left*, right*, link*: Node;
    class*, subclass*: INTEGER;
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

PROCEDURE Do*;
BEGIN
END Do;

END Tree.
