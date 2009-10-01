
use strict;
use warnings;

use Test::More 'no_plan';

use File::Temp qw(tempdir);
use Scriptalicious;

use CPAN2git;

my $repos_dir = tempdir();
my $cpan2git = CPAN2git->new( cpan_dir => "t/test-cpan/cpan", repos_dir => $repos_dir );

{
    my @dist_infos = $cpan2git->dist_infos();
    is_deeply( [ grep { $_->[0] eq "Module-DynamicSubModule" }
                   map { [ $_->{distname_info}->dist, $_->{distname_info}->version, $_->{mtime} ] } @dist_infos],
               [ [ qw|Module-DynamicSubModule 0.01 1194726542|] ] );
}

{
    my @dist_names = $cpan2git->dist_names();
    is_deeply( [sort @dist_names], [sort qw[Locale-PO Decision-Markov Module-DynamicSubModule Plucene-Plugin-Analyzer-MetaphoneAnalyzer]] );
}

{
    my @ordered_dist = $cpan2git->ordered_dist_infos_by_distname( 'Plucene-Plugin-Analyzer-MetaphoneAnalyzer' );
    is_deeply( [map { $_->{distname_info}->version } @ordered_dist],
               [qw[1.0 1.01 1.02]] );

    my $module_name = "Plucene-Plugin-Analyzer-MetaphoneAnalyzer";
    my @tagnames = map { $cpan2git->dist_tagname( $_ ) } @ordered_dist;

    is_deeply( [@tagnames],
               ["$module_name-1.0", "$module_name-1.01", "$module_name-1.02"] );
}

{
    my $distname = 'Plucene-Plugin-Analyzer-MetaphoneAnalyzer';
    ok( not $cpan2git->dist_has_repository( $distname ) );
    $cpan2git->create_dist_repository( $distname );
    ok( $cpan2git->dist_has_repository( $distname ) );
}

{
    my $distname = 'Plucene-Plugin-Analyzer-MetaphoneAnalyzer';
    my $distrepos = $cpan2git->dist_repos_dir($distname);
    run("touch", "$distrepos/.foo");
    ok( -e "$distrepos/.foo" );
    $cpan2git->update_all();

    chdir("$distrepos");

    is( `git tag -l`, "$distname-1.0\n$distname-1.01\n$distname-1.02\n" );

    my $tree_sha = `git log -n1 --pretty='format:%T' 'refs/tags/$distname-1.0'`;
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

}
