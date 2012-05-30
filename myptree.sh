#!/bin/ksh
#
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <jeremie@le-hen.org> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.
# -- Jeremie Le Hen, 2010
# ----------------------------------------------------------------------------

usage() {
	cat >&2 <<EOF
Home-rolled Solaris-like ptree(1) implementation.
OS: All.

Usage: ${0##*/} [options] [pid ...]

Options add additional fields in the output. THE ORDER IS SIGNIFICANT.
Options:
  -g		Add group
  -G		Add pgid
  -m		Add rss and vsz
  -p		Add ppid
  -s		Add state
  -t		Add start time and elapsed time
  -u		Add user
  -x keyword	Add a 'keyword' to format
EOF
	exit 0
}

case $(uname -s) in
Linux)
	myps() { ps -e -o pid,ppid${1},args; }
	AWK=awk
	_g=group; _G=pgid; _m=rss,vsz; _p=ppid;
	_s=s; _t=start,etime; _u=user
	;;
*BSD)
	myps() { ps -axo pid,ppid${1},args; }
	AWK=awk
	_g=group; _G=pgid; _m=rss,vsz; _p=ppid;
	_s=state; _t=start,etime; _u=user
	;;
SunOS)
	myps() { ps -e -o pid,ppid${1},args; }
	AWK=nawk
	_g=group; _G=pgid; _m=rss,vsz; _p=ppid;
	_s=s; _t=stime,etime; _u=user
	;;
esac

f=
nf=0
while getopts 'gGhmpstux:' opt; do
	case $opt in
	h) usage ;;
	g) f="$f,$_g", nf=$(($nf + 1)) ;;
	G) f="$f,$_G", nf=$(($nf + 1)) ;;
	m) f="$f,$_m"; nf=$(($nf + 2)) ;;
	p) f="$f,$_p"; nf=$(($nf + 1)) ;;
	s) f="$f,$_s"; nf=$(($nf + 1)) ;;
	t) f="$f,$_t"; nf=$(($nf + 2)) ;;
	u) f="$f,$_u"; nf=$(($nf + 1)) ;;
	x) f="$f,$OPTARG"; nf=$(($nf + 1)) ;;
	esac
done
shift $(($OPTIND - 1))

echo pid,${f},args | tr '[a-z],' '[A-Z] '

myps $f | $AWK -v PIDLIST="$*" -v OPTNF=$nf '
function show_children(pid, indent, i, pidtable)
	# pidtable and i are local variable, not args
{
	#print "DEBUG: show_children("pid")"
	if (!INFO[pid])
		return;
	if (DONE[pid])
		return;
	
	OUTPUT = OUTPUT""indent""INFO[pid]"\n";
	DONE[pid] = 1;

	split(CHILDREN[pid], pidtable);
	for (i in pidtable)
		show_children(pidtable[i], indent"  ");
}

function show_father(pid, indent, bool)
	# bool is used to not output the pid in show_father(),
	# or it will be skipped in the following show_children().
{
	#print "DEBUG: show_father("pid")"
	if (FATHER[pid] && pid != 1)
		indent = show_father(FATHER[pid], indent, 1);

	if (DONE[pid])
		return indent;

	if (bool) {
		OUTPUT = OUTPUT""indent""INFO[pid]"\n";
		DONE[pid] = 1;
		indent = indent"  ";
	}
	return indent;
}
{
	pid = $1;
	ppid = $2;
	CHILDREN[ppid] = pid" "CHILDREN[ppid];
	FATHER[pid] = ppid;
	$1 = $2 = "";
	args = "";
	# Set two spaces between fields, but the command and args.
	for (i = 3; i < OPTNF + 3; i++) {
		args = args"  "$i;
		$i = "";
	}
	sub("^ *", "");
	INFO[pid] = pid""args"  "$0;
}
END {
	#for (pid in CHILDREN) {
	#	print "DEBUG: children for "pid": "CHILDREN[pid]
	#}
	n = split(PIDLIST, pidtable);
	if (n == 0)
		show_children(1, "");
	else {
		for (i = 1; i <= n; i++) {
			#printf("DEBUG: pid %d\n", pidtable[i]);
			OUTPUT = "";
			indent = "";
			for (pid in DONE)
				delete DONE[pid];
			indent = show_father(pidtable[i], indent, 0);
			show_children(pidtable[n], indent);
		}
	}
	printf("%s", OUTPUT);
}'
