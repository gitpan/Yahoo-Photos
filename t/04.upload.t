#!perl -T
use strict;
use warnings;
use List::Util qw(first);
use Test::More;
use Test::Exception;
use Yahoo::Photos qw();

if (-f Yahoo::Photos->credfile) {
    plan tests => 10;
} else {
    plan skip_all => 'No credentials file set up for testing';
};

my $yp = Yahoo::Photos->new(
#    credentials => undef,
cookie => '/home/daxim/.mozilla/firefox/wtl4dmcx.default/cookies.txt',
);

dies_ok {
    $yp->upload;
} 'naked upload';

dies_ok {
    $yp->upload(
        album => undef,
    );
} 'no album';

dies_ok {
    $yp->upload(
        album => 1,
    );
} 'no files';

dies_ok {
    $yp->upload(
        album => 1,
        files => undef,
    );
} 'files is not aref';

dies_ok {
    $yp->upload(
        album => 1,
        files => {},
    );
} 'files still not aref';

diag "The following warning is okay.\n";
dies_ok {
    $yp->upload(
        album => 1,
        files => [],
        at_a_time => 'foo',
    );
} 'wacky at_a_time';

dies_ok {
    $yp->upload(
        album => 1,
        files => [],
        at_a_time => -2.5,
    );
} 'at_a_time too small';

dies_ok {
    $yp->upload(
        album => 1,
        files => [],
        at_a_time => 20,
    );
} 'at_a_time too big';

SKIP: {
    my $img = "$ENV{HOME}/.yahoo/Camel_berlin_2004.jpg";
    skip '-- no image', 2 unless -e $img;

    my $album = $yp->create_album(
        name => 'Camel',
        over_18_only => 1,
        restrict_prints => 1,
    );
    lives_ok {
        $yp->upload(
            album => $album,
            files => [$img],
        );
    } 'upload';

    {
        my $id = $album->id;
        $album = first {$id eq $_->id} $yp->albums;
    };

    $yp->verbose(1);

    lives_ok {
        $yp->upload(
            album => $album,
            files => [$img],
        );
    } 'verbose upload to album without upload_url';

    $yp->delete_album($album);
};
