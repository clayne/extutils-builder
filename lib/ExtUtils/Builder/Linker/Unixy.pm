package ExtUtils::Builder::Linker::Unixy;

use Moo;

use Carp ();
use ExtUtils::Builder::Argument;
use ExtUtils::Builder::Role::Command;

with Command(method => 'link'), 'ExtUtils::Builder::Role::Linker';

sub add_library_dirs {
	my ($self, $dirs, %opts) = @_;
	$self->add_argument(ranking => _fix_ranking(30, $opts{ranking}), value => [ map { "-L$_" } @{$dirs} ]);
	return;
}

sub add_libraries {
	my ($self, $libraries, %opts) = @_;
	$self->add_argument(ranking => _fix_ranking(35, $opts{ranking}), value => [ map { "-l$_" } @{$libraries} ]);
	return;
}

has _ccdlflags => (
	is => 'ro',
	default => sub { 
		my $self = shift;
		require ExtUtils::Helpers;
		return [ ExtUtils::Helpers::split_like_shell($self->config->get('ccdlflags')) ];
	},
	lazy => 1,
);

has _lddlflags => (
	is => 'ro',
	default => sub {
		my $self = shift;
		require ExtUtils::Helpers;
		my $lddlflags = $self->config->get('lddlflags');
		my $optimize = $self->config->get('optimize');
		$lddlflags =~ s/ ?\Q$optimize//;
		my %ldflags = map { ( $_ => 1 ) } ExtUtils::Helpers::split_like_shell($self->config->get('ldflags'));
		return [ grep { not $ldflags{$_} } ExtUtils::Helpers::split_like_shell($lddlflags) ];
	},
	lazy => 1,
);

sub get_linker_flags {
	my ($self, %opts) = @_;
	my $type = $self->type;
	if ($type eq 'shared-library' or $type eq 'loadable-object') {
		return $self->_lddlflags;
	}
	elsif ($type eq 'executable') {
		return $self->_has_export && $self->export eq 'all' ? $self->_ccdlflags : [];
	}
	else {
		Carp::croak("Unknown linkage type $type");
	}
}

has cpp_flags => (
	is => 'rw',
	default => sub {
		return [ '-lstdc++' ];
	},
);
sub get_language_flags {
	my $self = shift;
	return [] if $self->language eq 'C';
	return [ $self->cpp_flags ] if $self->language eq 'C++';
}

around arguments => sub {
	my ($orig, $self, $from, $to, %opts) = @_;
	return (
		$self->$orig,
		ExtUtils::Builder::Argument->new(ranking => 10, value => $self->get_linker_flags),
		ExtUtils::Builder::Argument->new(ranking => 75, value => [ '-o' => $to, @{$from} ]),
		ExtUtils::Builder::Argument->new(ranking => 85, value => $self->get_language_flags),
	);
};

1;
