package Mojo::Promise::Limitter::Proc;
use Mojo::Base -base, -signatures, -async_await;

use Mojo::Promise::Limitter;
use Mojo::Proc;

has limitter => undef;

sub new ($class, $concurrency) {
    my $limitter = Mojo::Promise::Limitter->new($concurrency);
    $class->SUPER::new(limitter => $limitter);
}

sub run ($self, %argv) {
    $self->limitter->limit(sub () { Mojo::Proc::run %argv });
}

1;
