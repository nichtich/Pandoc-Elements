package Pandoc::Filter::ImagesFromCode;
use strict;
use parent 'Pandoc::Filter::CodeImage';

BEGIN { 
    warn __PACKAGE__ . " is DEPRECATED, renamed to Pandoc::Filter::CodeImage\n" 
}

1;
