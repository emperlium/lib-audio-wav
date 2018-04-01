package Nick::Audio::Wav::Read;

use strict;
use warnings;

use base 'Nick::Audio::Wav';

use Nick::Audio::Wav qw( $WAV_BUFFER %PACK %INFO );
use Nick::Error ':try';

our $WAV_BLOCK = 8192;
our @EXPORT_OK = qw( $WAV_BUFFER $WAV_BLOCK );

=pod

=head1 NAME

Nick::Audio::Wav::Read - Module for reading uncompressed WAV files.

=head1 SYNOPSIS

    use Nick::Audio::Wav::Read qw( $WAV_BUFFER $WAV_BLOCK );

    use Nick::Audio::PulseAudio;

    $WAV_BLOCK = 512;

    my $wav = Nick::Audio::Wav::Read -> new( 'test.wav' );

    my $pulse = Nick::Audio::PulseAudio -> new(
        'sample_rate'   => $wav -> get_sample_rate(),
        'channels'      => $wav -> get_channels(),
        'buffer_in'     => \$WAV_BUFFER
    );

    while (
        $wav -> read()
    ) {
        $pulse -> play();
    }

=head1 METHODS

=head2 new()

Instantiates a new Nick::Audio::Wav::Read object.

Takes a single parameter, the WAV file to read.

It can also take a second optional parameter, a reference to a scalar which will be used instead of B<$WAV_BUFFER>.

=head2 read()

Optionally takes a number of bytes to read as an argument, returns the number of bytes read.

The data is read into the B<$WAV_BUFFER> scalar, which is exported by the module.

The default number of bytes to read is 8192. This can be changed by importing and changing B<$WAV_BLOCK>.

=head2 details()

Returns a hash with the following elements.

=over 2

=item channels

Number of audio channels.

=item sample_rate

Sample rate (e.g. 44100).

=item bits_sample

Number of bits per sample (e.g. 8, 16 or 24).

=item samples

Total number of samples (exclusive of channels).

=item length

Length of the file in seconds.

=item info

A reference to a hash containing metadata present in the file.

Example elements: B<title>, B<artist>, B<comments>, B<copyright>, B<creationdate>, B<engineers>, B<genre>, B<keywords>, B<medium>, B<name>, B<subject>, B<software>, B<supplier>, B<source>, B<digitizer>.

=back

=head2 get_sample_rate

Returns the sample rate (e.g. 44100).

=head2 get_channels

Returns the number of audio channels.

=head2 length_seconds

Returns the length of the file in seconds.

=head2 samples

Returns the total number of samples (exclusive of channels).

=head2 get_cues

Returns a reference to a hash containing any labl/cue chunks found in the file.

The key is the cue ID, the value is a reference to a hash containing B<position> (sample offset), B<label> and B<note> entries.

=cut

sub new {
    my( $class, $file, $buffer ) = @_;
    -f $file or $class -> throw(
        'Missing file: ' . $file
    );
    my $self = bless {
        'file'  => $file,
        'pos'   => 0,
        'info'  => {}
    } => $class;
    try {
        $self -> _open();
    } catch Nick::Error with {
        $_[0] -> rethrow( 'Problem opening ' . $file )
    };
    if ( $buffer ) {
        ref( $buffer ) eq 'SCALAR'
            or $self -> throw(
                'Expecting buffer to be a reference to a scalar.'
            );
        $$self{'buffer'} = $buffer;
        bless $self => $class . '::UserBuffer';
    }
    return $self;
}

sub details {
    my( $self ) = @_;
    my %details = (
        'length' => $self -> length_seconds(),
        'samples'=> $self -> samples(),
        map(
            { $_ => $$self{$_} }
            qw( channels sample_rate bits_sample info )
        )
    );
    return wantarray ? %details : \%details;
}

sub get_sample_rate {
    return $_[0]{'sample_rate'};
}

sub get_channels {
    return $_[0]{'channels'};
}

sub length_seconds {
    my( $self ) = @_;
    return $$self{'data_length'} / $$self{'bytes_sec'};
}

sub samples {
    my( $self ) = @_;
    return $$self{'data_length'} / $$self{'block_align'};
}

sub get_cues {
    my( $self ) = @_;
    exists( $$self{'cues'} )
        or return undef;
    my $cues = $$self{'cues'};
    my( $labels, $notes ) = map(
        exists( $$self{$_} ) && $$self{$_},
        qw( labl note )
    );
    return {
        map {
            $_ => {
                'position' => $$cues{$_}{'position'},
                ( $labels && exists( $$labels{$_} )
                    ? ( 'label' => $$labels{$_} )
                    : ()
                ),
                ( $notes && exists( $$notes{$_} )
                    ? ( 'note' => $$notes{$_} )
                    : ()
                )
            }
        } keys %$cues
    };
}

sub read {
    my( $self, $len ) = @_;
    $len ||= $WAV_BLOCK;
    $$self{'pos'} + $len > $$self{'data_finish'}
        and $len = $$self{'data_finish'} - $$self{'pos'};
    $len && $len > 0 or return undef;
    $self -> _read_bytes( $len );
    return $len;
}

sub _open {
    my( $self ) = @_;
    open( my $fh, '<' . $$self{'file'} )
        or $self -> throw( $! );
    $$self{'fh'} = $fh;
    binmode $fh;
    $self -> _read_dword() eq 'RIFF'
        or $self -> throw(
            "Expecting type RIFF (first 4 bytes)"
        );
    my $length = $$self{'length'}
        = $self -> _read_long();
    my $pos = \do{ $$self{'pos'} };
    $$pos + $length > -s $$self{'file'}
        and $self -> throw( sprintf
            'Expecting %d bytes of data in a file %d bytes long',
            $$pos + $length, -s $$self{'file'}
        );
    $self -> _read_dword() eq 'WAVE'
        or $self -> throw(
            "Expecting subtype WAVE (bytes 9-12)"
        );
    my( $head, $len, $unpack, $i );
    while ( ! eof $fh && $$pos < $length ) {
        $head = $self -> _read_dword();
        $len = $self -> _read_long();
        $len - $length + $$pos > 8
            and $self -> throw( sprintf
                'Block %s reads %d bytes beyond the end of the file',
                $head, $len - $length + $$pos - 8
            );
        if ( $head eq 'fmt ' ) {
            $unpack = $PACK{'wav'};
            @$self{
                @{ $$unpack[0] }
            } = $self -> _read_and_unpack(
                $len, $$unpack[1]
            );
            $head = delete $$self{'format'};
            ( $$self{'wave-ex'} = ( $head == 65534 ) || 0 )
                || $head == 1
                    or $self-> throw( 'Seems to be compressed' );
            next;
        } elsif ( $head eq 'data' ) {
            @$self{
                qw( data_start data_length )
             } = ( $$pos, $len );
        } elsif ( $head eq 'cue ' ) {
            my %cues;
            $len -= 4;
            if (
                $i = $self -> _read_long()
            ) {
                $unpack = $PACK{'cue'};
                $len -= $i * 24;
                $len < 0 and $self-> throw(
                    "Not enough space in block of $len bytes for $i cues"
                );
                for ( ; $i > 0; $i -- ) {
                    my %cue;
                    @cue{
                        @{ $$unpack[0] }
                    } = $self -> _read_and_unpack(
                        24, $$unpack[1]
                    );
                    $cues{ delete $cue{'id'} } = \%cue;
                }
            }
            $$self{'cues'} = \%cues;
       } elsif ( $head eq 'LIST' ) {
            $head = $self -> _read_dword();
            $len -= 4;
            if ( $head eq 'adtl' ) {
                while ( $len > 4 ) {
                    $len -= 4;
                    $head = $self -> _read_dword();
                    if ( $head eq 'ltxt' ) {
                        $len -= $self -> _skip_bytes( 24 );
                    } else {
                        $i = $self -> _read_long();
                        $i % 2 and $i++;
                        $len -= 4 + $i;
                        if ( $head eq 'labl' || $head eq 'note' ) {
                            $i -= 4;
                            $unpack = $self -> _read_long();
                            $$self{$head}{$unpack} = $self -> _read_string( $i );
                        } else {
                            $self -> _skip_bytes( $i );
                        }
                    }
                }
            } elsif ( $head eq 'INFO' ) {
                while ( $len > 4 ) {
                    $head = $self -> _read_dword();
                    $len -= 4;
                    $i = $self -> _read_long();
                    $i % 2 and $i++;
                    $len -= 4 + $i;
                    if ( exists $INFO{$head} ) {
                        $$self{'info'}{
                            $INFO{$head}
                        } = $self -> _read_string( $i );
                    } else {
                        $self -> _skip_bytes( $i );
                    }
                }
            }
        } elsif ( $head eq 'DISP' ) {
            $len -= 4;
            $len % 2 and $len++;
            if ( $self -> _read_long() == 1 ) {
                $$self{'info'}{'title'} = $self -> _read_string( $len );
           } else {
               $self -> _skip_bytes( $len );
           }
           next;
        } else {
            $len % 2 and $len ++;
            $self -> error(
                "Ignored unknown block type '$head' at $$pos for $len bytes"
            );
        }
        $len and $self -> _skip_bytes( $len );
    }
    if ( exists $$self{'data_start'} ) {
        $i = $$self{'data_start'};
        $$self{'data_finish'} = $i + $$self{'data_length'};
        seek $fh, $i, 0;
        $$pos = $i;
    } else {
        @$self{ qw( data_start data_length data_finish ) }
            = ( 0, 0, 0 );
    }
}

sub _skip_bytes {
    my( $self, $len ) = @_;
    seek $$self{'fh'}, $len, 1;
    $$self{'pos'} += $len;
    return $len;
}

sub _read_bytes {
    my( $self, $len ) = @_;
    $$self{'pos'} += CORE::read(
        $$self{'fh'}, $WAV_BUFFER, $len
    );
}

sub _read_dword {
    $_[0] -> _read_bytes( 4 );
    return $WAV_BUFFER;
}

sub _read_long {
    return $_[0] -> _read_and_unpack( 4, 'V' );
}

sub _read_string {
    return $_[0] -> _read_and_unpack( $_[1], 'Z' . $_[1] );
}

sub _read_and_unpack {
    my( $self, $len, $pack ) = @_;
    $self -> _read_bytes( $len );
    return unpack(
        $pack => $WAV_BUFFER
    );
}

package Nick::Audio::Wav::Read::UserBuffer;

use base 'Nick::Audio::Wav::Read';

sub _read_bytes {
    my( $self, $len ) = @_;
    $$self{'pos'} += CORE::read(
        $$self{'fh'}, ${ $$self{'buffer'} }, $len
    );
}

1;
