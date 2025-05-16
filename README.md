# Oberon compiler for macOS (Apple Silicon, ARM64)

![MOC – Mac Oberon Compiler](moc.jpg)

Oberon is a general-purpose programming language–the direct descendant of Pascal and Modula-2. It is both simpler and much more powerful than Pascal and Modula.

Moc is a compiler for the language Oberon to macOS/ARM64 (Apple Silicon M1-M4 processors).

## Setup

To compile this project, you will need to install [Free Oberon compiler](https://free.oberon.org/en).

Don't forget to add the path to the `fob` executable (the root directory of Free Oberon) to environment variable PATH.

To do that, edit `~/.zprofile` and add this:
```
export PATH=/Users/user/FreeOberon:$PATH
```
(or another directory)

Then open this project in VS Code and hit `[cmd+R]`.
