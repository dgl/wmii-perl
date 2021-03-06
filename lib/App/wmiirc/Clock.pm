package App::wmiirc::Clock;
use 5.014;
use App::wmiirc::Plugin;
use IO::Async::Timer::Absolute;
use POSIX qw(strftime);

has name => (
  is => 'ro',
  default => sub { '~clock' }
);

has format => (
  is => 'ro',
  default => sub {
    config("clock", "format", "%a %H:%M")
  }
);

has format_other_tz => (
  is => 'ro',
  default => sub {
    config("clock", "format_other_tz", "%a %b %d %H:%M:%S %Z")
  }
);

has extra_tz => (
  is => 'ro',
  default => sub {[
    split /,\s*/, config("clock",
      extra_tz => "America/Los_Angeles, America/New_York, Europe/Paris")
  ]}
);

has current_tz => (
  is => 'rw',
  default => sub { -1 }
);

has _timer => (
  is => 'rw'
);

with 'App::wmiirc::Role::Widget';

sub BUILD {
  my($self) = @_;
  $self->render;
}

sub render {
  my($self) = @_;
  my($text, $color, $next);

  if($self->current_tz == -1) {
    ($text, $next) = _format($self->format, localtime);
  } else {
    local $ENV{TZ} = $self->extra_tz->[$self->current_tz];
    ($text, $next) = _format($self->format_other_tz, localtime);
    $color = $self->core->main_config->{focuscolors};
  }

  $self->label($text, $color);

  $self->core->loop->remove($self->_timer) if $self->_timer;
  $self->core->loop->add($self->_timer(IO::Async::Timer::Absolute->new(
    time => $next,
    on_expire => sub {
      my($timer) = @_;
      $self->render unless $self->_timer != $timer;
    }
  )));
}

sub _format {
  my($format, @args) = @_;
  # Not sure it's worth going to these lengths to maybe save some wakeups, but
  # why not...
  my $next = $format =~ /%[^\w]?[EO]?[sSTr]/
      ? time + 1 : 60 * int(time / 60) + 60;
  return strftime($format, @args), $next;
}

sub widget_click {
  my($self, $button) = @_;

  given($button) {
    when (1) {
      $self->core->dispatch("action_calendar");
    }
    when ([4, 5]) {
      return unless @{$self->extra_tz};

      if($self->current_tz < 0) {
        $self->current_tz($button == 4 ? @{$self->extra_tz} - 1 : 0);
      } else {
        my $inc = $button == 4 ? -1 : 1;
        $self->current_tz($self->current_tz + $inc);
        if($self->current_tz < 0 || $self->current_tz == @{$self->extra_tz}) {
          $self->current_tz(-1);
        }
      }
      $self->render;
    }
    when (3) {
      system "zenity", "--calendar";
      system "cal -y | xmessage -file -" if $? == -1;
    }
  }
}

1;
