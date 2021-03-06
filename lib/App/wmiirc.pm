# ABSTRACT: An event loop for wmii (X11 window manager)
package App::wmiirc;
use 5.014;
use App::wmiirc::Util;
use File::Which;
use IO::Async::Loop;
use IO::Async::Stream;
use Moo;
use Try::Tiny;

$SIG{PIPE} = 'IGNORE';

our $DEBUG;
BEGIN {
  $DEBUG = !!$ENV{WMIIP_DEBUG};

  if($DEBUG) {
    require Carp;
    Carp->import('verbose');
    $SIG{__DIE__} = \&Carp::confess;
  }
}

has loop => (
  is => 'ro',
  default => sub { IO::Async::Loop->new }
);

has main_config => (
  is => 'ro',
  default => sub {
    +{config("config", {
      modkey      => 'Mod4',
      normcolors  => '#999999 #151f3f #2a3f3f',
      focuscolors => '#ffffaa #5f77bf #2a3f8f',
      alertcolors => '#ffffff #aa2299 #ff44cc',
      font        => '-*-fixed-medium-r-*-*-12-*-*-*-*-*-*-*',
      terminal    => scalar(config('commands', 'terminal',
                       which('urxvt') || which('xterm'))),
    })}
  }
);

has _actions => (
  is => 'ro',
  default => sub { +{} },
);

has _cache => (
  is => 'ro',
  default => sub { +{} },
);

has _keys => (
  is => 'rw',
  default => sub { +{} },
);


sub BUILD {
  my($self) = @_;

  $SIG{__WARN__} = sub {
    print STDERR @_;
    $self->dispatch("event_msg", @_);
  };

  $SIG{HUP} = sub {
    $self->dispatch("action_wmiirc");
    warn "action_wmiirc failed";
    exit 1;
  };

  # Munge defaults to wmii ctl form
  my %ctl_config = %{$self->main_config};
  $ctl_config{grabmod} ||= $self->main_config->{modkey};
  delete @ctl_config{qw(modkey terminal alertcolors)};
  wmiir "/ctl", map "$_ $ctl_config{$_}", keys %ctl_config;

  # Mirror various bits of config under .wmii to wmii's filesystem
  wmiir "/rules", scalar config("rules");
  wmiir "/colrules", scalar config("colrules");

  # Load configured modules
  my %modules = config("modules", { key => "", tag => "" });
  $self->load(/::/ ? $_ : "App::wmiirc::\u$_") for keys %modules;

  # Run configured external programs
  for(split /\n/, scalar config("startup") || "witray") {
    next if /^\s*#/;
    system "$_ &";
  }
}

sub run {
  my($self) = @_;

  $self->loop->open_child(
    command => [qw(wmiir read /event)],
    stdout => {
      on_read => sub {
        my(undef, $buffref) = @_;

        while($$buffref =~ s/^(.*\n)//) {
          my($event, @args) = split " ", $1;
          next unless $event;
          # CamelCase -> camel_case
          $event =~ s/(?<=[a-z])([A-Z])/_$1/g;
          try {
            $self->dispatch(lc "event_$event", @args);
          } catch {
            warn "Dispatch failed: $_";
          }
        }
      }
    },
    on_finish => sub {
      $self->loop->stop(1);
    }
  );

  my $stopped = 0;
  while (!$stopped) {
    try {
      $stopped = $self->loop->run;
    } catch {
      warn "Runloop failed: $_";
      sleep 1;
    };
  }
}

sub dispatch {
  my($self, $event, @args) = @_;

  my $ret;
  for my $module(grep /::$/, keys %App::wmiirc::) {
    my $class = "App::wmiirc::" . $module =~ s/::$//r;
    if($class->can($event)) {
      print STDERR "Dispatch: $event (@args) to $class\n" if $DEBUG;
      $self->{_cache}{$class} ||= $self->load($class);
      if(!ref $self->{_cache}{$class}) {
        warn "Failed to instantiate $class\n";
      } else {
        $ret = $self->{_cache}{$class}->$event(@args);
      }
    }
  }
  $ret;
}

sub load {
  my($self, $class) = @_;
  warn "Loading $class\n" if $DEBUG;
  my $file = $class =~ s{::}{/}rg;
  $file .= ".pm";
  try {
    # Make it so a bad module doesn't kill the whole thing and can usually be
    # recovered from with a simple Modkey-a wmiirc.
    require $file;
    $self->{_cache}{$class} = $class->new(core => $self);
  } catch {
    warn "Failed to load $class: $_";
  }
}

1;

=head1 DESCRIPTION

Please see the F<README> for details for now.

=cut
