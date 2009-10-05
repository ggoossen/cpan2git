package Test::CPAN2git;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = (qw[git_parent_sha git_tree_sha git_commit_sha git_author_name git_author_email git_author_date],
               qw[git_committer_name git_committer_email git_committer_date_unix_timestamp],
               qw[git_commit_subject git_commit_body],
           );


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

sub git_author_name {
    my ($rev) = @_;
    return _git_format_rev($rev, '%an');
}

sub git_author_email {
    my ($rev) = @_;
    return _git_format_rev($rev, '%ae');
}

sub git_author_date {
    my ($rev) = @_;
    return _git_format_rev($rev, '%aD');
}

sub git_committer_name {
    my ($rev) = @_;
    return _git_format_rev($rev, '%cn');
}

sub git_committer_email {
    my ($rev) = @_;
    return _git_format_rev($rev, '%ce');
}

sub git_committer_date_unix_timestamp {
    my ($rev) = @_;
    return _git_format_rev($rev, '%ct');
}

sub git_commit_subject {
    my ($rev) = @_;
    return _git_format_rev($rev, '%s');
}

sub git_commit_body {
    my ($rev) = @_;
    return _git_format_rev($rev, '%b');
}

1;
