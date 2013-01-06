package App::wmiirc::Client;
# ABSTRACT: Keep track of clients
use App::wmiirc::Plugin;
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
    @{$self->clients->{$id}}[4, 5] = ($pid, 0+`ps --pid=$pid ho ppid`);
  }
}

sub event_client_focus {
  my($self, $id) = @_;
  my $previous_id = $self->previous_id;
  if($self->previous_id && (my $props = wmiir "/client/$previous_id/props")) {
    @{$self->clients->{$previous_id}}[0..2] = split /:/, $props, 3;
  }
  $self->previous_id($id);
}

sub key_list_clients(Modkey-slash) {
  my($self) = @_;
  return unless %{$self->clients};
  my @clients = map { my $n = $self->clients->{$_}[2]; $n =~ s/!!//g; "$n!!$_" }
    grep defined $self->clients->{$_}[2], keys $self->clients;

  if(my $win = wimenu { name => 'client', S => '!!', i => undef }, @clients) {
    my($tags) = wmiir "/client/$win/tags";
    if($tags) {
      wmiir "/ctl", "view $tags";
      wmiir "/tag/sel/ctl", "select client $win";
    }
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

sub event_command_done {
  my($self, $pid, @msg) = @_;
  if(!$self->_last_destroyed_ppid or $pid != $self->_last_destroyed_ppid) {
    $self->core->dispatch("event_msg", "@msg");
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
  my $fork = fork;
  return if $fork || not defined $fork;
  if(-d "/proc/$pid/cwd") {
    chdir "/proc/$pid/cwd";
  } else {
    # No /proc, try lsof
    my($dir) = `lsof -p $pid -a -d cwd -a -u $ENV{USER} -Fn` =~ /^n(.*)/m;
    chdir $dir if $dir;
  }
  exec $self->core->main_config->{terminal};
  no warnings 'exec';
  warn "Exec failed: $?";
  exit 1;
}

sub key_goto_regex {
  my($self, $regex) = @_;
  my $found = 0;

  for my $c(keys %{$self->clients}) {
    my $cl = $self->clients->{$c};
    # TODO: use lsof here for portability
    if(($cl->[3] && `ps --ppid=$cl->[3] ho cmd` =~ $regex)
      || ($cl->[0] && $cl->[0] =~ $regex)
      || ($cl->[2] && $cl->[2] =~ $regex)) {
      # TODO: multiple tag support
      my($tags) = wmiir "/client/$c/tags";
      wmiir "/ctl", "view $tags";
      wmiir "/tag/sel/ctl", "select client $c";
      $found = 1;
      last;
    }
  }
  $found;
}

1;
