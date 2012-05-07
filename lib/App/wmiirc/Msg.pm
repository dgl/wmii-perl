package App::wmiirc::Msg;
use App::wmiirc::Plugin;
use IO::Async::Timer::Countdown;

has name => (
  is => 'ro',
  default => sub { '!notice' }
);

has _timer => (
  is => 'rw',
);

with 'App::wmiirc::Role::Widget';
with 'App::wmiirc::Role::Fade';

sub event_msg {
  my($self, @msg) = @_;
  my $msg = "@msg";
  $msg =~ s/\n//g;

  my $timer = IO::Async::Timer::Countdown->new(
    delay => .3,
    on_expire => sub {
      my $timer = shift;
      if(!defined $self->_timer || $self->_timer != $timer) {
        # Cancelled
        $self->core->loop->remove($timer);
        return;
      }

      $self->label($msg, $self->fade_current_color);

      if($self->fade_next) {
        $timer->start
      } else {
        $self->_timer(undef);
        $self->core->loop->remove($timer);
      }
    }
  );
  $timer->start;
  $self->core->loop->add($timer);
  $self->_timer($timer);

  $self->fade_set(0);
  $self->label($msg, $self->fade_current_color);
}

# Lower priority notification, don't interrupt an active msg.
sub event_notice {
  my($self, @msg) = @_;
  my $msg = "@msg";
  $msg =~ s/\n//g;

  if(!$self->_timer) {
    $self->label($msg);
  }
}

sub widget_click {
  my($self, $button) = @_;
  $self->label(" ");
  $self->_timer(undef);
}

1;
