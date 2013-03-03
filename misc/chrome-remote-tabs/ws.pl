#!/usr/bin/perl
use strict;
use Encode;
use IO::Async::Loop; # 0.55;
use JSON;
use Net::Async::WebSocket::Server 0.06;

my %c;
my $client;
my $id = 0;

my $server = Net::Async::WebSocket::Server->new(
  on_handshake => sub {
    my($self, $stream, $hs, $continuation) =  @_;
    my $ok = $stream->read_handle->peerhost =~ /^(?:\Q127.0.0.1\E|::1)$/;
    $ok &= $hs->req->origin =~ m{^chrome-extension://};
    $continuation->($ok);
  },
  on_client => sub {
    (undef, $client) = @_;
    $client->configure(
      on_frame => sub {
        my($self, $frame) = @_;
        my $d = from_json $frame;
        if(my $c = delete $c{$d->{id}}) {
          $c->write(encode_utf8 $frame . "\n");
        }
      },
    );
  }
);

my $loop = IO::Async::Loop->new;

my $listener = IO::Async::Listener->new(
  on_stream => sub {
    my(undef, $stream) = @_;

    $stream->configure(
      on_read => sub {
        my($self, $buffref, $eof) = @_;
        if($eof) {
          return;
        }

        my $d = from_json $$buffref;
        $d->{id} = ++$id;
        $c{$id} = $stream;
        return unless $client;
        $client->send_frame(to_json $d);
        $$buffref = "";
        return 0;
      },
    );

    $loop->add($stream);
  },
);

$loop->add($server);
$server->listen(
  host => "127.0.0.1", # Should support IPv6 one day, problem is I use the listening port
  # effectively as a lock, it's possible for one IPv6 and one IPv4 process to be listening.
  service => 3000,
  on_listen_error => sub { die "Cannot listen - $_[-1]" },
  on_resolve_error => sub { die "Cannot resolve - $_[-1]" },
);

$loop->loop_once;

$loop->add($listener);
unlink "/tmp/ch-$ENV{USER}";
umask 0077;
$listener->listen(
  addr => {
    family => "unix",
    path => "/tmp/ch-$ENV{USER}",
    socktype => 'stream',
  },
  on_listen_error => sub { die "Cannot listen - $_[-1]" },
);

$loop->run;
