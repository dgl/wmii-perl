#!/usr/bin/perl
# You probably don't want to make local customisations here.
# Instead: Write a plugin and load it in ~/.wmii/modules

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

use App::wmiirc;

exit !App::wmiirc->new->run;
