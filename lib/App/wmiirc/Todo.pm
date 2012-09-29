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
  default => sub { '' },
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
    $self->_doing($todos[$text]);
    $text = _format_line($self->_doing);
    $text =~ s/\s+\[[^[]+\]$//;
  } else {
    $self->_doing($text);
  }

  $self->_start_time(time);
  $self->label($text);
}

sub action_done {
  my($self) = @_;
  open my $fh, '>>', "$ENV{HOME}/done" or die $!;
  print $fh "- ", (ref $self->{_doing} ? _format_line($self->{_doing}) : $self->{_doing}),
    " [$self->{_start_time}, ", time, "]\n";
  if(ref $self->{_doing}) {
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
      # Not found
      return 0;
    };
    my $line = $gen_sub->($todos);

    if($line) {
      open my $todo_in, '<', "$ENV{HOME}/todo" or die $!;
      open my $todo_out, '>', "$ENV{HOME}/.todo-new" or die $!;
      my $seen_line = 0;
      while(<$todo_in>) {
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
      }
      close $todo_in;
      close $todo_out or die $!;
      rename "$ENV{HOME}/todo", "$ENV{HOME}/.todo-bak";
      rename "$ENV{HOME}/.todo-new", "$ENV{HOME}/todo";
    } else {
      warn "Couldn't find item to remove\n";
    }
  }
  $self->_start_time(0);
  $self->_doing('');
  $self->label("?");
}

sub action_todo {
  my($self, $text) = @_;
  open my $fh, '>>', "$ENV{HOME}/todo" or die $!;
  print $fh "- $text\n";
}

sub widget_click {
  my($self, $button) = @_;

  given($button) {
    when(1) {
      if(!$self->{_doing}) {
        $self->action_do;
      } else {
        for my $doing(ref $self->{_doing}
            ? reverse @{$self->{_doing}} : $self->{_doing}) {
          if($doing =~ m{(https?://\S+|\w+/\S+)}) {
            my $url = $1;
            $url =~ s/\W$//;
            App::wmiirc::Dwim->action_default($url);
            last;
          }
        }
      }
    }
    when(3) {
      App::wmiirc::Dwim->action_default("~/todo");
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
