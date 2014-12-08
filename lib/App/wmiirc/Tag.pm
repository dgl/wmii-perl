package App::wmiirc::Tag;
# ABSTRACT: Keep track of tags
use App::wmiirc::Plugin;
with 'App::wmiirc::Role::Key';
use experimental 'autoderef';

has _last_tag => (
  is => 'rw'
);

has _urgent => (
  is => 'rw',
  default => sub { [] },
);

my %color;
sub BUILD {
  my($self) = @_;

  %color = map { $_ => "colors " .
    $self->core->main_config->{"${_}colors"} } qw(norm focus alert);

  # Create the tag bar
  wmiir "/lbar/$_", undef for wmiir "/lbar/";
  my($seltag) = wmiir "/tag/sel/ctl";

  for(wmiir "/tag/") {
    next if /sel/;
    s{/}{};
    $self->event_create_tag($_);
    $self->event_focus_tag($_) if $seltag eq $_;
  }
}

sub event_create_tag {
  my($self, $tag) = @_;
  wmiir "/lbar/$tag", $color{norm}, "label $tag";
}

sub event_destroy_tag {
  my($self, $tag) = @_;
  wmiir "/lbar/$tag", undef;
}

sub event_focus_tag {
  my($self, $tag) = @_;
  wmiir "/lbar/$tag", $color{focus};
}

sub event_unfocus_tag {
  my($self, $tag) = @_;
  $self->_last_tag($tag);
  wmiir "/lbar/$tag", $color{norm};
}

sub event_urgent {
  my($self, $id, $type) = @_;
  push @{$self->_urgent}, $id;
}

sub key_urgent(Modkey-Shift-A) {
  my($self) = @_;
  my $id = $self->_urgent->[0];
  return unless $id;
  # TODO: This is duplicated from Client.pm, rationalise
  my($tags) = wmiir "/client/$id/tags";
  if($tags) {
    wmiir "/ctl", "view $tags";
    wmiir "/tag/sel/ctl", "select client $id";
  }
}

sub event_not_urgent {
  my($self, $id, $type) = @_;
  $self->_urgent([grep $id ne $_, @{$self->_urgent}]);
}

sub event_urgent_tag {
  my($self, $type, $tag) = @_;
  my($cur) = wmiir "/tag/sel/ctl";

  # Avoid notifying for current window.
  # This relies on the order of events from wmii :(
  if($tag eq $cur) {
    my($cur_id) = wmiir "/client/sel/ctl";
    my $other = 0;
    for my $id(@{$self->_urgent}) {
      my(undef, @items) = wmiir "/client/$id/ctl";
      $other = 1 if $id ne $cur_id && grep /^urgent on/, @items;
    }
    return unless $other;
  }

  wmiir "/lbar/$tag", $color{alert};
}

sub event_not_urgent_tag {
  my($self, $type, $tag) = @_;
  my($cur) = wmiir "/tag/sel/ctl";
  wmiir "/lbar/$tag", $cur eq $tag ?  $color{focus} : $color{norm};
}

sub event_left_bar_click {
  my($self, $button, $tag) = @_;
  wmiir "/ctl", "view $tag";
}
*event_left_bar_dnd = \&event_left_bar_click;

sub key_tag_back(Modkey-comma) {
  my($self) = @_;
  $self->key_tag_next(-1);
}

sub key_tag_next(Modkey-period) {
  my($self, $dir) = @_;
  my($cur) = wmiir "/tag/sel/ctl";
  my $skip = "~";
  $skip = "\0" if $cur =~ /^$skip/;
  my @tags = sort grep !/^(?:sel$|$skip)/, map s{/$}{}r, wmiir "/tag/";
  @tags = reverse @tags if defined $dir && $dir == -1;

  my $l = "";
  for my $tag(@tags) {
    wmiir "/ctl", "view $tag" if $l eq $cur;
    $l = $tag;
  }
  # Wrap around
  wmiir "/ctl", "view $tags[0]" if $l eq $cur;
}

sub key_tag_num(Modkey-#) {
  my(undef, $num) = @_;
  my $tag = $num >= 1 ? $num - 1 : 9;
  my @tags = sort map s{/$}{}r, grep !/sel/, wmiir "/tag/";
  wmiir "/ctl", "view $tags[$tag]" if $tags[$tag];
}

sub key_retag_num(Modkey-Shift-#) {
  my(undef, $tag) = @_;
  wmiir "/client/sel/tags", $tag;
}

sub _tagmenu {
  my @tags = sort map s{/$}{}r, grep !/sel/, wmiir "/tag/";
  wimenu { name => "tag:", history => "tags" }, @tags;
}

sub key_tag_menu(Modkey-t) {
  my($self) = @_;
  my $tag = _tagmenu();
  wmiir "/ctl", "view $tag" if length $tag;
}

sub key_retag_menu(Modkey-Shift-t) {
  my($self) = @_;
  my $tag = _tagmenu();
  wmiir "/client/sel/tags", $tag if length $tag;
}

sub key_retag_go_menu(Modkey-Shift-r) {
  my($self) = @_;
  my $tag = _tagmenu();
  if(length $tag) {
    wmiir "/client/sel/tags", $tag;
    wmiir "/ctl", "view $tag";
  }
}

sub key_tag_swap(Modkey-Tab) {
  my($self) = @_;
  wmiir "/ctl", "view " .  $self->_last_tag if $self->_last_tag;
}

1;
