MODULE Emitter;
IMPORT Out, Machine, Errors := MocErrors, Table, Tree;

CONST
  (** Item.mode values **)

TYPE
  Item* = RECORD
    mode*: INTEGER; (** Object.class values + Item.mode values *)
    type*: Table.Type;
    address*, offset*, index*: INTEGER
  END;

PROCEDURE Assign*(VAR z, x: Item);
BEGIN

END Assign;

PROCEDURE Relation*(VAR x: Item);
BEGIN

END Relation;

PROCEDURE Enter*;
BEGIN
END Enter;

PROCEDURE Exit*;
BEGIN
END Exit;

END Emitter.
