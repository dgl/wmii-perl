# ABSTRACT: Wolfram Alpha integration
package App::wmiirc::Wolframalpha;
use 5.014;
use App::wmiirc::Plugin;
use URI::Escape qw(uri_escape_utf8);
use WWW::WolframAlpha;
with 'App::wmiirc::Role::Action';

has wa => (
  is => 'ro',
  lazy => 1,
  default => sub {
    WWW::WolframAlpha->new(appid => config('wolframalpha', 'appid'))
  },
);


sub action_wolframalpha {
  my($self, @input) = @_;
  my $wa = $self->wa;

  $self->core->loop->run_child(
    code => sub {
      my $query = $wa->query(input => "@input");
      if($query->success) {
        my @out;
        for my $pod(@{$query->{pods}}) {
          for my $subpod(@{$pod->subpods}) {
            next unless $subpod->plaintext;
            push @out, $subpod->plaintext;
          }
        }
        return defined wimenu { i => undef, r => 10, p => "@input" }, @out;
      } else {
        print STDERR $wa->errmsg;
        return 0;
      }
    },
    on_finish => sub {
      my(undef, $exitcode, $stdout, $stderr) = @_;
      if($stderr) {
        warn "WolframAlpha query failed: $stderr";
      }
      if($exitcode) {
        $self->core->dispatch("action_default",
          "http://www.wolframalpha.com/input/?i=" . uri_escape_utf8("@input"));
      }
    },
  );
};

{
  no strict 'refs';
  *{"action_="} = *action_wolframalpha;
}

if(!caller) {
  require App::wmiirc::Test;
  my $self = App::wmiirc::Test->make;
  $self->action_wolframalpha(@ARGV);
  $self->core->run;
}

1;
