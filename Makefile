SRC=Moc.Mod
BIN=moc

PARAMS=-o example Examples/Example.Mod

all: $(BIN)

$(BIN): *.Mod
	@fob -o $(BIN) $(SRC)

justrun:
	@./$(BIN) $(PARAMS)

run: all
	clear
	@./$(BIN) $(PARAMS)

.PHONY: all clean run justrun
clean:
	@rm -rf _Build $(BIN) >/dev/null 2>&1
