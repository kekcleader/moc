    ELSIF IsDigit() THEN
      intVal := ORD(ch) - ORD('0');
      ok := TRUE;
      Machine.Read(ch);
      WHILE IsDigit() DO
        (* Overflow check *)
        IF intVal <= (Machine.maxInt - ORD(ch) + ORD('0')) DIV 10 THEN
          intVal := intVal * 10 + ORD(ch) - ORD('0')
        ELSE
          ok := FALSE
        END;
        Machine.Read(ch)
      END;
      IF ~ok THEN
        Machine.Error(Errors.intOverflow);
        intVal := 0
      END;
      sym := int
