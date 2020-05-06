package App;
use Mojo::Base -base, -signatures, -async_await;

use CPAN::Meta;
use Dist;
use Log;
use Mojo::File;
use Mojo::UserAgent;
use Mojo::Promise::Limiter::UserAgent;
use Mojo::Promise::Limiter::Proc;
use YAML::PP ();
use Repo;

use Mojo::Util 'dumper';

has http => sub ($self) { Mojo::Promise::Limiter::UserAgent->new(5) };
has proc => sub ($self) { Mojo::Promise::Limiter::Proc->new(5) };
has workdir => sub ($self) { Mojo::File->new("work-" . time)->make_path };
has log => sub ($self) { Log->new(path => $self->workdir->child("build.log")) };
has repo => sub ($self) { Repo->new };

async sub install ($self, $req) {
    my ($distpath, $version) = await $self->resolve($req);
    my $url = "https://cpan.metacpan.org/authors/id/$distpath";
    my $tarball = await $self->fetch_tarball($url);
    my $dir = await $self->extract_tarball($tarball);
    my $dist = await $self->load_dist($dir);
    $self->repo->add($dist);

    my @req_configure = grep { $self->repo->satisfy($_) } $dist->reqs('configure')->@*;

    my $ok1 = await $self->configure($dist);
    $dist->load_mymeta;

    my @req_build = grep { $self->repo->satisfy($_) } $dist->reqs('build')->@*;

    my $ok2 = await $self->build($dist);

    my @req_runtime = grep { $self->repo->satisfy($_) } $dist->reqs('runtime')->@*;
}

async sub load_dist ($self, $dir) {
    Dist->new(dir => $dir)->load_meta->load_provides;
}

async sub resolve ($self, $req) {
    $self->log->print(main => "Resolving @{[$req->package]}");
    my $url = "https://cpanmetadb.plackperl.org/v1.0/package/" . $req->package;
    my $res = await $self->http->get_p($url);
    my ($yaml) = YAML::PP->new->load_string($res->res->body);
    return ($yaml->{distfile}, $yaml->{version});
}

async sub fetch_tarball ($self, $url) {
    $self->log->print(main => "Fetching $url");
    my $res = await $self->http->get_p($url);
    my $path = $self->workdir->child($url =~ s{.*/}{}r);
    $res->res->save_to($path);
    $path;
}

async sub extract_tarball ($self, $tarball) {
    $self->log->print(main => "Extracting $tarball");
    my $exit = await $self->proc->run(
        cmd => ["tar", "xf", $tarball, "-C", $self->workdir],
        out => $self->log->cb("main"),
    );
    my $dir = $self->workdir->child($tarball->basename =~ s/\.(tar\.gz|tgz)$//r);
    if ($exit == 0 && -d $dir) {
        return $dir;
    } else {
        die;
    }
}

async sub configure ($self, $dist) {
    my $name = $dist->name;
    $self->log->print($name => "Configuring distribution");
    $dist->build_type(-f $dist->dir->child("Build.PL") ? "mb" : "mm");
    my $exit = await $self->proc->run(
        cmd => $dist->cmd_configure,
        dir => $dist->dir,
        out => $self->log->cb($name),
    );
    $exit == 0;
}

async sub build ($self, $dist) {
    my $name = $dist->name;
    $self->log->print($name => "Building distribution");
    my $exit = await $self->proc->run(
        cmd => $dist->cmd_build,
        dir => $dist->dir,
        out => $self->log->cb($name),
    );
    $exit == 0;
}

async sub test ($self, $dist) {
    my $name = $dist->name;
    $self->log->print($name => "Testing distribution");
    my $exit = await $self->proc->run(
        cmd => $dist->cmd_test,
        dir => $dist->dir,
        out => $self->log->cb($name),
    );
    $exit == 0;
}

1;
