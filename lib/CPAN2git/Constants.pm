package CPAN2git::Constants;

use strict;
use warnings;

=item DISTS_WITH_NON_READABLE_FILES

List of distributions which have non-readable files.

=cut

sub DISTS_WITH_NON_READABLE_FILES {
    return (qw|LWP-UserAgent-ProxyAny-1.02|);
}

=item SKIP_DISTS

List of distributions which should be skipped because there is something wrong with them.

=cut

sub SKIP_DISTS {
    return (
        DISTS_WITH_NON_READABLE_FILES,
    );
}

1;
