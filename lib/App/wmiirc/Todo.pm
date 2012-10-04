package App::wmiirc::Todo;
use 5.014;
use App::wmiirc::Plugin;
use Fcntl qw(SEEK_SET);

has name => (
  is => 'ro',
  default => sub { '!todo' }
);

has _doing => (
  is => 'rw',
  default => sub { undef },
);

has _start_time => (
  is => 'rw',
  default => sub { 0 },
);

with 'App::wmiirc::Role::Action';
with 'App::wmiirc::Role::Widget';


sub BUILD {
  my($self) = @_;
  $self->label("?");
}

sub rewrite_todo(&) {
  my($code) = @_;
  open my $todo_in, '<', "$ENV{HOME}/todo" or die $!;
  open my $todo_out, '>', "$ENV{HOME}/.todo-new" or die $!;
  while(<$todo_in>) {
    $code->($todo_out);
  }
  close $todo_in;
  close $todo_out or die $!;
  rename "$ENV{HOME}/.todo-new", "$ENV{HOME}/todo";
}

sub action_do {
  my $self = shift;
  my $text = "@_";

  if(!$text) {
    open my $fh, '<', "$ENV{HOME}/todo" or die $!;
    my $i = 0;
    my @todos = order_todos($fh);
    my @formatted_todos = map { _format_line($_) . "!!" . $i++ } @todos;
    $text = wimenu { name => "do", r => 10, S => '!!', i => undef }, @formatted_todos;
    return unless defined $text;
    if($todos[$text]) {
      $self->_doing($todos[$text]);
      $text = _format_line($self->_doing);
      $text =~ s/\s+\[[^[]+\]$//;
    } else {
      $self->_doing($text);
    }
  } else {
    $self->_doing($text);
  }

  if(!ref $self->{_doing}) {
    $text ||= $self->{_doing};
    rewrite_todo {
      my($todo_out) = @_;
      if($. == 1) {
        print $todo_out "- $text\n";
      }
      print $todo_out $_;
    };
    $self->_doing([$text]);
  }

  $self->_start_time(time);
  $self->label($text);
}

sub action_done {
  my($self) = @_;
  open my $fh, '>>', "$ENV{HOME}/done" or die $!;
  print $fh "- ", _format_line($self->{_doing})
    . " [$self->{_start_time}, ", time, "]\n";

  my @doing = @{$self->{_doing}};
  open my $todo_in, '<', "$ENV{HOME}/todo" or die $!;
  my $todos = parse_todos($todo_in);
  my $gen_sub; $gen_sub = sub {
    my($todos) = @_;
    for my $item(@$todos) {
      if($item->[0] eq $doing[0]) {
        shift @doing;
        if(@doing) {
          return $gen_sub->($item->[2]);
        } elsif(@{$item->[2]}) {
          warn "Still items below this\n";
          return 0;
        } else {
          return $item->[1];
        }
      }
    }
    warn "Couldn't find item to remove\n";
    return 0;
  };

  if(my $line = $gen_sub->($todos)) {
    my $seen_line = 0;
    rewrite_todo {
      my($todo_out) = @_;

      if($. == $line) {
        $seen_line = 1;
      } elsif($seen_line) {
        if(/^\s*-/) {
          $seen_line = 0;
          print $todo_out $_;
        }
      } else {
        print $todo_out $_;
      }
    };
  }
  $self->_start_time(0);
  $self->_doing(undef);
  $self->label("?");
}

sub action_todo {
  my $self = shift;
  my $text = "@_";
  if(!$text) {
    if(!$self->core->dispatch("key_goto_regex", qr/^todo \(~\)/)) {
      $self->core->dispatch("action_default", "~/todo");
    }
  } else {
    open my $fh, '>>', "$ENV{HOME}/todo" or die $!;
    print $fh "- $text\n";
  }
}

sub widget_click {
  my($self, $button) = @_;

  given($button) {
    when(1) {
      if(!$self->{_doing}) {
        $self->action_do;
      } else {
        for my $doing(reverse @{$self->{_doing}}) {
          if($doing =~ m{(https?://\S+|\w+/\S+)}) {
            my $url = $1;
            $url =~ s/\W$//;
            $self->core->dispatch("action_default", $url);
            last;
          }
        }
      }
    }
    when(3) {
      $self->action_todo;
    }
  }
}

sub parse_todos {
  my($fh) = @_;

  my @ret;
  my $size = 0;
  my $li = 0;
  # top level
  my $items = [];

  # something witty about how lisp would do this here
  my @nested;
  while(<$fh>) {
    if(/^(\s*)- (.*)/) {
      $size ||= length $1;
      my $text = $2;

      my $indent = $size ? length($1) / $size : 0;

      if($li > $indent) {
        while($li > $indent) {
          $li--;
          $items = pop @nested;
        }
      } elsif($indent > $li) {
        $li++;
        push @nested, $items;
        $items = $items->[-1]->[2];
      }

      push @$items, [ $text, $., [] ];
    }
  }

  # Unwind, but save some effort
  $items = $nested[0] if @nested;
  @nested = ();
  return $items;
}

sub order_todos {
  my($fh) = @_;
  my $items = parse_todos($fh);
  my @leaves = find_leaves($items, []);
  map { [ reverse(@{$_->[1]}), $_->[0] ] } @leaves;
}

sub find_leaves {
  my($items, $path) = @_;
  my @leaves;
  for my $item(@$items) {
    if(!@{$item->[2]}) {
      push @leaves, [ $item->[0], $path ];
    } else {
      push @leaves, find_leaves($item->[2], [ $item->[0], @$path ]);
    }
  }
  return @leaves;
}

sub _format_line {
  my($item) = @_;
  $item->[-1] . (@$item[0 .. $#$item - 1] ?
    " [" . join(", ", reverse @$item[0 .. $#$item - 1]) . "]" : "");
}

1;
__END__

=head1 DESCRIPTION

This is a fairly dumb todo list management thing, the main idea is to have a
quick way of picking tasks and marking them as done.

The todo list should look something like:

  - wmii-perl
    - Write todo plugin
      - Documentation
    - Fix something
      Longer comment here

When you invoke C<Mod4-a do> you will be given a list of the leaf nodes from the
tree, i.e. in the above list I<Documentation> is the first option that will be
given. Once an option is selected the wmii status bar will display it, then
C<Mod4-a done> will mark it as done or C<Mod4-a do> will change what you are
working on.

=head2 Vim setup

It's assumed you'll do most editing via your editor or other methods, but want
wmii-perl to be able to edit the list too. Therefore this works best when your
editor automatically saves and loads the todo file.

With Vim something like the following in F<.vimrc> works nicely (you can
probably delete the C<checkt> parts if you only use gvim):

  au CursorHold,CursorHoldI ~/todo checkt | if &modified | write | endif
  au CursorMoved,CursorMovedI ~/todo checkt
  au InsertEnter ~/todo checkt
  au BufRead ~/todo set ar aw

=cut
