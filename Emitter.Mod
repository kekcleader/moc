MODULE Emitter;
IMPORT Out, Machine, Errors := MocErrors, Table, Tree, G := Generator;

CONST
  (** Item.mode values for ARM64 **)
  Abs* = 20;
  Reg* = 21;

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

  ELSIF x.mode = Table.Const THEN
    G.MovHImm(0, x.address);
    IF z.mode = Abs THEN
      G.Adrp(1, 2);
      IF z.address # 0 THEN
        G.AddImm(1, 1, z.address)
      END;
      G.StrH(0, 1)
    ELSE
      Machine.NotImplemented('assignment to non-absolute destination')
    END
  ELSIF x.mode = Abs THEN
    G.Adrp(1, 2);
    IF x.address # 0 THEN
      G.AddImm(1, 1, x.address)
    END;
    G.LdrH(0, 1);

    IF z.mode = Abs THEN
      G.Adrp(1, 2);
      IF z.address # 0 THEN
        G.AddImm(1, 1, z.address)
      END;
      G.StrH(0, 1)
    ELSE
      Machine.NotImplemented('assignment to non-absolute destination')
    END
  ELSIF x.mode = Reg THEN
    IF z.mode = Abs THEN
      G.Adrp(1, 2);
      IF z.address # 0 THEN
        G.AddImm(1, 1, z.address)
      END;
      G.StrH(x.address, 1)
    ELSE
      Machine.NotImplemented('assignment to non-absolute destination')
    END
  ELSE
    Machine.NotImplemented('assignment of unknown mode')
  END
END Assign;

PROCEDURE Op*(op: INTEGER; VAR x, y: Item);
BEGIN
  (* Left operand to w0 *)
  IF x.mode = Abs THEN
    G.Adrp(1, 2);
    IF x.address # 0 THEN G.AddImm(1, 1, x.address) END;
    G.LdrH(0, 1)
  ELSIF x.mode = Table.Const THEN
    G.MovHImm(0, x.address)
  ELSE
    Machine.NotImplemented('left operand in Op')
  END;

  (* Right operand to w2 *)
  IF y.mode = Abs THEN
    G.Adrp(1, 2);
    IF y.address # 0 THEN G.AddImm(1, 1, y.address) END;
    G.LdrH(2, 1)
  ELSIF y.mode = Table.Const THEN
    G.MovHImm(2, y.address)
  ELSE
    Machine.NotImplemented('right operand in Op')
  END;

  IF op = Tree.plus THEN
    G.Add(0, 0, 2)
  ELSIF op = Tree.minus THEN
    G.Sub(0, 0, 2)
  ELSIF op = Tree.times THEN
    G.Mul(0, 0, 2)
  ELSIF op = Tree.div THEN
    G.Div(0, 0, 2)
  ELSE
    Machine.NotImplemented('Op: unsupported dyadic operator')
  END;

  (* Result in register 0 *)
  x.mode := Reg;
  x.address := 0;
  x.node := NIL;
END Op;


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
