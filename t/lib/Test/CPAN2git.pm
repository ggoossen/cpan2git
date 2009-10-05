package Test::CPAN2git;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw[git_parent_sha git_tree_sha git_commit_sha];

sub _git_format_rev {
    my ($rev, $format) = @_;
    my $x = `git log -n1 --pretty='format:$format' $rev`;
    chomp($x);
    return $x;
}

sub git_parent_sha {
    my ($rev) = @_;
    return _git_format_rev($rev, '%P');
}

sub git_tree_sha {
    my ($rev) = @_;
    return _git_format_rev($rev, '%T');
}

sub git_commit_sha {
    my ($rev) = @_;
    return _git_format_rev($rev, '%H');
}

1;
