package Archive;
use Mojo::Base -base, -signatures, -async_await;

has workdir => undef;

async sub fetch ($self, $http, $url) {
    my $res = await $http->get_p($url);
    my $path = $self->workdir->child($url =~ s{.*/}{}r);
    $res->res->save_to($path);
    $path;
}

async sub extract ($self, $proc, $log, $archive) {
    my $exit = await $proc->run(
        cmd => ["tar", "xf", $archive, "-C", $self->workdir],
        out => $log,
    );
    my $dir = $self->workdir->child($archive->basename =~ s/\.(tar\.gz|tgz)$//r);
    if ($exit == 0 && -d $dir) {
        return $dir;
    } else {
        die;
    }
}

1;
