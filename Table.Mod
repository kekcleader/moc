MODULE Table;
IMPORT Out, Strings, Machine, Errors := MocErrors, Scanner;

CONST
  (** Object.class values **)
  Head* = 0; Const* = 1; Var*   = 2; VarPar* = 3; Field* = 4;
  Typ*  = 5; SProc* = 6; SFunc* = 7; Mod*    = 8;

  (** Type.form values **)
  Byte*   =  1; Bool*    =  2; Char*    =  3; Int*    = 4; Real* =  5;
  Set*    =  6; Pointer* =  7; NilType* =  8; NoType* = 9; Proc* = 10;
  String* = 11; Array*   = 12; Record*  = 13;

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
  Module* = POINTER TO ModuleDesc;

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
    dsc*: Object; (** Descendant object *)
    type*: Type;
    value*: INTEGER;
    constVal*: ConstVal;
    next*: Object
  END;

  ModuleDesc* = RECORD(ObjectDesc)
    originalName*: Ident (** Original name of the module; name is alias *)
  END;

VAR topScope*, universe, system*: Object;
  byteType*, boolType*, charType*, intType*, realType*: Type;
  setType*, nilType*, noType*, strType*: Type;

PROCEDURE DD(n: INTEGER);
BEGIN
  Out.Char(1BX); Out.String('[41m');
  Out.Char(1BX); Out.String('[30m');
  Out.String(' ========================> DEBUG ===> ');
  Out.Char(1BX); Out.String('[97m');
  Out.Int(n, 0); Out.Char(' ');
  Out.Char(1BX); Out.String('[0m'); Out.Ln
END DD;

PROCEDURE NewConst*(): ConstVal;
VAR c: ConstVal;
BEGIN
  NEW(c)
RETURN c END NewConst;

PROCEDURE NewType(form, size: INTEGER): Type;
VAR t: Type;
BEGIN
  NEW(t);
  t.form := form;
  t.size := size
RETURN t END NewType;

PROCEDURE NewObject*(name: Ident; class: INTEGER): Object;
VAR obj, x: Object;
BEGIN
  x := topScope;
  WHILE (x.next # NIL) & (x.next.name # name) DO x := x.next END;
  IF x.next = NIL THEN
    NEW(obj);
    Strings.Copy(name, obj.name);
    obj.class := class;
    obj.value := 0;
    x.next := obj
  ELSE
    obj := x.next;
    Machine.Error(Errors.multipleDefs)
  END 
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
  topScope := universe;
  OpenScope
END Init;

(** Finds the object and returns it. *)
PROCEDURE ThisObject*(name: Ident): Object;
VAR scope, obj: Object;
BEGIN
  scope := topScope;
  REPEAT
    obj := scope.next;
    WHILE (obj # NIL) & (obj.name # name) DO obj := obj.next END;
    scope := scope.dsc
  UNTIL (obj # NIL) OR (scope = NIL)
RETURN obj END ThisObject;

(** Finds the object and returns it. *)
PROCEDURE ThisImport*(module: Object; name: Ident): Object;
VAR obj: Object;
BEGIN
  IF module.name # '' THEN
    obj := module.dsc;
    WHILE (obj # NIL) & (obj.name # name) DO obj := obj.next END
  END
RETURN obj END ThisImport;

(** Finds or adds module and returns it. *)
PROCEDURE ThisModule*(alias, name: Ident; declareNew: BOOLEAN): Object;
VAR module: Module;
  obj, prevObj: Object;
BEGIN
  (* Find module by name *)
  prevObj := topScope;
  obj := topScope.next;
  WHILE (obj # NIL) & (obj(Module).originalName # name) DO
    prevObj := obj;
    obj := obj.next
  END;
  IF obj = NIL THEN (* New module *)
    (* Make sure alias is not used *)
    obj := topScope.next;
    WHILE (obj # NIL) & (obj.name (*Alias*) # name) DO obj := obj.next END;
    IF obj = NIL THEN (* All good, adding module to symbol table *)
      NEW(module);
      module.class := Mod;
      Strings.Copy(name, module.originalName);
      Strings.Copy(alias, module.name);
      (* Add to symbol table *)
      module.next := topScope.next;
      topScope.next := module;
      obj := module
    ELSIF declareNew THEN (* Module already imported, could not declare *)
      Machine.Error(Errors.multipleImport)
    ELSE (* Module alias already used *)
      Machine.Error(Errors.aliasTaken)
    END
  ELSIF declareNew THEN (* Module already imported, could not declare *)
    Machine.Error(Errors.multipleImport)
  END
RETURN obj END ThisModule;

(** Returns a list of objects inside module with the given name.
     The supported module is Out. *)
PROCEDURE PseudoImport*(name: Scanner.Ident): Object;
VAR list, o, p: Object;
  t: Type;
BEGIN
  IF name = 'Out' THEN
    (* Out.Int *)
    NEW(o);
    list := o;
    o.class := Const;
    o.name := 'Int';
    o.value := 233; (*FIXME*)
    t := NewType(Proc, Machine.pointerSize);
    o.type := t;
    t.paramCount := 2;
    t.base := noType;
    (* Parameters *)
    NEW(p);
    t.dsc := p;
    p.class := Var;
    p.name := 'i';
    p.type := intType;
    p.value := 0; (* FIXME? *)
    NEW(p.next);
    p := p.next;
    p.class := Var;
    p.name := 'n';
    p.type := intType;
    p.value := 0; (* FIXME? *)

    (* Out.Ln *)
    NEW(o.next);
    o := o.next;
    o.class := Const;
    o.name := 'Ln';
    o.value := 234; (*FIXME*)
    t := NewType(Proc, Machine.pointerSize);
    o.type := t;
    t.paramCount := 0;
    t.base := noType
  END
RETURN list END PseudoImport;

PROCEDURE Import*(alias, name, selfName: Scanner.Ident);
VAR obj, objects, module: Object;
BEGIN
  Out.String('importing '); Out.String(name);
  Out.String(' as '); Out.String(alias);
  Out.String(' to '); Out.String(selfName);
  Out.Ln;
  IF name = 'SYSTEM' THEN
    module := ThisModule(alias, name, TRUE);
    module.dsc := system
  ELSE
    objects := PseudoImport(name);
    IF objects = NIL THEN
      Machine.Error(Errors.notImplemented)
    ELSE
      module := ThisModule(alias, name, TRUE);
      module.dsc := objects
    END
  END;
  obj := topScope.next
END Import;

(** Outputs 2n spaces. *)
PROCEDURE Indent(n: INTEGER);
BEGIN
  WHILE n # 0 DO
    Out.String('  ');
    DEC(n)
  END
END Indent;

PROCEDURE PrintConstVal*(const: ConstVal; type: Type);
VAR f: INTEGER;
BEGIN
  IF const # NIL THEN
    IF type = NIL THEN
      Out.String('NO TYPE')
    ELSE
      f := type.form;
      IF (f = Byte) OR (f = Bool) OR (f = Char) OR (f = Int) THEN
        Out.Int(const.intVal, 0)
      ELSIF f = Real THEN
        Out.Real(const.realVal, 0)
      END
    END
  END
END PrintConstVal;

PROCEDURE PrintType*(type: Type);
BEGIN
  IF type # NIL THEN
    IF    type.form = Byte    THEN Out.String('Byte')
    ELSIF type.form = Bool    THEN Out.String('Bool')
    ELSIF type.form = Char    THEN Out.String('Char')
    ELSIF type.form = Int     THEN Out.String('Int')
    ELSIF type.form = Real    THEN Out.String('Real')
    ELSIF type.form = Set     THEN Out.String('Set')
    ELSIF type.form = Pointer THEN Out.String('Pointer')
    ELSIF type.form = NilType  THEN Out.String('NilType')
    ELSIF type.form = NoType   THEN Out.String('NoType')
    ELSIF type.form = Proc    THEN Out.String('Proc')
    ELSIF type.form = String  THEN Out.String('String')
    ELSIF type.form = Array   THEN Out.String('Array')
    ELSIF type.form = Record  THEN Out.String('Record')
    ELSE Out.String('UNKNOWN')
    END
  END
END PrintType;

PROCEDURE PrintObject*(object: Object; indent: INTEGER);
BEGIN
  Indent(indent);
  Out.Char("'"); Out.String(object.name); Out.String("' ");
  IF object.class = Const THEN
    Out.String('Const ');
    PrintConstVal(object.constVal, object.type)
  ELSIF object.class = Var THEN
    Out.String('Var')
  ELSIF object.class = VarPar THEN
    Out.String('VarPar')
  ELSIF object.class = Typ THEN
    Out.String('Typ')
  ELSIF object.class = SProc THEN
    Out.String('SProc')
  ELSIF object.class = SFunc THEN
    Out.String('SFunc')
  ELSIF object.class = Mod THEN
    Out.String('Mod')
  ELSE
    Out.String('class #'); Out.Int(object.class, 0)
  END;
  IF object.type # NIL THEN
    Out.Char(' ');
    PrintType(object.type)
  END
END PrintObject;

PROCEDURE Print*(scope: Object; indent: INTEGER);
VAR obj: Object;
BEGIN
  WHILE scope # NIL DO
    Out.String('~ Scope ~'); Out.Ln;
    obj := scope.next;
    WHILE obj # NIL DO
      PrintObject(obj, indent + 1); Out.Ln;
      obj := obj.next
    END;
    scope := scope.dsc
  END
END Print;

(** Creates a new object and places it in the beginning of the system list. *)
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
  byteType := NewType(Int,     1);
  boolType := NewType(Bool,    1);
  charType := NewType(Char,    1);
  intType  := NewType(Int,     4);
  realType := NewType(Real,    4);
  setType  := NewType(Set,     4);
  nilType  := NewType(NilType, 4);
  noType   := NewType(NoType,  4);
  strType  := NewType(String,  8);

  (* Initialize Universe objects *)
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

  OpenScope;
  topScope.next := system;
  universe := topScope;
  system := NIL;

  (* Initialize unsafe pseudo-module SYSTEM objects *)
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
