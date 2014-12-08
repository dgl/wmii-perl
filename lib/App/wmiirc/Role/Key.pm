package App::wmiirc::Role::Key;
# ABSTRACT: A role for plugins which define key handlers
use 5.014;
use Moo::Role;
use App::wmiirc::Util;
use Scalar::Util ();
use experimental 'autoderef';

my %config = config("keys", {
  Modkey => scalar(config("config", "modkey", "Mod4")),
  up => "k",
  down => "j",
  left => "h",
  right => "l",
  DIR => '[up,down,left,right]',
  '#' => '[0-9]',
});

sub _getstash {
  no strict 'refs';
  return \%{ref(shift) . "::"};
}

sub BUILD {}
after BUILD => sub {
  my($self) = @_;
  # TODO: Support this properly rather than messing with core from a role.
  my %keys = %{$self->core->_keys};
  Scalar::Util::weaken($self);

  # Apologies, I seem to have invented yet another awful mini domain specific
  # language here.
  for my $subname(grep /^(?:action_|key_)/, keys _getstash($self)) {
    my $cv = _getstash($self)->{$subname};
    my $name = $subname =~ s/^key_//r;
    my $key = $config{$name} || prototype $cv;
    if(defined $key && $key =~ /^\+/ && prototype $cv) {
      $key =~ s/\+/prototype($cv) . ", "/e;
    }
    next unless $key;

    for my $key(split /,\s+/, $key) {
      for(keys %config) {
        $key =~ s/(^|-)\Q$_\E($|-)/$1$config{$_}$2/g;
      }
      # Expand [0-9], etc.
      $key =~ s/(\[[^]]*?)(.)-(.)/$1 . join "", $2..$3/eg;

      if(my($item) = $key =~ /\[([^]]+)\]/) {
        # This only handles one [] group, should be enough for now
        for my $expanded(split($key =~ m{[,/]} ? qr/,/ : qr//, $item)) {
          my $expanded_key = $expanded;
          if(exists $config{$expanded}) {
            $expanded_key = $config{$expanded}
          } elsif($expanded =~ m{/}) {
            # For Modkey-i[/irssi/] type hackery, but this is evil
            $expanded_key = "";
            $expanded =~ s{^/(.*)/$}{$1};
          }
          my $this_key = $key =~ s/\[.*?\]/$expanded_key/r;
          $keys{$this_key} = sub { $cv->($self, $expanded) };
        }
      } else {
        $keys{$key} = sub { $cv->($self) };
      }
    }
  }

  if($App::wmiirc::DEBUG) {
    require Data::Dump; Data::Dump::pp(\%keys);
  }

  wmiir "/keys", keys %keys;
  $self->core->_keys(\%keys);
};

1;
