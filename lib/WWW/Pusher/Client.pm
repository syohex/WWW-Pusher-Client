package WWW::Pusher::Client;
# ABSTRACT: Laughably incomplete Perl client for Pusher WS API

use strict;
use warnings;
use Moo;
use JSON;
use AnyEvent::WebSocket::Client;
use Digest::SHA qw(hmac_sha256_hex);

has 'app_key' => (
    is => 'rw' ,
    required => 1
);

has 'secret' => (
    is => 'rw',
    required => 1
);

has 'channel' => (
    is => 'rw',
    predicate => 'has_channel'
);

has 'scheme' => (
    is => 'rw',
    default => 'ws'
);

has 'port' => (
    is => 'rw',
    default => 80
);

has 'client' => (
    is => 'rw',
    lazy => 1,
    default => sub { shift->{client} // AnyEvent::WebSocket::Client->new }
);

has 'ws_url' => (
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;

        return $self->{scheme} . $self->{_pusher_base} . $self->{port}
        . "/app/" . $self->{app_key}
        . "?protocol=" . $self->{_protocol}
        . "&client=" . $self->{_client_name}
        . "&version=" . $self->{_version}
    }
);

has 'ws_conn' => (
    is => 'rw',
    lazy => 1,
    builder => sub {
        my $self = shift;
        return AnyEvent::WebSocket::Client->new->connect($self->ws_url)->recv;
    }
);

has '_pusher_base' => (
    is => 'ro',
    default => '://ws.pusherapp.com:'
);

has '_protocol' => (
    is => 'ro',
    default => 7
);

has '_client_name' => (
    is => 'ro',
    default => 'perl-pusher-client'
);

has '_version' => (
    is => 'ro',
    default => '0.001'
);

has '_socket_id' => (
    is => 'rw',
);

sub BUILD {
    my $self = shift;

    $self->ws_conn->on(
        next_message => sub {
            my ($conn, $message) = @_;
            my $body = from_json($message->decoded_body);

            if ($body->{event} eq 'pusher:connection_established') {
                $self->_socket_id(from_json($body->{data})->{socket_id});

                $self->subscribe($self->channel) if $self->has_channel;
            }
            else {
                die 'Connection error?' . $message->decoded_body;
            }
        });
}

sub subscribe {
    my $self = shift;
    my $data = {
        channel => $self->channel
    };
    if ($self->channel =~ /^private\-/) {
        $data->{auth} = $self->socket_auth($self->channel);
    }
    $self->ws_conn->send(to_json({
        event => 'pusher:subscribe',
        data => $data
    }));
}

sub socket_auth {
    my ($self, $channel) = @_;
    die 'Missing socket_id, sorry...' unless $self->_socket_id;

    my $plainSignature = $self->_socket_id . ':' . $channel;
    return hmac_sha256_hex($plainSignature, $self->secret);
}

sub trigger {
    my $self = shift;
    my $event = shift // 'ws update';
    my $message = shift;

    $self->ws_conn->send(to_json({
        event => $event,
        channel => $self->channel,
        data => $message
    }));
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Pusher::Client - Laughably incomplete Perl client for Pusher WS API

=head1 VERSION

version 0.01

=head1 AUTHOR

Daniel Gempesaw <gempesaw@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Daniel Gempesaw.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
