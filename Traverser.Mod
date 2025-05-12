MODULE Traverser;
IMPORT Out, Machine, Errors := MocErrors, E := Emitter, Generator, Table, Tree;

CONST

TYPE

PROCEDURE DD(n: INTEGER);
BEGIN
  Out.Char(1BX); Out.String('[41m');
  Out.Char(1BX); Out.String('[30m');
  Out.String(' ========================> DEBUG ===> ');
  Out.Char(1BX); Out.String('[97m');
  Out.Int(n, 0); Out.Char(' ');
  Out.Char(1BX); Out.String('[0m'); Out.Ln
END DD;

(*
PROCEDURE Module(module: Tree.Node);
VAR node: Tree.Node;
BEGIN
  WHILE node # NIL DO
    Traverse(node.left);
    Traverse(node.right);
    node := node.link
  END
END Module;
*)

PROCEDURE Expression(n: Tree.Node; VAR z: E.Item);
VAR x, y: E.Item;
  f: INTEGER;
  const: Table.ConstVal;
  type: Table.Type;
BEGIN
  IF n.class = Tree.NConst THEN
    IF n.type.form IN {Table.Int, Table.Char} THEN
      z.mode := Table.Const;
      z.address := n.constVal.intVal
    ELSE
      Machine.Error(Errors.notImplemented)
    END
  ELSIF n.class = Tree.NVar THEN
    Machine.Error(Errors.notImplemented)
  ELSIF n.class = Tree.NMonadic THEN
    Machine.Error(Errors.notImplemented)
  ELSIF n.class = Tree.NDyadic THEN
    Machine.Error(Errors.notImplemented)
  ELSIF n.class = Tree.NProc THEN
    Machine.Error(Errors.notImplemented)
  ELSE
    Machine.Error(Errors.notImplemented)
  END
END Expression;

PROCEDURE Statement(n: Tree.Node);
VAR x, y, z: E.Item;
BEGIN
  WHILE ~Machine.hadErrors & (n # NIL) DO
    IF n.class = Tree.NEnter THEN
      E.Enter;
      Statement(n.right);
      E.Exit
    ELSIF n.class = Tree.NAssign THEN
      IF n.subclass = Tree.assign THEN
        Expression(n.right, x);
        E.Relation(x);
        Expression(n.left, z);
        E.Assign(z, x)
      ELSE
        Machine.Error(Errors.notImplemented)
      END
    ELSIF n.class = Tree.NCall THEN
      Out.String('CALL');Out.Ln;
    END;
    n := n.link
  END
END Statement;

PROCEDURE Traverse*(module: Tree.Node);
BEGIN
  Generator.Init;
  Generator.DummyCode;
  (*Statement(module)*)
END Traverse;

END Traverser.
