#!/usr/bin/env perl

# p
#
# A pass-through to AWK with easier printing syntax.
#
# Usage: p [args to awk] [--] spec
#
#  All lone numbers in spec are converted to $\d+ fields in the
#  awk print statement.
#
#  Negative numbers are calculated as usual in interpreted languages: -1
#  is the last field, -2 the second to last, etc.
#
#  Use @\d+ for number literals, @-\d+ for negative literals.
#
#  Use @@ for literal '@', and %% for literal '%'.
#
#  Use %\d+ or %{\d+} (or with negative numbers) to explicitly specify
#  fields.
#
#  All AWK programs begin with 'BEGIN {OFS=FS}'.  If you specify an FS
#  (ie, via -F), the OFS will also be set to that character.
#
#  Because this pass-through script doesn't know which options take
#  arguments, spaces are disallowed between opt and arg _unless_ you use
#  a `--` to separate awk args from the print spec.  Ex: p -F , -- -1 3.
#
# Examples:
#   p 1 foo bar 2
#       awk '{print $1, "foo", "bar", $2}'
#
#   p 1 2 3
#       awk '{print $1, $2, $3}'
#
#   p 1 -1
#       awk '{print $1, $(NF)}'
#
#   p 1 -3
#       awk '{print $1, $(NF - 2)}'
#
#   p 1,2,3
#       awk '{print $1 "," $2 "," $3}'
#
#   p 1,@2,3
#       awk '{print $1 ",2," $3}'
#
#   p 1,@@2,3
#       awk '{print $1 ",@" $2 "," $3}'
#
#   p 1@2%3
#       awk '{print $1 "2" $3}'
#
#   p 1@{2%3anything}
#       awk '{print $1 "2%3anything" }'
#
#   p '1@2%{3}4'
#       awk '{print $1 "2" $3 $4}'
#
#   p '1%{4:-1}'
#       awk '{print $1 $4, $5, ..., $NF}'
#
#   p -1 -2 1
#       awk '{print $(NF), $(NF - 1), $1}'
#
#   NOTE: the 'BEGIN {OFS=FS}' part of the AWK program below has been
#         omitted in all above examples, but is passed to AWK in all
#         cases.
#   p -F\| 1 ' ' 2
#       awk -F \| 'BEGIN {OFS=FS} {print $1, " ", $2}'
#
#   NOTE: if you use -- as below, this pass-through script can handle
#         spaces between opts and their args
#   p -F\| -v foo=bar -- 1 ' ' 2
#       awk -F \| 'BEGIN {OFS=FS} {print $1, " ", $2}'
#
#   NOTE: quoting can be used to pass through single and double quotes,
#         and to put in separators beside that specified with -F.
#   p -F\| '"1" "2"' 3
#       awk -F \| 'BEGIN {OFS=FS} {print "\"" $1 "\" \"" $2 "\"", $3}'
#
# Copyright Justin Corn 2022
# Distributed under MIT license.

use warnings;
use strict;

my $DEBUG = $ENV{DEBUG};

sub begins_with_dash { qr/^-/ }
sub negative_int { qr/^-\d+$/ }
sub double_dash { qr/^--$/ }

sub is_print_spec_arg {
    my ($arg) = @_;

    return  !($arg =~ begins_with_dash && $arg !~ negative_int);
}

sub find_first_idx {
    my ($pred, $arr) = @_;

    for (my $i = 0; $i < @$arr; $i++) {
        return $i if $pred->($arr->[$i]);
    }

    return -1;
}

# Partition args into
#   - AWK opts meant to be passed along to AWK directly
#   - those following AWK opts that are part of the print specification dsl
sub partition_args {
    my @args = @_;

    my $double_dash_idx = find_first_idx(sub { $_[0] =~ double_dash }, \@args);
    my $has_double_dash = $double_dash_idx != -1;
    my $first_print_spec_idx = find_first_idx(\&is_print_spec_arg, \@args);
    my $part_idx = $has_double_dash ? $double_dash_idx + 1 : $first_print_spec_idx;
    my $has_no_print_spec = $part_idx == -1;
    my $has_no_awk_args = $part_idx == 0;

    if ($has_no_awk_args) {
        return ([], \@args);
    } elsif ($has_no_print_spec) {
        return (\@args, []);
    } else {
        my @awk_args = @args[0..($part_idx - 1)];
        my @print_spec = @args[$part_idx..$#args];

        return (\@awk_args, \@print_spec);
    }
}

sub token_re {
    return qr/
        (
            @@          | # literal @
            \%\%        | # literal %
            \@-?\d+     | # literal digits
            @\{[^}]*\}  | # literal block
            \%-?\d+     | # explicit field specifier
            \%\{[^}]*\} | # explicit field specifier
            -?\d+         # field specifier
        )
    /x;
}

sub token_group {
    my ($arg) = @_;

    my @tokens_with_empty_strings = split(token_re, $arg);
    my @token_group = grep { $_ ne '' } @tokens_with_empty_strings;

    warn "token_group:\n", join("\n", @token_group), "\n" if $DEBUG;

    return \@token_group;
}

sub dsl_token_to_awk_spec {
    my ($token) = @_;

    my $spec = undef;

    # literal @
    $spec = q{"@"} if ($token =~ /^@@$/);

    # literal %
    $spec = q{"%"} if ($token =~ /^%%$/);

    # literal digits
    if ($token =~ /^@(-?\d+)$/)     { $spec = qq{"$1"}; }

    # literal block
    if ($token =~ /^@\{([^}]*)\}$/) { $spec = qq{"$1"}; }

    # field specifiers
    if ($token =~ /^(\d+)$/)        { $spec = "\$$1"; }
    if ($token =~ /^%(\d+)$/)       { $spec = "\$$1"; }
    if ($token =~ /^%\{(\d+)\}$/)   { $spec = "\$$1"; }

    # negatively-indexed field specifiers
    if ($token =~ /^-(\d+)$/)       { $spec = qq{((NF - $1 + 1) < 1 ? "" : \$(NF - $1 + 1))}; }
    if ($token =~ /^%-(\d+)$/)      { $spec = qq{((NF - $1 + 1) < 1 ? "" : \$(NF - $1 + 1))}; }
    if ($token =~ /^%\{-(\d+)\}$/)  { $spec = qq{((NF - $1 + 1) < 1 ? "" : \$(NF - $1 + 1))}; }

    # range field specifier
    if ($token =~ /^%\{(\d+):(\d+)\}$/)   { $spec = qq{"";_print_range($1, $2); print }; }
    if ($token =~ /^%\{-(\d+):(\d+)\}$/)  { $spec = qq{"";_print_range(NF - $1 + 1, $2); print }; }
    if ($token =~ /^%\{(\d+):-(\d+)\}$/)  { $spec = qq{"";_print_range($1, NF - $2 + 1); print }; }
    if ($token =~ /^%\{-(\d+):-(\d+)\}$/) { $spec = qq{"";_print_range(NF - $1 + 1, NF - $2 + 1); print }; }

    # range field specifier with implicit start (1) or end (-1)
    if ($token =~ /^%\{:(\d+)\}$/)  { $spec = qq{"";_print_range(1, $1); print }; }
    if ($token =~ /^%\{:-(\d+)\}$/) { $spec = qq{"";_print_range(1, NF - $1 + 1); print }; }
    if ($token =~ /^%\{(\d+):\}$/)  { $spec = qq{"";_print_range($1, NF); print }; }
    if ($token =~ /^%\{-(\d+):\}$/) { $spec = qq{"";_print_range(NF - $1 + 1, NF); print }; }

    # syntax rejects
    if ($token =~ /^%\{(.*)\}$/ && !defined $spec) {
        die "invalid explicit field specifier: $token";
    }

    # add quotes to literal strings
    if (!defined $spec) {
        # Escape quote characters to be passed through.
        # Don't use quotemeta because gawk loudly rejects `\ ` and `\.`, for example.
        $token =~ s#"#\\"#g;
        $token =~ s#'#'\\''#g; # will be spliced into already-single-quoted command string
        $spec = qq{"$token"};
    }

    warn "token '$token' -> spec '$spec'" if $DEBUG;

    return $spec;
}

sub dsl_token_group_to_print_spec_group {
    my ($group) = @_;
    return [map { dsl_token_to_awk_spec($_) } @$group];
}

sub awk_prelude {
    my $prelude = <<'EOF';
BEGIN {
    OFS = FS
}

function _print_range(start, end) {
    _prev_ORS_in_print_range = ORS;
    ORS = "";

    i = start;

    if (i < 1) {
      i = 1;
    }

    if (end > NF) {
      end = NF
    }

    for (; i < end; i++) {
        print $i,"";
    }

    if (i == end) {
        print $end;
    }

    ORS = _prev_ORS_in_print_range;
}
EOF

    $prelude =~ s/\s+/ /g;

    return $prelude
}

sub main {
    my ($raw_awk_args, $raw_print_dsl) = partition_args(@ARGV);

    my @awk_args = map { quotemeta } @$raw_awk_args;

    my @token_groups = map { token_group($_) } @$raw_print_dsl;
    my @print_spec_groups = map { dsl_token_group_to_print_spec_group($_) } @token_groups;
    my @with_groups_joined = map { join(' ', @$_) } @print_spec_groups; # no comma in the awk print
    my $print_spec = join(', ', @with_groups_joined); # with comma in the awk print

    my $prelude = awk_prelude();

    my $cmd = join(' ', 'awk', @awk_args, qq{'$prelude {_prev_ORS=ORS; ORS=""; print $print_spec ""; ORS=_prev_ORS; printf "%s", ORS;}'});

    warn $cmd if $DEBUG;
    exec $cmd;
}

main();

1;
