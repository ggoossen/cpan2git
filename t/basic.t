
use strict;
use warnings;

use Test::More 'no_plan';

use File::Temp qw(tempdir);
use Scriptalicious;

use CPAN2git;
use Cwd qw(cwd);
use File::Path qw(mkpath);

my $cpan_dir = cwd() . "/t/test-cpan/cpan";

{
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $cpan_dir, repos_dir => $repos_dir );
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my @dist_infos = $cpan2git->dist_infos();
    my @x = sort { $a->{distname_info}->version <=>  $b->{distname_info}->version }
                grep { $_->{distname_info}->dist eq $module_name } @dist_infos;
    is(scalar(@x), 3);
    my $x0 = $x[0];
    is( $x0->{distname_info}->dist, $module_name);
    is( $x0->{distname_info}->version, '1.0');
    is( $x0->{mtime}, 1145080578);
    my $x1 = $x[1];
    is( $x1->{distname_info}->dist, $module_name);
    is( $x1->{distname_info}->version, '1.01');
    is( $x1->{mtime}, 1186900275);
}

{
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $cpan_dir, repos_dir => $repos_dir );
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my @dist_names = $cpan2git->dist_names();
    is_deeply( [sort @dist_names], [sort qw[GitIgnore-Test Locale-PO Decision-Markov Module-DynamicSubModule Plucene-Plugin-Analyzer-MetaphoneAnalyzer]] );
}

{
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $cpan_dir, repos_dir => $repos_dir );
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my @ordered_dist = $cpan2git->ordered_dist_infos_by_distname( $module_name );
    is_deeply( [map { $_->{distname_info}->version } @ordered_dist],
               [qw[1.0 1.01 1.02]] );

    my @tagnames = map { $cpan2git->dist_tagname( $_ ) } @ordered_dist;

    is_deeply( [@tagnames],
               ["$module_name-1.0", "$module_name-1.01", "$module_name-1.02"] );
}

{
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $cpan_dir, repos_dir => $repos_dir );
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my $distname = $module_name;
    ok( not $cpan2git->dist_has_repository( $distname ) );
    $cpan2git->create_dist_repository( $distname );
    ok( $cpan2git->dist_has_repository( $distname ) );

    ok( -d "$repos_dir/$module_name");
    ok( -d "$repos_dir/$module_name/.git", "$module_name has .git directory" );
}

{
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $cpan_dir, repos_dir => $repos_dir );
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my $distrepos = $cpan2git->dist_repos_dir($module_name);

    $cpan2git->update_all();

    chdir("$distrepos");

    is( `git tag -l`, "$module_name-1.0\n$module_name-1.01\n$module_name-1.02\n" );

    check_plucene_plugin_etc_1_0();
    check_plucene_plugin_etc_1_01();
}

sub check_plucene_plugin_etc_1_0 {
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my $tree_sha = git_tree_sha("refs/tags/$module_name-1.0");
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
    is(git_parent_sha("refs/tags/$module_name-1.0"), '');
}

sub check_plucene_plugin_etc_1_01 {
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my $parent_sha = git_parent_sha("refs/tags/$module_name-1.01");
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

{
    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";

    my $new_cpan_dir = tempdir( CLEANUP => 1 );
    my $repos_dir = tempdir( CLEANUP => 1 );

    mkpath($new_cpan_dir . "/authors");

    my $cpan2git = CPAN2git->new( cpan_dir => $new_cpan_dir, repos_dir => $repos_dir );
    $cpan2git->update_all();

    is(`ls $repos_dir`, '');
    my $alansz_dir = "/authors/id/A/AL/ALANSZ/";
    mkpath($new_cpan_dir . $alansz_dir);
    run("cp",
        "-a",
        "$cpan_dir/$alansz_dir/$module_name-1.0.tar.gz",
        "$new_cpan_dir/$alansz_dir/"
    );

    $cpan2git->update_all();

    check_plucene_plugin_etc_1_0();

    run("cp",
        "-a",
        "$cpan_dir/$alansz_dir/$module_name-1.01.tar.gz",
        "$new_cpan_dir/$alansz_dir/"
    );

    $cpan2git->update_all();

    check_plucene_plugin_etc_1_01();
}

{
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $cpan_dir, repos_dir => $repos_dir );

    $cpan2git->update_all();

    my $module_name = "GitIgnore-Test";
    my $distrepos = $cpan2git->dist_repos_dir($module_name);

    chdir("$distrepos");

    my $tree_sha = git_tree_sha("refs/tags/$module_name-1.0");

    is( `git ls-tree -r $tree_sha .`, <<'EOT' );
100644 blob 72e8ffc0db8aad71a934dd11e5968bd5109e54b4	.gitignore
100644 blob dd6d86a43dc9aadd55edad1dc23f6bf16a1e2ccf	test
EOT

}

sub git_parent_sha {
    my ($rev) = @_;

    my $x = `git log -n1 --pretty='format:%P' $rev`;
    chomp($x);
    return $x;
}

sub git_tree_sha {
    my ($rev) = @_;

    my $x = `git log -n1 --pretty='format:%T' $rev`;
    chomp($x);
    return $x;
}

sub git_commit_sha {
    my ($rev) = @_;

    my $x = `git log -n1 --pretty='format:%H' $rev`;
    chomp($x);
    return $x;
}

END {
    chdir($cpan_dir); # get away from temporary directory
}
