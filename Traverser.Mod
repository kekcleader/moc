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
      Machine.NotImplemented('constant expression of this type')
    END
  ELSIF n.class = Tree.NVar THEN
    Machine.NotImplemented('variable expression')
  ELSIF n.class = Tree.NMonadic THEN
    Machine.NotImplemented('monadic expression')
  ELSIF n.class = Tree.NDyadic THEN
    Machine.NotImplemented('dyadic expression')
  ELSIF n.class = Tree.NProc THEN
    Machine.NotImplemented('procedure expression')
  ELSE
    Machine.NotImplemented('this expression class')
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
        Machine.NotImplemented('this statement type')
      END
    ELSIF n.class = Tree.NCall THEN
      Machine.NotImplemented('procedure call')
    END;
    n := n.link
  END
END Statement;

PROCEDURE Traverse*(module: Tree.Node);
BEGIN
  Generator.Init;
  Statement(module)
  (*Generator.DummyCode*)
END Traverse;

END Traverser.
