package App::wmiirc::Reminder;
use App::wmiirc::Plugin;
with 'App::wmiirc::Role::Action';

sub action_reminder {
  my($self, $time, @message) = @_;

  if(!$time) {
    warn "Usage: reminder time [message]\n";
    return;
  }

  my $message = @message ? "@message" : wmiir "/client/sel/label";
  $message =~ s/(['"\\])/'\\$1'/g; # shell escape

  system "(sleep $time && wmiir xwrite /event MsgUrgent '$message')&";
}

1;
