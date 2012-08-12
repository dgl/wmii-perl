package App::wmiirc::Debug;
use App::wmiirc::Plugin;
use Data::Dump qw(pp);
use Eval::WithLexicals;
use Fcntl;
use IO::Pty;

has name => (
  is => 'ro',
  default => sub { 'debug' }
);

with 'App::wmiirc::Role::Action';
with 'App::wmiirc::Role::Widget';

sub BUILD {
  my($self) = @_;
  $self->label("d");
}

sub widget_click {
  my($self, $button) = @_;

  my $eval = Eval::WithLexicals->new(
    lexicals => {
      '$self' => \$self,
      '$core' => \$self->core,
      '$loop' => \$self->core->loop
    },
    in_package => 'D',
  );

  my $pty = IO::Pty->new;

  $self->core->loop->open_child(
    command => ["urxvt", "-title" => "wmiirc-debug", "-pty-fd" => 3],
    setup => [
      fd3 => $pty
    ],
    on_finish => sub {
      undef $pty;
    }
  );

  close $pty;

  my $stream = IO::Async::Stream->new(
    handle => $pty->slave,
    on_read => sub {
      my($self, $buf, $eof) = @_;

      while($$buf =~ s/^(.*\n)//) {
        my $str = $1;
        my @warnings;
        my @ret;
        my $evalret = eval {
          local $SIG{__WARN__} = sub {
            push @warnings, @_;
          };
          @ret = $eval->eval($str);
          1;
        };

        $self->write($_) for @warnings;
        $self->write((!defined $evalret && $@ ? $@ : pp @ret) . "\n$0> ");
      }
    },
  );

  $self->core->loop->add($stream);
  $stream->write("$0> ");
}
*action_debug = *action_debug = *widget_click;

{ package # avoid indexing
  D;

  use App::wmiirc::Util;
}

1;
