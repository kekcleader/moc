MODULE Linker;
IMPORT Out, Strings, Files, Machine, Errors := MocErrors, E := Emitter,
  Generator, Table, Tree, SYSTEM;

CONST
  codeSpace = Generator.maxCodeLen; (** Maximum code length *)

TYPE
  HUGEINT = SYSTEM.INT64;

VAR
  fname: ARRAY 256 OF CHAR;
  F: Files.File;
  r: Files.Rider;

  codeLen: INTEGER;

PROCEDURE DD(n: INTEGER);
BEGIN
  Out.Char(1BX); Out.String('[41m');
  Out.Char(1BX); Out.String('[30m');
  Out.String(' ========================> DEBUG ===> ');
  Out.Char(1BX); Out.String('[97m');
  Out.Int(n, 0); Out.Char(' ');
  Out.Char(1BX); Out.String('[0m'); Out.Ln
END DD;

(** Outputs 1 byte to the file. *)
PROCEDURE Byte(x: BYTE);
BEGIN
  Files.Write(r, x)
END Byte;

(** Outputs 2 bytes to the file. Little-endian.*)
PROCEDURE Word(x: INTEGER);
BEGIN
  Byte(x MOD 100H);
  Byte(x DIV 100H MOD 100H)
END Word;

(** Outputs a double word = 4 bytes to the file. Little-endian.*)
PROCEDURE DWord(x: INTEGER);
BEGIN
  Byte(x MOD 100H);
  Byte(x DIV 100H MOD 100H);
  Byte(x DIV 10000H MOD 100H);
  Byte(x DIV 1000000H MOD 100H)
END DWord;

(** Outputs a quadruple word = 8 bytes to the file. Little-endian.*)
PROCEDURE QWord(x: HUGEINT);
BEGIN
  Byte(x MOD 100H);
  Byte(x DIV 100H MOD 100H);
  Byte(x DIV 10000H MOD 100H);
  Byte(x DIV 1000000H MOD 100H);
  Byte(x DIV 1000000H DIV 100H MOD 100H);
  Byte(x DIV 1000000H DIV 10000H MOD 100H);
  Byte(x DIV 1000000H DIV 1000000H MOD 100H);
  Byte(x DIV 1000000H DIV 1000000H DIV 100H MOD 100H)
END QWord;

(** Outputs a set as 4 bytes to the file. Little-endian.*)
PROCEDURE Set(x: SET);
BEGIN
  DWord(ORD(x))
END Set;

(** Outputs string to the file (one byte per character) and then
    zero-bytes until total of n bytes is reached. Th of the string.
    If n is smaller than the string, the string is not truncated. *)
PROCEDURE String(s: ARRAY OF CHAR; n: INTEGER);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    Byte(ORD(s[i]));
    INC(i)
  END;
  WHILE i < n DO
    Byte(0);
    INC(i)
  END
END String;

(** Outputs n zero bytes to the file. *)
PROCEDURE Zeros(n: INTEGER);
BEGIN
  WHILE n > 0 DO
    Byte(0);
    DEC(n)
  END
END Zeros;

(** Outputs first 32 bytes - the Mach-O header to the file. *)
PROCEDURE Header;
BEGIN
  (* FEED-FACF Magic Number, little-endian *)
  Byte(0CFH); Byte(0FAH); Byte(0EDH); Byte(0FEH);
  (* CPU Type = ARM64 *)
  DWord(100000CH);
  (* CPU Subtype = ARM64_ALL *)
  DWord(0);
  (* File Type = MH_EXECUTE *)
  DWord(2);
  (* Number of Load Commands *)
  DWord(15);
  (* Size of Load Commands in bytes *)
  DWord(744-16);
  (* Flags = {NOUNDEFS, DYLDLINK, TWOLEVEL, PIE} *)
  Set({0, 2, 7, 21});
  (* Reserved = 0 *)
  DWord(0)
END Header;

PROCEDURE Command0;
BEGIN
  (* Command LC_SEGMENT_64 *)
  DWord(19H);
  (* Command Size in bytes *)
  DWord(72);
  (* Segment Name *)
  String('__PAGEZERO', 16);
  (* VM Address *)
  QWord(0);
  (* VM Size *)
  QWord(1000000H * 100H); (* 4 GB *)
  (* File Offset *)
  QWord(0);
  (* File Size *)
  QWord(0);
  (* Maximum VM Protection *)
  DWord(0);
  (* Initial VM Protection *)
  DWord(0);
  (* Number of Sections *)
  DWord(0);
  (* Flags *)
  Set({})
END Command0;

PROCEDURE Command1;

  PROCEDURE Section0;
  BEGIN
    (* Section Name *)
    String('__text', 16);
    (* Segment Name *)
    String('__TEXT', 16);
    (* Address *)
    QWord(1000000H * 100H + 4000H - codeSpace);
    (* Size in bytes *)
    QWord(codeLen);
    (* Offset *)
    DWord(4000H - codeSpace);
    (* Alignment = 2^2 = 4*)
    DWord(2);
    (* Relocations Offset *)
    DWord(0);
    (* Number of Relocations *)
    DWord(0);
    (* Flags = S_ATTR_SOME_INSTRUCTIONS + S_ATTR_PURE_INSTRUCTIONS *)
    Set({10, 31});
    (* Reserved *)
    DWord(0);
    DWord(0);
    DWord(0)
  END Section0;

  PROCEDURE Section1;
  BEGIN
    (* Section Name *)
    String('__unwind_info', 16);
    (* Segment Name *)
    String('__TEXT', 16);
    (* Address *)
    QWord(1000000H * 100H + 4000H - codeSpace + codeLen);
    (* Size in bytes *)
    QWord(codeSpace - codeLen);
    (* Offset *)
    DWord(4000H - codeSpace + codeLen);
    (* Alignment = 2^2 = 4*)
    DWord(2);
    (* Relocations Offset *)
    DWord(0);
    (* Number of Relocations *)
    DWord(0);
    (* Flags = S_REGULAR (empty set) *)
    Set({});
    (* Reserved *)
    DWord(0);
    DWord(0);
    DWord(0)
  END Section1;

BEGIN (* Command1 *)
  (* Command LC_SEGMENT_64 *)
  DWord(19H);
  (* Command Size in bytes *)
  DWord(232);
  (* Segment Name *)
  String('__TEXT', 16);
  (* VM Address *)
  QWord(1000000H * 100H); (* 4 GB *)
  (* VM Size *)
  QWord(4000H);
  (* File Offset *)
  QWord(0);
  (* File Size *)
  QWord(4000H);
  (* Maximum VM Protection = VM_PROT_READ, VM_PROT_EXECUTE *)
  Set({0, 2});
  (* Initial VM Protection = VM_PROT_READ, VM_PROT_EXECUTE *)
  Set({0, 2});
  (* Number of Sections *)
  DWord(2);
  (* Flags *)
  Set({});
  (* Sections *)
  Section0;
  Section1
END Command1;

PROCEDURE Command2;
BEGIN
  (* Command LC_SEGMENT_64 *)
  DWord(19H);
  (* Command Size in bytes *)
  DWord(72);
  (* Segment Name *)
  String('__LINKEDIT', 16);
  (* VM Address *)
  QWord(1000000H * 100H + 4000H);
  (* VM Size *)
  QWord(4000H); (* 16 KB *)
  (* File Offset *)
  QWord(4000H);
  (* File Size *)
  QWord(176);
  (* Maximum VM Protection *)
  DWord(1);
  (* Initial VM Protection *)
  DWord(1);
  (* Number of Sections *)
  DWord(0);
  (* Flags *)
  Set({})
END Command2;

PROCEDURE Command3;
BEGIN
  (* Command LC_DYLD_CHAINED_FIXUPS *)
  (*DWord(34H);*) (* FIXME <----------------- 34 00 00 80, what is 8 for? *)
  Byte(34H); Byte(0); Byte(0); Byte(80H);
  (* Command Size in bytes *)
  DWord(16);
  (* Data Offset *)
  DWord(4000H);
  (* Data Size *)
  DWord(56)
END Command3;

PROCEDURE Command4;
BEGIN
  (* Command LC_DYLD_EXPORTS_TRIE *)
  (*DWord(33H);*) (* FIXME <----------------- what is 8 for? *)
  Byte(33H); Byte(0); Byte(0); Byte(80H);
  (* Command Size in bytes *)
  DWord(16);
  (* Data Offset *)
  DWord(4000H + 56);
  (* Data Size *)
  DWord(48)
END Command4;

PROCEDURE Command5;
BEGIN
  (* Command LC_SYMTAB *)
  DWord(2);
  (* Command Size in bytes *)
  DWord(24);
  (* Symbol Table Offset, 8 bytes contain the procedure starts table, Seg. 13 *)
  DWord(4000H + 56 + 48 + 8); (* 4000H + 112 *)
  (* Number of Symbols *)
  DWord(2);
  (* String Table Offset *)
  DWord(4000H + 56 + 48 + 8 + 32); (* 4000H + 144 *)
  (* String Table Size *)
  DWord(32)
END Command5;

PROCEDURE Command6;
BEGIN
  (* Command LC_DYSYMTAB *)
  DWord(0BH);
  (* Command Size in bytes *)
  DWord(80);

  (* LocSymbol Index *)
  DWord(0);
  (* LocSymbol Number *)
  DWord(0);

  (* Defined ExtSymbol Index *)
  DWord(0);
  (* Defined ExtSymbol Number *)
  DWord(2);

  (* Undefined ExtSymbol Index *)
  DWord(2);
  (* Undefined ExtSymbol Number *)
  DWord(0);

  (* TOC (Table of Contents) Offset *)
  DWord(0);
  (* TOC Entries *)
  DWord(0);

  (* Module Table Offset *)
  DWord(0);
  (* Module Table Entries *)
  DWord(0);

  (* ExtRef Table Offset *)
  DWord(0);
  (* ExtRef Table Entries *)
  DWord(0);

  (* IndSym Table Offset *)
  DWord(0);
  (* IndSym Table Entries *)
  DWord(0);

  (* ExtReloc Table Offset *)
  DWord(0);
  (* ExtReloc Table Entries *)
  DWord(0);

  (* LocReloc Table Offset *)
  DWord(0);
  (* LocReloc Table Entries *)
  DWord(0)
END Command6;

PROCEDURE Command7;
BEGIN
  (* Command LC_LOAD_DYLINKER *)
  DWord(0EH);
  (* Command Size in bytes *)
  DWord(32);
  (* String Offset *)
  DWord(12);
  (* Name *)
  String('/usr/lib/dyld', 20)
END Command7;

PROCEDURE Command8;
BEGIN
  (* Command LC_UUID *)
  DWord(1BH);
  (* Command Size in bytes *)
  DWord(24);
  (* UUID, 16 bytes, TODO generate random *)
  Word(09A45H); Word(0ADB9H); Word(02E6CH); Word(09B32H);
  Word(0E48AH); Word(06EECH); Word(07BCDH); Word(0EC6DH)
END Command8;

PROCEDURE Command9;
BEGIN
  (* Command LC_BUILD_VERSION *)
  DWord(32H);
  (* Command Size in bytes *)
  DWord(32);
  (* Platform = MacOS *)
  DWord(1);
  (* Minimum OS Version = 15.0.0 *)
  DWord(0F0000H);
  (* SDK Version, 0 = undefined *)
  DWord(0);
  (* Tool Count - number of elements in the array below *)
  DWord(1);

  (* Array of Tools, 1 element *)
  (* Tool Type = linker ld *)
  DWord(3);
  (* Tool Version = 1115.7.3 *)
  DWord(45B0703H)
END Command9;

PROCEDURE Command10;
BEGIN
  (* Command LC_SOURCE_VERSION *)
  DWord(2AH);
  (* Command Size in bytes *)
  DWord(16);
  (* Version = 0.0 *)
  QWord(0)
END Command10;

PROCEDURE Command11;
BEGIN
  (* Command LC_MAIN *)
  Byte(28H); Byte(0); Byte(0); Byte(80H);
  (* Command Size in bytes *)
  DWord(24);
  (* Entry Offset *)
  QWord(4000H - codeSpace);
  (* Initial Stack Size, may be 0 *)
  QWord(0)
END Command11;

PROCEDURE Command12;
BEGIN
  (* Command LC_LOAD_DYLIB *)
  DWord(0CH);
  (* Command Size in bytes *)
  DWord(56);
  (* String Offset *)
  DWord(24);
  (* Time Stamp = 1970-01-01 00:00:02 *)
  DWord(2);
  (* Current Version = 1351.0.0 *)
  DWord(5470000H);
  (* Compatibility Version *)
  DWord(10000H);
  (* Name *)
  String('/usr/lib/libSystem.B.dylib', 32)
END Command12;

PROCEDURE Command13;
BEGIN
  (* Command LC_FUNCTION_STARTS *)
  DWord(26H);
  (* Command Size in bytes *)
  DWord(16);
  (* Data Offset *)
  DWord(4000H + 104);
  (* Data Size *)
  DWord(8)
END Command13;

PROCEDURE Command14;
BEGIN
  (* Command LC_DATA_IN_CODE *)
  DWord(29H);
  (* Command Size in bytes *)
  DWord(16);
  (* Data Offset *)
  DWord(4000H + 112);
  (* Data Size *)
  DWord(0)
END Command14;

(** Outputs Mach-O commands to the file. *)
PROCEDURE Commands;
BEGIN
  Command0;
  Command1;
  Command2;
  Command3;
  Command4;
  Command5;
  Command6;
  Command7;
  Command8;
  Command9;
  Command10;
  Command11;
  Command12;
  Command13;
  Command14
END Commands;

(** Outputs 56 bytes to the file. *)
PROCEDURE ChainedFixups;
BEGIN
  (* Fixups Version *)
  DWord(0);
  (* Starts Offset *)
  DWord(20H);
  (* Imports Offset *)
  DWord(30H);
  (* Symbols Offset *)
  DWord(30H);
  (* Imports Count *)
  DWord(0);
  (* Imports Format *)
  DWord(1);
  (* Symbols Format *)
  DWord(0);

  (* Starts in Image *)
  (* Segment Count *)
  DWord(0);
  (* Segment Info Offset - DWord array (empty) *)

  (* Starts in Segment *)
  (* Size *)
  DWord(3);
  (* Page Size *)
  DWord(0);
  (* Pointer Format *)
  DWord(0);
  (* Segment Offset *)
  DWord(0);
  (* Maximum Valid Pointer *)
  DWord(0);
  (* Page Count *)
  Word(0);
  (* Page Start - DWord array *)
  Word(0)
END ChainedFixups;

(** Outputs 48 bytes to the file. *)
PROCEDURE ExportsTrie;
BEGIN
  Byte(0);   Byte(1);   Byte(5FH); Byte(0);
  Byte(12H); Byte(0);   Byte(0);   Byte(0);

  Byte(0);   Byte(2);   Byte(0);   Byte(0);
  Byte(0);   Byte(3);   Byte(0);   Byte(9CH);
  Byte(7FH); Byte(0);   Byte(0);   Byte(2);

  String('_mh_execute_header', 0);
  Byte(0);   Byte(9);

  String('start', 0);
  Byte(0);   Byte(0DH); Byte(0)
END ExportsTrie;

PROCEDURE FunctionStarts;
BEGIN
  Byte(9CH); Byte(7FH); Word(0); DWord(0)
END FunctionStarts;

PROCEDURE SymbolTable;
BEGIN
  (* Proper Symbol Table *)
  DWord(2);   DWord(10010FH); DWord(0);     DWord(1);
  DWord(16H); DWord(10FH);    DWord(3F9CH); DWord(1);

  (* Name Strings *)
  Byte(20H); Byte(0);
  String('__mh_execute_header', 0); Byte(0);
  String('_start', 0); DWord(0)
END SymbolTable;

PROCEDURE Output;
BEGIN
  Header;
  Commands;

  (* Zero-out until position 4000H - codeSpace *)
  Zeros(4000H - codeSpace - Files.Pos(r));
  (* Machine code *)
  Generator.Output(r);
  (* Unwind Info *)
  Zeros(codeSpace - codeLen);

  ChainedFixups;
  ExportsTrie;
  FunctionStarts;
  SymbolTable
END Output;

PROCEDURE OpenOutputFile;
BEGIN
  F := Files.New(fname);
  IF F = NIL THEN
    Machine.GeneralError(Errors.outputFile)
  ELSE
    Files.Set(r, F, 0)
  END
END OpenOutputFile;

PROCEDURE ChmodAndSign;
VAR s: ARRAY 1024 OF CHAR;
  err: INTEGER;
BEGIN
  (* Chmod *)
  s := 'chmod +x ';
  Strings.Append(fname, s);
  err := Machine.Exec(s);
  IF err # 0 THEN
    Machine.GeneralError(Errors.chmodFailed)
  ELSE
    (* Sign *)
    s := 'codesign -s - -f --timestamp=none ';
    Strings.Append(fname, s);
    err := Machine.Exec(s);
    IF err # 0 THEN
      Machine.GeneralError(Errors.signFailed)
    END
  END
END ChmodAndSign;

PROCEDURE Link*(exeFname: ARRAY OF CHAR);
BEGIN
  Strings.Copy(exeFname, fname);
  codeLen := Generator.CodeLength();
  OpenOutputFile;
  IF ~Machine.hadErrors THEN
    Output;
    IF Machine.hadErrors THEN
      Files.Close(F)
    ELSE
      Files.Register(F);
      ChmodAndSign
    END
  END
END Link;

END Linker.
