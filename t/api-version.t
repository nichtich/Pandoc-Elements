use strict;
use Test::More 0.96; # for subtests

use Pandoc::Elements;

use constant PV => 'Pandoc::Version';

note '$Pandoc::Elements::PANDOC_VERSION ',            explain \$Pandoc::Elements::PANDOC_VERSION;
note '$Pandoc::Elements::PANDOC_API_VERSION ',        explain \$Pandoc::Elements::PANDOC_API_VERSION;
note '%Pandoc::Elements::PANDOC_API_VERSION_OF ',     explain \%Pandoc::Elements::PANDOC_API_VERSION_OF;
note '$Pandoc::Elements::PANDOC_EXE_VERSION_OF ',     explain \$Pandoc::Elements::PANDOC_EXE_VERSION_OF;
note '$Pandoc::Elements::PANDOC_LATEST_API_VERSION ', explain \$Pandoc::Elements::PANDOC_LATEST_API_VERSION;

local $Pandoc::Elements::PANDOC_VERSION = $Pandoc::Elements::PANDOC_VERSION;
local $Pandoc::Elements::PANDOC_API_VERSION = $Pandoc::Elements::PANDOC_API_VERSION;

$Pandoc::Elements::PANDOC_VERSION //= '1.18';
$Pandoc::Elements::PANDOC_API_VERSION //= '1.17.0.4';

isa_ok PANDOC_VERSION, PV, 'PANDOC_VERSION'; 
isa_ok PANDOC_API_VERSION, PV, 'PANDOC_API_VERSION'; 
isa_ok PANDOC_LATEST_API_VERSION, PV, 'PANDOC_LATEST_API_VERSION';
isa_ok $Pandoc::Elements::PANDOC_EXE_VERSION_OF, 'Hash::MultiValue', 'PANDOC_EXE_VERSION_OF';

isa_ok pandoc_version('1.16'), PV, 'pandoc_version()';
isa_ok pandoc_api_version_of('1.18'), PV, 'pandoc_api_version_of()';
isa_ok pandoc_exe_version_of('1.17.0.4'), PV, 'pandoc_exe_version_of()';

TODO: {
    todo_skip 'Behavior with out-of-range API versions undecided', 2;

    isa_ok pandoc_api_version_of('1.16'), PV, 'pandoc_api_version_of(PRE-1.18)';
    isa_ok pandoc_api_version_of('9999.999.999'), PV, "pandoc_api_version_of(INSANELY HIGH)";
}

is pandoc_api_version_of(pandoc_exe_version_of(PANDOC_LATEST_API_VERSION)), PANDOC_LATEST_API_VERSION, 'latest api/exe version roundtrip';

done_testing;
