MODULE Table;
IMPORT Out, Scanner;

TYPE
  Ident = Scanner.Ident;

  Node* = POINTER TO NodeDesc;
  NodeDesc* = RECORD

  END;

  Module* = POINTER TO ModuleDesc;
  ModuleDesc* = RECORD(NodeDesc)
    name*: Ident;
  END;

(** Outputs 2n indent space characters. *)
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
  CASE node OF
    Module:
    Out.String('Module '); Out.String(node.name); Out.Ln
  | Node:
    Out.String('Node'); Out.Ln
  END;
END Print;

PROCEDURE Do*;
BEGIN
END Do;

END Table.
