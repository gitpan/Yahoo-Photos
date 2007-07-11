#!perl -T
use strict;
use warnings;
use List::Util qw(first);
use Test::More;
use Test::Exception;
use Yahoo::Photos qw();

if (-f Yahoo::Photos->credfile) {
    plan tests => 11;
} else {
    plan skip_all => 'No credentials file set up for testing';
};

my $yp = Yahoo::Photos->new(
#    credentials => undef,
cookie => '/home/daxim/.mozilla/firefox/wtl4dmcx.default/cookies.txt',
);

dies_ok {
    my $album = $yp->create_album(
        access => 'foo',
    );
} 'invalid access';

dies_ok {
    my $album = $yp->create_album(
        yahoo_ids => 'foo',
    );
} 'invalid yahoo_ids';

dies_ok {
    my $album = $yp->create_album(
        yahoo_ids => {},
    );
} 'invalid yahoo_ids';

dies_ok {
    $yp->delete_album;
} 'album missing';

{
    my $album;
    lives_ok {
        $album = $yp->create_album;
    } 'create an album';

    {
        my @albums = $yp->albums;
        my $id = first {$_ eq $album->id} map {$_->id} @albums;
        ok $id, 'found album id';
        my $name = first {$_ eq $album->name} map {$_->name} @albums;
        ok $name, 'found album name';
    };

    lives_ok {
        $yp->delete_album($album);
    } 'deleted an album';

    {
        my @albums = $yp->albums;
        my $id = first {$_ eq $album->id} map {$_->id} @albums;
        ok !$id, 'did not find album id anymore';
        my $name = first {$_ eq $album->name} map {$_->name} @albums;
        ok !$name, 'did not find album name anymore';
    };
};

{
    my $album;
    lives_ok {
        $album = $yp->create_album(
            access => 'friends_only',
            yahoo_ids => ['foo'],
        )
    } 'create album with yahoo_ids';
    $yp->delete_album($album);
};
