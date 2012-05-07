package App::wmiirc::Ssh;
use 5.014;
use App::wmiirc::Plugin;
use File::stat;
with 'App::wmiirc::Role::Action';

=head2 NOTE

You may need to turn off the C<HashKnownHosts> option in F<~/.ssh/config>:

  echo HashKnownHosts no >> ~/.ssh/config

=cut

sub action_ssh {
  my($self, @args) = @_;
  state($last_mtime, @hosts);

  my $known_hosts = "$ENV{HOME}/.ssh/known_hosts";
  if(-r $known_hosts && !$last_mtime
      || $last_mtime != stat($known_hosts)->mtime) {
    open my $fh, "<", $known_hosts or die "$known_hosts: $!";
    @hosts = map /^([^, ]+)/ ? $1 : (), <$fh>;
  }

  if(my $host = @args ? "@args"
      : wimenu { name => "host:", history => "ssh" }, \@hosts) {
    system $self->core->main_config->{terminal} . " -e ssh $host &";
  }
}

1;
