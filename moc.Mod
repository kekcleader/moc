MODULE Moc;
IMPORT Out, Args, Strings, Machine, Parser, Scanner, Traverser, Table, Tree;
CONST
  version = '1.0.0-alpha.1';

PROCEDURE Welcome;
BEGIN
  Out.String('Mac Oberon Compiler version ');
  Out.String(version); Out.Ln;
  Out.String('Copyright (c) 2025');
  Out.String(' by Arthur Yefimov.'); Out.Ln
END Welcome;

PROCEDURE Usage;
VAR s: ARRAY 256 OF CHAR;
BEGIN
  Out.String('Usage:'); Out.Ln; Args.Get(0, s);
  Out.String(' '); Out.String(s);
  Out.String(' {parameter} sourceFile'); Out.Ln; Out.Ln;
  Out.String('Parameters:'); Out.Ln;
  Out.String(' -o outputFile    Specify an executable file name'); Out.Ln;
  Out.String(' --debug          Enable debug output'); Out.Ln; Out.Ln
END Usage;

(** Finds period and truncates the string there. Puts the result in exe.
    'Module.Mod' -> 'Module'.
    If period is not found, the result is an empty string. *)
PROCEDURE SourceToExeFname(fname: ARRAY OF CHAR; VAR exe: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (fname[i] # 0X) & (fname[i] # '.') DO
    exe[i] := fname[i];
    INC(i)
  END;
  IF fname[i] = 0X THEN i := 0 END;
  exe[i] := 0X
END SourceToExeFname;

PROCEDURE ParseArgs(VAR mainFname, exeFname: ARRAY OF CHAR);
VAR i, count: INTEGER;
  s: ARRAY 256 OF CHAR;
  ok: BOOLEAN;
BEGIN
  ok := TRUE;
  mainFname := '';
  exeFname := '';
  i := 1;
  count := Args.Count();
  WHILE i <= count DO
    Args.Get(i, s);
    IF s = '-o' THEN
      Args.Get(i + 1, exeFname);
      INC(i)
    ELSIF s = '--debug' THEN
      Machine.SetDebug(TRUE)
    ELSIF mainFname = '' THEN
      Strings.Copy(s, mainFname)
    ELSE
      ok := FALSE
    END;
    INC(i)
  END;
  IF ~ok THEN
    Out.String('Error while parsing command line arguments. ');
    Usage
  ELSIF exeFname = '' THEN
    SourceToExeFname(mainFname, exeFname)
  END
END ParseArgs;

PROCEDURE Run(mainFname, exeFname: ARRAY OF CHAR);
VAR module: Tree.Node;
BEGIN
  IF ~Machine.OpenSourceFile(mainFname) THEN
    Out.String('Could not open source file "');
    Out.String(mainFname); Out.String('".'); Out.Ln
  ELSE
    module := Parser.Parse();
    IF module = NIL THEN
      Out.String('Could not parse.'); Out.Ln
    ELSE
    (*
      Out.String('--- Abstract Syntax Tree ---'); Out.Ln;
      Tree.Print(module, 0);
      Out.String('--- Symbol Table ---'); Out.Ln;
      Table.Print(Table.topScope, 0)*)
    END
  END
END Run;

PROCEDURE PraseAndRun;
VAR
  mainFname, exeFname: ARRAY 256 OF CHAR;
BEGIN
  ParseArgs(mainFname, exeFname);
  IF mainFname # '' THEN
    Run(mainFname, exeFname)
  ELSE
    Out.String('No file specified.'); Out.Ln
  END
END PraseAndRun;

PROCEDURE Do*;
BEGIN
  IF Args.Count() = 0 THEN
    Welcome;
    Usage
  ELSE
    PraseAndRun
  END
END Do;

BEGIN
  Do
END Moc.
