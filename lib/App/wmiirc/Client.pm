package App::wmiirc::Client;
# ABSTRACT: Keep track of clients
use App::wmiirc::Plugin;
use JSON;
with 'App::wmiirc::Role::Key';

has clients => (
  is => 'ro',
  default => sub { {} },
);

has previous_id => (
  is => 'rw'
);

has _last_destroyed_ppid => (
  is => 'rw',
);

has _last_msg => (
  is => 'rw',
);

has _last_pid => (
  is => 'rw',
);

sub BUILD {
  my($self) = @_;

  for my $id(wmiir "/client/") {
    $id =~ s{/$}{};
    next if $id eq 'sel';
    $self->event_create_client($id);
  }
}

sub event_create_client {
  my($self, $id) = @_;
  my $props = wmiir "/client/$id/props";
  return unless $props;
  $self->clients->{$id} = [split /:/, $props, 3];
  if(my($pid) = map /(\d+)/, grep /^pid /, wmiir "/client/$id/ctl") {
    my $ppid = `ps --pid=$pid ho ppid`;
    $ppid = 0 + $ppid if $ppid;
    @{$self->clients->{$id}}[4, 5] = ($pid, $ppid);
  }
  $self->clients->{$id}[6] = time;
}

sub event_client_focus {
  my($self, $id) = @_;
  my $previous_id = $self->previous_id;
  if($self->previous_id && (my $props = wmiir "/client/$previous_id/props")) {
    @{$self->clients->{$previous_id}}[0..2] = split /:/, $props, 3;
    $self->clients->{$previous_id}->[6] = time;
  }
  $self->previous_id($id);
}

sub list_chrome_tabs {
  my($self) = @_;
  my $s = IO::Socket::UNIX->new("/tmp/ch-$ENV{USER}") or return;
  eval {
    print $s to_json({t => "windows"}), "\n";
    my $windows = from_json(<$s>)->{data};
    for my $win(@$windows) {
      print $s to_json({t => "tabs", windowId => $win->{id} }), "\n";
      $win->{tabs} = from_json(<$s>)->{data};
    }

    return $windows;
  };
}

sub key_list_clients(Modkey-slash) {
  my($self) = @_;
  return unless %{$self->clients};

  # Update with current window
  my($cur_id) = wmiir "/client/sel/ctl";
  my $props = wmiir "/client/$cur_id/props";
  @{$self->clients->{$cur_id}}[0..2] = split /:/, $props, 3 if $props;

  my @clients = map {
    my $n = $self->clients->{$_}[2];
    substr($n =~ s/`!//gr, 0, 100) . "`!$_"
  } grep defined $self->clients->{$_}[2],
      sort { $self->clients->{$b}[6] <=> $self->clients->{$a}[6] }
        keys %{$self->clients};

  my $chrome_windows = []; #$self->list_chrome_tabs;
  my %cr_id_map;
  for my $win(@$chrome_windows) {
    for my $tab(@{$win->{tabs}}) {
      if($tab->{active}) {
        # Urgh.
        no warnings 'uninitialized';
        my @ids = grep {
            $tab->{title} && $self->clients->{$_}[2] &&
            $self->clients->{$_}[2] =~
                /\Q$tab->{title}\E - (?:Chromium|Google Chrome)$/
          } keys %{$self->clients};
        next if !@ids || @ids > 1; # Better way to handle this?
        @clients = grep !/`!$ids[0]$/, @clients;
        $cr_id_map{$win->{id}} = $ids[0];
      }
      push @clients, substr($tab->{title}, 0, 80) . '`!cr:' . $win->{id} . ':' . $tab->{id};
    }
  }

  if(my $win = wimenu { name => 'client', S => '`!', i => undef }, @clients) {
    if($win =~ /^cr:(\d+):(\d+)/) {
      $win = $cr_id_map{$1};
      my $tab = 0+$2;
      my $s = IO::Socket::UNIX->new("/tmp/ch-$ENV{USER}") or return;
      print $s to_json({t => "focus", tabId => $tab}), "\n";
    }

    return unless $win;
    _goto_win($win);
  }
}

sub _goto_win {
  my($win) = @_;

  my($tags) = wmiir "/client/$win/tags";
  if($tags) {
    wmiir "/ctl", "view $tags";
    wmiir "/tag/sel/ctl", "select client $win";
  }
}

=for zshrc

if [[ -n $WMII_CONFPATH ]]; then
  wmiir xwrite /event ShellWindowPid $(printf "0x%x" $WINDOWID) $$
fi

=cut

sub event_shell_window_pid {
  my($self, $id, $pid) = @_;
  $self->clients->{$id}[3] = $pid;
}

# Undistract-me implementation
# TODO: Split into module, needs ->client data for _last_destroyed_ppid though.
sub event_command_done {
  my($self, $window_id, $pid, $exit, @msg) = @_;
  my($cur_id) = wmiir "/client/sel/ctl";
  return if $cur_id && $cur_id eq $window_id;
  return if $window_id && $self->clients->{$window_id}->[6]
    && $self->clients->{$window_id}->[6] > time - 1;

  if(!$self->_last_destroyed_ppid or $pid != $self->_last_destroyed_ppid) {
    my $msg = "@msg";
    if ($msg) {
      $self->_last_msg($msg);
      $self->_last_pid($pid);
    } elsif($exit && $self->_last_pid && $pid == $self->_last_pid) {
      $msg = $self->_last_msg;
      $self->_last_pid(0);
    } else {
      $self->_last_msg("");
      $self->_last_pid(0);
      return;
    }
    $self->core->dispatch("event_msg", ($exit ? "fail($exit)" : "done") .
      ": $msg");
  }
}

sub event_destroy_client {
  my($self, $id) = @_;
  $self->previous_id(undef) if $self->previous_id && $self->previous_id eq $id;
  $self->_last_destroyed_ppid($self->clients->{$id}[5]);

  delete $self->clients->{$id};
}

# TODO: Fix SIGCHLD handling -- think about using IO::Async properly
# TODO: Maybe also a util function for running commands as it's done everywhere

sub key_terminal_here(Modkey-Control-Return) {
  my($self) = @_;

  my($cur_id, @items) = wmiir "/client/sel/ctl";
  my $pid = $self->clients->{$cur_id // ""}[3] ||
    (map /(\d+)/, grep /^pid /, @items)[0];
  return unless $pid;

  my $exe = readlink("/proc/$pid/exe");
  my $is_ssh = $exe && $exe =~ m{/ssh$};
  if(!$is_ssh) {
    for my $child(map /(\d+)/, `ps --ppid=$pid ho pid`) {
      my $l = readlink "/proc/$child/exe";
      if($l && $l =~ m{/ssh$}) {
        $is_ssh = 1;
        $pid = $child;
      }
    }
  }

  my $fork = fork;
  return if $fork or not defined $fork;

  eval {
    if($is_ssh) {
      open my $cmd_fh, "<", "/proc/$pid/cmdline";
      my $cmd = join " ", <$cmd_fh>;
      $cmd =~ s/\0/ /g;
      my($host) = $cmd =~ /ssh\s+(?:-\S+\s+)*([a-zA-Z0-9.-]+)/;
      if(!$host) {
        die "Unable to figure out hostname\n";
      }
      my($title) = wmiir "/client/sel/label";
      my($dir) = $title =~
        m{(?:^|\()(?:[-\w]+: )?([~/][/a-zA-Z0-9._-]+)(?:$|\))};
      $dir ||= "~";
      exec $self->core->main_config->{terminal},
        qw(-name URxvtSsh -e zsh -i -c),
        qq{exec ssh -t $host 'cd $dir; exec \$SHELL'};
      die "Exec failed: $?";
    } elsif(-d "/proc/$pid/cwd") {
      chdir "/proc/$pid/cwd";
    } else {
      # No /proc, try lsof
      my($dir) = `lsof -p $pid -a -d cwd -a -u $ENV{USER} -Fn` =~ /^n(.*)/m;
      chdir $dir if $dir;
    }
    exec $self->core->main_config->{terminal};
    die "Exec failed: $?";
  };

  warn $@ if $@;
  exit 1;
}

sub key_goto_regex {
  my($self, $regex) = @_;
  my $found = 0;

  for my $c(keys %{$self->clients}) {
    my $cl = $self->clients->{$c};
    if(($cl->[0] && $cl->[0] =~ $regex)
      || ($cl->[2] && $cl->[2] =~ $regex)) {
      _goto_win($c);
      $found = 1;
      last;
    }
  }

  if(!$found) {
    # Try the more expensive shelling out only if needed
    for my $c(keys %{$self->clients}) {
      my $cl = $self->clients->{$c};
      # TODO: use lsof here for portability
      if($cl->[3] && `ps --ppid=$cl->[3] ho cmd` =~ $regex) {
        _goto_win($c);
        $found = 1;
        last;
      }
    }
  }
  $found;
}

1;
