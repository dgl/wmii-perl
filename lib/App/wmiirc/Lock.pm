package App::wmiirc::Lock;
use App::wmiirc::Plugin;
use IO::Async::Process;
use Scalar::Util qw(weaken);
with 'App::wmiirc::Role::Action';

has state => (
  is => 'rw',
  default => sub { "unblank" },
);

has _child => (
  is => 'rw',
  default => sub {
    my($self) = @_;
    weaken $self;
    my $child = IO::Async::Process->new(
      command => [ "xscreensaver-command", "-watch" ],
      stdout => {
        on_read => sub {
          my(undef, $buffref) = @_;
          while($$buffref =~ s/^(\w+) .*\n// ) {
            $self->_handle(lc $1);
          }
          return 0;
        },
      },
      on_finish => sub {
        warn "Lost connection to screensaver";
      },
    );
    $self->core->loop->add($child);
    $child;
  }
);

sub DESTROY {
  my($self) = @_;
  $self->_child->kill("TERM");
}

sub _handle {
  my($self, $action) = @_;
  return if $action eq 'run';

  if($action eq 'unblank' && $self->{state} =~ /^(lock|blank)/) {
    wmiir "/event", "SessionActive", $action;
  } elsif($self->{state} eq 'unblank' && $action =~ /^(lock|blank)/) {
    wmiir "/event", "SessionInactive", $action;
  }

  $self->state($action);
}

sub action_lock {
  system config("commands", "lock", "xscreensaver-command -lock");
}

sub action_sleep(XF86PowerOff) {
  system config("commands", "sleep", "sudo pm-suspend");
}

sub action_hibernate {
  system config("commands", "hibernate", "sudo pm-hibernate");
}

# TODO: Less hacky / more supported way? Probably involves dbus.
# On arch I currently have the following in /etc/acpi/actions/lm_lid.sh:
# DISPLAY=:0 sudo -u dgl ~dgl/bin/wmiir xwrite /event Lid $3

sub event_lid {
  my($self, $type) = @_;
  if($type eq 'close') {
    system config("commands", "sleep", "sudo pm-suspend");
  }
}

1;
