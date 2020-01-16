package App;
use Mojo::Base -base, -signatures, -async;

use CPAN::Meta;
use Dist;
use Log;
use Mojo::File;
use Mojo::UserAgent;
use Proc;
use YAML::PP ();

use Mojo::Util 'dumper';

has http => sub ($) { Mojo::UserAgent->new };
has workdir => sub ($) { Mojo::File->new("work-" . time)->make_path };
has log => sub ($self) { Log->new(path => $self->workdir->child("build.log")) };

async sub install ($self, $package) {
    my ($distpath, $version) = await $self->resolve($package);
    my $url = "https://cpan.metacpan.org/authors/id/$distpath";
    my $tarball = await $self->fetch_tarball($url);
    my $dir = await $self->extract_tarball($tarball);
    my $dist = Dist->new(dir => $dir)->load_meta;
    for my $req ($dist->reqs('configure')->@*) {
        warn sprintf "%s configure %s %s\n", $dist->name, $req->package, $req->range;
    }
    my $ok1 = await $self->configure($dist);
    $dist->load_mymeta;
    for my $req ($dist->reqs('runtime')->@*) {
        warn sprintf "%s runtime %s %s\n", $dist->name, $req->package, $req->range;
    }
    my $ok2 = await $self->build($dist);
    my $ok3 = await $self->test($dist);
}

async sub resolve ($self, $package) {
    $self->log->print(main => "Resolving $package");
    my $url = "https://cpanmetadb.plackperl.org/v1.0/package/$package";
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
    my $exit = await Proc::run
        cmd => ["tar", "xf", $tarball, "-C", $self->workdir],
        out => $self->log->cb("main"),
    ;
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
    my $exit = await Proc::run
        cmd => $dist->cmd_configure,
        dir => $dist->dir,
        out => $self->log->cb($name),
    ;
    $exit == 0;
}

async sub build ($self, $dist) {
    my $name = $dist->name;
    $self->log->print($name => "Building distribution");
    my $exit = await Proc::run
        cmd => $dist->cmd_build,
        dir => $dist->dir,
        out => $self->log->cb($name),
    ;
    $exit == 0;
}

async sub test ($self, $dist) {
    my $name = $dist->name;
    $self->log->print($name => "Testing distribution");
    my $exit = await Proc::run
        cmd => $dist->cmd_test,
        dir => $dist->dir,
        out => $self->log->cb($name),
    ;
    $exit == 0;
}

1;
