package App::wmiirc::Volume;
use 5.014;
use App::wmiirc::Plugin;
use IO::Async::Timer::Periodic;

# TODO: Split actual audio volume control into another module and fix the stupid
# logic. Anything on CPAN?

has name => (
  is => 'ro',
  default => sub { 'volume' },
);

has volume => (
  is => 'rw'
);

has device => (
  is => 'ro',
  default => sub {
    config("volume", "device", "Master")
  }
);

with 'App::wmiirc::Role::Key';
with 'App::wmiirc::Role::Widget';

sub BUILD {
  my($self) = @_;
  my $timer = IO::Async::Timer::Periodic->new(
    interval => 10,
    on_tick => sub {
      $self->render;
    },
    reschedule => 'skip',
  );
  $timer->start;
  $self->core->loop->add($timer);
  $self->render;
}

sub render {
  my($self) = @_;

  my $vol = `amixer get $self->{device},0`;
  $self->volume(($vol =~ /\[(off)\]/)[0] || $vol =~ /\[(\d+)%\]/);
  return unless defined $self->volume;
  $self->label($self->volume . ($self->volume =~ /\d/ && '%'));
}

sub widget_click {
  my($self, $button) = @_;

  if($button == 1) {
    $self->set($self->volume eq 'off' ? "unmute" : "mute");
  } elsif($button == 3) {
    system config("commands", "volume") . '&';
  } elsif($self->volume ne 'off') {
    if($button == 4) {
      $self->set($self->volume  + 2 . "%");
    } elsif($button == 5) {
      $self->set($self->volume - 2 . "%");
    }
  }
}

sub key_volume_down(XF86AudioLowerVolume) {
  my($self) = @_;
  $self->set("unmute") if $self->volume eq 'off';
  $self->set($self->volume - 6 . "%");
}

sub key_volume_up(XF86AudioRaiseVolume) {
  my($self) = @_;
  $self->set("unmute") if $self->volume eq 'off';
  $self->set($self->volume + 6 . "%");
}

sub key_volume_mute(XF86AudioMute) {
  my($self) = @_;
  $self->set($self->volume eq 'off' ? "unmute" : "mute");
}

sub set {
  my($self, $level) = @_;
  system "amixer", "set", "$self->{device},0", $level;
  $self->render;
}

1;
