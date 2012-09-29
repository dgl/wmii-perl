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

sub key_kbd_backlight_down(XF86KbdBrightnessDown) {
  system qw(gksudo -- sh -c), "echo 0 > /sys/devices/platform/applesmc.768/leds/smc::kbd_backlight";
}

sub key_kbd_backlight_up(XF86KbdBrightnessUp) {
  system qw(gksudo -- sh -c), "echo 4 > /sys/devices/platform/applesmc.768/leds/smc::kbd_backlight";
}

1;
