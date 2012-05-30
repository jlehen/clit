#!/bin/ksh

usage() {
	cat >&2 << EOF
Highlight lines matching patterns.
OS: All.

Usage: ${0##*/} <pattern> [ [color] [pattern [ [color] [...] ] ] ]
Patterns:
	Awk regex (don't forget to escape '/').
Colors:
	black red green yellow blue magenta cyan white
	lblack lred lgreen lyellow lblue lmagenta lcyan lwhite
	Format can be either <fg>:<bg> or just <fg>; use bold if <fg> is
	prefixed with "B".
	If no color is specified at all, then enbolden the line.
EOF
	exit $1
}

case $(uname -s) in
SunOS)
	AWK=nawk
	;;
*)
	AWK=awk
	;;
esac

[ $# -eq 0 -o "x$1" = "x-h" ] && usage 0

awkscript=""
while [ $# -gt 0 ]; do
	pattern="$1"
	color="$2"
	shift
	[ $# -gt 0 ] && shift

	case "$color" in
	'B'*) bold=1; color=${color#B} ;;
	esac

	case "$color" in
	*:*) fg=${color%:*}; bg=${color#*:} ;;
	*) fg=$color; bg= ;;
	esac
	[ "x$fg$bg" = "x" ] && bold=1

	awkscript="$awkscript
/$pattern/ {"

	[ -n "$bold" ] && awkscript="$awkscript
	bold();"

	[ -n "$fg" ] && awkscript="$awkscript
	setcolor(\"$fg\", \"fg\");"

	[ -n "$bg" ] && awkscript="$awkscript
	setcolor(\"$bg\", \"bg\");"

	awkscript="$awkscript
	print \$0;
	reset();"

	awkscript="$awkscript
	next;
}
"
done

exec $AWK '
BEGIN {
	_esc="[";
	_fb["fg"]=3; _fb["bg"]=4
	_esc256="8;5;";
	_m="m";
	_c["black"]=0;  _c["lblack"]=8;
	_c["red"]=1;    _c["lred"]=9;
	_c["green"]=2;  _c["lgreen"]=10;
	_c["yellow"]=3; _c["lyellow"]=11;
	_c["blue"]=4;   _c["lblue"]=12;
	_c["magenta"]=5;_c["lmagenta"]=13;
	_c["cyan"]=6;   _c["lcyan"]=14;
	_c["white"]=7;  _c["lwhite"]=15;
	_RESET=_esc"0m";
	_BOLD=_esc"1m";
}

function setcolor(color, fb) {
	if (color ~ /[a-z]/)
		color  = _c[color];
	if (color == "")
		return;
	printf("%s", _esc _fb[fb] _esc256 color _m);
}

function reset() {
	printf("%s", _RESET);
}

function bold() {
	printf("%s", _BOLD);
}
'"$awkscript"'
{
	print $0;
}
'
