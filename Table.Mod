MODULE Table;
IMPORT Out, Strings, Scanner;

CONST
  (** Object.class values **)
  Head* = 0; Const* = 1; Var*   = 2; VarPar* = 3; Field* = 4;
  Typ*  = 5; SProc* = 6; SFunc* = 7; Mod*    = 8;

  (** Type.form values **)
  Byte*   =  1; Bool*    =  2; Char*   =  3; Int*   = 4; Real* =  5;
  Set*    =  6; Pointer* =  7; NilTyp* =  8; NoTyp* = 9; Proc* = 10;
  String* = 11; Array*   = 12; Record* = 13;

  (** Standard procedure numbers **)
  umlFunc*   =  1; rorFunc* =  2; asrFunc*    =  3; lslFunc*  =  4;
  lenFunc*   =  5; chrFunc* =  6; ordFunc*    =  7; fltFunc*  =  8;
  floorFunc* =  9; oddFunc* = 10; absFunc*    = 11; unpkProc* = 12;
  packProc*  = 13; newProc* = 14; assertProc* = 15; exclProc* = 16;
  inclProc*  = 17; decProc* = 18; incProc*    = 19;

  (** System procedure numbers **)
  sizeFunc*   = 40; adrFunc*  = 41; valFunc* = 42; regFunc* = 43;
  bitFunc*    = 44; copyProc* = 65; putProc* = 66; getProc* = 65;
  putregProc* = 66;

TYPE
  Ident* = Scanner.Ident;
  StrVal* = Scanner.StrVal;

  ConstVal* = POINTER TO ConstValDesc;
  Type* = POINTER TO TypeDesc;
  Object* = POINTER TO ObjectDesc;

  ConstExt* = POINTER TO ConstExtDesc;
  ConstExtDesc*= RECORD
    s*: StrVal
  END;

  ConstValDesc* = RECORD
    ext*: ConstExt; (** For string constants *)
    intVal*: INTEGER;
    realVal*: REAL;
    setVal*: SET
  END;

  TypeDesc* = RECORD
    form*: INTEGER; (** See Type.form constants *)
    paramCount*: INTEGER;
    len*: INTEGER;
    size*: INTEGER; (** In bytes *)
    base*: Type;
    dsc*: Object; (** Descendant object *)
    typeObj*: Object (** Original object that introduced the type *)
  END;

  ObjectDesc* = RECORD
    class*: INTEGER; (** See Object.class constants *)
    name*: Ident;
    scope*: Object;
    dsc*: Object; (** Descendant object *)
    type*: Type;
    value*: INTEGER;
    constVal*: ConstVal;
    next*: Object
  END;

VAR topScope*, universe, system*: Object;
  byteType*, boolType*, charType*, intType*, realType*: Type;
  setType*, nilType*, noType*, strType*: Type;

PROCEDURE NewConst*(): ConstVal;
VAR c: ConstVal;
BEGIN
  NEW(c)
RETURN c END NewConst;

PROCEDURE NewObject*(): Object;
VAR obj: Object;
BEGIN
  NEW(obj)
RETURN obj END NewObject;

PROCEDURE OpenScope*;
VAR scope: Object;
BEGIN
  NEW(scope);
  scope.class := Head;
  scope.dsc := topScope;
  scope.next := NIL;
  topScope := scope
END OpenScope;

PROCEDURE CloseScope*;
BEGIN
  topScope := topScope.dsc
END CloseScope;

PROCEDURE Init*;
BEGIN
  topScope := universe
END Init;

PROCEDURE Import*(alias, name, selfName: Scanner.Ident);
BEGIN
  Out.String('importing '); Out.String(name);
  Out.String(' as '); Out.String(alias);
  Out.String(' to '); Out.String(selfName);
  Out.Ln
  (*TODO*)
END Import;

PROCEDURE MakeType(form: INTEGER; size: LONGINT): Type;
VAR t: Type;
BEGIN
  NEW(t);
  t.form := form;
  t.size := size
RETURN t END MakeType;

PROCEDURE Enter(name: ARRAY OF CHAR; class: INTEGER;
  type: Type; paramCount, value: INTEGER);
VAR obj: Object;
BEGIN
  NEW(obj);
  Strings.Copy(name, obj.name);
  obj.class := class;
  obj.type := type;
  (*obj.paramCount := paramCount; FIXME*)
  obj.value := value;
  obj.dsc := NIL;
  IF class = Typ THEN
    type.typeObj := obj
  END;
  (* Prepend obj to the list pointed to by system *)
  obj.next := system;
  system := obj
END Enter;

BEGIN
  byteType := MakeType(Int,    1);
  boolType := MakeType(Bool,   1);
  charType := MakeType(Char,   1);
  intType  := MakeType(Int,    4);
  realType := MakeType(Real,   4);
  setType  := MakeType(Set,    4);
  nilType  := MakeType(NilTyp, 4);
  noType   := MakeType(NoTyp,  4);
  strType  := MakeType(String, 8);

  system := NIL;

  (* Standard functions *)
  Enter('UML',     SFunc, intType,  2, umlFunc);
  Enter('ROR',     SFunc, intType,  2, rorFunc);
  Enter('ASR',     SFunc, intType,  2, asrFunc);
  Enter('LSL',     SFunc, intType,  2, lslFunc);
  Enter('LEN',     SFunc, intType,  1, lenFunc);
  Enter('CHR',     SFunc, charType, 1, chrFunc);
  Enter('ORD',     SFunc, intType,  1, ordFunc);
  Enter('FLT',     SFunc, realType, 1, fltFunc);
  Enter('FLOOR',   SFunc, intType,  1, floorFunc);
  Enter('ODD',     SFunc, boolType, 1, oddFunc);
  Enter('ABS',     SFunc, intType,  1, absFunc);

  (* Standard procedures *)
  Enter('UNPK',    SProc, noType,   2, unpkProc);
  Enter('PACK',    SProc, noType,   2, packProc);
  Enter('NEW',     SProc, noType,   1, newProc);
  Enter('ASSERT',  SProc, noType,   1, assertProc);
  Enter('EXCL',    SProc, noType,   2, exclProc);
  Enter('INCL',    SProc, noType,   2, inclProc);
  Enter('DEC',     SProc, noType,   1, decProc);
  Enter('INC',     SProc, noType,   1, incProc);

  (* Types *)
  Enter('SET',     Typ,   setType,  0, 0);
  Enter('BOOLEAN', Typ,   boolType, 0, 0);
  Enter('BYTE',    Typ,   byteType, 0, 0);
  Enter('CHAR',    Typ,   charType, 0, 0);
  Enter('LONGREAL',Typ,   realType, 0, 0); (* Alias to REAL *)
  Enter('REAL',    Typ,   realType, 0, 0);
  Enter('LONGINT', Typ,   intType,  0, 0); (* Alias to INTEGER *)
  Enter('INTEGER', Typ,   intType,  0, 0);

  topScope := NIL;
  OpenScope;
  topScope.next := system;
  universe := topScope;
  system := NIL;

  (* Unsafe pseudo-module SYSTEM *)
  (* Functions *)
  Enter('SIZE', SFunc, intType,  1, sizeFunc);
  Enter('ADR',  SFunc, intType,  1, adrFunc);
  Enter('VAL',  SFunc, intType,  2, valFunc);
  Enter('REG',  SFunc, intType,  1, regFunc);
  Enter('BIT',  SFunc, boolType, 1, bitFunc);
  (* Procedures *)
  Enter('COPY',   SProc, noType, 2, copyProc);
  Enter('PUT',    SProc, noType, 2, putProc);
  Enter('GET',    SProc, noType, 2, getProc);
  Enter('PUTREG', SProc, noType, 2, putregProc)
END Table.
