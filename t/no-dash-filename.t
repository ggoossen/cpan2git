
use strict;
use warnings;

=head1 DESCRIPTION

Test to check that files with the module name directly concatenated with version makes a tag with a version with a dash.

=cut

use lib 't/lib';

use CPAN2git;
use Carp qw(confess);
use Cwd qw(cwd);
use File::Temp qw(tempdir);
use Test::CPAN2git;
use Test::More;

plan('no_plan');

# $testcpan_dir referes to a mini CPAN distribution, containing some distributions for testing.
my $testcpan_dir = cwd() . "/t/test-cpan/cpan";

{
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $testcpan_dir, repos_dir => $repos_dir );

    $cpan2git->update_all();

    my $module_name = "NoDashTest";
    my $distrepos   = $cpan2git->dist_repos_dir($module_name);

    chdir("$distrepos") or confess("could not change dir: $!");

    ok( git_tree_sha("refs/tags/$module_name-1.0") );
}

1;
