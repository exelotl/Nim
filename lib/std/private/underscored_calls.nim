
#
#
#            Nim's Runtime Library
#        (c) Copyright 2020 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This is an internal helper module. Do not use.

import macros

proc underscoredCall(n, arg0: NimNode): NimNode =

  proc dotExprPrepended(n, arg0: NimNode): NimNode =
    ## Turns `a.b` into `(arg0.a).b`, and `_.a` into `arg0.a`
    if n.kind == nnkDotExpr:
      if n[0].eqIdent("_"): newDotExpr(arg0, n[1])
      else: newDotExpr(dotExprPrepended(n[0], arg0), n[1])
    else: newDotExpr(arg0, n)

  proc underscorePos(n: NimNode): int =
    for i in 1 ..< n.len:
      if n[i].eqIdent("_"): return i
    return 0

  if n.kind in nnkCallKinds:
    result = copyNimNode(n)

    if n[0].kind == nnkDotExpr:
      # a.foo(x) becomes arg0.a.foo(x)
      result.add dotExprPrepended(n[0], arg0)
      for i in 1..n.len-1: result.add n[i]
    elif n.kind == nnkInfix:
      # a.x += 1 becomes arg0.a.x += 1
      result.add n[0]
      result.add dotExprPrepended(n[1], arg0)
      result.add n[2]
    else:
      # foo(a, b) becomes foo(arg0, a, b)
      # foo(a, _, b) becomes foo(a, arg0, b)
      result.add n[0]
      let u = underscorePos(n)
      for i in 1..u-1: result.add n[i]
      result.add arg0
      for i in u+1..n.len-1: result.add n[i]
  elif n.kind in {nnkAsgn, nnkExprEqExpr}:
    # a.x = 1 becomes arg0.a.x = 1
    result = dotExprPrepended(n[0], arg0).newAssignment n[1]
  elif n.kind == nnkDotExpr:
    result = dotExprPrepended(n, arg0)
  else:
    # handle e.g. 'x.dup(sort)'
    result = newNimNode(nnkCall, n)
    result.add n
    result.add arg0

proc underscoredCalls*(result, calls, arg0: NimNode) =
  expectKind calls, {nnkArglist, nnkStmtList, nnkStmtListExpr}

  for call in calls:
    if call.kind in {nnkStmtList, nnkStmtListExpr}:
      underscoredCalls(result, call, arg0)
    else:
      result.add underscoredCall(call, arg0)
