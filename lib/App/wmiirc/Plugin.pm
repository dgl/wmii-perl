package App::wmiirc::Plugin;
# ABSTRACT: Imports modules a plugin needs.
use 5.014;
use Moo::Role;
require Moo;
require App::wmiirc::Util;

has core => (
  is => 'ro',
  required => 0, # TODO: something means this doesn't work
);

sub import {
  # This runs in the plugin itself.
  eval qq{
    package @{[scalar caller 0]};
    BEGIN { Moo->import }
    with 'App::wmiirc::Plugin';
    App::wmiirc::Util->import;
    1;
  } or die;
  feature->import(":5.14"); # TODO: does this work, seem to need use 5.014 too?
  strictures->import(1);
  warnings->unimport('illegalproto');
}

1;
