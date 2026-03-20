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

PROCEDURE Load*(VAR x: Item);
BEGIN
  IF x.mode = Table.Const THEN
    G.MovHImm(G.RH, x.address);
    x.mode := Reg;
    x.address := G.RH;
    G.IncRH;
  ELSIF x.mode = Abs THEN
    G.Adrp(16, 2); (* use x16 as scratch *)
    IF x.address # 0 THEN G.AddImm(16, 16, x.address) END;
    G.LdrH(G.RH, 16);
    x.mode := Reg;
    x.address := G.RH;
    G.IncRH
  ELSIF x.mode = Reg THEN
    (* In register already, nothing to do *)
  ELSE
    Machine.NotImplemented('Load: unsupported mode')
  END
END Load;



PROCEDURE Assign*(VAR z, x: Item);
BEGIN
  IF z.type.form # Table.Int THEN
    Machine.NotImplemented('assignment to a non-INTEGER')
  END;
  Load(x);
  IF z.mode = Abs THEN
    G.Adrp(16, 2);
    IF z.address # 0 THEN
      G.AddImm(16, 16, z.address)
    END;
    G.StrH(x.address, 16)
  ELSE
    Machine.NotImplemented('assignment to non-absolute destination')
  END
END Assign;

PROCEDURE MonadicOp*(op: INTEGER; VAR x: Item);
BEGIN
  Load(x);

  IF op = Tree.minus THEN
    (* SUB wX, wzr, wX *)
    G.Sub(x.address, 31, x.address)
  ELSE
    Machine.NotImplemented('MonadicOp: unsupported operator')
  END
  (* x stay in the same register, mode and address don't changes *)
END MonadicOp;


PROCEDURE Op*(op: INTEGER; VAR x, y: Item);
VAR resReg: INTEGER;
BEGIN
  Load(x);
  Load(y);

  IF x.address < y.address THEN
    resReg := x.address
  ELSE
    resReg := y.address
  END;

  IF op = Tree.plus THEN
    G.Add(resReg, x.address, y.address)
  ELSIF op = Tree.minus THEN
    G.Sub(resReg, x.address, y.address)
  ELSIF op = Tree.times THEN
    G.Mul(resReg, x.address, y.address)
  ELSIF op = Tree.div THEN
    G.Div(resReg, x.address, y.address)
  ELSIF op = Tree.mod THEN
    G.Div(16, x.address, y.address);          (* SDIV w16, wX, wY *)
    G.Msub(resReg, 16, y.address, x.address)  (* MSUB wRes, w16, wY, wX *)
  ELSE
    Machine.NotImplemented('Op: unsupported dyadic operator')
  END;

  x.mode := Reg;
  x.address := resReg;
  x.node := NIL;

  G.ResetRHTo(resReg + 1)
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
