package Resolver;
use Mojo::Base -base, -signatures, -async_await;

package Resolver::MetaDB {
    use Mojo::Base -base, -signatures, -async_await;
    use YAML::PP;

    has url => 'https://cpanmetadb.plackperl.org/v1.0';
    has mirror => 'https://cpan.metacpan.org';

    async sub resolve ($self, $http, $req) {
        my $url = sprintf "%s/package/%s", $self->url, $req->package;
        my $res = await $http->get_p($url);
        my ($yaml) = YAML::PP->new->load_string($res->res->body);
        my $disturl = sprintf "%s/authors/id/%s", $self->mirror, $yaml->{distfile};
        return ($disturl, $yaml->{version});
    }
}

has impl => sub { Resolver::MetaDB->new };

async sub resolve ($self, $http, $req) {
    await $self->impl->resolve($http, $req);
}

1;
