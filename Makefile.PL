use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Nick::Audio::Wav',
    VERSION_FROM        => 'lib/Nick/Audio/Wav.pm',
    AUTHOR              => 'Nick Peskett',
    PREREQ_PM       => {
        'Fcntl' => 0
    },
    TEST_REQUIRES       => {
        'Test::More' => 0,
        'IO::String' => 0,
        'Digest::MD5' => 0
    }
);
