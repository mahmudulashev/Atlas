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
