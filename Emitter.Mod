MODULE Emitter;
IMPORT Out, Machine, Errors := MocErrors, Table, Tree, G := Generator;

CONST
  (** Item.mode values for ARM64 **)
  Abs* = 20;
  Reg* = 21;

  firstCSReg = 19; (** First callee-saved register (x19) *)
  maxCSReg   = 28; (** Last callee-saved register (x28) *)


TYPE
  Item* = RECORD
    mode*: INTEGER; (** Object.class values + Item.mode values *)
    type*: Table.Type;
    node*: Tree.Node;
    a*, b*, r*: INTEGER;
  END;

VAR
  scratchOffset: INTEGER;
  SH: INTEGER; (** Next free callee-saved register (x19..x28) *)

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
  IF (z.type.form # Table.Int) & (z.type.form # Table.Set) THEN
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

(** INC(x) or DEC(x): increments or decrements variable x by 1 in place. *)
(** Allocate the next callee-saved register for long-lived values (e.g. FOR end value). *)
PROCEDURE AllocS(): INTEGER;
VAR r: INTEGER;
BEGIN
  r := SH;
  IF SH <= maxCSReg THEN INC(SH)
  ELSE Machine.Error(Errors.outOfMemory)
  END
RETURN r END AllocS;

(** Free the last allocated callee-saved register. *)
PROCEDURE FreeS;
BEGIN
  IF SH > firstCSReg THEN DEC(SH) END
END FreeS;

PROCEDURE IncDec*(VAR x: Item; dec: BOOLEAN);
BEGIN
  IF x.mode # Abs THEN
    Machine.NotImplemented('IncDec: only absolute variables supported')
  END;
  G.Adrp(16, 2);
  IF x.a # 0 THEN G.AddImm(16, 16, x.a) END;
  G.LdrH(0, 16);      (* Load into w0 *)
  IF dec THEN G.SubImmH(0, 0, 1)
  ELSE G.AddImmH(0, 0, 1)
  END;
  G.Adrp(16, 2);
  IF x.a # 0 THEN G.AddImm(16, 16, x.a) END;
  G.StrH(0, 16)       (* Store back *)
END IncDec;

(** Increment or decrement variable x by a constant step in place.
    step > 0: increment; step < 0: decrement.
    x must be in Abs mode (global variable). *)
PROCEDURE IncDecStep*(VAR x: Item; step: INTEGER);
BEGIN
  IF x.mode # Abs THEN
    Machine.NotImplemented('IncDecStep: only absolute mode supported')
  END;
  G.Adrp(16, 2);
  IF x.a # 0 THEN G.AddImm(16, 16, x.a) END;
  G.LdrH(0, 16);
  IF step > 0 THEN
    IF step < 1000H THEN G.AddImmH(0, 0, step)
    ELSE G.MovHImm(1, step); G.Add(0, 0, 1)
    END
  ELSE
    IF -step < 1000H THEN G.SubImmH(0, 0, -step)
    ELSE G.MovHImm(1, -step); G.Sub(0, 0, 1)
    END
  END;
  G.Adrp(16, 2);
  IF x.a # 0 THEN G.AddImm(16, 16, x.a) END;
  G.StrH(0, 16)
END IncDecStep;

(** ABS(x): absolute value.
    For constants: folds at compile time.
    For register/variable: loads, compares with 0, conditionally negates. *)
PROCEDURE AbsVal*(VAR x: Item);
BEGIN
  IF x.mode = Table.Const THEN
    IF x.a < 0 THEN x.a := -x.a END
  ELSE
    Load(x);
    G.CmpImm(x.r, 0);
    G.CSNeg(x.r, x.r, x.r, G.GE)
  END
END AbsVal;

(** ODD(x): returns 1 if x is odd, 0 if even.
    Always loads into a register (no constant folding) to avoid mode confusion
    between constant values and condition codes. Result is in Reg mode (0 or 1). *)
PROCEDURE OddVal*(VAR x: Item);
BEGIN
  Load(x);
  G.AndImm1(x.r, x.r)
END OddVal;

(** ASR(x, y): arithmetic shift right x by y bits. *)
PROCEDURE AsrVal*(VAR x, y: Item);
BEGIN
  IF (x.mode = Table.Const) & (y.mode = Table.Const) THEN
    x.a := ASR(x.a, y.a)
  ELSE
    Load(x); Load(y);
    G.Asr(x.r, x.r, y.r);
    G.DecRH
  END
END AsrVal;

(** LSL(x, y): logical shift left x by y bits. *)
PROCEDURE LslVal*(VAR x, y: Item);
BEGIN
  IF (x.mode = Table.Const) & (y.mode = Table.Const) THEN
    x.a := LSL(x.a, y.a)
  ELSE
    Load(x); Load(y);
    G.Lsl(x.r, x.r, y.r);
    G.DecRH
  END
END LslVal;

(** ROR(x, y): rotate right x by y bits. *)
PROCEDURE RorVal*(VAR x, y: Item);
BEGIN
  IF (x.mode = Table.Const) & (y.mode = Table.Const) THEN
    x.a := ROR(x.a, y.a)
  ELSE
    Load(x); Load(y);
    G.Ror(x.r, x.r, y.r);
    G.DecRH
  END
END RorVal;

(** {x} *)
PROCEDURE Singleton*(VAR x: Item);
BEGIN
  IF x.mode = Table.Const THEN
    x.a := LSL(1, x.a)
  ELSE
    Load(x);
    G.MovHImm(16, 1);
    G.Lsl(x.r, 16, x.r)
  END
END Singleton;

(** x + y : set union *)
PROCEDURE SetUnion*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.Orr(x.r, x.r, y.r);
  G.DecRH
END SetUnion;

(** x - y : set difference *)
PROCEDURE SetDiff*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.Bic(x.r, x.r, y.r);
  G.DecRH
END SetDiff;

(** x * y : set intersection *)
PROCEDURE SetInter*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.And(x.r, x.r, y.r);
  G.DecRH
END SetInter;

(** x / y : symmetric difference *)
PROCEDURE SetSymDiff*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.Eor(x.r, x.r, y.r);
  G.DecRH
END SetSymDiff;

(** -x : set complement *)
PROCEDURE SetComplement*(VAR x: Item);
BEGIN
  Load(x);
  G.Mvn(x.r, x.r)
END SetComplement;

(** x IN y *)
PROCEDURE InSet*(VAR x, y: Item);
BEGIN
  Load(x); Load(y);
  G.MovHImm(16, 1);
  G.Lsl(x.r, 16, x.r);
  G.Tst(y.r, x.r);
  G.ResetRHTo(0);
  x.mode := Table.Const;
  x.r := G.NE;
  x.a := 0;
  x.b := 0
END InSet;

(** INCL(s, x) / EXCL(s, x) for absolute set variables *)
PROCEDURE InclExclVar*(VAR s, x: Item; excl: BOOLEAN);
VAR addr: INTEGER;
BEGIN
  IF s.mode # Abs THEN
    Machine.NotImplemented('InclExclVar: only absolute set variables supported')
  END;

  addr := s.a;
  Load(s);  (* current set value in register *)

  IF x.mode = Table.Const THEN
    G.MovHImm(16, 1);
    G.MovHImm(17, x.a);
    G.Lsl(16, 16, 17);
    IF excl THEN
      G.Bic(s.r, s.r, 16)
    ELSE
      G.Orr(s.r, s.r, 16)
    END
  ELSE
    Load(x);
    G.MovHImm(16, 1);
    G.Lsl(x.r, 16, x.r);
    IF excl THEN
      G.Bic(s.r, s.r, x.r)
    ELSE
      G.Orr(s.r, s.r, x.r)
    END;
    G.DecRH
  END;

  G.Adrp(16, 2);
  IF addr # 0 THEN G.AddImm(16, 16, addr) END;
  G.StrH(s.r, 16);
  G.DecRH
END InclExclVar;

(** INC(x, n) or DEC(x, n): increment or decrement variable x by amount n.
    Works for both constant and variable amounts.
    x must be in Abs mode. Uses registers 0 (amount) and 1 (variable value).
    Precondition: G.RH = 0. *)
PROCEDURE IncDecByAmount*(VAR x, n: Item; dec: BOOLEAN);
BEGIN
  IF x.mode # Abs THEN
    Machine.NotImplemented('IncDecByAmount: only absolute mode supported')
  END;
  Load(n);           (* amount in register 0, G.RH = 1 *)
  G.Adrp(16, 2);
  IF x.a # 0 THEN G.AddImm(16, 16, x.a) END;
  G.LdrH(1, 16);     (* load variable value into register 1 *)
  IF dec THEN G.Sub(0, 1, 0)   (* w0 = w1 - w0 = value - amount *)
  ELSE        G.Add(0, 1, 0)   (* w0 = w1 + w0 = value + amount *)
  END;
  G.Adrp(16, 2);
  IF x.a # 0 THEN G.AddImm(16, 16, x.a) END;
  G.StrH(0, 16)      (* store result back *)
END IncDecByAmount;

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

(** Unconditional Forward Jump — chains into escape list for IF/ELSIF END *)
PROCEDURE FJump*(VAR L: INTEGER);
BEGIN
  G.BCond(14 (* AL = always true *), L);
  L := G.Here() - 1
END FJump;

(** Unconditional Backward Jump (Jump conditionally in WHILE) *)
PROCEDURE BJump*(L: INTEGER);
BEGIN
  G.B(L - G.Here())
END BJump;

(** Conditional Forward Jump.
    Emits B.cond(Negated) into false-list, fixes true-list to after the branch. *)
PROCEDURE CFJump*(VAR x: Item);
VAR saveB: INTEGER;
BEGIN
  IF x.mode # Table.Const THEN
    Machine.NotImplemented('CFJump: expected condition code')
  END;
  saveB := x.b;
  x.b := 0;
  G.BCond(Negated(x.r), x.a);
  x.a := G.Here() - 1;
  FixLink(saveB)
END CFJump;


(** Splices two B.cond chain lists into one.
    L1 and L2 are heads of chains (0 = empty). Returns merged head. *)
PROCEDURE MergeLists(L1, L2: INTEGER): INTEGER;
VAR L, prevL, instr, cond: INTEGER;
BEGIN
  IF L1 = 0 THEN L1 := L2
  ELSIF L2 # 0 THEN
    (* Walk to the tail of L1: the entry whose imm19 = 0 *)
    L := L1;
    REPEAT prevL := L; L := G.ImmFromBCond(L) UNTIL L = 0;
    (* Splice: patch tail of L1 to point to head of L2 *)
    instr := G.ReadWord(prevL);
    cond  := instr MOD 10H;
    G.WriteWord(prevL, 54000000H + (L2 MOD 80000H) * 20H + cond)
  END
RETURN L1 END MergeLists;

(** Converts x to a Cond item if it is not already.
    Emits CMP against 0 for Reg/Abs items. *)
PROCEDURE LoadCond*(VAR x: Item);
BEGIN
  IF x.mode # Table.Const THEN (* Not yet a condition code item *)
    Load(x);                   (* Get into register *)
    G.Cmp(x.r, 31);            (* CMP wX, wzr — test for non-zero *)
    G.ResetRHTo(0);
    x.mode := Table.Const;
    x.r := G.NE;               (* NE = was non-zero = TRUE *)
    x.a := 0; x.b := 0
  END
END LoadCond;

(** NOT x: inverts condition code and swaps true/false lists. *)
PROCEDURE Not*(VAR x: Item);
VAR t: INTEGER;
BEGIN
  LoadCond(x);
  x.r := Negated(x.r);
  t := x.a; x.a := x.b; x.b := t
END Not;

(** x & — first half of AND. Emits conditional jump and chains false-list. *)
PROCEDURE And1*(VAR x: Item);
BEGIN
  LoadCond(x);
  CFJump(x)  (* Emits B.cond(Negated) chained into x.a, fixes x.b to here *)
END And1;

(** x & y — second half of AND. Merges false-lists, takes y's condition. *)
PROCEDURE And2*(VAR x, y: Item);
BEGIN
  LoadCond(y);
  x.a := MergeLists(y.a, x.a);  (* Both false → same exit *)
  x.b := y.b;
  x.r := y.r
END And2;

(** x OR — first half of OR. Emits conditional jump and chains true-list. *)
PROCEDURE Or1*(VAR x: Item);
BEGIN
  LoadCond(x);
  FixLink(x.a);          (* Fix false-list to here — false falls through to y *)
  x.a := 0;
  G.BCond(x.r, x.b);    (* B.cond(TRUE) → chain into true-list *)
  x.b := G.Here() - 1
END Or1;

(** x OR y — second half of OR. Merges true-lists, takes y's condition. *)
PROCEDURE Or2*(VAR x, y: Item);
BEGIN
  LoadCond(y);
  x.b := MergeLists(y.b, x.b);  (* Both true → same exit *)
  x.a := y.a;
  x.r := y.r
END Or2;

PROCEDURE OutLn*;
BEGIN
  G.MovImm( 0, 1);        (* stdout *)
  G.Adrp  ( 1, 5);        (* address of 0AX  *)
  G.AddImm( 1, 1, 0FFFH);
  G.MovImm( 2, 1);        (* length = 1 *)
  G.MovImm(16, 4);        (* write *)
  G.Svc(0)
END OutLn;

(** Save the FOR loop end value before the loop starts.
    If endVal is a constant, stores it in savedConst and sets endReg = -1.
    Otherwise loads it into a callee-saved register (endReg). *)
PROCEDURE ForSave*(VAR endVal: Item; VAR savedConst: INTEGER; VAR endReg: INTEGER);
BEGIN
  IF endVal.mode = Table.Const THEN
    savedConst := endVal.a;
    endReg := -1
  ELSE
    Load(endVal);
    endReg := AllocS();
    G.Mov(endReg, endVal.r);
    G.DecRH
  END
END ForSave;

(** Generate the FOR loop condition check.
    step > 0: loop continues while loopVar <= end (exits on GT).
    step < 0: loop continues while loopVar >= end (exits on LT).
    Result x is a condition item ready for CFJump. *)
PROCEDURE ForCond*(obj: Table.Object; endReg, endConst, step: INTEGER; VAR x: Item);
VAR loopVar: Item;
BEGIN
  loopVar.mode := Abs;
  loopVar.a    := obj.address;
  loopVar.type := obj.type;
  loopVar.node := NIL;
  loopVar.b    := 0;
  loopVar.r    := 0;
  Load(loopVar);
  IF endReg = -1 THEN (* constant end value *)
    IF (endConst >= 0) & (endConst < 1000H) THEN
      G.CmpImm(loopVar.r, endConst)
    ELSE
      G.MovHImm(G.RH, endConst);
      G.Cmp(loopVar.r, G.RH)
    END
  ELSE (* non-constant: saved in callee-saved register *)
    G.Cmp(loopVar.r, endReg)
  END;
  G.ResetRHTo(0);
  IF step > 0 THEN x.r := G.LE ELSE x.r := G.GE END;
  x.mode := Table.Const;
  x.a    := 0;
  x.b    := 0
END ForCond;

(** Free the callee-saved register used by ForSave, if any. *)
PROCEDURE ForClean*(endReg: INTEGER);
BEGIN
  IF endReg # -1 THEN FreeS END
END ForClean;

PROCEDURE SetScratchOffset*(offset: INTEGER);
BEGIN
  scratchOffset := offset
END SetScratchOffset;

(** Load CASE expression into a register and keep it there for comparisons. *)
PROCEDURE CaseSave*(VAR x: Item);
BEGIN
  Load(x)
  (* x.mode = Reg, x.r holds the register with the selector value *)
END CaseSave;

(** Compare selector register with a single constant value.
    On match, branch is chained into matchList. *)
PROCEDURE CaseLabel*(VAR x: Item; val: INTEGER; VAR matchList: INTEGER);
BEGIN
  IF (val >= 0) & (val < 1000H) THEN
    G.CmpImm(x.r, val)
  ELSE
    G.MovHImm(G.RH, val);
    G.Cmp(x.r, G.RH)
  END;
  G.BCond(G.EQ, matchList);
  matchList := G.Here() - 1
END CaseLabel;

(** Compare selector register with a range [lo..hi].
    On match, branch is chained into matchList. *)
PROCEDURE CaseRangeLabel*(VAR x: Item; lo, hi: INTEGER; VAR matchList: INTEGER);
VAR skipPos: INTEGER;
BEGIN
  IF (lo >= 0) & (lo < 1000H) THEN
    G.CmpImm(x.r, lo)
  ELSE
    G.MovHImm(G.RH, lo);
    G.Cmp(x.r, G.RH)
  END;
  skipPos := G.Here();
  G.BCond(G.LT, 0);         (* skip if selector < lo *)
  IF (hi >= 0) & (hi < 1000H) THEN
    G.CmpImm(x.r, hi)
  ELSE
    G.MovHImm(G.RH, hi);
    G.Cmp(x.r, G.RH)
  END;
  G.BCond(G.LE, matchList); (* match if selector <= hi *)
  matchList := G.Here() - 1;
  G.PatchBCond(skipPos, G.Here())
END CaseRangeLabel;

(** Free the selector register at the end of the CASE statement. *)
PROCEDURE CaseClean*(VAR x: Item);
BEGIN
  G.ResetRHTo(0)
END CaseClean;

PROCEDURE OutInt*(VAR x: Item);
BEGIN
  Load(x);
  G.Adrp(16, 2);
  G.AddImm(16, 16, scratchOffset);
  G.StrH(x.r, 16);
  G.MovImm( 0, 1);
  G.Adrp  ( 1, 2);
  G.AddImm( 1, 1, scratchOffset);
  G.MovImm( 2, 1);
  G.MovImm(16, 4);
  G.Svc(0)
END OutInt;

PROCEDURE Enter*;
BEGIN
  SH := firstCSReg
END Enter;

PROCEDURE Exit*;
BEGIN
  G.Exit
END Exit;

BEGIN
  SH := firstCSReg

END Emitter.
