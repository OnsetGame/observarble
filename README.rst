===========
observarble
===========

*NOTE:* Use `-d:debugObservarble` to see macro output

1. Basic usage
--------------

.. code-block:: nim

    observarble MyObserverable1:
        field1* string
        field2 int


Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObservarble1* = ref object of Observarble
            p_field1: string
            p_field2: string

    proc field1(o186002: MyObservarble): string =
        o186002.p_field1

    proc `field1=`(o186004: MyObservarble; field1: string) =
        o186004.p_field1 = field1
        o186004.notify()

    proc field2*(o186006: MyObservarble): string =
        o186006.p_field2

    proc `field2=`*(o186008: MyObservarble; field2: string) =
        o186008.p_field2 = field2
        o186008.notify()


2. Mark some fields non-observarble
-----------------------------------

.. code-block:: nim

    observarble MyObserverable3:
        field1* string
        field2 int {disabled: true}
        field3* int {disabled: true}

Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObserverable3* = ref object of Observarble
            p_field1: string
            field2: int
            field3*: int

        proc field1*(o186032: MyObserverable2): string =
            o186032.p_field1

        proc `field1=`*(o186034: MyObserverable2; field1: string) =
            o186034.p_field1 = field1
            o186034.notify()


3. Set custom getter or setter
------------------------------

.. code-block:: nim

    observarble MyObserverable4:
        field1* string
        field2 string {
            getter: proc(o: MyObserverable4): string =
                result = o.field1 & o.field2
        }
        field3* string {
            setter: proc(o: MyObserverable4, v: string) =
                o.field1 = v
                o.field2 = v
                o.notify()
        }

Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObserverable4* = ref object of Observarble
            p_field1: string
            p_field2: string
            p_field3: string

    proc field1*(o186092: MyObserverable4): string =
        o186092.p_field1

    proc `field1=`*(o186094: MyObserverable4; field1: string) =
        o186094.p_field1 = field1
        o186094.notify()

    proc field2(o: MyObserverable4): string =
        result = o.field1 & o.field2

    proc `field2=`(o186098: MyObserverable4; field2: string) =
        o186098.p_field2 = field2
        o186098.notify()

    proc field3*(o186100: MyObserverable4): string =
        o186100.p_field3

    proc `field3=`*(o: MyObserverable4; v: string) =
        o.field1 = v
        o.field2 = v
        o.notify()


4. Inherits observarble type
----------------------------

.. code-block:: nim

    observarble MyObservarble5 of MyObservarble1:
        field3* string

Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObservarble5* = ref object of MyObservarble1
            p_field3: string

    proc field3*(o186136: MyObservarble5): string =
        o186136.p_field3

    proc `field3=`*(o186138: MyObservarble5; field3: string) =
        o186138.p_field3 = field3
        o186138.notify()


5. Enumerate observarble fields
--------------------------------

.. code-block:: nim

    observarble MyObservarble6:
        {field1, field4}

        field1* string
        field2 int
        field3* int
        field4* int
        field5* int


Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObservarble6* = ref object of Observarble
            p_field1: string
            field2: int
            field3*: int
            p_field4: int
            field5*: int

    proc field1*(o186002: MyObservarble6): string =
        o186002.p_field1

    proc `field1=`*(o186004: MyObservarble6; field1: string) =
        o186004.p_field1 = field1
        o186004.notify()

    proc field4*(o186014: MyObservarble6): int =
        o186014.p_field4

    proc `field4=`*(o186016: MyObservarble6; field4: int) =
        o186016.p_field4 = field4
        o186016.notify()


6. Create observarble from non-observarble parent
-------------------------------------------------

.. code-block:: nim

    type CustomType = ref object of RootObj
        field1: string

    asObservarble MyObservarble7 of CustomType:
        {field3}

        field2 string
        field3 string
        field4 string


Generated Code
~~~~~~~~~~~~~~

.. code-block:: nim

    type
        MyObservarble7* = ref object of CustomType
            listeners: TableRef[ObserverId, seq[ObserverHandler]]
            noNotify: bool
            field2: string
            p_field3: string
            field4: string

    proc notifyOn*(o186222: MyObservarble7): bool =
        not(o186222.noNotify)

    proc `notifyOn =`*(o186224: MyObservarble7; notifyOn186226: bool) =
        o186224.noNotify = not(notifyOn186226)

    proc subscribe*(o186228: MyObservarble7; r186230: ref; cb186232: ObserverHandler) =
        if o186228.listeners.isNil:
            o186228.listeners = newTable[ObserverId, seq[ObserverHandler]]()
        let id186234 = getObserverId(r186230)
        var listeners186236 = o186228.listeners.getOrDefault(id186234)
        if listeners186236.isNil:
            listeners186236 = @[]
        listeners186236.add(cb186232)
        []=(o186228.listeners186236, id186234, listeners186236)

    proc subscribe*(oo186238: openArray[MyObservarble7]; r186240: ref; cb186242: ObserverHandler) =
        for o186244 in oo186238:
            o186244.subscribe(r186240, cb186242)

    proc unsubscribe*(o186246: MyObservarble7; r186248: ref) =
        if o186246.listeners.isNil:
            return
        o186246.listeners.del(getObserverId(r186248))

    proc unsubscribe*(oo186250: openArray[MyObservarble7]; r186252: ref) =
        for o186254 in oo186250:
            o186254.unsubscribe(r186252)

    proc unsubscribe*(o186256: MyObservarble7; r186258: ref; cb186260: ObserverHandler) =
        if o186256.listeners.isNil:
            return
        let id186262 = getObserverId(r186258)
        var listeners186264 = o186256.listeners.getOrDefault(id186262)
        if listeners186264.isNil:
            return
        for c186266 in cb186260:
            let index186268 = listeners186264.find(c186266)
            if index186268 > -1:
            listeners186264.del(index186268)

    proc unsubscribe*(oo186270: openArray[MyObservarble7]; r186272: ref; cb186274: ObserverHandler) =
        for o186276 in oo186270:
            o186276.unsubscribe(r186272, cb186274)

    proc notify*(o186278: MyObservarble7) =
        if o186278.noNotify:
            return
        for cbs186280 in o186278.listeners.values:
            if cbs186280.isNil:
                continue
            for cb186282 in cbs186280:
                cb186282()

    proc field3(o186214: MyObservarble7): string =
        o186214.p_field3

    proc `field3=`(o186216: MyObservarble7; field3: string) =
        o186216.p_field3 = field3
        o186216.notify()


7. Reference
------------

Imports
~~~~~~~

`tables`, `macros`


Types
~~~~~

.. code-block:: nim

    type
        ObserverId* = int

        Observarble* = ref object of RootObj
            listeners: TableRef[ObserverId, seq[ObserverHandler]]
            noNotify: bool

        ObserverHandler* = proc()


Procs
~~~~~

.. code-block:: nim

    proc notifyOn*(o: Observarble): bool

    proc `notifyOn=`*(o: Observarble, notifyOn: bool)

    proc subscribe*(o: Observarble, r: ref, cb: ObserverHandler)

    proc subscribe*(oo: openarray[Observarble], r: ref, cb: ObserverHandler)

    proc unsubscribe*(o: Observarble, r: ref)

    proc unsubscribe*(oo: openarray[Observarble], r: ref)

    proc unsubscribe*(o: Observarble, r: ref, cb: ObserverHandler)

    proc unsubscribe*(oo: openarray[Observarble], r: ref, cb: ObserverHandler)

    proc notify*(o: Observarble)


Templates
~~~~~~~~~

.. code-block:: nim

    template update*[T](o: T, x: untyped): untyped


Macros
~~~~~~

.. code-block:: nim

    macro observarble*(x: untyped, y: untyped = nil): untyped

    macro asObservarble*(x: untyped, y: untyped = nil): untyped