MODULE Builder;
IMPORT Out, Table, Tree;

CONST

TYPE

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

END Builder.
