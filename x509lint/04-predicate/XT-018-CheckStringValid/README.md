# XT-018 — a comment marking a branch "shouldn't happen" is wrong, reachable via a `UTF8String` glibc's own `iconv` misjudges

| | |
|---|---|
| **Tool** | `kroeckx/x509lint` at `103c92f` |
| **Group** | `04-predicate` — The test itself is wrong |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | the pinned source, read |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`checks.c:436-454`, inside `CheckStringValid`, after a `UTF8STRING` or
`BMPSTRING` value has already been converted to a local UTF-8 buffer:

```c
if (iconv(iconv_utf32, (char **)&s, &n, (char **)&pu, &utf32_size) == (size_t) -1 || n != 0)
{
	/* Shouldn't happen. */
	SetError(ERR_INVALID_ENCODING);
	free(utf8);
	free(utf32);
	return false;
}
```

The comment states this branch is believed unreachable: the preceding UTF-8
buffer was already produced by one successful `iconv` call (`iconv_utf8`, the
identity `"utf-8"` → `"utf-8"` conversion at `checks.c:302`, or `iconv_ucs2`
for a `BMPSTRING`), so converting it onward to UTF-32 is expected to succeed
unconditionally.

### Why it is reachable

Executed directly, reproducing `x509lint`'s exact two-`iconv` sequence in five
lines of C against the system `iconv` (glibc, matching what the vendored
`x509lint` binary links):

```c
unsigned char outrange[] = {0xF4, 0x90, 0x80, 0x80}; /* U+110000, > U+10FFFF */
/* PASS 1: iconv_open("utf-8","utf-8"), the identity conversion checks.c:2319 uses */
iconv(cd1, &s, &inleft, &pu1, &outleft1);   /* -> SUCCEEDS: x509lint accepts this
                                                 4-octet sequence as valid UTF8STRING */
/* PASS 2: iconv_open("utf-32","utf-8"), checks.c:2321 */
iconv(cd2, &s2, &inleft2, &pu2, &outleft2); /* -> FAILS: EILSEQ */
```

```
PASS 1 (utf8->utf8): result=0 inleft=0  SUCCEEDED
PASS 2 (utf8->utf32): result=-1 inleft2=4  FAILED -- reaches the "Shouldn't happen" branch
```

glibc's `"utf-8"` → `"utf-8"` `iconv` conversion does not enforce the
`U+10FFFF` ceiling X.690 § 8.23.10 and ISO/IEC 10646 both impose — a 4-octet
sequence spelling a codepoint above it passes the first, identity conversion
unchanged. The second conversion, which has to produce an actual UTF-32
codepoint rather than copy octets, rejects the same input. The "shouldn't
happen" branch is exactly where glibc's own two `iconv` code paths disagree
with each other about a single input.

### Why this is Low, not Medium or High

No verdict changes. The branch that was believed dead sets
`ERR_INVALID_ENCODING` — the identical error the first `iconv` call would have
set had it been strict — so the certificate is reported as an error either
way. What is wrong is the comment's claim about the code, not the code's
output.

### Reach

```
$ pkimetal-linters/x509lint/x509lint 
E: Error parsing certificate
```

### Fix

Either remove the comment's claim of unreachability (it is reachable, just not
on inputs the first `iconv` call itself would flag), or make the identity
`"utf-8"` → `"utf-8"` conversion strict — glibc's `iconv` accepts an
`//IGNORE`/`//TRANSLIT` suffix and a stricter target encoding, but the more
direct fix is validating the codepoint range in `checks.c` rather than relying
on `iconv`'s first pass to have already done it.
