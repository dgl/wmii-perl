package App::wmiirc::Network;
# So network manager annoys me, this is a pretty lame replacement and certainly
# not "just works", but suits my purposes. YMMV
use 5.016;
use App::wmiirc::Plugin;
use IO::Async::Timer::Periodic 0.50;

has name => (
  is => 'ro',
  default => sub { "network" },
);

has _show_extra => (
  is => 'rw',
  default => sub { 0 },
);

with 'App::wmiirc::Role::Widget';

my %config = config('network', {
    device => 'wlan0',
  }
);

sub BUILD {
  my($self) = @_;

  my $timer = IO::Async::Timer::Periodic->new(
    interval => 30,
    on_tick => sub {
      $self->render;
    },
    reschedule => 'skip',
  );

  $self->render;
  $self->core->loop->add($timer);
  $timer->start;
}

sub render {
  my($self) = @_;

  if(!$self->{_show_extra}) {
    my $info = qx{iwconfig $config{device}};
    my($essid, $off) = $info =~ /ESSID:(?:"(.*?)"|(off))/;
    my($rate) = $info =~ /Bit Rate=(\d+)/;
    my($ap) = $info =~ /Access Point: (.*?)$/m;

    my $unassociated = $ap =~ /:/ ? "" : " [N/A]";
    $self->label($off ? "." : "$essid (${rate}M)$unassociated");
  } else {
    my($gateway) = qx{ip route show 0/0 dev $config{device}} =~ m{via (\S+)};
    my($ip) = qx{ip addr show dev $config{device} scope global} =~ m{inet ([^/]+)};

    # TODO: ping time to $gateway?
    $self->label($ip);
  }
}

sub widget_click {
  my($self, $button) = @_;

  given($button) {
    when(1) {
      my $network = wimenu { name => "network:", history => "ssid" },
        map { /ESSID:"(.*)"/ ? $1 : () } qx{iwlist $config{device} scan};
      if(defined $network) {
        $network = "'$network'";
        system "wifi-up $network &";
      }
    }
    when(2) {
      system "(ifconfig $config{device}; iwconfig $config{device}) | xmessage -default okay -file -&";
    }
    when(3) {
      $self->{_show_extra} ^= 1;
      $self->render;
    }
  }
}

1;
