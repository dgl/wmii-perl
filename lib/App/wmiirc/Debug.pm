package App::wmiirc::Debug;
use App::wmiirc::Plugin;
use Data::Dump qw(pp);
use Eval::WithLexicals;
use IO::Pty;
use IO::Async::Process;

has name => (
  is => 'ro',
  default => sub { 'debug' }
);

with 'App::wmiirc::Role::Action';
with 'App::wmiirc::Role::Widget';

sub BUILD {
  my($self) = @_;
  $self->label("!");
}

sub widget_click {
  my($self, $button) = @_;

  if($self->{_active}) {
    # This is a bit annoying, but we want to ensure we don't get nested deeply
    # inside the Term::ReadLine::Event loop.
    $self->{_active}->kill("TERM") if $self->{_active}->is_running;
    $self->{_active} = undef;
    wmiir "/event", "RightBarClick 1 debug";
    return;
  }

  my $pty = IO::Pty->new;
  my $process = IO::Async::Process->new(
    command => ["urxvt", "-title" => "wmiirc-debug", "-pty-fd" => 3],
    setup => [
      fd3 => $pty,
    ],
    on_finish => sub {
      $pty->close_slave;
    },
  );
  $self->core->loop->add($process);
  $self->{_active} = $process;
  close $pty;

  my $eval = Eval::WithLexicals->with_plugins("HintPersistence")->new(
    lexicals => {
      '$self' => \$self,
      '$core' => \$self->core,
      '$loop' => \$self->core->loop
    },
    in_package => 'D',
  );

  my $rl = My::Term::ReadLine::Event->with_IO_Async(
    ["wmiirc", ($pty->slave) x 2],
    loop => $self->core->loop,
  );
  $rl->Attribs->{rl_catch_signals} = 0;
  $rl->Attribs->{rl_catch_sigwinch} = 0;

  while(defined(my $line = $rl->readline("$0> "))) {
    my @ret;
    if(eval {
      my $out = Guard::TempFH->new('>', \*STDOUT, $pty->slave);
      my $err = Guard::TempFH->new('>', \*STDERR, $pty->slave);
      @ret = $eval->eval($line);
      1;
    }) {
      $pty->slave->write(pp(@ret) . "\n");
    } else {
      $pty->slave->write($@);
    }
  }

  $process->kill("TERM");
  $self->{_active} = undef;
}
*action_debug = *action_debug = *widget_click;

{ package # avoid indexing
  D;

  use App::wmiirc::Util;
  use Devel::Peek;

  sub mod {
    my($core, $module) = @_;
    return $core->{cache}{"App::wmiirc::\u$module"};
  }
}

{
  # TODO: Is there something like this on CPAN already?
  package
    Guard::TempFH;

  sub new {
    my($class, $type, $fh, $new_fh) = @_;
    open my $old_fh, "$type&", $fh or die "Unable to dup $fh: $!";
    open $fh, "$type&=", $new_fh or die "Unable to dup $new_fh: $!";

    return bless [ $old_fh, $fh, $type ], $class;
  }

  sub DESTROY {
    my($old_fh, $fh, $type) = @{$_[0]};
    open $fh, "$type&=", $old_fh or warn "Unable to restore $old_fh to $fh";
  }
}

{
  # TODO: Upstream this.
  package
    My::Term::ReadLine::Event;

  use Scalar::Util qw(blessed weaken);
  use Term::ReadLine 1.09;

  sub _new {
    my $class = shift;
    my $app = shift;

    my $self = bless {@_}, $class;

    $self->{_term} = blessed $app ? $app :
      Term::ReadLine->new(ref $app ? @$app : $app);
    $self;
  }

  sub with_IO_Async {
    my $self = _new(@_);
    my $weak_self = $self;
    weaken $weak_self;

    $self->trl->event_loop(
      sub {
        my $ready = shift;
        $$ready = 0;
        $weak_self->{loop}->loop_once while !$$ready;
      },
      sub {
        my $fh = shift;
        return unless $weak_self;

        # The data for IO::Async is just the ready flag.  To
        # ensure we're referring to the same value, this is
        # a SCALAR ref.
        my $ready = \ do{my $dummy};
        $weak_self->{loop}->add(
          $weak_self->{watcher} = IO::Async::Handle->new(
            read_handle => $$fh,
            on_read_ready => sub {
              $$ready = 1
            },
          )
        );
        $ready;
      }
    );

    $self->{_cleanup} = sub {
      my $s = shift;
      $s->{loop}->remove($s->{watcher});
    };

    $self;
  }

  sub DESTROY {
    my $self = shift;

    local $@;
    eval {
      $self->trl->event_loop(undef);

      $self->{_cleanup}->($self) if $self->{_cleanup};
    };
  }

  sub trl {
    my $self = shift;
    $self->{_term};
  }

  sub readline {
    my $self = shift;
    $self->trl->readline(@_);
  }

  sub Attribs {
    my $self = shift;
    $self->trl->Attribs(@_);
  }

  sub addhistory {
    my $self = shift;
    $self->trl->addhistory(@_);
  }
}

1;
