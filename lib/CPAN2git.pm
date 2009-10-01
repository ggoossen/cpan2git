package CPAN2git;

use strict;
use warnings;

use List::MoreUtils qw(uniq);
use CPAN::DistnameInfo;
use File::Find;
use Carp qw(confess);
use File::Path qw(mkpath rmtree);
use Scriptalicious;
use Archive::Extract;
use File::Temp qw(tempdir);

sub new {
    my ($class, %args) = @_;

    my $cpan_dir = $args{cpan_dir};
    -e $cpan_dir or confess("cpan_dir '$cpan_dir' does not exists");

    my $repos_dir = $args{repos_dir};
    -e $repos_dir or confess("repos_dir '$repos_dir' does not exists");

    my $self = bless { cpan_dir => $cpan_dir, repos_dir => $repos_dir }, $class;
    return $self;
}

sub repos_dir {
    my ($self) = @_;
    return $self->{'repos_dir'};
}

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
    find( sub {
              return if not -f;
              my $filename = File::Spec->rel2abs($_);
              my $mtime = (stat($filename))[9];
              push( @dist_infos, { filename => $filename,
                                    distname_info => CPAN::DistnameInfo->new($filename),
                                    mtime => $mtime,
                               } );
          }, "$cpan_dir/authors" );

    @dist_infos = grep { defined $_->{distname_info}->dist } @dist_infos;

    $self->{dist_infos} = @dist_infos;

    return @dist_infos;
}

sub dist_names {
    my ($self) = @_;
    return uniq map { $_->{distname_info}->dist } $self->dist_infos;
}

sub ordered_dist_infos_by_distname {
    my ($self, $distname) = @_;
    my @dist_infos =
      sort { $a->{mtime} <=> $b->{mtime} }
      grep { $_->{distname_info}->dist eq $distname }
      $self->dist_infos;

    return @dist_infos;
}

sub dist_repos_dir {
    my ($self, $distname) = @_;
    return $self->repos_dir . "/$distname";
}

sub dist_has_repository {
    my ($self, $distname) = @_;
    return -e $self->dist_repos_dir($distname) . "/.git";
}

sub create_dist_repository {
    my ($self, $distname) = @_;

    mkpath($self->dist_repos_dir($distname));

    run("git", "--git-dir" => $self->dist_repos_dir($distname) . "/.git", "init");

    return;
}

sub dist_tagname {
    my ($self, $dist) = @_;
    return $dist->{distname_info}->dist . "-" . $dist->{distname_info}->version;
}

sub has_gitrev_by_dist {
    my ($self, $dist) = @_;

    my $distname = $dist->{distname_info}->dist;
    my $err = run_err("git",
        "--git_dir" => $self->dist_repos_dir($distname),
        "rev-parse",
        "-q",
        "--verify",
        "refs/tags/" . $self->dist_tagname($dist),
    );

    return not $err;
}

sub repos_checkout_dist {
    my ($self, $dist, $distname) = @_;
    my $dist_repos_dir = $self->dist_repos_dir($distname);
    if (not $dist) {
        my $head_ref = "$dist_repos_dir/.git/refs/heads/master";
        if (-e $head_ref ) {
            unlink("$dist_repos_dir/.git/refs/heads/master") or confess("Failed unlink: $!");
        }
    }
    else {
        run("git",
            "--git-dir" => "$dist_repos_dir/.git",
            "checkout",
            "-q",
            "refs/tags/" . $self->dist_tagname($dist),
        );
    }

    return;
}

sub clean_repos_dir {
    my ($self, $dist) = @_;

    my $distname = $dist->{distname_info}->dist;
    my $dist_repos_dir = $self->dist_repos_dir($distname);

    opendir(my $x, $dist_repos_dir) or confess("failed openddir: $!");
    my @to_be_deleted_files = grep { $_ !~ m/^[.](|[.]|git)$/ } readdir($x);

    for (@to_be_deleted_files) {
        my $full_filename = "$dist_repos_dir/$_";
        rmtree($full_filename);
        if (-e $full_filename) {
            confess("'$full_filename' was not removed");
        }
    }

    return;
}

sub extract_to_repos {
    my ($self, $dist) = @_;

    my $distname = $dist->{distname_info}->dist;
    my $dist_repos_dir = $self->dist_repos_dir($distname);

    my $ae = Archive::Extract->new( archive => $dist->{filename} );
    my $extract_dir = tempdir();
    $ae->extract( to => $extract_dir );

    my $dir;
    {
        # Stolen from CPANPLUS
        for my $try (
            File::Spec->rel2abs(
                File::Spec->catdir( $ae->extract_path, $dist->{distname_info}->distvname )
                                ) ,
            File::Spec->rel2abs( $ae->extract_path ),
        ) {
            ($dir = $try) && last if -d $try;
        }
    }

    opendir(my $x, $dir) or confess("failed openddir: $!");
    my @to_be_moved_files = grep { $_ !~ m/^[.](|[.]|git)$/ } readdir($x);

    for my $filename (@to_be_moved_files) {
        run("mv", "$dir/$filename", "$dist_repos_dir/$filename");
    }

    return;
}

sub commit_to_repos {
    my ($self, $dist) = @_;

    my $distname = $dist->{distname_info}->dist;
    my $dist_repos_dir = $self->dist_repos_dir($distname);

    my $dist_versioned_name = $dist->{distname_info}->distvname;

    chdir("$dist_repos_dir") or confess("Failed chaning to repos dir: $!");

    run("git",
        "add",
        "--force",
        "--all",
        "./");

    run("git",
        "commit",
        "-m" => $dist_versioned_name,
    );

    run("git",
        "tag",
        "-m" => $dist_versioned_name,
        "-a" => $dist_versioned_name,
    );

    return;
}

sub update_dist {
    my ($self, $distname) = @_;

    my @dist_infos = $self->ordered_dist_infos_by_distname($distname);

    if (not $self->dist_has_repository($distname) ) {
        $self->create_dist_repository($distname);
    }

    my $prev_dist_info;
    for my $dist_info (@dist_infos) {
        next if $self->has_gitrev_by_dist($dist_info);
        $self->repos_checkout_dist( $prev_dist_info, $distname );
        $self->clean_repos_dir( $dist_info );
        $self->extract_to_repos( $dist_info );
        $self->commit_to_repos( $dist_info );
    }
    continue {
        $prev_dist_info = $dist_info;
    }

    return;
}

sub update_all {
    my ($self) = @_;

    for ($self->dist_names) {
        $self->update_dist($_);
    }

    return;
}

1;
