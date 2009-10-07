
use strict;
use warnings;

=head1 DESCRIPTION

Test to check that authors with non-ASCII characters work correctly.

=cut

use lib 't/lib';

use charnames ':full';
use Encode ('decode_utf8');
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

    my $module_name = "UTF8Author-Test";
    my $distrepos   = $cpan2git->dist_repos_dir($module_name);

    chdir("$distrepos") or confess("chdir failed: $!");

    my $author_name = decode_utf8( git_author_name("refs/tags/$module_name-1.0") );

    is( $author_name, "T\N{LATIN SMALL LETTER E WITH DIAERESIS}st UTF-8 \N{WHITE SMILING FACE}" );

}
