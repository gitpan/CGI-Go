use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'CGI::Go',
    AUTHOR              => q{Brian Medley <freesoftware@bmedley.org>},
    VERSION_FROM        => 'lib/CGI/Go.pm',
    ABSTRACT_FROM       => 'lib/CGI/Go.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'CGI-Go-*' },
);
