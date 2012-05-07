package App::wmiirc::Screenshot;
use App::wmiirc::Plugin;
with 'App::wmiirc::Role::Action';

sub _screenshot {
  my($window) = @_;
  system sprintf config("commands", "screenshot",
    'import -window %s ~/$(date +screenshot-%%Y-%%m-%%d-%%H-%%M-%%S.png)'),
    $window;
}

sub action_screenshot {
  _screenshot("root");
}

sub action_screenshot_active {
  my $window_id = hex wmiir "/client/sel/ctl";
  _screenshot($window_id);
}

1;
