
use strict;
use warnings;

=head1 DESCRIPTION

Test to check that .gitignore files inside a distribution are ignore by the CPAN2git framework.

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

    my $module_name = "GitIgnore-Test";
    my $distrepos   = $cpan2git->dist_repos_dir($module_name);

    chdir("$distrepos") or confess("chdir failed: $!");

    my $tree_sha = git_tree_sha("refs/tags/$module_name-1.0");

    is( `git ls-tree -r $tree_sha .`, <<'EOT' );
100644 blob 72e8ffc0db8aad71a934dd11e5968bd5109e54b4	.gitignore
100644 blob dd6d86a43dc9aadd55edad1dc23f6bf16a1e2ccf	test
EOT

}
