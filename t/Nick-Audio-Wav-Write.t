use strict;
use warnings;

use Test::More tests => 2;
use Digest::MD5 'md5_hex';

BEGIN {
    use_ok 'Nick::Audio::Wav::Write' => '$WAV_BUFFER';
}

my $wav = MockWavWrite -> new(
    'mockfilename',
    'channels'      => 1,
    'sample_rate'   => 11025,
    'bits_sample'   => 8
);

my $fh_scalar = $$wav{'fh'} -> string_ref();

$WAV_BUFFER = pack 'C10', ( 128 ) x 10;
$wav -> write();

$wav -> add_cue( 5, 'label64', 'note64' );

$wav -> close();

is(
    md5_hex( $$fh_scalar ),
    '21df4627b1cb29685c015a7d864359c5',
    'Expected file contents.'
);

package MockWavWrite;

use base 'Nick::Audio::Wav::Write';

use IO::String;

sub _open {
    return IO::String -> new();
}
