# A simple Makefile to (un)install mstdn.

NAME=instatweet

PREFIX?=/usr/local

all:
	@echo "Available targets:"
	@echo " clean      remove temporary files"
	@echo " install    install ${NAME} under ${PREFIX}"
	@echo " uninstall  remove ${NAME} from ${PREFIX}"
	@echo " prep       update the perl path in the source script"
	@echo " readme     generate the README after a manual page update"

prep: src/${NAME}

src/${NAME}: src/${NAME}.pl
	sed -e "s|/usr/local/bin/perl|$$(which perl)|" $? >$@

install: src/${NAME}
	mkdir -p ${PREFIX}/bin
	mkdir -p ${PREFIX}/share/man/man1
	install -c -m 755 src/${NAME} ${PREFIX}/bin/${NAME}
	install -c -m 444 doc/${NAME}.1 ${PREFIX}/share/man/man1/${NAME}.1

uninstall:
	rm -f ${PREFIX}/bin/${NAME} ${PREFIX}/share/man/man1/${NAME}.1

man: doc/${NAME}.1.txt

doc/${NAME}.1.txt: doc/${NAME}.1
	mandoc -c -O width=80 $? | col -b >$@

readme: man
	sed -n -e '/^NAME/!p;//q' README.md >.readme
	sed -n -e '/^NAME/,$$p' -e '/emailing/q' doc/${NAME}.1.txt >>.readme
	echo '```' >>.readme
	mv .readme README.md

clean:
	rm -f src/${NAME}

