#!/usr/bin/perl
# 2010/03/16 Jeremie LE HEN <jeremie.le-hen-ext@socgen.com>

use strict;
use warnings;

my @a;

while (<>) { push @a, $_ }

for (my $i = 0; $i < @a; $i++) {
	my $j = int (rand (@a));
	my $tmp;

	$tmp = $a[$i];
	$a[$i] = $a[$j];
	$a[$j] = $tmp;
}

foreach (@a) { print }
