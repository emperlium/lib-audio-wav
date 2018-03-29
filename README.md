# lib-audio-wav

Modules for reading & writing uncompressed WAV files.

## Installation

You'll also need to install the lib-base repository from this account.

    perl Makefile.PL
    make test
    sudo make install

## Reading Example

    use Nick::Audio::Wav::Read '$WAV_BUFFER';

    use Nick::Audio::PulseAudio;

    my $wav = Nick::Audio::Wav::Read -> new( 'test.wav' );

    my $pulse = Nick::Audio::PulseAudio -> new(
        'sample_rate'   => $wav -> get_sample_rate(),
        'channels'      => $wav -> get_channels(),
        'buffer_in'     => \$WAV_BUFFER
    );

    while (
        $wav -> read( 512 )
    ) {
        $pulse -> play();
    }

## Writing Example

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

## Reading Methods

### new()

Instantiates a new Nick::Audio::Wav::Read object.

Takes a single parameter, the WAV file to read.

### read()

Takes a number of bytes to read as an argument, returns the number of bytes read.

The data is read into the **$WAV\_BUFFER** scalar, which is exported by the module.

### details()

Returns a hash with the following elements.

- channels

    Number of audio channels.

- sample\_rate

    Sample rate (e.g. 44100).

- bits\_sample

    Number of bits per sample (e.g. 8, 16 or 24).

- samples

    Total number of samples (exclusive of channels).

- length

    Length of the file in seconds.

- info

    A reference to a hash containing metadata present in the file.

    Example elements: **title**, **artist**, **comments**, **copyright**, **creationdate**, **engineers**, **genre**, **keywords**, **medium**, **name**, **subject**, **software**, **supplier**, **source**, **digitizer**.

### get\_sample\_rate

Returns the sample rate (e.g. 44100).

### get\_channels

Returns the number of audio channels.

### length\_seconds

Returns the length of the file in seconds.

### samples

Returns the total number of samples (exclusive of channels).

### get\_cues

Returns a reference to a hash containing any labl/cue chunks found in the file.

The key is the cue ID, the value is a reference to a hash containing **position** (sample offset), **label** and **note** entries.

## Writing Methods

### new()

Instantiates a new Nick::Audio::Wav::Write object.

Takes a filename as the first argument, the following arguments as a hash.

There are three mandatory keys.

- channels

    Number of audio channels.

- sample\_rate

    Sample rate (e.g. 44100).

- bits\_sample

    Number of bits per sample (e.g. 8, 16 or 24).

The other keys are optional;

- wave-ex

    Whether the file format is WAVE-FORMAT-EXTENSIBLE.

### write

Writes the audio data currently in the **$WAV\_BUFFER** scalar (exported by the module) to the file.

### add\_cue

Adds a cue point to the file.

Takes three parameters, sample offset (integer), label and note (strings).

If the offset is undefined, the cue will added at the current position.

### close

Closes the current file.

If this isn't called, the file will automatically close when the object is destroyed.
