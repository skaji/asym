package Req;
use Mojo::Base -base, -signatures, -async;

has package => undef;
has range => undef;

sub new ($class, $package, $range = 0) {
    $class->SUPER::new(package => $package, range => $range);
}

1;
