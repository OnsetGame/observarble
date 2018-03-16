## My module

import tables, macros
import logging


type 
    ObserverId = int
    Observarble* = ref object of RootObj
        ## Represents observarble object
        listeners: TableRef[ObserverId, seq[ObserverHandler]]
        noNotify: bool
    ObserverHandler* = proc(o: Observarble)

proc notifyOn*(o: Observarble): bool = 
    ## Get notify status
    not o.noNotify
proc `notifyOn=`*(o: Observarble, notifyOn: bool) = 
    ## Set notify status
    o.noNotify = not notifyOn

when defined(js):
    {.emit:"""
    var _nimx_observerIdCounter = 0;
    """.}

    proc getObserverId(rawId: RootRef): ObserverId =
        {.emit: """
            if (`rawId`.__nimx_observer_id === undefined) {
                `rawId`.__nimx_observer_id = --_nimx_observerIdCounter;
            }
            `result` = `rawId`.__nimx_observer_id;
        """.}
    template getObserverID(rawId: ref): ObserverId = getObserverId(cast[RootRef](rawId))
else:
    template getObserverID(rawId: ref): ObserverId = cast[int](rawId)


proc subscribe*(o: Observarble, r: ref, cb: ObserverHandler) =
    ## Subscribe 

    if o.listeners.isNil:
        o.listeners = newTable[ObserverId, seq[ObserverHandler]]()

    let id = getObserverId(r)
    var listeners = o.listeners.getOrDefault(id)
    if listeners.isNil:
        listeners = @[]
    listeners.add(cb)
    o.listeners[id] = listeners

proc subscribe*(oo: openarray[Observarble], r: ref, cb: ObserverHandler) =
    ## Subscribe to each object in sequence

    for o in oo:
        o.subscribe(r, cb)

proc unsubscribe*(o: Observarble, r: ref) =
    if o.listeners.isNil:
        return
    o.listeners.del(getObserverId(r))

proc unsubscribe*(oo: openarray[Observarble], r: ref) =
    for o in oo:
        o.unsubscribe(r)

proc unsubscribe*(o: Observarble, r: ref, cb: ObserverHandler) =
    if o.listeners.isNil:
        return
    let id = getObserverId(r)
    var listeners = o.listeners.getOrDefault(id)
    if listeners.isNil:
        return
    for c in cb:
        let index = listeners.find(c)
        if index > -1:
            listeners.del(index)

proc unsubscribe*(oo: openarray[Observarble], r: ref, cb: ObserverHandler) =
    for o in oo:
        o.unsubscribe(r, cb)

proc notify*(o: Observarble) =
    if o.noNotify:
        return

    for cbs in o.listeners.values:
        if cbs.isNil:
            continue
        for cb in cbs:
            cb(o)

template update*(o: Observarble, x: untyped): untyped =
    let notify = o.notifyOn
    o.notifyOn = false

    x

    o.notifyOn = notify
    if notify:
        o.notify()

template genType(T, TT): untyped =
    type T* = ref object of TT

proc toObservarble(x: NimNode, y: NimNode): NimNode =
    var T: NimNode
    var TT: NimNode
    
    if x.kind == nnkIdent:
        T = x
        TT = ident("Observarble")
    elif x.kind == nnkInfix:
        if not x[0].eqIdent("of"):
            error "Unexpected infix node\n" & treeRepr(x)
        T = x[1]
        TT = x[2]
    else:
        error "Unexpected AST\n" & treeRepr(x)

    let genType = getAst(genType(T, TT))
    
    if y.isNil:
        return nnkStmtList.newTree(genType)
    y.expectKind(nnkStmtList)

    var fields = nnkRecList.newTree()
    var procs = nnkStmtList.newTree()

    var propWhitelist: seq[string]
    var startInd = 0
    if y[0].kind == nnkCurly:
        startInd.inc
        propWhitelist = @[]
        for n in y[0]:
            n.expectKind(nnkIdent)
            propWhitelist.add($n.ident)

    for i in startInd ..< y.len:
        var node = y[i]
        var name: NimNode
        var ntype: NimNode
        var isPublic: bool
        var settings: NimNode
        var disabled = false

        if node.kind == nnkCommand and node[1].kind == nnkTableConstr:
            settings = node[1]
            node = node[0]

        if node.kind == nnkInfix:
            if not node[0].eqIdent("*"):
                error "Unexpected infix node\n" & treeRepr(node)
            name = node[1]
            ntype = node[2]
            isPublic = true
        elif node.kind == nnkCommand:
            name = node[0]
            ntype = node[1]
        else:
            error "Unexpected AST\n" & treeRepr(node)
        
        disabled = propWhitelist.len > 0 and $name.ident notin propWhitelist
        let pname = ident("p_" & $name)
        
        var getter = quote:
            proc `name`(o: `T`): `ntype` = o.`pname`
        var setter = quote:
            proc `name`(o: `T`, `name`: `ntype`) = 
                o.`pname` = `name`
                o.notify()
        setter[0] = nnkAccQuoted.newTree(ident($setter[0] & "="))

        if isPublic:
            getter[0] = nnkPostfix.newTree(ident("*"), getter[0])
            setter[0] = nnkPostfix.newTree(ident("*"), setter[0])

        if not settings.isNil:
            for x in settings:
                if x[0].eqIdent("setter"):
                    setter[6] = x[1][6]
                    setter[3] = x[1][3]
                elif x[0].eqIdent("getter"):
                    getter[6] = x[1][6]
                    getter[3] = x[1][3]
                elif x[0].eqIdent("disabled"):
                    if x[1].eqIdent("true"):
                        disabled = true
        
        if not disabled:
            procs.add([getter, setter])
            fields.add(
                nnkIdentDefs.newTree(
                    pname,
                    ntype,
                    newEmptyNode()
                )
            )
        else:
            fields.add(
                nnkIdentDefs.newTree(
                    (if isPublic: nnkPostfix.newTree(ident("*"), name) else: name),
                    ntype,
                    newEmptyNode()
                )
            )

    genType[0][2][0][2] = fields
    
    result = nnkStmtList.newTree(
        genType, 
        procs
    )

macro observarble*(x: untyped, y: untyped = nil): untyped =
    result = toObservarble(x, y)
    
    when defined(debugObservarble):
        echo "\ngen finished \n ", repr(result)