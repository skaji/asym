package Proc;
use Mojo::Base -strict, -signatures, -async;

use Mojo::IOLoop::Stream;
use Mojo::IOLoop;
use Mojo::Promise;
use POSIX ();

use Exporter 'import';
our @EXPORT_OK = qw(run);

my $EV = Mojo::IOLoop->singleton->reactor->isa('Mojo::Reactor::EV');

sub _exec (%argv) {
    my $cmd = $argv{cmd};
    my $env = $argv{env};
    my $dir = $argv{dir};
    my $write = $argv{write};
    open STDOUT, ">&", $write;
    open STDERR, ">&", \*STDOUT;
    chdir $dir if $dir;
    %ENV = (%ENV, $env->%*) if $env;
    exec { $cmd->[0] } $cmd->@*;
    exit 127;
}

sub run (%argv) {
    my $cmd = $argv{cmd};
    my $env = $argv{env};
    my $dir = $argv{dir};
    my $out = $argv{out};
    my $timtout = $argv{timeout};

    $out->("Executing @{$cmd}");
    pipe my $read, my $write;
    my $pid = fork // die;
    if ($pid == 0) {
        Mojo::IOLoop->singleton->reset;
        close $read;
        POSIX::setpgid(0, 0);
        _exec cmd => $cmd, env => $env, dir => $dir, write => $write;
    }
    close $write;

    my $promise = Mojo::Promise->new;
    if ($EV) {
        $promise->{_ev} = 1;
        my $child = EV::child($pid, 0, sub ($w, @) {
            delete $promise->{_ev_child};
            $promise->resolve($w->rstatus);
        });
        $promise->{_ev_child} = $child;
    }

    my $stream = Mojo::IOLoop::Stream->new($read)->timeout(0);
    $promise->{_stream} = $stream;

    $stream->on(read => sub ($, $byte) { $out->($byte) });
    $stream->on(close => sub ($) {
        delete $promise->{_stream};
        return if $promise->{_ev};
        my $ret = waitpid $pid, 0;
        if ($ret > 0) {
            $promise->resolve($?);
        } else {
            $promise->reject("waitpid $pid, 0: $!");
        }
    });
    $stream->start;
    $promise;
}

1;
