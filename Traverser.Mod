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
    z.a := n.object.address;
    z.b := 0;
    z.r := 0
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
      z.a := n.constVal.intVal
    ELSE
      Machine.NotImplemented('constant expression of this type')
    END
  ELSIF n.class = Tree.NVar THEN
    Designator(n, z)
  ELSIF n.class = Tree.NMonadic THEN
    Expression(n.left, x);
    IF n.subclass = Tree.minus THEN
      E.MonadicOp(n.subclass, x);
      z := x
    ELSE
      Machine.NotImplemented('this monadic operator is not supported yet')
    END
  ELSIF n.class = Tree.NDyadic THEN
    Expression(n.left, x);
    E.Load(x);
    Expression(n.right, y);
    E.Load(y);
    IF (n.subclass = Tree.plus) OR (n.subclass = Tree.minus) OR
       (n.subclass = Tree.times) OR (n.subclass = Tree.div) OR
       (n.subclass = Tree.mod) THEN
      E.Op(n.subclass, x, y);
      z := x
    ELSIF (n.subclass >= Tree.eql) & (n.subclass <= Tree.geq) THEN
      E.CmpOp(n.subclass, x, y);
      z := x
    ELSE
      Machine.NotImplemented('this dyadic operator is not supported yet')
    END

  ELSIF n.class = Tree.NProc THEN
    Machine.NotImplemented('procedure expression')
  ELSE
    Machine.NotImplemented('this expression class')
  END
END Expression;

PROCEDURE Statement(n: Tree.Node);
VAR x, y, z: E.Item;
  con: Table.ConstVal;
  loopStart, escapeList: INTEGER;
  node: Tree.Node;
BEGIN
  WHILE ~Machine.hadErrors & (n # NIL) DO
    Generator.ResetRH;
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
        Expression(n.right, x);
        E.OutInt(x)
        ELSE
          Machine.NotImplemented('this standard procedure call');
        END
      END
    ELSIF n.class = Tree.NIf THEN
      escapeList := 0;
      node := n;
      WHILE node # NIL DO
        IF node.class = Tree.NIf THEN
          Expression(node.left, x);
          E.CFJump(x);
          Statement(node.right);
          E.FJump(escapeList);
          E.FixLink(x.a);
          node := node.els
        ELSIF node.class = Tree.NIfElse THEN
          IF node.left # NIL THEN
            Expression(node.left, x);
            E.CFJump(x);
            Statement(node.right);
            E.FJump(escapeList);
            E.FixLink(x.a);
            node := node.els
          ELSE
            Statement(node.right);
            node := NIL
          END
        END
      END;
      E.FixLink(escapeList)
    ELSIF n.class = Tree.NWhile THEN
      loopStart := Generator.Here();
      Expression(n.left, x);
      E.CFJump(x);           (* Jump out of loop if condition is false *)
      Statement(n.right);
      E.BJump(loopStart);    (* Jump back to condition evaluation *)
      E.FixLink(x.a)         (* Resolve the loop exit address *)

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
  (*Generator.SetDataLen(size) *)
  Generator.SetDataLen(size + 4);
  E.SetScratchOffset(size)
END SetAddressesAndSizes;

PROCEDURE Traverse*(module: Tree.Node);
BEGIN
  Generator.Init;
  Statement(module)
  (*Generator.DummyCode*)
END Traverse;

END Traverser.
