# p

A pass-through to awk with easier printing syntax.

## Blah blah

Writing AWK commands takes too many characters, and so do cut commands.
I always wanted a tool for printing stuff that behaved like AWK but was
more succinct.

Ex

```
ps aux | grep badman | p 2 | xargs kill -KILL
```

## Syntax

All lone numbers in spec are converted to $\d+ fields in the awk print
statement.

Negative numbers are calculated as usual in interpreted languages: -1 is
the last field, -2 the second to last, etc.

Any other text is copied to stdout literally.

Use `%\d+` for number literals, `%-\d+` for negative literals.

Use `%%` for literal `%`, and `$$` for literal `$`.

Use `$\d+` or `${\d+}` (or with negative numbers) to explicitly specify
fields.

All AWK programs begin with `BEGIN {OFS=IFS}`.  If you specify an IFS
(ie, via -F), the OFS will also be set to that character.

This pass-through script doesn't know which options take arguments, so
spaces are disallowed between opt and arg _unless_ you use a `--` to
separate awk args from the print spec.  Ex: `p -F , -- -1 3`.

## Examples

Given

```
p 1 2 3
```

Then invoke

```
awk '{print $1, $2, $3}'
```

---

Given

```
p 1 -1
```

Then invoke

```
awk '{print $1, $(NF)}'
```

---

Given

```
p 1 -3
```

Then invoke

```
awk '{print $1, $(NF - 2)}'
```

---

Given

```
p -1 -2 1
```

Then invoke

```
awk '{print $(NF), $(NF - 1), $1}'
```

---

Given

```
p 1 foo bar 2
```

Then invoke

```
awk '{print $1, "foo", "bar", $2}'
```

---

Given

```
p 1,2,3
```

Then invoke

```
awk '{print $1 "," $2 "," $3}'
```

---

Given

```
p 1,%2,3
```

Then invoke

```
awk '{print $1 ",2," $3}'
```

---

Given

```
p 1,%%2,3
```

Then invoke

```
awk '{print $1 ",%" $2 "," $3}'
```

---

Given

```
p 1%2\$3
```

Then invoke

```
awk '{print $1 "2" $3}'
```

---

Given

```
p '1%2${3}4'
```

Then invoke

```
awk '{print $1 "2" $3 $4}'
```

---

Given

```
p -F\| 1 ' ' 2
```

Then invoke

```
# NOTE: the 'BEGIN {OFS=IFS}' part of the AWK program below has been
#       omitted in all above examples, but is passed to AWK in all
#       cases.

awk -F \| 'BEGIN {OFS=IFS} {print $1, " ", $2}'
```

---

Given

```
p -F \| -v foo=bar -- 1 ' ' 2
```

Then invoke

```
# NOTE: if you use -- as above, this pass-through script can handle
#       spaces between opts and their args

awk -F \| 'BEGIN {OFS=IFS} {print $1, " ", $2}'
```

## Perl!?

OK, no one wants a syntax interpreter written in Perl and regexes, but
here I am.  This is because most systems I've used have Perl 5
pre-installed.  If yours does, too, it allows this script to be dropped
as-is onto the path.  Performance or whatever is not a concern because
this script isn't doing much work before AWK is invoked.  This script is
agnostic to the version of AWK you have installed.
