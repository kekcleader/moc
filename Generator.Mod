MODULE Generator;
IMPORT Out, Strings, Files, Machine, Errors := MocErrors;

CONST
  maxCodeLen* = 2000H;

TYPE

VAR
  code: ARRAY maxCodeLen OF BYTE;
  pc: INTEGER;

  outOfMemory: BOOLEAN;

PROCEDURE OutOfMemory;
BEGIN
  IF ~outOfMemory THEN
    outOfMemory := TRUE;
    Machine.GeneralError(Errors.outOfMemory)
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

PROCEDURE CodeLength*(): INTEGER;
RETURN pc END CodeLength;

PROCEDURE Output*(VAR r: Files.Rider);
BEGIN
  Files.WriteBytes(r, code, pc);
END Output;

PROCEDURE Init*;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO LEN(code) - 1 DO code[i] := 0 END;
  pc := 0;
  outOfMemory := FALSE
END Init;

END Generator.
