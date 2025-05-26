MODULE Generator;
IMPORT Out, Strings, Files, Machine, Errors := MocErrors;

CONST
  maxCodeLen* = 2000H;
  maxDataLen* = 2000H;

VAR
  code: ARRAY maxCodeLen OF BYTE;
  pc: INTEGER;

  dataLen: INTEGER; (** For global variables *)

  outOfMemory: BOOLEAN;

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

(** MOV w{r}, #{imm} *)
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

PROCEDURE Init*;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO LEN(code) - 1 DO code[i] := 0 END;
  pc := 0;
  outOfMemory := FALSE
END Init;

END Generator.
