package CPAN2git;

use strict;
use warnings;

=head1 NAME

CPAN2git - Library for converting a local cpan/backpan to git repositories.

=head1 DESCRIPTION

CPAN2git is a library for converting a local CPAN/backpan to git repositories.
It can either update all CPAN distribitons or specific distributions.

=head1 SYNOPSIS

    # initialize cpan2git object
    my $cpan2git = CPAN2git->new(
        cpan_dir  => "/var/lib/cpan2git/cpan-mirror",
        repos_dir => "/var/lib/cpan2git/cpan-repositories",
    );
    # convert all CPAN distributions to their corresponding repositories
    $cpan2git->update_all();

=cut

use Archive::Extract;
use CPAN::DistnameInfo;
use CPAN2git::Constants;
use Carp qw(confess);
use DateTime               ();
use DateTime::Format::Mail ();
use File::Find;
use File::Path qw(mkpath rmtree);
use File::Spec;
use File::Temp qw(tempdir tempfile);
use List::MoreUtils qw(uniq any);
use Parse::CPAN::Whois ();
use Scriptalicious;
use version qw(qv);

our $VERSION = qv('v1.0');

=head1 METHODS/SUBROUTINES

=over

=cut

=item new( cpan_dir => $, repos_dir => $ )

Create and configure the object which can later be used to do actual work.

=cut

sub new {
    my ( $class, %args ) = @_;

    my $cpan_dir = $args{cpan_dir};
    -e $cpan_dir or confess("cpan_dir '$cpan_dir' does not exists");

    my $repos_dir = $args{repos_dir};
    -e $repos_dir or confess("repos_dir '$repos_dir' does not exists");

    my $self = bless { cpan_dir => $cpan_dir, repos_dir => $repos_dir }, $class;
    return $self;
}

=item repos_dir()

The directory name where the git repositories are

=cut

sub repos_dir {
    my ($self) = @_;
    return $self->{'repos_dir'};
}

=item cpan_dir()

The directory name of the CPAN mirror

=cut

sub cpan_dir {
    my ($self) = @_;
    return $self->{'cpan_dir'};
}

sub dist_infos {
    my ($self) = @_;

    $self->{dist_infos} ||= [ $self->_dist_infos_no_cache() ];

    return @{ $self->{dist_infos} };
}

sub _dist_infos_no_cache {
    my ($self) = @_;

    my $cpan_dir = $self->cpan_dir;

    my @dist_infos;
    find(
        sub {
            return if not -f;
            my $filename      = File::Spec->rel2abs($_);
            my $mtime         = ( stat($filename) )[9];
            my $distname_info = CPAN::DistnameInfo->new($filename);

            # skip everything which is not a distribution file, e.g. *.meta files
            return if not $distname_info->dist;

            if ( not ( defined $distname_info->version
                         and $distname_info->version ne "" ) ) {
                mutter("Skipping '$filename' because it does not have a version.");
                return;
            }

            my $full_distname = $distname_info->dist . "-" . $distname_info->version;

            # skip everything which has not a proper name and might pose a security risk
            if (not $distname_info->dist =~ m/^[\w\d][\w\d.-]*$/) {
                say("Skipping dist '$full_distname', because its name is wierd.");
                return;
            }

            if (any { $full_distname eq $_ } CPAN2git::Constants::SKIP_DISTS()) {
                say("Skipping dist '$full_distname', because it is in our list of dists to skip.");
                return;
            }

            if ($full_distname =~ m/[.]$/) {
                say("Skipping dist '$full_distname, because it ends with '.'.");
                return;
            }

            push(
                @dist_infos,
                {
                    filename      => $filename,
                    distname_info => $distname_info,
                    mtime         => $mtime,
                    full_distname => $full_distname,
                }
            );
        },
        "$cpan_dir/authors"
    );

    return @dist_infos;
}

sub dist_names {
    my ($self) = @_;
    return uniq map { $_->{distname_info}->dist } $self->dist_infos;
}

sub _dist_name_x_distinfos {
    my ($self) = @_;
    return $self->{dist_name_x_distinfos} if $self->{dist_name_x_distinfos};
    for my $dist ($self->dist_infos()) {
        push @{ $self->{dist_name_x_distinfos}->{ $dist->{distname_info}->dist } }, $dist;
    }
    return $self->{dist_name_x_distinfos};
}

sub ordered_dist_infos_by_distname {
    my ( $self, $distname ) = @_;
    my @dist_infos =
      sort { $a->{mtime} <=> $b->{mtime} }
        @{ $self->_dist_name_x_distinfos()->{$distname} || [] };

    return @dist_infos;
}

sub dist_repos_dir {
    my ( $self, $distname ) = @_;
    return $self->repos_dir . "/$distname";
}

sub dist_has_repository {
    my ( $self, $distname ) = @_;
    return -e $self->dist_repos_dir($distname) . "/.git";
}

sub create_dist_repository {
    my ( $self, $distname ) = @_;

    mkpath( $self->dist_repos_dir($distname) );

    say("Creating repository for '$distname'");

    run( "git", "--git-dir" => $self->dist_repos_dir($distname) . "/.git", "init" );

    return;
}

sub has_gitrev_by_dist {
    my ( $self, $dist ) = @_;

    my $distname          = $dist->{distname_info}->dist;
    my $git_dir           = $self->dist_repos_dir($distname) . "/.git";
    if (not -d $git_dir) {
        return 0;
    }
    my $no_tag_error_code = 256;
    my @run_err_args      = (
        "git",
        "--git-dir" => $git_dir,
        "rev-parse",
        "-q",
        "--verify",
        "refs/tags/$dist->{full_distname}",
    );
    my $err = run_err(@run_err_args);
    if ( $err and ( $err != $no_tag_error_code ) ) {
        confess( "Found unexpected error code $err for command: " . join( ' ', @run_err_args ) );
    }

    return not $err;
}

sub repos_set_initial_state {
    my ( $self, $distname ) = @_;

    if ( not $self->dist_has_repository($distname) ) {
        $self->create_dist_repository($distname);
    }

    # reseting git to its initial state, i.e. there is no commit done yet,
    # is done by removing the file containing the current head (which is assumed to be "master").
    my $dist_repos_dir = $self->dist_repos_dir($distname);
    my $head_ref       = "$dist_repos_dir/.git/refs/heads/master";
    if ( -e $head_ref ) {
        unlink("$dist_repos_dir/.git/refs/heads/master") or confess("Failed to unlink: $!");
    }

    return;
}

sub repos_checkout_dist {
    my ( $self, $dist ) = @_;

    my $dist_repos_dir = $self->dist_repos_dir( $dist->{distname_info}->dist );
    run(
        "git",
        "--git-dir" => "$dist_repos_dir/.git",
        "reset",
        "--hard",
        "refs/tags/$dist->{full_distname}",
    );

    return;
}

sub _dir_non_dotgit_files {
    my ($dir) = @_;
    opendir( my $dh, $dir ) or confess("failed openddir of '$dir': $!");
    my @non_git_files = grep { $_ !~ m/^[.](|[.]|git)$/ } readdir($dh);
    return @non_git_files;
}

sub clean_repos_dir {
    my ( $self, $dist ) = @_;

    my $distname       = $dist->{distname_info}->dist;
    my $dist_repos_dir = $self->dist_repos_dir($distname);

    my @to_be_deleted_files = _dir_non_dotgit_files($dist_repos_dir);

    for (@to_be_deleted_files) {
        my $full_filename = "$dist_repos_dir/$_";
        rmtree($full_filename);
        if ( -e $full_filename ) {
            confess("'$full_filename' was not removed");
        }
    }

    return;
}

sub extract_to_repos {
    my ( $self, $dist ) = @_;

    my $distname       = $dist->{distname_info}->dist;
    my $dist_repos_dir = $self->dist_repos_dir($distname);

    my $ae = Archive::Extract->new( archive => $dist->{filename} );
    local $Archive::Extract::WARN = $VERBOSE > 0;
    my $extract_dir = tempdir( CLEANUP => 1 );
    $ae->extract( to => $extract_dir );
    if ( $ae->error() ) {
        say("Failed extracting '$dist->{filename}'.");
        return 1;
    }

    my $dir;
    {

        # The try list if taken from CPANPLUS
        for my $try (
            File::Spec->rel2abs(
                File::Spec->catdir( $ae->extract_path, $dist->{distname_info}->distvname )
            ),
            File::Spec->rel2abs(
                File::Spec->catdir( $ae->extract_path, $dist->{full_distname} )
            ),
            File::Spec->rel2abs( $ae->extract_path ),
          )
        {
            if ( -d $try ) {
                $dir = $try;
                last;
            }
        }
    }

    my @to_be_moved_files = _dir_non_dotgit_files($dir);

    for my $filename (@to_be_moved_files) {
        run( "mv", "$dir/$filename", "$dist_repos_dir/$filename" );
    }

    return 0;
}

sub whois {
    my ($self) = @_;
    return $self->{whois} if $self->{whois};

    open( my $fh, "<", $self->cpan_dir . "/authors/00whois.xml" )
      or confess("Could not open whois file: $!");
    $self->{whois} = Parse::CPAN::Whois->new($fh);

    return $self->{whois};
}

sub cpan_whois_author {
    my ( $self, $pause_id ) = @_;
    my $author = $self->whois->author($pause_id)
      or confess("Could not find author for pause id $pause_id");
    return $author;
}

sub commit_to_repos {
    my ( $self, $dist ) = @_;

    my $distname       = $dist->{distname_info}->dist;
    my $dist_repos_dir = $self->dist_repos_dir($distname);

    my $dist_versioned_name = $dist->{full_distname};

    say("Importing release '$dist_versioned_name'");

    chdir("$dist_repos_dir") or confess("Failed changing to repos dir: $!");

    run( "git", "add", "--force", "--all", "./" );

    my $pause_id = $dist->{distname_info}->cpanid;
    my $author   = $self->cpan_whois_author($pause_id);
    $ENV{GIT_AUTHOR_NAME}  = $author->name  || $pause_id;
    $ENV{GIT_AUTHOR_EMAIL} = $author->email || lc($pause_id) . '@cpan.org';
    $ENV{GIT_AUTHOR_DATE} =
      DateTime::Format::Mail->new->format_datetime(
        DateTime->from_epoch( epoch => $dist->{mtime}, time_zone => 'UTC' ) );
    $ENV{GIT_COMMITTER_NAME}  = 'CPAN2git ' . $VERSION;
    $ENV{GIT_COMMITTER_EMAIL} = 'cpan2git@localhost';

    run( "git", "commit",
         "--allow-empty",
         "-m" =>
           "release $dist_versioned_name\n\ncpan2git import of release $dist_versioned_name\n" );

    run(
        "git",
        "tag",
        "-m" => "cpan2git tag of release $dist_versioned_name",
        "-a" => $dist_versioned_name,
    );

    return;
}

sub _update_dist {
    my ( $self, $dist_info, $prev_dist_info ) = @_;

    if ($prev_dist_info) {
        $self->repos_checkout_dist($prev_dist_info);
    }
    else {
        $self->repos_set_initial_state($dist_info->{distname_info}->dist);
    }
    $self->clean_repos_dir($dist_info);
    if ($self->extract_to_repos($dist_info) ) {
        return $prev_dist_info;
    }
    $self->commit_to_repos($dist_info);
    return $dist_info;
}

=item update_dist( $dist_name )

Update a single distribution to its corresponding git repository.

=cut

sub update_dist {
    my ( $self, $distname ) = @_;

    say("update dist of '$distname'");

    my @dist_infos = $self->ordered_dist_infos_by_distname($distname);

    my $prev_dist_info;
    for my $dist_info (@dist_infos) {
        if ($self->has_gitrev_by_dist($dist_info)) {
            $prev_dist_info = $dist_info;
            next;
        }
        $prev_dist_info = $self->_update_dist($dist_info, $prev_dist_info);
    }

    return;
}

=item update_all()

Update all CPAN distributions to their corresponding git repositories.

=cut

sub update_all {
    my ($self) = @_;

    for my $dist_name ( $self->dist_names ) {
        $self->update_dist($dist_name);
    }

    return;
}

=back

=cut

1;
