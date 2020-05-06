package Mojo::Promise::Limiter::Proc;
use Mojo::Base -base, -signatures, -async_await;

use Mojo::Promise::Limiter;
use Mojo::Proc;

has limiter => undef;

sub new ($class, $concurrency) {
    my $limiter = Mojo::Promise::Limiter->new($concurrency);
    $class->SUPER::new(limiter => $limiter);
}

sub run ($self, %argv) {
    $self->limiter->limit(sub () { Mojo::Proc::run %argv });
}

1;
