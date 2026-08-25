# CT-016 — `E: No PDU defined` cannot fire given certlint's own registered extension handlers

| | |
|---|---|
| **Tool** | `certlint/certlint` at `528d78e` |
| **Group** | `02-unreachable` — Checks that cannot fire |
| **Impact on certificates issued today** | **Low** — no verdict changes on current issuance — historical certificates, message text, or a shape nobody issues |
| **Reproduction** | described below |
| **Requires** | the tool |
| **Cases** | none of its own |
| **Verified against** | enumeration of the real, vendored handler registry |

## Upstream issues, adjudicated

None found. Every issue on the tracker was read and searched for this check's identifier and the file it lives in.

## Analysis

### The code

`lib/certlint/extensions/asn1ext.rb:23-27`, the shared base class every
extension-specific checker inherits from:

```ruby
def self.lint(content, _cert, critical = false)
  messages = []
  if !@pdu.nil?
    messages += CertLint.check_pdu(@pdu, content)
  else
    messages << 'E: No PDU defined'
  end
  ...
```

The message fires when a subclass reaches this generic body with its class
instance variable `@pdu` left `nil` — a subclass that forgot to name the ASN.1
PDU its extension decodes as.

### The mechanism

Two ways a subclass avoids the branch: set a real `@pdu`, or override `lint`
itself so the generic body — and the `@pdu` it reads — is never reached at
all. `CL-T-cl-k-01-repro.rb` loads the real certlint and checks every class
registered with `CertExtLint` against both:

```
registered handlers: 27
handlers that could hit the 'No PDU defined' branch: 0
```

### Suggested fix

Either drop the branch (the two conditions that would trigger it — a new
handler with no `@pdu` and no override — is a certlint development mistake
that `NoMethodError` on a `nil` PDU inside `check_pdu` would already catch,
loudly, at development time) or add a class-level assertion in
`register_handler` that a class either declares `@pdu` or overrides `lint`, so
the gap is caught at registration rather than left as an unreachable runtime
message.

There is no certificate shape and no document requirement this could ever
answer; a faithful port would be dead code from the day it shipped.

## What was not verified

- Not checked against a **released** certlint. `bin/certlint` prints no version and no rebuild-and-diff against a tagged release was done, so this is a claim about commit `528d78e` as vendored, matching every other entry in this file's family. - The claim is about the **current** registry of 27 handlers only. A future handler added to certlint without following the `@pdu`-or-override discipline would reopen the branch; nothing here forecloses that.
