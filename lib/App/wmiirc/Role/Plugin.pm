package App::wmiirc::Role::Plugin;
use Moo::Role;

has core => (
  is => 'ro',
  required => 0, # TODO: something means this doesn't work
);

1;
