package Repo;
use Mojo::Base -base, -signatures, -async_await;
use Module::Corelist;

has dists => sub { [] };

sub add ($self, $dist) {
    push $self->dists->@*, $dist;
}

sub satisfy ($self, $req) {
    return 1 if $req->package eq 'perl';
    return 1 if $self->core($req);
    for my $dist ($self->dists->@*) {
        return 1 if $dist->satisfy($req);
    }
    return 0;
}

sub core ($self, $req) {
    exists $Module::CoreList::version{$]}{$req->package};
}

1;
