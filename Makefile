all: background-backup

background-backup: bb.ml
	ocamlbuild -use-ocamlfind bb.native

install: background-backup
	cp _build/bb.native /usr/local/bin/background-backup
	cp background-backup.service /usr/lib/systemd/system/

uninstall:
	rm -f /usr/local/bin/background-backup
	rm -f /usr/lib/systemd/system/background-backup.service

clean:
	ocamlbuild -clean
