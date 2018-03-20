import tables, macros


type 
    ObserverId* = int
    Observarble* = ref object of RootObj
        listeners: TableRef[ObserverId, seq[ObserverHandler]]
        noNotify: bool
    ObserverHandler* = proc()

when defined(js):
    {.emit:"""
        var _nimx_observerIdCounter = 0;
    """.}

    proc getObserverId*(rawId: RootRef): ObserverId =
        {.emit: """
            if (`rawId`.__nimx_observer_id === undefined) {
                `rawId`.__nimx_observer_id = --_nimx_observerIdCounter;
            }
            `result` = `rawId`.__nimx_observer_id;
        """.}
    template getObserverId*(rawId: ref): ObserverId = getObserverId(cast[RootRef](rawId))
else:
    template getObserverId*(rawId: ref): ObserverId = cast[int](rawId)

template notifyOnGet(T): untyped =
    proc notifyOn*(o: T): bool = 
        not (o.noNotify)
        
template notifyOnSet(T): untyped =
    proc `notifyOn=`*(o: T, notifyOn: bool) =
        o.noNotify = not (notifyOn)

template subscribe(T): untyped =
    proc subscribe*(o: T, r: ref, cb: ObserverHandler) =
        if o.listeners.isNil:
            o.listeners = newTable[ObserverId, seq[ObserverHandler]]()

        let id = getObserverId(r)
        var listeners = o.listeners.getOrDefault(id)
        if listeners.isNil:
            listeners = @[]
        listeners.add(cb)
        o.listeners[id] = listeners

template subscribeSeq(T): untyped =
    proc subscribe*(oo: openarray[T], r: ref, cb: ObserverHandler) =
        for o in oo:
            o.subscribe(r, cb)

template unsubscribe(T): untyped =
    proc unsubscribe*(o: T, r: ref) =
        if o.listeners.isNil:
            return
        o.listeners.del(getObserverId(r))

template unsubscribeSeq(T): untyped =
    proc unsubscribe*(oo: openarray[T], r: ref) =
        for o in oo:
            o.unsubscribe(r)

template unsubscribeProc(T): untyped =
    proc unsubscribe*(o: T, r: ref, cb: ObserverHandler) =
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

template unsubscribeProcSeq(T): untyped =
    proc unsubscribe*(oo: openarray[T], r: ref, cb: ObserverHandler) =
        for o in oo:
            o.unsubscribe(r, cb)

template notify(T): untyped =
    proc notify*(o: T) =
        if o.noNotify:
            return

        for cbs in o.listeners.values:
            if cbs.isNil:
                continue
            for cb in cbs:
                cb()

template update*[T](o: T, x: untyped): untyped =
    let notify = o.notifyOn
    o.notifyOn = false
    
    x
    
    o.notifyOn = notify
    if notify:
        o.notify()

proc getObservarbleMethods(x: NimNode): NimNode =
    result = nnkStmtList.newTree(
        getAst(notifyOnGet(x)),
        getAst(notifyOnSet(x)),
        getAst(subscribe(x)),
        getAst(subscribeSeq(x)),
        getAst(unsubscribe(x)),
        getAst(unsubscribeSeq(x)),
        getAst(unsubscribeProc(x)),
        getAst(unsubscribeProcSeq(x)),
        getAst(notify(x))
    )

macro observarbleMethods(x: untyped): untyped =
    result = getObservarbleMethods(x)

observarbleMethods(Observarble)

template genType(T, TT): untyped =
    type T* = ref object of TT

proc toObservarble(x: NimNode, y: NimNode, isChild: bool): NimNode =
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

    if not isChild:
        fields.add(
            nnkIdentDefs.newTree(
                newIdentNode("listeners"),
                nnkBracketExpr.newTree(
                    newIdentNode("TableRef"),
                    newIdentNode("ObserverId"),
                    nnkBracketExpr.newTree(
                        newIdentNode("seq"),
                        newIdentNode("ObserverHandler")
                    )
                ),
                newEmptyNode()
            ),
            nnkIdentDefs.newTree(
                newIdentNode("noNotify"),
                newIdentNode("bool"),
                newEmptyNode()
            )
        )

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
        let notify = ident("notify")
        
        var getter = quote:
            proc `name`(o: `T`): `ntype` = o.`pname`
        var setter = quote:
            proc `name`(o: `T`, `name`: `ntype`) = 
                o.`pname` = `name`
                o.`notify`()
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

proc addObservarbleMethods(x: var NimNode) =
    var T = x[0][0][0]
    if T.kind == nnkPostfix:
        T = T[1]

    x = nnkStmtList.newTree(
        x[0],
        getObservarbleMethods(T),
        x[1]
    )

macro observarble*(x: untyped, y: untyped = nil): untyped =
    result = toObservarble(x, y, true)
    
    when defined(debugObservarble):
        echo "\ngen finished \n ", repr(result)

macro asObservarble*(x: untyped, y: untyped = nil): untyped =
    result = toObservarble(x, y, false)
    result.addObservarbleMethods()

    when defined(debugObservarble):
        echo "\ngen finished \n ", repr(result)