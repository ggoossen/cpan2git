
use strict;
use warnings;

=head1 DESCRIPTION

Test to check the generation of the git repository of Plucene-Plugin-Analyzer-MetaphoneAnalyzer.
The conversion is done two times. The first time everything is convered in one run. The second
time by incrementally additing the distributions to the cpan import directory to create, and by
running "update_all" in between.

=cut

use lib 't/lib';
use Test::CPAN2git;

use CPAN2git;
use Cwd qw(cwd);
use File::Path qw(mkpath);
use File::Temp qw(tempdir);
use File::Touch ();
use Scriptalicious;
use Test::More;

plan('no_plan');

$Scriptalicious::VERBOSE = -1;

my $testcpan_dir = cwd() . "/t/test-cpan/cpan";

{

    # Check generation of Plucene-Plugin-Analyzer-MetaphoneAnalyzer
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $testcpan_dir, repos_dir => $repos_dir );
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    #  Set up timestamps of test resources (they are set after checkout from github)
    my $expected_mtime_1_0  = 1145080578;
    my $expected_mtime_1_01 = 1186900275;
    set_mtime( "$testcpan_dir/authors/id/A/AL/ALANSZ/$module_name-1.0.tar.gz",
        $expected_mtime_1_0 );
    set_mtime( "$testcpan_dir/authors/id/A/AL/ALANSZ/$module_name-1.01.tar.gz",
        $expected_mtime_1_01 );

    my $distrepos = $cpan2git->dist_repos_dir($module_name);

    $cpan2git->update_all();

    chdir("$distrepos");

    is( `git tag -l`, "$module_name-1.0\n$module_name-1.01\n$module_name-1.02\n" );

    check_plucene_plugin_etc_1_0( $cpan2git,
        "Check generation of Plucene-Plugin-Analyzer-MetaphoneAnalyzer from scratch" );
    check_plucene_plugin_etc_1_01($cpan2git);
}

{

    # Check that the same is generated with increment "update_all"s
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my $new_cpan_dir = tempdir( CLEANUP => 1 );
    my $repos_dir    = tempdir( CLEANUP => 1 );

    mkpath( $new_cpan_dir . "/authors" );

    my $cpan2git = CPAN2git->new( cpan_dir => $new_cpan_dir, repos_dir => $repos_dir );
    $cpan2git->update_all();

    is( `ls $repos_dir`, '' );
    my $alansz_dir = "/authors/id/A/AL/ALANSZ/";
    mkpath( $new_cpan_dir . $alansz_dir );
    run( "cp", "-a", "$testcpan_dir/$alansz_dir/$module_name-1.0.tar.gz",
        "$new_cpan_dir/$alansz_dir/" );
    run( "cp", "-a", "$testcpan_dir/authors/00whois.xml", "$new_cpan_dir/authors/" );

    $cpan2git = CPAN2git->new( cpan_dir => $new_cpan_dir, repos_dir => $repos_dir );
    $cpan2git->update_all();

    check_plucene_plugin_etc_1_0( $cpan2git, "Incrementally update everything" );

    run( "cp", "-a", "$testcpan_dir/$alansz_dir/$module_name-1.01.tar.gz",
        "$new_cpan_dir/$alansz_dir/" );

    $cpan2git = CPAN2git->new( cpan_dir => $new_cpan_dir, repos_dir => $repos_dir );
    $cpan2git->update_all();

    check_plucene_plugin_etc_1_01($cpan2git);
}

{

    # Check that the same is generated with incrementing and updating a single dist
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my $new_cpan_dir = tempdir( CLEANUP => 1 );
    my $repos_dir    = tempdir( CLEANUP => 1 );

    mkpath( $new_cpan_dir . "/authors" );

    my $cpan2git = CPAN2git->new( cpan_dir => $new_cpan_dir, repos_dir => $repos_dir );
    $cpan2git->update_all();

    is( `ls $repos_dir`, '' );
    my $alansz_dir = "/authors/id/A/AL/ALANSZ/";
    mkpath( $new_cpan_dir . $alansz_dir );
    run( "cp", "-a", "$testcpan_dir/$alansz_dir/$module_name-1.0.tar.gz",
        "$new_cpan_dir/$alansz_dir/" );
    run( "cp", "-a", "$testcpan_dir/authors/00whois.xml", "$new_cpan_dir/authors/" );

    $cpan2git = CPAN2git->new( cpan_dir => $new_cpan_dir, repos_dir => $repos_dir );
    $cpan2git->update_dist("$module_name");

    check_plucene_plugin_etc_1_0( $cpan2git, "Increment a single dist" );

    run( "cp", "-a", "$testcpan_dir/$alansz_dir/$module_name-1.01.tar.gz",
        "$new_cpan_dir/$alansz_dir/" );

    $cpan2git = CPAN2git->new( cpan_dir => $new_cpan_dir, repos_dir => $repos_dir );
    $cpan2git->update_dist("$module_name");

    check_plucene_plugin_etc_1_01($cpan2git);
}

sub check_plucene_plugin_etc_1_0 {
    my ( $cpan2git, $message ) = @_;
    my $module_name    = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";
    my $module_version = "1.0";

    my ($dist_info) =
      grep { $_->{distname_info}->version eq $module_version }
      $cpan2git->ordered_dist_infos_by_distname($module_name);

    ok( $cpan2git->has_gitrev_by_dist($dist_info),
        "Plucene-Plugin-Analyzer-MetaphoneAnalyzer-1.0 has a gitrev ($message)" );

    my $tag = "refs/tags/$module_name-$module_version";

    my $tree_sha = git_tree_sha($tag);
    chomp($tree_sha);
    is( $tree_sha, "4c37598e6640e7fd299654c88e016df4cbf36187" );
    is( `git ls-tree -r $tree_sha .`, <<'EOT' );
100644 blob 229b18329ba944d8b5b5c07894ed71d8c714e1c0	Changes
100644 blob 65ac8d77e358abc930fa7d151bacfe74bc954de8	MANIFEST
100644 blob 8946737c5731e970da4733fcc26f99f0d5418038	META.yml
100644 blob 3cd79b1731a3800966cb42faf8a246a5591f9c91	Makefile.PL
100644 blob 8a5d5eb8b79ce5b8f62c8cf9977edf9d304c5132	README
100644 blob 9a88b7d2473a4a3061e493194d94c83e5b2e6fbc	lib/Plucene/Plugin/Analyzer/MetaphoneAnalyzer.pm
100644 blob 7052ad612628c4896bdb38b8345afcb992b531ed	lib/Plucene/Plugin/Analyzer/MetaphoneFilter.pm
100644 blob 2b547bc529d32ee4e2df4bdbf33c317ee9c66df8	t/Plucene-Plugin-Analyzer-MetaphoneAnalyzer.t
EOT
    is( git_parent_sha($tag), '', "first distribution has no parent" );
    is( git_commit_subject($tag),  "release $module_name-1.0" );
    is( git_commit_body($tag),     "cpan2git import of release $module_name-1.0" );
    is( git_author_name($tag),     'Alan Schwartz' );
    is( git_author_email($tag),    'alansz@uic.edu' );
    is( git_author_date($tag),     'Sat, 15 Apr 2006 05:56:18 +0000' );
    is( git_committer_name($tag),  'CPAN2git ' . $CPAN2git::VERSION );
    is( git_committer_email($tag), 'cpan2git@localhost' );
    ok(
        DateTime->now()->subtract_datetime(
            DateTime->from_epoch( epoch => git_committer_date_unix_timestamp($tag) )
          )->minutes() < 2,
        "commit is done less than 2 minutes ago"
    );

    like(
        `git cat-file -p $tag`, qr/
                                        object[ ]\S+ \n
                                        type[ ]commit \n
                                        tag[ ]$module_name-1.0 \n
                                        tagger[ ]CPAN2git[ ]$CPAN2git::VERSION \s <cpan2git\@localhost> \s .+ \n
                                        \n
                                        cpan2git[ ]tag[ ]of[ ]release[ ]$module_name-1.0
                                    /x,
        "The tag was set correctly ($message)"
    );
}

sub check_plucene_plugin_etc_1_01 {
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my $parent_sha   = git_parent_sha("refs/tags/$module_name-1.01");
    my $expected_sha = git_commit_sha("refs/tags/$module_name-1.0");
    is( $parent_sha, $expected_sha );

    my $tree_sha = git_tree_sha("refs/tags/$module_name-1.01");
    is( `git ls-tree -r $tree_sha .`, <<'EOT' );
100644 blob e8d790b1ba537a4c84d8d775ef4b86d1fbdfbd43	Changes
100644 blob 65ac8d77e358abc930fa7d151bacfe74bc954de8	MANIFEST
100644 blob f685742eee12397400d6dbeb8e4e8c56104ee6e8	META.yml
100644 blob ea1649056acc1749dbf2d40ef52cb6faf6e069e0	Makefile.PL
100644 blob 8600501ba7903a68a51aa3b93a23993ebef2e6ae	Makefile.old
100644 blob cc82e4b376decbf82e4e9e6611afc514676dadbc	README
100644 blob 55af31ef1a72fdbe163771ffa802cf45aa6a353f	lib/Plucene/Plugin/Analyzer/MetaphoneAnalyzer.pm
100644 blob 7052ad612628c4896bdb38b8345afcb992b531ed	lib/Plucene/Plugin/Analyzer/MetaphoneFilter.pm
100644 blob 2b547bc529d32ee4e2df4bdbf33c317ee9c66df8	t/Plucene-Plugin-Analyzer-MetaphoneAnalyzer.t
EOT
}

END {
    chdir("/"); # get away from temporary directory
}
