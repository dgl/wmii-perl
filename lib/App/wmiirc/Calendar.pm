package App::wmiirc::Calendar;
use App::wmiirc::Plugin;
use IO::Async::Process;
use IO::Async::Timer::Absolute;
use IO::Async::Timer::Periodic;
use POSIX qw(mktime);
use Time::Piece;

has _event_timer => (
  is => 'rw'
);

has _events => (
  is => 'rw',
  default => sub { [] },
);

has _refresh_timer => (
  is => 'ro',
  default => sub {
    my($self) = @_;
    my $interval = config("calendar", "interval", 1800);
    (my $timer = IO::Async::Timer::Periodic->new(
      interval => $interval,
      # Add some randomness to avoid exactly on the hour, etc. but be near them.
      # Note this does make notifications for exactly midnight not work (along
      # with running 'google calendar today').  I mostly consider this a feature
      # (no notifications for all day events, ever).
      first_interval => int(rand 120) + $interval - time % $interval,
      reschedule => 'skip',
      on_tick => sub {
        $self->_update_events;
      },
    ))->start;
    $self->core->loop->add($timer);
    $timer;
  },
  lazy => 1,
);

with 'App::wmiirc::Role::Action';


sub BUILD {
  my($self) = @_;
  $self->_update_events;
}

sub action_calendar {
  my($self) = @_;
  my $t = localtime;
  my $today = sprintf "%s, %02d %s %d", $t->fullday, $t->mday, $t->fullmonth,
    $t->year;
  wimenu { i => undef, r => 10, p => $today },
    map _render_line($_), @{$self->_events} or return;

  # We can't easily open the right item, but open the calendar at least.
  $self->core->dispatch("action_default",
    scalar config("calendar", "url", "https://www.google.com/calendar/"));
}

sub action_rehash {
  my($self) = @_;
  $self->_update_events;
}

sub _update_events {
  my($self) = @_;
  my $stdout;
  $self->core->loop->add(IO::Async::Process->new(
      command => [ qw(google calendar today), "--fields=when,where,title" ],
      stdout => { into => \$stdout },
      on_finish => sub {
        my @events;
        for my $line(split /\n/, $stdout) {
          my($when, $where, $title) = split /,/, $line, 3;
          next unless $title;
          my($start, $end) = map Time::Piece->strptime((/(\d+:\d+)/)[0],
            "%H:%M"), split / - /, $when;
          my $t = localtime;
          my $today = mktime(0, 0, 0, $t->mday, $t->_mon, $t->_year);
          push @events, [ $start + $today, $end + $today, $title, $where ];
        }
        $self->_events([sort @events]);
        $self->_update_next_event;
        # Ensure timer is initialized (a race probably wouldn't matter, but
        # avoid anyway by doing this here, side-effects be damned).
        $self->_refresh_timer;
      }
    ));
}

sub _update_next_event {
  my($self) = @_;
  my $reminder = config("calendar", "reminder", 300);
  my $t = localtime;

  if(my @events = grep $_->[0] - $reminder > $t, @{$self->_events}) {
    $self->_event_timer->stop if $self->_event_timer;
    $self->core->loop->add(my $timer = IO::Async::Timer::Absolute->new(
      time => $events[0]->[0]->epoch - $reminder,
      on_expire => sub {
        $self->core->dispatch("event_msg", _render_line($events[0]));
        $self->_update_next_event;
      }
    ));
    $self->_event_timer($timer);
  }
}

sub _render_line {
  my($event) = @_;
  sprintf "%02d:%02d-%02d:%02d: %s (%s)", $event->[0]->hour, $event->[0]->min,
    $event->[1]->hour, $event->[1]->min, $event->[2], $event->[3];
}

1;
