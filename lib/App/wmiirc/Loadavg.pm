package App::wmiirc::Loadavg;
use 5.014;
use App::wmiirc::Plugin;
use IO::Async::Timer::Periodic 0.50;
use Unix::Uptime;

has name => (
  is => 'ro',
  default => sub { "loadavg" }
);

has _cpus => (
  is => 'ro',
  default => sub {
    ((`getconf _NPROCESSORS_ONLN` || `/sbin/sysctl hw.ncpu`) =~ /(\d+)/)[0];
  }
);

has _show_all => (
  is => 'rw',
  default => sub {
    my($self) = @_;
    config('loadavg', 'show', 'one') eq 'all';
  }
);

with 'App::wmiirc::Role::Fade';
with 'App::wmiirc::Role::Widget';

sub BUILD {
  my($self) = @_;

  my $normcolors = $self->core->main_config->{normcolors};
  # Only the foreground color is configurable for now
  my $load_color = config("load", "color", "#992222");
  $self->fade_start_color($normcolors);
  $self->fade_end_color($normcolors =~ s/(\S+)/$load_color/r);

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
  my @load = Unix::Uptime->load;
  my $load_scale = $load[0] / $self->_cpus * $self->fade_count;

  $self->fade_set($load_scale > $self->fade_count ?
    $self->fade_count : $load_scale);
  $self->label(join(" ", @load[0 .. $self->{_show_all} && 2]),
    $self->fade_current_color);
}

sub widget_click {
  my($self, $button) = @_;

  if($button == 1) {
    $self->{_show_all} ^= 1;
    $self->render;
  } elsif($button == 3) {
    system $self->core->main_config->{terminal}
      . " -e " . (config("commands", "top") || "top") . "&";
  }
}

1;
