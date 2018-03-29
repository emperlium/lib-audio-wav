package Nick::Audio::Wav;

use strict;
use warnings;

use base qw(
    Nick::StandardBase Exporter
);

our( @EXPORT_OK, $VERSION, $WAV_BUFFER, %PACK, %INFO );

BEGIN {
    $VERSION = '1.00';
    @EXPORT_OK = qw( $WAV_BUFFER %PACK %INFO );
    my( $type, $data, @keys, $i );
    for (
        [
            'wav' => [ qw(
                format      v
                channels    v
                sample_rate V
                bytes_sec   V
                block_align v
                bits_sample v
            ) ]
        ], [
            'cue' => [ qw(
                id          V
                position    V
                chunk       a4
                cstart      V
                bstart      V
                offset      V
            ) ]
        ]
    ) {
        ( $type, $data ) = @$_;
        my @names;
        undef @keys;
        for (
            $i = 0; $i < $#$data; $i += 2
        ) {
            push @names => $$data[$i];
            push @keys => $$data[ $i + 1 ];
        }
        $PACK{$type} = [
            \@names, join( '', @keys )
        ];
    }
    %INFO = qw(
        IARL    archivallocation
        IART    artist
        ICMS    commissioned
        ICMT    comments
        ICOP    copyright
        ICRD    creationdate
        IENG    engineers
        IGNR    genre
        IKEY    keywords
        IMED    medium
        INAM    name
        IPRD    product
        ISBJ    subject
        ISFT    software
        ISRC    supplier
        ISRF    source
        ITCH    digitizer
    );
}

=pod

=head1 NAME

Nick::Audio::Wav - Base class for the Read & Write modules.

=head1 SYNOPSIS

    use Nick::Audio::Wav::Read;
    use Nick::Audio::Wav::Write;

    my $read = Nick::Audio::Wav::Read -> new( 'in.wav' );
    my $write = Nick::Audio::Wav::Write -> new(
        'out.wav', $read -> details()
    );
    while (
        $read -> read( 512 )
    ) {
        $write -> write();
    }
    $write -> close();

=head1 NOTES

There are no methods, but you can use the class to import the B<$WAV_BUFFER> scalar that is used by the Read & Write modules.

    use Nick::Audio::Wav '$WAV_BUFFER';

=cut

1;
