package Mojo::Promise::Limiter::UserAgent;
use Mojo::Base 'Mojo::EventEmitter', -signatures, -async_await;

use Mojo::Promise::Limiter;
use Mojo::URL;
use Mojo::UserAgent;
use Scalar::Util 'blessed';

has concurrency => 0;
has limiters => sub { +{} };
has http => sub { Mojo::UserAgent->new(max_connections => 0) };

sub new ($class, $concurrency) {
    $class->SUPER::new(concurrency => $concurrency);
}

sub _limiter ($self, $url) {
    my $key;
    if (blessed $url && $url->isa('Mojo::URL')) {
        $key = $url->host_port;
    } else {
        $key = Mojo::URL->new($url)->host_port;
    }
    $self->{limiters}{$key} ||= do {
        my $limiter = Mojo::Promise::Limiter->new($self->concurrency);
        for my $event (qw(error run queue dequeue)) {
            $limiter->on($event => sub ($, $name) { $self->emit($event => $name) });
        }
        $limiter;
    };
}

sub get_p ($self, $url, @argv) {
    $self->_limiter($url)->limit(sub () { $self->http->get_p($url, @argv) }, $url);
}

1;
