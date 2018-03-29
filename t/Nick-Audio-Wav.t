use strict;
use warnings;

use Test::More tests => 3;
use Digest::MD5 'md5_hex';

BEGIN {
    use_ok 'Nick::Audio::Wav::Read';
    use_ok 'Nick::Audio::Wav::Write';
}

my $read = Nick::Audio::Wav::Read -> new( 'test.wav' );
my $write = MockWavWrite -> new(
    'mockfilename',
    $read -> details()
);
my $write_ref = $$write{'fh'} -> string_ref();

while (
    $read -> read( 512 )
) {
    $write -> write();
}

my $cues = $read -> get_cues();
if ( $cues ) {
    for ( sort keys %$cues ) {
        $write -> add_cue(
            @{ $$cues{$_} }{
                qw( position label note )
            }
        );
    }
}

$write -> close();

is(
    md5_hex( $$write_ref ),
    '3836d0c0c3c953a6eb4fc4dc73b93467',
    'Expected file contents.'
);

package MockWavWrite;

use base 'Nick::Audio::Wav::Write';

use IO::String;

sub _open {
    return IO::String -> new();
}
