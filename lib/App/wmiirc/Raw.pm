package App::wmiirc::Raw;
use App::wmiirc::Plugin;
with 'App::wmiirc::Role::Key';

sub event_focus_tag {
  my($self, $tag) = @_;
  if($tag =~ /^raw:/) {
    $self->core->dispatch("key_raw");

    my @keys = wmiir "/keys";
    my $modkey = config("keys", "modkey", "Mod4");
    my $exit_key = config("keys", "exit_raw", prototype \&key_exit_raw)
      =~ s/Modkey/$modkey/er;
    if(!grep $_ eq $exit_key, @keys) {
      push @keys, $exit_key;
      wmiir "/keys", @keys;
    }
  }
}

sub key_exit_raw(Modkey-q) {
  my($self) = @_;
  $self->core->dispatch("key_tag_swap");
}

*event_unfocus_tag = *event_unfocus_tag = *event_focus_tag;

1;
