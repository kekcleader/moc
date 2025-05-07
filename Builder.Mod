MODULE Builder;
IMPORT Out, Table, Tree;

CONST

TYPE

PROCEDURE Enter*(VAR x: Tree.Node);
BEGIN
  x := Tree.NewNode(Tree.NEnter);
  x.type := Table.noType;
  (*TODO*)
END Enter;

PROCEDURE NewLeaf*(object: Table.Object): Tree.Node;
VAR node: Tree.Node;
BEGIN
  IF object.class = Table.Var THEN
    node := Tree.NewNode(Tree.NVar)
  ELSIF object.class = Table.VarPar THEN
    node := Tree.NewNode(Tree.NVarPar)
  ELSIF object.class = Table.Const THEN
    node := Tree.NewNode(Tree.NConst);
    node.constVal := Tree.NewConst();
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
