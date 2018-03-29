use strict;
use warnings;

use Test::More tests => 7;
use Digest::MD5 'md5_base64';

BEGIN {
    use_ok 'Nick::Audio::Wav::Read' => '$WAV_BUFFER';
}

my $wav = Nick::Audio::Wav::Read -> new( 'test.wav' );

is( $wav -> length_seconds(), 0.5, 'length_seconds' );

is_deeply(
    { $wav -> details() }, {
        'channels'      => 1,
        'sample_rate'   => 8000,
        'bits_sample'   => 8,
        'samples'       => 4000,
        'length'        => .5,
        'info'          => { qw(
            title           tlt
            artist          art
            comments        comm
            copyright       cr
            creationdate    date
            engineers       eng
            genre           gnr
            keywords        keys
            medium          med
            name            nme
            subject         sub
            software        pck
            supplier        supp
            source          src
            digitizer       dig
        ) },
    }, 'details()'
);

is_deeply(
    $$wav{'cues'}, {
        1 => {
            'position'  => 2179,
            'chunk'     => 'data',
            'bstart'    => 0,
            'cstart'    => 0,
            'offset'    => 2179
        }
    }, 'decoded cue block'
);

is_deeply(
    $wav -> get_cues(), {
        1 => {
            'position'  => 2179,
            'label'     => 'Cue 1',
            'note'      => 'cue point'
        }
    }, 'get_cues()'
);

is(
    $wav -> read( 4000 ),
    4000,
    'read length'
);
is(
    md5_base64( $WAV_BUFFER ),
    '6g1pu6SSyYz4nVYYwa8isA',
    'read bytes'
);
