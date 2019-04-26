#! /usr/bin/env ruby
#
require 'mkmf'

$OUTFLAG = ' -o ../'

create_makefile('loader')
