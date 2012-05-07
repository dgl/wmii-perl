package App::wmiirc::Backlight;
use App::wmiirc::Plugin;
with 'App::wmiirc::Role::Key';

# So on my vaio the down works here, but up doesn't(?!), I've hacked it into the
# acpi stuff instead -- urgh. Serves me right for buying proprietary Sony stuff
# I guess.

sub key_backlight_down(XF86MonBrightnessDown) {
  system qw(xbacklight -steps 1 -time 0 -dec 10);
}

sub key_backlight_up(XF86MonBrightnessUp) {
  system qw(xbacklight -steps 1 -time 0 -inc 10);
}

1;
