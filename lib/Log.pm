package Log;
use Mojo::Base -base, -signatures, -async;

use POSIX ();

has path => undef;
has fh => undef;

sub new ($class, %argv) {
    my $self = $class->SUPER::new(%argv);
    my $fh = $self->path->open(">>:unix");
    $self->fh($fh);
    $self;
}

sub print ($self, $name, $byte) {
    my $time = POSIX::strftime("%FT%T", localtime);
    $self->fh->say("$time,$name| $_") for split /\n/, $byte;
}

sub cb ($self, $name) {
    sub ($byte) { $self->print($name, $byte) };
}

1;
