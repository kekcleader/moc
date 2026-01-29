MODULE Builder;
IMPORT Out, Machine, Errors := MocErrors, Table, Tree, S := Scanner;

PROCEDURE Enter*(procedures, statementSequence: Tree.Node;
  containingProc: Table.Object): Tree.Node;
VAR enter: Tree.Node;
BEGIN
  enter := Tree.NewNode(Tree.NEnter);
  enter.type := Table.noType;
  enter.object := containingProc;
  enter.left := procedures;
  enter.right := statementSequence
RETURN enter END Enter;

PROCEDURE NewIntConst*(value: INTEGER): Tree.Node;
VAR x: Tree.Node;
BEGIN
  x := Tree.NewNode(Tree.NConst);
  x.type := Table.intType;
  x.constVal := Table.NewConst();
  x.constVal.intVal := value
RETURN x END NewIntConst;

PROCEDURE NewRealConst*(value: REAL): Tree.Node;
VAR x: Tree.Node;
BEGIN
  x := Tree.NewNode(Tree.NConst);
  x.type := Table.realType;
  x.constVal := Table.NewConst();
  x.constVal.realVal := value
RETURN x END NewRealConst;

PROCEDURE NewLeaf*(object: Table.Object): Tree.Node;
VAR node: Tree.Node;
BEGIN
  IF object.class = Table.Var THEN
    node := Tree.NewNode(Tree.NVar)
  ELSIF object.class = Table.VarPar THEN
    node := Tree.NewNode(Tree.NVarPar)
  ELSIF object.class = Table.Const THEN
    IF (object.type # NIL) & (object.type.form = Table.Proc) THEN
      node := Tree.NewNode(Tree.NProc)
    ELSE (* constant *)
      node := Tree.NewNode(Tree.NConst);
      IF object.constVal # NIL THEN
        node.constVal := Table.NewConst();
        node.constVal^ := object.constVal^
      END
    END
  ELSIF object.class = Table.Typ THEN
    node := Tree.NewNode(Tree.NType)
  ELSIF object.class IN {Table.SProc, Table.SFunc} THEN
    node := Tree.NewNode(Tree.NProc)
  ELSE
    ASSERT(FALSE)
  END;
  node.object := object;
  node.type := object.type
RETURN node END NewLeaf;

(** Performs an optimized monadic operation op on x or creates a new
    monadic operator node. Returns the modified or created node.
     The supported operations are: ~, -, IS, convesion, ABS, CAP,
    ODD, ADR, CC. *)
PROCEDURE MonadicOperator*(op: INTEGER; x: Tree.Node): Tree.Node;
VAR mondaic: Tree.Node;
BEGIN
  IF x.class = Tree.NConst THEN
    IF op = S.not THEN
      IF x.type.form = Table.Bool THEN
        x.constVal.intVal := 1 - x.constVal.intVal
      (* TODO Table.Set *)
      ELSE
        Machine.Error(Errors.badMonadicOperand)
      END
    ELSIF op = S.minus THEN
      IF x.type.form = Table.Int THEN
        x.constVal.intVal := -x.constVal.intVal
      (* TODO form = Table.Set *)
      ELSE
        Machine.Error(Errors.badMonadicOperand)
      END
    END
  ELSE
    mondaic := Tree.NewNode(Tree.NMonadic);
    mondaic.subclass := op;
    mondaic.type := x.type; (*FIXME*)
    mondaic.left := x
  END
RETURN mondaic END MonadicOperator;

(** Performs an optimized dyadic operation op on NConst nodes x and y.
    Returns the modified node x.
     The supported operations are: *, DIV, MOD, &, +, -, OR, =, #,
    <, <=, >, >=, IN, ASH, LEN, BIT, LSH, ROT. *)
PROCEDURE DyadicConstOperator*(op: INTEGER; x, y: Tree.Node): Tree.Node;
VAR f: INTEGER;
BEGIN
  x.object := NIL;
  f := x.type.form;
  IF y.type.form # f THEN
    Machine.Error(Errors.incompatibleTypes)
  ELSIF op = S.times THEN
    IF f = Table.Int THEN
      x.constVal.intVal := x.constVal.intVal * y.constVal.intVal
    ELSIF f = Table.Real THEN
      x.constVal.realVal := x.constVal.realVal * y.constVal.realVal
    ELSE
      Machine.Error(Errors.badDyadicOperands)
    END
  ELSIF op = S.div THEN (*TODO*)
  ELSIF op = S.mod THEN (*TODO*)
  ELSIF op = S.and THEN (*TODO*)
  ELSIF op = S.plus THEN
    IF f = Table.Int THEN
      x.constVal.intVal := x.constVal.intVal + y.constVal.intVal
    ELSIF f = Table.Real THEN
      x.constVal.realVal := x.constVal.realVal + y.constVal.realVal
    ELSE
      Machine.Error(Errors.badDyadicOperands)
    END
  ELSIF op = S.minus THEN
    IF f = Table.Int THEN
      x.constVal.intVal := x.constVal.intVal - y.constVal.intVal
    ELSIF f = Table.Real THEN
      x.constVal.realVal := x.constVal.realVal - y.constVal.realVal
    ELSE
      Machine.Error(Errors.badDyadicOperands)
    END
  ELSIF op = S.or THEN (*TODO*)
  ELSIF op = S.eql THEN (*TODO*)
  ELSIF op = S.neq THEN (*TODO*)
  ELSIF op = S.lss THEN (*TODO*)
  ELSIF op = S.leq THEN (*TODO*)
  ELSIF op = S.gtr THEN (*TODO*)
  ELSIF op = S.geq THEN (*TODO, IN etc. *)
  END
RETURN x END DyadicConstOperator;

(** Performs an optimized dyadic operation op on x and y or creates a new
    dyadic operator node. Returns the modified node x or a new node.
     The supported operations are: *, DIV, MOD, &, +, -, OR, =, #,
    <, <=, >, >=, IN, ASH, LEN, BIT, LSH, ROT. *)
PROCEDURE DyadicOperator*(op: INTEGER; x, y: Tree.Node): Tree.Node;
VAR dyadic: Tree.Node;
BEGIN
  IF (x.class = Tree.NConst) & (y.class = Tree.NConst) THEN
    dyadic := DyadicConstOperator(op, x, y)
  ELSE 
    dyadic := Tree.NewNode(Tree.NDyadic);
    dyadic.subclass := op;
    dyadic.type := x.type; (*FIXME change type depending on the op?*)
    dyadic.left := x;
    dyadic.right := y
  END
RETURN dyadic END DyadicOperator;

(** Appends list y to the end of the list x..last. *)
PROCEDURE Link*(VAR x, last: Tree.Node; y: Tree.Node);
BEGIN
  IF x = NIL THEN x := y ELSE last.link := y END;
  WHILE y.link # NIL DO y := y.link END;
  last := y
END Link;

PROCEDURE Param*(VAR actual: Tree.Node; formal: Table.Object);
VAR t: Table.Type;
BEGIN
  IF formal.type.form # Table.NoType THEN
    IF actual.type # formal.type THEN
      Machine.Error(Errors.incompatibleTypes)
    END
  END
END Param;

(** Returns a list of formal parameters of procedure x. *)
PROCEDURE PrepareCall*(x: Tree.Node): Table.Object;
VAR list: Table.Object;
BEGIN
  list := x.object.type.dsc
RETURN list END PrepareCall;

(** Creates and returns a new NCall node. *)
PROCEDURE Call*(procedure, actualParams: Tree.Node;
  formalParams: Table.Object): Tree.Node;
VAR call: Tree.Node;
BEGIN
  call := Tree.NewNode(Tree.NCall);
  call.left := procedure;
  call.right := actualParams
  (* TODO check parameters *)
RETURN call END Call;

END Builder.
