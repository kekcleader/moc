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
  f, proc: INTEGER;
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
    ELSIF n.subclass = Tree.not THEN
      E.Not(x);
      z := x
    ELSE
      Machine.NotImplemented('this monadic operator is not supported yet')
    END
  ELSIF n.class = Tree.NDyadic THEN
    IF n.subclass = Tree.and THEN
      Expression(n.left, x);
      E.And1(x);
      Expression(n.right, y);
      E.And2(x, y);
      z := x
    ELSIF n.subclass = Tree.or THEN
      Expression(n.left, x);
      E.Or1(x);
      Expression(n.right, y);
      E.Or2(x, y);
      z := x
    ELSE
      (* Arithmetic and comparison — load both operands eagerly *)
      Expression(n.left, x);
      E.Load(x);
      Expression(n.right, y);
      E.Load(y);
      IF (n.subclass = Tree.plus) OR (n.subclass = Tree.minus) OR
         (n.subclass = Tree.times) OR (n.subclass = Tree.div) OR
         (n.subclass = Tree.mod) THEN
        IF n.left.type.form = Table.Set THEN
          IF    n.subclass = Tree.plus  THEN E.SetUnion(x, y)
          ELSIF n.subclass = Tree.minus THEN E.SetDiff(x, y)
          ELSIF n.subclass = Tree.times THEN E.SetInter(x, y)
          ELSIF n.subclass = Tree.div   THEN E.SetSymDiff(x, y)
          ELSE Machine.NotImplemented('this set operator')
          END
        ELSE
          E.Op(n.subclass, x, y)
        END;
        z := x
      ELSIF (n.subclass >= Tree.eql) & (n.subclass <= Tree.geq) THEN
        E.CmpOp(n.subclass, x, y);
        z := x
      ELSIF n.subclass = Tree.in THEN
        E.InSet(x, y);
        z := x
      ELSE
        Machine.NotImplemented('this dyadic operator is not supported yet')
      END
    END
  ELSIF n.class = Tree.NCall THEN
    (* Standard function call in expression context *)
    IF n.left.object.class = Table.SFunc THEN
      proc := n.left.object.constVal.intVal;
      IF proc = Table.absFunc THEN
        Expression(n.right, x);
        E.AbsVal(x);
        z := x
      ELSIF proc = Table.oddFunc THEN
        Expression(n.right, x);
        E.OddVal(x);
        z := x
      ELSIF proc = Table.asrFunc THEN
        Expression(n.right, x);
        Expression(n.right.link, y);
        E.AsrVal(x, y);
        z := x
      ELSIF proc = Table.lslFunc THEN
        Expression(n.right, x);
        Expression(n.right.link, y);
        E.LslVal(x, y);
        z := x
      ELSIF proc = Table.rorFunc THEN
        Expression(n.right, x);
        Expression(n.right.link, y);
        E.RorVal(x, y);
        z := x
      ELSIF (proc = Table.ordFunc) OR (proc = Table.chrFunc) THEN
        Expression(n.right, x); (* ORD/CHR: type cast, no code change *)
        z := x
      ELSE
        Machine.NotImplemented('this standard function')
      END
    ELSE
      Machine.NotImplemented('function call in expression')
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
  step, savedConst, savedReg: INTEGER;
  endVal: E.Item;
  doNode, label: Tree.Node;
  matchList, exitList: INTEGER;
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
      IF (n.left.object.class # Table.Const) &
         (n.left.object.class # Table.SProc) THEN
        Machine.NotImplemented('procedure variable call');
      ELSE
        con := n.left.object.constVal;
        IF con.intVal = -20 THEN
          E.OutLn
        ELSIF con.intVal = -21 THEN
        Expression(n.right, x);
        E.OutInt(x)
        ELSIF con.intVal = Table.incProc THEN
          Expression(n.right, x);
          IF n.right.link = NIL THEN
            E.IncDec(x, FALSE)        (* INC(x) *)
          ELSE
            Expression(n.right.link, y);
            E.IncDecByAmount(x, y, FALSE) (* INC(x, n) *)
          END
        ELSIF con.intVal = Table.decProc THEN
          Expression(n.right, x);
          IF n.right.link = NIL THEN
            E.IncDec(x, TRUE)         (* DEC(x) *)
          ELSE
            Expression(n.right.link, y);
            E.IncDecByAmount(x, y, TRUE) (* DEC(x, n) *)
          END
        ELSIF con.intVal = Table.inclProc THEN
          Expression(n.right, x);
          Expression(n.right.link, y);
          E.InclExclVar(x, y, FALSE)
        ELSIF con.intVal = Table.exclProc THEN
          Expression(n.right, x);
          Expression(n.right.link, y);
          E.InclExclVar(x, y, TRUE)
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
          E.LoadCond(x);
          E.CFJump(x);
          Statement(node.right);
          E.FJump(escapeList);
          E.FixLink(x.a);
          node := node.els
        ELSIF node.class = Tree.NIfElse THEN
          IF node.left # NIL THEN
            Expression(node.left, x);
            E.LoadCond(x);
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
      E.LoadCond(x);
      E.CFJump(x);           (* Jump out of loop if condition is false *)
      Statement(n.right);
      E.BJump(loopStart);    (* Jump back to condition evaluation *)
      E.FixLink(x.a)         (* Resolve the loop exit address *)
    ELSIF n.class = Tree.NRepeat THEN
      loopStart := Generator.Here();
      Statement(n.right);
      Generator.ResetRH;
      Expression(n.left, x);
      E.Not(x);          (* UNTIL condition: loop continues while NOT condition *)
      E.LoadCond(x);
      E.CFJump(x);
      E.BJump(loopStart);
      E.FixLink(x.a)
    ELSIF n.class = Tree.NFor THEN
      step := n.constVal.intVal;
      (* 1. Assign initial value to loop variable *)
      Expression(n.left, x);
      z.mode := E.Abs;
      z.a    := n.object.address;
      z.type := n.object.type;
      z.node := NIL;
      z.b    := 0; z.r := 0;
      E.Assign(z, x);
      Generator.ResetRH;
      (* 2. Evaluate and save end value (constant or callee-saved register) *)
      Expression(n.els, endVal);
      E.ForSave(endVal, savedConst, savedReg);
      Generator.ResetRH;
      (* 3. Loop start label *)
      loopStart := Generator.Here();
      (* 4. Condition check: sets condition item x *)
      E.ForCond(n.object, savedReg, savedConst, step, x);
      (* 5. Conditional exit if condition is false *)
      E.CFJump(x);
      (* 6. Loop body *)
      Statement(n.right);
      Generator.ResetRH;
      (* 7. Increment loop variable by step *)
      z.mode := E.Abs;
      z.a    := n.object.address;
      z.type := n.object.type;
      z.node := NIL;
      z.b    := 0; z.r := 0;
      E.IncDecStep(z, step);
      Generator.ResetRH;
      (* 8. Jump back to condition check *)
      E.BJump(loopStart);
      (* 9. Patch the exit jump to here *)
      E.FixLink(x.a);
      (* 10. Free callee-saved register if used *)
      E.ForClean(savedReg)
    ELSIF n.class = Tree.NCase THEN
      exitList := 0;
      Expression(n.left, x);
      E.CaseSave(x);
      doNode := n.right;
      WHILE doNode # NIL DO
        matchList := 0;
        label := doNode.left;
        WHILE label # NIL DO
          IF label.class = Tree.NUpTo THEN
            E.CaseRangeLabel(x, label.left.constVal.intVal,
                                label.right.constVal.intVal, matchList)
          ELSE
            E.CaseLabel(x, label.constVal.intVal, matchList)
          END;
          label := label.link
        END;
        (* No match: jump over this body to the next branch *)
        loopStart := 0;
        E.FJump(loopStart);
        (* Patch match jumps to body entry *)
        E.FixLink(matchList);
        Statement(doNode.right);
        Generator.ResetRH;
        (* After body: jump past whole CASE *)
        E.FJump(exitList);
        (* Next branch starts here *)
        E.FixLink(loopStart);
        doNode := doNode.link
      END;
      E.CaseClean(x);
      E.FixLink(exitList)
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
