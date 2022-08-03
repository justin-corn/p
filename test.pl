use strict;
use warnings;
use Test::More tests => 17;

sub output_of {
    my ($input, @args) = @_;

    chomp $input;
    my @quoted_args = map { quotemeta } @args;

    my $cmd = <<EOF;
cat <<EOF2 | ./p @quoted_args
$input
EOF2
EOF

    return qx{$cmd};
}

# default input
my $input = <<EOF;
a b c
d e f
EOF

{
    my $expected = <<EOF;
a c
d f
EOF

    is(
        output_of($input, qw{1 3}), $expected,
        "should select fields"
    );
};


{
    my $expected = <<EOF;
pre a post
pre d post
EOF

    is(
        output_of($input, qw{pre 1 post}), $expected,
        "should pass through literal values"
    );
};

{
    my $expected = <<EOF;
c b
f e
EOF

    is(
        output_of($input, qw{-1 -2}), $expected,
        "should do negative indexing"
    );
};

{
    my $expected = <<EOF;
a  c
d  f
EOF

    is(
        output_of($input, qw{1 -200 -1}), $expected,
        "should turn out of bounds, negatively-index fields into empty strings"
    );
};

{
    my $expected = <<EOF;
a1
d1
EOF

    is(
        output_of($input, q{1%1}), $expected,
        "should allow pct literals without spaces in spec"
    );
};

{
    my $expected = <<EOF;
a-1
d-1
EOF

    is(
        output_of($input, q{1%-1}), $expected,
        "should allow negative pct literals without spaces in spec"
    );
};

{
    my $expected = <<EOF;
c2a
f2d
EOF
    is(
        output_of($input, q{3%{2}1}), $expected,
        "should allow pct fields with curly braces without spaces in spec"
    );
};

{
    my $expected = <<EOF;
b-1a
e-1d
EOF
    is(
        output_of($input, q{2%{-1}1}), $expected,
        "should allow negative pct fields with curly braces without spaces in spec"
    );
};

{
    my $expected = <<'EOF';
b%1
e%1
EOF
    is(
        output_of($input, q{2%%%1}), $expected,
        "should allow literal double pct"
    );
};

{
    my $expected = <<EOF;
ba
ed
EOF

    is(
        output_of($input, q{2$1}), $expected,
        "should allow dollar fields without spaces in spec"
    );
}

{
    my $expected = <<EOF;
bc
ef
EOF

    is(
        output_of($input, q{2$-1}), $expected,
        "should allow negative dollar fields without spaces in spec"
    );
}

{
    my $expected = <<EOF;
cba
fed
EOF
    is(
        output_of($input, q{3${2}1}), $expected,
        "should allow dollar fields with curly braces without spaces in spec"
    );
};

{
    my $expected = <<EOF;
bca
efd
EOF
    is(
        output_of($input, q{2${-1}1}), $expected,
        "should allow negative dollar fields with curly braces without spaces in spec"
    );
};

{
    my $expected = <<'EOF';
b$a
e$d
EOF
    is(
        output_of($input, q{2$$$1}), $expected,
        "should allow literal double dollar"
    );
};


{
    my $input = <<EOF;
a.b.c
d.e.f
EOF
    my $expected = <<EOF;
c
f
EOF
    is(
        output_of($input, qw{-F. 3}), $expected,
        "should recognize flags having params without space between opt and param"
    );
};

{
    my $input = <<EOF;
a.b.c
d.e.f
EOF
    my $expected = <<EOF;
c
f
EOF
    is(
        output_of($input, qw{-F . -- 3}), $expected,
        "should recognize flag having params with space between opt and arg if double dash is provided"
    );
};

{
    my $input = <<EOF;
a.b.c
d.e.f
EOF
    my $expected = <<EOF;
a.c
d.f
EOF
    is(
        output_of($input, qw{-F . -- 1 3}), $expected,
        "should set OFS=IFS in BEGIN block"
    );
};
