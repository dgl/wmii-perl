package App::wmiirc::Role::Action;
# ABSTRACT: A role for plugins which define action handlers
use 5.014;
use Moo::Role;
use App::wmiirc::Util;
use Scalar::Util ();
use experimental 'autoderef';

# So actions can also have keyboard shortcuts
with 'App::wmiirc::Role::Key';

sub _getstash {
  no strict 'refs';
  return \%{ref(shift) . "::"};
}

sub BUILD {}
after BUILD => sub {
  my($self) = @_;

  Scalar::Util::weaken($self);
  for my $subname(grep /^action_/, keys _getstash($self)) {
    my $cv = _getstash($self)->{$subname};
    my $name = $subname =~ s/^action_//r;
    $self->core->_actions->{$name} = sub { $cv->($self, @_) };
  }
};

1;
