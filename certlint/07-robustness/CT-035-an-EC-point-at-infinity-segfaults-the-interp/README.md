# CT-035 — an EC point at infinity segfaults the interpreter

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `07-robustness` — Panics, run-ending failures, and non-determinism |
| **Impact on certificates issued today** | **High** — changes the verdict on certificates being issued now, or breaks the run for every consumer |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | a real corpus certificate with its subjectPublicKey replaced, and the unmodified certificate as the control |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

```ruby
      begin
        okey = OpenSSL::PKey::EC.new(spki_der)
      rescue ArgumentError => e
        messages << "E: EC public key #{e.message}"
      end
      if !okey.nil? && okey.public_key.infinity?
        messages << 'E: EC Public key is infinity'
      end
      if !okey.nil? && !okey.public_key.on_curve?
        messages << 'E: EC Public key is not on curve'
      end
```

### The mechanism

SEC 1 encodes the point at infinity as the single octet `0x00`. Ruby's
`OpenSSL::PKey::EC.new` accepts a `SubjectPublicKeyInfo` carrying it and
returns an object, so `okey.nil?` is false and the guard admits it — but the
`EVP_PKEY` it returns has no underlying `EC_KEY`, and `okey.public_key` calls
`EC_KEY_get0_public_key` on a null pointer. The interpreter takes SIGSEGV
inside libcrypto, at `certlint.rb:244`, which is the `infinity?` line. Nothing
is printed: `CertLint.lint` accumulates messages in an array and
`bin/certlint` prints them after it returns, so the findings already gathered
for that certificate die with the process.

Settled by execution, not by reading — three variants were run separately,
each in its own interpreter:

| subjectPublicKey | `EC.new` | `public_key` |
|---|---|---|
| valid uncompressed P-256 point | object | fine |
| `0x00` (point at infinity) | object | **SIGSEGV** |
| any other malformed point | `ArgumentError` | not reached |

```
$ ruby -I lib -I ext bin/certlint CL-T-cl-h-01-ec-point-at-infinity.der
/…/lib/certlint/certlint.rb:244: [BUG] Segmentation fault at 0x0000000000000020
…
Segmentation fault (core dumped)          # exit status 139

$ ruby -I lib -I ext bin/certlint CL-T-cl-h-01-control-ec-p256.der
                                          # exit status 0, no findings
```

**observed** — SIGSEGV, exit 139, no output. **correct** — `E: EC Public key
is infinity`, plus every other finding the certificate would have drawn.

Note that the check the crash prevents is the *only* place certlint would have
reported the shape, so the defect is not merely a crash: it is a crash instead
of the finding.

### Fix

One line. Ask the key for its point through a method that does not dereference
a key OpenSSL never populated, and treat a nil result as the finding:

```ruby
      point = okey.nil? ? nil : (okey.public_key rescue nil)
      if okey && point.nil?
        messages << 'E: EC Public key is infinity'
```
