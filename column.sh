#!/bin/ksh
#
# Copyright (c) 2010
#       Jeremie Le Hen <jeremie@le-hen.org> with ideas shamelessly
#	stolen to Franck Jouvanceau <franck.jouvanceau@socgen.com>
#	who shamelessly stole ideas in my original script.
#	I hereby declare that I owe him a bigger beer than the one
#	he owes me.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY Jeremie Le Hen AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL Bill Paul OR THE VOICES IN HIS HEAD
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
#
# TODO:	Add an option for the max number of column to align
#	Add an option to set the number of column
#	Allow to aggregate multiple consecutive columns

	usage() {
	cat >&2 << EOF
Pretty-print columns, for iostat, vmstat and others.
OS: All.

Usage:
  ${0##*/} [options] [file ...]

Options:
 -A <adjustment per column>
	List of	alignment ('-'/'+') per column (colon separated).
 -a <default adjustment>
	Change default adjustment ('-' left (default), '+' right).
 -F <field separator>
	Change field separator.
 -h	Show this help.
 -k <keyword pattern>
	Keyword used to identify the header line.  This may be an
	awk/nawk regex.
 -l	Live mode: print and adjust lines as they come.
 -m <min width>
	Minimum column width.
 -M <max width>
	Maximum column width.
 -n	Prefix each value with the column index.
 -O	Append a final field separator at the end of the line.
 -o <output field separator>
	Change output field separator.
 -p	Prefix each value with its header.  This is useful for
	"iostat -x" with an awful lot of disks.
 -r	Repeat header line whenever a column width changes
	(with -l and without -p only).
 -s <skip pattern>
	Skip lines matching this regular expression.
 -u <alignment of unexpected lines>
	noalign:    just print the line as is
	align-1:    align up to the last but one expected number of columns
	align:      align up to the expected number of columns (default)
	alignall:   align all no matter of the expected number of columns
 -w <min width per column>
	List on minimum width per column (colon separated).
 -W <max width per column>
	List on minimum width per column (colon separated).
EOF
	exit $1
}

percoladjust=
defadjust="-"
fs=
keyword=
live=0
defminwidth=0
defmaxwidth=0
prefixnum=0
finalofs=0
ofs=
prefix=0
repeat=0
skip=
unexpected="align"
percolminwidth=
perlmaxwidth=
while getopts 'A:a:F:hk:lm:M:nOo:prs:u:w:W:' opt; do
	case "$opt" in
	A) percoladjust="$OPTARG" ;;
	a) defadjust="$OPTARG" ;;
	F) fs="$OPTARG" ;;
	h) usage 0 ;;
	k) keyword="$OPTARG" ;;
	l) live=1 ;;
	m) defminwidth="$OPTARG" ;;
	M) defmaxwidth="$OPTARG" ;;
	n) prefixnum=1 ;;
	O) finalofs=1 ;;
	o) ofs="$OPTARG" ;;
	p) prefix=1 ;;
	r) repeat=1 ;;
	s) skip="$OPTARG" ;;
	u) unexpected="$OPTARG" ;;
	w) percolminwidth="$OPTARG" ;;
	W) percolmaxwidth="$OPTARG" ;;
	*) usage 1 ;;
	esac
done
shift $(($OPTIND - 1))

case "$unexpected" in
noalign)    unexpected=0 ;;
align-1)    unexpected=1 ;;
align)      unexpected=2 ;;
alignall)   unexpected=3 ;;
alignall+1) unexpected=4 ;;
*) echo "ERROR: Bad value for -u: $unexpected" >&2; usage 1 ;;
esac

if [ $live -eq 0 -a $repeat -eq 1 ]; then
	echo "WARNING: -r is meaningless without -l." >&2
fi
if [ $prefix -eq 1 -a $repeat -eq 1 ]; then
	echo "WARNING: -r is meaningless with -p." >&2
fi

case `uname -s` in
SunOS) AWK=nawk ;;
Linux|*BSD) AWK=awk ;;
esac

exec $AWK ${fs:+-v} ${fs:+FS="$fs"} ${ofs:+-v} ${ofs:+OFS="$ofs"} '
BEGIN {
	PERCOLADJUST = "'"$percoladjust"'";
	DEFADJUST = "'"$defadjust"'";
	KEYWORD = "'"$keyword"'";
	LIVE = '$live';
	DEFMINWIDTH = '"$defminwidth"';
	DEFMAXWIDTH = '"$defmaxwidth"';
	PREFIXNUM = '$prefixnum';
	FINALOFS = '$finalofs';
	PREFIX = '$prefix';
	REPEAT = '$repeat';
	SKIP = "'"$skip"'";
	UNEXPECTED = '$unexpected';
	PERCOLMINWIDTH = "'"$percolminwidth"'";
	PERCOLMAXWIDTH = "'"$percolmaxwidth"'";
	# 1 => print if REPEAT.
	PRINTHEADER = 0;
	# When live, delay the printing of the header because often the
	# first line of data is larger than the header.
	FIRSTHEADER = 1;
	NCOL = 0;
	NLINES = 0;
	GO = 0;
	gsub(",", ":", PERCOLADJUST);
	gsub(",", ":", PERCOLMINWIDTH);
	gsub(",", ":", PERCOLMAXWIDTH);
	split(PERCOLADJUST, ADJUST, ":");
	split(PERCOLMINWIDTH, MINWIDTH, ":");
	split(PERCOLMAXWIDTH, MAXWIDTH, ":");
	for (i in MINWIDTH)
		if (MINWIDTH[i] == "")
			MINWIDTH[i] = 0;
	for (i in MAXWIDTH)
		if (MAXWIDTH[i] == "")
			MAXWIDTH[i] = 0;
}

function adjust(i, a)
{
	a = ADJUST[i];
	return a == "" ? DEFADJUST : a;
}

function width(i, max)
{

	if (i > max) return 0;
	return WIDTH[i];
}

function set_width(i, w)
{
	if (MINWIDTH[i] != 0 && w < MINWIDTH[i])
		WIDTH[i] = MINWIDTH[i];
	else if (w < DEFMINWIDTH)
		WIDTH[i] = DEFMINWIDTH;
	else if (MAXWIDTH[i] != 0 && w > MAXWIDTH[i])
		WIDTH[i] = MAXWIDTH[i];
	else if (DEFMAXWIDTH != 0 && w > DEFMAXWIDTH)
		WIDTH[i] = DEFMAXWIDTH;
	else
		WIDTH[i] = w;
}

function printheader(i)
{
	for (i = 1; i <= NCOL; i++) {
		if (PREFIXNUM) printf("%d:", i);
		printf("%"adjust(i)"*s", WIDTH[i], HEADER[i]);
		if (i < NCOL) printf("%s", OFS);
	}
	if (FINALOFS) printf("%s", OFS);
	printf("\n");
}

SKIP != "" && match($0, SKIP) { next; }

# First header line.
!GO && (KEYWORD == "" || match($0, KEYWORD)) {
	split($0, HEADER);
	a = 0;
	for (i = 1; i <= NF; i++) {
		# Do not consider header line when prefix will be prepended.
		if (PREFIX) {
			WIDTH[i] = 1;
			continue;
		}
		w = length($i);
		set_width(i, w);
	}
	NCOL = NF;
	PRINTHEADER = 1;
	GO = 1;
	if (!LIVE) { LINES[++NLINES] = $0 }
	#printf("DEBUG: NCOL %d\n", NCOL);
	next;
}

# Keyword not found yet.
!GO {
	if (LIVE) {
		print;
	} else {
		LINES[++NLINES] = $0;
	}
	next;
}

# Following header lines.
KEYWORD != "" && match($0, KEYWORD) {
	if (PREFIX) { next }
	if (LIVE) {
		printheader();
	} else {
		LINES[++NLINES] = $0;
	}
	next;
}

NF == NCOL || UNEXPECTED > 0 {
	#printf("DEBUG: This line will be aligned (%d fields)\n", NF);
	# Recompute field width.
	for (i = 1; i <= NF; i++) {
		w = length($i);
		if (w > WIDTH[i]) {
			#printf("#DEBUG: field %d: raised from %d to %d\n", i, WIDTH[i], w);
			set_width(i, w);
		}
	}

	if (!LIVE) {
		LINES[++NLINES] = $0;
		next;
	}

	# XXX: Reprint header only when NF == NCOL or not?
	if (FIRSTHEADER || (PRINTHEADER > 0 && REPEAT)) {
		FIRSTHEADER = 0;
		if (!PREFIX) { printheader() }
		PRINTHEADER = 0;
	}

	if (UNEXPECTED == 0) { max = NF }
	else if (UNEXPECTED == 1) { max = (NF < NCOL - 1) ? NF : NCOL - 1 }
	else if (UNEXPECTED == 2) { max = (NF < NCOL) ? NF : NCOL }
	else if (UNEXPECTED == 3) { max = NF }

	for (i = 1; i <= NF; i++) {
		h = HEADER[i];
		if (PREFIXNUM) printf("%d:", i);
		if (PREFIX) printf("%s:", h == "" ? "?" : h);
		printf("%"adjust(i)"*s", width(i, max), $i);
		# Print specified OFS until <max> columns, then print
		# spaces until the end.
		if (i < max || (UNEXPECTED == 1 && i == max))
			printf("%s", OFS)
		else if (i < NF)
			printf(" ");
	}
	if (FINALOFS) printf("%s", OFS);
	printf("\n");
	next;
}

# NF != NCOL && UNEXPECTED == 0
{
	if (LIVE) {
		print;
	} else {
		LINES[++NLINES] = $0;
	}
	next;
}

END {
	if (LIVE) { exit }
	for (lnum = 1; lnum <= NLINES; lnum++) {
		line = LINES[lnum];
		if (PREFIX && KEYWORD != "" && match(line, KEYWORD))
			continue;
		NF = split(line, fields);
		if (UNEXPECTED == 0 && NF != NCOL) {
			print line;
			continue;
		}

		if (UNEXPECTED == 0) { max = NF }
		else if (UNEXPECTED == 1) { max = (NF < NCOL - 1) ? NF : NCOL - 1 }
		else if (UNEXPECTED == 2) { max = (NF < NCOL) ? NF : NCOL }
		else if (UNEXPECTED == 3) { max = NF }

		for (i = 1; i <= NF; i++) {
			h = HEADER[i];
			if (PREFIXNUM) printf("%d:", i);
			if (PREFIX) printf("%s:", h == "" ? "?" : h);
			printf("%"adjust(i)"*s", width(i, max), fields[i]);
			# Print specified OFS until <max> columns, then print
			# spaces until the end.
			if (i < max || (UNEXPECTED == 1 && i == max))
				printf("%s", OFS)
			else if (i < NF)
				printf(" ");
		}
		if (FINALOFS) printf("%s", OFS);
		printf("\n");
	}
}
' "$@"
