#!/usr/bin/perl -s
#
# usage: convert_date.pl [options] year0 {it|year month day hour min sec}
#
# possible options: -it2date -date2it
#
#-------------------------------------------------

use lib ("$ENV{HOME}/fem/femlib/perl","$ENV{HOME}/shyfem/femlib/perl");

use date;

my $date = new date;

$year0 = shift(@ARGV);
@date=@ARGV;

if( not defined $date[0] or $h or $help ) {
  print STDERR "Usage: convert_date.pl [-it2date|-date2it] year0 {it|date}\n";
  print STDERR "   date: year [month [day [hour [min [sec]]]]]\n";
  exit 1;
}

if( not $it2date and not $date2it ) {	# no option given
  if( defined $date[1] ) {		# more than one value given
    $date2it = 1;
  } else {
    $it2date = 1;
  }
}

#print "|$it2date|$date2it|\n";

$date->init_year($year0);

if( $it2date ) {
  (@res) = $date->convert_from_it(@date);
  (@res) = format_numbers(@res);
} else {
  (@res) = $date->convert_to_it(@date);
}

$line = join(" ",@res);
print "$line\n";

#--------------------------------------

sub format_numbers {

  foreach my $n (@_) {
    if( $n < 1 ) {
      $n = "00";
    } elsif( $n < 10) {
      $n = "0$n";
    }
  }

  return @_;
}
