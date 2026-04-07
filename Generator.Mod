MODULE Generator;
IMPORT Out, Strings, Files, Machine, Errors := MocErrors;

CONST
  maxCodeLen* = 2000H;
  maxDataLen* = 2000H;

  EQ* = 0;  NE* = 1;  (* Equal, Not Equal *)
  GE* = 10; LT* = 11; (* Greater/Equal, Less Than *)
  GT* = 12; LE* = 13; (* Greater Than, Less/Equal *)

VAR
  code: ARRAY maxCodeLen OF BYTE;
  pc: INTEGER;

  dataLen: INTEGER; (** For global variables *)
  outOfMemory: BOOLEAN;
  RH* : INTEGER; (* First free register *)

PROCEDURE OutOfMemory;
BEGIN
  IF ~outOfMemory THEN
    outOfMemory := TRUE;
    Machine.Error(Errors.outOfMemory)
  END
END OutOfMemory;

(** Outputs 1 byte. *)
PROCEDURE Byte*(x: BYTE);
BEGIN
  IF pc = LEN(code) THEN
    OutOfMemory
  ELSE
    code[pc] := x;
    INC(pc)
  END
END Byte;

(** Outputs 2 bytes. Little-endian.*)
PROCEDURE Word*(x: INTEGER);
BEGIN
  IF pc > LEN(code) - 2 THEN
    OutOfMemory
  ELSE
    code[pc] := x MOD 100H;
    INC(pc);
    code[pc] := x DIV 100H MOD 100H;
    INC(pc)
  END
END Word;

(** Outputs a double word = 4 bytes. Little-endian.*)
PROCEDURE DWord*(x: INTEGER);
BEGIN
  IF pc > LEN(code) - 4 THEN
    OutOfMemory
  ELSE
    code[pc] := x MOD 100H;
    INC(pc);
    code[pc] := x DIV 100H MOD 100H;
    INC(pc);
    code[pc] := x DIV 10000H MOD 100H;
    INC(pc);
    code[pc] := x DIV 1000000H MOD 100H;
    INC(pc)
  END
END DWord;

(** Outputs a set as 4 bytes. Little-endian.*)
PROCEDURE Set(x: SET);
BEGIN
  DWord(ORD(x))
END Set;

(** Outputs string to the file (one byte per character). *)
PROCEDURE String(s: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    Byte(ORD(s[i]));
    INC(i)
  END
END String;

(** Generates code that terminates the program. *)
PROCEDURE Exit*;
BEGIN
  Word(00000H); Word(0D280H);
  Word(00030H); Word(0D280H);
  Word(00001H); Word(0D400H)
END Exit;

PROCEDURE DummyCode*;
BEGIN
  Word(00020H); Word(0D280H);
  Word(000E1H); Word(01000H);
  Word(000E2H); Word(0D280H);
  Word(00090H); Word(0D280H);

  Word(00001H); Word(0D400H);
  Word(00000H); Word(0D280H);
  Word(00030H); Word(0D280H);
  Word(00001H); Word(0D400H);

  String('OBERON'); Byte(0AH); Byte(0)

(*
  Word(017E0H); Word(0D280H);
  Word(00030H); Word(0D280H);
  Word(00001H); Word(0D400H);
  *)
END DummyCode;

(** MOV x{r}, #{imm} *)
PROCEDURE MovImm*(r, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := (294H * 10000H + imm MOD 10000H) * 20H + r;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for 64-bit *)
  DWord(n)
END MovImm;

(** MOV w{r}, #{imm} *)
PROCEDURE MovHImm*(r, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := (294H * 10000H + imm MOD 10000H) * 20H + r;
  (* Keep highest bit 0 for 32-bit operand *)
  DWord(n)
END MovHImm;

(** ADRP w{r}, #{imm} *)
PROCEDURE Adrp*(r, imm: INTEGER);
VAR n, immlo, immhi: INTEGER;
BEGIN
  immlo := imm MOD 4;
  immhi := imm DIV 4;
  n := ((immlo * 20H + 10H) * 80000H + immhi) * 20H + r;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for op=ADRP *)
  DWord(n)
END Adrp;

(** MOV x{r1}, x{r2}, #{imm} *)
PROCEDURE AddImm*(r1, r2, imm: INTEGER);
VAR n: INTEGER;
BEGIN
  n := ((22H * 2000H + imm MOD 1000H) * 20H + r2) * 20H + r1;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit for sf=64bit *)
  DWord(n)
END AddImm;

(** ADD w{r1}, w{r2}, w{r3} (32-bit, shifted register with 0 shift) *)
PROCEDURE Add*(r1, r2, r3: INTEGER);
VAR n: INTEGER;
BEGIN
  (* base opcode for ADD (shifted register, 32-bit) = 0x0B000000 *)
  n := 0B000000H;
  (* Rm in bits 20..16 *)
  n := n + r3 * 10000H;
  (* Rn in bits 9..5 *)
  n := n + r2 * 20H;
  (* Rd in bits 4..0 *)
  n := n + r1;
  DWord(n)
END Add;

(** SUB w{r1}, w{r2}, w{r3} (32-bit, shifted register with 0 shift) *)
PROCEDURE Sub*(r1, r2, r3: INTEGER);
VAR n: INTEGER;
BEGIN
  (* base opcode for SUB (shifted register, 32-bit) = 0x4B000000 *)
  n := 4B000000H;
  (* Rm in bits 20..16 *)
  n := n + r3 * 10000H;
  (* Rn in bits 9..5 *)
  n := n + r2 * 20H;
  (* Rd in bits 4..0 *)
  n := n + r1;
  DWord(n)
END Sub;

(** MSUB w{r1}, w{r2}, w{r3}, w{r4} *)
PROCEDURE Msub*(r1, r2, r3, r4: INTEGER);
VAR n: INTEGER;
BEGIN
  (* Base opcode for 32-bit MSUB: 0x1B008000 *)
  n := 1B008000H;
  (* Rm in bits 20..16 *)
  n := n + r3 * 10000H;
  (* Ra (minuend) in bits 14..10 *)
  n := n + r4 * 400H;
  (* Rn in bits 9..5 *)
  n := n + r2 * 20H;
  (* Rd in bits 4..0 *)
  n := n + r1;
  DWord(n)
END Msub;


(** MUL w{r1}, w{r2}, w{r3} (alias for MADD w{r1}, w{r2}, w{r3}, wzr) *)
PROCEDURE Mul*(r1, r2, r3: INTEGER);
VAR n: INTEGER;
BEGIN
  (* Base opcode for 32-bit MADD: 0x1B000000 *)
  n := 1B000000H;
  (* Rm in bits 20..16 *)
  n := n + r3 * 10000H;
  (* Ra (addend) in bits 14..10. For MUL, Ra = 31 (WZR) *)
  n := n + 31 * 400H;
  (* Rn in bits 9..5 *)
  n := n + r2 * 20H;
  (* Rd in bits 4..0 *)
  n := n + r1;
  DWord(n)
END Mul;

(** SDIV w{r1}, w{r2}, w{r3} (32-bit signed divide) *)
PROCEDURE Div*(r1, r2, r3: INTEGER);
VAR n: INTEGER;
BEGIN
  (* Base opcode for 32-bit SDIV: 0x1AC00C00 *)
  n := 1AC00C00H;
  (* Rm in bits 20..16 *)
  n := n + r3 * 10000H;
  (* Rn in bits 9..5 *)
  n := n + r2 * 20H;
  (* Rd in bits 4..0 *)
  n := n + r1;
  DWord(n)
END Div;


(** STR w{r1}, [x{r2}] *)
PROCEDURE StrH*(r1, r2: INTEGER);
VAR n, Rm, option, S: INTEGER;
BEGIN
  Rm := 0;
  option := 0;
  S := 0;
  n := ((((1C8H * 20H + Rm) * 8 + option) * 2 + S) * 80H + r2) * 20H + r1;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit *)
  DWord(n)
END StrH;

(** LDR w{r1}, [x{r2}] *)
PROCEDURE LdrH*(r1, r2: INTEGER);
VAR n, Rm, option, S: INTEGER;
BEGIN
  Rm := 0;
  option := 0;
  S := 0;
  n := ((((1CAH * 20H + Rm) * 8 + option) * 2 + S) * 80H + r2) * 20H + r1;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit *)
  DWord(n)
END LdrH;


(** SVC {a}, a is ignored for now. *)
PROCEDURE Svc*(a: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 54000001H;
  n := -7FFFFFFFH - 1 + n; (* Set highest bit *)
  DWord(n)
END Svc;

PROCEDURE CodeLength*(): INTEGER;
RETURN pc END CodeLength;

PROCEDURE SetDataLen*(len: INTEGER);
BEGIN
  dataLen := len
END SetDataLen;

PROCEDURE DataLength*(): INTEGER;
RETURN dataLen END DataLength;

PROCEDURE OutputCode*(VAR r: Files.Rider);
BEGIN
  Files.WriteBytes(r, code, pc);
END OutputCode;

PROCEDURE OutputData*(VAR r: Files.Rider);
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO dataLen - 1 DO Files.Write(r, 0) END
END OutputData;

(** CMP w{r1}, w{r2} (alias for SUBS wzr, w{r1}, w{r2}) *)
PROCEDURE Cmp*(r1, r2: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 6B000000H;
  n := n + r2 * 10000H;
  n := n + r1 * 20H;
  n := n + 31; (* Rd = 31 (WZR) *)
  DWord(n)
END Cmp;

(** B.cond (Conditional branch) *)
PROCEDURE EmitCondBranch*(cond: INTEGER; VAR branchPC: INTEGER);
VAR n: INTEGER;
BEGIN
  branchPC := pc;
  n := 54000000H + cond; (* Base 0x54000000, offset 0 *)
  DWord(n)
END EmitCondBranch;

(** B (Unconditional branch) *)
PROCEDURE EmitBranch*(VAR branchPC: INTEGER);
VAR n: INTEGER;
BEGIN
  branchPC := pc;
  n := 14000000H; (* Base 0x14000000, offset 0 *)
  DWord(n)
END EmitBranch;

(** Current position in code (in words, not bytes) *)
PROCEDURE Here*(): INTEGER;
RETURN pc DIV 4 END Here;

(** Read 19-bit offset from B.cond instruction at address L (in words) *)
PROCEDURE ImmFromBCond*(L: INTEGER): INTEGER;
VAR instr, imm19, bytePos: INTEGER;
BEGIN
  bytePos := L * 4;
  instr := code[bytePos] + code[bytePos+1]*100H +
           code[bytePos+2]*10000H + code[bytePos+3]*1000000H;
  imm19 := (instr DIV 20H) MOD 80000H;
  IF imm19 >= 40000H THEN DEC(imm19, 80000H) END
RETURN imm19 END ImmFromBCond;

(** Patch the B.cond instruction at address L, replacing its offset with (target - L) *)
PROCEDURE PatchBCond*(L, target: INTEGER);
VAR offset, instr, cond, bytePos: INTEGER;
BEGIN
  bytePos := L * 4;
  instr := code[bytePos] + code[bytePos+1]*100H +
           code[bytePos+2]*10000H + code[bytePos+3]*1000000H;
  cond := instr MOD 10H;
  offset := target - L;
  instr := 54000000H + (offset MOD 80000H) * 20H + cond;
  code[bytePos]   := instr MOD 100H;
  code[bytePos+1] := (instr DIV 100H) MOD 100H;
  code[bytePos+2] := (instr DIV 10000H) MOD 100H;
  code[bytePos+3] := (instr DIV 1000000H) MOD 100H
END PatchBCond;

(** Gives an instruction B.cond. cond, offset - shift to the previous element (or 0) *)
PROCEDURE BCond*(cond, offset: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 54000000H + (offset MOD 80000H) * 20H + cond;
  DWord(n)
END BCond;

(** Gives an unconditional jump instruction B. *)
PROCEDURE B*(offset: INTEGER);
VAR n: INTEGER;
BEGIN
  n := 14000000H + (offset MOD 4000000H);
  DWord(n)
END B;

PROCEDURE IncRH*;
BEGIN
  INC(RH)
END IncRH;

PROCEDURE DecRH*;
BEGIN
  DEC(RH)
END DecRH;

PROCEDURE ResetRHTo*(newRH: INTEGER);
BEGIN
  RH := newRH
END ResetRHTo;

PROCEDURE ResetRH*;
BEGIN
  RH := 0
END ResetRH;

PROCEDURE Init*;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO LEN(code) - 1 DO code[i] := 0 END;
  pc := 0;
  RH := 0;
  outOfMemory := FALSE
END Init;

END Generator.
