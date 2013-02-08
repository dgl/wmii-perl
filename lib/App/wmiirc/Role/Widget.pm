package App::wmiirc::Role::Widget;
# ABSTRACT: A role for plugins which add an rbar item
use Moo::Role;
use App::wmiirc::Util;

requires 'name';

sub BUILD {}
before BUILD => sub {
  my($self) = @_;

  wmiir "/rbar/" . $self->name,
    "colors " . $self->core->main_config->{normcolors};
};

sub label {
  my($self, $text, $color) = @_;
  if(not defined $text) {
    return +(map s/^label //r, grep /^label /, wmiir "/rbar/" . $self->name)[0];
  }

  $color //= $self->core->main_config->{normcolors};

  wmiir "/rbar/" . $self->name, "label $text", "colors $color";
}

sub event_right_bar_click {
  my($self, $button, $item) = @_;
  return unless $item eq $self->name;

  if($self->can("widget_click")) {
    $self->widget_click($button, $item);
  }
}

1;
