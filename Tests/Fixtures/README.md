# Fixtures

Small projects with a known shape, used by `Scripts/verify-engine.py` to check
that the engine still finds what it is supposed to find.

## `python-package`

A package whose modules reach each other with **relative** imports
(`from ..shared import util`). Resolving those means resolving `..` against the
importing file's directory — which `NSString.standardizingPath` does not do for
relative paths, so every such import was silently dropped before the engine
grew its own path arithmetic. The fixture pins that: `pkg/sub/mod.py` must
depend on both files in `pkg/shared`.

Deliberately **not** pinned to LF by a `.gitattributes`. A Windows runner
checks these files out with CRLF endings, which is exactly the shape the
engine has to cope with — so leaving git alone is what makes CI exercise it.
`Scripts/verify-engine.py` also checks it directly, for anyone working on a
machine where the checkout is LF.
