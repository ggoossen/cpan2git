
use strict;
use warnings;

=head1 DESCRIPTION

Test to check that everything goes oke even if there are no changes between
versions.

=cut

use lib 't/lib';
use Test::CPAN2git;

use Carp qw(confess);
use Test::More;
use File::Temp qw(tempdir);
use CPAN2git;
use Cwd qw(cwd);

plan('no_plan');

# $testcpan_dir referes to a mini CPAN distribution, containing some distributions for testing.
my $testcpan_dir = cwd() . "/t/test-cpan/cpan";

{
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $testcpan_dir, repos_dir => $repos_dir );

    $cpan2git->update_all();

    my $module_name = "NoChangesBetweenVersions-Test";
    my $distrepos   = $cpan2git->dist_repos_dir($module_name);

    chdir("$distrepos") or confess("chdir failed: $!");

    my $tree_sha_1 = git_tree_sha("refs/tags/$module_name-1.0");
    my $tree_sha_2 = git_tree_sha("refs/tags/$module_name-2.0");
    ok( $tree_sha_1 );
    is( $tree_sha_1, $tree_sha_2, "the trees are indeed identical" );
}
