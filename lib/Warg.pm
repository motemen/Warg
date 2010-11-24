package Warg;
use Any::Moose;

with 'Warg::Role::Log';
with any_moose 'X::Getopt::Strict';

our $VERSION = '0.01';

# is
# - warg main
# has
# - downloader manager
# - interface
# - logger
# does
# - setup components from command args
# - run everything

has manager => (
    is  => 'rw',
    isa => 'Warg::Manager',
    lazy_build => 1,
);

sub _build_manager {
    my $self = shift;
    return Warg::Manager->new(
        interface      => $self->interface,
        logger         => $self->logger,
        control_listen => $self->control_listen,
        $self->scripts_dir  ? ( scripts_dir  => $self->scripts_dir  ) : (),
        $self->download_dir ? ( download_dir => $self->download_dir ) : (),
    );
}

has interface => (
    is => 'rw',
    lazy_build => 1,
);

sub _build_interface {
    my $self = shift;

    my $interface_class = 'Warg::Interface::' . $self->interface_class;
    $interface_class->require or die "Could not require $interface_class";

    Getopt::Long::Configure('no_pass_through');

    local @ARGV = @{ $self->extra_argv };
    return $interface_class->new_with_options(logger => $self->logger);
}

# --scripts-dir ./scripts
has scripts_dir => (
    is  => 'rw',
    isa => 'Str',
    metaclass => 'Getopt',
    cmd_flag  => 'scripts-dir',
);

# --download-dir ./downloads
has download_dir => (
    is  => 'rw',
    isa =>' Str',
    metaclass => 'Getopt',
    cmd_flag  => 'download-dir',
);

# --interface IRC
has interface_class => (
    is  => 'rw',
    isa => 'Str',
    metaclass   => 'Getopt',
    default     => 'Console',
    cmd_flag    => 'interface',
    cmd_aliases => [ 'i' ],
);

# --debug
has debug => (
    is  => 'rw',
    isa => 'Bool',
    metaclass => 'Getopt',
);

# --control-listen /tmp/warg_socket
has control_listen => (
    is  => 'rw',
    isa => 'Str',
    metaclass => 'Getopt',
    cmd_flag  => 'control-listen',
);

no Any::Moose;

__PACKAGE__->meta->make_immutable;

use Warg::Manager;

use Getopt::Long;
use Getopt::Long::Descriptive;
use UNIVERSAL::require;

Getopt::Long::Configure('pass_through');

sub BUILD {
    my $self = shift;
    $self->log_level('debug') if $self->debug;
}

sub run {
    my $self = shift;
    local $SIG{__DIE__} = sub {
        $self->log(error => $_[0]);
    };
    $self->manager->start_interactive;
}

1;

__END__

=head1 NAME

Warg - Downloader

=head1 SYNOPSIS

    % ./warg.pl # implies --interface Console

    % ./warg.pl -i IRC --server localhost:6667 --channels #foo

=head1 DESCRIPTION

Warg is a downloader extensible by scripts.

Once a URL is feeded, Warg searches its downloader scripts directory for applicable one to that URL.
When found, Warg produces a job for downloading. Downloader can ask user for input, such as captcha answer.

=head1 DOWNLOADER

A downloader (for a site) is a Perl script.

The script should have C<our $Config> which is a C<HTTP::Config> or a regexp that matches URL.

The script must return a coderef, which receives C<Warg::Downloader> and C<URI> as argumetns.

    our $Config = HTTP::Config->new;
    $Config->add(m_host => ...);

    sub {
        my ($self, $url) = @_;
        ...
        $self->download($file_url);
    };

TBD

=head1 AUTHOR

motemen E<lt>motemen@gmail.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
