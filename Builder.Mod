MODULE Builder;
IMPORT Out, Machine, Errors := MocErrors, Table, Tree;

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
    node := Tree.NewNode(Tree.NConst);
    node.constVal := Table.NewConst();
    node.constVal^ := object.constVal^
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

PROCEDURE NewMonadicOperator*(op: INTEGER; x: Tree.Node): Tree.Node;
VAR mondaic: Tree.Node;
BEGIN
  mondaic := Tree.NewNode(Tree.NMonadic);
  mondaic.subclass := op;
  mondaic.type := x.type; (*FIXME*)
  mondaic.left := x
RETURN mondaic END NewMonadicOperator;

PROCEDURE NewDyadicOperator*(op: INTEGER; x, y: Tree.Node): Tree.Node;
VAR dyadic: Tree.Node;
BEGIN
  dyadic := Tree.NewNode(Tree.NDyadic);
  dyadic.subclass := op;
  dyadic.type := x.type; (*FIXME*)
  dyadic.left := x;
  dyadic.right := y
RETURN dyadic END NewDyadicOperator;

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
  IF formal.type.form # Table.NoTyp THEN
    IF actual.type # formal.type THEN
      Machine.Error(Errors.incompatibleTypes)
    END
  END
END Param;

(** Returns a list of formal parameters of function x. *)
PROCEDURE PrepareCall*(x: Tree.Node): Table.Object;
VAR list: Table.Object;
BEGIN
  list := NIL (* TODO *)
RETURN list END PrepareCall;

PROCEDURE Call*(x, actualParams: Tree.Node;
  formalParams: Table.Object): Tree.Node;
BEGIN
RETURN x END Call;

END Builder.
