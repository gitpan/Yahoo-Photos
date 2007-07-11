package Yahoo::Photos;
use 5.008;
use utf8;
use strict;
use warnings;
use Carp qw(croak);
use Class::Spiffy qw(-base field const);
use File::HomeDir qw();
use File::Spec::Functions qw(catfile);
use HTTP::Cookies::Netscape qw();
use List::Util qw(first);
use Perl::Version qw(); our $VERSION = Perl::Version->new('0.0.1')->stringify;
use Readonly qw(Readonly);
use WWW::Mechanize qw();
use Yahoo::Photos::Album qw();
use YAML qw(LoadFile);

Readonly our $PHOTOS_START => 'http://photos.yahoo.com/';
Readonly our $LOGIN_START => 'https://login.yahoo.com/';
Readonly our $LOGIN_FAIL => 'https://login.yahoo.com/config/login?';

field 'user';
field 'pass';
field 'mech';
field 'verbose';

const 'credfile' => catfile(
    File::HomeDir->my_data,
    '.yahoo',
    'credentials.yaml',
);

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    my %param = @_;

    if (
        (exists $param{login} and exists $param{credentials})
    or
        (exists $param{login} and exists $param{cookie})
    or
        (exists $param{credentials} and exists $param{cookie})
    ) {
        croak 'decide on one way build the constructor: login or credentials or cookie';
    };

    if (exists $param{login}) {
        if (!$param{login}->{user}) {
            croak 'no user in login';
        };
        $self->user($param{login}->{user});

        if (!$param{login}->{pass}) {
            croak 'no pass in login';
        };
        $self->pass($param{login}->{pass});

        $self->_mech_login;
    } elsif (exists $param{credentials}) {
        my $cred;
        if ($param{credentials}) {
            $cred = LoadFile($param{credentials});
        } else {
            $cred = LoadFile($self->credfile);
        };

        if (!$cred->{user}) {
            croak 'no user in credentials file';
        };
        $self->user($cred->{user});

        if (!$cred->{pass}) {
            croak 'no pass in credentials file';
        };
        $self->pass($cred->{pass});

        $self->_mech_login;
    } elsif (exists $param{cookie}) {
        if (!$param{cookie}) {
            croak 'no cookie file path given';
        };
        if (!-f $param{cookie}) {
            croak 'cookie file does not exist';
        };
        if (!-r $param{cookie}) {
            croak 'cookie file not readable';
        };

        $self->mech(
            WWW::Mechanize->new(
                autocheck  => 1,
                cookie_jar => HTTP::Cookies::Netscape->new(
                    file     => $param{cookie},
                    autosave => 1,
                ),
            )
        );
    } else {
        croak 'no login or cookie or credentials in constructor';
    };

    return $self;
};

sub _mech_login {
    my $self = shift;

    my $mech = WWW::Mechanize->new(
        autocheck => 1,
    );

    $mech->get($LOGIN_START);
    $mech->submit_form(with_fields => {
        login  => $self->user,
        passwd => $self->pass,
        '.persistent' => 'y',
    });

    if ($mech->uri eq $LOGIN_FAIL) {
        croak 'wrong user or pass';
    };

    $self->mech($mech);

    return;
};

sub albums {
    my $self = shift;
    $self->mech->get($PHOTOS_START);

    return # a list of ...
    map {
        my %p;
        ($p{id}) = $_->url_abs =~ m{
            /album
            \?          # literal question mark
            \.          # literal dot
            dir=
            ([a-z0-9]+) # capture album id
            &
        }msx;
        $p{url} = $_->url_abs;
        $p{name} = $_->attrs->{title};
        Yahoo::Photos::Album->_new(%p); # ... albums
    } grep { # discard those without title attribute
        $_->attrs->{title}
    } $self->mech->find_all_links( # that look like they go to an album
        url_abs_regex => qr{
            /album
            \?      # literal question mark
            \.      # literal dot
            dir=
        }msx
    );
};

sub create_album {
    my $self = shift;

    my %p = @_;
    if (!$p{access}) {
        $p{access} = 'private';
    };

    my %acc = (
        private => 'p',
        public => 'g',
        friends_only => 'r',
    );
    if (!exists $acc{$p{access}}) {
        croak 'access must be one of private or public or friends_only';
    };

    if (
        $p{yahoo_ids}
    and
        (ref $p{yahoo_ids} ne 'ARRAY')
    ) {
        croak 'value to yahoo_ids must be an arrayref';
    };

    $self->mech->get($PHOTOS_START);
    $self->mech->follow_link(
        url_regex => qr{
            /create_album
            \?      # literal question mark
            \.      # literal dot
            dir=/
        }msx
    );

    $self->mech->form_with_fields('albumname');
    if ($p{name}) {
        $self->mech->field('albumname' => $p{name});
    } else {
        $p{name} = $self->mech->value('albumname');
    };
    $self->mech->field(
        'fat' => $acc{$p{access}}                   # radio button
    );
    if ($p{yahoo_ids}) {
        $self->mech->field(
            'acl' => join "\n", @{ $p{yahoo_ids} }  # textarea
        );
    };
    if ($p{over_18_only}) {
        $self->mech->tick('ar' => 'y');
    };
    if ($p{restrict_prints}) {
        $self->mech->tick('or' => 'y');
    };
    $self->mech->submit;

    my %album;
    ($album{id}) = $self->mech->uri =~ m{
        /upload_jump
        \?          # literal question mark
        \.          # literal dot
        dir=/
        ([a-z0-9]+) # capture album id
    }mxs;
    $album{name} = $p{name};
    $album{upload_url} = $self->mech->uri;

    return Yahoo::Photos::Album->_new(%album);
};

sub delete_album {
    my $self = shift;
    my $album = shift;
    if (!$album) {
        croak 'no album given to delete_album';
    };

    $self->mech->get($PHOTOS_START);
    $self->mech->submit_form(
        with_fields => {
            'form_action' => 'delete',
            '.dir' => $album->id,   # radio button
        }
    );
    $self->mech->submit_form(
        button => 'submitbtn',
    );

    return;
};

sub upload {
    my $self = shift;
    my %p = @_;

    if (!$p{album}) {
        croak 'no album given for upload';
    };

    if (!$p{files}) {
        croak 'no files given for upload';
    };

    if (ref $p{files} ne 'ARRAY') {
        croak 'value to files must be an arrayref';
    };

    if (!$p{at_a_time}) {
        $p{at_a_time} = 10;
    };
    $p{at_a_time} = int $p{at_a_time};
    if (($p{at_a_time} < 1) or ($p{at_a_time} > 10)) {
        croak 'at_a_time must be between 1 and 10'
    };

    my $album = $p{album};
    if (!$album->upload_url) {
        $self->mech->get($album->url);
        $album->upload_url(
            $self->mech->find_link(
                text_regex => qr{
                    /upload_jump
                    \?      # literal question mark
                    \.      # literal dot
                    dir=
                }msx
            )->url_abs
        );
    };

    my @files = @{ $p{files} };

    while (@files) {
        if ($self->verbose) {
            {
                local $| = 1;   # autoflush
                print scalar @files;
                print " files remaining.\n";
            };
        };

        my %photos;

        for (1..10) {
            $photos{"photo$_"} = [undef, undef];
        };

        for (1..$p{at_a_time}) {
            $photos{"photo$_"} = [shift @files, undef];
        };

        $self->mech->get($album->upload_url);
        my $upload_form = $self->mech->form_with_fields(keys %photos);

        my $post_form;

        foreach my $elem ($upload_form->inputs) {
            if (exists $photos{$elem->name}) {
                push @{ $post_form}, ($elem->name => $photos{$elem->name});
            } else {
                push @{ $post_form}, ($elem->name => $elem->value);
            };
        };

        $self->mech->post(
            $upload_form->action,
            $post_form,
            'Content-Type' => 'form-data',
        );
    };

    return;
};

1;

__END__

=head1 NAME

Yahoo::Photos - Manage Yahoo Photos


=head1 VERSION

This document describes Yahoo::Photos version 0.0.1


=head1 SYNOPSIS

    # This is the programmatic interface.

    # The distribution also ships with a handy wrapper script
    # for simple uploading from the shell,
    # its documentation is linked at the end of this file.

    use Yahoo::Photos qw();
    my $yp = Yahoo::Photos->new(
        credentials => undef,
    );
    my $album = $yp->create_album(
        name => 'Visiting the zoo',
        access => 'public',
    );
    $yp->upload(
        album => $album,
        files => [glob('dscf*.jpg')],
    );
    $yp->delete_album($album);


=head1 DESCRIPTION

With this module, you can manage your albums on Yahoo Photos
(L<http://photos.yahoo.com/>). Currently creating and deleting
albums and uploading photos is implemented.

I wrote it because the Firefox mass-upload addon provided by
Yahoo does not work anymore.


=head1 INTERFACE

=over

=item new

Pick one of the following three ways to authenticate against Yahoo.

    my $yp = Yahoo::Photos->new(
        login => {
            user => $user,
            pass => $pass,
        },
    );

C<$user> and C<$pass> are the same what you would type into the form at
L<https://login.yahoo.com/>.

    my $yp = Yahoo::Photos->new(
        credentials => $credfile,
    );

You can L<store the credentials on the file
system|/"CONFIGURATION AND ENVIRONMENT"> for convenience.
Instead of an explicite filename, you can also pass C<undef>,
the L<default credentials file location|/"credfile"> is then used.

    my $yp = Yahoo::Photos->new(
        cookie => $cookiefile,
    );

Simplify the authentification by reusing your browser cookies.
C<$cookiefile> is the path to a Netscape-style cookie file, e.g. on
Linux F<$ENV{HOME}/.mozilla/firefox/a1b2c3d4.default/cookies.txt>.

=item credfile

    print Yahoo::Photos->credfile;

Returns the path to the default location of the credentials YAML file.
For the description of the file see L</"CONFIGURATION AND ENVIRONMENT">.

=item albums

    my @albums = $yp->albums;

Returns the list of L<albums|Yahoo::Photos::Album>.

=item create_album

    my $album = $yp->create_album;
    my $album = $yp->create_album(
        name => 'Visiting the zoo',
        access => 'public',
    );
    my $album = $yp->create_album(
        access => 'friends_only',
        yahoo_ids => [qw(yahooligan5678 roxorfan573 the7jump)],
        over_18_only => 1,
        restrict_prints => 1,
    );

Creates an album. If no C<name> is given, defaults to the ISO 8601 date as
given by Yahoo. If no C<access> is given, defaults to C<private>.
Access can be C<private>, C<public> or C<friends_only>. If C<friends_only>
is given, you should also provide to the key C<yahoo_ids> an arrayref
of Yahoo IDs. It is okay to omit the whole C<yahoo_ids> altogether.
You can restrict access to users aged at least 18 years
by passing true to the key C<over_18_only>. You can restrict photo print
ordering by passing true to the key C<restrict_prints>.

Returns the newly created L<album|Yahoo::Photos::Album>.

=item delete

    $yp->delete_album($album);

Deletes the album.

B<Warning!> There is no confirmation and no undo,
so make 100% sure you are picking the right album.

=item upload

    $yp->upload(
        album => $album,
        files => [glob('dscf*.jpg')],
        at_a_time => 3,
    );

Upload photos into the album in batches of C<at_a_time>
files. C<album> is mandatory, pass an
L<album|Yahoo::Photos::Album>. C<files> is mandatory,
pass an arrayref of paths to files. C<at_a_time> is optional,
defaults to 10, it must be a number between 1 and 10.

=item verbose

    $yp->upload(1);

Set this to a true value to make L</"upload"> report
progress.

=back


=head1 EXPORTS

Nothing.


=head1 DIAGNOSTICS

=over

=item C<< decide on one way build the constructor: login or credentials or cookie >>

=item C<< no user in login >>

=item C<< no pass in login >>

=item C<< no user in credentials file >>

=item C<< no pass in credentials file >>

=item C<< no cookie file path given >>

=item C<< cookie file does not exist >>

=item C<< cookie file not readable >>

=item C<< no login or cookie or credentials in constructor >>

=item C<< wrong user or pass >>

Yahoo did not accept your user or pass.

=item C<< access must be one of private or public or friends_only >>

=item C<< value to yahoo_ids must be an arrayref >>

=item C<< no album given to delete_album >>

=item C<< no album given for upload >>

=item C<< no files given for upload >>

=item C<< value to files must be an arrayref >>

=item C<< at_a_time must be between 1 and 10 >>

=back

From L<YAML>: L<new|/"new"> dies if it cannot read the YAML file.

From L<HTTP::Request::Common>: L<upload|/"upload"> dies
if it cannot read photo files.


=head1 CONFIGURATION AND ENVIRONMENT

$credfile in L<new|/"new"> is the path to a L<YAML> file that looks like this:

    ---
    user: SUPERHAPPYFUNUSER
    pass: SUPERHAPPYFUNPASS


=head1 DEPENDENCIES

Core modules: L<Carp>, L<File::Spec::Functions>, L<List::Util>

CPAN modules: L<Class::Spiffy>, L<File::HomeDir>,
L<HTTP::Cookies::Netscape>, L<Perl::Version>,
L<Readonly>, L<WWW::Mechanize>, L<YAML>


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-yahoo-photos@rt.cpan.org>, or through the web interface at
L<https://rt.cpan.org/>.


=head1 TODO

=over

=item * change album name, description, title, access

=item * rename, delete, sort, move, copy photos

=back

Suggest more future plans by L<filing a
bug|/"BUGS AND LIMITATIONS">.


=head1 AUTHOR

Lars Dɪᴇᴄᴋᴏᴡ  C<< <daxim@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Lars Dɪᴇᴄᴋᴏᴡ C<< <daxim@cpan.org> >>.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE »AS IS« WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 SEE ALSO

L<yahoo-photos(1)>, L<Yahoo::Photos::Album>

=encoding utf8
