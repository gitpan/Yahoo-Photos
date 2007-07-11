package Yahoo::Photos::Album;
use 5.008;
use utf8;
use strict;
use warnings;
use Class::Spiffy qw(-base field);
use Perl::Version qw(); our $VERSION = Perl::Version->new('0.0.1')->stringify;

my @field_names = qw(id name url upload_url);
for my $field_name (@field_names) {
    field $field_name;
};

sub _new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    my %p = @_;
    foreach my $field_name (@field_names) {
        if (exists $p{$field_name}) {
            $self->$field_name($p{$field_name});
        };
    };

    return $self;
};

sub _merge {
    my $self = shift;
    my $album = shift;

    foreach my $field_name (@field_names) {
        if (!$self->$field_name) {
            $self->$field_name($album->$field_name);
        };
    };

    return $self;
};

1;

__END__

=head1 NAME

Yahoo::Photos::Album - Yahoo Photos album class

=head1 VERSION

This document describes Yahoo::Photos::Album version 0.0.1

=head1 SYNOPSIS

    print $album->id;
    print $album->name;

=head1 DESCRIPTION

This module represents an album on Yahoo Photos.

=head1 INTERFACE

=over

=item id

Returns the id associated with this album.
It is a short alphanumeric string like I<9ad5re2>.

=item name

Returns the name associated with this album.

=back

=encoding utf8
