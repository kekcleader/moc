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
    a*, b*, r*: INTEGER;
  END;

PROCEDURE Print*(x: Item);
BEGIN
  Out.String(' a='); Out.Int(x.a, 0);
  Out.String(' b='); Out.Int(x.b, 0);
  Out.String(' r='); Out.Int(x.r, 0);
  Out.String(' mode='); Out.Int(x.mode, 0);
  Out.String(' type='); Table.PrintType(x.type);
  Out.String(' node='); Tree.Print(x.node, 0)
END Print;

PROCEDURE Load*(VAR x: Item);
BEGIN
  IF x.mode = Table.Const THEN
    G.MovHImm(G.RH, x.a);
    x.mode := Reg;
    x.r := G.RH;
    G.IncRH;
  ELSIF x.mode = Abs THEN
    G.Adrp(16, 2); (* use x16 as scratch *)
    IF x.a # 0 THEN G.AddImm(16, 16, x.a) END;
    G.LdrH(G.RH, 16);
    x.mode := Reg;
    x.r := G.RH;
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
    IF z.a # 0 THEN
      G.AddImm(16, 16, z.a)
    END;
    G.StrH(x.r, 16)
  ELSE
    Machine.NotImplemented('assignment to non-absolute destination')
  END
END Assign;

PROCEDURE MonadicOp*(op: INTEGER; VAR x: Item);
BEGIN
  Load(x);

  IF op = Tree.minus THEN
    (* SUB wX, wzr, wX *)
    G.Sub(x.r, 31, x.r)
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

  IF x.r < y.r THEN
    resReg := x.r
  ELSE
    resReg := y.r
  END;

  IF op = Tree.plus THEN
    G.Add(resReg, x.r, y.r)
  ELSIF op = Tree.minus THEN
    G.Sub(resReg, x.r, y.r)
  ELSIF op = Tree.times THEN
    G.Mul(resReg, x.r, y.r)
  ELSIF op = Tree.div THEN
    G.Div(resReg, x.r, y.r)
  ELSIF op = Tree.mod THEN
    G.Div(16, x.r, y.r);          (* SDIV w16, wX, wY *)
    G.Msub(resReg, 16, y.r, x.r)  (* MSUB wRes, w16, wY, wX *)
  ELSE
    Machine.NotImplemented('Op: unsupported dyadic operator')
  END;

  x.mode := Reg;
  x.r := resReg;
  x.node := NIL;

  G.ResetRHTo(resReg + 1)
END Op;

PROCEDURE CmpOp*(op: INTEGER; VAR x, y: Item);
BEGIN
  Load(x);
  Load(y);

  G.Cmp(x.r, y.r);

  (* CMP only sets status flags. Free both registers *)
  G.ResetRHTo(0);

  (* Store direct condition code for the branch *)
  x.mode := Table.Const;
  IF op = Tree.eql THEN x.r := G.EQ
  ELSIF op = Tree.neq THEN x.r := G.NE
  ELSIF op = Tree.lss THEN x.r := G.LT
  ELSIF op = Tree.leq THEN x.r := G.LE
  ELSIF op = Tree.gtr THEN x.r := G.GT
  ELSIF op = Tree.geq THEN x.r := G.GE
  ELSE Machine.NotImplemented('CmpOp: unknown operator')
  END;

  x.a := 0;
  x.b := 0
END CmpOp;

PROCEDURE CondBranch*(VAR x: Item; VAR branchPC: INTEGER);
BEGIN
  IF x.mode = Table.Const THEN
    G.EmitCondBranch(x.r, branchPC)
  ELSE
    Machine.NotImplemented('CondBranch: expected condition code')
  END
END CondBranch;

PROCEDURE Relation*(VAR x: Item);
BEGIN

END Relation;

PROCEDURE FixLinkWith*(L, target: INTEGER);
VAR nextL: INTEGER;
BEGIN
  WHILE L # 0 DO
    nextL := G.ImmFromBCond(L);
    G.PatchBCond(L, target);
    L := nextL
  END
END FixLinkWith;

PROCEDURE FixLink*(L: INTEGER);
BEGIN
  FixLinkWith(L, G.Here())
END FixLink;

(** Inverts ARM64 condition code *)
PROCEDURE Negated*(code: INTEGER): INTEGER;
BEGIN
  IF ODD(code) THEN DEC(code) ELSE INC(code) END
RETURN code END Negated;

(** Conditional Forward Jump (Jump conditionally IF and WHILE) *)
PROCEDURE CFJump*(VAR x: Item);
BEGIN
  IF x.mode # Table.Const THEN Machine.NotImplemented('CFJump: expected condition code') END;

  FixLink(x.b);
  x.b := 0;

  G.BCond(Negated(x.r), x.a);
  x.a := G.Here() - 1
END CFJump;

(** Unconditional Backward Jump (Jump conditionally in WHILE) *)
PROCEDURE BJump*(L: INTEGER);
BEGIN
  G.B(L - G.Here())
END BJump;

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
