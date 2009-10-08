
use strict;
use warnings;

use lib 't/lib';

use CPAN2git;
use Cwd qw(cwd);
use File::Path qw(mkpath);
use File::Temp qw(tempdir);
use File::Touch ();
use Scriptalicious;
use Test::CPAN2git qw(set_mtime);
use Test::More 'no_plan';

$Scriptalicious::VERBOSE = -1;

# $testcpan_dir referes to a mini CPAN distribution, containing some distributions for testing.
my $testcpan_dir = cwd() . "/t/test-cpan/cpan";

{

    # test of "dist_infos"
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git            = CPAN2git->new( cpan_dir => $testcpan_dir, repos_dir => $repos_dir );
    my $module_name         = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";
    my $expected_mtime_1_0  = 1145080578;
    my $expected_mtime_1_01 = 1186900275;
    set_mtime( "$testcpan_dir/authors/id/A/AL/ALANSZ/$module_name-1.0.tar.gz",
        $expected_mtime_1_0 );
    set_mtime( "$testcpan_dir/authors/id/A/AL/ALANSZ/$module_name-1.01.tar.gz",
        $expected_mtime_1_01 );

    my @dist_infos = $cpan2git->dist_infos();
    my @x = sort { $a->{distname_info}->version <=> $b->{distname_info}->version }
      grep { $_->{distname_info}->dist eq $module_name } @dist_infos;
    is( scalar(@x), 3 );
    my $x0 = $x[0];
    like( $x0->{filename}, qr/\Q$module_name-1.0.tar.gz\E$/ );
    is( $x0->{distname_info}->dist,    $module_name );
    is( $x0->{distname_info}->version, '1.0' );
    is( $x0->{mtime},                  $expected_mtime_1_0 );
    my $x1 = $x[1];
    like( $x1->{filename}, qr/\Q$module_name-1.01.tar.gz\E$/ );
    is( $x1->{distname_info}->dist,    $module_name );
    is( $x1->{distname_info}->version, '1.01' );
    is( $x1->{mtime},                  $expected_mtime_1_01 );
}

{

    # test "dist_names"
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $testcpan_dir, repos_dir => $repos_dir );
    my @module_names = $cpan2git->dist_names();
    is_deeply(
        [ sort @module_names ],
        [
            sort
              qw[UTF8Author-Test NoChangesBetweenVersions-Test NoDashTest BrokenTarball GitIgnore-Test Locale-PO Decision-Markov Module-DynamicSubModule Plucene-Plugin-Analyzer-MetaphoneAnalyzer]
        ]
    );
}

{

    # test of "ordered_dist_infos_by_distname"
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $testcpan_dir, repos_dir => $repos_dir );
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my @ordered_dist = $cpan2git->ordered_dist_infos_by_distname($module_name);
    is_deeply( [ map { $_->{distname_info}->version } @ordered_dist ], [qw[1.0 1.01 1.02]] );

    my @dist_names = map { $_->{full_distname} } @ordered_dist;

    is_deeply( [@dist_names], [ "$module_name-1.0", "$module_name-1.01", "$module_name-1.02" ] );
}

{

    # test "dist_has_repository" and "create_dist_repository"
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $testcpan_dir, repos_dir => $repos_dir );
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my $distname = $module_name;
    ok( not $cpan2git->dist_has_repository($distname) );
    $cpan2git->create_dist_repository($distname);
    ok( $cpan2git->dist_has_repository($distname) );

    ok( -d "$repos_dir/$module_name" );
    ok( -d "$repos_dir/$module_name/.git", "$module_name has .git directory" );
}

1;
