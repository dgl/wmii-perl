package App::wmiirc::Plugin;
# ABSTRACT: Imports modules a plugin needs.
use 5.014;
require Moo;
require App::wmiirc::Util;

sub import {
  # This runs in the plugin itself.
  eval qq{
    package @{[scalar caller 0]};
    BEGIN { Moo->import }
    with 'App::wmiirc::Role::Plugin';
    App::wmiirc::Util->import;
    1;
  } or die;
  feature->import(":5.14"); # TODO: does this work, seem to need use 5.014 too?
  strict->import;
  warnings->unimport('illegalproto');
}

1;
