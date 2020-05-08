#!/usr/bin/perl -ws

#------------------------------------------------------------------------
#
#    Copyright (C) 1985-2018  Georg Umgiesser
#
#    This file is part of SHYFEM.
#
#------------------------------------------------------------------------

# header
#   header0		empty if no copy, everything in headermain
#   copy		empty lines before and after not counted
#   headermain		everything else
# headermain
#   header1		everything if no revision log
#   rev			start with "revision log :", not excluding this line
#   header2		start with no date line after rev, emtpy if no rev
# body

use lib ("$ENV{SHYFEMDIR}/femcheck/copyright"
		,"$ENV{HOME}/shyfem/femcheck/copyright");

use strict;
use revision_log;

$::file = $ARGV[0];

$::warn = 0;			#warn for revision out of revision log section
$::obsolete = 0;		#check for obsolete date in text

$::extract = 0 unless $::extract;	#extract revlog to revlog.tmp
$::check = 0 unless $::check;		#checks files
$::gitrev = 0 unless $::gitrev;		#uses gitrev for revision log
$::stats = 0 unless $::stats;		#uses gitrev for revision log
$::crewrite = 0 unless $::crewrite;	#re-writes c revision log
$::copy = 0 unless $::copy;		#re-writes copyright section
$::substdev = 0 unless $::substdev;	#substitute developer names

$::copyright = 0;
$::shyfem = 0;
$::manual = 0;
$::cstyle_revlog = 0;

$::debug = 0;

make_dev_names();
make_month_dates();

#print STDERR "reading file $::file\n";

#--------------------------------------------------------------

$::type = find_file_type($::file);
$::comchar = get_comment_char($::type);
$::need_revlog = is_code_type($::type);
$::need_copy = is_code_type($::type);
$::need_copy += $::type eq "script";
$::need_copy += $::type eq "text";
$::need_copy += $::type eq "tex";

exit 0 if $::type eq "binary";
exit 0 if $::type eq "image";

my ($header,$body) = extract_header();

my ($header0,$copy,$headermain) = extract_copy($header);
my ($header1,$rev,$header2) = extract_rev($headermain);

if( $::debug ) {
  print_file($header0,$copy,$header1,$rev,$header2);	#use this for debug
}

check_rev_dates($rev);

if( $::crewrite ) {
  if( $::cstyle_revlog ) {
    $header0 = clean_c_header($header0);
    $header1 = clean_c_header($header1);
    $header2 = clean_c_header($header2);
    $rev = rewrite_c_revlog($rev)
  } elsif( @$rev ) {
    print "*** file $::file already has new revison log... not rewriting\n";
  }
}

my $devs = count_developers($rev);
if( $::copy and @$rev and not $::manual ) {
  my $nrev = @$rev;
  my $newcopy = handle_developers($rev);
  $copy = subst_copyright($copy,$newcopy);
}

if( $::substdev and @$rev and not $::manual ) {
  $rev = subst_developers($rev);
}

if( $::gitrev or $::gitmerge ) {
 if( not $::manual ) {
  my $nrev = @$rev;
  if( $nrev == 0 ) {
    $header2 = copy_divisor($header1,$copy);
  }
  if( $::gitrev and $nrev == 0 ) {
    $rev = integrate_revlog($rev);
  } elsif( $::gitmerge ) {
    $rev = integrate_revlog($rev);
  }
 }
}

if( $::stats ) {
  stats_file($::file,$rev,$devs);
} else {
  write_file("$::file.new",$header0,$copy,$header1,$rev,$header2,$body);
}

my $has_revision_log = @$rev + $::manual;

exit $has_revision_log;

#--------------------------------------------------------------
#--------------------------------------------------------------
#--------------------------------------------------------------

sub extract_header
{
  my @header = ();
  my @body = ();

  my $cc = quotemeta($::comchar);

  my $in_header = 1;

  while(<>) {

    chomp;

    if( /^\s*$/ ) {			# empty line
    } elsif( $::type eq "fortran" ) {
      if( /^[!cC\*]/ ) {		# comment in first col
      } elsif( /^\s*!/ ) {		# comment with leading blanks
      } else {				# first line of code
        $in_header = 0;
      }
    } elsif( $::type eq "c" ) {
      if( /^\/\*\*/ ) {			# c comment start
      } elsif( /^\\\*\*/ ) {		# c comment end
      } elsif( /^\s*\*/ ) {		# c comment
      } else {				# first line of code
        $in_header = 0;
      }
    } else {
      if( /^\s*$cc/ ) {			# comment
      } else {				# first line not comment
        $in_header = 0;
      }
    }

    if( $in_header ) {
      push(@header,$_);
    } else {
      push(@body,$_);
    }
  }

  return (\@header,\@body);
}

sub extract_copy
{
  my $header = shift;

  my $in_copy = 0;
  my @copy = ();
  my @header0 = ();
  my @headermain = ();

  foreach (@$header) {
    #print "$in_copy: $_\n";
    if( /^..------------------------------/ or
	/^\s*.\*\*\*\*\*/ or
	/^\% \*\*\*\*\*/ ) {
      $in_copy++;
      if( $in_copy < 3 ) {
        push(@copy,$_);
        next;
      }
    }
    if( $in_copy == 0 ) {
      push(@header0,$_);
    } elsif( $in_copy == 1 ) {
      $::copyright++ if( /^..\s*Copyright/ );
      $::copyright++ if( /^\% \* Copyright/ );
      $::shyfem++ if( /^..\s*This file is part of SHYFEM./ );
      $::manual++ if( /^..\s*This file is part of SHYFEM.\s+\(m\)/ );
      push(@copy,$_);
    } else {
      push(@headermain,$_);
    }
  }

  if( $::copyright ) {
    #if( $::copyright > 1 ) {
    #  print STDERR "*** more than one copyright in file $::file\n";
    #}
    if( not $::stats ) {
      if( $in_copy < 2 ) {
        print STDERR "*** copyright notice not finished in file $::file\n";
      }
      if( $::shyfem == 0 and $::type ne "ps" ) {
        print STDERR "*** missing shyfem line in file $::file\n";
      }
    }
  } else {
    if( not $::stats and $::need_copy ) {
      print STDERR "*** no copyright in file $::file\n";
    }
    @headermain = @$header;
    @copy = ();
    @header0 = ();
  }

  return (\@header0,\@copy,\@headermain);
}

sub extract_rev
{
  my $headermain = shift;

  my $revs = 0;
  my $in_rev = 0;
  my @rev = ();
  my @header1 = ();
  my @header2 = ();

  foreach (@$headermain) {
    if( /^..\s*revision log :/ ) {
      $in_rev++;
    } elsif( /^..\s*Revision History:/ ) {
      $::cstyle_revlog = 1;
      $in_rev++;
    } elsif( /^[cC!\*]\s*$/ or /^\s*$/ 
		or /^ \*\s*$/ or /^ \*\s+\*\s*$/
		or /^\#\s*$/ ) {
      if( $in_rev == 1 and $revs > 1 ) {
        $in_rev++;				#account for empty line
      }
    }
    if( $in_rev == 0 ) {
      push(@header1,$_);
    } elsif( $in_rev == 1 ) {
      $revs++;
      push(@rev,$_);
    } else {
      push(@header2,$_);
    }
  }

  if( $in_rev > 2 ) {
    print "in_rev: $in_rev\n";
    print STDERR "*** more than one revision log in file $::file\n";
  }
  if( $::cstyle_revlog ) {
    print STDERR "   old c style revision log in file $::file\n";
  }
  if( $::need_revlog and not $revs and not $::manual ) {
    print STDERR "   no revision log in file $::file\n";
  }

  return (\@header1,\@rev,\@header2);
}

#--------------------------------------------------------------
#--------------------------------------------------------------
#--------------------------------------------------------------

sub write_file
{
  my $file = shift;

  open(FILE,">$file");

  foreach my $block (@_) {
    foreach my $line (@$block) {
      print FILE "$line\n";
    }
  }

  close(FILE);
}

sub print_file
{
  my $n = 0;

  my @title = ("header0","copy","header1","rev","header2");

  foreach my $block (@_) {
    $n++;
    my $title = shift(@title);
    print "======================================================\n";
    print "$n - $title\n";
    print "======================================================\n";
    foreach my $line (@$block) {
      print "$line\n";
    }
  }
}

sub stats_file
{
  my ($file,$rev,$dev) =@_;

  my $revs = @$rev;
  $revs -= 2 if $revs > 0;

  my $error = 0;
  $error++ if $::copyright != 1;
  $error++ if $::shyfem != 1;
  $error++ if $::manual != 0;
  $error++ if $revs == 0;

  return unless $error;

  print" $::copyright $::shyfem $::manual $revs $devs   $file\n";
}

#--------------------------------------------------------------
#--------------------------------------------------------------
#--------------------------------------------------------------

sub subst_copyright
{
  my ($cold,$csubst) = @_;

  my @cnew = ();
  my $in_old = 0;

  foreach (@$cold) {
    if( /..\s*Copyright/ ) {
      push(@cnew,@$csubst) unless $in_old;
      $in_old++;
      next;
    }
    push(@cnew,$_);
  }

  return \@cnew;
}

sub split_developers
{
  my ($name,$year) = @_;

  my @new = ();

  my $ln = length($name);

  my $lymax = 50 - $ln;

  while( length($year) > $lymax ) {
    my $new = "";
    while( length($new) < $lymax ) {
      $year =~ s/([^,]+),//;
      $new .= "$1,";
    }
    $new =~ s/,$//;
    push(@new,"$name $new");
  }
  push(@new,"$name $year");

  return @new;
}

sub subst_developers
{
  my $rev = shift;

  return 0 unless @$rev;

  foreach my $line (@$rev) {
    my ($date,$devs,$text) = parse_revision_line($line);
    my $subst = 0;
    my @devs = split(/\&/,$devs);
    foreach my $dev (@devs) {
      if( $::subst_dev_names{$dev} ) {
        my $new = $::subst_dev_names{$dev};
	print "   substituting developer $dev with $new\n";
	$dev = $new;
	$subst++;
      }
    }
    if( $subst ) {
      $devs = join("&",@devs);
      $line = "$::comchar $date\t$devs\t$text";
    }
  }

  return $rev;
}

sub count_developers
{
  my $rev = shift;

  return 0 unless @$rev;

  foreach (@$rev) {
    my ($date,$devs,$text) = parse_revision_line($_);
    #print "$date,$devs,$text\n";
    if( $date ) {
      insert_developers($devs,$date);
    }
  }

  my @keys = keys %::devcount;
  my $n = @keys;

  return $n;
}

sub handle_developers
{
  my $rev = shift;

  my @keys = keys %::devcount;
  my $n = @keys;
  #print "  $::file: $n\n";
  foreach my $key (@keys) {
    my $years = $::devyear{$key};
    my ($newyears,$nyears,$first) = compact_years($years);
    $::devyear{$key} = $newyears;
    $::devnyear{$key} = $nyears;
    $::devfirst{$key} = $first;
    my $name = $::dev_names{$key};
    unless( $name ) {
      print STDERR "*** no such developer in file $::file: $key\n";
      $name = "unknown";
    }
    $::devname{$key} = $name;
    #print "   Copyright  (C)  $key  $years\n";
  }

  my @copy = ();
  foreach my $key (sort { 
			   $::devfirst{$a} <=> $::devfirst{$b} 
  			or $::devnyear{$b} <=> $::devnyear{$a} 
  			or $::devname{$b} cmp $::devname{$a} 
			} keys %::devcount ) {
    my $name = $::devname{$key};
    my $year = $::devyear{$key};
    my @lines = split_developers("$name ($key)",$year);
    push(@copy,@lines);
  }

  foreach (@copy) { 
    $_ = "$::comchar    Copyright (C) $_";
  }

  return \@copy;
}

sub compact_years
{
  my $years = shift;

  $years =~ s/,$//;			#pop trailing ,
  #print "$years\n";
  my @years = split(",",$years);

  my $last = 0;
  my @new = ();
  foreach (@years) {
    push(@new,$_) if $_ != $last;
    $last = $_;
  }
  #print join(",",@new),"\n";
  my $nyears = @new;
  my $first = $new[0];

  my $line = "";
  my $start = shift(@new);
  my $end = $start;
  foreach (@new) {
    die "internal error... \n" if( $_ == $end );
    if( $_ - $end  == 1 ) {
      $end = $_;
    } else {
      if( $start == $end ) {
        $line .= "$start,";
      } else {
        $line .= "$start-$end,";
      }
      $start = $_;
      $end = $_;
    }
  }
  if( $start == $end ) {
    $line .= "$start,";
  } else {
    $line .= "$start-$end,";
  }

  $line =~ s/,$//;			#pop trailing ,
  #print "$line\n";
  return ($line,$nyears,$first);
}

sub clean_c_header
{
  my $text = shift;

  foreach (@$text) {
    next unless $_;
    s/\s*\*\s*$//;
    $_ = " *" unless $_;	#deleted initial star... put it back
  }

  return $text;
}

sub rewrite_c_revlog
{
  my $rev = shift;

  my $nrev = @$rev;
  return $rev unless $nrev;
  if( $nrev == 1 ) {
    print STDERR "incomplete revision log in file $::file\n";
    return $rev;
  }
  my @aux = @$rev;
  my $first = shift @aux;
  unless( $first =~ /Revision History:/ ) {
    print STDERR "cannot parse revision header in file $::file\n";
    print STDERR "$first\n";
    return $rev;
  }
  my $second = shift @aux;
  unless( $second =~ /^\s*\*\s+\*\s*$/ ) {
    unshift(@aux,$second);
  }

  my $error = 0;
  @aux = reverse(@aux);
  my @new = ();
  my @conti = ();
  push(@new," * revision log :");
  push(@new," *");
  foreach (@aux) {
    #print "parsing $_\n";
    s/\s*\*\s*$//;
    #if( /^\s*\*\s+(\S)\s+(.+)\*\s*$/ ) {
    if( /^\s*\*\s+(\.\.\.)\s+(.+)$/ ) {
      my $text = $2;
      my $line = " * ...\t\tggu\t$text";
      unshift(@conti,$line);
    } elsif( /^\s*\*\s+(\S+)\s+(.+)$/ ) {
      my $date = $1;
      my $text = $2;
      $date = translate_c_date($date);
      my $line = " * $date\tggu\t$text";
      push(@new,$line);
      if( @conti ) {
        push(@new,@conti);
	@conti = ();
      }
    } else {
      print STDERR "cannot parse revision log in file $::file\n";
      print STDERR "$_\n";
      $error++;
    }
  }

  if( $error ) {
    return $rev;
  } else {
    return \@new;
  }
}

sub translate_c_date
{
  my $date = shift;

  my ($day,$month,$year);

  if( $date =~ /^(\d\d)-(\S+)-(\d\d\d\d):*$/ ) {
    $day = $1;
    $month = $2;
    $year = $3;
  } elsif( $date =~ /^(\S\S)-(\S+)-(\d{2,4}):*$/ ) {
    $day = $1;
    $month = $2;
    $year = $3;
    $year += 2000 if $year < 50;
    $year += 1900 if $year < 1900;
    $day = "01" if $day eq "..";
    if( $day < 1 or $day > 31 ) {
      print "*** error parsing day: $date ($::file)\n";
      return $date;
    }
    $month = "Jan" if $month eq "...";
  } else {
    print "*** error parsing date: $date ($::file)\n";
    return $date;
  }

  $month = $::month_dates{$month};
  return $date unless $month;

  unless( $month ) {
    print "*** error parsing month: $date ($::file)\n";
    return $date;
  }

  $date="$day.$month.$year";
  return $date;
}

sub integrate_revlog
{
  my $rev = shift;

  my $nrev = @$rev;
 
  my @gitrev=`git-file -revlog $::file`;
  #my $ngit = @gitrev;
  #print "checking file $::file\n";
  #print "from git $ngit total lines read...\n";

  my @new = ();
  my $in_revision_log = 0;
  foreach (@gitrev) {
    $in_revision_log = 1 if /revision log/;
    next unless $in_revision_log;
    chomp;
    push(@new,$_);
  }
  #pop(@new) if $new[-1] =~ /^\s*$/;

  if( $nrev ) {
    print STDERR "$::file not ready for merging, can only integrate\n";
    #write_array('orig:',@$rev);
    #write_array('git:',@new);
    return $rev;
  }

  my $nnew = @new;
  if( $nnew <= 3 ) {
    print "$::file no git revlog found... ($nnew)\n";
    return $rev;
  } else {
    print "$::file from git $nnew lines read...\n";
    if( $::type eq "c" ) {
      @new = revadjust_for_c(@new);
    }
  }

  return \@new;
}

sub check_rev_dates
{
  my $rev = shift;

  if( $::cstyle_revlog ) {
    #print "   cannot check dates in old c style revlog\n";
    return
  }

  my $old_idate = 0;
  foreach (@$rev) {
    my ($date,$dev,$text) = parse_revision_line($_);
    if( $date ) {
      my $idate = make_idate($date);
      if( $old_idate > $idate ) {
        print "   *** error in dates of revision log: 
				$old_idate - $idate ($::file)\n";
      }
      $old_idate = $idate;
    } else {
      if( $dev eq "error" ) {
        print "   *** error parsing revision log: $_ ($::file)\n";
      }
    }
  }
}

sub revadjust_for_c
{
  print STDERR "   adjusting revlog for c\n";

  foreach (@_) {
    s/^./ */;
  }
  pop(@_);
  unshift(@_," *");
  #unshift(@_,"");
  unshift(@_,$::divisor_start);
  push(@_," *");
  push(@_,$::divisor_end);
  push(@_,"");

  return @_
}

sub copy_divisor
{
  my ($header,$copy) = @_;

  my @aux = reverse(@$header);
  my @new = ();
  my $div;

  foreach (@aux) {
    $div = $_;
    last if /^[cC!]\s*\*\*\*/;
    last if /^[cC!]\s*---/;
    last if /^[cC!]\s*===/;
    last if /^\s*\*\*\*/;
    $div = "";
  }

  if( $div ) {
    push(@new,$div);
    push(@new,"\n");
  } else {
    $::divisor_start = $copy->[0];
    $::divisor_end = $copy->[-1];
  }

  return \@new;
}

sub write_array
{
  my $text = shift;

  print "$text\n";
  foreach (@_) {
    print "$_\n";
  }
}
