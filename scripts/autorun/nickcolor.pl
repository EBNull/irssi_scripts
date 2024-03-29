use strict;
use Irssi 20020101.0250 ();
use vars qw($VERSION %IRSSI); 
$VERSION = "1";
%IRSSI = (
    authors     => "Timo Sirainen, Ian Peters",
    contact	=> "tss\@iki.fi", 
    name        => "Nick Color",
    description => "assign a different color for each nick",
    license	=> "Public Domain",
    url		=> "http://irssi.org/",
    changed	=> "2002-03-04T22:47+0100"
);
#CHANGES FROM ORIGINAL SCRIPT
# - 'Session' colors are persisted on exit
# - Removed using color 2 and 8 (change by editing @colors line)
# - one can /color set nick without specifyign a color to make a session color a saved color
# - /color list is sorted


# hm.. i should make it possible to use the existing one..
Irssi::theme_register([
  'pubmsg_hilight', '{pubmsghinick $0 $3 $1}$2'
]);

my %saved_colors;
my %session_colors = {};
my @colors = qw/3 4 5 6 7 9 10 11 12 13/;
my $colorcount = 10;

sub load_colors {
  open COLORS, "$ENV{HOME}/.irssi/saved_colors";

  while (<COLORS>) {
    # I don't know why this is necessary only inside of irssi
    my @lines = split "\n";
    foreach my $line (@lines) {
      my($nick, $color) = split ":", $line;
      $saved_colors{$nick} = $color;
    }
  }

  close COLORS;
  
  open COLORS, "$ENV{HOME}/.irssi/session_colors";

  while (<COLORS>) {
    # I don't know why this is necessary only inside of irssi
    my @lines = split "\n";
    foreach my $line (@lines) {
      my($nick, $color) = split ":", $line;
      $session_colors{$nick} = $color;
    }
  }

  close COLORS;
}

sub save_colors {
  open COLORS, ">$ENV{HOME}/.irssi/saved_colors";

  foreach my $nick (keys %saved_colors) {
    print COLORS "$nick:$saved_colors{$nick}\n";
  }

  close COLORS;
  
  open COLORS, ">$ENV{HOME}/.irssi/session_colors";

  foreach my $nick (keys %session_colors) {
    print COLORS "$nick:$session_colors{$nick}\n";
  }

  close COLORS;
}

# If someone we've colored (either through the saved colors, or the hash
# function) changes their nick, we'd like to keep the same color associated
# with them (but only in the session_colors, ie a temporary mapping).

sub sig_nick {
  my ($server, $newnick, $nick, $address) = @_;
  my $color;

  $newnick = substr ($newnick, 1) if ($newnick =~ /^:/);

  if ($color = $saved_colors{$nick}) {
    $session_colors{$newnick} = $color;
  } elsif ($color = $session_colors{$nick}) {
    $session_colors{$newnick} = $color;
  }
}

# This gave reasonable distribution values when run across
# /usr/share/dict/words

sub simple_hash {
  my ($string) = @_;
  chomp $string;
  my @chars = split //, $string;
  my $counter;

  foreach my $char (@chars) {
    $counter += ord $char;
  }

  $counter = $colors[$counter % $colorcount];

  return $counter;
}

# FIXME: breaks /HILIGHT etc.
sub sig_public {
  my ($server, $msg, $nick, $address, $target) = @_;
  my $chanrec = $server->channel_find($target);
  return if not $chanrec;
  my $nickrec = $chanrec->nick_find($nick);
  return if not $nickrec;
  my $nickmode = $nickrec->{op} ? "@" : $nickrec->{voice} ? "+" : "";

  # Has the user assigned this nick a color?
  my $color = $saved_colors{$nick};

  # Have -we- already assigned this nick a color?
  if (!$color) {
    $color = $session_colors{$nick};
  }

  # Let's assign this nick a color
  if (!$color) {
    $color = simple_hash $nick;
    $session_colors{$nick} = $color;
  }

  $color = "0".$color if ($color < 10);
  $server->command('/^format pubmsg {pubmsgnick $2 {pubnick '.chr(3).$color.'$0}}$1');
}

sub cmd_color {
  my ($data, $server, $witem) = @_;
  my ($op, $nick, $color) = split " ", $data;

  $op = lc $op;

  if (!$op) {
    Irssi::print ("No operation given, try 'save', 'set nick color', 'clear nick', 'list', 'preview'");
  } elsif ($op eq "save") {
    save_colors;
  } elsif ($op eq "get") {
    if (!$nick) {
      Irssi::print ("Nick not given");
    } else {
      if ($saved_colors{$nick}) {
        Irssi::print ("Saved - " . chr (3) . "$saved_colors{$nick} $saved_colors{$nick}: $nick" .
		      chr (3) . "1 ($saved_colors{$nick})");
      }
      if ($session_colors{$nick}) {
        Irssi::print ("Session - " . chr (3) . "$session_colors{$nick} $session_colors{$nick}: $nick" .
		    chr (3) . "1 ($session_colors{$nick})");
      }
    }
  } elsif ($op eq "set") {
    if (!$nick) {
      Irssi::print ("Nick not given");
    } elsif (!$color) {
      $color = $session_colors{$nick};
      if (!$color) {
          Irssi::print ("Color not given");
      } else {
          $saved_colors{$nick} = $color;
          delete ($session_colors{$nick});      
      }
    } elsif ($color < 2 || $color > 14) {
      Irssi::print ("Color must be between 2 and 14 inclusive");
    } else {
      $saved_colors{$nick} = $color;
      delete ($session_colors{$nick});
    }
  } elsif ($op eq "clear") {
    if (!$nick) {
      Irssi::print ("Nick not given");
    } else {
      delete ($saved_colors{$nick});
      delete ($session_colors{$nick});
    }
  } elsif ($op eq "clean") {
    foreach my $nick (sort {lc $a cmp lc $b} keys %saved_colors) {
        if (!$saved_colors{$nick}) {
            delete ($saved_colors{$nick});
        }
    }
    foreach my $nick (sort {lc $a cmp lc $b} keys %session_colors) {
        if (!$session_colors{$nick}) {
            delete ($session_colors{$nick});
        }
    }
  } elsif ($op eq "list") {
    Irssi::print ("\nSaved Colors:");
    foreach my $nick (sort {lc $a cmp lc $b} keys %saved_colors) {
      Irssi::print (chr (3) . "$saved_colors{$nick} $saved_colors{$nick}: $nick" .
		    chr (3) . "1 ($saved_colors{$nick})");
      delete ($session_colors{$nick}); #cleanup
    }
    Irssi::print ("\nSession Colors:");
    foreach my $nick (sort {lc $a cmp lc $b} keys %session_colors) {
      Irssi::print (chr (3) . "$session_colors{$nick} $session_colors{$nick}: $nick" .
		    chr (3) . "1 ($session_colors{$nick})");
    }
  } elsif ($op eq "preview") {
    Irssi::print ("\nAvailable colors:");
    foreach my $i (@colors) {
      Irssi::print (chr (3) . "$i" . "Color #$i");
    }
  }
}

load_colors;

Irssi::command_bind('color', 'cmd_color');

Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('event nick', 'sig_nick');
