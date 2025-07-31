MODULE Traverser;
IMPORT Out, Machine, Errors := MocErrors, E := Emitter, Generator, Table, Tree;

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

PROCEDURE Designator(n: Tree.Node; VAR z: E.Item);
BEGIN
  IF (n.class = Tree.NVar) OR (n.class = Tree.NVarPar) THEN
    z.node := n;
    z.type := n.object.type;
    z.mode := E.Abs; (* Global variable *)
    z.address := n.object.address;
    z.offset := 0;
    z.index := 0
  ELSE
    Machine.NotImplemented('designator of this type')
  END
END Designator;

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
    Designator(n, z)
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
  con: Table.ConstVal;
BEGIN
  WHILE ~Machine.hadErrors & (n # NIL) DO
    IF n.class = Tree.NEnter THEN
      IF n.object = NIL THEN (* n is module *)
        E.Enter;
        Statement(n.right);
        E.Exit
      ELSE (* n is procedure *)
        Machine.NotImplemented('procedure declaration')
      END
    ELSIF n.class = Tree.NAssign THEN
      IF n.subclass = Tree.assign THEN
        Expression(n.right, x);
        E.Relation(x); (* Load condition code if required *)
        Expression(n.left, z);
        E.Assign(z, x)
      ELSE
        Machine.NotImplemented('this statement type')
      END
    ELSIF n.class = Tree.NCall THEN
      IF n.left.object.class # Table.Const THEN
        Machine.NotImplemented('procedure variable call');
      ELSE
        con := n.left.object.constVal;
        IF con.intVal = -20 THEN
          E.OutLn
        ELSIF con.intVal = -21 THEN
          E.OutInt(n.right)
        ELSE
          Machine.NotImplemented('this standard procedure call');
        END
      END
    ELSE
      Machine.NotImplemented('this node class');
    END;
    n := n.link
  END
END Statement;

PROCEDURE SetAddressesAndSizes*(topScope: Table.Object);
VAR object: Table.Object;
  size: INTEGER;
BEGIN
  size := 0;
  object := topScope.next;
  WHILE object # NIL DO
    IF object.class = Table.Var THEN
      object.address := size;
      INC(size, object.type.size)
    END;
    object := object.next
  END;
  Generator.SetDataLen(size)
END SetAddressesAndSizes;

PROCEDURE Traverse*(module: Tree.Node);
BEGIN
  Generator.Init;
  Statement(module)
  (*Generator.DummyCode*)
END Traverse;

END Traverser.
