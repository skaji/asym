package App;
use Mojo::Base -base, -signatures, -async_await;

use CPAN::Meta;
use Mojo::File;
use Mojo::Promise::Limiter::Proc;
use Mojo::Promise::Limiter::UserAgent;
use Mojo::UserAgent;
use Mojo::Util 'dumper';

use Archive;
use Dist;
use Log;
use Repo;
use Resolver;

has http => sub ($self) { Mojo::Promise::Limiter::UserAgent->new(5) };
has proc => sub ($self) { Mojo::Promise::Limiter::Proc->new(5) };
has resolver => sub ($self) { Resolver->new };
has archive => sub ($self) { Archive->new(workdir => $self->workdir) };
has workdir => sub ($self) { Mojo::File->new("work-" . time)->make_path };
has log => sub ($self) { Log->new(path => $self->workdir->child("build.log")) };
has repo => sub ($self) { Repo->new };

async sub install ($self, $req) {
    $self->log->print(main => "Resolving @{[$req->package]}");
    my ($disturl, $version) = await $self->resolver->resolve($self->http, $req);

    $self->log->print(main => "Fetching $disturl");
    my $tarball = await $self->archive->fetch($self->http, $disturl);
    my $dir = await $self->archive->extract($self->proc, $self->log->cb("main"), $tarball);
    my $dist = await Dist->load($dir);
    $self->repo->add($dist);

    my @req_configure = grep { $self->repo->satisfy($_) } $dist->reqs('configure')->@*;

    $self->log->print($dist->name => "Configuring distribution");
    my $ok1 = await $dist->configure($self->proc, $self->log->cb($dist->name));

    my @req_build = grep { $self->repo->satisfy($_) } $dist->reqs('build')->@*;

    $self->log->print($dist->name => "Building distribution");
    my $ok2 = await $dist->build($self->proc, $self->log->cb($dist->name));

    my @req_runtime = grep { $self->repo->satisfy($_) } $dist->reqs('runtime')->@*;

    $self->log->print($dist->name => "Testing distribution");
    my $ok3 = await $dist->test($self->proc, $self->log->cb($dist->name));
}

1;
