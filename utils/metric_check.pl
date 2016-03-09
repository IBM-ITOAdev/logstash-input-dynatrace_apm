#!/usr/bin/perl -w

my $file = $ARGV[0];
my @index = split(':', $ARGV[1]);
my $correct_number = $ARGV[2];

my $h = {};

open (FH, "$file") || die "Can't open $file for read ...";
while (<FH>) {
    if ($. == 1) {
	next
    }
    chomp($_);
    my @fields = split(',', $_);
    my $resourceid = "$file";
    foreach my $i (@index) {
	$resourceid = join(':', $resourceid, $fields[$i]);
    }
    $h->{$resourceid} += 1;
}
close(FH);

for (sort keys %$h) {
    my $k = $_;
    my $v = $h->{$_};
    if ($v < $correct_number) {
	print "$k : $v\n";
    }
}
