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
	If the first character is "=", only the pattern will be highlighed.
	If no color is specified at all, then enbolden the line.
Color examples:
EOF
	exit $1
}

_esc="[";
_fg=3; _bg=4;
_esc256="8;5;";
_m="m";
_black=0;  _lblack=8;
_red=1;    _lred=9;
_green=2;  _lgreen=10;
_yellow=3; _lyellow=11;
_blue=4;   _lblue=12;
_magenta=5;_lmagenta=13;
_cyan=6;   _lcyan=14;
_white=7;  _lwhite=15;
_RESET="${_esc}0m";
_BOLD="${_esc}1m";

getcolor() {
	local color="$1"
	local fb="$2"

	case "$color" in
	*[abcdefghijklmnopqrstuvxyz]*) eval color=\"\$_$color\" ;;
	esac
	case "$color" in
	'') return ;;
	esac
	eval fb=\"\$_$fb\"
	echo "$_esc$fb$_esc256$color$_m"
}

[ $# -eq 0 -o "x$1" = "x-h" ] && usage 0

sedscript=""
while [ $# -gt 0 ]; do
	pattern="$1"
	color="$2"
	shift
	[ $# -gt 0 ] && shift

	case "$color" in
	'='*) w=; color=${color#=} ;;
	*) w=".*" ;;
	esac
	case "$color" in
	'B'*) bold="$_BOLD"; color=${color#B} ;;
	*) bold= ;;
	esac

	case "$color" in
	*:*)
		fg=$(getcolor "${color%:}" fg)
		bg=$(getcolor "${color#*:}" bg)
		;;
	*)
		fg=$(getcolor "${color}" fg)
		bg=
		;;
	esac
	[ "x$fg$bg" = "x" ] && bold="$_BOLD"


	sedscript="$sedscript
s/\\($w$pattern$w\\)/$bold$fg$bg\\1$_RESET/"
		
done

sed "$sedscript"
