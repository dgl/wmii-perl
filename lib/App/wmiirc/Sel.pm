package App::wmiirc::Sel;
use App::wmiirc::Plugin;
use URI;
with 'App::wmiirc::Role::Action';

has data => (
  is => 'ro',
  default => sub { [] },
);

my %canonical = config("urls", {});

sub action_save {
  my($self, $arg) = @_;

  my $data;
  if($arg) {
    $data = $arg;
  } else {
    open my $fh, "-|", "xsel" or die $!;
    $data = join "", <$fh>;
  }
  $data =~ s/\n+/\n/g;
  $data =~ s/\n$//s;
  my $canonical = _canonicalise($data);
  if($canonical && $canonical ne $data) {
    $data = $canonical;
    open my $in_fh, "|-", "xsel", "-i" or die $!;
    print $in_fh $data
  }
  open my $out_fh, ">>", "$ENV{HOME}/.sels";
  print $out_fh "-[", time, "] $data\n";
  push $self->data, $data;
}

sub action_restore {
  my($self) = @_;
  my $item = wimenu { name => "sel", r => 10, i => undef },
    @{$self->data}[(@{$self->data} > 10 ? -10 : -@{$self->data}) .. -1];
  if($item) {
    open my $fh, "|-", "xsel", "-i" or die $!;
    print $fh $item;
  }
}

sub _canonicalise {
  my $uri = URI->new(shift);
  if($uri) {
    for my $re(keys %canonical) {
      if($uri =~ $re) {
        my %c = %+;
        return $canonical{$re} =~ s/\$(\w+)/$c{$1}/gr;
      }
    }
  }
  return;
}

1;
