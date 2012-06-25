package App::wmiirc::Unlock;
use App::wmiirc::Plugin;

sub event_session_active {
  my $run = config("commands", "session_active");
  system $run if $run;
}

1;
