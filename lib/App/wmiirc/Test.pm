package App::wmiirc::Test;
# Test core.
use parent 'App::wmiirc';

sub App::wmiirc::BUILD {
}

sub make {
  caller->new(core => __PACKAGE__->new);
}

sub run {
  my($self) = @_;
  $self->loop->run;
}

1;
