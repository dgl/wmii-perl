# ABSTRACT: A default action that does something useful (hopefully)
package App::wmiirc::Dwim;
use Const::Fast;
use Net::Async::HTTP;
use User::pwent;
use URI::Escape qw(uri_escape_utf8);
use App::wmiirc::Plugin;
with 'App::wmiirc::Role::Action';

const my $SEARCH_DOMAIN_FINDER =>
  'https://www.google.com/searchdomaincheck?format=url&type=wmii-perl';

has search_domain => (
  is => 'rw',
  default => sub {
    "https://www.google.com/",
  },
);

my %aliases = config("alias", {});

for my $alias(keys %aliases) {
  my $target = $aliases{$alias};

  _getglob("action_$alias") = sub {
    my($self, @args) = @_;
    $self->action_default(sprintf $target, uri_escape_utf8 "@args");
  };
}

sub BUILD {
  my($self) = @_;
  $self->_search_domain;
}

sub action_xsel(Modkey-o) {
  my($self, @args) = @_;
  open my $fh, "-|", "xsel", "-o";
  my $selection = join "", <$fh>;
  $self->action_default($selection, @args);
}

sub action_default {
  my($self, $action, @args) = @_;

  if($action =~ m{^[/~]}) {
    # A file?
    my $file = $action =~ s{^~([^/]*)}{$1 ?
      (getpwnam($1) || die "No such user: $1\n")->dir : $ENV{HOME}}re;

    if(-d $file) {
      # TODO: Use xdg-open stuff?
      system config("commands", "file_manager") . " '$file'&";
    } else {
      system config("commands", "editor") . " '$file'&";
    }
  } elsif($action =~ m{^\w+://}) {
    system config("commands", "browser") . " '$action'&";
  } elsif($action =~ m{^[\w.+-]+@}) {
    $action =~ s/\@$//; # so I can type foo@ but it gets parsed properly
    system config("commands", "mail") . " '$action'&";
  } else {
    my($host, $rest) = split m{/}, $action, 2;

    if(defined $host && exists $aliases{$host}) {
      system config("commands", "browser") . " '" .
          sprintf($aliases{$host}, uri_escape_utf8 "$rest@args") . "'&";
    } else {
      my $search = sub {
        system config("commands", "browser") . " '" . $self->search_domain .
            "search?q=" . uri_escape_utf8(join " ", $action, @args) . "'&";
      };
      my $browser = sub {
        system config("commands", "browser") . " 'http://$action'&";
      };

      if($host =~ /^\S+:\d+/) {
        $browser->();
      } elsif($host !~ / /) {
        $self->core->loop->resolver->getaddrinfo(
          host => $host,
          service => "http",
          on_resolved => $browser,
          on_error => $search);
      } else {
        $search->();
      }
    }
  }
}

sub _search_domain {
  my($self) = @_;

  my $http = Net::Async::HTTP->new;
  $self->core->loop->add($http);
  $http->do_request(
    uri => URI->new($SEARCH_DOMAIN_FINDER),
    on_response => sub {
      my($response) = @_;
      $self->search_domain($response->content);
      $self->core->loop->remove($http);
    },
    on_error => sub {
      my($message) = @_;
      warn "Couldn't fetch search domain: $message\n";
      $self->core->loop->remove($http);
    },
 );
}

sub _getglob :lvalue {
  no strict 'refs';
  *{shift()};
}

1;
