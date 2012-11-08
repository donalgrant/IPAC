#!/usr/bin/perl -w -I/Users/imel/Desktop/Dropbox/dev/lib

use Data::Dumper;
use IPAC::AsciiTable;

my $I=new IPAC::AsciiTable('test.tbl');

my $r=$I->n_data_rows();
my $c=$I->n_cols();

for (0..$c-1) { print "Column $_:  ",$I->col_name($_),"\n"; print join(';',$I->col($I->col_name($_))),"\n" }

print "Number of rows = $r\n";
print "Number of cols = $c\n";

print "First and last columns\n";
print join(';',($I->col_name(0),$I->col_name($c-1))),"\n";
for (0..$r-1) { print join(';',$I->row($_,($I->col_name(0),$I->col_name($c-1)))),"\n" }

my $t=$I->extract(map { $I->col_name(2*$_) } (0..int($c-1)/2) );  # table with every other column

print Dumper($t),"\n";
