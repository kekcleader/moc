SRC=Moc.Mod
BIN=moc

all: $(BIN)

$(BIN): *.Mod
	@fob -o $(BIN) $(SRC)

run: $(BIN)
	@./$(BIN) -o HelloMod TT

.PHONY: all clean
clean:
	@rm -rf _Build $(BIN) >/dev/null 2>&1
