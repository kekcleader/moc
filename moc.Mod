MODULE Moc;
IMPORT Out, Args, Strings, Machine, Parser, Scanner, Traverser, Table, Tree, Linker;
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

(** Strips extension from fname and puts result in exe.
    './src/Module.Mod' -> './src/Module'.
    'Module.Mod'       -> 'Module'.
    'Module'           -> 'Module'.
    './src/Module'     -> './src/Module'. *)
PROCEDURE SourceToExeFname(fname: ARRAY OF CHAR; VAR exe: ARRAY OF CHAR);
VAR i, dotPos, slashPos: INTEGER;
BEGIN
  i := 0;
  dotPos := -1;
  slashPos := -1;
  WHILE fname[i] # 0X DO
    IF fname[i] = '.' THEN dotPos := i END;
    IF fname[i] = '/' THEN slashPos := i END;
    INC(i)
  END;
  IF dotPos <= slashPos THEN
    dotPos := i
  END;
  i := 0;
  WHILE i < dotPos DO
    exe[i] := fname[i];
    INC(i)
  END;
  exe[i] := 0X
END SourceToExeFname;

PROCEDURE ParseArgs(VAR mainFname, exeFname: ARRAY OF CHAR): BOOLEAN;
VAR i, count: INTEGER;
  s: ARRAY 256 OF CHAR;
  ok: BOOLEAN;
BEGIN
  ok := TRUE;
  mainFname := '';
  exeFname := '';
  i := 1;
  count := Args.Count();

  WHILE (i <= count) & ok DO
    Args.Get(i, s);
    IF s = '-o' THEN
      IF i < count THEN
        INC(i);
        Args.Get(i, exeFname)
      ELSE
        Out.String("Error: '-o' requires an output file name."); Out.Ln;
        ok := FALSE
      END
    ELSIF s = '--debug' THEN
      Machine.SetDebug(TRUE)
    ELSIF mainFname = '' THEN
      Strings.Copy(s, mainFname)
    ELSE
      Out.String("Error: Unrecognized parameter '"); Out.String(s); Out.String("'."); Out.Ln;
      ok := FALSE
    END;
    INC(i)
  END;

  IF ok THEN
    IF mainFname = '' THEN
      Out.String('Error: No source file specified.'); Out.Ln;
      ok := FALSE
    ELSIF exeFname = '' THEN
      SourceToExeFname(mainFname, exeFname)
    END
  END;

  IF ok & (mainFname = exeFname) THEN
    Out.String("Error: Refusing to overwrite the source file '");
    Out.String(mainFname);
    Out.String("' with the output binary."); Out.Ln;
    ok := FALSE
  END;

  IF ~ok THEN
    Usage
  END;

  RETURN ok
END ParseArgs;

PROCEDURE Run(mainFname, exeFname: ARRAY OF CHAR);
VAR module: Tree.Node;
BEGIN
  IF ~Machine.OpenSourceFile(mainFname) THEN
    Out.String('Could not open source file "');
    Out.String(mainFname); Out.String('".'); Out.Ln
  ELSE
    module := Parser.Parse();
    IF ~Machine.hadErrors THEN
      Machine.BackendPhase;
      IF Machine.debugFrontend THEN
        Out.String('--- Abstract Syntax Tree ---'); Out.Ln;
        Tree.Print(module, 0);
        Out.String('--- Symbol Table ---'); Out.Ln;
        Table.Print(Table.topScope, 0)
      END;

      Traverser.SetAddressesAndSizes(Table.topScope);
      IF ~Machine.hadErrors THEN
        Traverser.Traverse(module);
        IF ~Machine.hadErrors THEN
          Linker.Link(exeFname)
        END
      END
    END
  END
END Run;

PROCEDURE ParseAndRun;
VAR
  mainFname, exeFname: ARRAY 256 OF CHAR;
BEGIN
  IF ParseArgs(mainFname, exeFname) THEN
    Run(mainFname, exeFname)
  END
END ParseAndRun;


PROCEDURE Do*;
BEGIN
  IF Args.Count() = 0 THEN
    Welcome;
    Usage
  ELSE
    ParseAndRun
  END
END Do;

BEGIN
  Do
END Moc.
