package App::wmiirc::Key;
# ABSTRACT: Handle keys
use App::wmiirc::Plugin;
use Data::Dump qw(dump);
use IO::Async::Process;

{
  # Load external actions
  my $conf_dir = (split /:/, $ENV{WMII_CONFPATH})[0];
  for my $external(map s{.*/}{}r, grep -x $_, <$conf_dir/*>) {
    next if $external eq 'wmiirc';

    no strict 'refs';
    *{"action_$external"} = sub {
      my($self, @args) = @_;
      # FIXME, quoting
      system "$conf_dir/$external @args &";
    }
  }
}

with 'App::wmiirc::Role::Key';
with 'App::wmiirc::Role::Action';

sub BUILD {
  my($self) = @_;
  $self->action_rehash;
}

sub event_key {
  my($self, $key) = @_;

  if(exists $self->core->_keys->{$key}) {
    $self->core->_keys->{$key}->();
  }
}

sub tag { wmiir "/tag/sel/ctl", @_ }

sub key_select(Modkey-DIR) {
  my(undef, $dir) = @_;
  tag "select $dir";
}

sub key_select_move(Modkey-Shift-DIR) {
  my(undef, $dir) = @_;
  tag "send sel $dir";
}

sub key_select_stack(Modkey-Control-DIR) {
  my(undef, $dir) = @_;
  tag "select $dir stack";
}

sub key_floating(Modkey-space) {
  tag "select toggle";
}

sub key_floating_toggle(Modkey-Shift-space) {
  tag "send sel toggle";
}

sub key_colmode_default(Modkey-d) {
  tag "colmode sel default-max";
}

sub key_colmode_stack(Modkey-s) {
  tag "colmode sel stack-max";
}

sub key_colmode_max(Modkey-m) {
  tag "colmode sel stack+max";
}

sub key_fullscreen(Modkey-f) {
  wmiir "/client/sel/ctl", "fullscreen toggle";
}

sub key_terminal(Modkey-Return) {
  my($self) = @_;
  system "wmiir setsid " . $self->core->main_config->{terminal} . "&";
}

sub key_close(Modkey-Shift-c) {
  my($self) = @_;
  wmiir "/client/sel/ctl", "kill";
}

sub key_action(Modkey-a) {
  my($self, @opts) = @_;
  my $menu = wimenu { name => "action:", history => "actions" },
      sort grep !/^default$/, keys $self->core->_actions;
  return unless defined $menu;
  my($action, @args) = @opts ? @opts : split / /, $menu;

  if($action) {
    if(exists $self->core->_actions->{$action}) {
      $self->core->_actions->{$action}->(@args);
    } elsif(exists $self->core->_actions->{default}) {
      $self->core->_actions->{default}->($action, @args);
    }
  }
}

my @progs;

sub key_run(Modkey-p) {
  my($self, $terminal) = @_;
  if(!@progs) {
    $self->action_rehash(sub { $self->key_run });
    return;
  }

  if(my $run = wimenu { name => "run:", history => "progs" }, \@progs) {
    # Urgh, hacky
    my($prog) = $run =~ /(\S+)/;
    $run = "'$run'" if $terminal;
    system +($terminal ? "$terminal -hold -title '$prog' -e $ENV{SHELL} -i -c " : "")
      . "$run &";
  }
}

sub key_run_terminal(Modkey-Shift-p) {
  my($self) = @_;
  $self->key_run($self->core->main_config->{terminal});
}

sub action_rehash {
  my($self, $finish) = @_;

  my @new_progs;
  $self->core->loop->add(IO::Async::Process->new(
    command => ['wmiir', 'proglist', split /:/, $ENV{PATH}],
    stdout => {
      on_read => sub {
        my($stream, $buffref) = @_;
        while($$buffref =~ s/^(.*)\n//) {
          push @new_progs, $1;
        }
      }
    },
    on_finish => sub {
      my %uniq_progs = map +($_, 1), @new_progs;
      @progs = sort keys %uniq_progs;
      $finish->() if $finish && ref $finish eq 'CODE';
    }
  ));
}

sub action_wmiirc {
  my($self, $cmd) = @_;

  # Force everything not in use to be destroyed.
  $SIG{HUP} = $SIG{__WARN__} = 'IGNORE';
  delete $self->core->{_actions};
  delete $self->core->{_keys};
  delete $self->core->{_cache};

  exec $cmd || ($^X, $0);
}

sub action_quit {
  wmiir "/ctl", "quit";
  exit 0;
}

sub action_eval {
  my($self, @eval) = @_;
  # This is fugly.
  my $x;
  if(eval "\$x = do { @eval }; 1") {
    $self->core->dispatch("event_notice", dump $x);
  } else {
    $self->core->dispatch("event_msg", $@);
  }
}

sub action_env {
  my($self, $param, $value) = @_;
  if(!$param) {
    system 'export | xmessage -file -&';
  } elsif(!$value) {
    $self->core->dispatch("event_msg",
      exists $ENV{$param} ? $ENV{$param} : "[not set]");
  } else {
    $ENV{$param} = $value;
    $self->core->dispatch("event_notice", "Set $param=$value");
  }
}

1;
