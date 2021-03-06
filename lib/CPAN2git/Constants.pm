package CPAN2git::Constants;

use strict;
use warnings;

=item DISTS_INSECURE_TARBALL

List of distributions which contains insecure tarballs (e.g containing '..')

=cut

sub DISTS_INSECURE_TARBALL {
    return (qw[
                  Array-Sort-0.02
                  Math-Systems-0.01
                  Array-Parallel-0.01
              ]);
}

=item SKIP_DISTS

List of distributions which should be skipped because there is something wrong with them.

=cut

sub SKIP_DISTS {
    return (
        DISTS_INSECURE_TARBALL,
    );
}

1;
