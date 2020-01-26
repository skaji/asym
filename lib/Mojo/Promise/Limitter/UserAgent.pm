package Mojo::Promise::Limitter::UserAgent;
use Mojo::Base 'Mojo::EventEmitter', -signatures, -async_await;

use Mojo::Promise::Limitter;
use Mojo::URL;
use Mojo::UserAgent;
use Scalar::Util 'blessed';

has concurrency => 0;
has limitters => sub { +{} };
has http => sub { Mojo::UserAgent->new(max_connections => 0) };

sub new ($class, $concurrency) {
    $class->SUPER::new(concurrency => $concurrency);
}

sub _limitter ($self, $url) {
    my $key;
    if (blessed $url && $url->isa('Mojo::URL')) {
        $key = $url->host_port;
    } else {
        $key = Mojo::URL->new($url)->host_port;
    }
    $self->{limitters}{$key} ||= do {
        my $limitter = Mojo::Promise::Limitter->new($self->concurrency);
        for my $event (qw(error run queue dequeue)) {
            $limitter->on($event => sub ($limitter, @argv) { $self->emit($event => @argv) });
        }
        $limitter;
    };
}

sub get_p ($self, $url, @argv) {
    $self->_limitter($url)->limit(sub () { $self->http->get_p($url, @argv) }, $url);
}

1;
