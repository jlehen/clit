#!/bin/sh
# 2010/08/02 Jeremie LE HEN <jeremie@le-hen.org>

usage() {
	cat <<EOF >&2
Reads stdin and output each line concatenated with a separator between them.
Default separator is "|".
OS: All.

Usage: ${0##*/} [-a n] [-lp] [separator]
Options:
  -A     Issue an awk expression to not match field n.
  -a     Issue an awk expression to match field n.
  -l     Match full line only.
  -p     Put parentheses around.
  -q     Surround each value with simple quotes.
  -Q     Surround each value with double quotes.
Examples:
	sudo syminq -wwn | egrep \$(cat /tmp/luns_id | or -a 2)
EOF
	exit ${1:-0}
}

case $(uname -s) in
Linux|*BSD) AWK=awk ;;
SunOS) AWK=nawk ;;
esac

do_awk=0
awk_field=0
line=0
paren=0
quote=
while getopts 'A:a:hlpqQ' opt; do
	case $opt in
	A) do_awk=-1; awk_field="$OPTARG" ;;
	a) do_awk=1; awk_field="$OPTARG" ;;
	h) usage ;;
	l) line=1; paren=1 ;;
	p) paren=1 ;;
	q) quote=\"\'\" ;;
	Q) quote=\"\\\"\" ;;	# Can't use single quote because of awk.
	*) usage 1 ;;
	esac
done
shift $(($OPTIND - 1))

sep=${1:-|}

exec $AWK '
BEGIN {
	SEP="'"$sep"'";
	DO_AWK='$do_awk';
	AWK_FIELD="'"$awk_field"'";
	LINE='$line';
	PAREN='$paren';
	Q="'$qq$quote$qq'";
}

{
	s = sprintf("%s%s%s", s, a ? SEP : "", Q $0 Q);
	a = 1;
	line++;
}

END {
	if (line == 1) {
		nf = split(s, fields);
		s = ""
		a = 0;
		for (i = 1; i <= nf; i++) {
			s = sprintf("%s%s%s", s, a ? SEP : "", fields[i]);
			a = 1;
		}
	}
	if (PAREN)
		s = "(" s ")";
	if (LINE)
		s = "^" s "$";
	if (DO_AWK == 1)
		s = sprintf("$%i ~ /%s/", AWK_FIELD, s);
	else if (DO_AWK == -1)
		s = sprintf("$%i !~ /%s/", AWK_FIELD, s);
	print s;
}'
