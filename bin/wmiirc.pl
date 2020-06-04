#!/usr/bin/env perl
# ABSTRACT: Wmii should be configured to run this to use wmii-perl
package
  App::wmiirc::main;

# You probably don't want to make local customisations here.
# Instead: Write a plugin and load it in ~/.wmii/modules

use strictures 1;
use FindBin;
use lib "$FindBin::RealBin/../lib";

use App::wmiirc;

exit !App::wmiirc->new->run;
