package App::wmiirc::Role::Plugin;
use Moo::Role;

has core => (
  is => 'ro',
  required => 1,
);

1;
