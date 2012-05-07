package App::wmiirc::Loadavg;
use 5.014;
use App::wmiirc::Plugin;
use IO::Async::Timer::Countdown;
use Unix::Uptime;

has name => (
  is => 'ro',
  default => sub { "loadavg" }
);

has _show_all => (
  is => 'rw',
  default => sub {
    my($self) = @_;
    config('loadavg', 'show', 'one') eq 'all';
  }
);

with 'App::wmiirc::Role::Widget';
#with 'App::wmiirc::Role::Fade';

sub BUILD {
  my($self) = @_;

  my $timer = IO::Async::Timer::Countdown->new(
    delay => 10,
    on_expire => sub {
      my($timer) = @_;
      $self->render;
      $timer->start;
    }
  );

  $timer->start;
  $self->core->loop->add($timer);
  $self->render;
}

sub render {
  my($self) = @_;
  $self->label(join " ", (Unix::Uptime->load)[0 .. $self->{_show_all} && 2]);
}

sub widget_click {
  my($self, $button) = @_;

  given($button) {
    when(1) {
      $self->{_show_all} ^= 1;
      $self->render;
    }
    when(3) {
      system $self->core->main_config->{terminal}
        . " -e " . (config("commands", "top") || "top") . "&";
    }
  }
}

1;
