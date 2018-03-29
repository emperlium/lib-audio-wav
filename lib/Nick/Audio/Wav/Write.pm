package Nick::Audio::Wav::Write;

use strict;
use warnings;

use base 'Nick::Audio::Wav';

use Fcntl;

use Nick::Audio::Wav qw( $WAV_BUFFER %PACK );
use Nick::Error ':try';

our @EXPORT_OK = qw( $WAV_BUFFER );

=pod

=head1 NAME

Nick::Audio::Wav::Write - Module for writing uncompressed WAV files.

=head1 SYNOPSIS

    use Nick::Audio::Wav::Write '$WAV_BUFFER';

    use Nick::Audio::FLAC;

    my $flac = Nick::Audio::FLAC -> new(
        'test.flac',
        'buffer_out' => \$WAV_BUFFER
    );

    my $wav = Nick::Audio::Wav::Write -> new(
        '/tmp/test.wav',
        'channels'      => $flac -> get_channels(),
        'sample_rate'   => $flac -> get_sample_rate(),
        'bits_sample'   => 16
    );

    while ( $flac -> read() ) {
        $wav -> write();
    }

=head1 METHODS

=head2 new()

Instantiates a new Nick::Audio::Wav::Write object.

Takes a filename as the first argument, the following arguments as a hash.

There are three mandatory keys.

=over 2

=item channels

Number of audio channels.

=item sample_rate

Sample rate (e.g. 44100).

=item bits_sample

Number of bits per sample (e.g. 8, 16 or 24).

=back

The other keys are optional;

=over 2

=item wave-ex

Whether the file format is WAVE-FORMAT-EXTENSIBLE.

=back

=head2 write

Writes the audio data currently in the B<$WAV_BUFFER> scalar (exported by the module) to the file.

=head2 add_cue

Adds a cue point to the file.

Takes three parameters, sample offset (integer), label and note (strings).

If the offset is undefined, the cue will added at the current position.

=head2 close

Closes the current file.

If this isn't called, the file will automatically close when the object is destroyed.

=cut

sub new {
    my( $class, $file, %details ) = @_;
    my @missing = grep(
        ! exists( $details{$_} ),
        qw( channels sample_rate bits_sample )
    );
    ! $file and unshift @missing => 'filename';
    @missing and $class -> throw(
        'Missing arguments: ' . join ', ', @missing
    );
    exists( $details{'format'} )
        or $details{'format'} = (
            exists( $details{'wave-ex'} )
                && $details{'wave-ex'}
                    ? 65534 : 1
        );
    $details{'block_align'} ||= $details{'channels'} * (
        int( $details{'bits_sample'} / 8 )
            + ( $details{'bits_sample'} % 8 ? 1 : 0 )
    );
    $details{'bytes_sec'} ||= $details{'block_align'} * $details{'sample_rate'};
    my $self = bless {
        'file' => $file,
        'cues' => [],
        %details
    } => $class;
    try {
        $$self{'fh'} = $self -> _open();
    } catch Nick::Error with {
        $_[0] -> rethrow( 'Problem opening ' . $file )
    };
    my $pack = $PACK{'wav'};
    syswrite $$self{'fh'}, (
        'RIFF' . pack( 'V', 0 )
        . 'WAVE'
        . 'fmt ' . pack(
            'V' . $$pack[1],
            16, @$self{ @{ $$pack[0] } }
        )
        . 'data' . pack( 'V', 0 )
    ), 44;
    @$self{ qw( pos_riff pos_data len_riff len_data ) }
        = ( 4, 40, 36, 0 );
    return $self;
}

sub add_cue {
    my( $self, $pos, $label, $note ) = @_;
    my %cue = (
        'pos' => (
            defined( $pos )
            ? $pos
            : $$self{'len_data'} / $$self{'block_align'}
        )
    );
    $label and $cue{'labl'} = $label;
    $note and $cue{'note'} = $note;
    push @{ $$self{'cues'} } => \%cue;
}

sub _open {
    my( $self ) = @_;
    sysopen(
        my $fh, $$self{'file'},
        O_WRONLY | O_CREAT | O_TRUNC | O_BINARY
     ) or $self -> throw( $! );
    return $fh;
}

sub write {
    my( $self ) = @_;
    $$self{'len_data'} += syswrite $$self{'fh'}, $WAV_BUFFER;
}

sub close {
    my( $self ) = @_;
    exists( $$self{'fh'} )
        or return;
    my $fh = delete $$self{'fh'};
    if ( $$self{'len_data'} % 2 ) {
        syswrite $fh, "\0", 1;
        $$self{'len_data'} ++;
    }
    @{ $$self{'cues'} }
        and $self -> _write_cues( $fh );
    $$self{'len_riff'} += $$self{'len_data'};
    for ( qw( riff data ) )  {
        seek $fh, $$self{ 'pos_' . $_ }, 0;
        syswrite $fh, pack( 'V', $$self{ 'len_' . $_ } ), 4;
    }
    close $fh;
}

sub DESTROY {
    ref( $_[0] )
        and $_[0] -> close();
}

sub _write_cues {
    my( $self, $fh ) = @_;
    my @cues = @{ $$self{'cues'} };
    my $id = 0;
    my $pack = $PACK{'cue'}[1];
    my $cue = pack 'V', scalar @cues;
    my $adtl = '';
    my $pos;
    for my $q ( @cues ) {
        $pos = $$q{'pos'};
        $cue .= pack(
            $pack, ++$id, $pos, 'data', 0, 0, $pos
        );
        for (
            grep exists( $$q{$_} ), qw( labl note )
        ) {
            $pos = $$q{$_};
            length( $pos ) % 2
                or $pos .= "\0";
            $adtl .= $_ . pack( 'V', length( $pos ) + 5 )
                        . pack( 'V', $id ) . $pos . "\0";
        }
    }
    $pos = length $cue;
    syswrite $fh, 'cue ' . pack( 'V', $pos ) . $cue, $pos += 8;
    $$self{'len_riff'} += $pos;
    if ( $adtl ) {
        $pos = length( $adtl ) + 4;
        syswrite $fh, 'LIST' . pack( 'V', $pos ) . 'adtl' . $adtl;
        $$self{'len_riff'} += $pos + 8;
    }
}

1;
