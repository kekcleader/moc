MODULE Emitter;
IMPORT Out, Machine, Errors := MocErrors, Table, Tree, G := Generator;

CONST
  (** Item.mode values for ARM64 **)
  Abs* = 20;

TYPE
  Item* = RECORD
    mode*: INTEGER; (** Object.class values + Item.mode values *)
    type*: Table.Type;
    node*: Tree.Node;
    address*, offset*, index*: INTEGER
  END;

PROCEDURE Print*(x: Item);
BEGIN
  Out.String('address='); Out.Int(x.address, 0);
  Out.String(' mode='); Out.Int(x.mode, 0);
  Out.String(' type='); Table.PrintType(x.type);
  Out.String(' node='); Tree.Print(x.node, 0)
END Print;

PROCEDURE Assign*(VAR z, x: Item);
BEGIN
  IF z.type.form # Table.Int THEN
    Machine.NotImplemented('assignment to a non-INTEGER')
  ELSIF x.mode # Table.Const THEN
    Machine.NotImplemented('assignment of a non-constant value')
  ELSE
    G.MovHImm(0, x.address);
    G.Adrp(1, 2);
    IF z.address # 0 THEN
      G.AddImm(1, 1, z.address)
    END;
    G.StrH(0, 1)
  END
END Assign;

PROCEDURE Relation*(VAR x: Item);
BEGIN

END Relation;

PROCEDURE OutLn*;
BEGIN
  G.MovImm( 0, 1);        (* stdout *)
  G.Adrp  ( 1, 5);        (* address of 0AX  *)
  G.AddImm( 1, 1, 0FFFH);
  G.MovImm( 2, 1);        (* length = 1 *)
  G.MovImm(16, 4);        (* write *)
  G.Svc(0)
END OutLn;

PROCEDURE OutInt*(params: Tree.Node);
BEGIN
  G.MovImm( 0, 1);        (* stdout *)
  G.Adrp  ( 1, 2);        (* address *)
  G.AddImm( 1, 1, params.object.address);
  G.MovImm( 2, 1);        (* length = 1 *)
  G.MovImm(16, 4);        (* write *)
  G.Svc(0)
END OutInt;

PROCEDURE Enter*;
BEGIN
END Enter;

PROCEDURE Exit*;
BEGIN
  G.Exit
END Exit;

END Emitter.
