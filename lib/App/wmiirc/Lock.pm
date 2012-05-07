package App::wmiirc::Lock;
use App::wmiirc::Plugin;
with 'App::wmiirc::Role::Action';

sub action_lock {
  system config("commands", "lock", "xscreensaver-command -lock");
}

sub action_sleep(XF86PowerOff) {
  system config("commands", "sleep", "sudo pm-suspend");
}

sub action_hibernate {
  system config("commands", "hibernate", "sudo pm-hibernate");
}

# TODO: Less hacky / more supported way? Probably involves dbus.
# On arch I currently have the following in /etc/acpi/actions/lm_lid.sh:
# DISPLAY=:0 sudo -u dgl ~dgl/bin/wmiir xwrite /event Lid $3

sub event_lid {
  my($self, $type) = @_;
  if($type eq 'close') {
    system config("commands", "sleep", "sudo pm-suspend");
  }
}

1;
