package Dist;
use Mojo::Base -base, -signatures, -async_await;
use CPAN::Meta;
use Req;
use Config;
use Parse::LocalDistribution;

has dir => undef;
has build_type => undef;
has meta => undef;
has mymeta => undef;
has provides => undef;

sub reqs ($self, $phase) {
    my $meta = $phase eq 'configure' ? $self->meta : $self->mymeta;
    return [] if !$meta;
    my $reqs = $meta->effective_prereqs->requirements_for($phase, 'requires')->as_string_hash;
    [ map { Req->new($_, $reqs->{$_}) } sort keys $reqs->%* ];
}

sub load_meta ($self) {
    $self->meta($self->_load_meta(qw(META.json META.yml)));
    $self;
}

sub load_mymeta ($self) {
    $self->mymeta($self->_load_meta(qw(MYMETA.json MYMETA.yml)));
    $self;
}

sub _load_meta ($self, @try) {
    my ($file) = grep { -f $_ } map { $self->dir->child($_) } @try;
    return if !$file;
    return CPAN::Meta->load_file($file);
}

sub satisfy ($self, $req) {
    my $found = $self->provides->{$req->package};
    !!$found; # XXX version, range
}

sub load_provides ($self) {
    my $provides = Parse::LocalDistribution->new({ALLOW_DEV_VERSION => 1})->parse($self->dir);
    $self->provides(+{ map { $_ => $provides->{$_}{version} } keys $provides->%* });
    $self;
}

sub is_mb ($self) {
    $self->build_type eq 'mb';
}

sub name ($self) {
    $self->dir =~ s{.*/}{}r;
}

sub cmd_configure ($self) {
    $self->is_mb ? [$^X, "Build.PL"] : [$^X, "Makefile.PL"];
}

sub cmd_build ($self) {
    $self->is_mb ? ["./Build"] : [$Config{make}];
}

sub cmd_test ($self) {
    $self->is_mb ? ["./Build", "test"] : [$Config{make}, "test"];
}

1;
