
use strict;
use warnings;

=head1 DESCRIPTION

Test to check that a broken tarball is properly ignored.

=cut

use lib 't/lib';
use Test::CPAN2git;

use Test::More;
use File::Temp qw(tempdir);
use CPAN2git;
use Cwd qw(cwd);
use Scriptalicious;

plan('no_plan');

$Scriptalicious::VERBOSE = -1;

# $testcpan_dir referes to a mini CPAN distribution, containing some distributions for testing.
my $testcpan_dir = cwd() . "/t/test-cpan/cpan";

{
    my $repos_dir = tempdir( CLEANUP => 1 );
    my $cpan2git = CPAN2git->new( cpan_dir => $testcpan_dir, repos_dir => $repos_dir );

    my $module_name = "Broken-Tarball";

    $cpan2git->update_dist($module_name);

    my $distrepos   = $cpan2git->dist_repos_dir($module_name);

    ok( (not -d $distrepos), "Repository is not created");
}

END {
    chdir("/"); # get away from temporary directory
}
