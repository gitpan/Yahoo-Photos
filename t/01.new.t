#!perl
# File::Temp not taint-safe, suck
use strict;
use warnings;
use Test::More tests => 18;
use Test::Exception;

use Yahoo::Photos qw();

dies_ok {
    Yahoo::Photos->new
} 'naked new';

dies_ok {
    Yahoo::Photos->new(
        'foo' => 'bar',
    );
} 'invalid new';

dies_ok {
    Yahoo::Photos->new(
        'login' => undef,
        'cookie' => undef,
    );
} 'multiple constructor params - first pair';

dies_ok {
    Yahoo::Photos->new(
        'credentials' => undef,
        'login' => undef,
    );
} 'multiple constructor params - second pair';

dies_ok {
    Yahoo::Photos->new(
        'credentials' => undef,
        'cookie' => undef,
    );
} 'multiple constructor params - third pair';

dies_ok {
    Yahoo::Photos->new(
        'credentials' => undef,
        'cookie' => undef,
        'login' => undef,
    );
} 'multiple constructor params - three at a time';

dies_ok {
    Yahoo::Photos->new(
        login => undef,
    );
} 'naked login';

dies_ok {
    Yahoo::Photos->new(
        login => {
            pass => 1,
        },
    );
} 'no user';

dies_ok {
    Yahoo::Photos->new(
        login => {
            user => 1,
        },
    );
} 'no pass';

dies_ok {
    Yahoo::Photos->new(
        login => {
            user => 'fnurdle',
            pass => 'gibberty',
        },
    );
} 'invalid login';

dies_ok {
    Yahoo::Photos->new(
        credentials => 'THIS-FILE-DOES-NOT-EXIST',
    );
} 'bad credentials file';

use YAML qw(DumpFile);
use File::Temp qw(tempfile);

{
    my ($fh, $fn) = tempfile(UNLINK => 1);
    DumpFile $fh, q{};

    dies_ok {
        Yahoo::Photos->new(
            credentials => $fn,
        );
    } 'bad credentials';
};

{
    my ($fh, $fn) = tempfile(UNLINK => 1);
    DumpFile $fh, {user => 'fnurdle'};

    dies_ok {
        Yahoo::Photos->new(
            credentials => $fn,
        );
    } 'no pass in credentials';
};

{
    my ($fh, $fn) = tempfile(UNLINK => 1);
    DumpFile $fh, {pass => 'gibberty'};

    dies_ok {
        Yahoo::Photos->new(
            credentials => $fn,
        );
    } 'no user in credentials';
};

SKIP: {
    skip '-- no credentials file set up for testing', 1 unless -f Yahoo::Photos->credfile;

    my $yp = Yahoo::Photos->new(
        credentials => undef,
    );
    ok $yp, 'login with prepared credentials';
};

dies_ok {
    Yahoo::Photos->new(
        cookie => undef,
    );
} 'no cookie file';

dies_ok {
    Yahoo::Photos->new(
        cookie => 'THIS-FILE-DOES-NOT-EXIST',
    );
} 'cookie file missing';

SKIP: {
    my ($fh, $fn) = tempfile(UNLINK => 1);
    skip '-- could not make tmp file unreadable', 1
        unless chmod 0000, $fn;

    dies_ok {
        Yahoo::Photos->new(
            cookie => $fn,
        );
    } 'cannot read cookie file';
    chmod 0644, $fn;
};

