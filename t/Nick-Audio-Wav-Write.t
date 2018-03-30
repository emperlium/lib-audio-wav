use strict;
use warnings;

use Test::More tests => 3;
use Digest::MD5 'md5_hex';

BEGIN {
    use_ok 'Nick::Audio::Wav::Write' => '$WAV_BUFFER';
}

our @PARAMS = (
    'mockfilename',
    'channels'      => 1,
    'sample_rate'   => 11025,
    'bits_sample'   => 8
);

my $wav = MockWavWrite -> new( @PARAMS );

my $fh_scalar = $$wav{'fh'} -> string_ref();

$WAV_BUFFER = pack 'C10', ( 128 ) x 10;
$wav -> write();

$wav -> add_cue( 5, 'label64', 'note64' );

$wav -> close();

is(
    md5_hex( $$fh_scalar ),
    '21df4627b1cb29685c015a7d864359c5',
    'expected file contents'
);

my $buffer;
undef $WAV_BUFFER;
$wav = MockWavWrite -> new(
    @PARAMS,
    'buffer_in' => \$buffer
);
$fh_scalar = $$wav{'fh'} -> string_ref();
$buffer = pack 'C10', ( 128 ) x 10;
$wav -> write();
$wav -> close();
is(
    md5_hex( $$fh_scalar ),
    'cce3c52d9cb8da2438ce5ccd051da801',
    'user-supplied buffer'
);

package MockWavWrite;

use base 'Nick::Audio::Wav::Write';

use IO::String;

sub _open {
    return IO::String -> new();
}

package MockWavWrite::UserBuffer;

use base 'Nick::Audio::Wav::Write::UserBuffer';
